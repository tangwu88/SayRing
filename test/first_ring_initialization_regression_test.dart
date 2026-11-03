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
    _PendingInitializationRing ring, {
    MemorySessionVault? vault,
    Session? owner,
  }) async {
    final controller = AppController(
      (vault ?? MemorySessionVault())..privacyConsentGranted = true,
      api,
      MemoryHealthStore(),
      ring,
    );
    addTearDown(controller.dispose);
    addTearDown(ring.source.close);
    await controller.initialize();
    controller.session = owner ?? _owner;
    ring.ownerKey = controller.homeHealthCardOwner;
    return controller;
  }

  test(
    'prior binding proof releases an old unknown decision without a reset',
    () async {
      final vault = MemorySessionVault();
      final api = _RecoverableBindingApi()
        ..failDecision = true
        ..priorConfirmed = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring, vault: vault);
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isFalse);
      expect(vault.ringInitializationStages, isEmpty);
      expect(api.firstBindingCalls, 1);
      expect(api.historyChecks, 1);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 1);
    },
  );

  test(
    'unconfirmed prior history leaves the decision and history closed',
    () async {
      final vault = MemorySessionVault();
      final api = _RecoverableBindingApi()..failDecision = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring, vault: vault);
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(vault.ringInitializationStages.values, [
        RingInitializationStage.decisionUnknown,
      ]);
      expect(api.historyChecks, 1);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 0);
    },
  );

  test(
    'manual sync retries only the read-only proof then imports without reconnect',
    () async {
      final api = _RecoverableBindingApi()..failDecision = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring);
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.canRetryDeviceSyncPreparation, isTrue);
      api.priorConfirmed = true;
      expect(await controller.syncDeviceData(), isTrue);
      expect(controller.isRingInitializationPending, isFalse);
      expect(api.historyChecks, 2);
      expect(api.firstBindingCalls, 1);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 1);
      expect(controller.connectedDevice?.id, _device.id);
    },
  );

  test(
    'manual proof retry reports expired login without disconnecting or importing',
    () async {
      final api = _RecoverableBindingApi()..failDecision = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring);
      await controller.connectDevice(_device);
      await _settle();
      api.historyError = const ApiException('Expired', statusCode: 401);
      expect(await controller.syncDeviceData(), isFalse);
      expect(controller.errorMessage, '登录已过期，请重新登录后同步');
      expect(controller.isRingInitializationPending, isTrue);
      expect(controller.connectedDevice?.id, _device.id);
      expect(api.firstBindingCalls, 1);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 0);
      expect(controller.isDeviceSyncPreparing, isFalse);
    },
  );

  test(
    'another sync request cannot duplicate an in-flight history proof',
    () async {
      final delayed = Completer<bool>();
      final api = _RecoverableBindingApi()
        ..failDecision = true
        ..historyResult = delayed;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring);
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isDeviceSyncPreparing, isTrue);
      expect(await controller.syncDeviceData(), isFalse);
      expect(api.historyChecks, 1);
      delayed.complete(false);
      await _settle();
      expect(controller.isDeviceSyncPreparing, isFalse);
      expect(controller.isRingInitializationPending, isTrue);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 0);
    },
  );

  test(
    'old proof after an account change cannot release a persisted guard',
    () async {
      final vault = MemorySessionVault();
      final delayed = Completer<bool>();
      final api = _RecoverableBindingApi()
        ..failDecision = true
        ..historyResult = delayed;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring, vault: vault);
      await controller.connectDevice(_device);
      await _settle();
      expect(api.historyChecks, 1);
      controller.session = Session(
        accessToken: 'other',
        refreshToken: 'other',
        expiresAt: DateTime.utc(2099),
        memberId: 'other-owner',
        displayName: 'Other',
        accountKey: 'global:member:other-owner',
      );
      delayed.complete(true);
      await _settle();
      expect(vault.ringInitializationStages.values, [
        RingInitializationStage.decisionUnknown,
      ]);
      expect(ring.historyReads, 0);
      expect(ring.resetCalls, 0);
    },
  );

  test(
    'prior history proof never replaces an ambiguous reset receipt',
    () async {
      final vault = MemorySessionVault();
      final api = _RecoverableBindingApi()..priorConfirmed = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..saved = _device;
      final controller = await setup(api, ring, vault: vault);
      await vault.writeRingInitializationStage(
        controller.homeHealthCardOwner,
        _device.id,
        RingInitializationStage.resetAttempted,
      );
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(api.historyChecks, 0);
      expect(vault.ringInitializationStages.values, [
        RingInitializationStage.resetAttempted,
      ]);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 0);
    },
  );

  test(
    'native pending initialization cannot be bypassed by prior history',
    () async {
      final api = _RecoverableBindingApi()
        ..failDecision = true
        ..priorConfirmed = true;
      final ring = _PendingInitializationRing();
      final controller = await setup(api, ring);
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(api.historyChecks, 0);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 0);
    },
  );

  test(
    'automatic recovery can reconcile a previously unknown old-member decision',
    () async {
      final api = _RecoverableBindingApi()..failDecision = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring);
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      api.priorConfirmed = true;
      ring.source.add(
        WearableEvent(type: 'disconnected', payload: {'deviceId': _device.id}),
      );
      await _settle();
      ring.source.add(
        WearableEvent(type: 'reconnected', payload: _device.toJson()),
      );
      await _settle();
      expect(controller.isRingInitializationPending, isFalse);
      expect(api.firstBindingCalls, 1);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 1);
    },
  );

  test(
    'unreadable local guard cannot be reconciled as a known lost decision',
    () async {
      final api = _RecoverableBindingApi()..priorConfirmed = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..saved = _device;
      final controller = await setup(
        api,
        ring,
        vault: _UnavailableGuardVault(),
      );
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(api.historyChecks, 0);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 0);
    },
  );

  test(
    'lost first decision survives reconnect without replay or import',
    () async {
      final api = _ExistingBindingApi()..failDecision = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring);
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(ring.historyReads, 0);
      api.failDecision = false;
      await controller.reconnectDevice();
      await _settle();
      expect(controller.connectedDevice?.id, _device.id);
      expect(controller.isRingInitializationPending, isTrue);
      expect(await controller.syncDeviceData(), isFalse);
      expect(api.firstBindingCalls, 1);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 0);
    },
  );

  test(
    'new controller reloads lost decision for same owner and target',
    () async {
      final vault = MemorySessionVault();
      final api = _ExistingBindingApi()..failDecision = true;
      final firstRing = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final first = await setup(api, firstRing, vault: vault);
      await first.connectDevice(_device);
      await first.disconnectDevice();
      final nextRing = _PendingInitializationRing()
        ..initializationStatus = null
        ..saved = _device;
      final next = await setup(api, nextRing, vault: vault);
      await next.connectDevice(_device);
      await _settle();
      expect(next.isRingInitializationPending, isTrue);
      expect(api.firstBindingCalls, 1);
      expect(nextRing.resetCalls, 0);
      expect(nextRing.historyReads, 0);
    },
  );

  test(
    'automatic recovery also reloads unresolved decision before reading',
    () async {
      final api = _ExistingBindingApi()..failDecision = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring);
      await controller.connectDevice(_device);
      ring.source.add(
        WearableEvent(type: 'disconnected', payload: {'deviceId': _device.id}),
      );
      await _settle();
      ring.source.add(
        WearableEvent(type: 'reconnected', payload: _device.toJson()),
      );
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(ring.historyReads, 0);
      expect(api.firstBindingCalls, 1);
    },
  );

  test(
    'completion cannot erase a lost server decision after restart',
    () async {
      final vault = MemorySessionVault();
      final ring = _PendingInitializationRing()
        ..initializationStatus = 'complete'
        ..saved = _device;
      final api = _ExistingBindingApi();
      final controller = await setup(api, ring, vault: vault);
      await vault.writeRingInitializationStage(
        controller.homeHealthCardOwner,
        _device.id,
        RingInitializationStage.decisionUnknown,
      );
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(ring.historyReads, 0);
      expect(api.firstBindingCalls, 0);
    },
  );

  test(
    'ambiguous reset is never dispatched again on reconnect or restart',
    () async {
      final vault = MemorySessionVault();
      final api = _ExistingBindingApi()..shouldClear = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true
        ..failReset = true;
      final first = await setup(api, ring, vault: vault);
      await first.connectDevice(_device);
      await first.reconnectDevice();
      await _settle();
      expect(ring.resetCalls, 1);
      expect(ring.historyReads, 0);
      expect(first.isRingInitializationPending, isTrue);
      await first.disconnectDevice();
      final nextRing = _PendingInitializationRing()
        ..initializationStatus = null
        ..saved = _device;
      final next = await setup(api, nextRing, vault: vault);
      await next.connectDevice(_device);
      await _settle();
      expect(next.isRingInitializationPending, isTrue);
      expect(nextRing.resetCalls, 0);
      expect(nextRing.historyReads, 0);
      expect(api.firstBindingCalls, 1);
    },
  );

  test(
    'confirmed reset completion clears only the matching durable guard',
    () async {
      final vault = MemorySessionVault();
      final api = _ExistingBindingApi()..shouldClear = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring, vault: vault);
      await controller.connectDevice(_device);
      expect(ring.resetCalls, 1);
      ring.initializationStatus = 'complete';
      await controller.reconnectDevice();
      await _settle();
      expect(controller.isRingInitializationPending, isFalse);
      expect(ring.historyReads, greaterThan(0));
      expect(ring.resetCalls, 1);
      expect(vault.ringInitializationStages, isEmpty);
    },
  );

  test(
    'pending owner and target do not block another member or target',
    () async {
      final vault = MemorySessionVault();
      final api = _ExistingBindingApi()..failDecision = true;
      final ring = _PendingInitializationRing()..initializationStatus = null;
      final first = await setup(api, ring, vault: vault);
      await first.connectDevice(_device);
      await first.disconnectDevice();
      api.failDecision = false;
      final otherRing = _PendingInitializationRing()
        ..initializationStatus = null
        ..saved = _device;
      final other = await setup(
        api,
        otherRing,
        vault: vault,
        owner: Session(
          accessToken: 'other-test-token',
          refreshToken: 'other-test-refresh',
          expiresAt: DateTime.utc(2099),
          memberId: 'other-owner',
          displayName: 'Other',
          accountKey: 'global:member:other-owner',
        ),
      );
      await other.connectDevice(_device);
      await _settle();
      expect(other.isRingInitializationPending, isFalse);
      expect(otherRing.historyReads, 1);
      const replacement = DeviceInfo(
        id: 'qring:99999999-2222-4333-8444-555555555555',
        name: 'R21_TEST',
      );
      await first.connectDevice(replacement);
      await _settle();
      expect(first.isRingInitializationPending, isFalse);
      expect(ring.historyReads, 1);
      expect(vault.ringInitializationStages.values, [
        RingInitializationStage.decisionUnknown,
      ]);
    },
  );

  test(
    'failed guard read does not authorize sync or a destructive request',
    () async {
      final api = _ExistingBindingApi()..shouldClear = true;
      final ring = _PendingInitializationRing()..initializationStatus = null;
      final controller = await setup(
        api,
        ring,
        vault: _UnavailableGuardVault(),
      );
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.connectedDevice?.id, _device.id);
      expect(controller.isRingInitializationPending, isTrue);
      expect(api.firstBindingCalls, 0);
      expect(ring.resetCalls, 0);
      expect(ring.historyReads, 0);
    },
  );

  test(
    'history-only clear ACK resumes after a fresh CoolWear handshake',
    () async {
      const coolwear = DeviceInfo(
        id: 'coolwear:AA:BB:CC:DD:EE:FF',
        name: 'R7 Pro',
      );
      final vault = MemorySessionVault();
      final api = _ExistingBindingApi()..shouldClear = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..clearResult = RingDataClearResult.acknowledged;
      final controller = await setup(api, ring, vault: vault);
      await controller.connectDevice(coolwear);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(ring.historyReads, 0);
      expect(vault.ringInitializationStages.values, [
        RingInitializationStage.historyClearAcknowledged,
      ]);
      await controller.disconnectDevice();
      await controller.connectDevice(coolwear);
      await _settle();
      expect(controller.isRingInitializationPending, isFalse);
      expect(await controller.syncDeviceData(), isTrue);
      expect(ring.historyReads, 1);
      expect(ring.resetCalls, 1);
      expect(api.firstBindingCalls, 1);
      expect(vault.ringInitializationStages, isEmpty);
    },
  );

  test(
    'history-only dispatch without ACK remains guarded on reconnect',
    () async {
      const coolwear = DeviceInfo(
        id: 'coolwear:AA:BB:CC:DD:EE:FF',
        name: 'R7 Pro',
      );
      final api = _ExistingBindingApi()..shouldClear = true;
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..clearResult = RingDataClearResult.requested;
      final controller = await setup(api, ring);
      await controller.connectDevice(coolwear);
      await controller.disconnectDevice();
      await controller.connectDevice(coolwear);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(ring.resetCalls, 1);
      expect(ring.historyReads, 0);
      expect(api.firstBindingCalls, 1);
    },
  );

  test(
    'late first decision after disconnect cannot reset a retired session',
    () async {
      final api = _ExistingBindingApi()..decision = Completer<bool>();
      final ring = _PendingInitializationRing()
        ..initializationStatus = null
        ..rememberConnections = true;
      final controller = await setup(api, ring);
      final connecting = controller.connectDevice(_device);
      await _settle();
      expect(api.firstBindingCalls, 1);
      await controller.disconnectDevice();
      api.decision!.complete(true);
      await connecting;
      expect(ring.resetCalls, 0);
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.isRingInitializationPending, isTrue);
      expect(ring.historyReads, 0);
      expect(api.firstBindingCalls, 1);
    },
  );

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
  bool failDecision = false;
  bool shouldClear = false;

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
    if (failDecision) throw TimeoutException('Decision response lost');
    return decision?.future ?? shouldClear;
  }
}

class _RecoverableBindingApi extends _ExistingBindingApi
    implements SayRingBindingHistoryApi {
  bool priorConfirmed = false;
  int historyChecks = 0;
  Completer<bool>? historyResult;
  Object? historyError;

  @override
  Future<bool> hasPriorBindingBeforeDevice({
    required Session expectedSession,
    required String deviceId,
  }) async {
    historyChecks++;
    if (historyError case final error?) throw error;
    return historyResult?.future ?? priorConfirmed;
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
  bool rememberConnections = false;
  bool failReset = false;
  RingDataClearResult clearResult = RingDataClearResult.factoryResetRequested;
  DeviceInfo? saved;

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
  Future<DeviceInfo?> readRememberedDevice() async => saved;

  @override
  Future<DeviceInfo?> prepareRememberedDevice() async => saved;

  @override
  Future<void> forgetRememberedDevice() async {}

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connectedDeviceId = deviceId;
    if (rememberConnections) saved = _device;
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
    if (failReset) throw StateError('Reset outcome unknown');
    return clearResult;
  }

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    historyReads++;
    return [];
  }

  @override
  Future<List<SportRecord>> readSportRecords() async => [];
}

class _UnavailableGuardVault extends MemorySessionVault {
  @override
  Future<RingInitializationStage?> readRingInitializationStage(
    String owner,
    String deviceId,
  ) async => throw StateError('Guard storage unreadable');
}
