import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import '../domain/sleep_timeline.dart';
import 'global_storage_scope.dart';
import 'wearable_bridge.dart';

enum WearableTransport { veepoo, yucheng, moyoung, coolwear, qring }

/// Selects only the native transport that is allowed to attempt a handshake.
///
/// A name prefix is not treated as proof of device capability. The selected
/// SDK still has to complete its real handshake and capability read before the
/// App exposes any device feature.
class WearableDeviceClassifier {
  const WearableDeviceClassifier._();

  // The product owner confirmed these CoolWear/LuckRing model names. A name
  // only chooses a candidate transport; the native handshake still gates it.
  static final _coolwearName = RegExp(
    r'^(HR01|HR05|K80|R7PRO|R7Y|R7)(?:[-_ ](?:[0-9A-F]{1,12}|(?:[0-9A-F]{2}:){5}[0-9A-F]{2}))?$',
  );

  static String? coolwearModelForName(String name) {
    final normalized = name.trim().toUpperCase();
    // Preserve the existing HR01 numbered/custom hyphen suffix convention.
    if (normalized.startsWith('HR01-')) return 'HR01';
    final model = _coolwearName.firstMatch(normalized)?.group(1);
    return model == 'R7PRO' ? 'R7Pro' : model;
  }

  static WearableTransport? transportFor(String name) {
    final normalized = name.trim().toUpperCase();
    if (normalized.startsWith('YC')) return WearableTransport.yucheng;
    if (coolwearModelForName(normalized) != null) {
      return WearableTransport.coolwear;
    }
    if (normalized.startsWith('Q_') ||
        normalized.startsWith('O_') ||
        normalized.startsWith('R2')) {
      return WearableTransport.qring;
    }
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
      'coolwear' => WearableTransport.coolwear,
      'qring' => WearableTransport.qring,
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
        WearableConnectionRecoveryBridge,
        WearableBindingManagementBridge,
        WearableRememberedRecoveryEligibilityBridge,
        WearableBondedDeviceSelectionBridge {
  RoutedWearableBridge({
    required WearableBridge veepoo,
    required WearableBridge yucheng,
    WearableBridge? moyoung,
    WearableBridge? coolwear,
    WearableBridge? qring,
    WearableTransportPreferenceStore? preferenceStore,
    this.restoreOnlyBoundDevice = false,
    this.requireOwnerScopedBinding = false,
    this.recoveryOperationTimeout = const Duration(seconds: 30),
    this.recoveryStopScanTimeout = const Duration(seconds: 3),
  }) : _sources = {
         WearableTransport.veepoo: veepoo,
         WearableTransport.yucheng: yucheng,
       },
       _preferenceStore =
           preferenceStore ?? const SecureWearableTransportPreferenceStore() {
    if (moyoung != null) _sources[WearableTransport.moyoung] = moyoung;
    if (coolwear != null) _sources[WearableTransport.coolwear] = coolwear;
    if (qring != null) _sources[WearableTransport.qring] = qring;
    _eventController
      ..onListen = _subscribeToSourceEvents
      ..onCancel = _cancelSourceEvents;
  }

  final Map<WearableTransport, WearableBridge> _sources;
  final WearableTransportPreferenceStore _preferenceStore;
  final bool restoreOnlyBoundDevice;
  final bool requireOwnerScopedBinding;
  final Duration recoveryOperationTimeout;
  final Duration recoveryStopScanTimeout;
  final Map<String, RoutedDevice> _scanned = {};
  final Set<String> _manualRecoveryIds = {};
  final StreamController<WearableEvent> _eventController =
      StreamController<WearableEvent>.broadcast();
  final List<StreamSubscription<WearableEvent>> _subscriptions = [];
  WearableTransport? _activeTransport;
  int _connectionGeneration = 0;
  int? _activeConnectionGeneration;
  final Map<WearableTransport, int> _sourceConnectionGenerations = {};
  final Map<WearableTransport, Future<void>> _pendingRecoveryWork = {};
  int? _restoringGeneration;
  String? _recoveryOwnerKey;
  int _recoveryContextGeneration = 0;
  final Map<WearableTransport, String> _exactRecoveryTargets = {};
  Future<void> _bindingMutationTail = Future<void>.value();

  Future<void> _serializeBindingMutation(Future<void> Function() operation) {
    final mutation = _bindingMutationTail.then((_) => operation());
    _bindingMutationTail = mutation.catchError((Object _) {});
    return mutation;
  }

  Future<bool> _writeCurrentBinding(
    WearableBindingPreferenceStore store,
    SavedWearableBinding binding,
    bool Function() isCurrent,
  ) async {
    var saved = false;
    await _serializeBindingMutation(() async {
      if (!isCurrent()) return;
      final previous = await store.readBinding();
      if (!isCurrent()) return;
      await store.writeBinding(binding);
      if (isCurrent()) {
        saved = true;
        return;
      }
      // Secure storage has no CAS primitive. Serialize all bridge mutations
      // and roll back a write whose session changed while storage awaited.
      if (previous == null) {
        await _preferenceStore.clear();
      } else {
        await store.writeBinding(previous);
      }
    });
    return saved;
  }

  bool _bindingBelongsToOwner(SavedWearableBinding binding) =>
      !requireOwnerScopedBinding ||
      (_recoveryOwnerKey != null && binding.ownerKey == _recoveryOwnerKey);

  @override
  Future<void> setRecoveryContext({
    required String? ownerKey,
    required WearableUserProfile profile,
  }) async {
    final changesOwner = _recoveryOwnerKey != ownerKey || ownerKey == null;
    final contextGeneration = changesOwner
        ? ++_recoveryContextGeneration
        : _recoveryContextGeneration;
    if (changesOwner) {
      ++_connectionGeneration;
      _exactRecoveryTargets.clear();
      for (final source in _sources.values) {
        if (source is WearableExactTargetRecoveryBridge) {
          await (source as WearableExactTargetRecoveryBridge)
              .configureRecoveryTarget(nativeIdentifier: null);
        }
      }
    }
    if (contextGeneration != _recoveryContextGeneration) return;
    _recoveryOwnerKey = ownerKey;
  }

  Future<SavedWearableBinding?> _readVisibleBinding() async {
    final store = _preferenceStore;
    if (store is! WearableBindingPreferenceStore) return null;
    final saved = await store.readBinding();
    if (saved == null) return null;
    if (requireOwnerScopedBinding &&
        saved.ownerKey != null &&
        saved.ownerKey != _recoveryOwnerKey) {
      return null;
    }
    return saved;
  }

  @override
  Future<DeviceInfo?> readRememberedDevice() async {
    final saved = await _readVisibleBinding();
    if (saved == null || saved.deviceName == null) return null;
    if (!WearableDeviceClassifier.routesTo(
      saved.deviceName!,
      saved.transport,
    )) {
      return null;
    }
    return DeviceInfo(
      id: RoutedDevice.scopedID(saved.transport, saved.nativeIdentifier),
      name: saved.deviceName!,
      model: saved.deviceName,
    );
  }

  @override
  Future<bool> canAutomaticallyRecoverRememberedDevice() async {
    final saved = await _readVisibleBinding();
    return saved != null &&
        _bindingBelongsToOwner(saved) &&
        saved.deviceName != null &&
        _sources.containsKey(saved.transport) &&
        WearableDeviceClassifier.routesTo(saved.deviceName!, saved.transport);
  }

  @override
  Future<DeviceInfo?> prepareRememberedDevice() async {
    final saved = await _readVisibleBinding();
    if (saved == null) return null;
    final source = _sources[saved.transport];
    if (source is! WearableRememberedDeviceSelectionBridge) return null;
    final device = await (source as WearableRememberedDeviceSelectionBridge)
        .prepareRememberedDeviceForSelection(
          saved.nativeIdentifier,
          knownName: saved.deviceName,
        );
    if (device?.id != saved.nativeIdentifier) return null;
    final routed = RoutedDevice.fromDevice(saved.transport, device!);
    _scanned[routed.display.id] = routed;
    _manualRecoveryIds.add(routed.display.id);
    return routed.display;
  }

  @override
  Future<void> forgetRememberedDevice() async {
    await disconnect();
    await _serializeBindingMutation(_preferenceStore.clear);
  }

  Future<void> _armExactRecovery(
    WearableBridge source,
    SavedWearableBinding binding,
    WearableUserProfile profile,
  ) async {
    if (source is! WearableExactTargetRecoveryBridge ||
        !_bindingBelongsToOwner(binding) ||
        binding.deviceName == null) {
      return;
    }
    final store = _preferenceStore;
    final environment = store is SecureWearableTransportPreferenceStore
        ? globalStorageNamespace(store.storageNamespace)
        : 'local';
    _exactRecoveryTargets[binding.transport] = binding.nativeIdentifier;
    await (source as WearableExactTargetRecoveryBridge).configureRecoveryTarget(
      nativeIdentifier: binding.nativeIdentifier,
      knownName: binding.deviceName,
      contextKey: '$environment:${binding.ownerKey ?? 'compatibility'}',
      profile: profile,
    );
  }

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
    _exactRecoveryTargets.clear();
    for (final source in _sources.values) {
      if (source is WearableExactTargetRecoveryBridge) {
        await (source as WearableExactTargetRecoveryBridge)
            .configureRecoveryTarget(nativeIdentifier: null);
      }
    }
    _scanned.clear();
    _manualRecoveryIds.clear();
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
  Future<List<DeviceInfo>> listBondedDevicesForSelection() async {
    final selected = <DeviceInfo>[];
    final selectedIds = <String>{};
    _manualRecoveryIds.clear();
    for (final entry in _sources.entries) {
      final source = entry.value;
      if (source is! WearableBondedDeviceSelectionBridge) continue;
      final bonded = await (source as WearableBondedDeviceSelectionBridge)
          .listBondedDevicesForSelection();
      for (final device in bonded) {
        if (!WearableDeviceClassifier.routesTo(device.name, entry.key)) {
          continue;
        }
        final routed = RoutedDevice.fromDevice(entry.key, device);
        _scanned[routed.display.id] = routed;
        if (selectedIds.add(routed.display.id)) selected.add(routed.display);
      }
    }
    final preference = _preferenceStore;
    if (preference is WearableBindingPreferenceStore) {
      SavedWearableBinding? saved;
      try {
        saved = await preference.readBinding();
      } catch (_) {
        saved = null;
      }
      if (saved != null &&
          (!requireOwnerScopedBinding ||
              saved.ownerKey == null ||
              saved.ownerKey == _recoveryOwnerKey)) {
        final source = _sources[saved.transport];
        final savedDisplayId = RoutedDevice.scopedID(
          saved.transport,
          saved.nativeIdentifier,
        );
        if (!selectedIds.contains(savedDisplayId) &&
            source is WearableRememberedDeviceSelectionBridge) {
          final remembered =
              await (source as WearableRememberedDeviceSelectionBridge)
                  .prepareRememberedDeviceForSelection(
                    saved.nativeIdentifier,
                    knownName: saved.deviceName,
                  );
          if (remembered?.id == saved.nativeIdentifier) {
            final routed = RoutedDevice.fromDevice(
              saved.transport,
              remembered!,
            );
            _scanned[routed.display.id] = routed;
            _manualRecoveryIds.add(routed.display.id);
            if (selectedIds.add(routed.display.id)) {
              selected.add(routed.display);
            }
          }
        }
      }
    }
    return selected;
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
    final isExplicitRememberedTarget = _manualRecoveryIds.contains(deviceId);
    if (!isExplicitRememberedTarget &&
        !WearableDeviceClassifier.routesTo(
          device.display.name,
          device.transport,
        )) {
      throw PlatformException(
        code: 'DEVICE_PROVIDER_MISMATCH',
        message: '设备信息已变化，请重新扫描后重试',
      );
    }
    _requireRecoverySourceAvailable(device.transport);

    final connectionOwnerKey = _recoveryOwnerKey;
    final contextGeneration = _recoveryContextGeneration;
    final previous = _activeTransport == null
        ? null
        : _sources[_activeTransport];
    if (previous is WearableExactTargetRecoveryBridge) {
      _exactRecoveryTargets.remove(_activeTransport);
      await (previous as WearableExactTargetRecoveryBridge)
          .configureRecoveryTarget(nativeIdentifier: null);
    }
    if (contextGeneration != _recoveryContextGeneration ||
        connectionOwnerKey != _recoveryOwnerKey) {
      return;
    }

    final generation = ++_connectionGeneration;
    bool isCurrent() =>
        generation == _connectionGeneration &&
        contextGeneration == _recoveryContextGeneration &&
        connectionOwnerKey == _recoveryOwnerKey;
    _activeTransport = device.transport;
    _activeConnectionGeneration = generation;
    _sourceConnectionGenerations[device.transport] = generation;
    try {
      await _activeBridge.connect(device.nativeIdentifier, profile: profile);
      try {
        if (!isCurrent()) return;
        var verifiedName =
            WearableDeviceClassifier.routesTo(
              device.display.name,
              device.transport,
            )
            ? device.display.name
            : null;
        final active = _activeBridge;
        if (active is WearableDeviceDetailsBridge) {
          try {
            final details = await (active as WearableDeviceDetailsBridge)
                .getConnectedDeviceDetails();
            if (!isCurrent()) return;
            if (details != null &&
                details.id == device.nativeIdentifier &&
                WearableDeviceClassifier.routesTo(
                  details.name,
                  device.transport,
                )) {
              verifiedName = details.name;
              _scanned[deviceId] = RoutedDevice.fromDevice(
                device.transport,
                details,
              );
            }
          } catch (_) {
            // Connection success does not depend on optional display details.
          }
        }
        if (!isCurrent()) return;
        final preference = _preferenceStore;
        if (preference is WearableBindingPreferenceStore) {
          final binding = SavedWearableBinding(
            device.transport,
            device.nativeIdentifier,
            deviceName: verifiedName,
            ownerKey: connectionOwnerKey,
          );
          if (!await _writeCurrentBinding(preference, binding, isCurrent) ||
              !isCurrent()) {
            return;
          }
          await _armExactRecovery(active, binding, profile);
        } else {
          if (!isCurrent()) return;
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
    if (transport != null) _exactRecoveryTargets.remove(transport);
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
      if (!requireOwnerScopedBinding &&
          disconnectGeneration == _connectionGeneration) {
        try {
          await _serializeBindingMutation(_preferenceStore.clear);
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
    if (saved == null ||
        generation != _connectionGeneration ||
        !_bindingBelongsToOwner(saved)) {
      return null;
    }
    final source = _sources[saved.transport];
    if (source == null) return null;
    _requireRecoverySourceAvailable(saved.transport);
    if (source is WearableExactTargetRecoveryBridge &&
        saved.deviceName != null) {
      if (!WearableDeviceClassifier.routesTo(
        saved.deviceName!,
        saved.transport,
      )) {
        return null;
      }
      _activeTransport = saved.transport;
      _activeConnectionGeneration = generation;
      _sourceConnectionGenerations[saved.transport] = generation;
      await _armExactRecovery(source, saved, profile);
      if (generation != _connectionGeneration) return null;
      if (source is WearableDeviceDetailsBridge) {
        final current = await (source as WearableDeviceDetailsBridge)
            .getConnectedDeviceDetails();
        if (current?.id == saved.nativeIdentifier &&
            WearableDeviceClassifier.routesTo(current!.name, saved.transport)) {
          final routed = RoutedDevice.fromDevice(saved.transport, current);
          _scanned[routed.display.id] = routed;
          return routed.display;
        }
      }
      return null;
    }
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
    if (target == null && source is WearableBoundDeviceLookupBridge) {
      // Some bonded BLE rings stop advertising after pairing. Only the exact
      // device previously bound in this environment may be looked up, and the
      // native adapter must validate the OS bond before normal SDK connect.
      final bonded = await (source as WearableBoundDeviceLookupBridge)
          .lookupPreviouslyBoundDevice(saved.nativeIdentifier)
          .timeout(recoveryOperationTimeout);
      if (generation != _connectionGeneration) return null;
      if (bonded?.id == saved.nativeIdentifier) target = bonded;
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
      if (bridge is! WearableExactTargetRecoveryBridge) _activeTransport = null;
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
          final timeline = record.sleepTimeline == null
              ? null
              : SleepTimeline.fromJson(
                  _scopeSleepTimeline(
                    record.sleepTimeline!.toJson(),
                    transport,
                  ),
                );
          if (timeline != null && timeline.deviceId != deviceId) {
            throw PlatformException(
              code: 'DEVICE_PROVIDER_MISMATCH',
              message: '睡眠数据来源已变化，请重新同步',
            );
          }
          return record.copyWith(
            deviceId: deviceId,
            sleepTimeline: timeline,
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
    if (requireOwnerScopedBinding &&
        transport == WearableTransport.qring &&
        event.type == 'reconnected') {
      final identifier = '${event.payload['id'] ?? ''}';
      final expected = _exactRecoveryTargets[transport];
      if (_recoveryOwnerKey == null ||
          expected == null ||
          (identifier != expected &&
              identifier != RoutedDevice.scopedID(transport, expected))) {
        return;
      }
    }
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
          event.type == 'recoveryState' ||
          event.type == 'sleepReadStatus' ||
          event.type == 'healthRecord' ||
          event.type == 'cameraShutter') {
        final payload = Map<String, Object?>.from(event.payload);
        final usesPrimaryId =
            event.type == 'deviceDetails' || event.type == 'reconnected';
        final nativeValue = usesPrimaryId ? payload['id'] : payload['deviceId'];
        final nativeIdentifier = '${nativeValue ?? ''}';
        if (nativeIdentifier.isNotEmpty) {
          final existing = WearableDeviceClassifier.transportForScopedId(
            nativeIdentifier,
          );
          if (existing != null && existing != transport) return;
          final prefix = '${transport.name}:';
          final scopedIdentifier = nativeIdentifier.startsWith(prefix)
              ? nativeIdentifier
              : RoutedDevice.scopedID(transport, nativeIdentifier);
          if (usesPrimaryId && payload.containsKey('id')) {
            payload['id'] = scopedIdentifier;
          }
          if (payload.containsKey('deviceId')) {
            payload['deviceId'] = scopedIdentifier;
          }
        }
        if (payload['sleepTimeline'] is Map) {
          try {
            final timeline = _scopeSleepTimeline(
              Map<String, Object?>.from(payload['sleepTimeline'] as Map),
              transport,
            );
            if (timeline['deviceId'] != payload['deviceId']) return;
            payload['sleepTimeline'] = timeline;
          } on PlatformException {
            return;
          }
        }
        _eventController.add(WearableEvent(type: event.type, payload: payload));
        return;
      }
      _eventController.add(event);
    }
  }

  Map<String, Object?> _scopeSleepTimeline(
    Map<String, Object?> timeline,
    WearableTransport transport,
  ) {
    final identifier = '${timeline['deviceId'] ?? ''}';
    if (identifier.isEmpty) return timeline;
    final currentTransport = WearableDeviceClassifier.transportForScopedId(
      identifier,
    );
    if (currentTransport != null && currentTransport != transport) {
      throw PlatformException(
        code: 'DEVICE_PROVIDER_MISMATCH',
        message: '睡眠数据来源已变化，请重新同步',
      );
    }
    return {
      ...timeline,
      'deviceId': currentTransport == null
          ? RoutedDevice.scopedID(transport, identifier)
          : identifier,
    };
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
  const SavedWearableBinding(
    this.transport,
    this.nativeIdentifier, {
    this.deviceName,
    this.ownerKey,
  });

  final WearableTransport transport;
  final String nativeIdentifier;
  final String? deviceName;
  final String? ownerKey;
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
    if (value?['schemaVersion'] == 2 &&
        value?['environment'] != globalStorageNamespace(storageNamespace)) {
      return null;
    }
    final transport = _transport(value?['transport']);
    final identifier = value?['nativeIdentifier'];
    if (transport == null || identifier is! String || identifier.isEmpty) {
      return null;
    }
    final rawName = value?['deviceName'];
    final deviceName = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : null;
    final owner = value?['ownerKey'];
    return SavedWearableBinding(
      transport,
      identifier,
      deviceName: deviceName,
      ownerKey: owner is String && owner.isNotEmpty ? owner : null,
    );
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
      'schemaVersion': binding.ownerKey == null ? 1 : 2,
      if (binding.ownerKey != null) ...{
        'environment': globalStorageNamespace(storageNamespace),
        'ownerKey': binding.ownerKey,
      },
      'transport': binding.transport.name,
      'nativeIdentifier': binding.nativeIdentifier,
      if (binding.deviceName != null) 'deviceName': binding.deviceName,
    }),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
