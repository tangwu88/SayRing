import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'startup does not touch wearable recovery before privacy consent',
    () async {
      final wearable = _DelayedRecoveryWearable();
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        wearable,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(wearable.restoreStarted.isCompleted, isFalse);
    },
  );

  test(
    'manual scan cancels a stale saved-device restore before selection',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final wearable = _DelayedRecoveryWearable();
        final controller = AppController(
          MemorySessionVault()..privacyConsentGranted = true,
          _NoopApi(),
          MemoryHealthStore(),
          wearable,
        );
        addTearDown(controller.dispose);

        await controller.initialize();
        await wearable.restoreStarted.future;

        final scan = controller.scanDevices();
        await Future<void>.delayed(Duration.zero);
        wearable.restoreResult.complete(_DelayedRecoveryWearable.oldWatch);
        await scan;

        expect(controller.connectedDevice, isNull);
        expect(wearable.disconnectCount, 1);
        expect(controller.scannedDevices, [_DelayedRecoveryWearable.newWatch]);

        await controller.connectDevice(_DelayedRecoveryWearable.newWatch);

        expect(controller.connectedDevice?.id, 'NEW-W8');
        expect(wearable.connectCalls, ['NEW-W8']);
        expect(controller.deviceState, DeviceConnectionState.ready);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}

class _NoopApi extends Fake implements SaydianApi {
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];
}

class _DelayedRecoveryWearable extends Fake
    implements WearableBridge, WearableConnectionRecoveryBridge {
  static const oldWatch = DeviceInfo(id: 'OLD-W8', name: 'W8 Ultra old');
  static const newWatch = DeviceInfo(id: 'NEW-W8', name: 'W8 Plus new');

  final restoreStarted = Completer<void>();
  final restoreResult = Completer<DeviceInfo?>();
  final _events = StreamController<WearableEvent>.broadcast();
  final List<String> connectCalls = [];
  int disconnectCount = 0;

  @override
  Stream<WearableEvent> get events => _events.stream;

  @override
  Future<DeviceInfo?> restoreConnection({
    required WearableUserProfile profile,
  }) {
    if (!restoreStarted.isCompleted) restoreStarted.complete();
    return restoreResult.future;
  }

  @override
  Future<List<DeviceInfo>> scanDevices() async => [newWatch];

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
  Future<void> disconnect() async {
    disconnectCount++;
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(metrics: {});

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];

  @override
  Future<void> startMeasurement(HealthMetric metric) async {}

  @override
  Future<void> stopMeasurement(HealthMetric metric) async {}

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];
}
