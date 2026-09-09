import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({AppController controller, _Wearable wearable, MemoryHealthStore store})
  >
  setup() async {
    final wearable = _Wearable();
    final store = MemoryHealthStore();
    final controller = AppController(
      MemorySessionVault(),
      _Api(),
      store,
      wearable,
    );
    addTearDown(controller.dispose);
    addTearDown(wearable.eventsController.close);
    await controller.initialize();
    expect(await controller.login('owner-a', 'test-password'), isTrue);
    await controller.connectDevice(_Wearable.watch);
    await _settle();
    return (controller: controller, wearable: wearable, store: store);
  }

  test(
    'same account reauthentication drains disconnect and freshly connects before sync',
    () async {
      final test = await setup();
      test.wearable.nextHistory = [_record('owned-before-login')];
      await test.controller.syncDeviceData();
      await _settle();
      final syncsBefore = test.wearable.syncCount;
      test.wearable.disconnectResult = Completer<void>();
      final login = test.controller.login('owner-a', 'test-password');
      await test.wearable.disconnectStarted.future;
      expect(test.wearable.connectCount, 1);
      test.wearable.emitRecord(_record('during-disconnect'));
      test.wearable.disconnectResult!.complete();
      expect(await login, isTrue);
      await _settle();
      expect(test.wearable.connectCount, 2);
      expect(test.controller.connectedDevice?.id, _Wearable.watch.id);
      await test.controller.syncDeviceData();
      expect(test.wearable.syncCount, greaterThan(syncsBefore));
      expect(
        (await test.store.recent()).map((r) => r.id),
        contains('owned-before-login'),
      );
      expect(
        (await test.store.recent()).map((r) => r.id),
        isNot(contains('during-disconnect')),
      );
    },
  );

  test(
    'different account rejects stale history, orphan results and native reconnects',
    () async {
      final test = await setup();
      final lateHistory = Completer<List<HealthRecord>>();
      test.wearable.historyResult = lateHistory.future;
      final syncing = test.controller.syncDeviceData();
      expect(await test.controller.login('owner-b', 'test-password'), isTrue);
      lateHistory.complete([_record('old-account-history')]);
      await syncing;
      test.wearable.emitRecord(_record('old-account-event'));
      test.wearable.eventsController.add(
        WearableEvent(type: 'reconnected', payload: _Wearable.watch.toJson()),
      );
      await _settle();
      await test.controller.restoreWearableConnection();
      expect(test.controller.connectedDevice, isNull);
      expect(test.wearable.connectCount, 1);
      test.wearable.eventsController.add(
        const WearableEvent(
          type: 'sportState',
          payload: {'value': 'running', 'mode': 'walking'},
        ),
      );
      await _settle();
      expect(test.controller.activeSport, isNull);
      expect(await test.store.recent(), isEmpty);
      expect(test.controller.healthRecords, isEmpty);
    },
  );

  test(
    'logout fences native callbacks and stops an active measurement before disconnect',
    () async {
      final test = await setup();
      expect(
        await test.controller.startMeasurement(HealthMetric.heartRate),
        isTrue,
      );
      await test.controller.logout();
      expect(
        test.wearable.operations,
        containsAllInOrder(['measure', 'stop', 'disconnect']),
      );
      test.wearable.emitRecord(_record('orphan-after-logout'));
      test.wearable.eventsController.add(
        WearableEvent(type: 'reconnected', payload: _Wearable.watch.toJson()),
      );
      await _settle();
      expect(test.controller.connectedDevice, isNull);
      expect(await test.store.recent(), isEmpty);
    },
  );

  test(
    'a failed disconnect cannot silently adopt the old connection',
    () async {
      final test = await setup();
      test.wearable.failDisconnect = true;
      expect(await test.controller.login('owner-a', 'test-password'), isTrue);
      expect(test.controller.connectedDevice, isNull);
      expect(test.wearable.connectCount, 1);
      await test.controller.connectDevice(_Wearable.watch);
      expect(test.wearable.connectCount, 1);
      test.wearable.failDisconnect = false;
      await test.controller.connectDevice(_Wearable.watch);
      await _settle();
      expect(test.wearable.connectCount, 2);
      expect(test.controller.deviceState, DeviceConnectionState.ready);
    },
  );

  test(
    'another device result is rejected while the active native identifier is accepted',
    () async {
      final test = await setup();
      test.wearable.emitRecord(_record('wrong-watch', deviceId: 'OTHER'));
      test.wearable.emitRecord(_record('right-watch'));
      await _settle();
      expect((await test.store.recent()).map((r) => r.id), ['right-watch']);
    },
  );

  test(
    'old connect completion is drained before another account can select a watch',
    () async {
      final test = await setup();
      await test.controller.disconnectDevice();
      test.wearable.connectResult = Completer<void>();
      final connecting = test.controller.connectDevice(_Wearable.watch);
      await _settle();
      var loginFinished = false;
      final login = test.controller.login('owner-b', 'test-password').then((
        value,
      ) {
        loginFinished = true;
        return value;
      });
      await _settle();
      expect(loginFinished, isFalse);
      test.wearable.connectResult!.complete();
      await connecting;
      expect(await login, isTrue);
      expect(test.controller.connectedDevice, isNull);
      test.wearable.connectResult = null;
      await test.controller.connectDevice(_Wearable.watch);
      await _settle();
      expect(test.controller.deviceState, DeviceConnectionState.ready);
    },
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

HealthRecord _record(String id, {String deviceId = 'WATCH'}) => HealthRecord(
  id: id,
  metric: HealthMetric.heartRate,
  values: const {'value': 72},
  unit: 'bpm',
  measuredAt: DateTime.utc(2026, 9, 6),
  timezone: '+08:00',
  deviceId: deviceId,
  firmwareVersion: 'test',
  quality: 'device_reported',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);

class _Api extends Fake implements SaydianApi {
  @override
  Future<Session> login(String username, String password) async => Session(
    accessToken: 'test-token',
    refreshToken: 'test-refresh',
    expiresAt: DateTime.utc(2030),
    memberId: username,
    displayName: username,
  );
  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => const [];
  @override
  Future<Map<String, Object?>> getMemberProfile() async => const {};
  @override
  Future<Map<String, Object?>> getActivityGoals() async => const {};
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];
  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      const [];
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async =>
      BatchUploadResult(
        nextCursor: null,
        acceptedIds: batch.records.map((r) => r.id).toSet(),
        rejected: const {},
      );
  @override
  Future<void> logout() async {}
}

class _Wearable extends Fake implements WearableBridge {
  static const watch = DeviceInfo(id: 'veepoo:WATCH', name: 'W9S');
  final eventsController = StreamController<WearableEvent>.broadcast();
  final disconnectStarted = Completer<void>();
  final operations = <String>[];
  Completer<void>? disconnectResult;
  Completer<void>? connectResult;
  Future<List<HealthRecord>>? historyResult;
  List<HealthRecord> nextHistory = const [];
  int connectCount = 0;
  int syncCount = 0;
  bool failDisconnect = false;

  void emitRecord(HealthRecord record) => eventsController.add(
    WearableEvent(type: 'healthRecord', payload: record.toJson()),
  );
  @override
  Stream<WearableEvent> get events => eventsController.stream;
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connectCount++;
    await connectResult?.future;
  }

  @override
  Future<void> disconnect() async {
    operations.add('disconnect');
    if (!disconnectStarted.isCompleted) disconnectStarted.complete();
    if (failDisconnect) throw PlatformException(code: 'DISCONNECT_FAILED');
    await disconnectResult?.future;
  }

  @override
  Future<void> stopScan() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(metrics: {HealthMetric.heartRate});
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    syncCount++;
    return historyResult ?? nextHistory;
  }

  @override
  Future<void> startMeasurement(HealthMetric metric) async =>
      operations.add('measure');
  @override
  Future<void> stopMeasurement(HealthMetric metric) async =>
      operations.add('stop');
  @override
  Future<List<SportRecord>> readSportRecords() async => const [];
}
