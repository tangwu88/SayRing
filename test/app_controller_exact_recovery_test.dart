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

  Future<({AppController controller, _Ring ring})> setup({
    bool consent = true,
    bool legacy = false,
  }) async {
    final ring = legacy ? _LegacyRing() : _Ring();
    final controller = AppController(
      MemorySessionVault()..privacyConsentGranted = consent,
      _Api(),
      MemoryHealthStore(),
      ring,
    );
    addTearDown(controller.dispose);
    addTearDown(ring.source.close);
    await controller.initialize();
    await _settle();
    return (controller: controller, ring: ring);
  }

  test(
    'privacy denial only cancels existing restoration, never starts recovery',
    () async {
      final state = await setup(consent: false);
      expect(state.ring.contexts, [null]);
      expect(state.ring.restoreCount, 0);
      expect(state.controller.rememberedDevice, isNull);
    },
  );

  test('a dropped ring starts recovery without another app resume', () async {
    final state = await setup();
    await state.controller.connectDevice(_Ring.device);
    await _settle();
    final restores = state.ring.restoreCount;
    state.ring.source.add(
      const WearableEvent(
        type: 'disconnected',
        payload: {'deviceId': _Ring.id},
      ),
    );
    await _settle();
    expect(state.controller.connectedDevice, isNull);
    expect(state.controller.rememberedDevice?.id, _Ring.id);
    expect(state.controller.isWearableRecovering, isTrue);
    expect(state.ring.restoreCount, greaterThan(restores));
    state.ring.source.add(
      WearableEvent(type: 'reconnected', payload: _Ring.device.toJson()),
    );
    await _settle();
    expect(state.controller.connectedDevice?.id, _Ring.id);
    expect(state.controller.deviceState, DeviceConnectionState.ready);
    expect(state.controller.isWearableRecovering, isFalse);
  });

  test(
    'legacy binding is visible but never promises or starts automatic recovery',
    () async {
      final state = await setup(legacy: true);
      expect(state.controller.rememberedDevice?.id, _Ring.id);
      expect(state.controller.isWearableRecovering, isFalse);
      expect(state.controller.wearableRecoveryMessage, '保存的戒指需要确认，请点重新连接');
      expect(state.ring.restoreCount, 0);
      state.ring.source.add(
        WearableEvent(type: 'reconnected', payload: _Ring.device.toJson()),
      );
      state.ring.source.add(
        const WearableEvent(
          type: 'recoveryState',
          payload: {'status': 'waiting', 'deviceId': _Ring.id},
        ),
      );
      await _settle();
      expect(state.controller.connectedDevice, isNull);
      expect(state.controller.isWearableRecovering, isFalse);
      await state.controller.handleAppResumed();
      expect(state.ring.restoreCount, 0);
      expect(state.controller.wearableRecoveryMessage, '保存的戒指需要确认，请点重新连接');
    },
  );

  test(
    'legacy successful explicit confirmation enables later automatic recovery',
    () async {
      final state = await setup(legacy: true);
      await state.controller.reconnectDevice();
      expect(state.controller.connectedDevice?.id, _Ring.id);
      expect(state.controller.wearableRecoveryMessage, isNull);
      state.ring.source.add(
        const WearableEvent(
          type: 'disconnected',
          payload: {'deviceId': _Ring.id},
        ),
      );
      await _settle();
      expect(state.controller.isWearableRecovering, isTrue);
      expect(state.ring.restoreCount, 1);
      expect(state.controller.wearableRecoveryMessage, contains('靠近后会自动连接'));
    },
  );

  test(
    'legacy failed explicit handshake still requires manual confirmation',
    () async {
      final state = await setup(legacy: true);
      (state.ring as _LegacyRing).failHandshake = true;
      await state.controller.reconnectDevice();
      expect(state.controller.connectedDevice, isNull);
      expect(state.controller.isWearableRecovering, isFalse);
      expect(state.controller.wearableRecoveryMessage, '保存的戒指需要确认，请点重新连接');
      expect(state.ring.restoreCount, 0);
    },
  );

  test('the visible reconnect action drains then freshly connects', () async {
    final state = await setup();
    await state.controller.connectDevice(_Ring.device);
    await state.controller.reconnectDevice();
    expect(
      state.ring.operations,
      containsAllInOrder(['connect', 'disconnect', 'prepare', 'connect']),
    );
    expect(state.controller.connectedDevice?.id, _Ring.id);
    expect(state.controller.rememberedDevice?.id, _Ring.id);
    expect(state.ring.forgotten, isFalse);
  });

  test('unbind clears the saved target and rejects a late reconnect', () async {
    final state = await setup();
    await state.controller.connectDevice(_Ring.device);
    await state.controller.unbindDevice();
    state.ring.source.add(
      WearableEvent(type: 'reconnected', payload: _Ring.device.toJson()),
    );
    await _settle();
    expect(state.ring.forgotten, isTrue);
    expect(state.controller.rememberedDevice, isNull);
    expect(state.controller.connectedDevice, isNull);
    expect(state.controller.isWearableRecovering, isFalse);
  });

  test(
    'double reconnect taps share one native disconnect and handshake',
    () async {
      final state = await setup();
      await state.controller.connectDevice(_Ring.device);
      state.ring.delayedDisconnect = Completer<void>();
      final first = state.controller.reconnectDevice();
      await state.ring.disconnectStarted.future;
      final second = state.controller.reconnectDevice();
      await _settle();
      expect(
        state.ring.operations.where((value) => value == 'disconnect').length,
        1,
      );
      state.ring.delayedDisconnect!.complete();
      await Future.wait([first, second]);
      expect(
        state.ring.operations.where((value) => value == 'connect').length,
        2,
      );
      expect(state.controller.deviceState, DeviceConnectionState.ready);
    },
  );

  test(
    'native disconnect failure does not escape or permanently suspend reconnect',
    () async {
      final state = await setup();
      await state.controller.connectDevice(_Ring.device);
      state.ring.failDisconnect = true;
      await state.controller.reconnectDevice();
      expect(state.controller.connectedDevice, isNull);
      expect(state.controller.rememberedDevice?.id, _Ring.id);
      expect(state.controller.wearableRecoveryMessage, contains('结束上次连接'));
      state.ring.failDisconnect = false;
      await state.controller.reconnectDevice();
      expect(state.controller.connectedDevice?.id, _Ring.id);
      expect(state.controller.isWearableRecovering, isFalse);
      expect(
        state.ring.operations.where((value) => value == 'connect').length,
        2,
      );
    },
  );

  test(
    'search suspends recovery and leaving it resumes the saved target',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final state = await setup();
      final restores = state.ring.restoreCount;
      await state.controller.scanDevices();
      state.ring.source.add(
        WearableEvent(type: 'reconnected', payload: _Ring.device.toJson()),
      );
      await _settle();
      expect(state.controller.connectedDevice, isNull);
      expect(state.ring.restoreCount, restores);
      await state.controller.stopDeviceScan();
      await _settle();
      expect(state.ring.restoreCount, greaterThan(restores));
      expect(state.controller.isWearableRecovering, isTrue);
    },
  );
}

Future<void> _settle() async {
  for (var index = 0; index < 8; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Api extends Fake implements SaydianApi {
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];
}

class _Ring extends Fake
    implements
        WearableBridge,
        WearableConnectionRecoveryBridge,
        WearableBindingManagementBridge {
  static const id = 'qring:11111111-2222-4333-8444-555555555555';
  static const device = DeviceInfo(id: id, name: 'R21');
  final source = StreamController<WearableEvent>.broadcast();
  final operations = <String>[];
  final contexts = <String?>[];
  bool forgotten = false;
  int restoreCount = 0;
  bool failDisconnect = false;
  Completer<void>? delayedDisconnect;
  final disconnectStarted = Completer<void>();
  @override
  Stream<WearableEvent> get events => source.stream;
  @override
  Future<void> setRecoveryContext({
    required String? ownerKey,
    required WearableUserProfile profile,
  }) async {
    contexts.add(ownerKey);
  }

  @override
  Future<DeviceInfo?> readRememberedDevice() async => forgotten ? null : device;
  @override
  Future<DeviceInfo?> prepareRememberedDevice() async {
    operations.add('prepare');
    return forgotten ? null : device;
  }

  @override
  Future<void> forgetRememberedDevice() async {
    operations.add('forget');
    forgotten = true;
  }

  @override
  Future<DeviceInfo?> restoreConnection({
    required WearableUserProfile profile,
  }) async {
    restoreCount++;
    return null;
  }

  @override
  Future<List<DeviceInfo>> scanDevices() async => const [];
  @override
  Future<void> stopScan() async {}
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    operations.add('connect');
  }

  @override
  Future<void> disconnect() async {
    operations.add('disconnect');
    if (!disconnectStarted.isCompleted) disconnectStarted.complete();
    if (failDisconnect) throw StateError('native disconnect failed');
    await delayedDisconnect?.future;
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(metrics: {});
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];
  @override
  Future<List<SportRecord>> readSportRecords() async => const [];
}

class _LegacyRing extends _Ring
    implements WearableRememberedRecoveryEligibilityBridge {
  bool confirmed = false;
  bool failHandshake = false;
  @override
  Future<bool> canAutomaticallyRecoverRememberedDevice() async => confirmed;
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    if (failHandshake) throw StateError('legacy handshake failed');
    await super.connect(deviceId, profile: profile);
    confirmed = true;
  }
}
