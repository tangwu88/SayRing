import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/coolwear_wearable_bridge.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/domain/wearable_sync_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cc.saidian.ring/commands');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getCapabilities' => <Object?, Object?>{
          'resolved': true,
          'metrics': <Object?>['steps', 'distance', 'calories', 'sleep'],
          'manualMetrics': <Object?>[],
          'sportModes': <Object?>[
            'running',
            'indoor_running',
            'walking',
            'cycling',
            'indoor_cycling',
            'basketball',
            'football',
            'badminton',
            'swimming',
            'jump_rope',
            'yoga',
            'hiking',
            'mountaineering',
          ],
          'features': <Object?>[],
          'supportsSportPause': true,
        },
        'syncHealthData' => <Object?>[
          <Object?, Object?>{
            'id': 'health-1',
            'type': 'steps',
            'values': <Object?, Object?>{'value': 1234},
            'unit': '步',
            'measuredAt': '2026-09-22T01:00:00.000Z',
            'timezone': '+08:00',
            'deviceId': 'coolwear:ring',
            'firmwareVersion': '1.0',
            'quality': 'device_reported',
            'source': 'wearable',
            'origin': 'watch_history',
            'rawVersion': 1,
          },
        ],
        'readSportRecords' => <Object?>[
          <Object?, Object?>{
            'id': 'sport-1',
            'mode': 'hiking',
            'startedAt': '2026-09-22T01:00:00.000Z',
            'durationSeconds': 600,
            'distanceKm': 1.2,
            'calories': 60,
            'steps': 1500,
            'heartRate': 90,
            'minimumHeartRate': 0,
            'maximumHeartRate': 120,
            'routePoints': <Object?>[],
          },
        ],
        'readAutoMeasureIntervals' => <Object?, Object?>{
          'heartRate': <Object?, Object?>{
            'minutes': 30,
            'stepMinutes': 1,
            'canModify': true,
          },
        },
        'readDeviceFeature' => <Object?, Object?>{
          'supportedKeys': <Object?>['incomingCall', 'wechat'],
          'notificationAccess': true,
        },
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'sync map preserves partial and empty completion without changing legacy list API',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'records': [],
          'statuses': {'heart_rate': 'not_received'},
        },
      );
      final bridge = CoolWearWearableBridge(methods: channel);
      final missing = await bridge.syncHealthData();
      expect(missing, isA<WearableSyncResult>());
      expect((missing as WearableSyncResult).complete, isFalse);
      expect(missing.partial, isFalse);
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'records': [],
          'statuses': {'heart_rate': 'no_data'},
        },
      );
      final empty = await bridge.syncHealthData() as WearableSyncResult;
      expect(empty.complete, isTrue);
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'records': [],
          'statuses': {'sleep': 'partial'},
        },
      );
      expect(
        (await bridge.syncHealthData() as WearableSyncResult).partial,
        isTrue,
      );
    },
  );

  test('maps vendor-completed health history', () async {
    final bridge = CoolWearWearableBridge(methods: channel);

    final records = await bridge.syncHealthData(cursor: 'next');

    expect(records, hasLength(1));
    expect(records.single.metric, HealthMetric.steps);
    expect(records.single.values['value'], 1234);
    expect(calls.single.method, 'syncHealthData');
    expect(calls.single.arguments, {'cursor': 'next'});
  });

  test('forwards all supported sport controls', () async {
    final bridge = CoolWearWearableBridge(methods: channel);
    expect(bridge, isA<WearableSportPauseBridge>());

    await bridge.startSport(SportMode.walking);
    await bridge.pauseSport();
    await bridge.resumeSport();
    await bridge.stopSport();

    expect(calls.map((call) => call.method), [
      'startSport',
      'pauseSport',
      'resumeSport',
      'stopSport',
    ]);
    expect(calls.first.arguments, {'mode': 'walking'});
  });

  test('exposes the SDK-confirmed activity and LuckRing workout set', () async {
    final bridge = CoolWearWearableBridge(methods: channel);

    final capabilities = await bridge.getCapabilities();
    await bridge.startSport(SportMode.indoorRunning);

    expect(
      capabilities.metrics,
      containsAll(<HealthMetric>{
        HealthMetric.steps,
        HealthMetric.distance,
        HealthMetric.calories,
        HealthMetric.sleep,
      }),
    );
    expect(capabilities.sportModes, containsAll(SportMode.values));
    expect(capabilities.supportsSportPause, isTrue);
    expect(calls.last.arguments, {'mode': 'indoor_running'});
  });

  test('maps vendor sport history', () async {
    final bridge = CoolWearWearableBridge(methods: channel);

    final records = await bridge.readSportRecords();

    expect(records, hasLength(1));
    expect(records.single.mode, SportMode.hiking);
    expect(records.single.durationSeconds, 600);
    expect(records.single.distanceKm, 1.2);
    expect(records.single.steps, 1500);
  });

  test('forwards HR05 monitoring interval and reminder settings', () async {
    final bridge = CoolWearWearableBridge(methods: channel);
    expect(bridge, isA<WearableAutoMeasureIntervalBridge>());
    final intervals = await bridge.readAutoMeasureIntervals();
    expect(intervals['heartRate']?.minutes, 30);
    await bridge.setAutoMeasureInterval('heartRate', 60);
    final notifications = await bridge.readDeviceFeature(
      DeviceFeature.notifications,
    );
    expect(notifications['notificationAccess'], true);
    await bridge.writeDeviceFeature(DeviceFeature.healthReminders, {
      'id': 'drinking',
      'enabled': true,
      'startMinutes': 480,
      'endMinutes': 1320,
      'intervalMinutes': 30,
    });
    expect(calls.map((call) => call.method), [
      'readAutoMeasureIntervals',
      'setAutoMeasureInterval',
      'readDeviceFeature',
      'writeDeviceFeature',
    ]);
    expect(calls[1].arguments, {'type': 'heartRate', 'minutes': 60});
    expect(calls[3].arguments['feature'], 'health_reminders');
  });

  test('keeps unsupported CoolWear controls closed', () async {
    final bridge = CoolWearWearableBridge(methods: channel);
    await expectLater(
      bridge.readDeviceFeature(DeviceFeature.watchFaces),
      throwsA(isA<PlatformException>()),
    );
    expect(calls, isEmpty);
  });
}
