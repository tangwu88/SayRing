import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/notification_route_service.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

// Synthetic records only; these tests validate product boundaries, not sensors.
HealthRecord _record(String id, HealthMetric metric) => HealthRecord(
  id: id,
  metric: metric,
  values: metric == HealthMetric.sleep
      ? const {'value': 7, 'deepHours': 2, 'lightHours': 5, 'score': 91}
      : const {'value': 72},
  unit: metric.defaultUnit,
  measuredAt: DateTime.utc(2026, 10, 1),
  timezone: '+08:00',
  deviceId: _Wearable.device.id,
  firmwareVersion: 'synthetic',
  quality: 'device_reported',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);

Future<void> _settle() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Api extends Fake
    implements SaydianApi, GlobalCareApi, GlobalCareRangeApi {
  int careReads = 0;
  @override
  Future<Session> login(String username, String password) async => Session(
    accessToken: 'synthetic-token',
    refreshToken: 'synthetic-refresh',
    expiresAt: DateTime.utc(2030),
    memberId: username,
    displayName: 'Synthetic',
  );
  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => const [];
  @override
  Future<Map<String, Object?>> getMemberProfile() async => const {};
  @override
  Future<Map<String, Object?>> getActivityGoals() async => const {};
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];
  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      const [];
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async =>
      BatchUploadResult(
        nextCursor: null,
        acceptedIds: batch.records.map((record) => record.id).toSet(),
        rejected: const {},
      );
  @override
  Future<List<Map<String, Object?>>> globalCareRecords(
    String id,
    String metric,
    DateTime day,
  ) async {
    careReads++;
    return const [];
  }

  @override
  Future<List<Map<String, Object?>>> globalCareRecordsRange(
    String id,
    String metric,
    DateTime start,
    DateTime end,
  ) async {
    careReads++;
    return const [];
  }
}

class _Wearable extends Fake implements WearableBridge {
  static const device = DeviceInfo(id: 'qring:SYNTHETIC', name: 'R21_TEST');
  final emitter = StreamController<WearableEvent>.broadcast();
  final calls = <String>[];
  @override
  Stream<WearableEvent> get events => emitter.stream;
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(
        metrics: {
          HealthMetric.steps,
          HealthMetric.heartRate,
          HealthMetric.sleep,
        },
        manualMetrics: {HealthMetric.heartRate},
        features: {
          DeviceFeature.healthMonitoring,
          DeviceFeature.healthReminders,
        },
        integratedFeatures: {
          DeviceFeature.healthMonitoring,
          DeviceFeature.healthReminders,
        },
        supportsHistorySync: false,
      );
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];
  @override
  Future<void> startMeasurement(HealthMetric metric) async =>
      calls.add('measure');
  @override
  Future<void> stopMeasurement(HealthMetric metric) async => calls.add('stop');
  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async {
    calls.add('readMonitoring');
    return const {};
  }

  @override
  Future<int?> readHeartRateWarning() async {
    calls.add('readWarning');
    return null;
  }

  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) async =>
      calls.add('writeMonitoring');
  @override
  Future<void> setHeartRateWarning(int value) async =>
      calls.add('writeWarning');
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    calls.add('readFeature');
    return const {};
  }

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({
      AppController controller,
      MemoryHealthStore store,
      _Wearable ring,
      _Api api,
    })
  >
  setup({bool wellness = true, bool connect = false}) async {
    final store = MemoryHealthStore();
    final ring = _Wearable();
    final api = _Api();
    final controller = AppController(
      MemorySessionVault(),
      api,
      store,
      ring,
      wellnessOnly: wellness,
      allowAutomaticWearableRestore: false,
    );
    addTearDown(controller.dispose);
    addTearDown(ring.emitter.close);
    await controller.initialize();
    expect(
      await controller.login('synthetic-owner', 'synthetic-password'),
      isTrue,
    );
    if (connect) {
      await controller.connectDevice(_Wearable.device);
      await _settle();
      expect(controller.connectedDevice?.id, _Wearable.device.id);
    }
    return (controller: controller, store: store, ring: ring, api: api);
  }

  test(
    'old physiology is inaccessible without deleting stored history',
    () async {
      final fixture = await setup();
      final old = _record('old-heart', HealthMetric.heartRate);
      final steps = _record('old-steps', HealthMetric.steps);
      await fixture.store.upsert([old, steps]);
      fixture.controller.healthRecords = [old, steps];
      expect(
        fixture.controller.shouldShowHealthMetric(HealthMetric.heartRate),
        isFalse,
      );
      expect(fixture.controller.latestByMetric.keys, [HealthMetric.steps]);
      expect(
        await fixture.controller.loadHealthRecords(
          metric: HealthMetric.heartRate,
          start: DateTime.utc(2026),
          end: DateTime.utc(2027),
        ),
        isEmpty,
      );
      expect(
        (await fixture.store.recent()).map((record) => record.id),
        containsAll(['old-heart', 'old-steps']),
      );
      expect(
        await fixture.controller.loadHealthRecords(
          metric: HealthMetric.steps,
          start: DateTime.utc(2026),
          end: DateTime.utc(2027),
        ),
        hasLength(1),
      );
    },
  );

  test('direct measurement and health settings never call SDK', () async {
    final fixture = await setup(connect: true);
    fixture.ring.calls.clear();
    expect(
      await fixture.controller.startMeasurement(HealthMetric.heartRate),
      isFalse,
    );
    await fixture.controller.refreshDeviceSettings();
    await expectLater(
      fixture.controller.setAutoMeasureSetting('heartRate', true),
      throwsA(isA<FeatureNotConfiguredException>()),
    );
    await expectLater(
      fixture.controller.setHeartRateWarning(130),
      throwsA(isA<FeatureNotConfiguredException>()),
    );
    expect(
      await fixture.controller.readDeviceFeature(
        DeviceFeature.healthMonitoring,
      ),
      isEmpty,
    );
    expect(fixture.controller.visibleDeviceFeatures, isEmpty);
    expect(
      fixture.controller.canMeasureHealthMetric(HealthMetric.heartRate),
      isFalse,
    );
    expect(fixture.ring.calls, isEmpty);
  });

  test('warning notification route is consumed without opening it', () async {
    final fixture = await setup();
    fixture.controller.pendingNotificationRoute = const NotificationRouteIntent(
      target: NotificationRouteTarget.healthWarningHistory,
      eventId: 'synthetic-warning',
    );
    expect(fixture.controller.consumePendingNotificationRoute(), isNull);
    expect(fixture.controller.pendingNotificationRoute, isNull);
    expect(fixture.controller.healthAlertsAvailable, isFalse);
    fixture.controller.pendingNotificationRoute = const NotificationRouteIntent(
      target: NotificationRouteTarget.notificationInbox,
      eventId: 'synthetic-system',
    );
    expect(
      fixture.controller.consumePendingNotificationRoute()?.target,
      NotificationRouteTarget.notificationInbox,
    );
  });

  test(
    'type-based health events save activity and reject HR and unknown types',
    () async {
      final fixture = await setup(connect: true);
      final activity = _record('new-steps', HealthMetric.steps);
      final heart = _record('new-heart', HealthMetric.heartRate);
      fixture.ring.emitter.add(
        WearableEvent(type: 'healthRecord', payload: activity.toJson()),
      );
      fixture.ring.emitter.add(
        WearableEvent(type: 'healthRecord', payload: heart.toJson()),
      );
      fixture.ring.emitter.add(
        WearableEvent(
          type: 'healthRecord',
          payload: {
            ...activity.toJson(),
            'id': 'unknown',
            'type': 'unknown_sensor',
          },
        ),
      );
      await _settle();
      expect((await fixture.store.recent()).map((record) => record.id), [
        'new-steps',
      ]);
      expect(fixture.controller.latestByMetric.keys, [HealthMetric.steps]);
    },
  );

  test(
    'sleep projections omit score while raw legacy store retains it',
    () async {
      final fixture = await setup();
      await fixture.store.upsert([_record('old-sleep', HealthMetric.sleep)]);
      final latest = await fixture.controller.loadLatestSleepDay();
      expect(latest?.values['value'], 7);
      expect(latest?.values.containsKey('score'), isFalse);
      final rows = await fixture.controller.loadSleepDays(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 1),
      );
      expect(rows.single.values.containsKey('score'), isFalse);
      expect((await fixture.store.recent()).single.values['score'], 91);
      expect(fixture.controller.sleepAiEnabled, isFalse);
      expect(fixture.controller.hideAiContent, isTrue);
    },
  );

  test(
    'restricted care requests stop before API but activity still loads',
    () async {
      final fixture = await setup();
      final day = DateTime(2026, 10, 1);
      expect(
        await fixture.controller.globalCareRecords(
          'synthetic',
          'heart_rate',
          day,
        ),
        isEmpty,
      );
      expect(
        await fixture.controller.globalCareRecordsRange(
          'synthetic',
          'ecg',
          day,
          day,
        ),
        isEmpty,
      );
      expect(
        await fixture.controller.globalCareRecords(
          'synthetic',
          'unknown_sensor',
          day,
        ),
        isEmpty,
      );
      expect(fixture.api.careReads, 0);
      await fixture.controller.globalCareRecords('synthetic', 'steps', day);
      await fixture.controller.globalCareRecordsRange(
        'synthetic',
        'sleep',
        day,
        day,
      );
      expect(fixture.api.careReads, 2);
    },
  );

  test(
    'non-wellness release keeps historical physiology and SDK measurements',
    () async {
      final fixture = await setup(wellness: false, connect: true);
      final heart = _record('android-heart', HealthMetric.heartRate);
      fixture.ring.emitter.add(
        WearableEvent(type: 'healthRecord', payload: heart.toJson()),
      );
      await _settle();
      expect((await fixture.store.recent()).single.id, 'android-heart');
      expect(
        fixture.controller.shouldShowHealthMetric(HealthMetric.heartRate),
        isTrue,
      );
      expect(
        await fixture.controller.startMeasurement(HealthMetric.heartRate),
        isTrue,
      );
      expect(fixture.ring.calls, contains('measure'));
      await fixture.controller.stopMeasurement(HealthMetric.heartRate);
      expect(fixture.controller.healthAlertsAvailable, isTrue);
    },
  );
}
