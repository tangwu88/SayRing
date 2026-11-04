import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/health_cloud_upload_policy.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/sync_service.dart';

const uploadPolicy = HealthCloudUploadPolicy();
const readPolicy = WellnessReleasePolicy(enabled: true);

HealthRecord _row(
  String id,
  HealthMetric metric,
  Map<String, num> values, {
  DateTime? at,
}) => HealthRecord(
  id: id,
  metric: metric,
  values: values,
  unit: metric.defaultUnit,
  measuredAt: at ?? DateTime.utc(2026, 11, 1, 3),
  timezone: '+08:00',
  deviceId: 'coolwear:synthetic-ring',
  firmwareVersion: 'synthetic-firmware',
  quality: 'device_reported',
  source: MeasurementSource.wearable,
  origin: MeasurementOrigin.watchHistory,
  rawVersion: 2,
  sourceVendor: 'coolwear',
);

List<HealthRecord> _physiology() => [
  _row('pressure', HealthMetric.bloodPressure, {
    'systolic': 118,
    'diastolic': 76,
  }),
  _row('heart', HealthMetric.heartRate, {'value': 72}),
  _row('oxygen', HealthMetric.bloodOxygen, {'value': 97}),
  _row('temperature', HealthMetric.bodyTemperature, {
    'value': 33.5,
    'skinTemperature': 33.5,
  }),
  _row('hrv', HealthMetric.hrv, {
    'value': 42,
    'sdnn': 42,
    'sdkQuality': 3,
    'validCount': 30,
  }),
];

Session _session([String owner = 'a']) => Session(
  accessToken: 'synthetic-$owner',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: owner,
  displayName: 'Synthetic',
  accountKey: 'global:member:$owner',
);

http.Response _ok(Object data) => http.Response(
  jsonEncode({'code': 200, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

GlobalSaydianApiClient _api(SessionVault vault, http.Client client) =>
    GlobalSaydianApiClient(
      vault,
      client: client,
      healthReleasePolicy: readPolicy,
      healthUploadPolicyOverride: uploadPolicy,
      healthReadPolicyOverride: readPolicy,
    );

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'upload ceiling remains independent from iOS display and manual leases',
    () {
      expect(uploadPolicy.allowedMetrics, {
        ...WellnessReleasePolicy.activitySleepMetrics,
        ...HealthCloudUploadPolicy.physiologicalMetrics,
      });
      for (final row in _physiology()) {
        expect(uploadPolicy.projectRecord(row)?.toJson(), row.toJson());
        expect(readPolicy.allowsMetric(row.metric), isFalse);
        expect(readPolicy.allowsManualMeasurement(row.metric), isFalse);
      }
      for (final metric in [
        HealthMetric.ecg,
        HealthMetric.stress,
        HealthMetric.bodyComposition,
        HealthMetric.bloodComposition,
      ]) {
        expect(
          uploadPolicy.projectRecord(_row('held', metric, {'value': 1})),
          isNull,
        );
      }
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test(
      '$platform sends original physiological values and confirmed IDs only',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final rows = _physiology();
        final originals = rows.map((row) => row.encode()).toList();
        final requests = <http.Request>[];
        final api = _api(
          MemorySessionVault()..session = _session(),
          MockClient((request) async {
            requests.add(request);
            final wire = (jsonDecode(request.body) as Map)['records'] as List;
            for (var i = 0; i < rows.length; i++) {
              expect(wire[i]['values'], rows[i].values);
              expect(wire[i]['unit'], rows[i].unit);
              expect(
                wire[i]['observedAt'],
                rows[i].measuredAt.toIso8601String(),
              );
              expect(wire[i]['timezoneOffsetMinutes'], 480);
              expect(wire[i]['quality'], 'unknown');
              expect(wire[i]['source']['origin'], 'watch_history');
              expect(
                wire[i]['source']['platform'],
                platform == TargetPlatform.iOS ? 'ios' : 'android',
              );
            }
            expect(wire[3]['metric'], 'temperature');
            return _ok({
              'acceptedIds': rows.map((row) => row.id).toList(),
              'rejected': [],
              'nextCursor': null,
            });
          }),
        );
        final batch = SyncBatch(cursor: null, records: rows);
        expect(
          (await api.uploadHealthBatch(batch)).acceptedIds,
          rows.map((row) => row.id).toSet(),
        );
        await api.uploadHealthBatch(batch);
        expect(
          requests.first.url.toString(),
          'https://app.saydian.cn/global/api/saydian-app/v2/health/records/batch',
        );
        expect(
          requests.first.headers['idempotency-key'],
          requests.last.headers['idempotency-key'],
        );
        expect(rows.map((row) => row.encode()), originals);
      },
    );
  }

  test(
    'old pending physiology drains without losing local payload or owner isolation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final store = MemoryHealthStore();
      await store.switchOwner('owner-a');
      final original = _physiology();
      await store.upsert(original);
      final sent = <String>[];
      final api = _api(
        MemorySessionVault()..session = _session(),
        MockClient((request) async {
          final rows = (jsonDecode(request.body) as Map)['records'] as List;
          final ids = rows.map((row) => row['id'] as String).toList();
          sent.addAll(ids);
          return _ok({'acceptedIds': ids, 'rejected': [], 'nextCursor': null});
        }),
      );
      final service = HealthSyncService(store, api, policy: uploadPolicy);
      expect((await service.synchronizeNow()).uploaded, 5);
      expect((await service.synchronizeNow()).uploaded, 0);
      expect(sent, unorderedEquals(original.map((row) => row.id)));
      expect(await store.pending(), isEmpty);
      final saved = {
        for (final row in await store.recent()) row.id: row.encode(),
      };
      for (final row in original) {
        expect(saved[row.id], row.encode());
      }
      await store.switchOwner('owner-b');
      expect(await store.recent(), isEmpty);
      expect((await service.synchronizeNow()).uploaded, 0);
    },
  );

  test('partial acknowledgements leave unconfirmed rows pending', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final store = MemoryHealthStore();
    await store.switchOwner('owner-a');
    await store.upsert(_physiology());
    var calls = 0;
    final api = _api(
      MemorySessionVault()..session = _session(),
      MockClient((_) async {
        calls++;
        return _ok({
          'acceptedIds': calls == 1 ? ['heart'] : [],
          'rejected': [],
          'nextCursor': null,
        });
      }),
    );
    final result = await HealthSyncService(
      store,
      api,
      policy: uploadPolicy,
    ).synchronizeNow();
    expect(result.uploaded, 1);
    expect(
      (await store.pending()).map((row) => row.id),
      unorderedEquals(['pressure', 'oxygen', 'temperature', 'hrv']),
    );
    expect(await store.recent(), hasLength(5));
  });

  test(
    'invalid and future physiology cannot bypass validation through direct API calls',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var calls = 0;
      final api = _api(
        MemorySessionVault()..session = _session(),
        MockClient((_) async {
          calls++;
          throw StateError('Invalid records must never reach HTTP');
        }),
      );
      final invalid = [
        _row('sentinel-heart', HealthMetric.heartRate, {'value': 1}),
        _row('bad-pressure', HealthMetric.bloodPressure, {
          'systolic': 70,
          'diastolic': 110,
        }),
        _row('incomplete-hrv', HealthMetric.hrv, {'value': 42}),
        _row(
          'future',
          HealthMetric.heartRate,
          {'value': 72},
          at: DateTime.now().toUtc().add(const Duration(days: 1)),
        ),
        _row('remote', HealthMetric.heartRate, {
          'value': 72,
        }).copyWith(origin: MeasurementOrigin.remoteMember),
        _row('waveform', HealthMetric.heartRate, {
          'value': 72,
        }).copyWith(samples: [1, 2]),
      ];
      final result = await api.uploadHealthBatch(
        SyncBatch(cursor: null, records: invalid),
      );
      expect(result.acceptedIds, isEmpty);
      expect(result.rejected, hasLength(invalid.length));
      expect(calls, 0);
    },
  );

  test(
    'guest cannot send physiology and owner switch rejects delayed upload ACK',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final vault = MemorySessionVault();
      final started = Completer<void>();
      final response = Completer<http.Response>();
      var calls = 0;
      final api = _api(
        vault,
        MockClient((_) async {
          calls++;
          started.complete();
          return response.future;
        }),
      );
      final batch = SyncBatch(cursor: null, records: _physiology());
      await expectLater(
        api.uploadHealthBatch(batch),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 0);
      vault.session = _session('a');
      final operation = api.uploadHealthBatch(batch);
      await started.future;
      vault.session = _session('b');
      response.complete(
        _ok({
          'acceptedIds': ['heart'],
          'rejected': [],
          'nextCursor': null,
        }),
      );
      await expectLater(
        operation,
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'STALE_HEALTH_SESSION',
          ),
        ),
      );
    },
  );
}
