import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';

final _owner = Session(
  accessToken: 'recovery-owner-token',
  refreshToken: 'recovery-owner-refresh',
  expiresAt: DateTime.utc(2099),
  memberId: 'recovery-owner',
  displayName: 'Test',
  accountKey: 'global:member:recovery-owner',
);
final _otherOwner = Session(
  accessToken: 'other-owner-token',
  refreshToken: 'other-owner-refresh',
  expiresAt: DateTime.utc(2099),
  memberId: 'other-owner',
  displayName: 'Other',
  accountKey: 'global:member:other-owner',
);
const _coolwear = DeviceInfo(id: 'coolwear:AA:BB:CC:DD:EE:FF', name: 'R7 Pro');
const _replacement = DeviceInfo(
  id: 'qring:99999999-2222-4333-8444-555555555555',
  name: 'R8_TEST',
  model: 'R8',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      null,
    );
  });

  Future<AppController> setup(
    _BindingApi api,
    _Ring ring, {
    MemorySessionVault? vault,
    bool disposeAtTearDown = true,
  }) async {
    final controller = AppController(
      (vault ?? MemorySessionVault())..privacyConsentGranted = true,
      api,
      MemoryHealthStore(),
      ring,
    );
    if (disposeAtTearDown) addTearDown(controller.dispose);
    addTearDown(ring.eventsSource.close);
    await controller.initialize();
    controller.session = _owner;
    return controller;
  }

  Future<AppController> pendingRecovery(
    _BindingApi api,
    _Ring ring,
    _DelayedClearVault vault, {
    bool disposeAtTearDown = true,
  }) async {
    final controller = await setup(
      api,
      ring,
      vault: vault,
      disposeAtTearDown: disposeAtTearDown,
    );
    // 模拟上次已确认的清空回执；本次只测试新握手后的持久状态清理。
    await vault.writeRingInitializationStage(
      controller.homeHealthCardOwner,
      _coolwear.id,
      RingInitializationStage.historyClearAcknowledged,
    );
    ring.eventsSource.add(
      WearableEvent(type: 'reconnected', payload: _coolwear.toJson()),
    );
    await _settle();
    expect(vault.started.isCompleted, isTrue);
    expect(controller.connectedDevice?.id, _coolwear.id);
    return controller;
  }

  for (final platformError in [false, true]) {
    final kind = platformError ? 'platform' : 'general';
    Object failure() => platformError
        ? PlatformException(code: 'VAULT_UNAVAILABLE', message: 'Synthetic')
        : StateError('Synthetic vault failure');

    test(
      '$kind late recovery failure preserves a replacement ready link',
      () async {
        final vault = _DelayedClearVault();
        final api = _BindingApi();
        final ring = _Ring();
        final controller = await pendingRecovery(api, ring, vault);
        await controller.disconnectDevice();
        await controller.connectDevice(_replacement);
        await _settle();
        expect(controller.deviceState, DeviceConnectionState.ready);
        expect(controller.connectedDevice?.id, _replacement.id);
        final currentCapabilities = controller.capabilities;
        controller.errorMessage = 'current session message';
        vault.pending.completeError(failure());
        await _settle();
        expect(controller.connectedDevice?.id, _replacement.id);
        expect(controller.capabilities, same(currentCapabilities));
        expect(controller.deviceState, DeviceConnectionState.ready);
        expect(controller.errorMessage, 'current session message');
        expect(ring.clearCalls, 0);
      },
    );

    test(
      '$kind late recovery failure cannot change a logged-out session',
      () async {
        final vault = _DelayedClearVault();
        final controller = await pendingRecovery(_BindingApi(), _Ring(), vault);
        await controller.logout();
        expect(controller.session, isNull);
        expect(controller.deviceState, DeviceConnectionState.disconnected);
        controller.errorMessage = 'signed out';
        vault.pending.completeError(failure());
        await _settle();
        expect(controller.connectedDevice, isNull);
        expect(controller.deviceState, DeviceConnectionState.disconnected);
        expect(controller.errorMessage, 'signed out');
      },
    );

    test(
      '$kind late recovery failure cannot clear another account link',
      () async {
        final vault = _DelayedClearVault();
        final ring = _Ring();
        final controller = await pendingRecovery(_BindingApi(), ring, vault);
        await controller.logout();
        controller.session = _otherOwner;
        await controller.connectDevice(_replacement);
        await _settle();
        expect(controller.connectedDevice?.id, _replacement.id);
        expect(controller.deviceState, DeviceConnectionState.ready);
        final currentCapabilities = controller.capabilities;
        vault.pending.completeError(failure());
        await _settle();
        expect(controller.session, same(_otherOwner));
        expect(controller.connectedDevice?.id, _replacement.id);
        expect(controller.capabilities, same(currentCapabilities));
        expect(controller.deviceState, DeviceConnectionState.ready);
        expect(controller.errorMessage, isNull);
      },
    );

    test(
      '$kind late recovery failure cannot notify a disposed controller',
      () async {
        final vault = _DelayedClearVault();
        final controller = await pendingRecovery(
          _BindingApi(),
          _Ring(),
          vault,
          disposeAtTearDown: false,
        );
        var notifications = 0;
        controller.addListener(() => notifications++);
        final before = notifications;
        controller.dispose();
        vault.pending.completeError(failure());
        await _settle();
        expect(notifications, before);
        expect(controller.connectedDevice?.id, _coolwear.id);
      },
    );

    test('$kind current recovery failure still reports an error', () async {
      final vault = _DelayedClearVault();
      final controller = await pendingRecovery(_BindingApi(), _Ring(), vault);
      vault.pending.completeError(failure());
      await _settle();
      expect(controller.connectedDevice, isNull);
      expect(controller.capabilities, isNull);
      expect(controller.deviceState, DeviceConnectionState.error);
      expect(controller.errorMessage, isNotEmpty);
      expect(controller.isRingInitializationPending, isTrue);
    });
  }

  testWidgets(
    'CoolWear confirmed ACK automatically reaches a usable sync action',
    (tester) async {
      final vault = MemorySessionVault();
      final api = _BindingApi()..shouldClear = true;
      final ring = _Ring();
      final controller = (await tester.runAsync(
        () => setup(api, ring, vault: vault),
      ))!;
      await tester.runAsync(() async {
        await controller.connectDevice(_coolwear);
        await _settle();
      });
      // 不由测试补调用 disconnect/connect：必须是生产流程自行完成一次新握手。
      expect(ring.connectCalls, 2);
      expect(ring.disconnectCalls, 1);
      expect(ring.forgetCalls, 0);
      expect(ring.clearCalls, 1);
      expect(api.firstBindingCalls, 1);
      expect(controller.connectedDevice?.id, _coolwear.id);
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.isRingInitializationPending, isFalse);
      expect(vault.ringInitializationStages, isEmpty);
      expect(ring.historyReads, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DevicePage(controller: controller)),
        ),
      );
      await tester.pump();
      final sync = find.byKey(const Key('device-sync-data'));
      expect(sync, findsOneWidget);
      expect(tester.widget<FilledButton>(sync).onPressed, isNotNull);
      expect(find.byKey(const Key('device-reconnect')), findsNothing);
      await tester.runAsync(() async {
        expect(await controller.syncDeviceData(), isTrue);
        await _settle();
      });
      expect(ring.historyReads, 2);
      expect(ring.connectCalls, 2);
      expect(ring.clearCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final result in [
    RingDataClearResult.requested,
    RingDataClearResult.factoryResetRequested,
  ]) {
    test(
      'unconfirmed ${result.name} never schedules a CoolWear reconnect',
      () async {
        final api = _BindingApi()..shouldClear = true;
        final ring = _Ring()..clearResult = result;
        final controller = await setup(api, ring);
        await controller.connectDevice(_coolwear);
        await _settle();
        expect(controller.isRingInitializationPending, isTrue);
        expect(ring.connectCalls, 1);
        expect(ring.disconnectCalls, 0);
        expect(ring.clearCalls, 1);
        expect(ring.historyReads, 0);
        expect(ring.forgetCalls, 0);
      },
    );
  }

  test(
    'failed ACK persistence does not schedule a reconnect or repeat clearing',
    () async {
      final vault = _FailAcknowledgementWriteVault();
      final api = _BindingApi()..shouldClear = true;
      final ring = _Ring();
      final controller = await setup(api, ring, vault: vault);
      await controller.connectDevice(_coolwear);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(vault.ringInitializationStages.values, [
        RingInitializationStage.resetAttempted,
      ]);
      expect(ring.connectCalls, 1);
      expect(ring.disconnectCalls, 0);
      expect(ring.clearCalls, 1);
      expect(ring.historyReads, 0);
    },
  );

  test(
    'late ACK after disconnect cannot reconnect the retired target',
    () async {
      final api = _BindingApi()..shouldClear = true;
      final ring = _Ring()..clearResponse = Completer<RingDataClearResult>();
      final controller = await setup(api, ring);
      final connecting = controller.connectDevice(_coolwear);
      await _settle();
      expect(ring.clearCalls, 1);
      await controller.disconnectDevice();
      ring.clearResponse!.complete(RingDataClearResult.acknowledged);
      await connecting;
      await _settle();
      expect(controller.connectedDevice, isNull);
      expect(controller.deviceState, DeviceConnectionState.disconnected);
      expect(ring.connectCalls, 1);
      expect(ring.disconnectCalls, 1);
      expect(ring.clearCalls, 1);
      expect(ring.historyReads, 0);
      api.shouldClear = false;
      await controller.connectDevice(_replacement);
      await _settle();
      expect(controller.connectedDevice?.id, _replacement.id);
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(ring.connectCalls, 2);
      expect(ring.disconnectCalls, 1);
      expect(ring.clearCalls, 1);
    },
  );

  test(
    'late ACK during logout cannot restore the old account connection',
    () async {
      final api = _BindingApi()..shouldClear = true;
      final ring = _Ring()..clearResponse = Completer<RingDataClearResult>();
      final controller = await setup(api, ring);
      final connecting = controller.connectDevice(_coolwear);
      await _settle();
      expect(ring.clearCalls, 1);
      final loggingOut = controller.logout();
      await _settle();
      ring.clearResponse!.complete(RingDataClearResult.acknowledged);
      await connecting;
      await loggingOut;
      await _settle();
      expect(controller.session, isNull);
      expect(controller.connectedDevice, isNull);
      expect(ring.connectCalls, 1);
      expect(ring.clearCalls, 1);
      expect(ring.historyReads, 0);
      expect(ring.forgetCalls, 0);
    },
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _BindingApi extends Fake
    implements SaydianApi, SaydianDeviceBindingApi, SayRingFirstBindingApi {
  bool shouldClear = false;
  int firstBindingCalls = 0;
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
    return shouldClear;
  }
}

class _Ring extends Fake
    implements
        WearableBridge,
        WearableBindingManagementBridge,
        WearableRingDataClearBridge {
  final eventsSource = StreamController<WearableEvent>.broadcast(sync: true);
  DeviceInfo? saved;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int forgetCalls = 0;
  int clearCalls = 0;
  int historyReads = 0;
  RingDataClearResult clearResult = RingDataClearResult.acknowledged;
  Completer<RingDataClearResult>? clearResponse;
  @override
  Stream<WearableEvent> get events => eventsSource.stream;
  @override
  Future<void> setRecoveryContext({
    required String? ownerKey,
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<DeviceInfo?> readRememberedDevice() async => saved;
  @override
  Future<DeviceInfo?> prepareRememberedDevice() async => saved;
  @override
  Future<void> forgetRememberedDevice() async {
    forgetCalls++;
    saved = null;
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connectCalls++;
    saved = deviceId == _coolwear.id ? _coolwear : _replacement;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(
        metrics: {HealthMetric.steps, HealthMetric.sleep},
        supportsHistorySync: true,
      );
  @override
  Future<RingDataClearResult> clearRingHistory({
    required String deviceId,
    required String ownerKey,
    bool allowFactoryReset = false,
  }) async {
    clearCalls++;
    return clearResponse?.future ?? clearResult;
  }

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    historyReads++;
    return [];
  }

  @override
  Future<List<SportRecord>> readSportRecords() async => [];
}

class _DelayedClearVault extends MemorySessionVault {
  final started = Completer<void>();
  final pending = Completer<void>();
  @override
  Future<void> clearRingInitializationStage(
    String owner,
    String deviceId,
  ) async {
    if (deviceId == _coolwear.id) {
      if (!started.isCompleted) started.complete();
      await pending.future;
    }
    await super.clearRingInitializationStage(owner, deviceId);
  }
}

class _FailAcknowledgementWriteVault extends MemorySessionVault {
  @override
  Future<void> writeRingInitializationStage(
    String owner,
    String deviceId,
    RingInitializationStage stage,
  ) async {
    if (stage == RingInitializationStage.historyClearAcknowledged) {
      throw StateError('Synthetic ACK persistence failure');
    }
    await super.writeRingInitializationStage(owner, deviceId, stage);
  }
}
