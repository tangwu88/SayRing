import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/device_state_machine.dart';
import '../domain/feature_models.dart';
import '../domain/models.dart';
import '../domain/wellness_release_policy.dart';

/// A second boundary before parsing native records: the legacy model parser
/// defaults unknown metric names to steps. Never apply that fallback on iOS.
WellnessReleasePolicy get wearableHealthReleasePolicy => WellnessReleasePolicy(
  enabled: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
);

List<HealthRecord> parseWearableHealthRecords(Iterable<Object?> values) {
  final policy = wearableHealthReleasePolicy;
  return values
      .whereType<Map<Object?, Object?>>()
      .where((value) {
        if (!policy.enabled) return true;
        final type = value['type'];
        return type is String && policy.allowsWireMetric(type);
      })
      .map(
        (value) => HealthRecord.fromJson(
          value.map((key, item) => MapEntry('$key', item)),
        ),
      )
      .map(policy.projectRecord)
      .whereType<HealthRecord>()
      .toList(growable: false);
}

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

/// Optional controls for watches that explicitly report sport pause support.
///
/// This remains separate from [WearableBridge] so older SDK adapters and test
/// doubles keep their existing contract.
abstract interface class WearableSportPauseBridge {
  Future<void> pauseSport();
  Future<void> resumeSport();
}

/// Optional pull API for the connected watch's online watch-face catalogue
/// parameters. The values must come from the authenticated device session;
/// watches sold under the same model name can use different display profiles.
abstract interface class WearableWatchFaceProfileBridge {
  Future<Map<String, Object?>> getWatchFaceProfile();
}

/// Optional native Veepoo watch-face catalogue API.
///
/// iOS must use the catalogue and binary download APIs shipped with the
/// Veepoo SDK. This avoids constructing the Android HTTP request shape on iOS
/// and keeps the SDK model used for download bound to the live watch session.
abstract interface class WearableNativeWatchFaceBridge {
  Future<List<NativeWatchFaceCatalogItem>> getNativeWatchFaceCatalog();

  Future<NativeWatchFaceDownload> downloadNativeWatchFace(String catalogId);
}

class NativeWatchFaceCatalogItem {
  const NativeWatchFaceCatalogItem({
    required this.id,
    required this.name,
    required this.fileUrl,
    required this.previewUrl,
    required this.crc,
    required this.binProtocol,
    required this.dialShape,
  });

  factory NativeWatchFaceCatalogItem.fromMap(Map<Object?, Object?> value) {
    int requiredNumber(String key) {
      final raw = value[key];
      final parsed = raw is num ? raw.toInt() : int.tryParse('$raw');
      if (parsed == null || parsed < 0) {
        throw FormatException('Invalid native watch-face $key');
      }
      return parsed;
    }

    final id = '${value['id'] ?? ''}'.trim();
    final fileUrl = Uri.tryParse('${value['fileUrl'] ?? ''}'.trim());
    final previewUrl = Uri.tryParse('${value['previewUrl'] ?? ''}'.trim());
    if (id.isEmpty ||
        fileUrl == null ||
        !fileUrl.hasScheme ||
        previewUrl == null ||
        !previewUrl.hasScheme) {
      throw const FormatException('Invalid native watch-face catalogue item');
    }
    return NativeWatchFaceCatalogItem(
      id: id,
      name: '${value['name'] ?? ''}'.trim(),
      fileUrl: fileUrl,
      previewUrl: previewUrl,
      crc: requiredNumber('crc'),
      binProtocol: requiredNumber('binProtocol'),
      dialShape: requiredNumber('dialShape'),
    );
  }

  final String id;
  final String name;
  final Uri fileUrl;
  final Uri previewUrl;
  final int crc;
  final int binProtocol;
  final int dialShape;
}

class NativeWatchFaceDownload {
  const NativeWatchFaceDownload({
    required this.catalogId,
    required this.filePath,
    required this.fileLength,
  });

  factory NativeWatchFaceDownload.fromMap(Map<Object?, Object?> value) {
    final catalogId = '${value['catalogId'] ?? ''}'.trim();
    final filePath = '${value['filePath'] ?? ''}'.trim();
    final rawLength = value['fileLength'];
    final fileLength = rawLength is num
        ? rawLength.toInt()
        : int.tryParse('$rawLength');
    if (catalogId.isEmpty ||
        filePath.isEmpty ||
        fileLength == null ||
        fileLength <= 0) {
      throw const FormatException('Invalid native watch-face download');
    }
    return NativeWatchFaceDownload(
      catalogId: catalogId,
      filePath: filePath,
      fileLength: fileLength,
    );
  }

  final String catalogId;
  final String filePath;
  final int fileLength;
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

/// App-owned binding context. Native SDK installation-wide saved targets must
/// never determine the account or environment entitled to recover a device.
abstract interface class WearableBindingManagementBridge {
  Future<void> setRecoveryContext({
    required String? ownerKey,
    required WearableUserProfile profile,
  });
  Future<DeviceInfo?> readRememberedDevice();
  Future<DeviceInfo?> prepareRememberedDevice();
  Future<void> forgetRememberedDevice();
}

/// A visible legacy binding can be manually selected without authorizing
/// automatic recovery. Optional to preserve older adapters and test doubles.
abstract interface class WearableRememberedRecoveryEligibilityBridge {
  Future<bool> canAutomaticallyRecoverRememberedDevice();
}

/// Optional exact-target recovery, used by QRing after a successful binding.
/// Null cancels native recovery; a target is only armed by the scoped router.
abstract interface class WearableExactTargetRecoveryBridge {
  Future<void> configureRecoveryTarget({
    required String? nativeIdentifier,
    String? knownName,
    String? contextKey,
    WearableUserProfile? profile,
  });
}

/// Optional lookup for one device previously bound in this App environment.
/// A native adapter must verify the exact identifier against its trusted OS
/// bond before returning it; the normal vendor handshake still follows.
abstract interface class WearableBoundDeviceLookupBridge {
  Future<DeviceInfo?> lookupPreviouslyBoundDevice(String nativeIdentifier);
}

/// Optional, user-initiated recovery for rings that remain in the Android
/// system bond list but no longer advertise.
///
/// This API must never be called by automatic restore. Native adapters may
/// return only OS-bonded devices with an accepted vendor name. A returned
/// device is still untrusted until the user selects it and the normal vendor
/// SDK connection and capability handshake succeeds.
abstract interface class WearableBondedDeviceSelectionBridge {
  Future<List<DeviceInfo>> listBondedDevicesForSelection();
}

/// Optional, user-initiated recovery for the exact device identifier that this
/// App saved after a successful vendor handshake.
///
/// Unlike [WearableBoundDeviceLookupBridge], this path may prepare a device
/// that is no longer present in the Android bond list or BLE scan. It must only
/// be called from an explicit selection UI. The normal vendor connection and
/// capability handshake still decides whether the device is trusted.
abstract interface class WearableRememberedDeviceSelectionBridge {
  Future<DeviceInfo?> prepareRememberedDeviceForSelection(
    String nativeIdentifier, {
    String? knownName,
  });
}

class WearableSdkNotConfigured implements Exception {
  const WearableSdkNotConfigured([this.message = '此功能暂时无法使用，请稍后再试']);

  final String message;

  @override
  String toString() => message;
}

class MethodChannelWearableBridge
    implements
        WearableBridge,
        WearableDeviceDetailsBridge,
        WearableWatchFaceProfileBridge,
        WearableNativeWatchFaceBridge,
        WearableAutoMeasureIntervalBridge,
        WearableConnectionRecoveryBridge {
  MethodChannelWearableBridge({
    MethodChannel? methods,
    EventChannel? eventChannel,
    this.operationTimeout = const Duration(seconds: 30),
    this.syncTimeout = const Duration(minutes: 3),
    this.watchFaceTimeout = const Duration(minutes: 3),
  }) : _methods = methods ?? const MethodChannel('cc.saidian/wearable_methods'),
       _eventChannel =
           eventChannel ?? const EventChannel('cc.saidian/wearable_events');

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  final Duration operationTimeout;
  final Duration syncTimeout;
  final Duration watchFaceTimeout;
  final SerialOperationQueue _queue = SerialOperationQueue();
  static const _deviceFeatureTimeout = Duration(seconds: 20);

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
  Future<Map<String, Object?>> getWatchFaceProfile() => _queue.run(() async {
    final result =
        await _invokeOperation<Map<Object?, Object?>>('getWatchFaceProfile') ??
        const <Object?, Object?>{};
    return result.map((key, value) => MapEntry('$key', value));
  });

  @override
  Future<List<NativeWatchFaceCatalogItem>> getNativeWatchFaceCatalog() =>
      _queue.run(() async {
        final result =
            await _invoke<List<Object?>>(
              'getNativeWatchFaceCatalog',
            ).timeout(watchFaceTimeout) ??
            const <Object?>[];
        return result
            .whereType<Map<Object?, Object?>>()
            .map(NativeWatchFaceCatalogItem.fromMap)
            .toList(growable: false);
      });

  @override
  Future<NativeWatchFaceDownload> downloadNativeWatchFace(String catalogId) =>
      _queue.run(() async {
        final result =
            await _invoke<Map<Object?, Object?>>('downloadNativeWatchFace', {
              'catalogId': catalogId,
            }).timeout(watchFaceTimeout) ??
            const <Object?, Object?>{};
        return NativeWatchFaceDownload.fromMap(result);
      });

  @override
  Future<DeviceCapabilities> getCapabilities() => _queue.run(() async {
    final result =
        await _invokeOperation<Map<Object?, Object?>>('getCapabilities') ??
        const <Object?, Object?>{};
    if (result['resolved'] != true) {
      throw PlatformException(
        code: 'CAPABILITIES_UNAVAILABLE',
        message: '暂时无法读取此戒指的功能',
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
        return parseWearableHealthRecords(result);
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
                  ? watchFaceTimeout
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
              ? watchFaceTimeout
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
        throw WearableSdkNotConfigured(error.message ?? '此功能暂时无法使用，请稍后再试');
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
