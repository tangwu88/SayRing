import 'package:flutter/services.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import 'wearable_bridge.dart';

/// QRing transport backed by the supplied QCBand SDKs on Android and iOS.
///
/// A scanned name only selects this transport. The native adapter still has
/// to bind the peripheral and read the vendor feature table before reporting
/// resolved capabilities.
class QRingWearableBridge
    implements
        WearableBridge,
        WearableDeviceDetailsBridge,
        WearableBoundDeviceLookupBridge {
  QRingWearableBridge({MethodChannel? methods, EventChannel? events})
    : _methods =
          methods ?? const MethodChannel('cc.saidian.ring/qring/commands'),
      _events = events ?? const EventChannel('cc.saidian.ring/qring/events');

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
      throw const WearableSdkNotConfigured('此手机尚未接入 QRing 戒指 SDK');
    }
  }

  Future<T> _unsupported<T>() => Future<T>.error(
    PlatformException(
      code: 'QRING_FEATURE_UNVERIFIED',
      message: '此戒指功能尚未通过能力握手或 SDK 实物验证',
    ),
  );

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    final values =
        await _invoke<List<Object?>>(
          'scanDevices',
          null,
          const Duration(seconds: 18),
        ) ??
        const <Object?>[];
    return values
        .whereType<Map<Object?, Object?>>()
        .map(DeviceInfo.fromMap)
        .toList(growable: false);
  }

  @override
  Future<DeviceInfo?> lookupPreviouslyBoundDevice(
    String nativeIdentifier,
  ) async {
    final value = await _invoke<Map<Object?, Object?>>('lookupBondedDevice', {
      'id': nativeIdentifier,
    });
    return value == null || value.isEmpty ? null : DeviceInfo.fromMap(value);
  }

  @override
  Future<void> stopScan() => _invoke<void>('stopScan');

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) => _invoke<void>('connect', {
    'id': deviceId,
    'profile': profile.toMap(),
  }, const Duration(seconds: 40));

  @override
  Future<void> disconnect() => _invoke<void>('disconnect');

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async {
    final value = await _invoke<Map<Object?, Object?>>('getDeviceDetails');
    return value == null || value.isEmpty ? null : DeviceInfo.fromMap(value);
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async {
    final value = await _invoke<Map<Object?, Object?>>(
      'getCapabilities',
      null,
      const Duration(seconds: 15),
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
          const Duration(minutes: 3),
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
  Future<void> startMeasurement(HealthMetric metric) => _invoke<void>(
    'startMeasurement',
    {'metric': metric.wireName},
    switch (metric) {
      HealthMetric.hrv => const Duration(seconds: 95),
      _ => const Duration(seconds: 45),
    },
  );

  @override
  Future<void> stopMeasurement(HealthMetric metric) =>
      _invoke<void>('stopMeasurement', {'metric': metric.wireName});

  @override
  Future<void> startSport(SportMode mode) =>
      _invoke<void>('startSport', {'mode': mode.wireName});

  @override
  Future<void> stopSport() => _invoke<void>('stopSport');

  @override
  Future<List<SportRecord>> readSportRecords() async {
    final values =
        await _invoke<List<Object?>>(
          'readSportRecords',
          null,
          const Duration(minutes: 2),
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
  }) {
    if (feature != DeviceFeature.findWatch) return _unsupported();
    return _invoke<void>('triggerDeviceAction', {
      'feature': feature.wireName,
      'enabled': enabled,
    });
  }
}
