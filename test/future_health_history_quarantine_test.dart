import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_record_validation.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

HealthRecord _sample(
  String id,
  HealthMetric metric,
  DateTime at, {
  MeasurementSource source = MeasurementSource.wearable,
  MeasurementOrigin origin = MeasurementOrigin.watchHistory,
}) => HealthRecord(
  id: id,
  metric: metric,
  values: {
    'value': switch (metric) {
      HealthMetric.hrv => 50,
      HealthMetric.bodyTemperature => 36.5,
      HealthMetric.bloodOxygen => 98,
      _ => 40,
    },
  },
  unit: metric.defaultUnit,
  measuredAt: at,
  timezone: '-05:00',
  deviceId: 'qring:synthetic-ring',
  firmwareVersion: 'synthetic',
  quality: 'device_reported',
  source: source,
  origin: origin,
  rawVersion: 1,
);

Future<({EncryptedHealthStore store, Database database})> _sqliteStore(
  DateTime Function() clock,
) async {
  final directory = await Directory.systemTemp.createTemp('ring-time-guard-');
  addTearDown(() => directory.delete(recursive: true));
  late Database database;
  final store = EncryptedHealthStore(
    MemorySessionVault(),
    clock: clock,
    globalEdition: true,
    storageNamespace: List.filled(64, 'a').join(),
    databasePathProvider: () async => '${directory.path}/health.db',
    databaseOpener:
        (
          databasePath, {
          required password,
          required version,
          onConfigure,
          onCreate,
          onUpgrade,
        }) async => database = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: version,
            onConfigure: onConfigure,
            onCreate: onCreate,
            onUpgrade: onUpgrade,
          ),
        ),
  );
  addTearDown(store.close);
  await store.initialize();
  await store.switchOwner('owner-a');
  return (store: store, database: database);
}

Future<void> _legacyInsert(
  Database database,
  HealthRecord record, {
  String owner = 'owner-a',
  int synced = 0,
}) => database.insert('health_records', {
  'owner_id': owner,
  'id': record.id,
  'metric': record.metric.wireName,
  'measured_at': record.measuredAt.toUtc().toIso8601String(),
  'payload': record.encode(),
  'synced': synced,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  for (final metric in const [
    HealthMetric.hrv,
    HealthMetric.stress,
    HealthMetric.bodyTemperature,
    HealthMetric.bloodOxygen,
  ]) {
    for (final entry in ['batch', 'immediate', 'cloud']) {
      test(
        '$entry future ${metric.name} keeps exact payload but is hidden',
        () async {
          final now = DateTime.now().toUtc();
          final f = await _sqliteStore(() => now);
          final past = _sample(
            'past',
            metric,
            now.subtract(const Duration(minutes: 10)),
          );
          final future = _sample(
            'future',
            metric,
            now.add(const Duration(hours: 7)),
          );
          await f.store.upsert([past]);
          switch (entry) {
            case 'batch':
              await f.store.upsert([future]);
            case 'immediate':
              await f.store.upsertImmediate(future);
            case 'cloud':
              await f.store.upsertSynced([future]);
          }
          expect((await f.store.recent()).map((r) => r.id), ['past']);
          expect((await f.store.latestForEachMetric()).single.id, 'past');
          expect(
            (await f.store.range(
              metric: metric,
              start: now.subtract(const Duration(days: 1)),
              end: now.add(const Duration(days: 10)),
            )).map((r) => r.id),
            ['past'],
          );
          expect((await f.store.pendingForMetrics({metric})).map((r) => r.id), [
            'past',
          ]);
          final raw = (await f.database.query(
            'health_records',
            where: 'owner_id = ? AND id = ?',
            whereArgs: ['owner-a', future.id],
          )).single;
          expect(raw['id'], future.id);
          expect(raw['payload'], future.encode());
          expect(
            raw['measured_at'],
            future.measuredAt.toUtc().toIso8601String(),
          );
          expect(raw['synced'], -1);
        },
      );
    }
  }

  test(
    'five minute boundary and non-history sources keep existing behavior',
    () async {
      final now = DateTime.now().toUtc();
      final f = await _sqliteStore(() => now);
      final edge = _sample(
        'edge',
        HealthMetric.hrv,
        now.add(const Duration(minutes: 5)),
      );
      final after = _sample(
        'after-edge',
        HealthMetric.hrv,
        now.add(const Duration(minutes: 5, microseconds: 1)),
      );
      final manual = _sample(
        'manual',
        HealthMetric.hrv,
        now.add(const Duration(days: 1)),
        origin: MeasurementOrigin.appMeasurement,
      );
      final imported = _sample(
        'imported',
        HealthMetric.hrv,
        now.add(const Duration(days: 1)),
        source: MeasurementSource.imported,
      );
      expect(isFutureWearableHistory(edge, receivedAt: now), isFalse);
      expect(isFutureWearableHistory(after, receivedAt: now), isTrue);
      await f.store.upsert([edge, after, manual, imported]);
      expect((await f.store.recent()).map((r) => r.id).toSet(), {
        'edge',
        'manual',
        'imported',
      });
    },
  );

  test(
    'existing queued and synced future rows are isolated before LIMIT or latest',
    () async {
      final now = DateTime.now().toUtc();
      final f = await _sqliteStore(() => now);
      final past = _sample(
        'past',
        HealthMetric.hrv,
        now.subtract(const Duration(minutes: 10)),
      );
      await _legacyInsert(f.database, past);
      for (var index = 0; index < 210; index++) {
        await _legacyInsert(
          f.database,
          _sample(
            'future-$index',
            HealthMetric.hrv,
            now.add(Duration(days: 1, minutes: index)),
          ),
          synced: index % 2,
        );
      }
      final other = _sample(
        'other-owner-future',
        HealthMetric.hrv,
        now.add(const Duration(days: 1)),
      );
      await _legacyInsert(f.database, other, owner: 'owner-b', synced: 1);
      expect((await f.store.recent(limit: 1)).single.id, 'past');
      expect((await f.store.latestForEachMetric()).single.id, 'past');
      expect((await f.store.pending()).single.id, 'past');
      final otherRaw = (await f.database.query(
        'health_records',
        where: 'owner_id = ?',
        whereArgs: ['owner-b'],
      )).single;
      expect(
        otherRaw['synced'],
        1,
        reason: 'Reading owner A must not mutate owner B',
      );
      await f.store.switchOwner('owner-b');
      expect(await f.store.recent(), isEmpty);
      expect(
        (await f.database.query(
          'health_records',
          where: 'owner_id = ?',
          whereArgs: ['owner-b'],
        )).single['synced'],
        -1,
      );
      expect((await f.database.query('health_records')).length, 212);
    },
  );

  test(
    'legacy future rows cannot reach upload even when cache was never loaded',
    () async {
      final now = DateTime.now().toUtc();
      final f = await _sqliteStore(() => now);
      final api = _AcceptingApi();
      for (final metric in [
        HealthMetric.hrv,
        HealthMetric.stress,
        HealthMetric.bodyTemperature,
        HealthMetric.bloodOxygen,
      ]) {
        await _legacyInsert(
          f.database,
          _sample(metric.name, metric, now.add(const Duration(hours: 7))),
        );
      }
      final past = _sample(
        'past',
        HealthMetric.hrv,
        now.subtract(const Duration(minutes: 10)),
      );
      await _legacyInsert(f.database, past);
      final result = await HealthSyncService(f.store, api).synchronizeNow();
      expect(api.received, {'past'});
      expect(result.uploaded, 1);
      expect(await f.store.pending(), isEmpty);
      expect((await f.database.query('health_records')).length, 5);
    },
  );

  test(
    'quarantine survives clock advance, cloud echo, late ack and restart',
    () async {
      var now = DateTime.now().toUtc();
      final f = await _sqliteStore(() => now);
      final future = _sample(
        'immutable-id',
        HealthMetric.hrv,
        now.add(const Duration(hours: 7)),
      );
      await f.store.upsert([future]);
      now = now.add(const Duration(days: 2));
      await f.store.upsertSynced([future]);
      await f.store.markSynced([future.id]);
      await f.store.upsert([future]);
      expect(await f.store.isHealthRecordQuarantined(future.id), isTrue);
      expect(await f.store.recent(), isEmpty);
      final row = (await f.database.query('health_records')).single;
      expect(row['synced'], -1);
      expect(row['payload'], future.encode());
      await f.store.close();
      await f.store.initialize();
      expect(await f.store.isHealthRecordQuarantined(future.id), isTrue);
      expect(await f.store.recent(), isEmpty);
      expect(await f.store.pending(), isEmpty);
    },
  );

  test(
    'arbitrary invalid past record cannot be revived by cloud echo or ack',
    () async {
      final now = DateTime.now().toUtc();
      final f = await _sqliteStore(() => now);
      final record = _sample(
        'invalid-past',
        HealthMetric.hrv,
        now.subtract(const Duration(minutes: 10)),
      );
      await f.store.upsert([record]);
      await f.store.markInvalid([record.id]);
      await f.store.upsertSynced([record]);
      await f.store.markSynced([record.id]);
      expect(await f.store.recent(), isEmpty);
      expect(
        (await f.database.query('health_records')).single['payload'],
        record.encode(),
      );
    },
  );

  test(
    'future cloud id conflict does not hide or overwrite a valid original',
    () async {
      final now = DateTime.now().toUtc();
      final f = await _sqliteStore(() => now);
      final past = _sample(
        'same-id',
        HealthMetric.hrv,
        now.subtract(const Duration(minutes: 10)),
      );
      final future = _sample(
        'same-id',
        HealthMetric.hrv,
        now.add(const Duration(days: 9)),
      );
      await f.store.upsert([past]);
      await f.store.upsertSynced([future]);
      expect((await f.store.recent()).single.encode(), past.encode());
      expect((await f.store.pending()).single.encode(), past.encode());
    },
  );

  test(
    'Memory store mirrors persistent quarantine and source boundaries',
    () async {
      var now = DateTime.now().toUtc();
      final store = MemoryHealthStore(clock: () => now);
      final future = _sample(
        'future',
        HealthMetric.hrv,
        now.add(const Duration(hours: 7)),
      );
      await store.upsertImmediate(future);
      now = now.add(const Duration(days: 2));
      await store.upsertSynced([future]);
      await store.markSynced([future.id]);
      expect(await store.recent(), isEmpty);
      expect(await store.pending(), isEmpty);
      await store.switchOwner('other');
      expect(await store.isHealthRecordQuarantined(future.id), isFalse);
      await store.upsert([future]);
      expect(
        (await store.recent()).single.id,
        'future',
        reason: 'Other owner receives an actual past sample independently',
      );
      await store.switchOwner('anonymous');
      expect(await store.recent(), isEmpty);
    },
  );

  test(
    'SyncService quarantines future rows from a legacy store adapter',
    () async {
      final now = DateTime.now().toUtc();
      final store = MemoryHealthStore(
        clock: () => now.add(const Duration(days: 20)),
      );
      final record = _sample(
        'legacy-future',
        HealthMetric.hrv,
        now.add(const Duration(days: 9)),
      );
      await store.upsert([record]);
      expect(await store.pending(), hasLength(1));
      final api = _AcceptingApi();
      final result = await HealthSyncService(store, api).synchronizeNow();
      expect(api.received, isEmpty);
      expect(result.rejected, 1);
      expect(await store.recent(), isEmpty);
    },
  );
}

class _AcceptingApi extends Fake implements SaydianApi {
  final received = <String>{};
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    final ids = batch.records.map((row) => row.id).toSet();
    received.addAll(ids);
    return BatchUploadResult(
      acceptedIds: ids,
      rejected: const {},
      nextCursor: null,
    );
  }
}
