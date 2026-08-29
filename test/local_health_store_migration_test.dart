import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/notification_inbox.dart';
import 'package:saydian_app/services/notification_models.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test(
    'unreadable encrypted database is preserved before a fresh database opens',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'saidian-health-unreadable-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = path.join(directory.path, 'health.db');
      final originalBytes = List<int>.generate(128, (index) => index);
      await File(file).writeAsBytes(originalBytes);
      await File('$file-wal').writeAsBytes(const [9, 8, 7]);
      await File('$file-shm').writeAsBytes(const [6, 5, 4]);
      await File('$file-journal').writeAsBytes(const [3, 2, 1]);
      const token = 1787988600000000;
      final collidingSidecar = '$file.unreadable-$token-journal';
      await File(collidingSidecar).writeAsBytes(const [99]);
      var attempts = 0;
      final factory = databaseFactoryFfi;
      final store = EncryptedHealthStore(
        MemorySessionVault(),
        databasePathProvider: () async => file,
        clock: () => DateTime.utc(2026, 8, 29, 7, 30),
        databaseOpener:
            (
              databasePath, {
              required password,
              required version,
              onConfigure,
              onCreate,
              onUpgrade,
            }) async {
              attempts += 1;
              if (attempts == 1) {
                throw StateError(
                  'DatabaseException(file is not a database (code 26))',
                );
              }
              return factory.openDatabase(
                databasePath,
                options: OpenDatabaseOptions(
                  version: version,
                  onConfigure: onConfigure,
                  onCreate: onCreate,
                  onUpgrade: onUpgrade,
                ),
              );
            },
      );

      await store.initialize();

      expect(attempts, 2);
      expect(store.recoveryPending, isTrue);
      expect(store.recoveryNotice, contains('原数据库文件已隔离保留'));
      final backupBase = '$file.unreadable-$token-1';
      expect(await File(backupBase).readAsBytes(), originalBytes);
      expect(await File('$backupBase-wal').readAsBytes(), const [9, 8, 7]);
      expect(await File('$backupBase-shm').readAsBytes(), const [6, 5, 4]);
      expect(await File('$backupBase-journal').readAsBytes(), const [3, 2, 1]);
      expect(await File(collidingSidecar).readAsBytes(), const [99]);
      expect(
        await File('$file.recovery-pending').readAsString(),
        '$backupBase\n',
      );
      expect(await File(file).exists(), isTrue);
      await store.switchOwner('qa-account');
      expect(await store.recent(), isEmpty);
      await store.close();

      final restarted = EncryptedHealthStore(
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
      await restarted.initialize();
      expect(restarted.recoveryPending, isTrue);
      expect(restarted.recoveryNotice, contains('恢复处理尚未完成'));
      await restarted.close();

      await File('$file.recovery-pending').delete();
      await restarted.initialize();
      expect(restarted.recoveryPending, isFalse);
      expect(restarted.recoveryNotice, isNull);
      await restarted.close();
    },
  );

  test(
    'recovery rollback restores the unreadable database when reopen fails',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'saidian-health-rollback-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = path.join(directory.path, 'health.db');
      const originalBytes = [4, 3, 2, 1];
      await File(file).writeAsBytes(originalBytes);
      await File('$file-wal').writeAsBytes(const [4, 4]);
      await File('$file-shm').writeAsBytes(const [3, 3]);
      await File('$file-journal').writeAsBytes(const [2, 2]);
      var attempts = 0;
      final store = EncryptedHealthStore(
        MemorySessionVault(),
        databasePathProvider: () async => file,
        clock: () => DateTime.utc(2026, 8, 29, 7, 31),
        databaseOpener:
            (
              databasePath, {
              required password,
              required version,
              onConfigure,
              onCreate,
              onUpgrade,
            }) async {
              attempts += 1;
              if (attempts == 1) {
                throw StateError('file is not a database (code 26)');
              }
              await File(databasePath).writeAsBytes(const [9, 9, 9]);
              await File('$databasePath-wal').writeAsBytes(const [8, 8]);
              await File('$databasePath-shm').writeAsBytes(const [7, 7]);
              await File('$databasePath-journal').writeAsBytes(const [6, 6]);
              throw StateError('disk I/O error');
            },
      );

      await expectLater(store.initialize(), throwsStateError);

      expect(attempts, 2);
      expect(await File(file).readAsBytes(), originalBytes);
      expect(await File('$file-wal').readAsBytes(), const [4, 4]);
      expect(await File('$file-shm').readAsBytes(), const [3, 3]);
      expect(await File('$file-journal').readAsBytes(), const [2, 2]);
      expect(await File('$file.recovery-pending').exists(), isFalse);
      expect(
        await directory
            .list()
            .where((entry) => entry.path.contains('.unreadable-'))
            .toList(),
        isEmpty,
      );
    },
  );

  for (final failure in const [
    (name: 'first', attempt: 1),
    (name: 'middle', attempt: 2),
  ]) {
    test(
      '${failure.name} quarantine rename failure preserves every original file',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'saidian-health-rename-failure-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = path.join(directory.path, 'health.db');
        await File(file).writeAsBytes(const [1, 2, 3, 4]);
        await File('$file-wal').writeAsBytes(const [5, 6]);
        await File('$file-journal').writeAsBytes(const [7, 8]);
        var openAttempts = 0;
        final store = EncryptedHealthStore(
          MemorySessionVault(),
          databasePathProvider: () async => file,
          fileOperations: _FailingRenameFileOperations(failure.attempt),
          clock: () => DateTime.utc(2026, 8, 29, 7, 32),
          databaseOpener:
              (
                _, {
                required password,
                required version,
                onConfigure,
                onCreate,
                onUpgrade,
              }) async {
                openAttempts += 1;
                throw StateError('file is not a database (code 26)');
              },
        );

        await expectLater(
          store.initialize(),
          throwsA(isA<FileSystemException>()),
        );

        expect(openAttempts, 1);
        expect(await File(file).readAsBytes(), const [1, 2, 3, 4]);
        expect(await File('$file-wal').readAsBytes(), const [5, 6]);
        expect(await File('$file-journal').readAsBytes(), const [7, 8]);
        expect(await File('$file.recovery-pending').exists(), isFalse);
        expect(
          await directory
              .list()
              .where((entry) => entry.path.contains('.unreadable-'))
              .toList(),
          isEmpty,
        );
      },
    );
  }

  test('non-key database failures do not move the existing database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'saidian-health-io-error-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = path.join(directory.path, 'health.db');
    const originalBytes = [1, 3, 5, 7];
    await File(file).writeAsBytes(originalBytes);
    final store = EncryptedHealthStore(
      MemorySessionVault(),
      databasePathProvider: () async => file,
      databaseOpener:
          (
            _, {
            required password,
            required version,
            onConfigure,
            onCreate,
            onUpgrade,
          }) async => throw StateError('disk I/O error'),
    );

    await expectLater(store.initialize(), throwsStateError);

    expect(await File(file).readAsBytes(), originalBytes);
    expect(
      await directory
          .list()
          .where((entry) => entry.path.contains('.unreadable-'))
          .toList(),
      isEmpty,
    );
  });

  test(
    'pending recovery prevents legacy migration from being marked handled',
    () async {
      final vault = MemorySessionVault();
      final store = _PendingRecoveryHealthStore();
      final controller = AppController(
        vault,
        _MigrationTestApi(),
        store,
        _MigrationTestWearable(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(vault.legacyHealthMigrationHandled, isFalse);
      expect(store.adoptLegacyCallCount, 0);
      expect(controller.storageStatus, contains('恢复处理尚未完成'));
    },
  );
}

class _FailingRenameFileOperations implements HealthStoreFileOperations {
  _FailingRenameFileOperations(this.failureAttempt);

  final int failureAttempt;
  final _delegate = const IoHealthStoreFileOperations();
  int _renameAttempt = 0;

  @override
  Future<void> delete(String file) => _delegate.delete(file);

  @override
  Future<bool> exists(String file) => _delegate.exists(file);

  @override
  Future<void> rename(String source, String destination) async {
    _renameAttempt += 1;
    if (_renameAttempt == failureAttempt) {
      throw FileSystemException('injected rename failure', source);
    }
    await _delegate.rename(source, destination);
  }

  @override
  Future<void> writeText(String file, String contents) =>
      _delegate.writeText(file, contents);
}

class _PendingRecoveryHealthStore extends MemoryHealthStore
    implements HealthStoreRecoveryStatus {
  int adoptLegacyCallCount = 0;

  @override
  bool get recoveryPending => true;

  @override
  String? get recoveryNotice => '此前检测到本机加密数据库无法读取；原数据库文件仍保留，恢复处理尚未完成';

  @override
  Future<void> adoptLegacyData({
    required String healthOwnerId,
    required String notificationOwnerId,
  }) async {
    adoptLegacyCallCount += 1;
    await super.adoptLegacyData(
      healthOwnerId: healthOwnerId,
      notificationOwnerId: notificationOwnerId,
    );
  }
}

class _MigrationTestApi extends Fake implements SaydianApi {
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];
}

class _MigrationTestWearable extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}

final _warningTime = DateTime.utc(2026, 8, 28, 3, 5);
