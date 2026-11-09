import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

class _Api extends Fake implements SaydianApi {
  @override
  Future<List<Map<String, Object?>>> getArticles() async => [];
}

class _Ring extends Fake implements WearableBridge {
  final source = StreamController<WearableEvent>.broadcast();
  int starts = 0, stops = 0, historyReads = 0;
  @override
  Stream<WearableEvent> get events => source.stream;
  @override
  Future<void> startSport(SportMode mode) async {
    starts++;
  }

  @override
  Future<void> stopSport() async {
    stops++;
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async => _caps;
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    historyReads++;
    return [];
  }

  @override
  Future<List<SportRecord>> readSportRecords() async {
    historyReads++;
    return [];
  }
}

const _device = DeviceInfo(id: 'coolwear:TEST', name: 'R7 Ultra');
const _caps = DeviceCapabilities(
  metrics: {HealthMetric.steps},
  sportModes: {SportMode.walking},
);
Future<void> _settle() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Future<(AppController, _Ring)> setup({DeviceInfo device = _device}) async {
    final ring = _Ring();
    final app = AppController(
      MemorySessionVault()..privacyConsentGranted = true,
      _Api(),
      MemoryHealthStore(),
      ring,
    );
    addTearDown(app.dispose);
    addTearDown(ring.source.close);
    await app.initialize();
    app.connectedDevice = app.rememberedDevice = device;
    app.capabilities = _caps;
    app.deviceCapabilityState = DeviceCapabilityState.ready;
    expect(await app.startSport(SportMode.walking), isTrue);
    return (app, ring);
  }

  Future<void> event(
    _Ring ring,
    String type,
    Map<String, Object?> payload,
  ) async {
    ring.source.add(WearableEvent(type: type, payload: payload));
    await _settle();
  }

  test(
    'short transport loss preserves workout but removes stale pulse; same target resumes without start or history replay',
    () async {
      final (app, ring) = await setup();
      await event(ring, 'sportData', {
        'deviceId': _device.id,
        'steps': 12,
        'heartRate': 83,
      });
      await event(ring, 'disconnected', {
        'deviceId': _device.id,
        'recoveryOwner': 'native_sdk',
      });
      expect(app.activeSport, SportMode.walking);
      expect(app.connectedDevice, isNull);
      expect(app.sportConnectionInterrupted, isTrue);
      expect(app.liveSportData['steps'], 12);
      expect(app.liveSportData.containsKey('heartRate'), isFalse);
      await event(ring, 'sportData', {'deviceId': _device.id, 'heartRate': 90});
      expect(app.liveSportData.containsKey('heartRate'), isFalse);
      await event(ring, 'reconnected', {
        'id': _device.id,
        'name': _device.name,
      });
      expect(app.connectedDevice?.id, _device.id);
      expect(app.activeSport, SportMode.walking);
      expect(ring.historyReads, 0);
      expect(ring.starts, 1);
      await event(ring, 'sportData', {
        'deviceId': 'coolwear:OTHER',
        'heartRate': 99,
      });
      expect(app.liveSportData.containsKey('heartRate'), isFalse);
      await event(ring, 'sportData', {
        'deviceId': _device.id,
        'steps': 16,
        'heartRate': 86,
      });
      expect(app.liveSportData['steps'], 16);
      expect(app.liveSportData['heartRate'], 86);
      expect(app.sportConnectionInterrupted, isFalse);
    },
  );

  test(
    'user can finish during recovery and late running acknowledgement cannot resurrect workout',
    () async {
      final (app, ring) = await setup();
      await event(ring, 'disconnected', {
        'deviceId': _device.id,
        'recoveryOwner': 'native_sdk',
      });
      await app.stopSport();
      expect(app.activeSport, isNull);
      expect(ring.stops, 1);
      await event(ring, 'reconnected', {
        'id': _device.id,
        'name': _device.name,
      });
      await event(ring, 'sportState', {
        'deviceId': _device.id,
        'mode': 'walking',
        'value': 'running',
      });
      expect(app.activeSport, isNull);
      expect(ring.starts, 1);
    },
  );

  test(
    'late disconnect for another target cannot interrupt this workout',
    () async {
      final (app, ring) = await setup();
      await event(ring, 'disconnected', {
        'deviceId': 'coolwear:OTHER',
        'recoveryOwner': 'native_sdk',
      });
      expect(app.connectedDevice?.id, _device.id);
      expect(app.activeSport, SportMode.walking);
      expect(app.sportConnectionInterrupted, isFalse);
    },
  );
  test('R7 recovery does not retain a legacy-model workout', () async {
    final (app, ring) = await setup(
      device: const DeviceInfo(id: 'coolwear:TEST', name: 'HR05'),
    );
    await event(ring, 'disconnected', {
      'deviceId': _device.id,
      'recoveryOwner': 'controller',
    });
    expect(app.activeSport, isNull);
    expect(app.sportConnectionInterrupted, isFalse);
  });
  test(
    'selecting a different ring during recovery cannot migrate the workout',
    () async {
      final (app, ring) = await setup();
      await event(ring, 'disconnected', {
        'deviceId': _device.id,
        'recoveryOwner': 'native_sdk',
      });
      await app.connectDevice(
        const DeviceInfo(id: 'coolwear:OTHER', name: 'R7 Pro'),
      );
      expect(app.activeSport, SportMode.walking);
      expect(app.rememberedDevice?.id, _device.id);
      expect(app.connectedDevice, isNull);
      expect(app.errorMessage, '请先结束当前运动，再连接其他戒指');
      expect(ring.starts, 1);
    },
  );
}
