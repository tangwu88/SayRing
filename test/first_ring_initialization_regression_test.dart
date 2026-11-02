import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

final _owner = Session(
  accessToken: 'initialization-test-token',
  refreshToken: 'initialization-test-refresh',
  expiresAt: DateTime.utc(2099),
  memberId: 'initialization-test-owner',
  displayName: 'Test',
  accountKey: 'global:member:initialization-test-owner',
);
const _device = DeviceInfo(
  id: 'qring:11111111-2222-4333-8444-555555555555',
  name: 'R8_TEST',
  model: 'R8',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppController> setup(
    _ExistingBindingApi api,
    _PendingInitializationRing ring,
  ) async {
    final controller = AppController(
      MemorySessionVault()..privacyConsentGranted = true,
      api,
      MemoryHealthStore(),
      ring,
    );
    addTearDown(controller.dispose);
    addTearDown(ring.source.close);
    await controller.initialize();
    controller.session = _owner;
    ring.ownerKey = controller.homeHealthCardOwner;
    return controller;
  }

  test(
    'server lifetime binding does not erase native pending initialization',
    () async {
      final api = _ExistingBindingApi();
      final ring = _PendingInitializationRing();
      final controller = await setup(api, ring);
      bool? pendingBeforeServerDecision;
      api.beforeDecision = () {
        pendingBeforeServerDecision = controller.isRingInitializationPending;
      };

      await controller.connectDevice(_device);
      await _settle();

      expect(api.firstBindingCalls, 1);
      expect(pendingBeforeServerDecision, isTrue);
      expect(ring.pendingEvents, 1);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 0);
      expect(controller.connectedDevice?.id, _device.id);
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.capabilities?.supportsHistorySync, isFalse);
      expect(
        controller.isRingInitializationPending,
        isTrue,
        reason:
            'A previous server binding denies a second reset; it does not '
            'complete the exact owner/device initialization still pending '
            'in the native receipt. The reconnect action must stay available.',
      );
    },
  );

  test('existing member without a native receipt can synchronize', () async {
    final api = _ExistingBindingApi();
    final ring = _PendingInitializationRing()..initializationStatus = null;
    final controller = await setup(api, ring);

    await controller.connectDevice(_device);
    await _settle();

    expect(api.firstBindingCalls, 1);
    expect(controller.isRingInitializationPending, isFalse);
    expect(controller.capabilities?.supportsHistorySync, isTrue);
    expect(ring.historyReads, 1);
    expect(ring.resetCalls, 0);
  });

  test(
    'matching native completion releases the held synchronization',
    () async {
      final ring = _PendingInitializationRing();
      final controller = await setup(_ExistingBindingApi(), ring);
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(ring.historyReads, 0);

      ring.initializationStatus = 'complete';
      ring.source.add(
        WearableEvent(
          type: 'capabilitiesUpdated',
          payload: ring.capabilities.toJson(),
        ),
      );
      ring.emitInitialization('complete');
      await _settle();

      expect(controller.isRingInitializationPending, isFalse);
      expect(controller.capabilities?.supportsHistorySync, isTrue);
      expect(ring.historyReads, 1);
      expect(ring.resetCalls, 0);
    },
  );

  test(
    'native completion cannot bypass an unresolved server decision',
    () async {
      final api = _ExistingBindingApi()..decision = Completer<bool>();
      final ring = _PendingInitializationRing()
        ..initializationStatus = 'complete';
      final controller = await setup(api, ring);
      final connecting = controller.connectDevice(_device);
      await _settle();

      expect(api.firstBindingCalls, 1);
      expect(controller.isRingInitializationPending, isTrue);
      expect(ring.historyReads, 0);
      api.decision!.complete(false);
      await connecting;
      await _settle();

      expect(controller.isRingInitializationPending, isFalse);
      expect(ring.historyReads, 1);
      expect(ring.resetCalls, 0);
    },
  );

  test(
    'replacement target cannot inherit or receive the old receipt',
    () async {
      final ring = _PendingInitializationRing();
      final controller = await setup(_ExistingBindingApi(), ring);
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      await controller.disconnectDevice();
      ring.initializationStatus = null;
      const replacement = DeviceInfo(
        id: 'qring:99999999-2222-4333-8444-555555555555',
        name: 'R21_TEST',
        model: 'R21',
      );
      await controller.connectDevice(replacement);
      await _settle();
      ring.emitInitialization('pending', deviceId: _device.id);
      await _settle();

      expect(controller.connectedDevice?.id, replacement.id);
      expect(controller.isRingInitializationPending, isFalse);
      expect(ring.historyReads, 1);
      expect(ring.resetCalls, 0);
    },
  );

  test('account transition clears pending and rejects the old owner', () async {
    final ring = _PendingInitializationRing();
    final controller = await setup(_ExistingBindingApi(), ring);
    final previousOwner = ring.ownerKey;
    await controller.connectDevice(_device);
    await _settle();
    expect(controller.isRingInitializationPending, isTrue);
    await controller.logout();
    expect(controller.isRingInitializationPending, isFalse);
    controller.session = Session(
      accessToken: 'other-test-token',
      refreshToken: 'other-test-refresh',
      expiresAt: DateTime.utc(2099),
      memberId: 'other-test-owner',
      displayName: 'Other',
      accountKey: 'global:member:other-test-owner',
    );
    ring.ownerKey = controller.homeHealthCardOwner;
    ring.initializationStatus = null;
    await controller.connectDevice(_device);
    await _settle();
    ring.emitInitialization('pending', owner: previousOwner);
    await _settle();

    expect(controller.isRingInitializationPending, isFalse);
    expect(ring.historyReads, 1);
    expect(ring.resetCalls, 0);
  });
}

Future<void> _settle() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _ExistingBindingApi extends Fake
    implements SaydianApi, SaydianDeviceBindingApi, SayRingFirstBindingApi {
  int firstBindingCalls = 0;
  void Function()? beforeDecision;
  Completer<bool>? decision;

  @override
  Future<List<Map<String, Object?>>> getArticles() async => [];

  @override
  Future<void> logout() async {}

  @override
  Future<void> reportDeviceConnection({
    required Session expectedSession,
    required String deviceId,
    required String vendor,
    required String model,
    required String displayName,
    String? firmware,
    String? macAddress,
    List<String> capabilities = const [],
  }) async {}

  @override
  Future<bool> reportFirstRingBinding({
    required Session expectedSession,
    required String deviceId,
    required String vendor,
    required String model,
    required String displayName,
    String? firmware,
    String? macAddress,
    List<String> capabilities = const [],
  }) async {
    firstBindingCalls++;
    beforeDecision?.call();
    return decision?.future ?? false;
  }
}

class _PendingInitializationRing extends Fake
    implements
        WearableBridge,
        WearableBindingManagementBridge,
        WearableRingDataClearBridge {
  final source = StreamController<WearableEvent>.broadcast(sync: true);
  String ownerKey = '';
  int pendingEvents = 0;
  int resetCalls = 0;
  int historyReads = 0;
  String? initializationStatus = 'pending';
  String connectedDeviceId = _device.id;

  DeviceCapabilities get capabilities => DeviceCapabilities(
    metrics: const {HealthMetric.steps, HealthMetric.sleep},
    supportsHistorySync: initializationStatus != 'pending',
  );

  void emitInitialization(String status, {String? deviceId, String? owner}) {
    source.add(
      WearableEvent(
        type: 'ringInitialization',
        payload: {
          'deviceId': deviceId ?? connectedDeviceId,
          'ownerKey': owner ?? ownerKey,
          'status': status,
          'requiresReconnect': false,
        },
      ),
    );
  }

  @override
  Stream<WearableEvent> get events => source.stream;

  @override
  Future<void> setRecoveryContext({
    required String? ownerKey,
    required WearableUserProfile profile,
  }) async {}

  @override
  Future<DeviceInfo?> readRememberedDevice() async => null;

  @override
  Future<DeviceInfo?> prepareRememberedDevice() async => null;

  @override
  Future<void> forgetRememberedDevice() async {}

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connectedDeviceId = deviceId;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<DeviceCapabilities> getCapabilities() async {
    // iOS getCapabilities replays the durable native receipt before its
    // capability result. No reset is authorized in this reconnect scenario.
    if (initializationStatus case final status?) {
      pendingEvents++;
      emitInitialization(status);
    }
    return capabilities;
  }

  @override
  Future<RingDataClearResult> clearRingHistory({
    required String deviceId,
    required String ownerKey,
    bool allowFactoryReset = false,
  }) async {
    resetCalls++;
    return RingDataClearResult.factoryResetRequested;
  }

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    historyReads++;
    return [];
  }

  @override
  Future<List<SportRecord>> readSportRecords() async => [];
}
