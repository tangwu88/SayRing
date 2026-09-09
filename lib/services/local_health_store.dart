import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../domain/models.dart';
import 'notification_inbox.dart';
import 'secure_vault.dart';

abstract interface class HealthStore implements NotificationInboxStorage {
  Future<void> initialize();
  Future<void> switchOwner(String ownerId);
  Future<void> adoptLegacyData({
    required String healthOwnerId,
    required String notificationOwnerId,
  });
  Future<void> upsert(List<HealthRecord> records);
  Future<void> upsertImmediate(HealthRecord record);
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

abstract interface class HealthStoreRecoveryStatus {
  String? get recoveryNotice;
  bool get recoveryPending;
}

abstract interface class HealthStoreFileOperations {
  Future<bool> exists(String file);
  Future<void> rename(String source, String destination);
  Future<void> delete(String file);
  Future<void> writeText(String file, String contents);
}

class IoHealthStoreFileOperations implements HealthStoreFileOperations {
  const IoHealthStoreFileOperations();

  @override
  Future<bool> exists(String file) => File(file).exists();

  @override
  Future<void> rename(String source, String destination) async {
    await File(source).rename(destination);
  }

  @override
  Future<void> delete(String file) => File(file).delete();

  @override
  Future<void> writeText(String file, String contents) =>
      File(file).writeAsString(contents, flush: true);
}

typedef HealthDatabaseOpener =
    Future<Database> Function(
      String file, {
      required String password,
      required int version,
      OnDatabaseConfigureFn? onConfigure,
      OnDatabaseCreateFn? onCreate,
      OnDatabaseVersionChangeFn? onUpgrade,
    });

Future<Database> _openEncryptedHealthDatabase(
  String file, {
  required String password,
  required int version,
  OnDatabaseConfigureFn? onConfigure,
  OnDatabaseCreateFn? onCreate,
  OnDatabaseVersionChangeFn? onUpgrade,
}) => openDatabase(
  file,
  password: password,
  version: version,
  onConfigure: onConfigure,
  onCreate: onCreate,
  onUpgrade: onUpgrade,
);

bool _isUnreadableEncryptedDatabaseError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('file is not a database') ||
      message.contains('sqlite_notadb') ||
      message.contains('code 26') ||
      message.contains('error 26') ||
      message.contains('hmac check failed');
}

class EncryptedHealthStore implements HealthStore, HealthStoreRecoveryStatus {
  EncryptedHealthStore(
    this._vault, {
    this._databasePathProvider,
    this._databaseOpener = _openEncryptedHealthDatabase,
    this.fileOperations = const IoHealthStoreFileOperations(),
    this.globalEdition = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SessionVault _vault;
  final bool globalEdition;
  final Future<String> Function()? _databasePathProvider;
  final HealthDatabaseOpener _databaseOpener;
  final HealthStoreFileOperations fileOperations;
  final DateTime Function() _clock;
  Database? _database;
  Future<void> _databaseQueue = Future<void>.value();
  String _ownerId = 'anonymous';

  @override
  String? recoveryNotice;

  @override
  bool recoveryPending = false;

  HealthStoreFileOperations get _fileOperations => fileOperations;

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _databaseQueue = _databaseQueue.catchError((_) {}).then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

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
    recoveryNotice = null;
    recoveryPending = false;
    final configuredPath = _databasePathProvider;
    final file = configuredPath == null
        ? path.join(
            (await getApplicationSupportDirectory()).path,
            globalEdition
                ? 'saydian_global_health_v1.db'
                : 'saydian_health_v1.db',
          )
        : await configuredPath();
    final recoveryMarker = _recoveryMarkerPath(file);
    if (await _fileOperations.exists(recoveryMarker)) {
      recoveryPending = true;
      recoveryNotice = '此前检测到本机加密数据库无法读取；原数据库文件仍保留，恢复处理尚未完成';
    }
    final password = await _vault.databaseKey();
    Future<Database> open() => _databaseOpener(
      file,
      password: password,
      version: 6,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE health_records (
            owner_id TEXT NOT NULL,
            id TEXT NOT NULL,
            metric TEXT NOT NULL,
            measured_at TEXT NOT NULL,
            payload TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(owner_id, id)
          )
        ''');
        await database.execute('''
          CREATE INDEX health_records_time
          ON health_records(owner_id, measured_at DESC)
        ''');
        await database.execute('''
          CREATE INDEX health_records_metric_time
          ON health_records(owner_id, metric, measured_at DESC)
        ''');
        await database.execute('''
          CREATE TABLE metadata (
            owner_id TEXT NOT NULL,
            key TEXT NOT NULL,
            value TEXT NOT NULL,
            PRIMARY KEY(owner_id, key)
          )
        ''');
        await database.execute('''
          CREATE TABLE sport_records (
            owner_id TEXT NOT NULL,
            id TEXT NOT NULL,
            started_at TEXT NOT NULL,
            payload TEXT NOT NULL,
            PRIMARY KEY(owner_id, id)
          )
        ''');
        await database.execute('''
          CREATE INDEX sport_records_time
          ON sport_records(owner_id, started_at DESC)
        ''');
        await _createHealthWarningTable(database);
        await _createNotificationInboxTable(database);
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
        if (oldVersion < 4) {
          await _createNotificationInboxTable(database);
        } else if (oldVersion < 5) {
          await _migrateNotificationInboxToAccountScope(database);
        }
        if (oldVersion < 6) {
          await _migrateHealthDataToAccountScope(database);
        }
      },
    );
    try {
      _database = await open();
    } catch (error, stackTrace) {
      if (!_isUnreadableEncryptedDatabaseError(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final recovered = await _quarantineUnreadableDatabase(file, open);
      if (recovered == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      _database = recovered;
      recoveryPending = true;
      recoveryNotice = '检测到本机加密数据库暂时无法读取；原数据库文件已隔离保留，App 当前使用新建数据库';
    }
  }

  static const _databaseFileSuffixes = ['', '-wal', '-shm', '-journal'];

  static String _recoveryMarkerPath(String file) => '$file.recovery-pending';

  Future<bool> _backupSetExists(String backupBase) async {
    for (final suffix in _databaseFileSuffixes) {
      if (await _fileOperations.exists('$backupBase$suffix')) return true;
    }
    return false;
  }

  Future<void> _rollbackMovedFiles(List<MapEntry<String, String>> moved) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final entry in moved.reversed) {
      try {
        if (!await _fileOperations.exists(entry.value)) continue;
        if (await _fileOperations.exists(entry.key)) {
          throw FileSystemException(
            'Refusing to overwrite a database file during recovery rollback',
            entry.key,
          );
        }
        await _fileOperations.rename(entry.value, entry.key);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  Future<void> _deleteFreshDatabaseFiles(String file) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final suffix in _databaseFileSuffixes.reversed) {
      final fresh = '$file$suffix';
      try {
        if (await _fileOperations.exists(fresh)) {
          await _fileOperations.delete(fresh);
        }
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  Future<void> _preserveRecoveryMarkerBestEffort(
    String marker,
    String backupBase,
  ) async {
    recoveryPending = true;
    recoveryNotice = '本机加密数据库恢复未完成；原数据库文件仍保留，请勿删除应用数据';
    try {
      if (!await _fileOperations.exists(marker)) {
        await _fileOperations.writeText(marker, '$backupBase\n');
      }
    } catch (_) {
      // The backup files remain authoritative even when a damaged filesystem
      // also prevents the conservative marker from being written.
    }
  }

  Future<Database?> _quarantineUnreadableDatabase(
    String file,
    Future<Database> Function() reopen,
  ) async {
    if (!await _fileOperations.exists(file)) return null;

    final token = _clock().toUtc().microsecondsSinceEpoch;
    var backupBase = '$file.unreadable-$token';
    var suffix = 0;
    while (await _backupSetExists(backupBase)) {
      suffix += 1;
      backupBase = '$file.unreadable-$token-$suffix';
    }
    final marker = _recoveryMarkerPath(file);
    final markerAlreadyExisted = await _fileOperations.exists(marker);

    final moved = <MapEntry<String, String>>[];
    try {
      for (final sidecar in _databaseFileSuffixes) {
        final source = '$file$sidecar';
        if (!await _fileOperations.exists(source)) continue;
        final backup = '$backupBase$sidecar';
        try {
          await _fileOperations.rename(source, backup);
          moved.add(MapEntry(source, backup));
        } catch (_) {
          // A custom or platform file operation can fail after performing the
          // rename. Detect that state so rollback still restores the source.
          if (!await _fileOperations.exists(source) &&
              await _fileOperations.exists(backup)) {
            moved.add(MapEntry(source, backup));
          }
          rethrow;
        }
      }
    } catch (error, stackTrace) {
      try {
        await _rollbackMovedFiles(moved);
      } catch (rollbackError, rollbackStackTrace) {
        await _preserveRecoveryMarkerBestEffort(marker, backupBase);
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    var markerCreated = false;
    try {
      if (!markerAlreadyExisted) {
        await _fileOperations.writeText(marker, '$backupBase\n');
        markerCreated = true;
      }
    } catch (error, stackTrace) {
      try {
        await _rollbackMovedFiles(moved);
      } catch (rollbackError, rollbackStackTrace) {
        await _preserveRecoveryMarkerBestEffort(marker, backupBase);
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      if (!markerAlreadyExisted && await _fileOperations.exists(marker)) {
        try {
          await _fileOperations.delete(marker);
        } catch (_) {
          // A stale marker is conservative: it prevents legacy migration from
          // being marked handled after the original files were restored.
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    try {
      return await reopen();
    } catch (error, stackTrace) {
      Object? recoveryError;
      StackTrace? recoveryStackTrace;
      try {
        // Every original path was vacated before reopen started, so files now
        // present at these paths were created by this reopen attempt only.
        await _deleteFreshDatabaseFiles(file);
      } catch (cleanupError, cleanupStackTrace) {
        recoveryError ??= cleanupError;
        recoveryStackTrace ??= cleanupStackTrace;
      }
      try {
        await _rollbackMovedFiles(moved);
      } catch (rollbackError, rollbackStackTrace) {
        recoveryError ??= rollbackError;
        recoveryStackTrace ??= rollbackStackTrace;
      }
      if (markerCreated && recoveryError == null) {
        try {
          if (await _fileOperations.exists(marker)) {
            await _fileOperations.delete(marker);
          }
        } catch (markerError, markerStackTrace) {
          recoveryError ??= markerError;
          recoveryStackTrace ??= markerStackTrace;
        }
      }
      if (recoveryError != null) {
        Error.throwWithStackTrace(recoveryError, recoveryStackTrace!);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> switchOwner(String ownerId) {
    final normalized = ownerId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'must not be empty');
    }
    return _enqueue(() async {
      _ownerId = normalized;
    });
  }

  @override
  Future<void> adoptLegacyData({
    required String healthOwnerId,
    required String notificationOwnerId,
  }) {
    final healthOwner = healthOwnerId.trim();
    final notificationOwner = notificationOwnerId.trim();
    const legacyOwner = 'legacy-unscoped';
    if (healthOwner.isEmpty ||
        notificationOwner.isEmpty ||
        healthOwner == legacyOwner ||
        notificationOwner == legacyOwner) {
      throw ArgumentError('Legacy data requires stable account owners');
    }
    return _enqueue(() async {
      await _db.transaction((transaction) async {
        await transaction.execute(
          '''
          INSERT OR IGNORE INTO health_records(
            owner_id, id, metric, measured_at, payload, synced
          )
          SELECT ?, id, metric, measured_at, payload, synced
          FROM health_records WHERE owner_id = ?
          ''',
          [healthOwner, legacyOwner],
        );
        await transaction.delete(
          'health_records',
          where: 'owner_id = ?',
          whereArgs: [legacyOwner],
        );
        await transaction.execute(
          '''
          INSERT OR IGNORE INTO sport_records(
            owner_id, id, started_at, payload
          )
          SELECT ?, id, started_at, payload
          FROM sport_records WHERE owner_id = ?
          ''',
          [healthOwner, legacyOwner],
        );
        await transaction.delete(
          'sport_records',
          where: 'owner_id = ?',
          whereArgs: [legacyOwner],
        );
        await transaction.execute(
          '''
          INSERT OR IGNORE INTO health_warning_alerts(
            owner_id, id, triggered_at, payload
          )
          SELECT ?, id, triggered_at, payload
          FROM health_warning_alerts WHERE owner_id = ?
          ''',
          [healthOwner, legacyOwner],
        );
        await transaction.delete(
          'health_warning_alerts',
          where: 'owner_id = ?',
          whereArgs: [legacyOwner],
        );
        await transaction.execute(
          '''
          INSERT OR IGNORE INTO metadata(owner_id, key, value)
          SELECT ?, key, value FROM metadata WHERE owner_id = ?
          ''',
          [healthOwner, legacyOwner],
        );
        await transaction.delete(
          'metadata',
          where: 'owner_id = ?',
          whereArgs: [legacyOwner],
        );
        await transaction.execute(
          '''
          INSERT OR IGNORE INTO notification_inbox(
            account_id, event_id, created_at, payload
          )
          SELECT ?, event_id, created_at, payload
          FROM notification_inbox WHERE account_id = ?
          ''',
          [notificationOwner, legacyOwner],
        );
        await transaction.delete(
          'notification_inbox',
          where: 'account_id = ?',
          whereArgs: [legacyOwner],
        );
      });
    });
  }

  static Future<void> _createHealthWarningTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS health_warning_alerts (
        owner_id TEXT NOT NULL,
        id TEXT NOT NULL,
        triggered_at TEXT NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY(owner_id, id)
      )
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS health_warning_alerts_time
      ON health_warning_alerts(owner_id, triggered_at DESC)
    ''');
  }

  static Future<void> _createNotificationInboxTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS notification_inbox (
        account_id TEXT NOT NULL,
        event_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY(account_id, event_id)
      )
    ''');
    await database.execute('''
      CREATE INDEX IF NOT EXISTS notification_inbox_time
      ON notification_inbox(account_id, created_at DESC)
    ''');
  }

  static Future<void> _migrateNotificationInboxToAccountScope(
    Database database,
  ) async {
    await database.execute(
      'ALTER TABLE notification_inbox RENAME TO notification_inbox_legacy_v4',
    );
    await database.execute('DROP INDEX IF EXISTS notification_inbox_time');
    await _createNotificationInboxTable(database);
    await database.execute('''
      INSERT INTO notification_inbox(account_id, event_id, created_at, payload)
      SELECT 'legacy-unscoped', event_id, created_at, payload
      FROM notification_inbox_legacy_v4
    ''');
    await database.execute('DROP TABLE notification_inbox_legacy_v4');
  }

  static Future<bool> _tableExists(Database database, String name) async {
    final rows = await database.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static Future<void> _migrateHealthDataToAccountScope(
    Database database,
  ) async {
    const legacyOwner = 'legacy-unscoped';

    if (await _tableExists(database, 'health_records')) {
      await database.execute(
        'ALTER TABLE health_records RENAME TO health_records_legacy_v5',
      );
      await database.execute('DROP INDEX IF EXISTS health_records_time');
      await database.execute('DROP INDEX IF EXISTS health_records_metric_time');
    }
    await database.execute('''
      CREATE TABLE health_records (
        owner_id TEXT NOT NULL,
        id TEXT NOT NULL,
        metric TEXT NOT NULL,
        measured_at TEXT NOT NULL,
        payload TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(owner_id, id)
      )
    ''');
    await database.execute('''
      CREATE INDEX health_records_time
      ON health_records(owner_id, measured_at DESC)
    ''');
    await database.execute('''
      CREATE INDEX health_records_metric_time
      ON health_records(owner_id, metric, measured_at DESC)
    ''');
    if (await _tableExists(database, 'health_records_legacy_v5')) {
      await database.execute(
        '''
        INSERT INTO health_records(
          owner_id, id, metric, measured_at, payload, synced
        )
        SELECT ?, id, metric, measured_at, payload, synced
        FROM health_records_legacy_v5
      ''',
        [legacyOwner],
      );
      await database.execute('DROP TABLE health_records_legacy_v5');
    }

    if (await _tableExists(database, 'sport_records')) {
      await database.execute(
        'ALTER TABLE sport_records RENAME TO sport_records_legacy_v5',
      );
      await database.execute('DROP INDEX IF EXISTS sport_records_time');
    }
    await database.execute('''
      CREATE TABLE sport_records (
        owner_id TEXT NOT NULL,
        id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY(owner_id, id)
      )
    ''');
    await database.execute('''
      CREATE INDEX sport_records_time
      ON sport_records(owner_id, started_at DESC)
    ''');
    if (await _tableExists(database, 'sport_records_legacy_v5')) {
      await database.execute(
        '''
        INSERT INTO sport_records(owner_id, id, started_at, payload)
        SELECT ?, id, started_at, payload
        FROM sport_records_legacy_v5
      ''',
        [legacyOwner],
      );
      await database.execute('DROP TABLE sport_records_legacy_v5');
    }

    if (await _tableExists(database, 'health_warning_alerts')) {
      await database.execute('''
        ALTER TABLE health_warning_alerts
        RENAME TO health_warning_alerts_legacy_v5
      ''');
      await database.execute('DROP INDEX IF EXISTS health_warning_alerts_time');
    }
    await _createHealthWarningTable(database);
    if (await _tableExists(database, 'health_warning_alerts_legacy_v5')) {
      await database.execute(
        '''
        INSERT INTO health_warning_alerts(
          owner_id, id, triggered_at, payload
        )
        SELECT ?, id, triggered_at, payload
        FROM health_warning_alerts_legacy_v5
      ''',
        [legacyOwner],
      );
      await database.execute('DROP TABLE health_warning_alerts_legacy_v5');
    }

    if (await _tableExists(database, 'metadata')) {
      await database.execute(
        'ALTER TABLE metadata RENAME TO metadata_legacy_v5',
      );
    }
    await database.execute('''
      CREATE TABLE metadata (
        owner_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY(owner_id, key)
      )
    ''');
    if (await _tableExists(database, 'metadata_legacy_v5')) {
      await database.execute(
        '''
        INSERT INTO metadata(owner_id, key, value)
        SELECT ?, key, value FROM metadata_legacy_v5
      ''',
        [legacyOwner],
      );
      await database.execute('DROP TABLE metadata_legacy_v5');
    }
  }

  @override
  Future<void> upsert(List<HealthRecord> records) async {
    if (records.isEmpty) return;
    final ownerId = _ownerId;
    // Device sync may return thousands of samples. Sending every insert over
    // the platform channel while a transaction is open keeps SQLCipher locked
    // long enough to block a freshly completed manual measurement. A batch is
    // still atomic, but crosses the channel only once.
    await _enqueue(() async {
      final batch = _db.batch();
      for (final record in records) {
        batch.insert('health_records', {
          'owner_id': ownerId,
          'id': record.id,
          'metric': record.metric.wireName,
          'measured_at': record.measuredAt.toUtc().toIso8601String(),
          'payload': record.encode(),
          'synced': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> upsertImmediate(HealthRecord record) async {
    // A completed manual measurement is user-facing and must not sit behind a
    // large historical/cloud read. Initial device sync has already finished
    // before measurements are enabled, so this single non-transactional insert
    // can safely use sqflite's native command queue without joining the slower
    // background store queue.
    final ownerId = _ownerId;
    await _enqueue(
      () => _db.insert('health_records', {
        'owner_id': ownerId,
        'id': record.id,
        'metric': record.metric.wireName,
        'measured_at': record.measuredAt.toUtc().toIso8601String(),
        'payload': record.encode(),
        'synced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore),
    );
  }

  @override
  Future<List<HealthRecord>> recent({int limit = 200}) async {
    final ownerId = _ownerId;
    final rows = await _enqueue(
      () => _db.query(
        'health_records',
        columns: ['payload'],
        where: 'owner_id = ? AND synced != -1',
        whereArgs: [ownerId],
        orderBy: 'measured_at DESC',
        limit: limit,
      ),
    );
    return _decodeRows(rows);
  }

  @override
  Future<List<HealthRecord>> range({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) async {
    final ownerId = _ownerId;
    final rows = await _enqueue(
      () => _db.query(
        'health_records',
        columns: ['payload'],
        where:
            'owner_id = ? AND metric = ? AND measured_at >= ? AND measured_at < ? AND synced != -1',
        whereArgs: [
          ownerId,
          metric.wireName,
          start.toUtc().toIso8601String(),
          end.toUtc().toIso8601String(),
        ],
        orderBy: 'measured_at ASC',
      ),
    );
    return _decodeRows(rows);
  }

  @override
  Future<List<HealthRecord>> latestForEachMetric() async {
    final ownerId = _ownerId;
    final rows = await _enqueue(
      () => _db.rawQuery(
        '''
        SELECT payload
        FROM health_records AS current
        WHERE current.owner_id = ? AND current.synced != -1 AND measured_at = (
          SELECT MAX(candidate.measured_at)
          FROM health_records AS candidate
          WHERE candidate.owner_id = current.owner_id
            AND candidate.metric = current.metric
            AND candidate.synced != -1
        )
        ORDER BY measured_at DESC
      ''',
        [ownerId],
      ),
    );
    return _decodeRows(rows);
  }

  @override
  Future<void> saveSportRecord(SportRecord record) {
    final ownerId = _ownerId;
    return _enqueue(
      () => _db.insert('sport_records', {
        'owner_id': ownerId,
        'id': record.id,
        'started_at': (record.startedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'payload': jsonEncode(record.toMap()),
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
  }

  @override
  Future<List<SportRecord>> localSportRecords() async {
    final ownerId = _ownerId;
    final rows = await _enqueue(
      () => _db.query(
        'sport_records',
        columns: ['payload'],
        where: 'owner_id = ?',
        whereArgs: [ownerId],
        orderBy: 'started_at DESC',
      ),
    );
    return rows
        .map((row) => jsonDecode('${row['payload']}'))
        .whereType<Map>()
        .map(SportRecord.fromMap)
        .toList();
  }

  @override
  Future<void> saveHealthWarningAlert(HealthWarningAlert alert) {
    final ownerId = _ownerId;
    return _enqueue(
      () => _db.insert('health_warning_alerts', {
        'owner_id': ownerId,
        'id': alert.id,
        'triggered_at': alert.triggeredAt.toUtc().toIso8601String(),
        'payload': jsonEncode(alert.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
  }

  @override
  Future<List<HealthWarningAlert>> healthWarningAlerts() async {
    final ownerId = _ownerId;
    final rows = await _enqueue(
      () => _db.query(
        'health_warning_alerts',
        columns: ['payload'],
        where: 'owner_id = ?',
        whereArgs: [ownerId],
        orderBy: 'triggered_at DESC',
      ),
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
  Future<List<Map<String, Object?>>> readAll({
    String ownerId = 'default',
  }) async {
    final rows = await _enqueue(
      () => _db.query(
        'notification_inbox',
        columns: ['payload'],
        where: 'account_id = ?',
        whereArgs: [ownerId],
        orderBy: 'created_at DESC',
      ),
    );
    return rows
        .map((row) => jsonDecode('${row['payload']}'))
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  @override
  Future<void> replaceAll(
    List<Map<String, Object?>> rows, {
    String ownerId = 'default',
  }) => _enqueue(() async {
    await _db.transaction((transaction) async {
      await transaction.delete(
        'notification_inbox',
        where: 'account_id = ?',
        whereArgs: [ownerId],
      );
      final batch = transaction.batch();
      for (final row in rows) {
        final eventId = '${row['event_id'] ?? ''}'.trim();
        final createdAt = row['created_at'];
        if (eventId.isEmpty || createdAt is! num) continue;
        batch.insert('notification_inbox', {
          'account_id': ownerId,
          'event_id': eventId,
          'created_at': createdAt.toInt(),
          'payload': jsonEncode(row),
        });
      }
      await batch.commit(noResult: true);
    });
  });

  @override
  Future<List<HealthRecord>> pending({int limit = 200}) async {
    final ownerId = _ownerId;
    final rows = await _enqueue(
      () => _db.query(
        'health_records',
        columns: ['payload'],
        where: 'owner_id = ? AND synced = 0',
        whereArgs: [ownerId],
        orderBy: 'measured_at ASC',
        limit: limit,
      ),
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
    final ownerId = _ownerId;
    final values = ids.toSet().toList();
    if (values.isEmpty) return;
    final placeholders = List.filled(values.length, '?').join(',');
    await _enqueue(
      () => _db.update(
        'health_records',
        {'synced': 1},
        where: 'owner_id = ? AND id IN ($placeholders)',
        whereArgs: [ownerId, ...values],
      ),
    );
  }

  @override
  Future<void> markInvalid(Iterable<String> ids) async {
    final ownerId = _ownerId;
    final values = ids.toSet().toList();
    if (values.isEmpty) return;
    final placeholders = List.filled(values.length, '?').join(',');
    await _enqueue(
      () => _db.update(
        'health_records',
        {'synced': -1},
        where: 'owner_id = ? AND id IN ($placeholders)',
        whereArgs: [ownerId, ...values],
      ),
    );
  }

  @override
  Future<String?> readCursor() async {
    final ownerId = _ownerId;
    return _enqueue(() async {
      final rows = await _db.query(
        'metadata',
        columns: ['value'],
        where: 'owner_id = ? AND key = ?',
        whereArgs: [ownerId, 'sync_cursor'],
        limit: 1,
      );
      return rows.isEmpty ? null : '${rows.first['value']}';
    });
  }

  @override
  Future<void> writeCursor(String cursor) {
    final ownerId = _ownerId;
    return _enqueue(
      () => _db.insert('metadata', {
        'owner_id': ownerId,
        'key': 'sync_cursor',
        'value': cursor,
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
  }

  @override
  Future<void> close() async {
    await _enqueue(() async {
      await _database?.close();
      _database = null;
    });
  }
}

class MemoryHealthStore implements HealthStore {
  String _ownerId = 'anonymous';
  final Map<String, Map<String, HealthRecord>> _recordsByOwner = {};
  final Map<String, Set<String>> _syncedByOwner = {};
  final Map<String, Set<String>> _invalidByOwner = {};
  final Map<String, String> _cursorByOwner = {};
  final Map<String, Map<String, SportRecord>> _sportRecordsByOwner = {};
  final Map<String, Map<String, HealthWarningAlert>>
  _healthWarningAlertsByOwner = {};
  final Map<String, List<Map<String, Object?>>> _notificationInboxRowsByOwner =
      <String, List<Map<String, Object?>>>{};

  @override
  Future<void> initialize() async {}

  Map<String, HealthRecord> get _records =>
      _recordsByOwner.putIfAbsent(_ownerId, () => <String, HealthRecord>{});

  Set<String> get _synced =>
      _syncedByOwner.putIfAbsent(_ownerId, () => <String>{});

  Set<String> get _invalid =>
      _invalidByOwner.putIfAbsent(_ownerId, () => <String>{});

  Map<String, SportRecord> get _sportRecords =>
      _sportRecordsByOwner.putIfAbsent(_ownerId, () => <String, SportRecord>{});

  Map<String, HealthWarningAlert> get _healthWarningAlerts =>
      _healthWarningAlertsByOwner.putIfAbsent(
        _ownerId,
        () => <String, HealthWarningAlert>{},
      );

  @override
  Future<void> switchOwner(String ownerId) async {
    final normalized = ownerId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'must not be empty');
    }
    _ownerId = normalized;
  }

  @override
  Future<void> adoptLegacyData({
    required String healthOwnerId,
    required String notificationOwnerId,
  }) async {
    final healthOwner = healthOwnerId.trim();
    final notificationOwner = notificationOwnerId.trim();
    const legacyOwner = 'legacy-unscoped';
    if (healthOwner.isEmpty ||
        notificationOwner.isEmpty ||
        healthOwner == legacyOwner ||
        notificationOwner == legacyOwner) {
      throw ArgumentError('Legacy data requires stable account owners');
    }

    void moveMap<T>(Map<String, Map<String, T>> source, String targetOwner) {
      final legacy = source.remove(legacyOwner);
      if (legacy == null) return;
      final target = source.putIfAbsent(targetOwner, () => <String, T>{});
      for (final entry in legacy.entries) {
        target.putIfAbsent(entry.key, () => entry.value);
      }
    }

    void moveSet(Map<String, Set<String>> source, String targetOwner) {
      final legacy = source.remove(legacyOwner);
      if (legacy == null) return;
      source.putIfAbsent(targetOwner, () => <String>{}).addAll(legacy);
    }

    moveMap(_recordsByOwner, healthOwner);
    moveSet(_syncedByOwner, healthOwner);
    moveSet(_invalidByOwner, healthOwner);
    moveMap(_sportRecordsByOwner, healthOwner);
    moveMap(_healthWarningAlertsByOwner, healthOwner);
    final legacyCursor = _cursorByOwner.remove(legacyOwner);
    if (legacyCursor != null) {
      _cursorByOwner.putIfAbsent(healthOwner, () => legacyCursor);
    }
    final legacyInbox = _notificationInboxRowsByOwner.remove(legacyOwner);
    if (legacyInbox != null) {
      final target = _notificationInboxRowsByOwner.putIfAbsent(
        notificationOwner,
        () => <Map<String, Object?>>[],
      );
      final knownIds = target
          .map((row) => '${row['event_id'] ?? ''}')
          .where((id) => id.isNotEmpty)
          .toSet();
      target.addAll(
        legacyInbox.where((row) => knownIds.add('${row['event_id'] ?? ''}')),
      );
    }
  }

  @override
  Future<void> upsert(List<HealthRecord> records) async {
    for (final record in records) {
      _records.putIfAbsent(record.id, () => record);
    }
  }

  @override
  Future<void> upsertImmediate(HealthRecord record) => upsert([record]);

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
  Future<List<Map<String, Object?>>> readAll({
    String ownerId = 'default',
  }) async => (_notificationInboxRowsByOwner[ownerId] ?? const [])
      .map((row) => Map<String, Object?>.from(row))
      .toList(growable: false);

  @override
  Future<void> replaceAll(
    List<Map<String, Object?>> rows, {
    String ownerId = 'default',
  }) async {
    _notificationInboxRowsByOwner[ownerId] = rows
        .map((row) => Map<String, Object?>.from(row))
        .toList(growable: false);
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
  Future<String?> readCursor() async => _cursorByOwner[_ownerId];

  @override
  Future<void> writeCursor(String cursor) async =>
      _cursorByOwner[_ownerId] = cursor;

  @override
  Future<void> close() async {}
}
