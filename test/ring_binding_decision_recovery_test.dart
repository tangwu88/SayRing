import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

final _owner = Session(
  accessToken: 'decision-owner-token',
  refreshToken: 'decision-owner-refresh',
  expiresAt: DateTime.utc(2099),
  memberId: 'decision-owner',
  displayName: 'Test',
  accountKey: 'global:member:decision-owner',
);
final _otherOwner = Session(
  accessToken: 'other-decision-owner-token',
  refreshToken: 'other-decision-owner-refresh',
  expiresAt: DateTime.utc(2099),
  memberId: 'other-decision-owner',
  displayName: 'Other',
  accountKey: 'global:member:other-decision-owner',
);
const _ring8 = DeviceInfo(
  id: 'qring:11111111-2222-4333-8444-555555555555',
  name: 'R8_TEST',
  model: 'R8',
);
const _replacement = DeviceInfo(
  id: 'qring:99999999-2222-4333-8444-555555555555',
  name: 'R21_TEST',
  model: 'R21',
);
const _coolwear = DeviceInfo(id: 'coolwear:AA:BB:CC:DD:EE:FF', name: 'R7 Pro');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppController> setup(
    _DecisionApi api,
    _Ring ring,
    MemorySessionVault vault,
  ) async {
    final controller = AppController(
      vault..privacyConsentGranted = true,
      api,
      MemoryHealthStore(),
      ring,
    );
    addTearDown(controller.dispose);
    addTearDown(ring.source.close);
    await controller.initialize();
    controller.session = _owner;
    return controller;
  }

  for (final failure in <String, Object>{
    '401 before submitting': const ApiException('Expired', statusCode: 401),
    '404 before submitting': const ApiException(
      'Missing endpoint',
      statusCode: 404,
    ),
    'network timeout before submitting': TimeoutException(
      'Offline before write',
    ),
  }.entries) {
    test(
      '${failure.key} keeps ready and retries the same operation safely',
      () async {
        final vault = MemorySessionVault();
        final api = _DecisionApi()..firstPostErrorBeforeWrite = failure.value;
        final ring = _Ring();
        final controller = await setup(api, ring, vault);
        await controller.connectDevice(_ring8);
        await _settle();
        expect(controller.connectedDevice?.id, _ring8.id);
        expect(controller.deviceState, DeviceConnectionState.ready);
        expect(controller.capabilities?.supportsHistorySync, isTrue);
        expect(controller.canRetryDeviceSyncPreparation, isTrue);
        expect(controller.isRingInitializationPending, isTrue);
        expect(vault.ringInitializationStages.values, [
          RingInitializationStage.decisionUnknown,
        ]);
        expect(api.posts, hasLength(1));
        expect(api.ledger, isEmpty);
        final op = api.posts.single.operationId;
        expect(isValidRingInitializationOperationId(op), isTrue);
        expect(vault.ringInitializationOperationIds.values, [op]);
        // 登录/网络恢复，只读回执证明原请求未提交，按原编号重试。
        api.readAllowed = true;
        expect(await controller.syncDeviceData(), isTrue);
        await _settle();
        expect(api.statusesRead, [RingBindingDecisionStatus.notFound]);
        expect(api.posts, hasLength(2));
        expect(api.posts.map((request) => request.operationId).toSet(), {op});
        expect(
          api.posts.every((request) => request.deviceId == _ring8.id),
          isTrue,
        );
        expect(
          api.posts.every((request) => request.ownerId == _owner.memberId),
          isTrue,
        );
        expect(api.legacyFirstBindingCalls, 0);
        expect(controller.isRingInitializationPending, isFalse);
        expect(vault.ringInitializationStages, isEmpty);
        expect(vault.ringInitializationOperationIds, isEmpty);
        expect(ring.clearCalls, 0);
        expect(ring.historyReads, 1);
        expect(ring.connectCalls, 1);
        expect(ring.disconnectCalls, 0);
      },
    );
  }

  test(
    'same old R8 lost preserve response is read without another decision POST',
    () async {
      final vault = MemorySessionVault();
      final api = _DecisionApi()..loseFirstResponse = true;
      final ring = _Ring();
      final controller = await setup(api, ring, vault);
      await controller.connectDevice(_ring8);
      await _settle();
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.isRingInitializationPending, isTrue);
      expect(api.posts, hasLength(1));
      expect(api.ledger.values, [RingBindingDecisionStatus.preserve]);
      final op = api.posts.single.operationId;
      api.readAllowed = true;
      expect(await controller.syncDeviceData(), isTrue);
      await _settle();
      expect(api.statusesRead, [RingBindingDecisionStatus.preserve]);
      expect(api.reads.last.operationId, op);
      expect(api.posts, hasLength(1));
      expect(api.legacyProofReads, 0);
      expect(api.legacyFirstBindingCalls, 0);
      expect(controller.isRingInitializationPending, isFalse);
      expect(ring.clearCalls, 0);
      expect(ring.historyReads, 1);
    },
  );

  test(
    'clear-issued receipt never releases guard or replays the clear grant',
    () async {
      final vault = MemorySessionVault();
      final api = _DecisionApi()
        ..shouldClear = true
        ..loseFirstResponse = true
        ..readAllowed = true;
      final ring = _Ring();
      final controller = await setup(api, ring, vault);
      await controller.connectDevice(_ring8);
      await _settle();
      for (var retry = 0; retry < 3; retry++) {
        expect(await controller.syncDeviceData(), isFalse);
      }
      await _settle();
      expect(api.posts, hasLength(1));
      expect(
        api.statusesRead,
        everyElement(RingBindingDecisionStatus.clearIssued),
      );
      expect(controller.isRingInitializationPending, isTrue);
      expect(vault.ringInitializationStages.values, [
        RingInitializationStage.decisionUnknown,
      ]);
      expect(vault.ringInitializationOperationIds, hasLength(1));
      expect(ring.clearCalls, 0);
      expect(ring.historyReads, 0);
      expect(controller.connectedDevice?.id, _ring8.id);
      expect(controller.deviceState, DeviceConnectionState.ready);
    },
  );

  test(
    'legacy unknown without operation never invents a fresh binding operation',
    () async {
      final vault = MemorySessionVault();
      final api = _DecisionApi()..readAllowed = true;
      final ring = _Ring()..saved = _ring8;
      final controller = await setup(api, ring, vault);
      await vault.writeRingInitializationStage(
        controller.homeHealthCardOwner,
        _ring8.id,
        RingInitializationStage.decisionUnknown,
      );
      await controller.connectDevice(_ring8);
      await _settle();
      expect(await controller.syncDeviceData(), isFalse);
      expect(api.legacyProofReads, 2);
      expect(api.reads, isEmpty);
      expect(api.posts, isEmpty);
      expect(vault.ringInitializationOperationIds, isEmpty);
      expect(controller.isRingInitializationPending, isTrue);
      expect(ring.clearCalls, 0);
      expect(ring.historyReads, 0);
    },
  );

  test(
    'legacy unknown may still use a positive conservative prior-binding proof',
    () async {
      final vault = MemorySessionVault();
      final api = _DecisionApi()..priorConfirmed = true;
      final ring = _Ring()..saved = _ring8;
      final controller = await setup(api, ring, vault);
      await vault.writeRingInitializationStage(
        controller.homeHealthCardOwner,
        _ring8.id,
        RingInitializationStage.decisionUnknown,
      );
      await controller.connectDevice(_ring8);
      await _settle();
      expect(api.legacyProofReads, 1);
      expect(api.reads, isEmpty);
      expect(api.posts, isEmpty);
      expect(controller.isRingInitializationPending, isFalse);
      expect(ring.clearCalls, 0);
      expect(ring.historyReads, 1);
    },
  );

  test(
    'new member not-found retry grants only one clear and completes ACK reconnect',
    () async {
      final vault = MemorySessionVault();
      final api = _DecisionApi()
        ..firstPostErrorBeforeWrite = const ApiException(
          'Expired',
          statusCode: 401,
        )
        ..shouldClear = true;
      final ring = _Ring();
      final controller = await setup(api, ring, vault);
      await controller.connectDevice(_coolwear);
      await _settle();
      final originalOp = api.posts.single.operationId;
      expect(ring.clearCalls, 0);
      api.readAllowed = true;
      // 本次只完成初始化和新握手，不能把旧握手缓存当同步成功。
      expect(await controller.syncDeviceData(), isFalse);
      await _settle();
      expect(api.posts, hasLength(2));
      expect(api.posts.map((request) => request.operationId).toSet(), {
        originalOp,
      });
      expect(ring.clearCalls, 1);
      expect(ring.connectCalls, 2);
      expect(ring.disconnectCalls, 1);
      expect(ring.forgetCalls, 0);
      expect(ring.historyReads, 1);
      expect(controller.connectedDevice?.id, _coolwear.id);
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.isRingInitializationPending, isFalse);
      expect(await controller.syncDeviceData(), isTrue);
      expect(ring.historyReads, 2);
      expect(ring.clearCalls, 1);
      expect(api.posts, hasLength(2));
    },
  );

  test(
    'persisted operation survives controller restart and preserves the same old R8',
    () async {
      final vault = MemorySessionVault();
      final api = _DecisionApi()..loseFirstResponse = true;
      final firstRing = _Ring();
      final first = await setup(api, firstRing, vault);
      await first.connectDevice(_ring8);
      await _settle();
      final originalOp = api.posts.single.operationId;
      await first.disconnectDevice();
      api.readAllowed = true;
      final secondRing = _Ring()..saved = _ring8;
      final second = await setup(api, secondRing, vault);
      await second.connectDevice(_ring8);
      await _settle();
      expect(api.posts, hasLength(1));
      expect(api.reads.last.operationId, originalOp);
      expect(second.isRingInitializationPending, isFalse);
      expect(secondRing.clearCalls, 0);
      expect(secondRing.historyReads, 1);
    },
  );

  test(
    'late preserve receipt cannot release the former target guard',
    () async {
      final vault = MemorySessionVault();
      final delayed = Completer<RingBindingDecisionStatus>();
      final api = _DecisionApi()
        ..firstPostErrorBeforeWrite = const ApiException(
          'Expired',
          statusCode: 401,
        )
        ..readResult = delayed;
      final ring = _Ring();
      final controller = await setup(api, ring, vault);
      await controller.connectDevice(_ring8);
      await _settle();
      expect(controller.isDeviceSyncPreparing, isTrue);
      final owner = controller.homeHealthCardOwner;
      final originalOp = api.posts.single.operationId;
      await controller.disconnectDevice();
      await controller.connectDevice(_replacement);
      await _settle();
      expect(controller.connectedDevice?.id, _replacement.id);
      final newReads = ring.historyReads;
      delayed.complete(RingBindingDecisionStatus.preserve);
      await _settle();
      expect(controller.connectedDevice?.id, _replacement.id);
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(
        await vault.readRingInitializationStage(owner, _ring8.id),
        RingInitializationStage.decisionUnknown,
      );
      expect(
        await vault.readRingInitializationOperationId(owner, _ring8.id),
        originalOp,
      );
      expect(ring.historyReads, newReads);
      expect(ring.clearCalls, 0);
      expect(api.posts, hasLength(1));
    },
  );

  test('late preserve receipt cannot cross an account transition', () async {
    final vault = MemorySessionVault();
    final delayed = Completer<RingBindingDecisionStatus>();
    final api = _DecisionApi()
      ..firstPostErrorBeforeWrite = const ApiException(
        'Expired',
        statusCode: 401,
      )
      ..readResult = delayed;
    final ring = _Ring();
    final controller = await setup(api, ring, vault);
    await controller.connectDevice(_ring8);
    await _settle();
    final oldOwner = controller.homeHealthCardOwner;
    final originalOp = api.posts.single.operationId;
    await controller.logout();
    controller.session = _otherOwner;
    delayed.complete(RingBindingDecisionStatus.preserve);
    await _settle();
    expect(controller.session, same(_otherOwner));
    expect(controller.connectedDevice, isNull);
    expect(
      await vault.readRingInitializationStage(oldOwner, _ring8.id),
      RingInitializationStage.decisionUnknown,
    );
    expect(
      await vault.readRingInitializationOperationId(oldOwner, _ring8.id),
      originalOp,
    );
    expect(ring.clearCalls, 0);
    expect(ring.historyReads, 0);
  });

  test(
    'late first clear grant after not-found retry cannot reset a retired connection',
    () async {
      final vault = MemorySessionVault();
      final api = _DecisionApi()
        ..firstPostErrorBeforeWrite = const ApiException(
          'Expired',
          statusCode: 401,
        )
        ..readAllowed = true
        ..retryPostResult = Completer<bool>();
      final ring = _Ring();
      final controller = await setup(api, ring, vault);
      await controller.connectDevice(_ring8);
      await _settle();
      expect(api.posts, hasLength(2));
      final owner = controller.homeHealthCardOwner;
      await controller.disconnectDevice();
      api.retryPostResult!.complete(true);
      await _settle();
      expect(controller.connectedDevice, isNull);
      expect(controller.deviceState, DeviceConnectionState.disconnected);
      expect(
        await vault.readRingInitializationStage(owner, _ring8.id),
        RingInitializationStage.decisionUnknown,
      );
      expect(ring.clearCalls, 0);
      expect(ring.historyReads, 0);
      expect(ring.connectCalls, 1);
    },
  );

  test(
    'operation persistence failure never submits or clears a ring',
    () async {
      final vault = _FailOperationWriteVault();
      final api = _DecisionApi()..readAllowed = true;
      final ring = _Ring();
      final controller = await setup(api, ring, vault);
      await controller.connectDevice(_ring8);
      await _settle();
      expect(await controller.syncDeviceData(), isFalse);
      expect(controller.isRingInitializationPending, isTrue);
      expect(controller.canRetryDeviceSyncPreparation, isTrue);
      expect(api.posts, isEmpty);
      expect(api.reads, isEmpty);
      expect(api.legacyProofReads, 0);
      expect(vault.ringInitializationOperationIds, isEmpty);
      expect(ring.clearCalls, 0);
      expect(ring.historyReads, 0);
    },
  );

  test(
    'failed guard deletion keeps the operation and permits only the same receipt retry',
    () async {
      final vault = _FailGuardDeleteVault();
      final api = _DecisionApi()..loseFirstResponse = true;
      final ring = _Ring();
      final controller = await setup(api, ring, vault);
      await controller.connectDevice(_ring8);
      await _settle();
      final originalOp = api.posts.single.operationId;
      api.readAllowed = true;
      expect(await controller.syncDeviceData(), isFalse);
      expect(controller.isRingInitializationPending, isTrue);
      expect(vault.ringInitializationOperationIds.values, [originalOp]);
      expect(ring.historyReads, 0);
      expect(ring.clearCalls, 0);
      vault.failDelete = false;
      expect(await controller.syncDeviceData(), isTrue);
      expect(controller.isRingInitializationPending, isFalse);
      expect(api.posts, hasLength(1));
      expect(
        api.reads.every((request) => request.operationId == originalOp),
        isTrue,
      );
      expect(ring.historyReads, 1);
      expect(ring.clearCalls, 0);
    },
  );

  test(
    'reset-attempt persistence failure never dispatches clear and cannot replay its grant',
    () async {
      final vault = _FailResetStageVault();
      final api = _DecisionApi()
        ..shouldClear = true
        ..readAllowed = true;
      final ring = _Ring();
      final controller = await setup(api, ring, vault);
      await controller.connectDevice(_ring8);
      await _settle();
      expect(api.posts, hasLength(1));
      expect(api.ledger.values, [RingBindingDecisionStatus.clearIssued]);
      expect(ring.clearCalls, 0);
      await controller.disconnectDevice();
      await controller.connectDevice(_ring8);
      await _settle();
      expect(await controller.syncDeviceData(), isFalse);
      expect(controller.isRingInitializationPending, isTrue);
      expect(api.posts, hasLength(1));
      expect(
        api.statusesRead,
        everyElement(RingBindingDecisionStatus.clearIssued),
      );
      expect(ring.clearCalls, 0);
      expect(ring.historyReads, 0);
    },
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

typedef _Request = ({String ownerId, String deviceId, String operationId});

class _DecisionApi extends Fake
    implements
        SaydianApi,
        SaydianDeviceBindingApi,
        SayRingFirstBindingApi,
        SayRingBindingHistoryApi,
        SayRingBindingDecisionApi {
  final posts = <_Request>[];
  final reads = <_Request>[];
  final statusesRead = <RingBindingDecisionStatus>[];
  final ledger = <String, RingBindingDecisionStatus>{};
  bool shouldClear = false;
  bool readAllowed = false;
  bool loseFirstResponse = false;
  bool priorConfirmed = false;
  Object? firstPostErrorBeforeWrite;
  Completer<RingBindingDecisionStatus>? readResult;
  Completer<bool>? retryPostResult;
  int legacyFirstBindingCalls = 0;
  int legacyProofReads = 0;
  int normalReports = 0;
  String key(_Request request) =>
      '${request.ownerId}\u0000${request.deviceId}\u0000${request.operationId}';
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
  }) async {
    normalReports++;
  }

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
    legacyFirstBindingCalls++;
    throw StateError('Operation-capable clients must not use the legacy POST');
  }

  @override
  Future<bool> hasPriorBindingBeforeDevice({
    required Session expectedSession,
    required String deviceId,
  }) async {
    legacyProofReads++;
    return priorConfirmed;
  }

  @override
  Future<RingBindingDecisionStatus> readRingBindingDecision({
    required Session expectedSession,
    required String deviceId,
    required String operationId,
  }) async {
    final request = (
      ownerId: expectedSession.memberId,
      deviceId: deviceId,
      operationId: operationId,
    );
    reads.add(request);
    await Future<void>.delayed(Duration.zero);
    if (readResult case final result?) return result.future;
    if (!readAllowed) throw const ApiException('Expired', statusCode: 401);
    final status = ledger[key(request)] ?? RingBindingDecisionStatus.notFound;
    statusesRead.add(status);
    return status;
  }

  @override
  Future<bool> reportFirstRingBindingDecision({
    required Session expectedSession,
    required String deviceId,
    required String operationId,
    required String vendor,
    required String model,
    required String displayName,
    String? firmware,
    String? macAddress,
    List<String> capabilities = const [],
  }) async {
    final request = (
      ownerId: expectedSession.memberId,
      deviceId: deviceId,
      operationId: operationId,
    );
    posts.add(request);
    // 必须真正异步失败，才能捕获 return Future 未 await 导致 catch 失效的问题。
    await Future<void>.delayed(Duration.zero);
    if (posts.length == 1) {
      if (firstPostErrorBeforeWrite case final error?) throw error;
    }
    final previous = ledger[key(request)];
    if (previous == RingBindingDecisionStatus.clearIssued) {
      throw const ApiException('Grant already issued', statusCode: 409);
    }
    if (previous == RingBindingDecisionStatus.preserve) return false;
    final clear = posts.length > 1 && retryPostResult != null
        ? await retryPostResult!.future
        : shouldClear;
    ledger[key(request)] = clear
        ? RingBindingDecisionStatus.clearIssued
        : RingBindingDecisionStatus.preserve;
    if (posts.length == 1 && loseFirstResponse) {
      throw TimeoutException('Committed response lost');
    }
    return clear;
  }
}

class _Ring extends Fake
    implements
        WearableBridge,
        WearableBindingManagementBridge,
        WearableRingDataClearBridge {
  final source = StreamController<WearableEvent>.broadcast(sync: true);
  DeviceInfo? saved;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int clearCalls = 0;
  int historyReads = 0;
  int forgetCalls = 0;
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
    saved = deviceId == _ring8.id
        ? _ring8
        : deviceId == _coolwear.id
        ? _coolwear
        : _replacement;
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
    return RingDataClearResult.acknowledged;
  }

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    historyReads++;
    return [];
  }

  @override
  Future<List<SportRecord>> readSportRecords() async => [];
}

class _FailOperationWriteVault extends MemorySessionVault {
  @override
  Future<void> writeRingInitializationRequest(
    String owner,
    String deviceId,
    String operationId,
  ) async => throw StateError('Synthetic operation persistence failure');
}

class _FailGuardDeleteVault extends MemorySessionVault {
  bool failDelete = true;
  @override
  Future<void> clearRingInitializationStage(
    String owner,
    String deviceId,
  ) async {
    if (failDelete) throw StateError('Synthetic guard deletion failure');
    await super.clearRingInitializationStage(owner, deviceId);
  }
}

class _FailResetStageVault extends MemorySessionVault {
  @override
  Future<void> writeRingInitializationStage(
    String owner,
    String deviceId,
    RingInitializationStage stage,
  ) async {
    if (stage == RingInitializationStage.resetAttempted) {
      throw StateError('Synthetic reset-attempt persistence failure');
    }
    await super.writeRingInitializationStage(owner, deviceId, stage);
  }
}
