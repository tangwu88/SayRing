import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/read_only_health_features.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/domain/wearable_sync_result.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';
import 'package:saydian_app/services/secure_vault.dart';

const _metrics = {
  HealthMetric.heartRate,
  HealthMetric.hrv,
  HealthMetric.bloodOxygen,
};
http.Response _page() => http.Response(
  jsonEncode({
    'code': 200,
    'data': {
      'items': [
        {
          'id': 'synthetic-cloud',
          'metric': 'heart_rate',
          'observedAt': '2026-10-18T01:00:00Z',
          'timezoneOffsetMinutes': 480,
          'values': {'value': 70},
          'unit': 'bpm',
          'quality': 'unknown',
          'source': {
            'platform': 'ios',
            'measurementSource': 'wearable',
            'origin': 'watch_history',
            'vendor': 'qring',
            'deviceCategory': 'ring',
            'deviceId': 'synthetic-ring',
            'sourceApp': 'say-ring',
            'rawVersion': 1,
          },
        },
      ],
      'nextCursor': null,
    },
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'read flags do not expand physiological uploads and filter cloud reads',
    () async {
      final features = ReadOnlyHealthFeatures()
        ..replace(_metrics, const Duration(minutes: 5));
      final policy = WellnessReleasePolicy(
        enabled: true,
        readOnlyFeatures: features,
      );
      var reads = 0;
      final api = GlobalSaydianApiClient(
        MemorySessionVault()
          ..session = Session(
            accessToken: 'synthetic-only',
            refreshToken: '',
            expiresAt: DateTime.utc(2099),
            memberId: 'synthetic-owner',
            displayName: 'QA',
            accountKey: 'synthetic-owner',
          ),
        healthReleasePolicy: const WellnessReleasePolicy(enabled: true),
        healthReadPolicyOverride: policy,
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.queryParameters['product'], 'say-ring');
          expect(request.url.queryParameters['platform'], 'ios');
          reads++;
          return _page();
        }),
      );
      final page = await api.getCloudHealthRecords();
      expect(page.records.single.metric, HealthMetric.heartRate);
      expect(page.records.single.sourceVendor, 'qring');
      final upload = await api.uploadHealthBatch(
        SyncBatch(cursor: null, records: page.records),
      );
      expect(upload.acceptedIds, isEmpty);
      expect(upload.rejected.length, 1);
      expect(reads, 1);
      features.close();
      expect((await api.getCloudHealthRecords()).records, isEmpty);
    },
  );

  test(
    'cloud response cannot cross a feature close/reopen generation',
    () async {
      final features = ReadOnlyHealthFeatures()
        ..replace(_metrics, const Duration(minutes: 5));
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final api = GlobalSaydianApiClient(
        MemorySessionVault()
          ..session = Session(
            accessToken: 'synthetic-only',
            refreshToken: '',
            expiresAt: DateTime.utc(2099),
            memberId: 'synthetic-owner',
            displayName: 'QA',
            accountKey: 'synthetic-owner',
          ),
        healthReadPolicyOverride: WellnessReleasePolicy(
          enabled: true,
          readOnlyFeatures: features,
        ),
        client: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      final pending = api.getCloudHealthRecords();
      final rejected = expectLater(
        pending,
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'HEALTH_POLICY_CHANGED',
          ),
        ),
      );
      await started.future;
      features.close();
      features.replace(_metrics, const Duration(minutes: 5));
      response.complete(_page());
      await rejected;
    },
  );

  test(
    'QRing supports strict leases and both old and per-metric sync formats',
    () async {
      const channel = MethodChannel('synthetic-read-only-qring');
      final features = ReadOnlyHealthFeatures()
        ..replace(_metrics, const Duration(minutes: 5));
      final policy = WellnessReleasePolicy(
        enabled: true,
        readOnlyFeatures: features,
      );
      final calls = <MethodCall>[];
      var legacy = false;
      final record = HealthRecord(
        id: 'synthetic-native',
        metric: HealthMetric.heartRate,
        values: const {'value': 70},
        unit: 'bpm',
        measuredAt: DateTime.utc(2026, 10, 18, 1),
        timezone: '+08:00',
        deviceId: 'qring:SYNTHETIC',
        firmwareVersion: 'synthetic',
        quality: 'unknown',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'configureReadOnlyHealthMetrics') return null;
            final rows = [record.toJson()];
            return legacy
                ? rows
                : {
                    'records': rows,
                    'statuses': {
                      'heart_rate': 'complete',
                      'blood_pressure': 'partial',
                    },
                  };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final bridge = QRingWearableBridge(
        methods: channel,
        healthReleasePolicy: policy,
      );
      await bridge.configureReadOnlyHealthMetrics(
        _metrics,
        validity: const Duration(minutes: 5),
      );
      expect((calls.single.arguments as Map)['validForSeconds'], 300);
      final current = await bridge.syncHealthData();
      expect(current.single.metric, HealthMetric.heartRate);
      expect((current as WearableSyncResult).statuses, {
        'heart_rate': 'complete',
      });
      legacy = true;
      expect((await bridge.syncHealthData()).length, 1);
      features.close();
      expect(await bridge.syncHealthData(), isEmpty);
    },
  );
}
