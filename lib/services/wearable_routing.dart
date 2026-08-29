import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import 'wearable_bridge.dart';

enum WearableTransport { veepoo, yucheng }

class YuchengDeviceClassifier {
  const YuchengDeviceClassifier._();

  static const _models = ['W8ULTRAR', 'W8ULTRA', 'W8PRO', 'W8S', 'W8'];

  static bool matches(String name) {
    final normalized = name.toUpperCase().replaceAll(
      RegExp(r'[\s\-‐‑‒–—]'),
      '',
    );
    for (final model in _models) {
      if (normalized == model) return true;
      if (!normalized.startsWith(model)) continue;
      final suffix = normalized.substring(model.length);
      if (RegExp(r'^[0-9A-F]{4,6}$').hasMatch(suffix)) return true;
    }
    return false;
  }
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
        WearableAutoMeasureIntervalBridge,
        WearableConnectionRecoveryBridge {
  RoutedWearableBridge({
    required WearableBridge veepoo,
    required WearableBridge yucheng,
  }) : _sources = {
         WearableTransport.veepoo: veepoo,
         WearableTransport.yucheng: yucheng,
       } {
    _eventController
      ..onListen = _subscribeToSourceEvents
      ..onCancel = _cancelSourceEvents;
  }

  final Map<WearableTransport, WearableBridge> _sources;
  final Map<String, RoutedDevice> _scanned = {};
  final StreamController<WearableEvent> _eventController =
      StreamController<WearableEvent>.broadcast();
  final List<StreamSubscription<WearableEvent>> _subscriptions = [];
  WearableTransport? _activeTransport;

  WearableBridge get _activeBridge {
    final transport = _activeTransport;
    if (transport == null) {
      throw PlatformException(code: 'NOT_CONNECTED', message: '请先连接手表');
    }
    return _sources[transport]!;
  }

  @override
  Stream<WearableEvent> get events => _eventController.stream;

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    _scanned.clear();
    final results = await Future.wait([
      _sources[WearableTransport.veepoo]!.scanDevices(),
      _sources[WearableTransport.yucheng]!.scanDevices(),
    ]);
    final candidates =
        <RoutedDevice>[
          ...results[0].map(
            (device) =>
                RoutedDevice.fromDevice(WearableTransport.veepoo, device),
          ),
          ...results[1].map(
            (device) =>
                RoutedDevice.fromDevice(WearableTransport.yucheng, device),
          ),
        ].where((candidate) {
          // Yucheng-family devices must use Yucheng. The two native SDKs expose
          // different identifiers for the same watch, so filtering here avoids a
          // duplicate Veepoo entry even when identifier-based grouping cannot.
          return candidate.transport == WearableTransport.yucheng ||
              !YuchengDeviceClassifier.matches(candidate.display.name);
        }).toList();
    final grouped = <String, List<RoutedDevice>>{};
    for (final candidate in candidates) {
      grouped.putIfAbsent(candidate.nativeIdentifier, () => []).add(candidate);
    }

    for (final group in grouped.values) {
      final selected = _selectDevice(group);
      if (selected == null) continue;
      _scanned[selected.display.id] = selected;
    }
    return _scanned.values.map((device) => device.display).toList();
  }

  RoutedDevice? _selectDevice(List<RoutedDevice> candidates) {
    final hasYuchengModel = candidates.any(
      (candidate) => YuchengDeviceClassifier.matches(candidate.display.name),
    );
    if (hasYuchengModel) {
      for (final candidate in candidates) {
        if (candidate.transport == WearableTransport.yucheng &&
            YuchengDeviceClassifier.matches(candidate.display.name)) {
          return candidate;
        }
      }
      return candidates.firstWhere(
        (candidate) => candidate.transport == WearableTransport.veepoo,
        orElse: () => candidates.first,
      );
    }
    for (final candidate in candidates) {
      if (candidate.transport == WearableTransport.veepoo) return candidate;
    }
    return null;
  }

  @override
  Future<void> stopScan() => Future.wait([
    _sources[WearableTransport.veepoo]!.stopScan(),
    _sources[WearableTransport.yucheng]!.stopScan(),
  ]).then((_) {});

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
    if (device.transport == WearableTransport.veepoo &&
        YuchengDeviceClassifier.matches(device.display.name)) {
      throw PlatformException(
        code: 'YUCHENG_DISCOVERY_MISMATCH',
        message: 'Yuc 设备未被云创 SDK 识别，请重新扫描后重试',
      );
    }

    _activeTransport = device.transport;
    try {
      await _activeBridge.connect(device.nativeIdentifier, profile: profile);
    } catch (_) {
      _activeTransport = null;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final transport = _activeTransport;
    if (transport == null) return;
    try {
      await _sources[transport]!.disconnect();
    } finally {
      _activeTransport = null;
    }
  }

  @override
  Future<DeviceInfo?> restoreConnection({
    required WearableUserProfile profile,
  }) async {
    for (final entry in _sources.entries) {
      final bridge = entry.value;
      if (bridge is! WearableConnectionRecoveryBridge) continue;
      try {
        final details = await (bridge as WearableConnectionRecoveryBridge)
            .restoreConnection(profile: profile);
        if (details == null) continue;
        _activeTransport = entry.key;
        return RoutedDevice.fromDevice(entry.key, details).display;
      } on PlatformException catch (error) {
        if (error.code != 'NO_SAVED_DEVICE') rethrow;
      }
    }
    return null;
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

  @override
  Future<DeviceCapabilities> getCapabilities() =>
      _activeBridge.getCapabilities();

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) =>
      _activeBridge.syncHealthData(cursor: cursor);

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
        message: '当前手表不支持调整监测间隔',
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
    if (event.type == 'scanDevice') {
      final device = DeviceInfo.fromMap(event.payload);
      // Both Android SDKs can report the same W8-family watch while scanning.
      // W8 devices are owned by Yucheng, so never expose the Veepoo discovery
      // event to the controller (the completed scan is filtered the same way).
      if (transport == WearableTransport.veepoo &&
          YuchengDeviceClassifier.matches(device.name)) {
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
