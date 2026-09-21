import 'package:flutter/services.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import 'wearable_bridge.dart';

/// Android-only HR01 transport backed by the project-supplied CoolWear AAR.
///
/// The native side waits for the vendor connection and device-info response.
/// Historical packets are intentionally unavailable until their multi-packet
/// completion and acknowledgement contract has been verified on a real ring.
class CoolWearWearableBridge
    implements WearableBridge, WearableDeviceDetailsBridge {
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
  Future<List<HealthRecord>> syncHealthData({String? cursor}) =>
      Future<List<HealthRecord>>.error(
        PlatformException(
          code: 'HISTORY_UNVERIFIED',
          message: '此戒指的多包历史数据协议尚未完成实物验证，暂不读取',
        ),
      );

  @override
  Future<void> startMeasurement(HealthMetric metric) =>
      _invoke<void>('startMeasurement', {'metric': metric.wireName});

  @override
  Future<void> stopMeasurement(HealthMetric metric) =>
      _invoke<void>('stopMeasurement', {'metric': metric.wireName});

  @override
  Future<void> startSport(SportMode mode) => _unsupported();

  @override
  Future<void> stopSport() => _unsupported();

  @override
  Future<List<SportRecord>> readSportRecords() => _unsupported();

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() => _unsupported();

  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) =>
      _unsupported();

  @override
  Future<int?> readHeartRateWarning() => _unsupported();

  @override
  Future<void> setHeartRateWarning(int value) => _unsupported();

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) =>
      _unsupported();

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) => _unsupported();

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) => _unsupported();
}
