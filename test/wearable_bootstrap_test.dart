import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/wearable_bootstrap.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/services/wearable_routing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'iOS excludes legacy SDKs and preserves an unsupported saved binding',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final veepoo = _FakeBridge(const [
        DeviceInfo(id: 'legacy-v', name: 'V Ring'),
      ]);
      final yucheng = _FakeBridge(const [
        DeviceInfo(id: 'legacy-y', name: 'YC Ring'),
      ]);
      final store = _MemoryBindingStore();
      final bridge =
          createProductionWearableBridge(
                veepoo: veepoo,
                yucheng: yucheng,
                coolwear: _FakeBridge(const [
                  DeviceInfo(id: 'cool', name: 'HR01'),
                ]),
                qring: _FakeBridge(const [DeviceInfo(id: 'qr', name: 'R21')]),
                preferenceStore: store,
              )
              as RoutedWearableBridge;
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(
        ownerKey: 'synthetic-owner',
        profile: _profile,
      );
      final devices = await bridge.scanDevices();
      expect(
        devices.map((device) => device.name),
        unorderedEquals(['HR01', 'R21']),
      );
      expect(veepoo.scanCalls, 0);
      expect(yucheng.scanCalls, 0);
      expect((await bridge.readRememberedDevice())?.name, 'V Ring');
      expect(await bridge.canAutomaticallyRecoverRememberedDevice(), isFalse);
      final unsupported = throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'DEVICE_SDK_UNAVAILABLE',
        ),
      );
      await expectLater(bridge.prepareRememberedDevice(), unsupported);
      await expectLater(
        bridge.restoreConnection(profile: _profile),
        unsupported,
      );
      expect(store.binding?.nativeIdentifier, 'legacy-v');
      expect(store.writes, 0);
      expect(store.clears, 0);
      expect(veepoo.connectCalls, isEmpty);
      expect(yucheng.connectCalls, isEmpty);
    },
  );
  test(
    'iOS registers real CoolWear transport for all confirmed ring names',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const commands = MethodChannel('cc.saidian.ring/commands');
      const events = MethodChannel('cc.saidian.ring/events');
      final calls = <String>[];
      messenger.setMockMethodCallHandler(commands, (call) async {
        calls.add(call.method);
        if (call.method == 'scanDevices') {
          return [
            for (final name in [
              'hr01',
              'HR05_1234',
              'K80',
              'R7',
              'R7y',
              'R7Pro',
              'K800',
            ])
              {'id': 'synthetic-$name', 'name': name},
          ];
        }
        return null;
      });
      messenger.setMockMethodCallHandler(events, (_) async => null);
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(commands, null);
        messenger.setMockMethodCallHandler(events, null);
      });
      final bridge = createProductionWearableBridge(
        veepoo: _FakeBridge(const []),
        yucheng: _FakeBridge(const []),
        qring: _FakeBridge(const []),
      );
      final devices = await bridge.scanDevices();
      expect(
        devices.map((d) => d.name),
        unorderedEquals(['hr01', 'HR05_1234', 'K80', 'R7', 'R7y', 'R7Pro']),
      );
      expect(devices.every((d) => d.id.startsWith('coolwear:')), isTrue);
      expect(calls, contains('scanDevices'));
      await bridge.stopScan();
    },
  );
  test(
    'production bridge routes YC, V and QRing names to their SDKs',
    () async {
      final veepoo = _FakeBridge(const [
        DeviceInfo(id: 'VP-01', name: 'V Ring'),
      ]);
      final yucheng = _FakeBridge(const [
        DeviceInfo(id: 'YC-01', name: 'YC Ring'),
      ]);
      final qring = _FakeBridge(const [
        DeviceInfo(id: 'QR-01', name: 'Q_Ring'),
      ]);
      final bridge = createProductionWearableBridge(
        veepoo: veepoo,
        yucheng: yucheng,
        qring: qring,
      );
      final devices = await bridge.scanDevices();
      await bridge.connect(
        devices.singleWhere((d) => d.name == 'YC Ring').id,
        profile: _profile,
      );
      expect(yucheng.connectCalls, ['YC-01']);
      expect(veepoo.connectCalls, isEmpty);
      await bridge.connect(
        devices.singleWhere((d) => d.name == 'Q_Ring').id,
        profile: _profile,
      );
      expect(qring.connectCalls, ['QR-01']);
    },
  );
}

const _profile = WearableUserProfile(
  gender: 1,
  heightCm: 175,
  weightKg: 70,
  birthYear: 1996,
  age: 30,
  targetSteps: 10000,
);

class _FakeBridge implements WearableBridge {
  _FakeBridge(this.devices);
  final List<DeviceInfo> devices;
  final List<String> connectCalls = [];
  int scanCalls = 0;
  @override
  Stream<WearableEvent> get events => const Stream.empty();
  @override
  Future<List<DeviceInfo>> scanDevices() async {
    scanCalls++;
    return devices;
  }

  @override
  Future<void> stopScan() async {}
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connectCalls.add(deviceId);
  }

  @override
  Future<void> disconnect() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(metrics: {});
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => [];
  @override
  Future<void> startMeasurement(HealthMetric metric) async {}
  @override
  Future<void> stopMeasurement(HealthMetric metric) async {}
  @override
  Future<void> startSport(SportMode mode) async {}
  @override
  Future<void> stopSport() async {}
  @override
  Future<List<SportRecord>> readSportRecords() async => [];
  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async => {};
  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) async {}
  @override
  Future<int?> readHeartRateWarning() async => null;
  @override
  Future<void> setHeartRateWarning(int value) async {}
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      {};
  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {}
  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {}
}

class _MemoryBindingStore implements WearableBindingPreferenceStore {
  SavedWearableBinding? binding = const SavedWearableBinding(
    WearableTransport.veepoo,
    'legacy-v',
    deviceName: 'V Ring',
    ownerKey: 'synthetic-owner',
  );
  int writes = 0;
  int clears = 0;
  @override
  Future<SavedWearableBinding?> readBinding() async => binding;
  @override
  Future<WearableTransport?> read() async => binding?.transport;
  @override
  Future<void> clear() async {
    clears++;
    binding = null;
  }

  @override
  Future<void> write(WearableTransport transport) async {
    writes++;
  }

  @override
  Future<void> writeBinding(SavedWearableBinding value) async {
    writes++;
    binding = value;
  }
}
