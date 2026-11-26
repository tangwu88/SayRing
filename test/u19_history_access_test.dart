import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/read_only_health_features.dart';
import 'package:saydian_app/domain/u19_health_features.dart';
import 'package:saydian_app/domain/wearable_sync_result.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

const _watch = DeviceInfo(id: 'urion:fixture', name: 'U19M');
const _grant = U19HealthSnapshot(
  {
    HealthMetric.bloodPressure,
    HealthMetric.heartRate,
    HealthMetric.bloodOxygen,
  },
  {},
  Duration(minutes: 5),
);
const _ringGrant = ReadOnlyHealthFeatureSnapshot(
  metrics: {},
  validity: Duration(minutes: 5),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a pending ring configuration does not delay U19 authorization',
    () async {
      final ring = Completer<ReadOnlyHealthFeatureSnapshot>();
      final api = _Api(() async => _grant, readRing: () => ring.future);
      final (app, _, bridge) = _controller(api);
      addTearDown(app.dispose);
      try {
        final pending = app.refreshReadOnlyHealthFeatures();
        await pumpEventQueue();
        expect(app.healthReleasePolicy.u19Features!.active, isTrue);
        expect(bridge.eventsSeen, contains('U19 read scope granted'));
        ring.complete(_ringGrant);
        await pending;
      } finally {
        if (!ring.isCompleted) ring.complete(_ringGrant);
      }
    },
  );

  test(
    'offline U19 sync saves activity, then only a valid grant restores vital history',
    () async {
      var online = false;
      final (app, store, bridge) = _controller(
        _Api(() async {
          if (!online) throw const ApiException('Network unavailable');
          return _grant;
        }),
      );
      addTearDown(app.dispose);

      expect(await app.syncDeviceData(), isTrue);
      expect(app.syncStatus, '暂未取得手表健康数据读取权限，请联网后再次同步');
      expect(bridge.eventsSeen, ['U19 read scope closed', 'read history']);
      expect((await store.recent()).map((record) => record.metric), [
        HealthMetric.steps,
      ]);

      online = true;
      expect(await app.syncDeviceData(), isTrue);
      expect(app.u19HealthReadNotice, isNull);
      expect(bridge.eventsSeen.skip(2), [
        'U19 read scope granted',
        'detect capabilities',
        'read history',
      ]);
      expect((await store.recent()).map((record) => record.metric).toSet(), {
        HealthMetric.bloodPressure,
        HealthMetric.steps,
      });
    },
  );

  test(
    'manual U19 sync restores scope and capabilities before a single history read',
    () async {
      final reply = Completer<U19HealthSnapshot>();
      final (app, store, bridge) = _controller(_Api(() => reply.future));
      addTearDown(app.dispose);

      final pending = app.syncDeviceData();
      try {
        await pumpEventQueue();
        expect(app.isDeviceHistorySyncing, isTrue);
        expect(bridge.eventsSeen, isEmpty);
        expect(await app.syncDeviceData(), isFalse);
      } finally {
        reply.complete(_grant);
        await pending;
      }
      expect(await pending, isTrue);
      await pumpEventQueue();
      expect(bridge.eventsSeen, [
        'U19 read scope granted',
        'detect capabilities',
        'read history',
      ]);
      final saved = await store.recent();
      expect(saved.map((record) => record.metric).toSet(), {
        HealthMetric.steps,
        HealthMetric.bloodPressure,
      });
      final pressure = saved.singleWhere(
        (record) => record.metric == HealthMetric.bloodPressure,
      );
      expect(pressure.values, {'systolic': 118, 'diastolic': 76});
    },
  );

  test(
    'switching away during the scope request leaves history unread',
    () async {
      final reply = Completer<U19HealthSnapshot>();
      final (app, store, bridge) = _controller(_Api(() => reply.future));
      addTearDown(app.dispose);

      final pending = app.syncDeviceData();
      await pumpEventQueue();
      app.connectedDevice = null;
      reply.complete(_grant);

      expect(await pending, isFalse);
      expect(bridge.eventsSeen, isNot(contains('read history')));
      expect(await store.recent(), isEmpty);
    },
  );
}

(AppController, MemoryHealthStore, _Bridge) _controller(_Api api) {
  final store = MemoryHealthStore();
  final bridge = _Bridge();
  final app = AppController(
    MemorySessionVault(),
    api,
    store,
    bridge,
    wellnessOnly: true,
    healthReadPolicy: WellnessReleasePolicy(
      enabled: true,
      readOnlyFeatures: ReadOnlyHealthFeatures(),
      u19Features: U19HealthFeatures(),
    ),
  )..connectedDevice = _watch;
  return (app, store, bridge);
}

class _Api extends Fake
    implements SaydianApi, SayRingReadOnlyHealthApi, SayRingU19HealthApi {
  _Api(this.readWatch, {this.readRing});

  final Future<U19HealthSnapshot> Function() readWatch;
  final Future<ReadOnlyHealthFeatureSnapshot> Function()? readRing;

  @override
  Future<U19HealthSnapshot> getU19HealthFeatures() => readWatch();

  @override
  Future<ReadOnlyHealthFeatureSnapshot> getReadOnlyHealthFeatures() =>
      readRing?.call() ?? Future.value(_ringGrant);
}

class _Bridge extends Fake
    implements
        WearableBridge,
        WearableReadOnlyHealthPolicyBridge,
        WearableU19HealthPolicyBridge {
  final eventsSeen = <String>[];
  bool _pressureAllowed = false;
  bool _pressureVerified = false;

  @override
  Future<void> configureReadOnlyHealthMetrics(
    Set<HealthMetric> metrics, {
    required Duration validity,
  }) async {}

  @override
  Future<void> configureU19HealthMetrics(
    Set<HealthMetric> reads,
    Set<HealthMetric> manual, {
    required Duration validity,
  }) async {
    _pressureAllowed = reads.contains(HealthMetric.bloodPressure);
    _pressureVerified = false;
    eventsSeen.add(
      _pressureAllowed ? 'U19 read scope granted' : 'U19 read scope closed',
    );
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async {
    eventsSeen.add('detect capabilities');
    _pressureVerified = _pressureAllowed;
    return DeviceCapabilities(
      metrics: {
        HealthMetric.steps,
        if (_pressureVerified) HealthMetric.bloodPressure,
      },
    );
  }

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    eventsSeen.add('read history');
    HealthRecord sample(
      HealthMetric metric,
      Map<String, num> values,
      String unit,
    ) => HealthRecord(
      id: 'fixture-${metric.wireName}',
      metric: metric,
      values: values,
      unit: unit,
      measuredAt: DateTime.now().toUtc(),
      timezone: '+08:00',
      deviceId: _watch.id,
      firmwareVersion: '',
      sourceVendor: 'urion',
      sourceDeviceCategory: 'watch',
      quality: 'valid',
      source: MeasurementSource.wearable,
      origin: MeasurementOrigin.watchHistory,
      rawVersion: 1,
    );
    return WearableSyncResult(
      [
        sample(HealthMetric.steps, {'value': 42}, 'steps'),
        if (_pressureVerified)
          sample(HealthMetric.bloodPressure, {
            'systolic': 118,
            'diastolic': 76,
          }, 'mmHg'),
      ],
      {
        'steps': 'complete',
        if (_pressureVerified) 'blood_pressure': 'complete',
      },
    );
  }
}
