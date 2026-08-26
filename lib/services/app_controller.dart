import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart' as platform_info;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/device_state_machine.dart';
import '../domain/feature_models.dart';
import '../domain/health_record_validation.dart';
import '../domain/models.dart';
import 'api_client.dart';
import 'local_health_store.dart';
import 'secure_vault.dart';
import 'sync_service.dart';
import 'wearable_bridge.dart';
import 'wearable_bootstrap.dart';

class AppController extends ChangeNotifier {
  AppController(this._vault, this._api, this._healthStore, this._wearable)
    : _syncService = HealthSyncService(_healthStore, _api);

  factory AppController.production() {
    final vault = SecureSessionVault();
    return AppController(
      vault,
      SaydianApiClient(vault),
      EncryptedHealthStore(vault),
      createProductionWearableBridge(),
    );
  }

  final SessionVault _vault;
  final SaydianApi _api;
  final HealthStore _healthStore;
  final WearableBridge _wearable;
  final HealthSyncService _syncService;
  final DeviceStateMachine deviceMachine = DeviceStateMachine();

  StreamSubscription<WearableEvent>? _wearableEvents;
  StreamSubscription<DeviceConnectionState>? _deviceStates;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _measurementTimeout;
  HealthMetric? _activeMeasurementMetric;
  bool _syncing = false;
  bool _disposed = false;
  int _deviceSyncGeneration = 0;
  DeviceInfo? _latestDeviceDetails;
  String? _deviceSyncErrorMessage;

  bool isBooting = true;
  bool isBusy = false;
  bool isDeviceSyncing = false;
  double deviceSyncProgress = 0;
  bool isPreviewMode = false;
  Session? session;
  int selectedTab = 0;
  String? errorMessage;
  String? measurementErrorMessage;
  int measurementProgress = 0;
  bool measurementWearConfirmed = true;
  List<num> measurementSamples = const [];
  int measurementSampleFrequency = 250;
  String storageStatus = '正在准备数据';
  String sdkStatus = '等待连接';
  String syncStatus = '尚未同步';
  String cloudSyncStatus = '尚未上传';
  DeviceInfo? connectedDevice;
  DeviceCapabilities? capabilities;
  DeviceCapabilityState deviceCapabilityState =
      DeviceCapabilityState.disconnected;
  SportMode? activeSport;
  List<DeviceInfo> scannedDevices = const [];
  List<HealthRecord> healthRecords = const [];
  List<SportRecord> sportRecords = const [];
  List<Map<String, Object?>> careMembers = const [];
  List<Map<String, Object?>> careInvitations = const [];
  String careStatus = '等待加载';
  String careInvitationStatus = '等待加载';
  List<Map<String, Object?>> aiArticles = const [];
  List<Map<String, Object?>> aiMessages = const [];
  String? articleCategoryLoadError;
  String? articleListLoadError;
  String? articleDetailLoadError;
  List<Map<String, Object?>> notifications = const [];
  List<Map<String, Object?>> orders = const [];
  List<Map<String, Object?>> addresses = const [];
  List<Map<String, Object?>> shopCart = const [];
  Map<String, Object?> memberProfile = const {};
  final Map<int, String> _aiSessionIds = {};
  String aiStatus = '等待加载';
  String notificationStatus = '等待加载';
  String orderStatus = '等待加载';
  int stepGoal = 10000;
  double distanceGoal = 6;
  int calorieGoal = 800;
  String distanceUnit = '公里';
  String temperatureUnit = '摄氏度（℃）';
  Map<String, bool> autoMeasureSettings = const {};
  Map<DeviceFeature, Map<String, Object?>> deviceFeatureData = const {};
  Set<DeviceFeature> deviceFeatureBusy = const {};
  int cameraShutterSequence = 0;
  int heartRateWarning = 120;
  bool heartRateWarningSupported = false;
  String deviceSettingsStatus = '连接手表后可读取';
  HealthWarningSettings healthWarningSettings = const HealthWarningSettings();
  List<HealthWarningAlert> healthWarningAlerts = const [];
  HealthWarningAlert? activeHealthWarningAlert;

  bool get isAuthenticated => session != null;
  DeviceConnectionState get deviceState => deviceMachine.state;
  HealthMetric? get activeMeasurementMetric => _activeMeasurementMetric;

  Map<HealthMetric, HealthRecord> get latestByMetric {
    final result = <HealthMetric, HealthRecord>{};
    for (final record in healthRecords) {
      result.putIfAbsent(record.metric, () => record);
    }
    return result;
  }

  Set<DeviceFeature> get visibleDeviceFeatures {
    final current = capabilities;
    if (!_hasResolvedDeviceCapabilities || current == null) {
      return const <DeviceFeature>{};
    }
    return current.features.intersection(current.integratedFeatures);
  }

  bool get _hasResolvedDeviceCapabilities =>
      deviceCapabilityState == DeviceCapabilityState.ready ||
      (deviceCapabilityState == DeviceCapabilityState.disconnected &&
          connectedDevice != null &&
          capabilities != null);

  bool shouldShowHealthMetric(HealthMetric metric) =>
      latestByMetric.containsKey(metric) ||
      (_hasResolvedDeviceCapabilities &&
          capabilities?.supports(metric) == true);

  bool canMeasureHealthMetric(HealthMetric metric) =>
      connectedDevice != null &&
      _hasResolvedDeviceCapabilities &&
      capabilities?.supportsManualMeasurement(metric) == true;

  Future<void> initialize() async {
    _deviceStates = deviceMachine.changes.listen((_) => notifyListeners());
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none) &&
          session != null) {
        unawaited(synchronizeCloud());
      }
    });
    try {
      await _healthStore.initialize();
      storageStatus = '数据已安全保存在本机';
      await _refreshHealthRecordCache();
      healthWarningAlerts = await _healthStore.healthWarningAlerts();
    } catch (_) {
      storageStatus = '本机数据暂时无法读取';
    }
    try {
      healthWarningSettings = await _vault.readHealthWarningSettings();
    } catch (_) {
      healthWarningSettings = const HealthWarningSettings();
    }
    try {
      shopCart = await _vault.readShopCart();
    } catch (_) {
      shopCart = const [];
    }
    try {
      session = await _vault.readSession();
    } catch (_) {
      errorMessage = '安全存储初始化失败';
    }
    try {
      _wearableEvents = _wearable.events.listen(
        _handleWearableEvent,
        onError: (_) {
          sdkStatus = '设备连接服务暂时不可用';
          notifyListeners();
        },
      );
    } catch (_) {
      sdkStatus = '设备连接服务暂时不可用';
    }
    isBooting = false;
    notifyListeners();
    unawaited(refreshAiArticles());
    if (session != null) {
      unawaited(refreshCare());
      unawaited(refreshCareInvitations());
      unawaited(refreshMemberProfile());
      unawaited(refreshActivityGoals());
    }
  }

  Future<bool> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      errorMessage = '请输入账号和密码';
      notifyListeners();
      return false;
    }
    return _guard(() async {
      session = await _api.login(username.trim(), password);
      isPreviewMode = false;
      await refreshCare();
      await refreshCareInvitations();
      await refreshMemberProfile();
      await refreshActivityGoals();
    });
  }

  Future<bool> sendSmsCode({
    required String mobile,
    required String usage,
  }) async {
    final normalized = mobile.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(normalized)) {
      errorMessage = '请输入正确的中国大陆手机号';
      notifyListeners();
      return false;
    }
    final api = _api;
    if (api is! SaydianSmsAuthApi) {
      errorMessage = '短信服务暂时无法使用，请稍后再试';
      notifyListeners();
      return false;
    }
    return _guard(
      () => (api as SaydianSmsAuthApi).sendSmsCode(
        mobile: normalized,
        usage: usage,
      ),
    );
  }

  Future<bool> register(
    String mobile,
    String password, {
    String? code,
    String? nickname,
  }) async {
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile.trim())) {
      errorMessage = '请输入正确的中国大陆手机号';
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      errorMessage = '密码至少需要 6 位';
      notifyListeners();
      return false;
    }
    final smsApi = _api is SaydianSmsAuthApi ? _api as SaydianSmsAuthApi : null;
    if (smsApi != null && !RegExp(r'^\d{4,6}$').hasMatch(code?.trim() ?? '')) {
      errorMessage = '请输入收到的短信验证码';
      notifyListeners();
      return false;
    }
    return _guard(() async {
      session = smsApi == null
          ? await _api.register(mobile.trim(), password)
          : await smsApi.registerWithSms(
              mobile: mobile.trim(),
              code: code!.trim(),
              password: password,
              nickname: nickname?.trim().isNotEmpty == true
                  ? nickname!.trim()
                  : '赛电用户${mobile.trim().substring(7)}',
            );
      isPreviewMode = false;
      await refreshCare();
      await refreshCareInvitations();
      await refreshMemberProfile();
      await refreshActivityGoals();
    });
  }

  Future<bool> resetPassword({
    required String mobile,
    required String code,
    required String password,
  }) async {
    final normalized = mobile.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(normalized)) {
      errorMessage = '请输入正确的中国大陆手机号';
      notifyListeners();
      return false;
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(code.trim())) {
      errorMessage = '请输入收到的短信验证码';
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      errorMessage = '密码至少需要 6 位';
      notifyListeners();
      return false;
    }
    final api = _api;
    if (api is! SaydianSmsAuthApi) {
      errorMessage = '找回密码服务暂时无法使用，请稍后再试';
      notifyListeners();
      return false;
    }
    return _guard(() async {
      session = await (api as SaydianSmsAuthApi).resetPassword(
        mobile: normalized,
        code: code.trim(),
        password: password,
      );
      isPreviewMode = false;
    });
  }

  void enterPreview() {
    isPreviewMode = true;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    isBusy = true;
    notifyListeners();
    try {
      if (session != null) {
        await _api.logout();
      } else {
        await _vault.clearSession();
      }
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '退出失败，请稍后重试');
    } finally {
      session = null;
      isPreviewMode = false;
      memberProfile = const {};
      aiMessages = const [];
      _aiSessionIds.clear();
      notifications = const [];
      orders = const [];
      addresses = const [];
      selectedTab = 0;
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() => _guard(() async {
    if (session == null) {
      throw const ApiException('快速体验账号无需注销');
    }
    await _api.deleteAccount();
    session = null;
    isPreviewMode = false;
  });

  void selectTab(int index) {
    if (selectedTab != index) {
      selectedTab = index;
      notifyListeners();
    }
    if (index == 1 && connectedDevice != null) {
      unawaited(refreshConnectedDeviceDetails());
    }
  }

  Future<void> scanDevices() async {
    errorMessage = null;
    scannedDevices = const [];
    try {
      if (!await _ensureBluetoothPermissions()) {
        errorMessage = '允许相关权限后使用';
        notifyListeners();
        return;
      }
      if (deviceState == DeviceConnectionState.error) {
        deviceMachine.transition(DeviceConnectionState.disconnected);
      }
      deviceMachine.transition(DeviceConnectionState.scanning);
      notifyListeners();
      final completedDevices = await _wearable.scanDevices();
      for (final device in completedDevices) {
        _upsertScannedDevice(device);
      }
      sdkStatus = '设备连接服务可用';
      if (deviceState == DeviceConnectionState.scanning) {
        deviceMachine.transition(DeviceConnectionState.disconnected);
      }
    } on WearableSdkNotConfigured catch (_) {
      sdkStatus = '设备连接服务暂时不可用';
      errorMessage = '此功能暂时无法使用，请稍后再试';
      deviceMachine.transition(DeviceConnectionState.error);
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(error, fallback: '暂时无法查找手表');
      deviceMachine.transition(DeviceConnectionState.error);
    } catch (_) {
      errorMessage = '暂时无法查找手表，请稍后重试';
      deviceMachine.transition(DeviceConnectionState.error);
    }
    notifyListeners();
  }

  Future<void> stopDeviceScan() async {
    if (deviceState != DeviceConnectionState.scanning) return;
    try {
      await _wearable.stopScan();
    } catch (_) {
      // Leaving the search page must remain possible even if the SDK has
      // already stopped the scan by timeout.
    } finally {
      if (!_disposed) {
        if (deviceState == DeviceConnectionState.scanning) {
          deviceMachine.transition(DeviceConnectionState.disconnected);
        }
        notifyListeners();
      }
    }
  }

  Future<bool> _ensureBluetoothPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final android = await platform_info.DeviceInfoPlugin().androidInfo;
    final permissions = android.version.sdkInt >= 31
        ? [Permission.bluetoothScan, Permission.bluetoothConnect]
        : [Permission.locationWhenInUse];
    final statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> connectDevice(DeviceInfo device) async {
    errorMessage = null;
    _invalidateDeviceSync();
    _latestDeviceDetails = null;
    try {
      if (deviceState == DeviceConnectionState.error) {
        deviceMachine.transition(DeviceConnectionState.disconnected);
      }
      if (deviceState == DeviceConnectionState.scanning) {
        deviceMachine.transition(DeviceConnectionState.connecting);
        try {
          await _wearable.stopScan().timeout(const Duration(seconds: 3));
        } on TimeoutException {
          // Some vendor SDK versions stop their native scanner but never
          // complete the Dart method call. Connecting is safe after the short
          // grace period and must not remain stuck on the add-device page.
        }
      } else {
        deviceMachine.transition(DeviceConnectionState.connecting);
      }
      await _wearable.connect(
        device.id,
        profile: WearableUserProfile.fromMember(
          memberProfile,
          targetSteps: stepGoal,
        ),
      );
      connectedDevice = _mergeDeviceDetails(device);
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.loading;
      deviceMachine.transition(DeviceConnectionState.authenticating);
      await refreshDeviceCapabilities(announceFailure: false);
      deviceMachine.transition(DeviceConnectionState.syncing);
      syncStatus = '正在同步设备数据';
      deviceMachine.transition(DeviceConnectionState.ready);
      // Authentication is the connection boundary. Historical data is a
      // background follow-up and must not keep the add-device page spinning.
      unawaited(_syncInitialDeviceData(device.id));
    } on WearableSdkNotConfigured catch (_) {
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      sdkStatus = '设备连接服务暂时不可用';
      errorMessage = '此功能暂时无法使用，请稍后再试';
      deviceMachine.transition(DeviceConnectionState.error);
    } on PlatformException catch (error) {
      if (error.code == 'CONNECT_CANCELLED') {
        errorMessage = null;
        if (deviceState != DeviceConnectionState.disconnected) {
          deviceMachine.transition(DeviceConnectionState.disconnected);
        }
      } else {
        deviceCapabilityState = DeviceCapabilityState.disconnected;
        errorMessage = _wearableErrorMessage(error, fallback: '设备连接失败');
        deviceMachine.transition(DeviceConnectionState.error);
      }
    } catch (_) {
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      errorMessage = '连接失败，请将手表靠近手机后重试';
      deviceMachine.transition(DeviceConnectionState.error);
    }
    notifyListeners();
  }

  Future<bool> refreshDeviceCapabilities({bool announceFailure = true}) async {
    if (connectedDevice == null) {
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      notifyListeners();
      return false;
    }
    final deviceId = connectedDevice!.id;
    capabilities = null;
    deviceCapabilityState = DeviceCapabilityState.loading;
    notifyListeners();
    try {
      final reported = await _wearable.getCapabilities();
      if (_disposed || connectedDevice?.id != deviceId) return false;
      capabilities = reported;
      deviceCapabilityState = DeviceCapabilityState.ready;
      notifyListeners();
      return true;
    } on PlatformException catch (error) {
      if (_disposed || connectedDevice?.id != deviceId) return false;
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.unavailable;
      if (announceFailure) {
        errorMessage = _wearableErrorMessage(error, fallback: '暂时无法读取此手表的功能');
      }
    } catch (_) {
      if (_disposed || connectedDevice?.id != deviceId) return false;
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.unavailable;
      if (announceFailure) errorMessage = '暂时无法读取此手表的功能';
    }
    notifyListeners();
    return false;
  }

  Future<void> _syncInitialDeviceData(String deviceId) async {
    if (connectedDevice?.id != deviceId || _disposed) return;
    final isCurrent = await _syncDeviceData(deviceId, initial: true);
    if (!isCurrent) return;
    unawaited(refreshSportRecords());
    unawaited(synchronizeCloud());
  }

  Future<void> syncDeviceData() async {
    final device = connectedDevice;
    if (device == null) {
      errorMessage = '请先连接手表';
      notifyListeners();
      return;
    }
    if (isDeviceSyncing) return;
    final succeeded = await _syncDeviceData(device.id, initial: false);
    if (succeeded) {
      unawaited(synchronizeCloud());
    }
  }

  Future<bool> _syncDeviceData(String deviceId, {required bool initial}) async {
    if (connectedDevice?.id != deviceId || isDeviceSyncing) return false;
    final generation = ++_deviceSyncGeneration;
    isDeviceSyncing = true;
    var succeeded = false;
    deviceSyncProgress = 0;
    syncStatus = '正在读取手表数据';
    _clearDeviceSyncError();
    notifyListeners();
    try {
      final receivedRecords = await _wearable.syncHealthData();
      if (!_isDeviceSyncCurrent(generation, deviceId)) return false;
      final records = receivedRecords
          .where(hasSaneWearableTransportValues)
          .toList();
      await _healthStore.upsert(records);
      if (!_isDeviceSyncCurrent(generation, deviceId)) return false;
      await _refreshHealthRecordCache();
      if (!_isDeviceSyncCurrent(generation, deviceId)) return false;
      syncStatus = records.isEmpty ? '设备暂无新数据' : '已同步 ${records.length} 条';
      succeeded = true;
    } on PlatformException catch (error) {
      if (!_isDeviceSyncCurrent(generation, deviceId)) return false;
      syncStatus = '设备已连接，${initial ? '首次数据同步失败' : '历史数据同步失败'}';
      _deviceSyncErrorMessage =
          '设备已连接，但${_wearableErrorMessage(error, fallback: initial ? '首次数据同步失败' : '历史数据同步失败')}';
      errorMessage = _deviceSyncErrorMessage;
    } catch (_) {
      if (!_isDeviceSyncCurrent(generation, deviceId)) return false;
      syncStatus = '设备已连接，${initial ? '首次数据同步失败' : '历史数据同步失败'}';
      _deviceSyncErrorMessage = '设备已连接，但数据读取失败，请稍后重试';
      errorMessage = _deviceSyncErrorMessage;
    } finally {
      if (_deviceSyncGeneration == generation) {
        isDeviceSyncing = false;
        deviceSyncProgress = 0;
        if (!_disposed) notifyListeners();
      }
    }
    return succeeded && _isDeviceSyncCurrent(generation, deviceId);
  }

  bool _isDeviceSyncCurrent(int generation, String deviceId) =>
      !_disposed &&
      _deviceSyncGeneration == generation &&
      connectedDevice?.id == deviceId;

  void _invalidateDeviceSync() {
    _deviceSyncGeneration++;
    isDeviceSyncing = false;
    deviceSyncProgress = 0;
    _clearDeviceSyncError();
  }

  void _clearDeviceSyncError() {
    if (errorMessage == _deviceSyncErrorMessage) {
      errorMessage = null;
    }
    _deviceSyncErrorMessage = null;
  }

  Future<void> disconnectDevice() async {
    _invalidateDeviceSync();
    try {
      await _wearable.disconnect();
    } finally {
      connectedDevice = null;
      _latestDeviceDetails = null;
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      deviceFeatureData = const {};
      deviceFeatureBusy = const {};
      if (deviceState != DeviceConnectionState.disconnected) {
        if (deviceState == DeviceConnectionState.error) {
          deviceMachine.transition(DeviceConnectionState.disconnected);
        } else {
          deviceMachine.transition(DeviceConnectionState.disconnected);
        }
      }
      notifyListeners();
    }
  }

  Future<bool> refreshConnectedDeviceDetails() async {
    final current = connectedDevice;
    final bridge = _wearable;
    if (current == null) return false;
    if (bridge is! WearableDeviceDetailsBridge) return true;
    try {
      final details = await (bridge as WearableDeviceDetailsBridge)
          .getConnectedDeviceDetails();
      if (_disposed) return false;
      if (details == null) {
        _invalidateDeviceSync();
        connectedDevice = null;
        _latestDeviceDetails = null;
        capabilities = null;
        deviceCapabilityState = DeviceCapabilityState.disconnected;
        deviceFeatureData = const {};
        deviceFeatureBusy = const {};
        if (deviceState != DeviceConnectionState.disconnected) {
          try {
            deviceMachine.transition(DeviceConnectionState.disconnected);
          } on StateError {
            // A concurrent native disconnect may already have moved the state.
          }
        }
        errorMessage = '手表连接已断开，请重新连接';
        notifyListeners();
        return false;
      }
      if (connectedDevice?.id != current.id || details.id != current.id) {
        return connectedDevice != null;
      }
      _latestDeviceDetails = details;
      connectedDevice = _mergeDeviceDetails(current);
      notifyListeners();
      return true;
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(error, fallback: '设备信息刷新失败，请稍后重试');
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = '设备信息刷新失败，请稍后重试';
      notifyListeners();
      return false;
    }
  }

  Future<bool> startMeasurement(HealthMetric metric) async {
    if (_activeMeasurementMetric != null ||
        deviceState == DeviceConnectionState.measuring) {
      measurementErrorMessage = '另一项手表测量尚未结束，请稍后重试';
      errorMessage = measurementErrorMessage;
      notifyListeners();
      return false;
    }
    _measurementTimeout?.cancel();
    _activeMeasurementMetric = null;
    measurementErrorMessage = null;
    measurementProgress = 0;
    measurementWearConfirmed = true;
    measurementSamples = const [];
    measurementSampleFrequency = 250;
    errorMessage = null;
    if (connectedDevice == null) {
      errorMessage = '请先连接手表';
      notifyListeners();
      return false;
    }
    if (!(capabilities?.supportsManualMeasurement(metric) ?? false)) {
      errorMessage = '当前设备不支持${metric.label}测量';
      notifyListeners();
      return false;
    }
    if (isDeviceSyncing) {
      measurementErrorMessage = '手表数据正在同步，请稍后再测量';
      errorMessage = measurementErrorMessage;
      notifyListeners();
      return false;
    }
    try {
      _activeMeasurementMetric = metric;
      deviceMachine.transition(DeviceConnectionState.measuring);
      await _wearable.startMeasurement(metric);
      if (_activeMeasurementMetric != metric ||
          measurementErrorMessage != null) {
        return false;
      }
      _measurementTimeout = Timer(
        _measurementTimeoutFor(metric),
        () => unawaited(_handleMeasurementTimeout(metric)),
      );
      notifyListeners();
      return true;
    } on WearableSdkNotConfigured catch (_) {
      _activeMeasurementMetric = null;
      measurementErrorMessage = '此功能暂时无法使用，请稍后再试';
      errorMessage = measurementErrorMessage;
      if (deviceState == DeviceConnectionState.measuring) {
        deviceMachine.transition(DeviceConnectionState.ready);
      }
    } on PlatformException catch (error) {
      _activeMeasurementMetric = null;
      measurementErrorMessage = _wearableErrorMessage(
        error,
        fallback: '${metric.label}测量失败',
      );
      errorMessage = measurementErrorMessage;
      if (deviceState == DeviceConnectionState.measuring) {
        deviceMachine.transition(DeviceConnectionState.ready);
      }
    } catch (_) {
      _activeMeasurementMetric = null;
      measurementErrorMessage = '${metric.label}测量失败，请稍后重试';
      errorMessage = measurementErrorMessage;
      if (deviceState == DeviceConnectionState.measuring) {
        deviceMachine.transition(DeviceConnectionState.ready);
      }
    }
    notifyListeners();
    return false;
  }

  Future<void> stopMeasurement(HealthMetric metric) async {
    _measurementTimeout?.cancel();
    _measurementTimeout = null;
    _activeMeasurementMetric = null;
    measurementProgress = 0;
    measurementWearConfirmed = true;
    measurementSamples = const [];
    measurementSampleFrequency = 250;
    try {
      await _wearable
          .stopMeasurement(metric)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      errorMessage = '停止测量失败';
    } finally {
      if (deviceState == DeviceConnectionState.measuring) {
        deviceMachine.transition(DeviceConnectionState.ready);
      }
    }
    notifyListeners();
  }

  Future<List<HealthRecord>> loadHealthRecords({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) async => (await _healthStore.range(
    metric: metric,
    start: start,
    end: end,
  )).where(hasSaneWearableTransportValues).toList();

  void setUnits({String? distance, String? temperature}) {
    if (distance != null) distanceUnit = distance;
    if (temperature != null) temperatureUnit = temperature;
    notifyListeners();
  }

  Future<void> _handleMeasurementTimeout(HealthMetric metric) async {
    if (_activeMeasurementMetric != metric || _disposed) return;
    _activeMeasurementMetric = null;
    _measurementTimeout = null;
    measurementErrorMessage = '长时间未检测到有效结果，请确认手表已贴合手腕后重新测量';
    errorMessage = measurementErrorMessage;
    if (deviceState == DeviceConnectionState.measuring) {
      deviceMachine.transition(DeviceConnectionState.ready);
    }
    notifyListeners();
    try {
      await _wearable.stopMeasurement(metric);
    } catch (_) {
      // The timeout result is already actionable; a stop acknowledgement is
      // best-effort and must not replace the wear guidance.
    }
  }

  Duration _measurementTimeoutFor(HealthMetric metric) => switch (metric) {
    HealthMetric.hrv => const Duration(seconds: 180),
    HealthMetric.ecg => const Duration(seconds: 120),
    HealthMetric.bloodPressure => const Duration(seconds: 150),
    HealthMetric.bodyComposition ||
    HealthMetric.bloodComposition => const Duration(seconds: 90),
    _ => const Duration(seconds: 75),
  };

  Future<bool> saveHealthWarningSettings(HealthWarningSettings settings) async {
    if (settings.heartRateUpper < 20 || settings.heartRateUpper > 300) {
      errorMessage = '心率报警值需设置在 20–300 bpm';
      notifyListeners();
      return false;
    }
    if (settings.systolicUpper < 60 || settings.systolicUpper > 300) {
      errorMessage = '收缩压报警值需设置在 60–300 mmHg';
      notifyListeners();
      return false;
    }
    if (settings.diastolicUpper < 20 || settings.diastolicUpper > 200) {
      errorMessage = '舒张压报警值需设置在 20–200 mmHg';
      notifyListeners();
      return false;
    }
    if (settings.temperatureUpper < 20 || settings.temperatureUpper > 45) {
      errorMessage = '体温报警值需设置在 20–45℃';
      notifyListeners();
      return false;
    }
    try {
      await _vault.writeHealthWarningSettings(settings);
      healthWarningSettings = settings;
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = '健康预警设置保存失败，请稍后重试';
      notifyListeners();
      return false;
    }
  }

  void dismissHealthWarningAlert() {
    if (activeHealthWarningAlert == null) return;
    activeHealthWarningAlert = null;
    notifyListeners();
  }

  Future<bool> startSport(SportMode mode) async {
    if (connectedDevice == null) {
      errorMessage = '请先连接手表后再开始运动';
      notifyListeners();
      return false;
    }
    errorMessage = null;
    try {
      await _wearable.startSport(mode);
      activeSport = mode;
      if (deviceState == DeviceConnectionState.ready) {
        deviceMachine.transition(DeviceConnectionState.measuring);
      }
      notifyListeners();
      return true;
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(error, fallback: '无法开始运动');
    } on WearableSdkNotConfigured catch (_) {
      errorMessage = '此功能暂时无法使用，请稍后再试';
    } catch (_) {
      errorMessage = '无法开始运动，请稍后重试';
    }
    notifyListeners();
    return false;
  }

  Future<void> stopSport() async {
    if (activeSport == null) return;
    try {
      await _wearable.stopSport();
      activeSport = null;
      if (deviceState == DeviceConnectionState.measuring) {
        deviceMachine.transition(DeviceConnectionState.ready);
      }
      await refreshSportRecords();
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(error, fallback: '结束运动失败');
    } catch (_) {
      errorMessage = '结束运动失败，请稍后重试';
    }
    notifyListeners();
  }

  Future<void> refreshSportRecords() async {
    await Future<void>.delayed(Duration.zero);
    if (_disposed) return;
    final localRecords = await _healthStore.localSportRecords();
    if (connectedDevice == null) {
      sportRecords = localRecords;
      notifyListeners();
      return;
    }
    sportRecords = localRecords;
    try {
      final records = await _wearable.readSportRecords();
      if (_disposed) return;
      final byId = <String, SportRecord>{
        for (final record in records) record.id: record,
        for (final record in localRecords) record.id: record,
      };
      sportRecords = byId.values.toList()
        ..sort(
          (a, b) => (b.startedAt ?? DateTime(1970)).compareTo(
            a.startedAt ?? DateTime(1970),
          ),
        );
    } on PlatformException catch (error) {
      if (_disposed) return;
      errorMessage = _wearableErrorMessage(error, fallback: '读取运动记录失败');
    } catch (_) {
      if (_disposed) return;
      errorMessage = '运动记录读取失败，请稍后重试';
    }
    notifyListeners();
  }

  Future<void> saveLocalSportRecord(SportRecord record) async {
    await _healthStore.saveSportRecord(record);
    await refreshSportRecords();
  }

  Future<void> refreshDeviceSettings() async {
    await Future<void>.delayed(Duration.zero);
    if (connectedDevice == null) {
      autoMeasureSettings = const {};
      heartRateWarningSupported = false;
      deviceSettingsStatus = '请先连接手表';
      notifyListeners();
      return;
    }
    deviceSettingsStatus = '正在读取手表设置';
    heartRateWarningSupported = false;
    notifyListeners();
    try {
      final settings = await _wearable.readAutoMeasureSettings();
      autoMeasureSettings = settings;
      final warning = await _wearable.readHeartRateWarning();
      heartRateWarningSupported = warning != null;
      if (warning != null && warning > 0) {
        final bounded = warning.clamp(70, 185).toInt();
        heartRateWarning = (bounded ~/ 5) * 5;
      }
      deviceSettingsStatus = settings.isEmpty && !heartRateWarningSupported
          ? '当前手表未提供可设置的健康检测项目'
          : '设置已同步';
    } on PlatformException catch (error) {
      deviceSettingsStatus = _wearableErrorMessage(error, fallback: '读取手表设置失败');
    } catch (_) {
      deviceSettingsStatus = '手表设置读取失败，请稍后重试';
    }
    notifyListeners();
  }

  Future<void> setAutoMeasureSetting(String type, bool enabled) async {
    if (connectedDevice == null) {
      errorMessage = '请先连接手表';
      notifyListeners();
      return;
    }
    try {
      await _wearable.setAutoMeasureSetting(type, enabled);
      autoMeasureSettings = {...autoMeasureSettings, type: enabled};
      deviceSettingsStatus = '设置已写入手表';
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(error, fallback: '写入手表设置失败');
    }
    notifyListeners();
  }

  Future<void> setHeartRateWarning(int value) async {
    if (connectedDevice == null) {
      errorMessage = '请先连接手表';
      notifyListeners();
      return;
    }
    try {
      await _wearable.setHeartRateWarning(value);
      heartRateWarning = value;
      deviceSettingsStatus = '心率预警已写入手表';
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(error, fallback: '心率预警设置失败');
    }
    notifyListeners();
  }

  FeatureAvailability availabilityFor(DeviceFeature feature) {
    if (connectedDevice == null) {
      return const FeatureAvailability(FeatureAvailabilityStatus.needsDevice);
    }
    final currentCapabilities = capabilities;
    if (!_hasResolvedDeviceCapabilities || currentCapabilities == null) {
      return const FeatureAvailability(
        FeatureAvailabilityStatus.serviceUnavailable,
      );
    }
    if (!currentCapabilities.supportsFeature(feature)) {
      return const FeatureAvailability(
        FeatureAvailabilityStatus.unsupportedDevice,
      );
    }
    if (!currentCapabilities.integratedFeatures.contains(feature)) {
      return const FeatureAvailability(
        FeatureAvailabilityStatus.serviceUnavailable,
      );
    }
    return const FeatureAvailability(FeatureAvailabilityStatus.ready);
  }

  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    final availability = availabilityFor(feature);
    if (!availability.isReady) {
      errorMessage = availability.message;
      notifyListeners();
      return const {};
    }
    _setDeviceFeatureBusy(feature, true);
    try {
      final value = await _wearable.readDeviceFeature(feature);
      deviceFeatureData = {...deviceFeatureData, feature: value};
      return value;
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(
        error,
        fallback: '${feature.label}暂时无法读取',
      );
      return const {};
    } catch (_) {
      errorMessage = '${feature.label}暂时无法读取，请稍后重试';
      return const {};
    } finally {
      _setDeviceFeatureBusy(feature, false);
    }
  }

  Future<Map<String, Object?>> readWatchFaceProfile() async {
    if (connectedDevice == null) return const {};
    final bridge = _wearable;
    if (bridge is! WearableWatchFaceProfileBridge) return const {};
    try {
      return await (bridge as WearableWatchFaceProfileBridge)
          .getWatchFaceProfile();
    } catch (_) {
      // The market has a device-family fallback, so a transient profile read
      // must not block the rest of the device page or show a global error.
      return const {};
    }
  }

  Future<bool> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    final availability = availabilityFor(feature);
    if (!availability.isReady) {
      errorMessage = availability.message;
      notifyListeners();
      return false;
    }
    _setDeviceFeatureBusy(feature, true);
    try {
      await _wearable.writeDeviceFeature(feature, values);
      deviceFeatureData = {
        ...deviceFeatureData,
        feature: {...?deviceFeatureData[feature], ...values},
      };
      errorMessage = null;
      return true;
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(
        error,
        fallback: '${feature.label}保存失败',
      );
      return false;
    } catch (_) {
      errorMessage = '${feature.label}保存失败，请稍后重试';
      return false;
    } finally {
      _setDeviceFeatureBusy(feature, false);
    }
  }

  Future<bool> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {
    final availability = availabilityFor(feature);
    if (!availability.isReady) {
      errorMessage = availability.message;
      notifyListeners();
      return false;
    }
    _setDeviceFeatureBusy(feature, true);
    try {
      await _wearable.triggerDeviceAction(feature, enabled: enabled);
      errorMessage = null;
      return true;
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(
        error,
        fallback: '${feature.label}暂时无法使用',
      );
      return false;
    } catch (_) {
      errorMessage = '${feature.label}暂时无法使用，请稍后重试';
      return false;
    } finally {
      _setDeviceFeatureBusy(feature, false);
    }
  }

  void _setDeviceFeatureBusy(DeviceFeature feature, bool busy) {
    final next = {...deviceFeatureBusy};
    if (busy) {
      next.add(feature);
    } else {
      next.remove(feature);
    }
    deviceFeatureBusy = next;
    notifyListeners();
  }

  Future<void> synchronizeCloud() async {
    if (_syncing) return;
    if (session == null) {
      cloudSyncStatus = '未登录，数据仅保存在本机';
      notifyListeners();
      return;
    }
    _syncing = true;
    try {
      final result = await _syncService.synchronizeNow();
      cloudSyncStatus =
          result.message ?? '已上传 ${result.uploaded} 条，拒绝 ${result.rejected} 条';
    } on ApiException catch (error) {
      cloudSyncStatus = _apiErrorMessage(error, fallback: '数据上传失败，请稍后重试');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> refreshCare() async {
    if (session == null) {
      careMembers = const [];
      return;
    }
    try {
      careMembers = _careMembersWithoutCurrentAccount(
        await _api.getCareMembers(),
      );
      careStatus = '已加载';
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '关爱数据暂时无法读取');
      careStatus = error is FeatureNotConfiguredException ? '服务暂不可用' : '加载失败';
    }
    notifyListeners();
  }

  Future<void> refreshCareInvitations() async {
    if (session == null) {
      careInvitations = const [];
      careInvitationStatus = '请先登录';
      notifyListeners();
      return;
    }
    final careApi = _api is SaydianCareApi ? _api as SaydianCareApi : null;
    if (careApi == null) {
      careInvitationStatus = '服务暂不可用';
      notifyListeners();
      return;
    }
    try {
      careInvitations = await careApi.getCareInvitations();
      careInvitationStatus = careInvitations.isEmpty ? '暂无待处理' : '已加载';
    } on ApiException catch (error) {
      careInvitationStatus = _apiErrorMessage(error, fallback: '关爱邀请暂时无法读取');
    }
    notifyListeners();
  }

  Future<bool> respondCareInvitation({
    required int id,
    required bool accepted,
  }) => _guard(() async {
    final careApi = _api is SaydianCareApi ? _api as SaydianCareApi : null;
    if (careApi == null) {
      throw const FeatureNotConfiguredException('远程关爱暂时无法使用，请稍后再试');
    }
    await careApi.respondCareInvitation(id: id, accepted: accepted);
    await refreshCareInvitations();
    await refreshCare();
  });

  Future<Set<String>> loadCareShareSettings({
    required int memberId,
    int type = 0,
  }) async {
    final careApi = _api is SaydianCareApi ? _api as SaydianCareApi : null;
    if (careApi == null) {
      throw const FeatureNotConfiguredException('共享设置暂时无法使用，请稍后再试');
    }
    return careApi.getCareShareSettings(type: type, memberId: memberId);
  }

  Future<bool> saveCareShareSettings({
    required int memberId,
    required Set<String> settings,
    int type = 0,
  }) => _guard(() async {
    final careApi = _api is SaydianCareApi ? _api as SaydianCareApi : null;
    if (careApi == null) {
      throw const FeatureNotConfiguredException('共享设置暂时无法使用，请稍后再试');
    }
    await careApi.saveCareShareSettings(
      type: type,
      memberId: memberId,
      settings: settings,
    );
  });

  Future<bool> addCare(String mobile) => _guard(() async {
    final normalized = mobile.trim();
    final ownMobile = '${memberProfile['mobile'] ?? ''}'.trim();
    if (ownMobile.isNotEmpty && normalized == ownMobile) {
      throw const ApiException('不能添加当前登录账号作为关爱成员');
    }
    await _api.addCare(normalized);
    careMembers = _careMembersWithoutCurrentAccount(
      await _api.getCareMembers(),
    );
  });

  List<Map<String, Object?>> _careMembersWithoutCurrentAccount(
    Iterable<Map<String, Object?>> members,
  ) {
    final ownMemberId = session?.memberId.trim() ?? '';
    return members
        .where((item) {
          final nested = item['member'];
          final memberId = nested is Map ? '${nested['id'] ?? ''}'.trim() : '';
          return ownMemberId.isEmpty || memberId != ownMemberId;
        })
        .toList(growable: false);
  }

  Future<void> refreshMemberProfile() async {
    if (session == null) {
      memberProfile = const {};
      notifyListeners();
      return;
    }
    try {
      memberProfile = await _api.getMemberProfile();
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '个人资料暂时无法读取');
    }
    notifyListeners();
  }

  Future<bool> saveMemberProfile({
    required String nickname,
    required int gender,
    required String birthday,
    required double height,
    required double weight,
    String? avatarFilePath,
  }) => _guard(() async {
    if (session == null) throw const ApiException('请先登录后编辑个人资料');
    var headPortrait = memberProfile['head_portrait']?.toString();
    final normalizedAvatarPath = avatarFilePath?.trim() ?? '';
    if (normalizedAvatarPath.isNotEmpty) {
      if (_api is! SaydianFileApi) {
        throw const FeatureNotConfiguredException('头像上传暂时无法使用，请稍后再试');
      }
      headPortrait = await (_api as SaydianFileApi).uploadImage(
        normalizedAvatarPath,
      );
    }
    await _api.saveMemberProfile(
      nickname: nickname,
      gender: gender,
      birthday: birthday,
      height: height,
      weight: weight,
      headPortrait: headPortrait,
    );
    await refreshMemberProfile();
  });

  Future<String?> uploadProfileImage(String filePath) async {
    if (session == null) {
      errorMessage = '请先登录后上传头像';
      notifyListeners();
      return null;
    }
    final uploadApi = _api is SaydianProfileUploadApi
        ? _api as SaydianProfileUploadApi
        : null;
    if (uploadApi == null) {
      errorMessage = '头像上传接口暂未配置';
      notifyListeners();
      return null;
    }
    try {
      errorMessage = null;
      final url = await uploadApi.uploadProfileImage(filePath);
      return url;
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '头像上传失败，请稍后重试');
      notifyListeners();
      return null;
    }
  }

  Future<void> refreshActivityGoals() async {
    if (session == null) return;
    try {
      final goals = await _api.getActivityGoals();
      stepGoal = num.tryParse('${goals['steps'] ?? ''}')?.toInt() ?? stepGoal;
      distanceGoal =
          num.tryParse('${goals['juli'] ?? ''}')?.toDouble() ?? distanceGoal;
      calorieGoal =
          num.tryParse('${goals['reliang'] ?? ''}')?.toInt() ?? calorieGoal;
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '目标暂时无法读取');
    }
    notifyListeners();
  }

  Future<bool> saveActivityGoals({
    required int steps,
    required double distance,
    required int calories,
  }) => _guard(() async {
    if (session == null) throw const ApiException('请先登录后保存目标');
    await _api.saveActivityGoals(
      steps: steps,
      distance: distance,
      calories: calories,
    );
    stepGoal = steps;
    distanceGoal = distance;
    calorieGoal = calories;
  });

  Future<void> refreshAiArticles() async {
    aiStatus = '正在加载';
    notifyListeners();
    try {
      aiArticles = await _api.getArticles();
      aiStatus = aiArticles.isEmpty ? '暂无百科内容' : '已加载';
    } on ApiException catch (error) {
      aiStatus = _apiErrorMessage(error, fallback: '百科暂时无法加载');
    }
    notifyListeners();
  }

  Future<List<Map<String, Object?>>> loadArticleCategories({
    int parentId = 3,
  }) async {
    articleCategoryLoadError = null;
    final api = _api;
    final articleApi = api is SaydianArticleApi
        ? api as SaydianArticleApi
        : null;
    if (articleApi == null) {
      articleCategoryLoadError = '健康百科分类暂时无法加载';
      errorMessage = articleCategoryLoadError;
      notifyListeners();
      return const [];
    }
    try {
      return await articleApi.getArticleCategories(parentId: parentId);
    } on ApiException catch (error) {
      articleCategoryLoadError = _apiErrorMessage(
        error,
        fallback: '健康百科分类暂时无法加载',
      );
      errorMessage = articleCategoryLoadError;
      notifyListeners();
      return const [];
    }
  }

  Future<List<Map<String, Object?>>> loadArticlesByCategory({
    int? categoryId,
    int page = 1,
  }) async {
    articleListLoadError = null;
    final api = _api;
    final articleApi = api is SaydianArticleApi
        ? api as SaydianArticleApi
        : null;
    if (articleApi == null) {
      articleListLoadError = '健康百科文章暂时无法加载';
      errorMessage = articleListLoadError;
      notifyListeners();
      return const [];
    }
    try {
      return await articleApi.getArticlesByCategory(
        categoryId: categoryId,
        page: page,
      );
    } on ApiException catch (error) {
      articleListLoadError = _apiErrorMessage(error, fallback: '健康百科文章暂时无法加载');
      errorMessage = articleListLoadError;
      notifyListeners();
      return const [];
    }
  }

  Future<Map<String, Object?>> loadArticle(int id) async {
    articleDetailLoadError = null;
    try {
      return await _api.getArticle(id);
    } on ApiException catch (error) {
      articleDetailLoadError = _apiErrorMessage(error, fallback: '文章暂时无法加载');
      errorMessage = articleDetailLoadError;
      notifyListeners();
      return const {};
    }
  }

  Future<Map<String, Object?>> loadSingleArticle(int id) async {
    articleDetailLoadError = null;
    try {
      return await _api.getSingleArticle(id);
    } on ApiException catch (error) {
      articleDetailLoadError = _apiErrorMessage(error, fallback: '内容暂时无法加载');
      errorMessage = articleDetailLoadError;
      notifyListeners();
      return const {};
    }
  }

  Future<void> refreshNotifications() => refreshNotificationHistory();

  Future<void> refreshNotificationHistory({bool allPages = false}) async {
    await Future<void>.delayed(Duration.zero);
    if (session == null) {
      notifications = const [];
      notificationStatus = '请先登录';
      notifyListeners();
      return;
    }
    notificationStatus = '正在加载';
    notifyListeners();
    try {
      if (!allPages) {
        notifications = await _api.getNotifications();
      } else {
        final merged = <Map<String, Object?>>[];
        final seen = <String>{};
        for (var page = 1; page <= 100; page++) {
          final values = await _api.getNotifications(page: page);
          if (values.isEmpty) break;
          var added = 0;
          for (final value in values) {
            final identity = [
              value['id'],
              value['type'],
              value['title'],
              value['created_at'],
              value['content'],
            ].join('|');
            if (seen.add(identity)) {
              merged.add(value);
              added++;
            }
          }
          if (added == 0) break;
        }
        notifications = merged;
      }
      notificationStatus = notifications.isEmpty ? '暂无消息' : '已加载';
    } on ApiException catch (error) {
      notificationStatus = _apiErrorMessage(error, fallback: '消息暂时无法加载');
    }
    notifyListeners();
  }

  Future<Map<String, Object?>> loadNotification(int id) async {
    try {
      return await _api.getNotification(id);
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '消息暂时无法加载');
      notifyListeners();
      return const {};
    }
  }

  Future<Map<String, Object?>> loadCareMemberPreview(
    int id, {
    DateTime? day,
  }) async {
    try {
      final selected = day ?? DateTime.now();
      return await _api.getCareMemberPreview(
        id: id,
        day: selected.toIso8601String().substring(0, 10),
      );
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '对方数据暂时无法读取');
      notifyListeners();
      return const {};
    }
  }

  Future<void> refreshAiMessages({required int app}) async {
    await Future<void>.delayed(Duration.zero);
    if (session == null) {
      aiMessages = const [];
      errorMessage = '请先登录后使用 AI 管家';
      notifyListeners();
      return;
    }
    errorMessage = null;
    try {
      final messages = await _api.getAiMessages(app: app);
      if (messages.isNotEmpty) {
        final sessionId = '${messages.first['session_id'] ?? ''}';
        if (sessionId.isNotEmpty) _aiSessionIds[app] = sessionId;
      } else {
        _aiSessionIds.remove(app);
      }
      aiMessages = messages.reversed
          .map(
            (message) => <String, Object?>{
              ...message,
              'my': switch (message['my']) {
                final num value => value.toInt(),
                final String value => int.tryParse(value) ?? 0,
                true => 1,
                _ => 0,
              },
            },
          )
          .toList(growable: false);
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '暂时无法开始对话');
    }
    notifyListeners();
  }

  Future<bool> sendAiMessage({
    required int app,
    required String message,
  }) async {
    final normalized = message.trim();
    if (normalized.isEmpty) return false;
    if (session == null) {
      errorMessage = '请先登录后使用 AI 管家';
      notifyListeners();
      return false;
    }
    aiMessages = [
      ...aiMessages,
      <String, Object?>{'message': normalized, 'my': 1},
    ];
    isBusy = true;
    notifyListeners();
    try {
      final reply = await _api.sendAiMessage(
        app: app,
        message: normalized,
        sessionId: _aiSessionIds[app],
      );
      aiMessages = [...aiMessages, reply];
      final sessionValue = reply['session_id']?.toString();
      if (sessionValue?.isNotEmpty ?? false) _aiSessionIds[app] = sessionValue!;
      return true;
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '消息发送失败，请稍后重试');
      aiMessages = [
        ...aiMessages.take(aiMessages.length - 1),
        <String, Object?>{...aiMessages.last, 'send_failed': true},
      ];
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> loadOrders(int? status) async {
    await Future<void>.delayed(Duration.zero);
    if (session == null) {
      orders = const [];
      orderStatus = '请先登录';
      notifyListeners();
      return;
    }
    orderStatus = '正在加载';
    notifyListeners();
    try {
      orders = await _api.getOrders(status: status);
      orderStatus = orders.isEmpty ? '暂无订单' : '已加载';
    } on ApiException catch (error) {
      orderStatus = _apiErrorMessage(error, fallback: '订单暂时无法加载');
    }
    notifyListeners();
  }

  Future<Map<String, Object?>> loadOrderDetail(int id) async {
    try {
      return await _api.getOrderDetail(id);
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '订单详情暂时无法加载');
      notifyListeners();
      return const {};
    }
  }

  Future<void> loadAddresses() async {
    await Future<void>.delayed(Duration.zero);
    if (session == null) {
      addresses = const [];
      errorMessage = '请先登录后查看收货地址';
      notifyListeners();
      return;
    }
    try {
      addresses = await _api.getAddresses();
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '收货地址暂时无法加载');
    }
    notifyListeners();
  }

  SaydianShopApi get _requiredShopApi {
    final api = _api;
    if (api is SaydianShopApi) return api as SaydianShopApi;
    throw const FeatureNotConfiguredException('商城暂时无法使用，请稍后再试');
  }

  Future<Map<String, Object?>> loadShopHome() =>
      _shopMapRequest('商城首页', () => _requiredShopApi.getShopHome());

  Future<Map<String, Object?>> loadShopProduct(int id) =>
      _shopMapRequest('商品详情', () => _requiredShopApi.getShopProduct(id));

  Future<Map<String, Object?>> previewShopOrder({
    required List<Map<String, int>> items,
  }) => _shopMapRequest(
    '确认订单',
    () => _requiredShopApi.previewShopOrder(items: items),
  );

  Future<Map<String, Object?>> createShopOrder({
    required List<Map<String, int>> items,
    required int addressId,
    required String buyerMessage,
    required num point,
  }) async {
    if (session == null) {
      errorMessage = '请先登录后提交订单';
      notifyListeners();
      return const {};
    }
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final order = await _requiredShopApi.createShopOrder(
        items: items,
        addressId: addressId,
        buyerMessage: buyerMessage,
        point: point,
      );
      unawaited(loadOrders(null));
      return order;
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '订单提交失败，请稍后重试');
      return const {};
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> confirmOrderReceipt(int orderId) => _guard(() async {
    if (session == null) throw const ApiException('请先登录后确认收货');
    await _requiredShopApi.confirmOrderReceipt(orderId);
    await loadOrders(2);
  });

  Future<bool> applyOrderRefund({
    required int orderProductId,
    required int refundType,
    required num amount,
    required String reason,
  }) => _guard(() async {
    if (session == null) throw const ApiException('请先登录后申请售后');
    if (reason.trim().length < 4) throw const ApiException('请填写至少 4 个字的售后原因');
    await _requiredShopApi.applyOrderRefund(
      orderProductId: orderProductId,
      refundType: refundType,
      amount: amount,
      reason: reason,
    );
    unawaited(loadOrders(null));
  });

  Future<void> addToShopCart({
    required Map<String, Object?> product,
    required Map<String, Object?> sku,
    required int quantity,
  }) async {
    final skuId = _cartInt(sku['id']);
    final productId = _cartInt(product['id']);
    if (skuId == null || productId == null || quantity <= 0) {
      throw const ApiException('商品规格信息不完整');
    }
    final next = shopCart
        .map((item) => Map<String, Object?>.from(item))
        .toList();
    final index = next.indexWhere((item) => _cartInt(item['sku_id']) == skuId);
    if (index >= 0) {
      final stock = _cartInt(next[index]['stock']) ?? 999;
      final current = _cartInt(next[index]['quantity']) ?? 0;
      next[index]['quantity'] = (current + quantity).clamp(1, stock);
    } else {
      next.add({
        'product_id': productId,
        'sku_id': skuId,
        'product_name': '${product['name'] ?? '商品'}',
        'sku_name': '${sku['name'] ?? '默认规格'}',
        'picture': '${sku['picture'] ?? product['picture'] ?? ''}',
        'price': sku['price'] ?? product['price'] ?? 0,
        'stock': _cartInt(sku['stock']) ?? 0,
        'quantity': quantity,
      });
    }
    shopCart = next;
    await _vault.writeShopCart(shopCart);
    notifyListeners();
  }

  Future<void> updateShopCartQuantity(int skuId, int quantity) async {
    final next = shopCart
        .map((item) => Map<String, Object?>.from(item))
        .toList();
    final index = next.indexWhere((item) => _cartInt(item['sku_id']) == skuId);
    if (index < 0) return;
    if (quantity <= 0) {
      next.removeAt(index);
    } else {
      final stock = _cartInt(next[index]['stock']) ?? quantity;
      next[index]['quantity'] = quantity.clamp(1, stock < 1 ? 1 : stock);
    }
    shopCart = next;
    await _vault.writeShopCart(shopCart);
    notifyListeners();
  }

  Future<void> clearShopCart() async {
    shopCart = const [];
    await _vault.writeShopCart(shopCart);
    notifyListeners();
  }

  Future<void> removeShopCartItems(Iterable<int> skuIds) async {
    final selected = skuIds.toSet();
    if (selected.isEmpty) return;
    shopCart = shopCart
        .where((item) => !selected.contains(_cartInt(item['sku_id'])))
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
    await _vault.writeShopCart(shopCart);
    notifyListeners();
  }

  Future<Map<String, Object?>> loadShopAddress(int id) =>
      _shopMapRequest('收货地址', () => _requiredShopApi.getAddress(id));

  Future<bool> saveShopAddress({
    int? id,
    required String realname,
    required String mobile,
    required String addressDetails,
    required bool isDefault,
    required String region,
    required int provinceId,
    required int cityId,
    required int areaId,
  }) async {
    if (session == null) {
      errorMessage = '请先登录后保存收货地址';
      notifyListeners();
      return false;
    }
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _requiredShopApi.saveAddress(
        id: id,
        realname: realname,
        mobile: mobile,
        addressDetails: addressDetails,
        isDefault: isDefault,
        region: region,
        provinceId: provinceId,
        cityId: cityId,
        areaId: areaId,
      );
      await loadAddresses();
      return true;
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '收货地址保存失败');
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, Object?>>> loadOrderExpress(int orderId) async {
    try {
      return await _requiredShopApi.getOrderExpress(orderId);
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '物流信息暂时无法加载');
      notifyListeners();
      return const [];
    }
  }

  Future<Map<String, Object?>> _shopMapRequest(
    String label,
    Future<Map<String, Object?>> Function() request,
  ) async {
    await Future<void>.delayed(Duration.zero);
    try {
      return await request();
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '$label暂时无法加载');
      notifyListeners();
      return const {};
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  String _apiErrorMessage(ApiException error, {required String fallback}) {
    if (error is FeatureNotConfiguredException) {
      return '此功能暂时无法使用，请稍后再试';
    }
    final message = error.message.trim();
    final normalized = message.toLowerCase();
    if (normalized.contains('network') ||
        normalized.contains('socket') ||
        normalized.contains('timeout') ||
        message.contains('网络')) {
      return '网络不可用，请检查后重试';
    }
    if (message.contains('接口未配置') ||
        normalized.contains('token') ||
        normalized.contains('http') ||
        normalized.contains('api')) {
      return fallback;
    }
    return message.isEmpty ? fallback : message;
  }

  bool _isMeasurementErrorCode(String code) {
    const measurementErrors = {
      'HEART_NOT_WORN',
      'HEART_DEVICE_BUSY',
      'HEART_LOW_BATTERY',
      'BLOOD_PRESSURE_FAILED',
      'BLOOD_PRESSURE_INVALID',
      'BLOOD_PRESSURE_NOT_WORN',
      'BLOOD_PRESSURE_WEAR_CHECK_FAILED',
      'BLOOD_PRESSURE_LOW_BATTERY',
      'BLOOD_PRESSURE_DEVICE_BUSY',
      'OXYGEN_UNSUPPORTED',
      'OXYGEN_NOT_WORN',
      'OXYGEN_DEVICE_BUSY',
      'TEMPERATURE_UNSUPPORTED',
      'TEMPERATURE_LOW_BATTERY',
      'TEMPERATURE_SENSOR_ERROR',
      'TEMPERATURE_DEVICE_BUSY',
      'GLUCOSE_MEASUREMENT_FAILED',
      'BODY_COMPOSITION_FAILED',
      'BODY_COMPOSITION_NOT_WORN',
      'BODY_COMPOSITION_BUSY',
      'BODY_COMPOSITION_LOW_BATTERY',
      'BLOOD_COMPONENT_FAILED',
      'BLOOD_COMPONENT_NOT_WORN',
      'BLOOD_COMPONENT_BUSY',
      'BLOOD_COMPONENT_LOW_BATTERY',
      'ECG_MEASUREMENT_FAILED',
      'ECG_NOT_WORN',
      'HRV_MEASUREMENT_FAILED',
      'HRV_NOT_WORN',
      'HRV_DEVICE_BUSY',
      'HRV_LOW_BATTERY',
      'MEASUREMENT_DEVICE_BUSY',
      'MEASUREMENT_START_FAILED',
      'MEASUREMENT_COMMAND_FAILED',
      'MEASUREMENT_STOP_FAILED',
    };
    return measurementErrors.contains(code);
  }

  String _wearableErrorMessage(
    PlatformException error, {
    required String fallback,
  }) {
    final nativeMessage = error.message?.trim();
    final mappedMessage = switch (error.code) {
      'BLUETOOTH_DISABLED' => '请先打开手机蓝牙',
      'BLE_PERMISSION_DENIED' || 'LOCATION_SERVICE_DISABLED' => '允许相关权限后使用',
      'DEVICE_NOT_FOUND' => '手表已离开搜索范围，请重新搜索',
      'NOT_CONNECTED' => '连接手表后使用',
      'UNSUPPORTED_METRIC' ||
      'MEASUREMENT_NOT_AVAILABLE' ||
      'FEATURE_UNSUPPORTED' => '当前手表不支持此功能',
      'FEATURE_UNAVAILABLE' ||
      'DEVICE_SETTINGS_NOT_CONFIGURED' ||
      'SPORT_NOT_CONFIGURED' => '请在手表上操作',
      'SDK_NOT_CONFIGURED' => '此功能暂时无法使用，请稍后再试',
      'CONNECT_FAILED' || 'CONNECTION_DROPPED' => '连接失败，请确认手表未连接其他手机后重试',
      'YUCHENG_SYNC_TIMEOUT' => '数据同步超时，可稍后重试',
      'NETWORK_ERROR' || 'NETWORK_UNAVAILABLE' => '网络不可用，请检查后重试',
      _ => null,
    };
    if (mappedMessage != null) return mappedMessage;
    if (nativeMessage != null && nativeMessage.isNotEmpty) {
      return nativeMessage;
    }
    return fallback;
  }

  Future<bool> _guard(Future<void> Function() operation) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '操作失败，请稍后重试');
      return false;
    } catch (_) {
      errorMessage = '操作失败，请稍后重试';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _handleWearableEvent(WearableEvent event) {
    if (_disposed) return;
    if (event.type == 'scanDevice') {
      final device = DeviceInfo.fromMap(event.payload);
      _upsertScannedDevice(device);
    } else if (event.type == 'deviceDetails') {
      _latestDeviceDetails = DeviceInfo.fromMap(event.payload);
      final current = connectedDevice;
      if (current != null && current.id == _latestDeviceDetails?.id) {
        connectedDevice = _mergeDeviceDetails(current);
      }
    } else if (event.type == 'reconnected') {
      unawaited(_restoreReconnectedDevice(event.payload));
    } else if (event.type == 'capabilitiesUpdated') {
      if (connectedDevice != null) {
        capabilities = DeviceCapabilities.fromMap(event.payload);
        deviceCapabilityState = DeviceCapabilityState.ready;
      }
    } else if (event.type == 'syncProgress') {
      final deviceId = '${event.payload['deviceId'] ?? ''}';
      if (isDeviceSyncing && connectedDevice?.id == deviceId) {
        deviceSyncProgress =
            ((event.payload['progress'] as num?)?.toDouble() ?? 0)
                .clamp(0.0, 1.0)
                .toDouble();
        syncStatus = '正在读取手表数据 ${(deviceSyncProgress * 100).round()}%';
      }
    } else if (event.type == 'healthRecord') {
      try {
        final record = HealthRecord.fromJson(event.payload);
        if (!hasSaneWearableTransportValues(record)) return;
        unawaited(_saveWearableRecord(record));
      } catch (_) {
        errorMessage = '收到无法识别的设备数据';
      }
    } else if (event.type == 'measurementProgress') {
      final metric = HealthMetric.fromWire(
        '${event.payload['metric'] ?? _activeMeasurementMetric?.wireName ?? ''}',
      );
      if (_activeMeasurementMetric == metric) {
        measurementProgress =
            (event.payload['progress'] as num?)
                ?.toInt()
                .clamp(0, 100)
                .toInt() ??
            measurementProgress;
        measurementWearConfirmed =
            '${event.payload['deviceState'] ?? ''}' != 'UNPASS_WEAR';
        final frequency = (event.payload['frequency'] as num?)?.toInt();
        if (frequency != null && frequency >= 50 && frequency <= 1000) {
          measurementSampleFrequency = frequency;
        }
        final samples = event.payload['samples'];
        if (samples is List) {
          final combined = <num>[
            ...measurementSamples,
            ...samples.whereType<num>(),
          ];
          final windowSamples = (measurementSampleFrequency * 6).clamp(
            480,
            3000,
          );
          measurementSamples = combined.length > windowSamples
              ? combined.sublist(combined.length - windowSamples)
              : combined;
        }
      }
    } else if (event.type == 'cameraShutter') {
      cameraShutterSequence += 1;
    } else if (event.type == 'deviceFeatureProgress') {
      final feature = DeviceFeature.tryFromWire(
        '${event.payload['feature'] ?? ''}',
      );
      if (feature != null) {
        deviceFeatureData = {
          ...deviceFeatureData,
          feature: {
            ...?deviceFeatureData[feature],
            'progress': (event.payload['progress'] as num?)?.toInt() ?? 0,
          },
        };
      }
    } else if (event.type == 'disconnected') {
      // Some Veepoo devices briefly report a disconnect while replacing the
      // scan connection with the authenticated connection. The pending
      // connect future remains authoritative and will report a real failure.
      if (deviceState == DeviceConnectionState.connecting) return;
      _invalidateDeviceSync();
      connectedDevice = null;
      _latestDeviceDetails = null;
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      if (deviceState != DeviceConnectionState.disconnected) {
        try {
          deviceMachine.transition(DeviceConnectionState.disconnected);
        } on StateError {
          // Native disconnects are authoritative; the next scan resets state.
        }
      }
    } else if (event.type == 'error') {
      final errorCode = '${event.payload['code'] ?? 'WEARABLE_ERROR'}';
      final resolvedMessage = _wearableErrorMessage(
        PlatformException(
          code: errorCode,
          message: event.payload['message']?.toString(),
        ),
        fallback: '手表连接出现问题，请稍后重试',
      );
      errorMessage = resolvedMessage;
      if (_isMeasurementErrorCode(errorCode) && activeSport == null) {
        _measurementTimeout?.cancel();
        _measurementTimeout = null;
        _activeMeasurementMetric = null;
        measurementErrorMessage = resolvedMessage;
        if (deviceState == DeviceConnectionState.measuring) {
          deviceMachine.transition(DeviceConnectionState.ready);
        }
      }
    } else if (event.type == 'sportState' &&
        event.payload['value'] == 'stopped') {
      activeSport = null;
      if (deviceState == DeviceConnectionState.measuring) {
        deviceMachine.transition(DeviceConnectionState.ready);
      }
      unawaited(refreshSportRecords());
    }
    notifyListeners();
  }

  Future<void> _restoreReconnectedDevice(Map<String, Object?> payload) async {
    final device = DeviceInfo.fromMap(payload);
    if (device.id.trim().isEmpty ||
        deviceState != DeviceConnectionState.disconnected) {
      return;
    }
    _latestDeviceDetails = device;
    errorMessage = null;
    try {
      deviceMachine.transition(DeviceConnectionState.connecting);
      connectedDevice = _mergeDeviceDetails(device);
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.loading;
      deviceMachine.transition(DeviceConnectionState.authenticating);
      await refreshDeviceCapabilities(announceFailure: false);
      if (connectedDevice?.id != device.id) return;
      deviceMachine.transition(DeviceConnectionState.syncing);
      syncStatus = '设备已自动重连';
      deviceMachine.transition(DeviceConnectionState.ready);
      notifyListeners();
      unawaited(_syncInitialDeviceData(device.id));
    } on PlatformException catch (error) {
      connectedDevice = null;
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      errorMessage = _wearableErrorMessage(error, fallback: '设备重连失败');
      if (deviceState != DeviceConnectionState.error) {
        deviceMachine.transition(DeviceConnectionState.error);
      }
      notifyListeners();
    } catch (_) {
      connectedDevice = null;
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      errorMessage = '设备重连失败，请重新连接';
      if (deviceState != DeviceConnectionState.error) {
        deviceMachine.transition(DeviceConnectionState.error);
      }
      notifyListeners();
    }
  }

  void _upsertScannedDevice(DeviceInfo device) {
    if (device.id.trim().isEmpty) return;
    final byId = <String, DeviceInfo>{
      for (final existing in scannedDevices) existing.id: existing,
      device.id: device,
    };
    scannedDevices = byId.values.toList()
      ..sort(
        (left, right) => (right.rssi ?? -999).compareTo(left.rssi ?? -999),
      );
  }

  DeviceInfo _mergeDeviceDetails(DeviceInfo device) {
    final details = _latestDeviceDetails;
    if (details == null || details.id != device.id) return device;
    final firmware = details.firmwareVersion?.trim();
    return DeviceInfo(
      id: device.id,
      name: details.name.trim().isEmpty ? device.name : details.name,
      model: (details.model?.trim().isNotEmpty ?? false)
          ? details.model
          : device.model,
      serialNumber: details.serialNumber ?? device.serialNumber,
      hardwareAddress: details.hardwareAddress ?? device.hardwareAddress,
      firmwareVersion: (firmware?.isNotEmpty ?? false)
          ? firmware
          : device.firmwareVersion,
      batteryPercent: details.batteryPercent ?? device.batteryPercent,
      rssi: device.rssi ?? details.rssi,
      lastSyncAt: device.lastSyncAt ?? details.lastSyncAt,
    );
  }

  Future<void> _saveWearableRecord(HealthRecord record) async {
    if (!hasSaneWearableTransportValues(record)) return;
    final shouldStopMeasurement = _activeMeasurementMetric == record.metric;
    if (shouldStopMeasurement) {
      _measurementTimeout?.cancel();
      _measurementTimeout = null;
      _activeMeasurementMetric = null;
      measurementErrorMessage = null;
    }

    // Surface a valid device result immediately. Encrypted storage can take a
    // noticeable amount of time on a physical phone and must not leave the
    // measurement dialog looking as if the watch is still measuring.
    final byId = <String, HealthRecord>{
      for (final item in healthRecords) item.id: item,
      record.id: record,
    };
    healthRecords = byId.values.toList()
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    if (healthRecords.length > 200) {
      healthRecords = healthRecords.take(200).toList(growable: false);
    }
    _evaluateHealthWarning(record);
    if (shouldStopMeasurement &&
        deviceState == DeviceConnectionState.measuring) {
      deviceMachine.transition(DeviceConnectionState.ready);
    }
    if (!_disposed) notifyListeners();

    if (shouldStopMeasurement) {
      unawaited(
        _wearable.stopMeasurement(record.metric).catchError((_) {
          // The final record is authoritative. A delayed stop acknowledgement
          // must not turn a completed measurement into a visible failure.
        }),
      );
    }

    try {
      await _healthStore.upsert([record]);
      await _refreshHealthRecordCache();
      if (!_disposed) notifyListeners();
      unawaited(synchronizeCloud());
    } catch (_) {
      errorMessage = '测量结果已显示，但暂时无法保存到本机';
      if (!_disposed) notifyListeners();
    }
  }

  void _evaluateHealthWarning(HealthRecord record) {
    if (record.measuredAt.isBefore(
      DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    )) {
      return;
    }
    final settings = healthWarningSettings;
    String? message;
    if (record.metric == HealthMetric.heartRate && settings.heartRateEnabled) {
      final value = record.values['value'];
      if (value != null && value > settings.heartRateUpper) {
        final display = value % 1 == 0
            ? value.toInt().toString()
            : value.toStringAsFixed(1);
        message = '心率 $display bpm，超过设定值 ${settings.heartRateUpper} bpm';
      }
    } else if (record.metric == HealthMetric.bloodPressure &&
        settings.bloodPressureEnabled) {
      final systolic = record.values['systolic'];
      final diastolic = record.values['diastolic'];
      final parts = <String>[];
      if (systolic != null && systolic > settings.systolicUpper) {
        parts.add('收缩压 ${systolic.toStringAsFixed(0)}');
      }
      if (diastolic != null && diastolic > settings.diastolicUpper) {
        parts.add('舒张压 ${diastolic.toStringAsFixed(0)}');
      }
      if (parts.isNotEmpty) {
        message = '${parts.join('、')} mmHg 超过设定值';
      }
    } else if (record.metric == HealthMetric.bodyTemperature &&
        settings.temperatureEnabled) {
      final value = record.values['value'];
      if (value != null && value > settings.temperatureUpper) {
        message =
            '体温 ${value.toStringAsFixed(1)}℃，超过设定值 ${settings.temperatureUpper.toStringAsFixed(1)}℃';
      }
    }
    if (message == null) return;
    final alert = HealthWarningAlert(
      id: record.id,
      metric: record.metric,
      title: '${record.metric.label}健康预警',
      message: message,
      triggeredAt: DateTime.now(),
    );
    healthWarningAlerts = [
      alert,
      ...healthWarningAlerts.where((item) => item.id != alert.id),
    ];
    unawaited(_healthStore.saveHealthWarningAlert(alert));
    activeHealthWarningAlert = alert;
  }

  Future<void> _refreshHealthRecordCache() async {
    final storedRecent = await _healthStore.recent();
    final storedLatest = await _healthStore.latestForEachMetric();
    final invalidIds = [...storedRecent, ...storedLatest]
        .where((record) => !hasSaneWearableTransportValues(record))
        .map((record) => record.id)
        .toSet();
    if (invalidIds.isNotEmpty) await _healthStore.markInvalid(invalidIds);
    final recent = storedRecent.where(hasSaneWearableTransportValues);
    final latest = storedLatest.where(hasSaneWearableTransportValues);
    final byId = <String, HealthRecord>{
      for (final record in recent) record.id: record,
      for (final record in latest) record.id: record,
    };
    healthRecords = byId.values.toList()
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  }

  @override
  void dispose() {
    _disposed = true;
    _measurementTimeout?.cancel();
    _invalidateDeviceSync();
    unawaited(_wearableEvents?.cancel());
    unawaited(_deviceStates?.cancel());
    unawaited(_connectivity?.cancel());
    deviceMachine.dispose();
    unawaited(_healthStore.close());
    super.dispose();
  }
}

int? _cartInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}');
