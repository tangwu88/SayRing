import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../domain/models.dart';
import 'secure_vault.dart';

abstract interface class HealthStore {
  Future<void> initialize();
  Future<void> upsert(List<HealthRecord> records);
  Future<List<HealthRecord>> recent({int limit = 200});
  Future<List<HealthRecord>> range({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  });
  Future<List<HealthRecord>> latestForEachMetric();
  Future<void> saveSportRecord(SportRecord record);
  Future<List<SportRecord>> localSportRecords();
  Future<void> saveHealthWarningAlert(HealthWarningAlert alert);
  Future<List<HealthWarningAlert>> healthWarningAlerts();
  Future<List<HealthRecord>> pending({int limit = 200});
  Future<void> markSynced(Iterable<String> ids);
  Future<void> markInvalid(Iterable<String> ids);
  Future<String?> readCursor();
  Future<void> writeCursor(String cursor);
  Future<void> close();
}

class EncryptedHealthStore implements HealthStore {
  EncryptedHealthStore(this._vault);

  final SessionVault _vault;
  Database? _database;

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('Health store has not been initialized');
    }
    return database;
  }

  @override
  Future<void> initialize() async {
    if (_database != null) return;
    final directory = await getApplicationSupportDirectory();
    final file = path.join(directory.path, 'saydian_health_v1.db');
    final password = await _vault.databaseKey();
    _database = await openDatabase(
      file,
      password: password,
      version: 3,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE health_records (
            id TEXT PRIMARY KEY,
            metric TEXT NOT NULL,
            measured_at TEXT NOT NULL,
            payload TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await database.execute('''
          CREATE INDEX health_records_time
          ON health_records(measured_at DESC)
        ''');
        await database.execute('''
          CREATE INDEX health_records_metric_time
          ON health_records(metric, measured_at DESC)
        ''');
        await database.execute('''
          CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE sport_records (
            id TEXT PRIMARY KEY,
            started_at TEXT NOT NULL,
            payload TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE INDEX sport_records_time
          ON sport_records(started_at DESC)
        ''');
        await _createHealthWarningTable(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('''
            CREATE INDEX IF NOT EXISTS health_records_metric_time
            ON health_records(metric, measured_at DESC)
          ''');
          await database.execute('''
            CREATE TABLE IF NOT EXISTS sport_records (
              id TEXT PRIMARY KEY,
              started_at TEXT NOT NULL,
              payload TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE INDEX IF NOT EXISTS sport_records_time
            ON sport_records(started_at DESC)
          ''');
        }
        if (oldVersion < 3) await _createHealthWarningTable(database);
      },
    );
  }

  static Future<void> _createHealthWarningTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS health_warning_alerts (
        id TEXT PRIMARY KEY,
        triggered_at TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS health_warning_alerts_time
      ON health_warning_alerts(triggered_at DESC)
    ''');
  }

  @override
  Future<void> upsert(List<HealthRecord> records) async {
    if (records.isEmpty) return;
    // Device sync may return thousands of samples. Sending every insert over
    // the platform channel while a transaction is open keeps SQLCipher locked
    // long enough to block a freshly completed manual measurement. A batch is
    // still atomic, but crosses the channel only once.
    final batch = _db.batch();
    for (final record in records) {
      batch.insert('health_records', {
        'id': record.id,
        'metric': record.metric.wireName,
        'measured_at': record.measuredAt.toUtc().toIso8601String(),
        'payload': record.encode(),
        'synced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<HealthRecord>> recent({int limit = 200}) async {
    final rows = await _db.query(
      'health_records',
      columns: ['payload'],
      where: 'synced != -1',
      orderBy: 'measured_at DESC',
      limit: limit,
    );
    return _decodeRows(rows);
  }

  @override
  Future<List<HealthRecord>> range({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _db.query(
      'health_records',
      columns: ['payload'],
      where:
          'metric = ? AND measured_at >= ? AND measured_at < ? AND synced != -1',
      whereArgs: [
        metric.wireName,
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
      ],
      orderBy: 'measured_at ASC',
    );
    return _decodeRows(rows);
  }

  @override
  Future<List<HealthRecord>> latestForEachMetric() async {
    final rows = await _db.rawQuery('''
      SELECT payload
      FROM health_records AS current
      WHERE current.synced != -1 AND measured_at = (
        SELECT MAX(candidate.measured_at)
        FROM health_records AS candidate
        WHERE candidate.metric = current.metric AND candidate.synced != -1
      )
      ORDER BY measured_at DESC
    ''');
    return _decodeRows(rows);
  }

  @override
  Future<void> saveSportRecord(SportRecord record) =>
      _db.insert('sport_records', {
        'id': record.id,
        'started_at': (record.startedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'payload': jsonEncode(record.toMap()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<List<SportRecord>> localSportRecords() async {
    final rows = await _db.query(
      'sport_records',
      columns: ['payload'],
      orderBy: 'started_at DESC',
    );
    return rows
        .map((row) => jsonDecode('${row['payload']}'))
        .whereType<Map>()
        .map(SportRecord.fromMap)
        .toList();
  }

  @override
  Future<void> saveHealthWarningAlert(HealthWarningAlert alert) =>
      _db.insert('health_warning_alerts', {
        'id': alert.id,
        'triggered_at': alert.triggeredAt.toUtc().toIso8601String(),
        'payload': jsonEncode(alert.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<List<HealthWarningAlert>> healthWarningAlerts() async {
    final rows = await _db.query(
      'health_warning_alerts',
      columns: ['payload'],
      orderBy: 'triggered_at DESC',
    );
    return rows
        .map((row) => jsonDecode('${row['payload']}'))
        .whereType<Map>()
        .map(
          (value) => HealthWarningAlert.fromJson(
            value.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .where((alert) => alert.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<HealthRecord>> pending({int limit = 200}) async {
    final rows = await _db.query(
      'health_records',
      columns: ['payload'],
      where: 'synced = 0',
      orderBy: 'measured_at ASC',
      limit: limit,
    );
    return _decodeRows(rows);
  }

  List<HealthRecord> _decodeRows(List<Map<String, Object?>> rows) => rows
      .map((row) => jsonDecode('${row['payload']}'))
      .whereType<Map>()
      .map(
        (value) => HealthRecord.fromJson(
          value.map((key, value) => MapEntry('$key', value)),
        ),
      )
      .toList();

  @override
  Future<void> markSynced(Iterable<String> ids) async {
    final values = ids.toSet().toList();
    if (values.isEmpty) return;
    final placeholders = List.filled(values.length, '?').join(',');
    await _db.update(
      'health_records',
      {'synced': 1},
      where: 'id IN ($placeholders)',
      whereArgs: values,
    );
  }

  @override
  Future<void> markInvalid(Iterable<String> ids) async {
    final values = ids.toSet().toList();
    if (values.isEmpty) return;
    final placeholders = List.filled(values.length, '?').join(',');
    await _db.update(
      'health_records',
      {'synced': -1},
      where: 'id IN ($placeholders)',
      whereArgs: values,
    );
  }

  @override
  Future<String?> readCursor() async {
    final rows = await _db.query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['sync_cursor'],
      limit: 1,
    );
    return rows.isEmpty ? null : '${rows.first['value']}';
  }

  @override
  Future<void> writeCursor(String cursor) => _db.insert('metadata', {
    'key': 'sync_cursor',
    'value': cursor,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

class MemoryHealthStore implements HealthStore {
  final Map<String, HealthRecord> _records = {};
  final Set<String> _synced = {};
  final Set<String> _invalid = {};
  String? _cursor;
  final Map<String, SportRecord> _sportRecords = {};
  final Map<String, HealthWarningAlert> _healthWarningAlerts = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<void> upsert(List<HealthRecord> records) async {
    for (final record in records) {
      _records.putIfAbsent(record.id, () => record);
    }
  }

  @override
  Future<List<HealthRecord>> recent({int limit = 200}) async {
    final values =
        _records.values
            .where((record) => !_invalid.contains(record.id))
            .toList()
          ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return values.take(limit).toList();
  }

  @override
  Future<List<HealthRecord>> range({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) async {
    final values =
        _records.values
            .where(
              (record) =>
                  !_invalid.contains(record.id) &&
                  record.metric == metric &&
                  !record.measuredAt.isBefore(start) &&
                  record.measuredAt.isBefore(end),
            )
            .toList()
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return values;
  }

  @override
  Future<List<HealthRecord>> latestForEachMetric() async {
    final latest = <HealthMetric, HealthRecord>{};
    for (final record in _records.values) {
      if (_invalid.contains(record.id)) continue;
      final current = latest[record.metric];
      if (current == null || record.measuredAt.isAfter(current.measuredAt)) {
        latest[record.metric] = record;
      }
    }
    final values = latest.values.toList()
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return values;
  }

  @override
  Future<void> saveSportRecord(SportRecord record) async {
    _sportRecords[record.id] = record;
  }

  @override
  Future<List<SportRecord>> localSportRecords() async {
    final values = _sportRecords.values.toList()
      ..sort(
        (a, b) => (b.startedAt ?? DateTime(1970)).compareTo(
          a.startedAt ?? DateTime(1970),
        ),
      );
    return values;
  }

  @override
  Future<void> saveHealthWarningAlert(HealthWarningAlert alert) async {
    _healthWarningAlerts[alert.id] = alert;
  }

  @override
  Future<List<HealthWarningAlert>> healthWarningAlerts() async {
    final values = _healthWarningAlerts.values.toList()
      ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    return values;
  }

  @override
  Future<List<HealthRecord>> pending({int limit = 200}) async => _records.values
      .where(
        (record) =>
            !_synced.contains(record.id) && !_invalid.contains(record.id),
      )
      .take(limit)
      .toList();

  @override
  Future<void> markSynced(Iterable<String> ids) async => _synced.addAll(ids);

  @override
  Future<void> markInvalid(Iterable<String> ids) async => _invalid.addAll(ids);

  @override
  Future<String?> readCursor() async => _cursor;

  @override
  Future<void> writeCursor(String cursor) async => _cursor = cursor;

  @override
  Future<void> close() async {}
}
