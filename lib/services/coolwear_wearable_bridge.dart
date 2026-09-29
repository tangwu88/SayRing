import 'package:flutter/services.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import 'wearable_bridge.dart';

/// Android-only HR01/HR05 transport backed by the project-supplied CoolWear AAR.
///
/// The native side waits for the vendor connection and device-info response.
/// History is completed only after the vendor SDK emits its device-sync
/// callback; individual packets are never treated as a completed sync.
class CoolWearWearableBridge
    implements
        WearableBridge,
        WearableDeviceDetailsBridge,
        WearableSportPauseBridge,
        WearableAutoMeasureIntervalBridge {
  CoolWearWearableBridge({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('cc.saidian.ring/commands'),
      _events = events ?? const EventChannel('cc.saidian.ring/events');

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Stream<WearableEvent> get events => _events
      .receiveBroadcastStream()
      .where((value) => value is Map)
      .map((value) => WearableEvent.fromMap(value as Map<Object?, Object?>));

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
    Duration timeout = const Duration(seconds: 30),
  ]) async {
    try {
      return await _methods.invokeMethod<T>(method, arguments).timeout(timeout);
    } on MissingPluginException {
      throw const WearableSdkNotConfigured('此手机尚未接入 CoolWear 戒指 SDK');
    }
  }

  Future<T> _unsupported<T>() => Future<T>.error(
    PlatformException(
      code: 'COOLWEAR_FEATURE_UNVERIFIED',
      message: '此戒指功能尚未完成 SDK 实物验证',
    ),
  );

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    final values =
        await _invoke<List<Object?>>(
          'scanDevices',
          null,
          const Duration(seconds: 15),
        ) ??
        const <Object?>[];
    return values
        .whereType<Map<Object?, Object?>>()
        .map(DeviceInfo.fromMap)
        .toList(growable: false);
  }

  @override
  Future<void> stopScan() => _invoke<void>('stopScan');

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) => _invoke<void>('connect', {'id': deviceId}, const Duration(seconds: 35));

  @override
  Future<void> disconnect() => _invoke<void>('disconnect');

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async {
    final value = await _invoke<Map<Object?, Object?>>('getDeviceDetails');
    return value == null ? null : DeviceInfo.fromMap(value);
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async {
    final value = await _invoke<Map<Object?, Object?>>(
      'getCapabilities',
      null,
      const Duration(seconds: 12),
    );
    if (value?['resolved'] != true) {
      throw PlatformException(
        code: 'CAPABILITIES_UNAVAILABLE',
        message: '暂时无法读取此戒指的功能',
      );
    }
    return DeviceCapabilities.fromMap(value!);
  }

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    final values =
        await _invoke<List<Object?>>(
          'syncHealthData',
          cursor == null ? null : {'cursor': cursor},
          const Duration(seconds: 35),
        ) ??
        const <Object?>[];
    return values
        .whereType<Map<Object?, Object?>>()
        .map(
          (value) => HealthRecord.fromJson(
            value.map((key, item) => MapEntry('$key', item)),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> startMeasurement(HealthMetric metric) =>
      _invoke<void>('startMeasurement', {'metric': metric.wireName});

  @override
  Future<void> stopMeasurement(HealthMetric metric) =>
      _invoke<void>('stopMeasurement', {'metric': metric.wireName});

  @override
  Future<void> startSport(SportMode mode) =>
      _invoke<void>('startSport', {'mode': mode.wireName});

  @override
  Future<void> stopSport() => _invoke<void>('stopSport');

  @override
  Future<void> pauseSport() => _invoke<void>('pauseSport');

  @override
  Future<void> resumeSport() => _invoke<void>('resumeSport');

  @override
  Future<List<SportRecord>> readSportRecords() async {
    final values =
        await _invoke<List<Object?>>(
          'readSportRecords',
          null,
          const Duration(seconds: 35),
        ) ??
        const <Object?>[];
    return values
        .whereType<Map<Object?, Object?>>()
        .map(SportRecord.fromMap)
        .toList(growable: false);
  }

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async {
    final value =
        await _invoke<Map<Object?, Object?>>('readAutoMeasureSettings') ??
        const {};
    return value.map((key, item) => MapEntry('$key', item == true));
  }

  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) =>
      _invoke<void>('setAutoMeasureSetting', {
        'type': type,
        'enabled': enabled,
      });

  @override
  Future<Map<String, AutoMeasureIntervalSetting>>
  readAutoMeasureIntervals() async {
    final values = await _invoke<Map<Object?, Object?>>(
      'readAutoMeasureIntervals',
    );
    return <String, AutoMeasureIntervalSetting>{
      for (final entry in (values ?? const <Object?, Object?>{}).entries)
        if (entry.value is Map)
          '${entry.key}': AutoMeasureIntervalSetting.fromMap(
            (entry.value as Map).cast<Object?, Object?>(),
          ),
    };
  }

  @override
  Future<void> setAutoMeasureInterval(String type, int minutes) =>
      _invoke<void>('setAutoMeasureInterval', {
        'type': type,
        'minutes': minutes,
      });

  @override
  Future<int?> readHeartRateWarning() => _unsupported();

  @override
  Future<void> setHeartRateWarning(int value) => _unsupported();

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    if (feature != DeviceFeature.notifications &&
        feature != DeviceFeature.healthReminders) {
      return _unsupported();
    }
    final value = await _invoke<Map<Object?, Object?>>('readDeviceFeature', {
      'feature': feature.wireName,
    });
    return (value ?? const <Object?, Object?>{}).map(
      (key, item) => MapEntry('$key', item),
    );
  }

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) =>
      feature == DeviceFeature.notifications ||
          feature == DeviceFeature.healthReminders
      ? _invoke<void>('writeDeviceFeature', {
          'feature': feature.wireName,
          'values': values,
        })
      : _unsupported();

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) => _invoke<void>('triggerDeviceAction', {
    'feature': feature.wireName,
    'enabled': enabled,
  });
}
