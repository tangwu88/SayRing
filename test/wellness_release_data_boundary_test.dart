import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const policy = WellnessReleasePolicy(enabled: true);

HealthRecord record(
  String id,
  HealthMetric metric, {
  Map<String, num>? values,
}) => HealthRecord(
  id: id,
  metric: metric,
  values: values ?? {'value': metric == HealthMetric.sleep ? 7 : 72},
  unit: metric.defaultUnit,
  measuredAt: DateTime.utc(2026, 10, 3),
  timezone: '+08:00',
  deviceId: 'qring:synthetic',
  firmwareVersion: 'test',
  quality: 'unknown',
  source: MeasurementSource.wearable,
  rawVersion: 2,
);

class RecordingApi extends Fake implements SaydianApi {
  final List<HealthRecord> uploaded = [];
  Completer<void>? started;
  Completer<BatchUploadResult>? delayed;
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    uploaded.addAll(batch.records);
    started?.complete();
    return delayed?.future ??
        BatchUploadResult(
          acceptedIds: batch.records.map((record) => record.id).toSet(),
          rejected: const {},
          nextCursor: 'synthetic-cursor',
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'enabled policy rejects all physiological metrics and unknown wire types',
    () {
      for (final metric in HealthMetric.values) {
        expect(
          policy.allowsMetric(metric),
          WellnessReleasePolicy.activitySleepMetrics.contains(metric),
        );
        expect(
          policy.projectRecord(record(metric.name, metric)) != null,
          WellnessReleasePolicy.activitySleepMetrics.contains(metric),
        );
      }
      expect(policy.allowsWireMetric('future_medical_measurement'), isFalse);
      expect(policy.allowsWireMetric('temperature'), isFalse);
      expect(policy.allowsFeature(DeviceFeature.healthMonitoring), isFalse);
      expect(policy.allowsFeature(DeviceFeature.healthAssessment), isFalse);
      expect(policy.allowsFeature(DeviceFeature.camera), isTrue);
      expect(policy.allowsFeature(DeviceFeature.gestureControl), isTrue);
    },
  );

  test(
    'sleep projection strips score and physiology without mutating snapshot',
    () {
      final timeline = SleepTimeline(
        deviceId: 'qring:synthetic',
        sdkDate: '2026-10-03',
        timezone: '+08:00',
        readAt: DateTime.utc(2026, 10, 3, 5),
        sessions: const [],
        revision: 3,
        rawSummary: const {
          'deepSeconds': 7200,
          'lightSeconds': 18000,
          'score': 88,
          'meanHeartRate': 65,
        },
      );
      final original = record(
        'sleep',
        HealthMetric.sleep,
        values: {
          'value': 7,
          'deepHours': 2,
          'lightHours': 5,
          'score': 88,
          'meanHeartRate': 65,
          'efficiency': 90,
        },
      ).copyWith(sleepTimeline: timeline, samples: const [70, 72]);
      final snapshot = original.encode();
      final projected = policy.projectRecord(original)!;
      expect(projected.values, {'value': 7, 'deepHours': 2, 'lightHours': 5});
      expect(projected.samples, isEmpty);
      expect(projected.sleepTimeline!.rawSummary, {
        'deepSeconds': 7200,
        'lightSeconds': 18000,
      });
      expect(projected.sleepTimeline!.revision, 3);
      expect(original.encode(), snapshot);
    },
  );

  test('activity and sport projections remove hidden physiological fields', () {
    final activity = record(
      'steps',
      HealthMetric.steps,
      values: {'value': 800, 'heartRate': 75, 'score': 99},
    );
    expect(policy.projectRecord(activity)!.values, {'value': 800});
    final sport = SportRecord(
      id: 'sport',
      mode: SportMode.walking,
      startedAt: DateTime.utc(2026),
      durationSeconds: 60,
      distanceKm: 0.1,
      calories: 8,
      steps: 100,
      heartRate: 75,
      minimumHeartRate: 60,
      maximumHeartRate: 90,
      heartRateSamples: const [
        SportHeartRateSample(elapsedSeconds: 1, bpm: 75),
      ],
    );
    final projected = policy.projectSport(sport);
    expect(projected.steps, 100);
    expect(projected.heartRate, 0);
    expect(projected.minimumHeartRate, 0);
    expect(projected.maximumHeartRate, 0);
    expect(projected.heartRateSamples, isEmpty);
    expect(sport.heartRate, 75);
    expect(
      policy.projectSportValues({
        'steps': 100,
        'heartRate': 75,
        'bloodPressure': 110,
      }),
      {'steps': 100},
    );
  });

  test('disabled policy preserves Android records and feature behavior', () {
    const unrestricted = WellnessReleasePolicy();
    final original = record('heart', HealthMetric.heartRate);
    expect(identical(unrestricted.projectRecord(original), original), isTrue);
    expect(unrestricted.allowedMetrics, isNull);
    expect(unrestricted.allowsFeature(DeviceFeature.healthMonitoring), isTrue);
  });

  for (final encrypted in [false, true]) {
    test(
      '${encrypted ? 'SQL' : 'memory'} filters before LIMIT and preserves restricted pending by owner',
      () async {
        final HealthStore store;
        if (encrypted) {
          final directory = await Directory.systemTemp.createTemp(
            'sayring-policy-test-',
          );
          addTearDown(() => directory.delete(recursive: true));
          store = EncryptedHealthStore(
            MemorySessionVault(),
            databasePathProvider: () async =>
                path.join(directory.path, 'health.db'),
            databaseOpener:
                (
                  file, {
                  required password,
                  required version,
                  onConfigure,
                  onCreate,
                  onUpgrade,
                }) => databaseFactoryFfi.openDatabase(
                  file,
                  options: OpenDatabaseOptions(
                    version: version,
                    onConfigure: onConfigure,
                    onCreate: onCreate,
                    onUpgrade: onUpgrade,
                  ),
                ),
          );
        } else {
          store = MemoryHealthStore();
        }
        addTearDown(store.close);
        await store.initialize();
        await store.switchOwner('synthetic-a');
        final held = List.generate(
          25,
          (i) => record(
            'heart-$i',
            HealthMetric.heartRate,
            values: const {'value': 1},
          ),
        );
        final sleep = record(
          'sleep',
          HealthMetric.sleep,
          values: const {'value': 7, 'score': 81},
        );
        await store.upsert([
          ...held,
          sleep,
          record('steps', HealthMetric.steps),
        ]);
        final originalSleep = sleep.encode();
        final api = RecordingApi();
        final result = await HealthSyncService(
          store,
          api,
          policy: policy,
        ).synchronizeNow();
        expect(result.uploaded, 2);
        expect(result.rejected, 0);
        expect(
          api.uploaded.map((row) => row.id),
          unorderedEquals(['sleep', 'steps']),
        );
        expect(api.uploaded.firstWhere((row) => row.id == 'sleep').values, {
          'value': 7,
        });
        expect(
          (await store.pending()).map((row) => row.id),
          unorderedEquals(held.map((row) => row.id)),
        );
        expect(
          (await store.recent())
              .firstWhere((row) => row.id == 'sleep')
              .encode(),
          originalSleep,
        );
        expect(await store.recent(), hasLength(27));
        await store.switchOwner('synthetic-b');
        final filtered = store as MetricFilteredPendingHealthStore;
        expect(
          await filtered.pendingForMetrics(
            WellnessReleasePolicy.activitySleepMetrics,
          ),
          isEmpty,
        );
        await store.switchOwner('synthetic-a');
        expect(await store.pending(), hasLength(25));
        expect(
          (await HealthSyncService(
            store,
            api,
            policy: policy,
          ).synchronizeNow()).uploaded,
          0,
        );
      },
    );
  }

  test(
    'account switch during restricted-policy upload cannot acknowledge old rows',
    () async {
      final store = MemoryHealthStore();
      await store.switchOwner('a');
      await store.upsert([record('a-sleep', HealthMetric.sleep)]);
      final api = RecordingApi()
        ..started = Completer<void>()
        ..delayed = Completer<BatchUploadResult>();
      var current = true;
      final operation = HealthSyncService(
        store,
        api,
        policy: policy,
      ).synchronizeNow(isCurrent: () => current);
      await api.started!.future;
      current = false;
      await store.switchOwner('b');
      api.delayed!.complete(
        const BatchUploadResult(
          acceptedIds: {'a-sleep'},
          rejected: {},
          nextCursor: 'a-cursor',
        ),
      );
      await operation;
      expect(await store.readCursor(), isNull);
      expect(await store.pending(), isEmpty);
      await store.switchOwner('a');
      expect((await store.pending()).single.id, 'a-sleep');
      expect(await store.readCursor(), isNull);
    },
  );

  test(
    'global API rejects physiological metrics and strips extra fields before HTTP',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = <http.Request>[];
      final api = GlobalSaydianApiClient(
        MemorySessionVault()
          ..session = Session(
            accessToken: 'synthetic',
            refreshToken: '',
            expiresAt: DateTime.utc(2099),
            memberId: 'test',
            displayName: 'Synthetic',
            accountKey: 'global:member:test',
          ),
        healthReleasePolicy: policy,
        client: MockClient((request) async {
          calls.add(request);
          final rows = (jsonDecode(request.body) as Map)['records'] as List;
          expect(rows, hasLength(1));
          expect(rows.single['metric'], 'sleep');
          expect(rows.single['values'], {'value': 7});
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {
                'acceptedIds': ['sleep'],
                'rejected': [],
                'nextCursor': null,
              },
            }),
            200,
          );
        }),
      );
      final heartOnly = await api.uploadHealthBatch(
        SyncBatch(
          cursor: null,
          records: [record('heart', HealthMetric.heartRate)],
        ),
      );
      expect(calls, isEmpty);
      expect(heartOnly.acceptedIds, isEmpty);
      expect(heartOnly.rejected, contains('heart'));
      final mixed = await api.uploadHealthBatch(
        SyncBatch(
          cursor: null,
          records: [
            record('heart', HealthMetric.heartRate),
            record(
              'sleep',
              HealthMetric.sleep,
              values: {'value': 7, 'score': 88, 'heartRate': 70},
            ),
          ],
        ),
      );
      expect(calls, hasLength(1));
      expect(mixed.acceptedIds, {'sleep'});
      expect(mixed.rejected, contains('heart'));
    },
  );
}
