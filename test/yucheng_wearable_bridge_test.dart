import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/yucheng_product_client.dart';
import 'package:saydian_app/services/yucheng_wearable_bridge.dart';

void main() {
  test('keeps vendor auto reconnect from hiding a bound W8', () async {
    final client = _FakeYuchengClient(modelName: 'W8 Ultra');
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
    );

    await bridge.scanDevices();

    expect(client.reconnectEnabled, isFalse);
  });

  test('accepts YC-prefixed rings without a W8 model allowlist', () async {
    final client = _FakeYuchengClient(
      modelName: 'YC Ring',
      scannedName: 'YC Ring',
    );
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
    );
    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);

    expect(client.disconnectCount, 0);
    expect((await bridge.getConnectedDeviceDetails())?.name, 'YC Ring');
  });

  test('maps unavailable operation to FEATURE_UNSUPPORTED', () async {
    final client = _FakeYuchengClient(
      modelName: 'W8 Ultra',
      measurementStatus: 2,
    );
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
    );
    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);
    await expectLater(
      bridge.startMeasurement(HealthMetric.heartRate),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'FEATURE_UNSUPPORTED',
        ),
      ),
    );
  });

  test('accepts a suffixed W8S as a supported Yucheng model', () async {
    final client = _FakeYuchengClient(modelName: 'w8s 4DE9');
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
    );

    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);

    expect(client.disconnectCount, 0);
    expect(client.modelCalls, 0);
  });

  test('preserves the vendor MAC separately from the iOS identifier', () async {
    final client = _FakeYuchengClient(modelName: 'W8S');
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
      deviceInfoSettleDelay: Duration.zero,
      deviceInfoRetryDelay: Duration.zero,
    );

    final device = (await bridge.scanDevices()).single;
    await bridge.connect(device.id, profile: _profile);
    final connected = await bridge.getConnectedDeviceDetails();

    expect(device.id, 'YC-01');
    expect(device.hardwareAddress, '07:43:00:00:4D:E9');
    expect(device.macAddress, '07:43:00:00:4D:E9');
    expect(connected?.hardwareAddress, '07:43:00:00:4D:E9');
    expect(connected?.identifierLabel, 'MAC · 07:43:00:00:4D:E9');
  });

  test('queries the W8 MAC when iOS scan omits it', () async {
    final client = _FakeYuchengClient(
      modelName: 'W8S',
      scannedHardwareAddress: '',
      queriedMacAddress: '07-43-00-00-4D-E9',
    );
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
      deviceInfoSettleDelay: Duration.zero,
      deviceInfoRetryDelay: Duration.zero,
    );

    final device = (await bridge.scanDevices()).single;
    await bridge.connect(device.id, profile: _profile);
    final connected = await bridge.getConnectedDeviceDetails();

    expect(device.macAddress, isNull);
    expect(connected?.hardwareAddress, '07:43:00:00:4D:E9');
    expect(connected?.identifierLabel, 'MAC · 07:43:00:00:4D:E9');
  });

  test(
    'maps the W8 basic-info battery without guessing another field',
    () async {
      final client = _FakeYuchengClient(
        modelName: 'W8S',
        basicInfoValue: const YuchengDeviceBasicInfo(
          batteryPercent: 86,
          batteryStatus: 2,
          firmwareVersion: '1.23',
        ),
      );
      final bridge = YuchengWearableBridge(
        client: client,
        initialHealthSettleDelay: Duration.zero,
        deviceInfoSettleDelay: Duration.zero,
        deviceInfoRetryDelay: Duration.zero,
      );

      await bridge.scanDevices();
      await bridge.connect('YC-01', profile: _profile);
      final details = await bridge.getConnectedDeviceDetails();

      expect(client.basicInfoCalls, 1);
      expect(details?.firmwareVersion, '1.23');
      expect(details?.effectiveBattery?.displayLabel, '86%');
      expect(details?.effectiveBattery?.isCharging, isTrue);
      expect(details?.effectiveBattery?.isLow, isFalse);
      expect(details?.effectiveBattery?.updatedAt?.isUtc, isTrue);
    },
  );

  test('rejects a late W8 battery callback from an older connection', () async {
    final oldRead = Completer<YuchengOperationResult<YuchengDeviceBasicInfo>>();
    final currentRead =
        Completer<YuchengOperationResult<YuchengDeviceBasicInfo>>();
    final client = _FakeYuchengClient(
      modelName: 'W8S',
      basicInfoResults: [oldRead.future, currentRead.future],
    );
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
      deviceInfoSettleDelay: Duration.zero,
      deviceInfoRetryDelay: Duration.zero,
    );
    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);
    await _waitUntil(() => client.basicInfoCalls == 1);

    await bridge.disconnect();
    await bridge.connect('YC-01', profile: _profile);
    await _waitUntil(() => client.basicInfoCalls == 2);
    final detailsFuture = bridge.getConnectedDeviceDetails();
    currentRead.complete(
      const YuchengOperationResult(
        0,
        YuchengDeviceBasicInfo(
          batteryPercent: 73,
          batteryStatus: 0,
          firmwareVersion: '2.00',
        ),
      ),
    );
    final currentDetails = await detailsFuture;

    oldRead.complete(
      const YuchengOperationResult(
        0,
        YuchengDeviceBasicInfo(
          batteryPercent: 12,
          batteryStatus: 1,
          firmwareVersion: '0.01',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final afterLateCallback = await bridge.getConnectedDeviceDetails();

    expect(currentDetails?.effectiveBattery?.displayLabel, '73%');
    expect(afterLateCallback?.effectiveBattery?.displayLabel, '73%');
    expect(afterLateCallback?.firmwareVersion, '2.00');
  });

  test('times out a Yucheng history read instead of hanging sync', () async {
    final client = _FakeYuchengClient(
      modelName: 'W8S',
      healthResult:
          Completer<YuchengOperationResult<List<Map<String, Object?>>>>()
              .future,
    );
    final bridge = YuchengWearableBridge(
      client: client,
      healthReadTimeout: const Duration(milliseconds: 10),
      initialHealthSettleDelay: Duration.zero,
    );
    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);

    await expectLater(
      bridge.syncHealthData(),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'YUCHENG_SYNC_TIMEOUT',
        ),
      ),
    );
  });

  test('maps raw native bluetooth state events', () async {
    final client = _FakeYuchengClient(modelName: 'W8S');
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
    );
    await bridge.scanDevices();
    final disconnected = bridge.events.first;

    client.emit({'bluetoothStateChange': 4});

    expect((await disconnected).type, 'disconnected');
  });

  test('emits a camera shutter only for the W8 photo state', () async {
    final client = _FakeYuchengClient(modelName: 'W8S');
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
    );
    await bridge.scanDevices();
    final shutter = bridge.events.firstWhere(
      (event) => event.type == 'cameraShutter',
    );

    client.emit({'deviceControlPhotoStateChange': 1});
    client.emit({'deviceControlPhotoStateChange': 2});

    expect((await shutter).payload['value'], 2);
  });

  test('uses only the capability flags reported by the connected W8', () async {
    final client = _FakeYuchengClient(modelName: 'W8S');
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
    );
    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);

    final capabilities = await bridge.getCapabilities();

    expect(capabilities.manualMetrics, {
      HealthMetric.heartRate,
      HealthMetric.bloodPressure,
      HealthMetric.bloodOxygen,
    });
    expect(capabilities.supportsManualMeasurement(HealthMetric.sleep), isFalse);
  });

  test('waits for the W8 feature handshake before giving up', () async {
    final client = _FakeYuchengClient(
      modelName: 'W8 Ultra',
      capabilityFailuresBeforeSuccess: 5,
    );
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
      capabilityRetryDelay: Duration.zero,
    );
    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);

    final capabilities = await bridge.getCapabilities();

    expect(client.capabilityCalls, 6);
    expect(capabilities.metrics, contains(HealthMetric.heartRate));
  });

  test(
    'does not invent a generic W8 capability set when reporting fails',
    () async {
      final client = _FakeYuchengClient(
        modelName: 'W8S',
        capabilityFlags: const {},
      );
      final bridge = YuchengWearableBridge(
        client: client,
        initialHealthSettleDelay: Duration.zero,
      );
      await bridge.scanDevices();
      await bridge.connect('YC-01', profile: _profile);

      await expectLater(
        bridge.getCapabilities(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'CAPABILITIES_UNAVAILABLE',
          ),
        ),
      );
    },
  );

  test(
    'maps W8 live measurement payloads to canonical health records',
    () async {
      final client = _FakeYuchengClient(modelName: 'W8S');
      final bridge = YuchengWearableBridge(
        client: client,
        initialHealthSettleDelay: Duration.zero,
      );
      await bridge.scanDevices();
      await bridge.connect('YC-01', profile: _profile);

      final heartFuture = bridge.events.firstWhere(
        (event) => event.type == 'healthRecord',
      );
      client.emit({'deviceRealHeartRate': 78});
      final heart = HealthRecord.fromJson((await heartFuture).payload);
      expect(heart.metric, HealthMetric.heartRate);
      expect(heart.values, {'value': 78});
      expect(heart.deviceId, 'YC-01');

      final pressureFuture = bridge.events.firstWhere(
        (event) => event.type == 'healthRecord',
      );
      client.emit({
        'deviceRealBloodPressure': {
          'heartRate': 72,
          'systolicBloodPressure': 118,
          'diastolicBloodPressure': 76,
        },
      });
      final pressure = HealthRecord.fromJson((await pressureFuture).payload);
      expect(pressure.metric, HealthMetric.bloodPressure);
      expect(pressure.values, {'systolic': 118, 'diastolic': 76, 'pulse': 72});

      final oxygenFuture = bridge.events.firstWhere(
        (event) => event.type == 'healthRecord',
      );
      client.emit({'deviceRealBloodOxygen': 97});
      final oxygen = HealthRecord.fromJson((await oxygenFuture).payload);
      expect(oxygen.metric, HealthMetric.bloodOxygen);
      expect(oxygen.values, {'value': 97});
    },
  );

  test('recovers the final W8 blood pressure record after SDK stops', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final client = _FakeYuchengClient(
      modelName: 'W8S',
      healthResult: Future.value(
        YuchengOperationResult(0, [
          {
            'startTimeStamp': now,
            'systolicBloodPressure': 121,
            'diastolicBloodPressure': 79,
          },
        ]),
      ),
    );
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
    );
    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);
    await bridge.startMeasurement(HealthMetric.bloodPressure);
    final recordFuture = bridge.events.firstWhere(
      (event) => event.type == 'healthRecord',
    );

    client.emit({
      'deviceHealthDataMeasureStateChange': {
        'state': 0,
        'healthDataType': YuchengMeasurementType.bloodPressure,
      },
    });

    final record = HealthRecord.fromJson((await recordFuture).payload);
    expect(record.metric, HealthMetric.bloodPressure);
    expect(record.values, {'systolic': 121, 'diastolic': 79});
  });

  test(
    'reads and switches installed W8 watch faces without online upload',
    () async {
      final client = _FakeYuchengClient(
        modelName: 'W8S',
        watchFaceRows: const [
          {
            'id': '101',
            'dialId': 101,
            'name': '表盘 101',
            'isCurrent': true,
            'type': 'yuc',
            'index': 101,
          },
        ],
      );
      final bridge = YuchengWearableBridge(
        client: client,
        initialHealthSettleDelay: Duration.zero,
      );
      await bridge.scanDevices();
      await bridge.connect('YC-01', profile: _profile);

      final data = await bridge.readDeviceFeature(DeviceFeature.watchFaces);
      expect(data['onlineMarketSupported'], isFalse);
      expect(data['source'], 'Yuc');
      expect((data['items'] as List).single, containsPair('id', '101'));

      await bridge.writeDeviceFeature(DeviceFeature.watchFaces, {
        'operation': 'switch',
        'id': '101',
      });
      expect(client.changedWatchFaceId, 101);
    },
  );

  test('does not resend the one-shot W8 find command when stopping', () async {
    final client = _FakeYuchengClient(modelName: 'W8S');
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
    );
    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);

    await bridge.triggerDeviceAction(DeviceFeature.findWatch);
    await bridge.triggerDeviceAction(DeviceFeature.findWatch, enabled: false);

    expect(client.findDeviceCalls, 1);
  });

  test('uses exact W8 sport commands including pause and resume', () async {
    final client = _FakeYuchengClient(
      modelName: 'W8S',
      capabilityFlags: const {
        'isSupportHeartRate': true,
        'isSupportOutdoorRunning': true,
        'isSupportSportPause': true,
      },
    );
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
      capabilityRetryDelay: Duration.zero,
    );
    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);
    await bridge.getCapabilities();

    await bridge.startSport(SportMode.running);
    await bridge.pauseSport();
    await bridge.resumeSport();
    await bridge.stopSport();

    expect(client.sportCalls, const [
      (YuchengSportState.start, 0x0F),
      (YuchengSportState.pause, 0x0F),
      (YuchengSportState.resume, 0x0F),
      (YuchengSportState.stop, 0x0F),
    ]);
  });

  test('maps W8 sport state and live watch values without guessing', () async {
    final client = _FakeYuchengClient(modelName: 'W8S');
    final bridge = YuchengWearableBridge(
      client: client,
      initialHealthSettleDelay: Duration.zero,
    );
    await bridge.scanDevices();

    final stateFuture = bridge.events.firstWhere(
      (event) => event.type == 'sportState',
    );
    client.emit({
      'deviceSportStateChange': {'state': 2, 'sportType': 0x1B},
    });
    final state = await stateFuture;
    expect(state.payload, containsPair('value', 'paused'));
    expect(state.payload, containsPair('mode', SportMode.hiking.wireName));

    final dataFuture = bridge.events.firstWhere(
      (event) => event.type == 'sportData',
    );
    client.emit({
      'deviceRealSport': {
        'time': 62,
        'heartRate': 91,
        'step': 320,
        'distance': 450,
        'calories': 16,
        'vo2max': 33,
      },
    });
    expect((await dataFuture).payload, {
      'durationSeconds': 62,
      'heartRate': 91,
      'steps': 320,
      'distanceMeters': 450,
      'calories': 16,
      'vo2max': 33,
    });
  });

  test('restores only the explicitly remembered W8 connection', () async {
    final store = _MemoryYuchengSavedDeviceStore();
    final firstClient = _FakeYuchengClient(
      modelName: 'W8 Plus',
      scannedName: 'YC W8 Plus 549D',
    );
    final firstBridge = YuchengWearableBridge(
      client: firstClient,
      savedDeviceStore: store,
      initialHealthSettleDelay: Duration.zero,
    );
    await firstBridge.scanDevices();
    await firstBridge.connect('YC-01', profile: _profile);

    final restoredClient = _FakeYuchengClient(modelName: 'W8 Plus');
    final restoredBridge = YuchengWearableBridge(
      client: restoredClient,
      savedDeviceStore: store,
      initialHealthSettleDelay: Duration.zero,
    );
    final restored = await restoredBridge.restoreConnection(profile: _profile);

    expect(restoredClient.savedConnectCalls, ['YC-01']);
    expect(restored?.name, 'YC W8 Plus 549D');
    expect(restored?.hardwareAddress, '07:43:00:00:4D:E9');
  });

  test('explicit W8 disconnect removes the recovery target', () async {
    final store = _MemoryYuchengSavedDeviceStore();
    final client = _FakeYuchengClient(modelName: 'W8S');
    final bridge = YuchengWearableBridge(
      client: client,
      savedDeviceStore: store,
      initialHealthSettleDelay: Duration.zero,
    );
    await bridge.scanDevices();
    await bridge.connect('YC-01', profile: _profile);

    await bridge.disconnect();

    expect(await store.read(), isNull);
  });
}

const _profile = WearableUserProfile(
  gender: 1,
  heightCm: 175,
  weightKg: 70,
  birthYear: 1996,
  age: 30,
  targetSteps: 10000,
);

class _FakeYuchengClient implements YuchengProductClient {
  _FakeYuchengClient({
    required this.modelName,
    this.scannedName = 'YC W8 Ultra',
    this.scannedHardwareAddress = '07:43:00:00:4D:E9',
    this.queriedMacAddress = '07:43:00:00:4D:E9',
    this.measurementStatus = 0,
    this.healthResult,
    this.watchFaceRows = const [],
    this.capabilityFailuresBeforeSuccess = 0,
    this.basicInfoResults = const [],
    this.basicInfoValue = const YuchengDeviceBasicInfo(
      batteryPercent: 86,
      batteryStatus: 0,
      firmwareVersion: '1.0',
    ),
    this.capabilityFlags = const {
      'isSupportStep': true,
      'isSupportSleep': true,
      'isSupportHeartRate': true,
      'isSupportBloodPressure': true,
      'isSupportBloodOxygen': true,
      'isSupportStartHeartRateMeasurement': true,
      'isSupportStartBloodPressureMeasurement': true,
      'isSupportStartBloodOxygenMeasurement': true,
    },
  });
  final String modelName;
  final String scannedName;
  final String scannedHardwareAddress;
  final String queriedMacAddress;
  final int measurementStatus;
  final Future<YuchengOperationResult<List<Map<String, Object?>>>>?
  healthResult;
  final List<Map<String, Object?>> watchFaceRows;
  final int capabilityFailuresBeforeSuccess;
  final List<Future<YuchengOperationResult<YuchengDeviceBasicInfo>>>
  basicInfoResults;
  final YuchengDeviceBasicInfo basicInfoValue;
  final Map<String, Object?> capabilityFlags;
  int disconnectCount = 0;
  int modelCalls = 0;
  int? changedWatchFaceId;
  bool? reconnectEnabled;
  int capabilityCalls = 0;
  int basicInfoCalls = 0;
  int findDeviceCalls = 0;
  final List<(int, int)> sportCalls = [];
  final List<String> savedConnectCalls = [];
  final _events = StreamController<Map<String, Object?>>.broadcast();
  @override
  Stream<Map<String, Object?>> get events => _events.stream;
  @override
  Future<void> initialize({
    required bool reconnectEnabled,
    required bool logEnabled,
  }) async {
    this.reconnectEnabled = reconnectEnabled;
  }

  @override
  Future<List<Map<String, Object?>>> scan() async => [
    {
      'identifier': 'YC-01',
      'name': scannedName,
      'rssi': -40,
      'hardwareAddress': scannedHardwareAddress,
    },
  ];
  @override
  Future<void> stopScan() async {}
  @override
  Future<bool> connect(String identifier) async => true;
  @override
  Future<bool> connectSaved({
    required String identifier,
    required String name,
    String? hardwareAddress,
  }) async {
    savedConnectCalls.add(identifier);
    return true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
  }

  @override
  Future<YuchengOperationResult<String>> model() async {
    modelCalls++;
    return YuchengOperationResult(0, modelName);
  }

  @override
  Future<YuchengOperationResult<String>> firmware() async =>
      const YuchengOperationResult(0, '1.0');
  @override
  Future<YuchengOperationResult<String>> macAddress() async =>
      YuchengOperationResult(0, queriedMacAddress);
  @override
  Future<YuchengOperationResult<YuchengDeviceBasicInfo>> basicInfo() {
    final index = basicInfoCalls++;
    if (index < basicInfoResults.length) return basicInfoResults[index];
    return Future.value(YuchengOperationResult(0, basicInfoValue));
  }

  @override
  Future<Map<String, Object?>> capabilities() async {
    capabilityCalls++;
    return capabilityCalls <= capabilityFailuresBeforeSuccess
        ? const {}
        : capabilityFlags;
  }

  @override
  Future<YuchengOperationResult<void>> syncTime() async =>
      const YuchengOperationResult(0, null);
  @override
  Future<YuchengOperationResult<void>> setUserProfile({
    required int height,
    required int weight,
    required int age,
    required int gender,
  }) async => const YuchengOperationResult(0, null);
  @override
  Future<YuchengOperationResult<void>> setStepGoal(int steps) async =>
      const YuchengOperationResult(0, null);
  @override
  Future<YuchengOperationResult<List<Map<String, Object?>>>> health(int type) =>
      healthResult ?? Future.value(const YuchengOperationResult(0, []));

  void emit(Map<String, Object?> event) => _events.add(event);
  @override
  Future<YuchengOperationResult<void>> measure({
    required bool enabled,
    required int type,
  }) async => YuchengOperationResult(measurementStatus, null);
  @override
  Future<YuchengOperationResult<void>> sport({
    required int state,
    required int type,
  }) async {
    sportCalls.add((state, type));
    return const YuchengOperationResult(0, null);
  }

  @override
  Future<YuchengOperationResult<void>> setHealthMonitoring(
    bool enabled,
  ) async => const YuchengOperationResult(0, null);
  @override
  Future<YuchengOperationResult<void>> setHeartRateAlarm(int value) async =>
      const YuchengOperationResult(0, null);
  @override
  Future<YuchengOperationResult<void>> findDevice() async {
    findDeviceCalls++;
    return const YuchengOperationResult(0, null);
  }

  @override
  Future<YuchengOperationResult<void>> camera(bool enabled) async =>
      const YuchengOperationResult(0, null);
  @override
  Future<YuchengOperationResult<List<Map<String, Object?>>>>
  watchFaces() async => YuchengOperationResult(0, watchFaceRows);
  @override
  Future<YuchengOperationResult<void>> changeWatchFace(int dialId) async {
    changedWatchFaceId = dialId;
    return const YuchengOperationResult(0, null);
  }
}

class _MemoryYuchengSavedDeviceStore implements YuchengSavedDeviceStore {
  YuchengSavedDevice? value;

  @override
  Future<YuchengSavedDevice?> read() async => value;

  @override
  Future<void> write(YuchengSavedDevice device) async {
    value = device;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Timed out waiting for the asynchronous Yucheng operation');
}
