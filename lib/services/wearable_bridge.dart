import 'package:flutter/services.dart';

import '../domain/device_state_machine.dart';
import '../domain/feature_models.dart';
import '../domain/models.dart';

abstract interface class WearableBridge {
  Stream<WearableEvent> get events;

  Future<List<DeviceInfo>> scanDevices();
  Future<void> stopScan();
  Future<void> connect(String deviceId, {required WearableUserProfile profile});
  Future<void> disconnect();
  Future<DeviceCapabilities> getCapabilities();
  Future<List<HealthRecord>> syncHealthData({String? cursor});
  Future<void> startMeasurement(HealthMetric metric);
  Future<void> stopMeasurement(HealthMetric metric);
  Future<void> startSport(SportMode mode);
  Future<void> stopSport();
  Future<List<SportRecord>> readSportRecords();
  Future<Map<String, bool>> readAutoMeasureSettings();
  Future<void> setAutoMeasureSetting(String type, bool enabled);
  Future<int?> readHeartRateWarning();
  Future<void> setHeartRateWarning(int value);
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature);
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  );
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  });
}

/// Optional pull API for bridges that can verify the native connection and
/// return the latest device metadata. Keeping it separate preserves test and
/// third-party bridge implementations that only implement [WearableBridge].
abstract interface class WearableDeviceDetailsBridge {
  Future<DeviceInfo?> getConnectedDeviceDetails();
}

/// Optional pull API for the connected watch's online watch-face catalogue
/// parameters. The values must come from the authenticated device session;
/// watches sold under the same model name can use different display profiles.
abstract interface class WearableWatchFaceProfileBridge {
  Future<Map<String, Object?>> getWatchFaceProfile();
}

class AutoMeasureIntervalSetting {
  const AutoMeasureIntervalSetting({
    required this.minutes,
    required this.stepMinutes,
    required this.canModify,
  });

  final int minutes;
  final int stepMinutes;
  final bool canModify;

  factory AutoMeasureIntervalSetting.fromMap(Map<Object?, Object?> value) =>
      AutoMeasureIntervalSetting(
        minutes: ((value['minutes'] as num?)?.toInt() ?? 0).clamp(0, 1440),
        stepMinutes: ((value['stepMinutes'] as num?)?.toInt() ?? 1).clamp(
          1,
          1440,
        ),
        canModify: value['canModify'] == true,
      );

  List<int> get choices {
    final values = <int>{minutes};
    for (final value in const [5, 10, 15, 20, 30, 60, 120]) {
      if (value >= stepMinutes && value % stepMinutes == 0) values.add(value);
    }
    final ordered = values.where((value) => value > 0).toList()..sort();
    return ordered;
  }
}

/// Optional API exposed by watches whose firmware allows changing the
/// automatic health-measurement interval.
abstract interface class WearableAutoMeasureIntervalBridge {
  Future<Map<String, AutoMeasureIntervalSetting>> readAutoMeasureIntervals();
  Future<void> setAutoMeasureInterval(String type, int minutes);
}

/// Optional recovery API. It adopts a live vendor-SDK connection when
/// possible, or reconnects the last explicitly bound watch without scanning.
abstract interface class WearableConnectionRecoveryBridge {
  Future<DeviceInfo?> restoreConnection({required WearableUserProfile profile});
}

class WearableSdkNotConfigured implements Exception {
  const WearableSdkNotConfigured([this.message = 'Veepoo 合作方 SDK 尚未配置']);

  final String message;

  @override
  String toString() => message;
}

class MethodChannelWearableBridge
    implements
        WearableBridge,
        WearableDeviceDetailsBridge,
        WearableWatchFaceProfileBridge,
        WearableAutoMeasureIntervalBridge,
        WearableConnectionRecoveryBridge {
  MethodChannelWearableBridge({
    MethodChannel? methods,
    EventChannel? eventChannel,
    this.operationTimeout = const Duration(seconds: 30),
    this.syncTimeout = const Duration(minutes: 3),
  }) : _methods = methods ?? const MethodChannel('cc.saidian/wearable_methods'),
       _eventChannel =
           eventChannel ?? const EventChannel('cc.saidian/wearable_events');

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  final Duration operationTimeout;
  final Duration syncTimeout;
  final SerialOperationQueue _queue = SerialOperationQueue();
  static const _deviceFeatureTimeout = Duration(seconds: 20);
  static const _watchFaceTimeout = Duration(minutes: 3);

  @override
  Stream<WearableEvent> get events => _eventChannel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => WearableEvent.fromMap(event as Map<Object?, Object?>));

  @override
  Future<List<DeviceInfo>> scanDevices() => _queue.run(() async {
    final result =
        await _invokeOperation<List<Object?>>('scanDevices') ?? const [];
    return result
        .whereType<Map<Object?, Object?>>()
        .map(DeviceInfo.fromMap)
        .toList();
  });

  @override
  Future<void> stopScan() => _invokeOperation<void>('stopScan');

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) => _queue.run(
    () => _invokeOperation<void>('connect', {
      'deviceId': deviceId,
      'profile': profile.toMap(),
    }),
  );

  @override
  Future<void> disconnect() => _invokeOperation<void>('disconnect');

  @override
  Future<DeviceInfo?> restoreConnection({
    required WearableUserProfile profile,
  }) async {
    final result = await _invokeOperation<Map<Object?, Object?>>(
      'restoreConnection',
      {'profile': profile.toMap()},
    );
    return result == null || result.isEmpty ? null : DeviceInfo.fromMap(result);
  }

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async {
    final result = await _invokeOperation<Map<Object?, Object?>>(
      'getDeviceDetails',
    );
    return result == null ? null : DeviceInfo.fromMap(result);
  }

  @override
  Future<Map<String, Object?>> getWatchFaceProfile() async {
    final result =
        await _invokeOperation<Map<Object?, Object?>>('getWatchFaceProfile') ??
        const <Object?, Object?>{};
    return result.map((key, value) => MapEntry('$key', value));
  }

  @override
  Future<DeviceCapabilities> getCapabilities() => _queue.run(() async {
    final result =
        await _invokeOperation<Map<Object?, Object?>>('getCapabilities') ??
        const <Object?, Object?>{};
    if (result['resolved'] != true) {
      throw PlatformException(
        code: 'CAPABILITIES_UNAVAILABLE',
        message: '暂时无法读取此手表的功能',
      );
    }
    return DeviceCapabilities.fromMap(result);
  });

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) =>
      _queue.run(() async {
        final result =
            await _invokeSync<List<Object?>>('syncHealthData', {
              'cursor': cursor,
            }) ??
            const [];
        return result
            .whereType<Map<Object?, Object?>>()
            .map(
              (item) => HealthRecord.fromJson(
                item.map((key, value) => MapEntry('$key', value)),
              ),
            )
            .toList();
      });

  @override
  Future<void> startMeasurement(HealthMetric metric) => _queue.run(
    () =>
        _invokeOperation<void>('startMeasurement', {'metric': metric.wireName}),
  );

  @override
  Future<void> stopMeasurement(HealthMetric metric) => _queue.run(
    () =>
        _invokeOperation<void>('stopMeasurement', {'metric': metric.wireName}),
  );

  @override
  Future<void> startSport(SportMode mode) => _queue.run(
    () => _invokeOperation<void>('startSport', {'mode': mode.wireName}),
  );

  @override
  Future<void> stopSport() =>
      _queue.run(() => _invokeOperation<void>('stopSport'));

  @override
  Future<List<SportRecord>> readSportRecords() => _queue.run(() async {
    final result =
        await _invokeSync<List<Object?>>('readSportRecords') ?? const [];
    return result
        .whereType<Map<Object?, Object?>>()
        .map(SportRecord.fromMap)
        .toList();
  });

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() => _queue.run(() async {
    final result =
        await _invokeOperation<Map<Object?, Object?>>(
          'readAutoMeasureSettings',
        ) ??
        const {};
    return result.map((key, value) => MapEntry('$key', value == true));
  });

  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) => _queue.run(
    () => _invokeOperation<void>('setAutoMeasureSetting', {
      'type': type,
      'enabled': enabled,
    }),
  );

  @override
  Future<Map<String, AutoMeasureIntervalSetting>> readAutoMeasureIntervals() =>
      _queue.run(() async {
        final result =
            await _invokeOperation<Map<Object?, Object?>>(
              'readAutoMeasureIntervals',
            ) ??
            const {};
        return <String, AutoMeasureIntervalSetting>{
          for (final entry in result.entries)
            if (entry.value is Map<Object?, Object?>)
              '${entry.key}': AutoMeasureIntervalSetting.fromMap(
                entry.value! as Map<Object?, Object?>,
              ),
        };
      });

  @override
  Future<void> setAutoMeasureInterval(String type, int minutes) => _queue.run(
    () => _invokeOperation<void>('setAutoMeasureInterval', {
      'type': type,
      'minutes': minutes,
    }),
  );

  @override
  Future<int?> readHeartRateWarning() =>
      _queue.run(() => _invokeOperation<int>('readHeartRateWarning'));

  @override
  Future<void> setHeartRateWarning(int value) => _queue.run(
    () => _invokeOperation<void>('setHeartRateWarning', {'value': value}),
  );

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) =>
      _queue.run(() async {
        final result =
            await _invoke<Map<Object?, Object?>>('readDeviceFeature', {
              'feature': feature.wireName,
            }).timeout(
              feature == DeviceFeature.watchFaces ||
                      feature == DeviceFeature.photoWatchFace
                  ? _watchFaceTimeout
                  : _deviceFeatureTimeout,
            ) ??
            const <Object?, Object?>{};
        return result.map((key, value) => MapEntry('$key', value));
      });

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) => _queue.run(
    () =>
        _invoke<void>('writeDeviceFeature', {
          'feature': feature.wireName,
          'values': values,
        }).timeout(
          feature == DeviceFeature.watchFaces ||
                  feature == DeviceFeature.photoWatchFace
              ? _watchFaceTimeout
              : _deviceFeatureTimeout,
        ),
  );

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) => _queue.run(
    () => _invoke<void>('triggerDeviceAction', {
      'feature': feature.wireName,
      'enabled': enabled,
    }).timeout(_deviceFeatureTimeout),
  );

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _methods.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      if (error.code == 'SDK_NOT_CONFIGURED') {
        throw WearableSdkNotConfigured(error.message ?? 'Veepoo SDK 未配置');
      }
      rethrow;
    } on MissingPluginException {
      throw const WearableSdkNotConfigured();
    }
  }

  Future<T?> _invokeOperation<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) => _invoke<T>(method, arguments).timeout(operationTimeout);

  Future<T?> _invokeSync<T>(String method, [Map<String, Object?>? arguments]) =>
      _invoke<T>(method, arguments).timeout(syncTimeout);
}
