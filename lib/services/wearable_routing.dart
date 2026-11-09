import 'dart:async';
import '../domain/wearable_sync_result.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import '../domain/sleep_timeline.dart';
import 'global_storage_scope.dart';
import 'safe_secure_storage.dart';
import 'wearable_bridge.dart';

enum WearableTransport { veepoo, yucheng, moyoung, coolwear, qring }

/// Selects only the native transport that is allowed to attempt a handshake.
///
/// A name match is not treated as proof of device capability. The selected
/// SDK still has to complete its real handshake and capability read before the
/// App exposes any device feature.
class WearableDeviceClassifier {
  const WearableDeviceClassifier._();

  static bool _explicitQRing(String name) =>
      name.startsWith('R1') || name.startsWith('R2') || name.contains('R7C');

  static bool _qringMarker(String name) =>
      const ['R8', 'R21', 'R22'].any(name.contains);

  // The product owner confirmed these CoolWear/LuckRing model names. A name
  // only chooses a candidate transport; the native handshake still gates it.
  static String? coolwearModelForName(String name) {
    final normalized = name.trim().toUpperCase();
    if (_explicitQRing(normalized) || _qringMarker(normalized)) {
      return null;
    }
    if (normalized.contains('HR01')) return 'HR01';
    if (normalized.contains('HR05')) return 'HR05';
    final model = normalized.replaceAll(RegExp(r'[\s_-]+'), '');
    if (model.contains('R7ULTRA')) return 'R7Ultra';
    if (model.contains('R7PRO')) return 'R7Pro';
    if (normalized.contains('R7Y')) return 'R7Y';
    if (normalized.contains('R7')) return 'R7';
    if (normalized.contains('K80')) return 'K80';
    return null;
  }

  static WearableTransport? transportFor(String name) {
    final normalized = name.trim().toUpperCase();
    // Explicit prefix rules override inherited substring matches (R7C/R7).
    if (_explicitQRing(normalized)) return WearableTransport.qring;
    final qring = _qringMarker(normalized);
    final luckring = const [
      'R7',
      'K80',
      'HR01',
      'HR05',
    ].any(normalized.contains);
    // User-confirmed model markers take priority over inherited SDK prefixes.
    // A conflicting name cannot select either SDK without clarification.
    if (qring && luckring) return null;
    if (qring) return WearableTransport.qring;
    if (luckring) return WearableTransport.coolwear;
    if (normalized.startsWith('R')) return WearableTransport.qring;
    if (normalized.startsWith('YC')) return WearableTransport.yucheng;
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

  static bool isVibratingReminderCandidate(String name) {
    if (_explicitQRing(name.trim().toUpperCase())) return false;
    final transport = transportFor(name);
    if (transport == WearableTransport.coolwear) {
      return const {
        'R7Pro',
        'R7Ultra',
        'HR05',
      }.contains(coolwearModelForName(name));
    }
    return transport == WearableTransport.qring &&
        name.toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '').contains('R8PRO');
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
        WearableRecentHistoryBridge,
        WearableHealthReceiptBridge,
        WearableDeviceDetailsBridge,
        WearableWatchFaceProfileBridge,
        WearableNativeWatchFaceBridge,
        WearableAutoMeasureIntervalBridge,
        WearableSportPauseBridge,
        WearableConnectionRecoveryBridge,
        WearableBindingManagementBridge,
        WearableRingDataClearBridge,
        WearableRememberedRecoveryEligibilityBridge,
        WearableDirectRememberedRecoveryBridge,
        WearableReadOnlyHealthPolicyBridge,
        WearableManualHealthPolicyBridge,
        WearableHealthReminderHapticsBridge,
        WearableBondedDeviceSelectionBridge {
  RoutedWearableBridge({
    WearableBridge? veepoo,
    WearableBridge? yucheng,
    WearableBridge? moyoung,
    WearableBridge? coolwear,
    WearableBridge? qring,
    WearableTransportPreferenceStore? preferenceStore,
    this.restoreOnlyBoundDevice = false,
    this.requireOwnerScopedBinding = false,
    this.includeSystemConnectedCandidates = false,
    this.recoveryOperationTimeout = const Duration(seconds: 30),
    this.recoveryStopScanTimeout = const Duration(seconds: 3),
  }) : _sources = {
         WearableTransport.veepoo: ?veepoo,
         WearableTransport.yucheng: ?yucheng,
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
  final bool includeSystemConnectedCandidates;
  final Duration recoveryOperationTimeout;
  final Duration recoveryStopScanTimeout;
  final Map<String, RoutedDevice> _scanned = {};
  final Set<String> _manualRecoveryIds = {};
  final StreamController<WearableEvent> _eventController =
      StreamController<WearableEvent>.broadcast();
  final List<StreamSubscription<WearableEvent>> _subscriptions = [];
  WearableTransport? _activeTransport;
  // 同一通道也可能换戒指。保留本轮明确目标，旧设备迟到的断开/数据
  // 不能改变新会话代次；此字段不持久化、不替代账号绑定或实际握手。
  String? _activeNativeIdentifier;
  int _connectionGeneration = 0;
  int? _activeConnectionGeneration;
  final Map<WearableTransport, int> _sourceConnectionGenerations = {};
  final Map<WearableTransport, Future<void>> _pendingRecoveryWork = {};
  int? _restoringGeneration;
  String? _recoveryOwnerKey;
  int _recoveryContextGeneration = 0;
  final Map<WearableTransport, String> _exactRecoveryTargets = {};
  ({String deviceId, int contextGeneration, String profile})?
  _directRecoveryLease;
  Future<void> _bindingMutationTail = Future<void>.value();
  Future<List<DeviceInfo>>? _scanInFlight;
  int _scanGeneration = 0;
  int _selectionGeneration = 0;
  bool _acceptScanEvents = false;

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
      if (store is WearableConditionalBindingPreferenceStore) {
        saved = await store.writeBindingIfCurrent(
          binding,
          isCurrent: isCurrent,
        );
        return;
      }
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
      if (_recoveryOwnerKey != null) {
        // 上一账号已显示的候选同样要撤销，否则旧列表的点击仍能走到原生连接。
        ++_scanGeneration;
        _scanInFlight = null;
        _acceptScanEvents = false;
        _scanned.clear();
        _manualRecoveryIds.clear();
      }
      // 等待原生取消期间不得继续读取上一账号的绑定；只有最新一次切换可以启用新账号。
      _recoveryOwnerKey = null;
      _directRecoveryLease = null;
      _exactRecoveryTargets.clear();
      for (final source in _sources.values) {
        if (contextGeneration != _recoveryContextGeneration) return;
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

  // 两种手动入口共用有效期。读取缓存或系统蓝牙期间，切号、换目标、重搜都可能发生。
  bool Function() _beginManualSelection() {
    final selection = ++_selectionGeneration;
    final context = _recoveryContextGeneration;
    final scan = _scanGeneration;
    final connection = _connectionGeneration;
    final owner = _recoveryOwnerKey;
    return () =>
        selection == _selectionGeneration &&
        context == _recoveryContextGeneration &&
        scan == _scanGeneration &&
        connection == _connectionGeneration &&
        owner == _recoveryOwnerKey;
  }

  Future<DeviceInfo?> _lookupOwnedSystemTarget(
    WearableBridge source,
    SavedWearableBinding saved,
  ) async {
    final owner = _recoveryOwnerKey;
    if (source is! WearableOwnedSystemTargetBridge ||
        owner == null ||
        saved.ownerKey != owner ||
        saved.deviceName == null ||
        !WearableDeviceClassifier.routesTo(
          saved.deviceName!,
          saved.transport,
        )) {
      return null;
    }
    final DeviceInfo? device;
    try {
      device = await (source as WearableOwnedSystemTargetBridge)
          .lookupOwnedSystemTarget(saved.nativeIdentifier)
          .timeout(recoveryOperationTimeout);
    } on Exception {
      // 系统查询只是捷径。旧原生端、系统枚举失败或超时，都交还给原扫描和权限流程。
      return null;
    }
    if (device == null ||
        device.id != saved.nativeIdentifier ||
        !WearableDeviceClassifier.routesTo(device.name, saved.transport)) {
      return null;
    }
    return device;
  }

  @override
  Future<DeviceInfo?> prepareRememberedDevice() async {
    final current = _beginManualSelection();
    final saved = await _readVisibleBinding();
    if (!current() || saved == null) return null;
    final source = _sources[saved.transport];
    if (source == null) {
      throw PlatformException(
        code: 'DEVICE_SDK_UNAVAILABLE',
        message: '此版本不支持该设备，请选择兼容的智能戒指',
      );
    }
    final DeviceInfo? device;
    if (source is WearableOwnedSystemTargetBridge) {
      device = await _lookupOwnedSystemTarget(source, saved);
    } else if (source is WearableRememberedDeviceSelectionBridge) {
      device = await (source as WearableRememberedDeviceSelectionBridge)
          .prepareRememberedDeviceForSelection(
            saved.nativeIdentifier,
            knownName: saved.deviceName,
          );
    } else {
      return null;
    }
    if (!current() || device?.id != saved.nativeIdentifier) return null;
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
    final directLease = _directRecoveryLease;
    if (directLease != null &&
        directLease.deviceId ==
            RoutedDevice.scopedID(
              binding.transport,
              binding.nativeIdentifier,
            ) &&
        directLease.contextGeneration == _recoveryContextGeneration &&
        directLease.profile == jsonEncode(profile.toMap()) &&
        _exactRecoveryTargets[binding.transport] == binding.nativeIdentifier) {
      // A manual exact restore already armed this native owner. Re-entering
      // foreground must not reconfigure it during the vendor handshake/probe.
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
  Future<void> configureReadOnlyHealthMetrics(
    Set<HealthMetric> metrics, {
    required Duration validity,
  }) async {
    final adapters = _sources.values
        .whereType<WearableReadOnlyHealthPolicyBridge>()
        .toList();
    if (adapters.isEmpty) {
      throw const WearableSdkNotConfigured('健康数据读取暂不可用');
    }
    try {
      await Future.wait(
        adapters.map(
          (adapter) => adapter.configureReadOnlyHealthMetrics(
            metrics,
            validity: validity,
          ),
        ),
      );
    } catch (_) {
      await Future.wait(
        adapters.map((adapter) async {
          try {
            await adapter.configureReadOnlyHealthMetrics(
              const {},
              validity: Duration.zero,
            );
          } catch (_) {}
        }),
      );
      rethrow;
    }
  }

  @override
  Future<void> configureManualHealthMetrics(
    Set<HealthMetric> metrics, {
    required Duration validity,
  }) async {
    final adapters = _sources.values
        .whereType<WearableManualHealthPolicyBridge>()
        .toList();
    if (adapters.isEmpty) throw const WearableSdkNotConfigured('手动测量暂不可用');
    try {
      await Future.wait(
        adapters.map(
          (adapter) =>
              adapter.configureManualHealthMetrics(metrics, validity: validity),
        ),
      );
    } catch (_) {
      await Future.wait(
        adapters.map((adapter) async {
          try {
            await adapter.configureManualHealthMetrics(
              const {},
              validity: Duration.zero,
            );
          } catch (_) {}
        }),
      );
      rethrow;
    }
  }

  @override
  Future<List<DeviceInfo>> scanDevices() {
    if (_scanInFlight != null) return _scanInFlight!;
    final generation = ++_scanGeneration;
    late Future<List<DeviceInfo>> pending;
    pending = (() async {
      try {
        return await _scanDevices(generation);
      } finally {
        if (generation == _scanGeneration) _acceptScanEvents = false;
        if (identical(_scanInFlight, pending)) _scanInFlight = null;
      }
    })();
    _scanInFlight = pending;
    return pending;
  }

  Future<List<DeviceInfo>> _scanDevices(int generation) async {
    _exactRecoveryTargets.clear();
    // 只在本轮开始时清理；撤销原生恢复可能很慢，等它回来再清会误删下一轮已显示的戒指。
    _scanned.clear();
    _manualRecoveryIds.clear();
    for (final source in _sources.values) {
      if (generation != _scanGeneration) return const [];
      if (source is WearableExactTargetRecoveryBridge) {
        await (source as WearableExactTargetRecoveryBridge)
            .configureRecoveryTarget(nativeIdentifier: null);
      }
    }
    if (generation != _scanGeneration) return const [];
    _acceptScanEvents = true;
    final errors = <PlatformException>[];
    final batches = await Future.wait(
      _sources.entries.map((entry) async {
        try {
          return MapEntry(
            entry.key,
            await entry.value.scanDevices().timeout(
              const Duration(seconds: 18),
            ),
          );
        } catch (error) {
          // A canceled round may fail after its replacement has started. Its
          // cleanup must not stop the new native scan on the same SDK.
          if (generation != _scanGeneration) {
            return MapEntry(entry.key, const <DeviceInfo>[]);
          }
          if (error is PlatformException) errors.add(error);
          try {
            await entry.value.stopScan().timeout(recoveryStopScanTimeout);
          } catch (_) {}
          // One unavailable SDK must not hide rings found by another SDK.
          return MapEntry(entry.key, const <DeviceInfo>[]);
        }
      }),
    );
    if (generation != _scanGeneration) return const [];
    for (final batch in batches) {
      for (final device in batch.value) {
        if (!WearableDeviceClassifier.routesTo(device.name, batch.key)) {
          continue;
        }
        final routed = RoutedDevice.fromDevice(batch.key, device);
        _scanned[routed.display.id] = routed;
      }
    }
    if (_scanned.isEmpty) {
      final failure = errors
          .where(
            (error) =>
                error.code.contains('SCAN') ||
                error.code.contains('BLE_') ||
                error.code.contains('BLUETOOTH') ||
                error.code == 'LOCATION_SERVICE_DISABLED',
          )
          .firstOrNull;
      if (failure != null) throw failure;
    }
    return _scanned.values.map((device) => device.display).toList();
  }

  @override
  Future<List<DeviceInfo>> listBondedDevicesForSelection() async {
    final current = _beginManualSelection();
    final owner = _recoveryOwnerKey;
    final selected = <String, RoutedDevice>{};
    final manualIds = <String>{};
    _manualRecoveryIds.clear();

    Future<void> prepareCached(SavedWearableBinding saved) async {
      final id = RoutedDevice.scopedID(saved.transport, saved.nativeIdentifier);
      if (!current() || selected.containsKey(id)) return;
      final source = _sources[saved.transport];
      if (source is! WearableRememberedDeviceSelectionBridge) return;
      DeviceInfo? remembered;
      try {
        remembered = await (source as WearableRememberedDeviceSelectionBridge)
            .prepareRememberedDeviceForSelection(
              saved.nativeIdentifier,
              knownName: saved.deviceName,
              cacheOnly: true,
            )
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        // A missing/unavailable cache must still allow normal discovery.
        return;
      }
      if (!current() || remembered?.id != saved.nativeIdentifier) return;
      // Legacy bindings remain explicit manual choices; they never arm recovery.
      if (saved.ownerKey != null &&
          !WearableDeviceClassifier.routesTo(
            remembered!.name,
            saved.transport,
          )) {
        return;
      }
      selected[id] = RoutedDevice.fromDevice(saved.transport, remembered!);
      manualIds.add(id);
    }

    final preference = _preferenceStore;
    if (preference is WearableBindingPreferenceStore) {
      SavedWearableBinding? saved;
      try {
        saved = await preference.readBinding();
      } catch (_) {
        saved = null;
      }
      if (!current()) return const [];
      if (saved != null &&
          (!requireOwnerScopedBinding ||
              saved.ownerKey == null ||
              saved.ownerKey == owner)) {
        await prepareCached(saved);
      }
    }
    if (!current()) return const [];
    if (owner != null && preference is WearableRecentBindingPreferenceStore) {
      List<SavedWearableBinding> recent;
      try {
        recent = await preference.readRecentBindings(owner);
      } catch (_) {
        recent = const [];
      }
      if (!current()) return const [];
      for (final saved in recent) {
        if (!current()) return const [];
        if (saved.ownerKey != owner ||
            saved.deviceName == null ||
            !WearableDeviceClassifier.routesTo(
              saved.deviceName!,
              saved.transport,
            )) {
          continue;
        }
        await prepareCached(saved);
      }
    }
    if (!current()) return const [];

    // 系统已连接的戒指可能暂停广播；即使已找回另一枚缓存戒指，也要合并系统候选。
    final hasCached = selected.isNotEmpty;
    if (!hasCached || includeSystemConnectedCandidates) {
      for (final entry in _sources.entries) {
        if (!current()) return const [];
        final source = entry.value;
        if (source is! WearableBondedDeviceSelectionBridge) continue;
        late final List<DeviceInfo> bonded;
        try {
          final lookup = (source as WearableBondedDeviceSelectionBridge)
              .listBondedDevicesForSelection();
          bonded = hasCached
              ? await lookup.timeout(const Duration(seconds: 2))
              : await lookup;
        } catch (_) {
          if (!hasCached) rethrow;
          continue;
        }
        if (!current()) return const [];
        for (final device in bonded) {
          if (!WearableDeviceClassifier.routesTo(device.name, entry.key)) {
            continue;
          }
          final routed = RoutedDevice.fromDevice(entry.key, device);
          selected.putIfAbsent(routed.display.id, () => routed);
        }
      }
    }
    if (!current()) return const [];
    // Publish atomically after all awaits, never a previous account's result.
    _scanned.addAll(selected);
    _manualRecoveryIds.addAll(manualIds);
    return selected.values.map((device) => device.display).toList();
  }

  @override
  Future<void> stopScan() {
    ++_selectionGeneration;
    ++_scanGeneration;
    _acceptScanEvents = false;
    _scanInFlight = null;
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
    _directRecoveryLease = null;
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
    final previousTransport = _activeTransport;
    final previous = _sources[previousTransport];
    final changesTransport =
        previousTransport != null && previousTransport != device.transport;
    final retiringGeneration = changesTransport
        ? ++_connectionGeneration
        : null;
    if (changesTransport) {
      // 换通道前先撤销旧事件归属；退出期间迟到的断开/恢复回包不能改新连接代次。
      // 这里只停用 SDK 会话，不调用路由解绑，也不清账号保存的恢复目标。
      _activeTransport = null;
      _activeNativeIdentifier = null;
      _activeConnectionGeneration = null;
    }
    if (previous is WearableExactTargetRecoveryBridge) {
      _exactRecoveryTargets.remove(previousTransport);
      await (previous as WearableExactTargetRecoveryBridge)
          .configureRecoveryTarget(nativeIdentifier: null);
    } else if (previous != null && changesTransport) {
      // 非 Exact SDK 也可能有安装级自动重连。切走时必须普通断开，不能让旧
      // SDK 继续抢占无线连接。复用屏障，保留超时后仍在运行的真实退出任务。
      var pending = _pendingRecoveryWork[previousTransport];
      if (pending == null) {
        late final Future<void> retiring;
        retiring = previous.disconnect().whenComplete(() {
          if (identical(_pendingRecoveryWork[previousTransport], retiring)) {
            _pendingRecoveryWork.remove(previousTransport);
          }
        });
        _pendingRecoveryWork[previousTransport] = retiring;
        unawaited(retiring.catchError((Object _) {}));
        pending = retiring;
      }
      await pending.timeout(recoveryOperationTimeout);
    }
    if (contextGeneration != _recoveryContextGeneration ||
        connectionOwnerKey != _recoveryOwnerKey ||
        (retiringGeneration != null &&
            retiringGeneration != _connectionGeneration)) {
      return;
    }

    final generation = ++_connectionGeneration;
    bool isCurrent() =>
        generation == _connectionGeneration &&
        contextGeneration == _recoveryContextGeneration &&
        connectionOwnerKey == _recoveryOwnerKey;
    _activeTransport = device.transport;
    _activeNativeIdentifier = device.nativeIdentifier;
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
            final details = active is WearableConnectionSnapshotBridge
                ? await (active as WearableConnectionSnapshotBridge)
                      .getConnectedDeviceSnapshot()
                : await (active as WearableDeviceDetailsBridge)
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
        _activeNativeIdentifier = null;
        _activeConnectionGeneration = null;
      }
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _directRecoveryLease = null;
    final disconnectGeneration = ++_connectionGeneration;
    final transport = _activeTransport;
    if (transport != null) _exactRecoveryTargets.remove(transport);
    if (transport == null) return;
    final connectionOwner = _activeConnectionGeneration;
    final pending = _pendingRecoveryWork[transport];
    if (pending == null) {
      await _sources[transport]!.disconnect();
    } else {
      await pending.timeout(recoveryOperationTimeout);
    }
    if (_activeConnectionGeneration != connectionOwner) return;
    _activeTransport = null;
    _activeNativeIdentifier = null;
    _activeConnectionGeneration = null;
    if (!requireOwnerScopedBinding &&
        disconnectGeneration == _connectionGeneration) {
      try {
        await _serializeBindingMutation(_preferenceStore.clear);
      } catch (_) {
        // The SDK disconnect has completed; storage remains retryable.
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
        _activeNativeIdentifier = details.id;
        _activeConnectionGeneration = generation;
        return RoutedDevice.fromDevice(entry.key, details).display;
      } on PlatformException catch (error) {
        if (error.code != 'NO_SAVED_DEVICE') rethrow;
      }
    }
    return null;
  }

  @override
  Future<({bool started, DeviceInfo? device})> restoreRememberedDeviceDirectly({
    required String expectedDeviceId,
    required WearableUserProfile profile,
  }) async {
    final generation = ++_connectionGeneration;
    _restoringGeneration = generation;
    var started = false;
    try {
      final device = await _restoreBoundDevice(
        profile,
        generation,
        directDeviceId: expectedDeviceId,
        onExactRecoveryStarted: () => started = true,
      );
      return (started: started, device: device);
    } finally {
      if (_restoringGeneration == generation) _restoringGeneration = null;
    }
  }

  Future<DeviceInfo?> _restoreBoundDevice(
    WearableUserProfile profile,
    int generation, {
    String? directDeviceId,
    void Function()? onExactRecoveryStarted,
  }) async {
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
    if (directDeviceId != null &&
        (saved.transport != WearableTransport.qring ||
            _recoveryOwnerKey == null ||
            saved.ownerKey != _recoveryOwnerKey ||
            saved.deviceName == null ||
            RoutedDevice.scopedID(saved.transport, saved.nativeIdentifier) !=
                directDeviceId ||
            source is! WearableExactTargetRecoveryBridge)) {
      return null;
    }
    if (source == null) {
      throw PlatformException(
        code: 'DEVICE_SDK_UNAVAILABLE',
        message: '此版本不支持该设备，请选择兼容的智能戒指',
      );
    }
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
      _activeNativeIdentifier = saved.nativeIdentifier;
      _activeConnectionGeneration = generation;
      _sourceConnectionGenerations[saved.transport] = generation;
      await _armExactRecovery(source, saved, profile);
      onExactRecoveryStarted?.call();
      if (generation != _connectionGeneration) return null;
      if (directDeviceId != null) {
        _directRecoveryLease = (
          deviceId: directDeviceId,
          contextGeneration: _recoveryContextGeneration,
          profile: jsonEncode(profile.toMap()),
        );
      }
      if (source is WearableDeviceDetailsBridge) {
        final current = source is WearableConnectionSnapshotBridge
            ? await (source as WearableConnectionSnapshotBridge)
                  .getConnectedDeviceSnapshot()
            : await (source as WearableDeviceDetailsBridge)
                  .getConnectedDeviceDetails();
        if (generation != _connectionGeneration) return null;
        if (current?.id == saved.nativeIdentifier &&
            WearableDeviceClassifier.routesTo(current!.name, saved.transport)) {
          final routed = RoutedDevice.fromDevice(saved.transport, current);
          _scanned[routed.display.id] = routed;
          return routed.display;
        }
      }
      return null;
    }
    if (source is WearableOwnedSystemTargetBridge) {
      final current = await _lookupOwnedSystemTarget(source, saved);
      if (generation != _connectionGeneration) return null;
      if (current != null) {
        try {
          return await _connectBoundTarget(
            saved.transport,
            source,
            current,
            generation,
            profile,
          );
        } on PlatformException catch (error) {
          // 只在确定连接已经结束时回到正常搜索。还在处理的原生任务保留原有屏障。
          if (generation != _connectionGeneration) return null;
          if (!const {
            'UNKNOWN_SCANNED_DEVICE',
            'COOLWEAR_HANDSHAKE_TIMEOUT',
            'COOLWEAR_HANDSHAKE_FAILED',
            'COOLWEAR_DISCONNECTED',
          }.contains(error.code)) {
            rethrow;
          }
        }
      }
    }
    // Native SDKs keep installation-wide saved targets. Never ask them to
    // restore a target selected in another API environment.
    final List<DeviceInfo> scanned;
    try {
      scanned =
          await (source is WearableBoundTargetDiscoveryBridge
                  ? (source as WearableBoundTargetDiscoveryBridge)
                        .scanForBoundDevice(saved.nativeIdentifier)
                  : source.scanDevices())
              .timeout(recoveryOperationTimeout);
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
    return _connectBoundTarget(
      saved.transport,
      source,
      target,
      generation,
      profile,
    );
  }

  Future<DeviceInfo?> _connectBoundTarget(
    WearableTransport transport,
    WearableBridge source,
    DeviceInfo target,
    int generation,
    WearableUserProfile profile,
  ) async {
    if (!WearableDeviceClassifier.routesTo(target.name, transport)) return null;
    final routed = RoutedDevice.fromDevice(transport, target);
    _activeTransport = transport;
    _activeNativeIdentifier = target.id;
    _activeConnectionGeneration = generation;
    _sourceConnectionGenerations[transport] = generation;
    var timedOut = false;
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
      if (_activeConnectionGeneration == generation) {
        _activeTransport = null;
        _activeNativeIdentifier = null;
      }
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
      _activeNativeIdentifier = null;
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
    final generation = _connectionGeneration;
    final identifier = _activeNativeIdentifier;
    bool current() =>
        generation == _connectionGeneration &&
        transport == _activeTransport &&
        identifier == _activeNativeIdentifier;
    final DeviceInfo? details;
    try {
      details = await (bridge as WearableDeviceDetailsBridge)
          .getConnectedDeviceDetails();
    } catch (_) {
      // 旧查询的失败只属于旧会话，不能交给新戒指的页面当成当前断开。
      if (!current()) return null;
      rethrow;
    }
    // 返回空值也必须核对代次；否则旧页面的轮询会清掉后来已连接的目标。
    if (!current()) return null;
    if (details == null) {
      if (bridge is! WearableExactTargetRecoveryBridge) {
        _activeTransport = null;
        _activeNativeIdentifier = null;
      }
      return null;
    }
    if (identifier != null && details.id != identifier) return null;
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
  Future<List<HealthRecord>> syncHealthData({String? cursor}) =>
      _syncHistory(cursor: cursor);

  @override
  Future<void> acknowledgeHealthRecords(Map<String, String> receipts) async {
    if (_activeTransport == null) return;
    final source = _activeBridge;
    if (source is WearableHealthReceiptBridge) {
      final generation = _connectionGeneration;
      await (source as WearableHealthReceiptBridge).acknowledgeHealthRecords(
        receipts,
      );
      _requireCurrentConnection(generation, message: '戒指连接已变化');
    }
  }

  @override
  bool get supportsRecentHistorySync {
    if (_activeTransport != WearableTransport.qring) return false;
    final source = _activeBridge;
    return source is WearableRecentHistoryBridge &&
        (source as WearableRecentHistoryBridge).supportsRecentHistorySync;
  }

  @override
  Future<List<HealthRecord>> syncRecentHealthData({required int days}) =>
      _syncHistory(days: days);

  Future<List<HealthRecord>> _syncHistory({String? cursor, int? days}) async {
    final transport = _activeTransport;
    if (transport == null) {
      throw PlatformException(code: 'NOT_CONNECTED', message: '请先连接戒指');
    }
    final generation = _connectionGeneration;
    final source = _activeBridge;
    if (days != null && !supportsRecentHistorySync) {
      throw StateError('Recent history unavailable');
    }
    final records = days == null
        ? await source.syncHealthData(cursor: cursor)
        : await (source as WearableRecentHistoryBridge).syncRecentHealthData(
            days: days,
          );
    _requireCurrentConnection(generation, message: '戒指连接已变化，请重新同步');
    final scoped = records
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
    return records is WearableSyncResult
        ? WearableSyncResult(
            scoped,
            records.statuses,
            historyDays: records.historyDays,
            receipts: records.receipts,
            protocolChecks: records.protocolChecks,
          )
        : scoped;
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
  Future<RingDataClearResult> clearRingHistory({
    required String deviceId,
    required String ownerKey,
    bool allowFactoryReset = false,
  }) async {
    final generation = _connectionGeneration;
    final bridge = _activeBridge;
    final transport = _activeTransport;
    final binding = await _readVisibleBinding();
    _requireCurrentConnection(generation);
    if (ownerKey != _recoveryOwnerKey ||
        binding == null ||
        binding.ownerKey != ownerKey ||
        binding.transport != transport ||
        RoutedDevice.scopedID(binding.transport, binding.nativeIdentifier) !=
            deviceId) {
      throw PlatformException(
        code: 'STALE_DEVICE_SESSION',
        message: '戒指或账号已变化，未清空数据',
      );
    }
    if (bridge is! WearableRingDataClearBridge) {
      throw PlatformException(
        code: 'RING_HISTORY_CLEAR_UNSUPPORTED',
        message: '此戒指暂不支持仅清除历史数据，未执行恢复出厂',
      );
    }
    final result = await (bridge as WearableRingDataClearBridge)
        .clearRingHistory(
          deviceId: binding.nativeIdentifier,
          ownerKey: ownerKey,
          allowFactoryReset: allowFactoryReset,
        );
    _requireCurrentConnection(generation);
    return result;
  }

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

  @override
  Future<RingReminderHapticResult> pulseHealthReminder({
    required String expectedDeviceId,
  }) {
    final source = _activeBridge;
    if (WearableDeviceClassifier.transportForScopedId(expectedDeviceId) !=
            _activeTransport ||
        source is! WearableHealthReminderHapticsBridge) {
      throw PlatformException(code: 'UNSUPPORTED', message: '此设备暂不支持振动提醒');
    }
    final nativeId = expectedDeviceId.substring(
      expectedDeviceId.indexOf(':') + 1,
    );
    return (source as WearableHealthReminderHapticsBridge).pulseHealthReminder(
      expectedDeviceId: nativeId,
    );
  }

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
    if (event.type == 'ringInitialization' &&
        (event.payload['ownerKey'] != _recoveryOwnerKey ||
            _recoveryOwnerKey == null)) {
      return;
    }
    if (requireOwnerScopedBinding &&
        _sources[transport] is WearableExactTargetRecoveryBridge &&
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
      if (!_acceptScanEvents) return;
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
      if (event.type == 'deviceDetails' ||
          event.type == 'reconnected' ||
          event.type == 'disconnected' ||
          event.type == 'syncProgress' ||
          event.type == 'syncRecords' ||
          event.type == 'recoveryState' ||
          event.type == 'sleepReadStatus' ||
          event.type == 'ringInitialization' ||
          event.type == 'healthRecord' ||
          event.type == 'sportData' ||
          event.type == 'sportState' ||
          event.type == 'cameraShutter' ||
          event.type == 'cameraRemoteStopped') {
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
          final expected = _activeNativeIdentifier;
          if (expected != null &&
              scopedIdentifier != RoutedDevice.scopedID(transport, expected)) {
            return;
          }
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
        // 必须先校验通道、精确目标和载荷，再改变连接代次。否则被丢弃的
        // 旧断开通知仍会使正在执行的同步误报“连接已变化”。无标识的原厂
        // 断开事件沿用原生会话校验，真实断开仍立即使旧读取失效。
        if (event.type == 'disconnected' || event.type == 'reconnected') {
          ++_connectionGeneration;
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

/// Previous successful targets are offered only for explicit selection by
/// the same owner. They never participate in automatic recovery.
abstract interface class WearableRecentBindingPreferenceStore
    implements WearableTransportPreferenceStore {
  Future<List<SavedWearableBinding>> readRecentBindings(String ownerKey);
}

/// Compensates both binding and candidate writes if their owner changes.
abstract interface class WearableConditionalBindingPreferenceStore
    implements WearableBindingPreferenceStore {
  Future<bool> writeBindingIfCurrent(
    SavedWearableBinding binding, {
    required bool Function() isCurrent,
  });
}

class SecureWearableTransportPreferenceStore
    implements
        WearableConditionalBindingPreferenceStore,
        WearableRecentBindingPreferenceStore {
  const SecureWearableTransportPreferenceStore({this.storageNamespace});

  final String? storageNamespace;
  String get _environment => globalStorageNamespace(storageNamespace);
  String get _key => 'saydian.global.env.$_environment.wearable.binding.v1';
  String _historyKey(String owner) =>
      'saydian.global.env.$_environment.wearable.selection-history.v1.'
      '${sha256.convert(utf8.encode(owner))}';
  final FlutterSecureStorage _storage = safeSecureStorage;

  Map<String, Object?>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  bool _owned(Map<String, Object?>? value, String owner, int version) =>
      owner.isNotEmpty &&
      value?['schemaVersion'] == version &&
      value?['environment'] == _environment &&
      value?['ownerKey'] == owner;

  WearableTransport? _transport(Object? value) => WearableTransport.values
      .where((transport) => transport.name == value)
      .firstOrNull;

  SavedWearableBinding? _candidate(Object? value, String owner) {
    if (value is! Map) return null;
    final transport = _transport(value['transport']);
    final id = value['nativeIdentifier'];
    final name = value['deviceName'];
    if (transport == null ||
        id is! String ||
        id.isEmpty ||
        name is! String ||
        !WearableDeviceClassifier.routesTo(name, transport)) {
      return null;
    }
    return SavedWearableBinding(
      transport,
      id,
      deviceName: name.trim(),
      ownerKey: owner,
    );
  }

  List<SavedWearableBinding> _history(String? raw, String owner) {
    final value = _decode(raw);
    if (!_owned(value, owner, 1) || value?['bindings'] is! List) {
      return const [];
    }
    return (value!['bindings'] as List)
        .map((entry) => _candidate(entry, owner))
        .whereType<SavedWearableBinding>()
        .toList();
  }

  List<SavedWearableBinding> _legacyHistory(
    Map<String, Object?>? value,
    String owner,
  ) {
    if (!_owned(value, owner, 2)) return const [];
    return [
          value,
          ...?value?['recentBindings'] is List
              ? value!['recentBindings'] as List
              : null,
        ]
        .map((entry) => _candidate(entry, owner))
        .whereType<SavedWearableBinding>()
        .toList();
  }

  List<SavedWearableBinding> _unique(Iterable<SavedWearableBinding> entries) {
    final seen = <String>{};
    return entries
        .where(
          (entry) => seen.add(
            RoutedDevice.scopedID(entry.transport, entry.nativeIdentifier),
          ),
        )
        .take(4)
        .toList();
  }

  Map<String, Object?> _entry(SavedWearableBinding binding) => {
    'transport': binding.transport.name,
    'nativeIdentifier': binding.nativeIdentifier,
    if (binding.deviceName != null) 'deviceName': binding.deviceName,
  };

  Future<void> _writeHistory(
    String owner,
    List<SavedWearableBinding> entries,
  ) => _storage.write(
    key: _historyKey(owner),
    value: jsonEncode({
      'schemaVersion': 1,
      'environment': _environment,
      'ownerKey': owner,
      'bindings': _unique(entries).map(_entry).toList(),
    }),
  );

  @override
  Future<WearableTransport?> read() async =>
      _transport(_decode(await _storage.read(key: _key))?['transport']);

  @override
  Future<SavedWearableBinding?> readBinding() async {
    final value = _decode(await _storage.read(key: _key));
    if (value?['schemaVersion'] == 2 && value?['environment'] != _environment) {
      return null;
    }
    final transport = _transport(value?['transport']);
    final identifier = value?['nativeIdentifier'];
    if (transport == null || identifier is! String || identifier.isEmpty) {
      return null;
    }
    final rawName = value?['deviceName'];
    final rawOwner = value?['ownerKey'];
    return SavedWearableBinding(
      transport,
      identifier,
      deviceName: rawName is String && rawName.trim().isNotEmpty
          ? rawName.trim()
          : null,
      ownerKey: rawOwner is String && rawOwner.isNotEmpty ? rawOwner : null,
    );
  }

  @override
  Future<void> write(WearableTransport transport) async {
    await clear();
    await _storage.write(
      key: _key,
      value: jsonEncode({'transport': transport.name}),
    );
  }

  @override
  Future<void> writeBinding(SavedWearableBinding binding) async {
    await writeBindingIfCurrent(binding, isCurrent: () => true);
  }

  @override
  Future<bool> writeBindingIfCurrent(
    SavedWearableBinding binding, {
    required bool Function() isCurrent,
  }) async {
    final previousRaw = await _storage.read(key: _key);
    final previous = _decode(previousRaw);
    final owner = binding.ownerKey;
    final previousOwner = previous?['ownerKey'];
    final owners = <String>{
      if (owner != null && owner.isNotEmpty) owner,
      if (previousOwner is String && _owned(previous, previousOwner, 2))
        previousOwner,
    };
    final snapshots = <String, String?>{};
    for (final candidateOwner in owners) {
      snapshots[_historyKey(candidateOwner)] = await _storage.read(
        key: _historyKey(candidateOwner),
      );
    }
    if (!isCurrent()) return false;
    Future<void> rollback() async {
      for (final entry in {...snapshots, _key: previousRaw}.entries) {
        if (entry.value == null) {
          await _storage.delete(key: entry.key);
        } else {
          await _storage.write(key: entry.key, value: entry.value!);
        }
      }
    }

    try {
      for (final candidateOwner in owners) {
        final raw = snapshots[_historyKey(candidateOwner)];
        if (raw != null &&
            (!_owned(_decode(raw), candidateOwner, 1) ||
                _decode(raw)?['bindings'] is! List)) {
          throw StateError('Invalid retained ring history; not overwritten');
        }
        final entries = <SavedWearableBinding>[
          if (candidateOwner == owner &&
              _candidate(_entry(binding), candidateOwner) != null)
            binding,
          ..._legacyHistory(previous, candidateOwner),
          ..._history(raw, candidateOwner),
        ];
        if (!isCurrent()) {
          await rollback();
          return false;
        }
        await _writeHistory(candidateOwner, entries);
      }
      if (!isCurrent()) {
        await rollback();
        return false;
      }
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'schemaVersion': owner == null ? 1 : 2,
          if (owner != null) ...{
            'environment': _environment,
            'ownerKey': owner,
          },
          ..._entry(binding),
        }),
      );
      if (!isCurrent()) {
        await rollback();
        return false;
      }
      return true;
    } catch (_) {
      await rollback();
      rethrow;
    }
  }

  @override
  Future<List<SavedWearableBinding>> readRecentBindings(String ownerKey) async {
    if (ownerKey.isEmpty) return const [];
    final current = _decode(await _storage.read(key: _key));
    final history = await _storage.read(key: _historyKey(ownerKey));
    return _unique([
          ..._history(history, ownerKey),
          ..._legacyHistory(current, ownerKey),
        ])
        .where(
          (entry) =>
              !(_owned(current, ownerKey, 2) &&
                  entry.transport == _transport(current?['transport']) &&
                  entry.nativeIdentifier == current?['nativeIdentifier']),
        )
        .toList();
  }

  @override
  Future<void> clear() async {
    // Unbinding retires the automatic target, not the same-owner manual list.
    // Migrate legacy embedded candidates before deleting the old binding key.
    final value = _decode(await _storage.read(key: _key));
    final owner = value?['ownerKey'];
    if (owner is String && _owned(value, owner, 2)) {
      final raw = await _storage.read(key: _historyKey(owner));
      if (raw != null &&
          (!_owned(_decode(raw), owner, 1) ||
              _decode(raw)?['bindings'] is! List)) {
        throw StateError('Invalid retained ring history; binding not removed');
      }
      await _writeHistory(owner, [
        ..._legacyHistory(value, owner),
        ..._history(raw, owner),
      ]);
    }
    await _storage.delete(key: _key);
  }
}
