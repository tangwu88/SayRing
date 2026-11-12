import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:saydian_app/domain/health_cloud_upload_policy.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

Session _session() => Session(
  accessToken: 'synthetic-only',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: 'synthetic-member',
  displayName: 'Synthetic',
  accountKey: 'global:synthetic-member',
);

HealthRecord _record(int index, HealthMetric metric) => HealthRecord(
  id: 'synthetic-$index',
  metric: metric,
  values: {'value': metric == HealthMetric.bloodOxygen ? 98 : 74},
  unit: metric.defaultUnit,
  measuredAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
  timezone: '+00:00',
  deviceId: 'coolwear:synthetic-r7-pro',
  firmwareVersion: 'synthetic',
  quality: 'device_reported',
  source: MeasurementSource.wearable,
  sourceVendor: 'coolwear',
  rawVersion: 2,
);

class _Bridge extends Fake implements WearableBridge {}

class _Server extends Fake implements SaydianApi {
  final received = <String>{};
  final receivedRecords = <String, HealthRecord>{};
  bool offline = false;
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    if (offline) throw const ApiException('Synthetic offline', statusCode: 503);
    received.addAll(batch.records.map((r) => r.id));
    receivedRecords.addAll({for (final r in batch.records) r.id: r});
    return BatchUploadResult(
      acceptedIds: {
        for (final r in batch.records)
          if (const HealthCloudUploadPolicy().allowsMetric(r.metric)) r.id,
      },
      rejected: {
        for (final r in batch.records)
          if (!const HealthCloudUploadPolicy().allowsMetric(r.metric))
            r.id: 'unsupported_metric',
      },
      nextCursor: null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'Android controller and HTTP retry preserve legacy sleep payload exactly',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final oldSleep = _record(30, HealthMetric.sleep).copyWith(
        values: const {'value': 7.25, 'deepHours': 1.5, 'movementMinutes': 12},
      );
      final store = MemoryHealthStore();
      await store.initialize();
      await store.upsert([
        for (var i = 0; i < 30; i++) _record(i, HealthMetric.stress),
        oldSleep,
      ]);
      final server = _Server();
      final controller = AppController(
        MemorySessionVault(),
        server,
        store,
        _Bridge(),
      )..session = _session();
      addTearDown(controller.dispose);
      await controller.synchronizeCloud();
      expect(server.receivedRecords[oldSleep.id]?.encode(), oldSleep.encode());
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _session(),
        client: MockClient((request) async {
          final row =
              ((jsonDecode(request.body) as Map)['records'] as List).single
                  as Map;
          expect(row['values'], oldSleep.values);
          expect(row['observedAt'], oldSleep.measuredAt.toIso8601String());
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {
                'acceptedIds': [oldSleep.id],
                'rejected': [],
                'nextCursor': null,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      expect(
        (await api.uploadHealthBatch(
          SyncBatch(cursor: null, records: [oldSleep]),
        )).acceptedIds,
        {oldSleep.id},
      );
    },
  );

  test('guest records remain local without an upload', () async {
    final store = MemoryHealthStore();
    await store.initialize();
    await store.upsert([_record(0, HealthMetric.heartRate)]);
    final server = _Server();
    final controller = AppController(
      MemorySessionVault(),
      server,
      store,
      _Bridge(),
    );
    addTearDown(controller.dispose);
    await controller.synchronizeCloud();
    expect(server.received, isEmpty);
    expect(await store.pending(), hasLength(1));
  });

  test(
    'failed upload preserves the queue and later retries only eligible records',
    () async {
      final store = MemoryHealthStore();
      await store.initialize();
      await store.upsert([
        for (var i = 0; i < 30; i++) _record(i, HealthMetric.stress),
        _record(30, HealthMetric.heartRate),
      ]);
      final server = _Server()..offline = true;
      final controller = AppController(
        MemorySessionVault(),
        server,
        store,
        _Bridge(),
      )..session = _session();
      addTearDown(controller.dispose);
      await controller.synchronizeCloud();
      expect(await store.pending(), hasLength(31));
      server.offline = false;
      await controller.synchronizeCloud();
      expect(server.received, {'synthetic-30'});
      expect(await store.pending(), hasLength(30));
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform controller drains supported data behind old stress rows',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final store = MemoryHealthStore();
        await store.initialize();
        final held = [
          for (var i = 0; i < 30; i++) _record(i, HealthMetric.stress),
        ];
        final valid = [
          _record(30, HealthMetric.heartRate),
          _record(31, HealthMetric.bloodOxygen),
        ];
        await store.upsert([...held, ...valid]);
        final before = {
          for (final row in await store.recent()) row.id: row.encode(),
        };
        final server = _Server();
        final controller = AppController(
          MemorySessionVault()..session = _session(),
          server,
          store,
          _Bridge(),
          wellnessOnly: platform == TargetPlatform.iOS,
        )..session = _session();
        addTearDown(controller.dispose);
        await controller.synchronizeCloud();
        await controller.synchronizeCloud();
        expect(server.received, valid.map((r) => r.id).toSet());
        expect(
          (await store.pending()).map((r) => r.id).toSet(),
          held.map((r) => r.id).toSet(),
        );
        expect({
          for (final row in await store.recent()) row.id: row.encode(),
        }, before);
        // Switching the account cannot expose or upload another owner's queue.
        await store.switchOwner('synthetic-other-owner');
        expect(await store.pending(), isEmpty);
      },
    );

    test(
      '$platform global API default keeps unsupported records off the wire',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        var calls = 0;
        final api = GlobalSaydianApiClient(
          MemorySessionVault()..session = _session(),
          client: MockClient((request) async {
            calls++;
            final records =
                (jsonDecode(request.body) as Map)['records'] as List;
            expect(records.map((r) => r['metric']), ['heart_rate']);
            return http.Response(
              jsonEncode({
                'code': 200,
                'data': {
                  'acceptedIds': ['synthetic-30'],
                  'rejected': [],
                  'nextCursor': null,
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final response = await api.uploadHealthBatch(
          SyncBatch(
            cursor: null,
            records: [
              _record(0, HealthMetric.stress),
              _record(30, HealthMetric.heartRate),
            ],
          ),
        );
        expect(response.acceptedIds, {'synthetic-30'});
        expect(response.rejected.keys, ['synthetic-0']);
        expect(calls, 1);
      },
    );
  }
}
