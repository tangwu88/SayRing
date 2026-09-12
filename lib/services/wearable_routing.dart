import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import 'global_storage_scope.dart';
import 'wearable_bridge.dart';

enum WearableTransport { veepoo, yucheng, moyoung }

/// Selects only the native transport that is allowed to attempt a handshake.
///
/// A name prefix is not treated as proof of device capability. The selected
/// SDK still has to complete its real handshake and capability read before the
/// App exposes any device feature.
class WearableDeviceClassifier {
  const WearableDeviceClassifier._();

  static WearableTransport? transportFor(String name) {
    final normalized = name.trimLeft().toUpperCase();
    if (normalized.startsWith('YC')) return WearableTransport.yucheng;
    if (normalized.startsWith('TK') || normalized.startsWith('V')) {
      return WearableTransport.veepoo;
    }
    if (normalized.startsWith('D')) return WearableTransport.moyoung;
    return null;
  }

  static WearableTransport? transportForScopedId(String deviceId) {
    final normalized = deviceId.trim().toLowerCase();
    final separator = normalized.indexOf(':');
    if (separator <= 0) return null;
    return switch (normalized.substring(0, separator)) {
      'yucheng' => WearableTransport.yucheng,
      'veepoo' => WearableTransport.veepoo,
      'moyoung' => WearableTransport.moyoung,
      _ => null,
    };
  }

  static bool routesTo(String name, WearableTransport transport) =>
      transportFor(name) == transport;
}

class RoutedDevice {
  const RoutedDevice({
    required this.display,
    required this.transport,
    required this.nativeIdentifier,
  });

  final DeviceInfo display;
  final WearableTransport transport;
  final String nativeIdentifier;

  factory RoutedDevice.fromScan({
    required WearableTransport transport,
    required String nativeIdentifier,
    required String name,
    String? model,
    String? serialNumber,
    String? hardwareAddress,
    String? firmwareVersion,
    DeviceBatteryInfo? battery,
    int? batteryPercent,
    int? rssi,
  }) => RoutedDevice(
    display: DeviceInfo(
      id: scopedID(transport, nativeIdentifier),
      name: name,
      model: model,
      serialNumber: serialNumber,
      hardwareAddress: hardwareAddress,
      firmwareVersion: firmwareVersion,
      battery: battery,
      batteryPercent: batteryPercent,
      rssi: rssi,
    ),
    transport: transport,
    nativeIdentifier: nativeIdentifier,
  );

  factory RoutedDevice.fromDevice(
    WearableTransport transport,
    DeviceInfo device,
  ) => RoutedDevice.fromScan(
    transport: transport,
    nativeIdentifier: device.id,
    name: device.name,
    model: device.model,
    serialNumber: device.serialNumber,
    hardwareAddress: device.hardwareAddress,
    firmwareVersion: device.firmwareVersion,
    battery: device.battery,
    batteryPercent: device.batteryPercent,
    rssi: device.rssi,
  );

  static String scopedID(
    WearableTransport transport,
    String nativeIdentifier,
  ) => '${transport.name}:$nativeIdentifier';
}

class RoutedWearableBridge
    implements
        WearableBridge,
        WearableDeviceDetailsBridge,
        WearableWatchFaceProfileBridge,
        WearableNativeWatchFaceBridge,
        WearableAutoMeasureIntervalBridge,
        WearableSportPauseBridge,
        WearableConnectionRecoveryBridge {
  RoutedWearableBridge({
    required WearableBridge veepoo,
    required WearableBridge yucheng,
    WearableBridge? moyoung,
    WearableTransportPreferenceStore? preferenceStore,
    this.restoreOnlyBoundDevice = false,
    this.recoveryOperationTimeout = const Duration(seconds: 30),
    this.recoveryStopScanTimeout = const Duration(seconds: 3),
  }) : _sources = {
         WearableTransport.veepoo: veepoo,
         WearableTransport.yucheng: yucheng,
       },
       _preferenceStore =
           preferenceStore ?? const SecureWearableTransportPreferenceStore() {
    if (moyoung != null) _sources[WearableTransport.moyoung] = moyoung;
    _eventController
      ..onListen = _subscribeToSourceEvents
      ..onCancel = _cancelSourceEvents;
  }

  final Map<WearableTransport, WearableBridge> _sources;
  final WearableTransportPreferenceStore _preferenceStore;
  final bool restoreOnlyBoundDevice;
  final Duration recoveryOperationTimeout;
  final Duration recoveryStopScanTimeout;
  final Map<String, RoutedDevice> _scanned = {};
  final StreamController<WearableEvent> _eventController =
      StreamController<WearableEvent>.broadcast();
  final List<StreamSubscription<WearableEvent>> _subscriptions = [];
  WearableTransport? _activeTransport;
  int _connectionGeneration = 0;
  int? _activeConnectionGeneration;
  final Map<WearableTransport, int> _sourceConnectionGenerations = {};
  final Map<WearableTransport, Future<void>> _pendingRecoveryWork = {};
  int? _restoringGeneration;

  WearableBridge get _activeBridge {
    final transport = _activeTransport;
    if (transport == null) {
      throw PlatformException(code: 'NOT_CONNECTED', message: '请先连接戒指');
    }
    return _sources[transport]!;
  }

  @override
  Stream<WearableEvent> get events => _eventController.stream;

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    _scanned.clear();
    final batches = await Future.wait(
      _sources.entries.map((entry) async {
        try {
          return MapEntry(entry.key, await entry.value.scanDevices());
        } catch (_) {
          // One unavailable SDK must not hide rings found by another SDK.
          return MapEntry(entry.key, const <DeviceInfo>[]);
        }
      }),
    );
    for (final batch in batches) {
      for (final device in batch.value) {
        if (!WearableDeviceClassifier.routesTo(device.name, batch.key)) {
          continue;
        }
        final routed = RoutedDevice.fromDevice(batch.key, device);
        _scanned[routed.display.id] = routed;
      }
    }
    return _scanned.values.map((device) => device.display).toList();
  }

  @override
  Future<void> stopScan() {
    if (_restoringGeneration == _connectionGeneration) {
      ++_connectionGeneration;
    }
    return Future.wait(
      _sources.values.map(
        (source) => source.stopScan().timeout(
          recoveryStopScanTimeout,
          onTimeout: () {},
        ),
      ),
    ).then((_) {});
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    final device = _scanned[deviceId];
    if (device == null) {
      throw PlatformException(
        code: 'UNKNOWN_SCANNED_DEVICE',
        message: '请重新扫描后再连接设备',
      );
    }
    if (!WearableDeviceClassifier.routesTo(
      device.display.name,
      device.transport,
    )) {
      throw PlatformException(
        code: 'DEVICE_PROVIDER_MISMATCH',
        message: '设备信息已变化，请重新扫描后重试',
      );
    }
    _requireRecoverySourceAvailable(device.transport);

    final generation = ++_connectionGeneration;
    _activeTransport = device.transport;
    _activeConnectionGeneration = generation;
    _sourceConnectionGenerations[device.transport] = generation;
    try {
      await _activeBridge.connect(device.nativeIdentifier, profile: profile);
      try {
        if (generation != _connectionGeneration) return;
        final preference = _preferenceStore;
        if (preference is WearableBindingPreferenceStore) {
          await preference.writeBinding(
            SavedWearableBinding(device.transport, device.nativeIdentifier),
          );
        } else {
          await preference.write(device.transport);
        }
      } catch (_) {
        // A preference write is not part of the authenticated BLE boundary.
      }
    } catch (_) {
      if (_activeConnectionGeneration == generation) {
        _activeTransport = null;
        _activeConnectionGeneration = null;
      }
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final disconnectGeneration = ++_connectionGeneration;
    final transport = _activeTransport;
    if (transport == null) return;
    final connectionOwner = _activeConnectionGeneration;
    try {
      final pending = _pendingRecoveryWork[transport];
      if (pending == null) {
        await _sources[transport]!.disconnect();
      } else {
        await pending.timeout(recoveryOperationTimeout);
      }
    } finally {
      if (_activeConnectionGeneration == connectionOwner) {
        _activeTransport = null;
        _activeConnectionGeneration = null;
      }
      if (disconnectGeneration == _connectionGeneration) {
        try {
          await _preferenceStore.clear();
        } catch (_) {
          // The explicit disconnect has already completed.
        }
      }
    }
  }

  @override
  Future<DeviceInfo?> restoreConnection({
    required WearableUserProfile profile,
  }) async {
    final generation = ++_connectionGeneration;
    if (restoreOnlyBoundDevice) {
      _restoringGeneration = generation;
      try {
        return await _restoreBoundDevice(profile, generation);
      } finally {
        if (_restoringGeneration == generation) _restoringGeneration = null;
      }
    }
    WearableTransport? preferred;
    try {
      preferred = await _preferenceStore.read();
    } catch (_) {
      preferred = null;
    }
    final entries = preferred == null
        ? _sources.entries
        : _sources.entries.where((entry) => entry.key == preferred);
    for (final entry in entries) {
      final bridge = entry.value;
      if (bridge is! WearableConnectionRecoveryBridge) continue;
      try {
        final details = await (bridge as WearableConnectionRecoveryBridge)
            .restoreConnection(profile: profile);
        if (generation != _connectionGeneration) return null;
        if (details == null) continue;
        if (!WearableDeviceClassifier.routesTo(details.name, entry.key)) {
          await bridge.disconnect();
          continue;
        }
        _activeTransport = entry.key;
        _activeConnectionGeneration = generation;
        return RoutedDevice.fromDevice(entry.key, details).display;
      } on PlatformException catch (error) {
        if (error.code != 'NO_SAVED_DEVICE') rethrow;
      }
    }
    return null;
  }

  Future<DeviceInfo?> _restoreBoundDevice(
    WearableUserProfile profile,
    int generation,
  ) async {
    final preference = _preferenceStore;
    if (preference is! WearableBindingPreferenceStore) return null;
    SavedWearableBinding? saved;
    try {
      saved = await preference.readBinding();
    } catch (_) {
      return null;
    }
    if (saved == null || generation != _connectionGeneration) return null;
    final source = _sources[saved.transport];
    if (source == null) return null;
    _requireRecoverySourceAvailable(saved.transport);
    // Native SDKs keep installation-wide saved targets. Never ask them to
    // restore a target selected in another API environment.
    final List<DeviceInfo> scanned;
    try {
      scanned = await source.scanDevices().timeout(recoveryOperationTimeout);
    } finally {
      try {
        await source.stopScan().timeout(recoveryStopScanTimeout);
      } on TimeoutException {
        // The controller's explicit connect uses the same grace period for
        // SDKs that stop scanning but fail to complete their method callback.
      }
    }
    if (generation != _connectionGeneration) return null;
    DeviceInfo? target;
    for (final device in scanned) {
      if (device.id == saved.nativeIdentifier) {
        target = device;
        break;
      }
    }
    if (target == null) return null;
    final routed = RoutedDevice.fromDevice(saved.transport, target);
    if (!WearableDeviceClassifier.routesTo(target.name, saved.transport)) {
      return null;
    }
    _activeTransport = saved.transport;
    _activeConnectionGeneration = generation;
    _sourceConnectionGenerations[saved.transport] = generation;
    var timedOut = false;
    final transport = saved.transport;
    final actualWork = () async {
      try {
        await source.connect(routed.nativeIdentifier, profile: profile);
        if (timedOut || generation != _connectionGeneration) {
          await _disconnectRetiredRecovery(source, transport, generation);
        }
      } catch (_) {
        _clearRecoveryOwner(transport, generation);
        rethrow;
      }
    }();
    late final Future<void> trackedWork;
    trackedWork = actualWork.whenComplete(() {
      if (identical(_pendingRecoveryWork[transport], trackedWork)) {
        _pendingRecoveryWork.remove(transport);
      }
    });
    _pendingRecoveryWork[transport] = trackedWork;
    // Keep the actual native chain, not the timeout wrapper, as the channel
    // barrier. A failed wait must not release a still-running SDK operation.
    unawaited(trackedWork.catchError((Object _) {}));
    try {
      await trackedWork.timeout(recoveryOperationTimeout);
    } on TimeoutException {
      timedOut = true;
      if (_activeConnectionGeneration == generation) _activeTransport = null;
      rethrow;
    } catch (_) {
      _clearRecoveryOwner(transport, generation);
      rethrow;
    }
    if (generation != _connectionGeneration) {
      return null;
    }
    _scanned[routed.display.id] = routed;
    return routed.display;
  }

  Future<void> _disconnectRetiredRecovery(
    WearableBridge source,
    WearableTransport transport,
    int generation,
  ) async {
    if (_sourceConnectionGenerations[transport] != generation) return;
    try {
      // Do not timeout this original future: the caller times out its wait,
      // while the same-source barrier stays until native cleanup really ends.
      await source.disconnect();
    } finally {
      _clearRecoveryOwner(transport, generation);
    }
  }

  void _clearRecoveryOwner(WearableTransport transport, int generation) {
    if (_sourceConnectionGenerations[transport] == generation) {
      _sourceConnectionGenerations.remove(transport);
    }
    if (_activeConnectionGeneration == generation) {
      _activeTransport = null;
      _activeConnectionGeneration = null;
    }
  }

  void _requireRecoverySourceAvailable(WearableTransport transport) {
    if (_pendingRecoveryWork.containsKey(transport)) {
      throw PlatformException(
        code: 'RECOVERY_PENDING',
        message: '戒指正在恢复连接，请稍后重试',
      );
    }
  }

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async {
    final transport = _activeTransport;
    if (transport == null) return null;
    final bridge = _sources[transport];
    if (bridge is! WearableDeviceDetailsBridge) return null;
    final details = await (bridge as WearableDeviceDetailsBridge)
        .getConnectedDeviceDetails();
    if (details == null) {
      _activeTransport = null;
      return null;
    }
    return RoutedDevice.fromDevice(transport, details).display;
  }

  @override
  Future<Map<String, Object?>> getWatchFaceProfile() async {
    final bridge = _activeBridge;
    if (bridge is! WearableWatchFaceProfileBridge) return const {};
    return (bridge as WearableWatchFaceProfileBridge).getWatchFaceProfile();
  }

  WearableNativeWatchFaceBridge get _nativeWatchFaceBridge {
    final bridge = _activeBridge;
    if (_activeTransport != WearableTransport.veepoo ||
        bridge is! WearableNativeWatchFaceBridge) {
      throw PlatformException(
        code: 'WATCH_FACE_MARKET_UNSUPPORTED',
        message: '当前戒指暂不支持在线显示样式',
      );
    }
    return bridge as WearableNativeWatchFaceBridge;
  }

  void _requireCurrentConnection(
    int generation, {
    String message = '设备连接已变化，请重新打开显示样式商城',
  }) {
    if (generation != _connectionGeneration || _activeTransport == null) {
      throw PlatformException(code: 'DEVICE_CHANGED', message: message);
    }
  }

  @override
  Future<List<NativeWatchFaceCatalogItem>> getNativeWatchFaceCatalog() async {
    final generation = _connectionGeneration;
    final result = await _nativeWatchFaceBridge.getNativeWatchFaceCatalog();
    _requireCurrentConnection(generation);
    return result;
  }

  @override
  Future<NativeWatchFaceDownload> downloadNativeWatchFace(
    String catalogId,
  ) async {
    final generation = _connectionGeneration;
    final result = await _nativeWatchFaceBridge.downloadNativeWatchFace(
      catalogId,
    );
    _requireCurrentConnection(generation);
    return result;
  }

  @override
  Future<DeviceCapabilities> getCapabilities() =>
      _activeBridge.getCapabilities();

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    final transport = _activeTransport;
    if (transport == null) {
      throw PlatformException(code: 'NOT_CONNECTED', message: '请先连接戒指');
    }
    final generation = _connectionGeneration;
    final records = await _activeBridge.syncHealthData(cursor: cursor);
    _requireCurrentConnection(generation, message: '戒指连接已变化，请重新同步');
    return records
        .map((record) {
          final existingTransport =
              WearableDeviceClassifier.transportForScopedId(record.deviceId);
          if (existingTransport != null && existingTransport != transport) {
            throw PlatformException(
              code: 'DEVICE_PROVIDER_MISMATCH',
              message: '戒指数据来源已变化，请重新连接后同步',
            );
          }
          final deviceId = record.deviceId.isEmpty || existingTransport != null
              ? record.deviceId
              : RoutedDevice.scopedID(transport, record.deviceId);
          return record.copyWith(
            deviceId: deviceId,
            sourceVendor: transport.name,
            sourceDeviceCategory: 'ring',
            sourceApp: 'say-ring',
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> startMeasurement(HealthMetric metric) =>
      _activeBridge.startMeasurement(metric);

  @override
  Future<void> stopMeasurement(HealthMetric metric) =>
      _activeBridge.stopMeasurement(metric);

  @override
  Future<void> startSport(SportMode mode) => _activeBridge.startSport(mode);

  @override
  Future<void> stopSport() => _activeBridge.stopSport();

  @override
  Future<void> pauseSport() {
    final bridge = _activeBridge;
    if (bridge is! WearableSportPauseBridge) {
      throw PlatformException(
        code: 'SPORT_PAUSE_UNSUPPORTED',
        message: '当前戒指不支持暂停运动',
      );
    }
    return (bridge as WearableSportPauseBridge).pauseSport();
  }

  @override
  Future<void> resumeSport() {
    final bridge = _activeBridge;
    if (bridge is! WearableSportPauseBridge) {
      throw PlatformException(
        code: 'SPORT_PAUSE_UNSUPPORTED',
        message: '当前戒指不支持暂停运动',
      );
    }
    return (bridge as WearableSportPauseBridge).resumeSport();
  }

  @override
  Future<List<SportRecord>> readSportRecords() =>
      _activeBridge.readSportRecords();

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() =>
      _activeBridge.readAutoMeasureSettings();

  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) =>
      _activeBridge.setAutoMeasureSetting(type, enabled);

  @override
  Future<Map<String, AutoMeasureIntervalSetting>> readAutoMeasureIntervals() {
    final bridge = _activeBridge;
    if (bridge is! WearableAutoMeasureIntervalBridge) return Future.value({});
    return (bridge as WearableAutoMeasureIntervalBridge)
        .readAutoMeasureIntervals();
  }

  @override
  Future<void> setAutoMeasureInterval(String type, int minutes) {
    final bridge = _activeBridge;
    if (bridge is! WearableAutoMeasureIntervalBridge) {
      throw PlatformException(
        code: 'AUTO_MEASURE_INTERVAL_UNSUPPORTED',
        message: '当前戒指不支持调整监测间隔',
      );
    }
    return (bridge as WearableAutoMeasureIntervalBridge).setAutoMeasureInterval(
      type,
      minutes,
    );
  }

  @override
  Future<int?> readHeartRateWarning() => _activeBridge.readHeartRateWarning();

  @override
  Future<void> setHeartRateWarning(int value) =>
      _activeBridge.setHeartRateWarning(value);

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) =>
      _activeBridge.readDeviceFeature(feature);

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) => _activeBridge.writeDeviceFeature(feature, values);

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) => _activeBridge.triggerDeviceAction(feature, enabled: enabled);

  void _subscribeToSourceEvents() {
    if (_subscriptions.isNotEmpty) return;
    for (final entry in _sources.entries) {
      _subscriptions.add(
        entry.value.events.listen(
          (event) => _forwardEvent(entry.key, event),
          onError: _eventController.addError,
        ),
      );
    }
  }

  void _cancelSourceEvents() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  void _forwardEvent(WearableTransport transport, WearableEvent event) {
    if (_pendingRecoveryWork.containsKey(transport) &&
        (_sourceConnectionGenerations[transport] != _connectionGeneration ||
            _activeTransport != transport)) {
      // Retired native callbacks may arrive before disconnect finishes. They
      // must not re-adopt the old watch or publish health data after cancellation.
      return;
    }
    if (event.type == 'scanDevice') {
      final device = DeviceInfo.fromMap(event.payload);
      if (!WearableDeviceClassifier.routesTo(device.name, transport)) {
        return;
      }
      final routed = RoutedDevice.fromDevice(transport, device);
      // A user can tap a device as soon as it appears. Keep the routing table
      // in sync with live discovery events instead of waiting for the native
      // scan Future to finish.
      _scanned[routed.display.id] = routed;
      _eventController.add(
        WearableEvent(type: event.type, payload: routed.display.toJson()),
      );
      return;
    }
    if (transport == _activeTransport) {
      if (event.type == 'disconnected' || event.type == 'reconnected') {
        ++_connectionGeneration;
      }
      if (event.type == 'deviceDetails' ||
          event.type == 'reconnected' ||
          event.type == 'disconnected' ||
          event.type == 'syncProgress' ||
          event.type == 'cameraShutter') {
        final payload = Map<String, Object?>.from(event.payload);
        final usesPrimaryId =
            event.type == 'deviceDetails' || event.type == 'reconnected';
        final nativeValue = usesPrimaryId ? payload['id'] : payload['deviceId'];
        final nativeIdentifier = '${nativeValue ?? ''}';
        if (nativeIdentifier.isNotEmpty) {
          final prefix = '${transport.name}:';
          final scopedIdentifier = nativeIdentifier.startsWith(prefix)
              ? nativeIdentifier
              : RoutedDevice.scopedID(transport, nativeIdentifier);
          if (payload.containsKey('id')) payload['id'] = scopedIdentifier;
          if (payload.containsKey('deviceId')) {
            payload['deviceId'] = scopedIdentifier;
          }
        }
        _eventController.add(WearableEvent(type: event.type, payload: payload));
        return;
      }
      _eventController.add(event);
    }
  }

  Future<void> dispose() async {
    _cancelSourceEvents();
    await _eventController.close();
  }
}

abstract interface class WearableTransportPreferenceStore {
  Future<WearableTransport?> read();
  Future<void> write(WearableTransport transport);
  Future<void> clear();
}

class SavedWearableBinding {
  const SavedWearableBinding(this.transport, this.nativeIdentifier);

  final WearableTransport transport;
  final String nativeIdentifier;
}

abstract interface class WearableBindingPreferenceStore
    implements WearableTransportPreferenceStore {
  Future<SavedWearableBinding?> readBinding();
  Future<void> writeBinding(SavedWearableBinding binding);
}

class SecureWearableTransportPreferenceStore
    implements WearableBindingPreferenceStore {
  const SecureWearableTransportPreferenceStore({this.storageNamespace});

  final String? storageNamespace;
  String get _key =>
      'saydian.global.env.${globalStorageNamespace(storageNamespace)}.wearable.binding.v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, Object?>?> _readValue() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  WearableTransport? _transport(Object? value) {
    for (final transport in WearableTransport.values) {
      if (transport.name == value) return transport;
    }
    return null;
  }

  @override
  Future<WearableTransport?> read() async =>
      _transport((await _readValue())?['transport']);

  @override
  Future<SavedWearableBinding?> readBinding() async {
    final value = await _readValue();
    final transport = _transport(value?['transport']);
    final identifier = value?['nativeIdentifier'];
    if (transport == null || identifier is! String || identifier.isEmpty) {
      return null;
    }
    return SavedWearableBinding(transport, identifier);
  }

  @override
  Future<void> write(WearableTransport transport) => _storage.write(
    key: _key,
    value: jsonEncode({'transport': transport.name}),
  );

  @override
  Future<void> writeBinding(SavedWearableBinding binding) => _storage.write(
    key: _key,
    value: jsonEncode({
      'transport': binding.transport.name,
      'nativeIdentifier': binding.nativeIdentifier,
    }),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
