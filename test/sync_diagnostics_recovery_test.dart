import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

const device = DeviceInfo(
  id: 'coolwear:SYNTHETIC-R7P',
  name: 'R7 Pro',
  model: 'R7Pro',
);

class Remote extends Fake
    implements
        SaydianApi,
        SaydianDeviceBindingApi,
        SayRingFirstBindingApi,
        SayRingBindingDecisionApi {
  int firstDecisions = 0;
  bool readFails = true, firstClear = false;
  @override
  Future<List<Map<String, Object?>>> getArticles() async => [];
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
    firstDecisions++;
    return firstClear;
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
    firstDecisions++;
    return firstClear;
  }

  @override
  Future<RingBindingDecisionStatus> readRingBindingDecision({
    required Session expectedSession,
    required String deviceId,
    required String operationId,
  }) async {
    if (readFails) throw const ApiException('Synthetic offline');
    return RingBindingDecisionStatus.notFound;
  }
}

class Ring extends Fake implements WearableBridge, WearableRingDataClearBridge {
  final source = StreamController<WearableEvent>.broadcast();
  int connects = 0, reads = 0, clears = 0;
  @override
  Stream<WearableEvent> get events => source.stream;
  @override
  Future<void> connect(String id, {WearableUserProfile? profile}) async {
    connects++;
  }

  @override
  Future<void> disconnect() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(metrics: {HealthMetric.heartRate});
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    reads++;
    return [];
  }

  @override
  Future<List<SportRecord>> readSportRecords() async => [];
  @override
  Future<void> startMeasurement(HealthMetric metric) async {}
  @override
  Future<void> stopMeasurement(HealthMetric metric) async {}
  @override
  Future<RingDataClearResult> clearRingHistory({
    required String deviceId,
    required String ownerKey,
    bool allowFactoryReset = false,
  }) async {
    clears++;
    return RingDataClearResult.acknowledged;
  }
}

Future<void> settle() async {
  for (var i = 0; i < 60; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<(AppController, Remote, Ring)> setup({
    RingInitializationStage? stage,
    bool connect = true,
  }) async {
    final vault = MemorySessionVault()..privacyConsentGranted = true,
        api = Remote(),
        ring = Ring();
    final app = AppController(vault, api, MemoryHealthStore(), ring);
    addTearDown(app.dispose);
    addTearDown(ring.source.close);
    await app.initialize();
    app.session = Session(
      accessToken: 'synthetic',
      refreshToken: '',
      expiresAt: DateTime.utc(2099),
      memberId: 'synthetic',
      displayName: 'Synthetic',
      accountKey: 'global:synthetic',
    );
    if (stage != null) {
      await vault.writeRingInitializationStage(
        app.homeHealthCardOwner,
        device.id,
        RingInitializationStage.decisionRequired,
      );
      await vault.writeRingInitializationRequest(
        app.homeHealthCardOwner,
        device.id,
        '11111111-1111-4111-8111-111111111111',
      );
      await vault.writeRingInitializationStage(
        app.homeHealthCardOwner,
        device.id,
        stage,
      );
    }
    if (connect) {
      await app.connectDevice(device);
      await settle();
    } else {
      app.rememberedDevice = device;
    }
    return (app, api, ring);
  }

  test(
    'recovery cannot turn a missing server decision into a new clear authorization',
    () async {
      final (app, api, ring) = await setup(
        stage: RingInitializationStage.decisionUnknown,
      );
      expect(app.isRingInitializationPending, isTrue);
      api.readFails = false;
      api.firstClear = true;
      expect(await app.recoverSyncFromDiagnostics(), contains('尚待确认'));
      expect(api.firstDecisions, 0);
      expect(ring.clears, 0);
      expect(ring.reads, 0);
      expect(app.isRingInitializationPending, isTrue);
    },
  );
  test(
    'disconnected first decision is retained without reconnecting or clearing',
    () async {
      final (app, api, ring) = await setup(
        stage: RingInitializationStage.decisionRequired,
        connect: false,
      );
      expect(await app.recoverSyncFromDiagnostics(), contains('尚待确认'));
      expect(ring.connects, 0);
      expect(ring.clears, 0);
      expect(api.firstDecisions, 0);
    },
  );
  test('missing native reset ACK stays guarded during recovery', () async {
    final (app, api, ring) = await setup(
      stage: RingInitializationStage.resetAttempted,
    );
    expect(await app.recoverSyncFromDiagnostics(), contains('尚待确认'));
    expect(ring.clears, 0);
    expect(ring.reads, 0);
    expect(api.firstDecisions, 0);
    expect(app.isRingInitializationPending, isTrue);
  });
  test(
    'ready member retries data reads without another first-binding decision',
    () async {
      final (app, api, ring) = await setup();
      final decisions = api.firstDecisions, reads = ring.reads;
      expect(await app.recoverSyncFromDiagnostics(), contains('检查已完成'));
      expect(ring.reads, reads + 1);
      expect(api.firstDecisions, decisions);
      expect(ring.clears, 0);
    },
  );
  test(
    'remembered existing target can reconnect without first initialization',
    () async {
      final (app, api, ring) = await setup(connect: false);
      api.firstClear = true;
      await app.recoverSyncFromDiagnostics();
      await settle();
      expect(ring.connects, 1);
      expect(ring.clears, 0);
      expect(api.firstDecisions, 0);
    },
  );
  test('recovery does not interrupt a manual measurement', () async {
    final (app, api, ring) = await setup();
    expect(await app.startMeasurement(HealthMetric.heartRate), isTrue);
    final reads = ring.reads;
    expect(await app.recoverSyncFromDiagnostics(), contains('结束当前'));
    expect(ring.reads, reads);
    expect(ring.clears, 0);
    await app.stopMeasurement(HealthMetric.heartRate);
  });
}
