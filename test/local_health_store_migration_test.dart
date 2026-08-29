import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/notification_inbox.dart';
import 'package:saydian_app/services/notification_models.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'v5 to v6 keeps old data unscoped until the persisted account adopts it',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'saidian-health-v3-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = path.join(directory.path, 'health.db');
      final factory = databaseFactoryFfi;
      final measuredAt = DateTime.utc(2026, 8, 28, 3, 4, 5);
      final record = HealthRecord(
        id: 'legacy-heart-rate',
        metric: HealthMetric.heartRate,
        values: const {'value': 72},
        unit: 'bpm',
        measuredAt: measuredAt,
        timezone: '+08:00',
        deviceId: 'legacy-watch',
        firmwareVersion: '1.0',
        quality: 'good',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      );
      final warning = HealthWarningAlert(
        id: 'legacy-warning',
        metric: HealthMetric.heartRate,
        title: '心率提醒',
        message: '历史提醒',
        triggeredAt: _warningTime,
      );
      final sport = SportRecord(
        id: 'legacy-sport',
        mode: SportMode.running,
        startedAt: measuredAt,
        durationSeconds: 600,
        distanceKm: 1.2,
        calories: 80,
      );

      final legacy = await factory.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (database, _) async {
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
            await database.execute(
              'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
            await database.execute('''
            CREATE TABLE sport_records (
              id TEXT PRIMARY KEY,
              started_at TEXT NOT NULL,
              payload TEXT NOT NULL
            )
          ''');
            await database.execute('''
            CREATE TABLE health_warning_alerts (
              id TEXT PRIMARY KEY,
              triggered_at TEXT NOT NULL,
              payload TEXT NOT NULL
            )
          ''');
            await database.execute('''
            CREATE TABLE notification_inbox (
              account_id TEXT NOT NULL,
              event_id TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              payload TEXT NOT NULL,
              PRIMARY KEY(account_id, event_id)
            )
          ''');
            await database.execute('''
            CREATE INDEX notification_inbox_time
            ON notification_inbox(account_id, created_at DESC)
          ''');
            await database.insert('health_records', {
              'id': record.id,
              'metric': record.metric.wireName,
              'measured_at': measuredAt.toIso8601String(),
              'payload': record.encode(),
              'synced': 0,
            });
            await database.insert('health_warning_alerts', {
              'id': warning.id,
              'triggered_at': warning.triggeredAt.toIso8601String(),
              'payload': jsonEncode(warning.toJson()),
            });
            await database.insert('sport_records', {
              'id': sport.id,
              'started_at': measuredAt.toIso8601String(),
              'payload': jsonEncode(sport.toMap()),
            });
            await database.insert('metadata', {
              'key': 'sync_cursor',
              'value': 'legacy-cursor',
            });
          },
        ),
      );
      await legacy.close();

      final store = EncryptedHealthStore(
        MemorySessionVault(),
        databasePathProvider: () async => file,
        databaseOpener:
            (
              databasePath, {
              required password,
              required version,
              onConfigure,
              onCreate,
              onUpgrade,
            }) => factory.openDatabase(
              databasePath,
              options: OpenDatabaseOptions(
                version: version,
                onConfigure: onConfigure,
                onCreate: onCreate,
                onUpgrade: onUpgrade,
              ),
            ),
      );
      await store.initialize();

      expect(await store.recent(), isEmpty);
      expect(await store.healthWarningAlerts(), isEmpty);
      expect(await store.localSportRecords(), isEmpty);
      expect(await store.readCursor(), isNull);

      await store.switchOwner('signed-in-account');
      expect(await store.recent(), isEmpty);
      expect(await store.healthWarningAlerts(), isEmpty);
      expect(await store.localSportRecords(), isEmpty);
      expect(await store.readCursor(), isNull);

      await store.switchOwner('legacy-unscoped');
      expect((await store.recent()).single.id, record.id);
      expect((await store.healthWarningAlerts()).single.id, warning.id);
      expect((await store.localSportRecords()).single.id, sport.id);
      expect(await store.readCursor(), 'legacy-cursor');

      await store.adoptLegacyData(
        healthOwnerId: 'signed-in-account',
        notificationOwnerId: 'signed-in-notifications',
      );
      await store.switchOwner('signed-in-account');
      expect((await store.recent()).single.id, record.id);
      expect((await store.healthWarningAlerts()).single.id, warning.id);
      expect((await store.localSportRecords()).single.id, sport.id);
      expect(await store.readCursor(), 'legacy-cursor');
      await store.switchOwner('legacy-unscoped');
      expect(await store.recent(), isEmpty);
      expect(await store.healthWarningAlerts(), isEmpty);
      expect(await store.localSportRecords(), isEmpty);
      expect(await store.readCursor(), isNull);

      final inbox = StoredNotificationInboxRepository(store);
      final event = NotificationEvent.tryParse(<String, Object?>{
        'schema_version': 1,
        'event_id': 'migration-event',
        'event_type': 'system',
        'source': 'server',
        'created_at': '2026-08-29T08:00:00Z',
      });
      expect(event, isNotNull);
      await inbox.upsert(event!);
      expect((await inbox.list()).single.eventId, 'migration-event');
      await store.close();

      final verified = await factory.openDatabase(file);
      final schema = await verified.query(
        'sqlite_master',
        columns: ['name'],
        where: 'type = ? AND name = ?',
        whereArgs: ['index', 'notification_inbox_time'],
      );
      expect(schema, hasLength(1));
      expect(await verified.getVersion(), 6);
      await verified.close();
    },
  );

  test('v4 inbox rows remain unscoped until explicitly adopted', () async {
    final directory = await Directory.systemTemp.createTemp(
      'saidian-health-v4-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = path.join(directory.path, 'health.db');
    final factory = databaseFactoryFfi;
    final legacy = await factory.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (database, _) async {
          await database.execute('''
            CREATE TABLE notification_inbox (
              event_id TEXT PRIMARY KEY,
              created_at INTEGER NOT NULL,
              payload TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE INDEX notification_inbox_time
            ON notification_inbox(created_at DESC)
          ''');
          await database.insert('notification_inbox', {
            'event_id': 'legacy-event',
            'created_at': 1787990400,
            'payload': jsonEncode(const <String, Object?>{
              'schema_version': 1,
              'event_id': 'legacy-event',
              'event_type': 'system',
              'source': 'server',
              'created_at': 1787990400,
            }),
          });
        },
      ),
    );
    await legacy.close();

    final store = EncryptedHealthStore(
      MemorySessionVault(),
      databasePathProvider: () async => file,
      databaseOpener:
          (
            databasePath, {
            required password,
            required version,
            onConfigure,
            onCreate,
            onUpgrade,
          }) => factory.openDatabase(
            databasePath,
            options: OpenDatabaseOptions(
              version: version,
              onConfigure: onConfigure,
              onCreate: onCreate,
              onUpgrade: onUpgrade,
            ),
          ),
    );
    await store.initialize();

    expect(
      await StoredNotificationInboxRepository(
        store,
        ownerId: 'signed-in-account',
      ).list(),
      isEmpty,
    );
    expect(
      (await StoredNotificationInboxRepository(
        store,
        ownerId: 'legacy-unscoped',
      ).list()).single.eventId,
      'legacy-event',
    );
    await store.adoptLegacyData(
      healthOwnerId: 'signed-in-health',
      notificationOwnerId: 'signed-in-account',
    );
    expect(
      (await StoredNotificationInboxRepository(
        store,
        ownerId: 'signed-in-account',
      ).list()).single.eventId,
      'legacy-event',
    );
    expect(
      await StoredNotificationInboxRepository(
        store,
        ownerId: 'legacy-unscoped',
      ).list(),
      isEmpty,
    );
    await store.close();
  });
}

final _warningTime = DateTime.utc(2026, 8, 28, 3, 5);
