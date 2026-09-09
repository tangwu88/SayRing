import 'dart:async';

import 'package:flutter/foundation.dart';
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

  test(
    'failed health persistence logs only type and preserves visible result',
    () async {
      final wearable = _Wearable();
      final store = _FailingStore();
      final controller = AppController(
        MemorySessionVault(),
        _UnusedApi(),
        store,
        wearable,
      );
      final logs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() {
        debugPrint = previousDebugPrint;
        controller.dispose();
      });
      addTearDown(wearable.eventSource.close);
      await controller.initialize();
      controller.enterPreview();
      await controller.connectDevice(_Wearable.watch);
      await _settle();
      controller.clearError();
      logs.clear();
      final record = HealthRecord(
        id: 'synthetic-sensitive-record-id',
        metric: HealthMetric.heartRate,
        values: const {'value': 73},
        unit: 'bpm',
        measuredAt: DateTime.utc(2026, 9, 1),
        timezone: '+00:00',
        deviceId: 'PRIVATE_FIXTURE_WATCH',
        firmwareVersion: 'synthetic-firmware',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      );
      wearable.eventSource.add(
        WearableEvent(type: 'healthRecord', payload: record.toJson()),
      );
      await _settle();

      expect(store.attempts, 1);
      expect(logs, ['Health record persistence failed: PlatformException']);
      expect(
        controller.healthRecords.map((record) => record.id),
        contains(record.id),
      );
      expect(await store.recent(), isEmpty);
      expect(controller.errorMessage, '测量结果已显示，但暂时无法保存到本机');
    },
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FailingStore extends MemoryHealthStore {
  int attempts = 0;

  @override
  Future<void> upsertImmediate(HealthRecord record) async {
    attempts++;
    throw PlatformException(
      code: 'SYNTHETIC_PRIVATE_DATABASE_ERROR',
      message:
          'SQL values (${record.id}, ${record.deviceId}, ${record.values})',
      details: {'test_token': 'synthetic-secret-not-for-logs'},
    );
  }
}

class _UnusedApi extends Fake implements SaydianApi {
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];
}

class _Wearable extends Fake implements WearableBridge {
  static const watch = DeviceInfo(
    id: 'veepoo:PRIVATE_FIXTURE_WATCH',
    name: 'Synthetic watch',
  );
  final eventSource = StreamController<WearableEvent>.broadcast();

  @override
  Stream<WearableEvent> get events => eventSource.stream;
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(metrics: {HealthMetric.heartRate});
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];
  @override
  Future<List<SportRecord>> readSportRecords() async => const [];
}
