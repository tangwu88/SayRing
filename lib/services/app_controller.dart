import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart' as platform_info;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../domain/device_state_machine.dart';
import '../domain/feature_models.dart';
import '../domain/health_report_models.dart';
import '../domain/health_record_validation.dart';
import '../domain/health_record_dedup.dart';
import '../domain/health_source_policy.dart';
import '../domain/models.dart';
import '../domain/global_account.dart';
import '../domain/global_care.dart';
import '../l10n/global_locale_controller.dart';
import 'api_client.dart';
import 'app_payment_bridge.dart';
import 'app_notification_service.dart';
import 'local_health_store.dart';
import 'notification_inbox.dart';
import 'notification_models.dart';
import 'notification_route_service.dart';
import 'secure_vault.dart';
import 'storekit_purchase_bridge.dart';
import 'sync_service.dart';
import 'wearable_bridge.dart';
import 'wearable_bootstrap.dart';
import 'wechat_auth_bridge.dart';
import 'user_message.dart';

enum PushDeviceRegistrationState {
  idle,
  waitingForRegistrationId,
  registering,
  registered,
  retryScheduled,
  unavailable,
  unregistering,
  unregistered,
  unregisterRetryPending,
  failed,
}

enum DeviceScanIssue { permissionsRequired, locationServiceDisabled }

const _defaultPushRegistrationRetryDelays = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(minutes: 1),
];

class AppController extends ChangeNotifier {
  AppController(
    this._vault,
    this._api,
    this._healthStore,
    this._wearable, {
    AppPaymentBridge? paymentBridge,
    StoreKitPurchaseBridge? storeKitPurchaseBridge,
    WechatAuthBridge? wechatAuthBridge,
    AppNotificationService? notificationService,
    List<Duration>? pushRegistrationRetryDelays,
    this._allowAutomaticWearableRestore = true,
  }) : _paymentBridge = paymentBridge ?? const MethodChannelAppPaymentBridge(),
       _storeKitPurchaseBridge =
           storeKitPurchaseBridge ??
           const MethodChannelStoreKitPurchaseBridge(),
       _wechatAuthBridge = wechatAuthBridge ?? MethodChannelWechatAuthBridge(),
       _notificationService =
           notificationService ?? const DisabledAppNotificationService(),
       _pushRegistrationRetryDelays = List.unmodifiable(
         pushRegistrationRetryDelays ?? _defaultPushRegistrationRetryDelays,
       ),
       _syncService = HealthSyncService(_healthStore, _api) {
    _notificationInboxRepository = StoredNotificationInboxRepository(
      _healthStore,
      ownerId: _notificationOwnerId,
    );
    _notificationInboxService = NotificationInboxService(
      _notificationInboxRepository,
    );
  }

  factory AppController.production({
    bool allowAutomaticWearableRestore = true,
  }) {
    final vault = SecureSessionVault.global();
    return AppController(
      vault,
      GlobalSaydianApiClient(
        vault,
        locale: () => GlobalLocaleController.instance.locale.toLanguageTag(),
      ),
      EncryptedHealthStore(vault, globalEdition: true),
      createProductionWearableBridge(),
      notificationService: JPushAppNotificationService(),
      allowAutomaticWearableRestore: allowAutomaticWearableRestore,
    );
  }

  final SessionVault _vault;
  final bool _allowAutomaticWearableRestore;
  final SaydianApi _api;
  bool get isGlobalEdition => _api is GlobalAccountApi;

  /// Stable API classification only; raw response bodies never reach the UI.
  ApiException? lastApiError;

  Future<List<Map<String, Object?>>> loadGlobalArticleCategories() =>
      (_api as GlobalContentApi).getGlobalArticleCategories();
  Future<List<Map<String, Object?>>> loadGlobalArticles({
    String? categoryId,
    int page = 1,
  }) => (_api as GlobalContentApi).getGlobalArticles(
    categoryId: categoryId,
    page: page,
  );
  Future<Map<String, Object?>> loadGlobalArticle(String id) =>
      (_api as GlobalContentApi).getGlobalArticle(id);

  Future<Map<String, Object?>> loadGlobalShopProducts({
    String? keyword,
    String? categoryId,
    int page = 1,
  }) => (_api as GlobalCommerceApi).getGlobalShopProducts(
    keyword: keyword,
    categoryId: categoryId,
    page: page,
  );

  Future<Map<String, Object?>> loadGlobalShopProduct(String id) =>
      (_api as GlobalCommerceApi).getGlobalShopProduct(id);

  GlobalCommerceApi get _globalCommerceApi {
    final api = _api;
    if (api is GlobalCommerceApi) return api as GlobalCommerceApi;
    throw const FeatureNotConfiguredException(
      'Shopping is not available right now.',
    );
  }

  Future<T> _globalCommerceAccountRequest<T>(
    Future<T> Function(GlobalCommerceApi api) request,
  ) async {
    final generation = _sessionGeneration;
    final owner = session;
    if (owner == null) {
      throw const ApiException('Sign in to continue.', statusCode: 401);
    }
    final result = await request(_globalCommerceApi);
    if (!_isCurrentAccountRequest(generation, owner)) {
      throw const ApiException(
        'Your account changed. Please open the shop again.',
        code: 'STALE_COMMERCE_SESSION',
      );
    }
    return result;
  }

  Future<Map<String, Object?>> loadGlobalCommerceCapabilities() =>
      _globalCommerceApi.getGlobalCommerceCapabilities();

  Future<Map<String, Object?>> loadGlobalShopCart() =>
      _globalCommerceAccountRequest((api) => api.getGlobalShopCart());

  Future<Map<String, Object?>> updateGlobalShopCartItem({
    required String skuId,
    required int quantity,
    bool selected = true,
    String mode = 'set',
  }) => _globalCommerceAccountRequest(
    (api) => api.putGlobalShopCartItem(
      skuId: skuId,
      quantity: quantity,
      selected: selected,
      mode: mode,
    ),
  );

  Future<Map<String, Object?>> removeGlobalShopCartItem(String id) =>
      _globalCommerceAccountRequest((api) => api.deleteGlobalShopCartItem(id));

  Future<List<Map<String, Object?>>> loadGlobalShopAddresses() =>
      _globalCommerceAccountRequest((api) => api.getGlobalShopAddresses());

  Future<Map<String, Object?>> loadGlobalShopAddress(String id) =>
      _globalCommerceAccountRequest((api) => api.getGlobalShopAddress(id));

  Future<Map<String, Object?>> saveGlobalShopAddress(
    Map<String, Object?> address, {
    String? id,
  }) => _globalCommerceAccountRequest(
    (api) => api.saveGlobalShopAddress(address, id: id),
  );

  Future<void> deleteGlobalShopAddress(String id) =>
      _globalCommerceAccountRequest((api) => api.deleteGlobalShopAddress(id));

  Future<Map<String, Object?>> previewGlobalShopOrder({
    required String addressId,
    required List<Map<String, Object?>> items,
    String? couponClaimId,
    int pointCents = 0,
    String buyerRemark = '',
  }) => _globalCommerceAccountRequest(
    (api) => api.previewGlobalShopOrder(
      addressId: addressId,
      items: items,
      couponClaimId: couponClaimId,
      pointCents: pointCents,
      buyerRemark: buyerRemark,
    ),
  );

  Future<Map<String, Object?>> placeGlobalShopOrder({
    required String addressId,
    required List<Map<String, Object?>> items,
    required String expectedQuote,
    required String idempotencyKey,
    String? couponClaimId,
    int pointCents = 0,
    String buyerRemark = '',
  }) => _globalCommerceAccountRequest(
    (api) => api.createGlobalShopOrder(
      addressId: addressId,
      items: items,
      expectedQuote: expectedQuote,
      idempotencyKey: idempotencyKey,
      couponClaimId: couponClaimId,
      pointCents: pointCents,
      buyerRemark: buyerRemark,
    ),
  );

  Future<List<Map<String, Object?>>> loadGlobalShopOrders({
    String? status,
    String? group,
  }) => _globalCommerceAccountRequest(
    (api) => api.getGlobalShopOrders(status: status, group: group),
  );

  Future<Map<String, Object?>> loadGlobalShopOrder(String id) =>
      _globalCommerceAccountRequest((api) => api.getGlobalShopOrder(id));

  Future<void> cancelGlobalShopOrder(String id) =>
      _globalCommerceAccountRequest((api) => api.cancelGlobalShopOrder(id));

  Future<void> confirmGlobalShopOrderReceipt(String id) =>
      _globalCommerceAccountRequest(
        (api) => api.confirmGlobalShopOrderReceipt(id),
      );

  Future<List<Map<String, Object?>>> loadGlobalShopOrderLogistics(String id) =>
      _globalCommerceAccountRequest(
        (api) => api.getGlobalShopOrderLogistics(id),
      );

  Future<Map<String, Object?>> previewGlobalShopAfterSale({
    required String orderId,
    required Map<String, Object?> input,
  }) => _globalCommerceAccountRequest(
    (api) => api.previewGlobalShopAfterSale(orderId: orderId, input: input),
  );

  Future<Map<String, Object?>> createGlobalShopAfterSale({
    required String orderId,
    required Map<String, Object?> input,
  }) => _globalCommerceAccountRequest(
    (api) => api.createGlobalShopAfterSale(orderId: orderId, input: input),
  );

  Future<Map<String, Object?>> loadGlobalShopEvidenceCapabilities() =>
      _globalCommerceAccountRequest(
        (api) => api.getGlobalShopEvidenceCapabilities(),
      );

  Future<Map<String, Object?>> uploadGlobalShopEvidence(
    String filePath, {
    void Function(double progress)? onProgress,
  }) => _globalCommerceAccountRequest(
    (api) => api.uploadGlobalShopEvidence(filePath, onProgress: onProgress),
  );

  Future<Uint8List> loadGlobalShopEvidence(String id) =>
      _globalCommerceAccountRequest((api) => api.loadGlobalShopEvidence(id));

  String _globalCommerceDraftOwner(Session value) =>
      value.accountKey.trim().isNotEmpty
      ? value.accountKey.trim()
      : value.memberId.trim();

  Future<Map<String, Object?>?> readGlobalShopDraft(String key) async {
    final generation = _sessionGeneration;
    final owner = session;
    if (owner == null) return null;
    final value = await _vault.readGlobalCommerceDraft(
      _globalCommerceDraftOwner(owner),
      key,
    );
    if (!_isCurrentAccountRequest(generation, owner)) {
      throw const ApiException(
        'Your account changed. Please open the shop again.',
        code: 'STALE_COMMERCE_SESSION',
      );
    }
    return value;
  }

  Future<void> writeGlobalShopDraft(
    String key,
    Map<String, Object?> value,
  ) async {
    final generation = _sessionGeneration;
    final owner = session;
    if (owner == null) {
      throw const ApiException('Sign in to continue.', statusCode: 401);
    }
    await _vault.writeGlobalCommerceDraft(
      _globalCommerceDraftOwner(owner),
      key,
      value,
    );
    if (!_isCurrentAccountRequest(generation, owner)) {
      throw const ApiException(
        'Your account changed. Please open the shop again.',
        code: 'STALE_COMMERCE_SESSION',
      );
    }
  }

  Future<void> clearGlobalShopDraft(String key) async {
    final generation = _sessionGeneration;
    final owner = session;
    if (owner == null) return;
    await _vault.clearGlobalCommerceDraft(
      _globalCommerceDraftOwner(owner),
      key,
    );
    if (!_isCurrentAccountRequest(generation, owner)) {
      throw const ApiException(
        'Your account changed. Please open the shop again.',
        code: 'STALE_COMMERCE_SESSION',
      );
    }
  }

  Future<Map<String, Object?>> submitGlobalShopReturnLogistics({
    required String orderId,
    required String saleId,
    required Map<String, Object?> input,
  }) => _globalCommerceAccountRequest(
    (api) => api.submitGlobalShopReturnLogistics(
      orderId: orderId,
      saleId: saleId,
      input: input,
    ),
  );

  Future<List<Map<String, Object?>>> loadGlobalShopFavorites() =>
      _globalCommerceAccountRequest((api) => api.getGlobalShopFavorites());

  Future<void> setGlobalShopFavorite(String productId, bool enabled) =>
      _globalCommerceAccountRequest(
        (api) => api.setGlobalShopFavorite(productId, enabled),
      );

  Future<List<Map<String, Object?>>> loadGlobalShopCoupons() =>
      _globalCommerceAccountRequest((api) => api.getGlobalShopCoupons());

  Future<Map<String, Object?>> loadGlobalShopAvailableCoupons({int page = 1}) =>
      _globalCommerceAccountRequest(
        (api) => api.getGlobalShopAvailableCoupons(page: page),
      );

  Future<Map<String, Object?>> claimGlobalShopCoupon(String id) =>
      _globalCommerceAccountRequest((api) => api.claimGlobalShopCoupon(id));

  Future<Map<String, Object?>> claimGlobalShopCouponCode(String code) =>
      _globalCommerceAccountRequest(
        (api) => api.claimGlobalShopCouponCode(code),
      );

  Future<Map<String, Object?>> loadGlobalShopPoints({int page = 1}) =>
      _globalCommerceAccountRequest(
        (api) => api.getGlobalShopPoints(page: page),
      );

  Future<Map<String, Object?>> submitGlobalShopReview({
    required String orderItemId,
    required int rating,
    required String content,
  }) => _globalCommerceAccountRequest(
    (api) => api.createGlobalShopReview(
      orderItemId: orderItemId,
      rating: rating,
      content: content,
    ),
  );

  Future<List<GlobalCareRelationship>> globalCareRelationships() =>
      (_api as GlobalCareApi).globalCareRelationships();
  Future<void> globalInviteCare(String identifier) =>
      (_api as GlobalCareApi).globalInviteCare(identifier);
  Future<void> globalRespondCare(String id, bool accepted) =>
      (_api as GlobalCareApi).globalRespondCare(id, accepted);
  Future<void> globalShareCare(String id, Set<String> metrics) =>
      (_api as GlobalCareApi).globalShareCare(id, metrics);
  Future<void> globalRevokeCare(String id) =>
      (_api as GlobalCareApi).globalRevokeCare(id);
  Future<List<Map<String, Object?>>> globalCareRecords(
    String id,
    String metric,
    DateTime day,
  ) => (_api as GlobalCareApi).globalCareRecords(id, metric, day);

  Future<GlobalAuthCapabilities> globalAuthCapabilities() =>
      (_api as GlobalAccountApi).getAuthCapabilities();

  Future<Map<String, Object?>> globalLegalDocument(String path) =>
      (_api as GlobalAccountApi).getGlobalLegalDocument(path);

  Future<VerificationChallenge> requestGlobalVerification({
    required GlobalAccountIdentity identity,
    required String purpose,
    required String locale,
  }) => (_api as GlobalAccountApi).requestVerification(
    identity: identity,
    purpose: purpose,
    locale: locale,
  );

  Future<bool> registerGlobalWithoutVerification({
    required GlobalAccountIdentity identity,
    required String password,
    required String locale,
    required bool privacyConsentGranted,
    String? consentVersion,
  }) async {
    if (isBusy ||
        !privacyConsentGranted ||
        consentVersion == null ||
        consentVersion.isEmpty) {
      return false;
    }
    return _guard(() async {
      _accountTransitioning = true;
      try {
        await _drainCloudSync();
        session = await (_api as GlobalAccountApi).registerWithoutVerification(
          identity: identity,
          password: password,
          locale: locale,
          consentVersion: consentVersion,
        );
        await _prepareAuthenticatedNotificationSession(
          privacyConsentGranted: privacyConsentGranted,
        );
        isPreviewMode = false;
        await refreshMemberProfile();
        await refreshActivityGoals();
        await refreshCare();
        await refreshCareInvitations();
        await _refreshRemoteNotificationUnreadCount();
        _careInvitationPollBackoffIndex = 0;
        _scheduleCareInvitationPoll(const Duration(seconds: 30));
      } finally {
        await _finishAccountTransition();
      }
    });
  }

  Future<bool> completeGlobalVerification({
    required VerificationChallenge challenge,
    required String code,
    required String password,
    required bool resetPassword,
    required String locale,
    required bool privacyConsentGranted,
    String? consentVersion,
  }) async {
    if (isBusy ||
        !privacyConsentGranted ||
        consentVersion == null ||
        consentVersion.trim().isEmpty) {
      return false;
    }
    return _guard(() async {
      _accountTransitioning = true;
      try {
        await _drainCloudSync();
        session = await (_api as GlobalAccountApi).completeVerification(
          challengeId: challenge.id,
          code: code.trim(),
          password: password,
          resetPassword: resetPassword,
          locale: locale,
          consentVersion: consentVersion,
        );
        await _prepareAuthenticatedNotificationSession(
          privacyConsentGranted: privacyConsentGranted,
        );
        isPreviewMode = false;
        await refreshMemberProfile();
        await refreshActivityGoals();
        await refreshCare();
        await refreshCareInvitations();
        await _refreshRemoteNotificationUnreadCount();
        _careInvitationPollBackoffIndex = 0;
        _scheduleCareInvitationPoll(const Duration(seconds: 30));
      } finally {
        await _finishAccountTransition();
      }
    });
  }

  final HealthStore _healthStore;
  final WearableBridge _wearable;
  final AppPaymentBridge _paymentBridge;
  final StoreKitPurchaseBridge _storeKitPurchaseBridge;
  final WechatAuthBridge _wechatAuthBridge;
  int _wechatLoginGeneration = 0;
  bool isWechatLoginInProgress = false;
  bool get canCancelWechatLogin =>
      isWechatLoginInProgress && !_accountTransitioning;
  final AppNotificationService _notificationService;
  final List<Duration> _pushRegistrationRetryDelays;
  final HealthSyncService _syncService;
  late NotificationInboxRepository _notificationInboxRepository;
  late NotificationInboxService _notificationInboxService;
  static const NotificationRouteService _notificationRouteService =
      NotificationRouteService();
  final DeviceStateMachine deviceMachine = DeviceStateMachine();

  StreamSubscription<WearableEvent>? _wearableEvents;
  StreamSubscription<DeviceConnectionState>? _deviceStates;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  StreamSubscription<Map<String, Object?>>? _pushReceivedEvents;
  StreamSubscription<Map<String, Object?>>? _pushOpenedEvents;
  StreamSubscription<bool>? _pushPermissionEvents;
  StreamSubscription<void>? _pushRegistrationReadyEvents;
  Timer? _careInvitationPollTimer;
  int _careInvitationPollBackoffIndex = 0;
  bool _appIsForeground = true;
  Timer? _measurementTimeout;
  HealthMetric? _activeMeasurementMetric;
  bool _syncing = false;
  bool _accountTransitioning = false;
  Future<void>? _activeCloudSync;
  bool _disposed = false;
  int _deviceSyncGeneration = 0;
  int _wearableRestoreGeneration = 0;
  Future<void>? _wearableRestoreInFlight;
  Future<void>? _wearableConnectInFlight;
  bool _wearableAccountRecoveryAllowed = true;
  bool _wearableNeedsDisconnect = false;
  String _activeHealthOwner = 'anonymous';
  ({DeviceInfo device, int generation})? _accountWearableResume;
  DeviceInfo? _latestDeviceDetails;
  String? _deviceSyncErrorMessage;
  Future<void>? _deviceSettingsRefresh;
  Future<void> _notificationIngestTail = Future<void>.value();
  bool _notificationStorageReady = false;
  Future<void>? _careInvitationRefresh;
  Future<void>? _pushRegistration;
  int? _pushRegistrationGeneration;
  Timer? _pushRegistrationRetryTimer;
  int _pushRegistrationRetryAttempt = 0;
  int _sessionGeneration = 0;
  int? _careShareSaveGeneration;
  int? _connectedDeviceSessionGeneration;
  int? _activeMeasurementSessionGeneration;
  String _notificationOwnerId = 'anonymous';
  bool _privacyConsentGranted = false;

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
  bool sportPaused = false;
  Map<String, num> liveSportData = const {};
  List<DeviceInfo> scannedDevices = const [];
  DeviceScanIssue? deviceScanIssue;
  List<HealthRecord> healthRecords = const [];
  List<SportRecord> sportRecords = const [];
  List<Map<String, Object?>> careMembers = const [];
  List<Map<String, Object?>> careInvitations = const [];
  String careStatus = '等待加载';
  String? careErrorMessage;
  String careInvitationStatus = '等待加载';
  List<Map<String, Object?>> aiArticles = const [];
  List<Map<String, Object?>> aiMessages = const [];
  String? articleCategoryLoadError;
  String? articleListLoadError;
  String? articleDetailLoadError;
  List<Map<String, Object?>> notifications = const [];
  List<NotificationEvent> notificationInboxEvents = const [];
  int notificationUnreadCount = 0;
  int? remoteNotificationUnreadCount;
  NotificationRouteIntent? pendingNotificationRoute;
  bool notificationPermissionEnabled = false;
  PushDeviceRegistrationState pushDeviceRegistrationState =
      PushDeviceRegistrationState.idle;
  String? pushDeviceRegistrationIssueCode;
  Duration? pushDeviceRegistrationRetryDelay;
  int get pushDeviceRegistrationRetryAttempt => _pushRegistrationRetryAttempt;
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
  Map<String, AutoMeasureIntervalSetting> autoMeasureIntervals = const {};
  bool isDeviceSettingsLoading = false;
  Map<DeviceFeature, Map<String, Object?>> deviceFeatureData = const {};
  Set<DeviceFeature> deviceFeatureBusy = const {};
  int cameraShutterSequence = 0;
  int heartRateWarning = 120;
  bool heartRateWarningSupported = false;
  String deviceSettingsStatus = '连接戒指后可读取';
  HealthWarningSettings healthWarningSettings = const HealthWarningSettings();
  List<HealthWarningAlert> healthWarningAlerts = const [];
  HealthWarningAlert? activeHealthWarningAlert;
  NotificationEvent? activeCareInvitationAlert;

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

  List<Map<String, Object?>> get pendingCareInvitations =>
      careInvitations.where(_isPendingCareInvitation).toList(growable: false);

  bool get notificationServiceConfigured => _notificationService.isConfigured;

  String _notificationOwnerFor(Session? value) {
    final memberId = value?.memberId.trim() ?? '';
    final accountIdentity = memberId.isNotEmpty
        ? 'member:$memberId'
        : value == null
        ? ''
        : 'account:${value.accountKey.trim()}';
    if (accountIdentity.isEmpty) return 'anonymous';
    if (accountIdentity == 'account:') {
      throw StateError('Authenticated session has no stable account key');
    }
    return sha256
        .convert(utf8.encode('saydian-notification-owner:$accountIdentity'))
        .toString();
  }

  String _healthOwnerFor(Session? value) {
    final memberId = value?.memberId.trim() ?? '';
    final accountIdentity = memberId.isNotEmpty
        ? 'member:$memberId'
        : value == null
        ? ''
        : 'account:${value.accountKey.trim()}';
    if (accountIdentity.isEmpty) return 'anonymous';
    if (accountIdentity == 'account:') {
      throw StateError('Authenticated session has no stable account key');
    }
    return sha256
        .convert(utf8.encode('saydian-health-owner:$accountIdentity'))
        .toString();
  }

  void _switchNotificationOwner(Session? value) {
    _notificationOwnerId = _notificationOwnerFor(value);
    _notificationInboxRepository = StoredNotificationInboxRepository(
      _healthStore,
      ownerId: _notificationOwnerId,
    );
    _notificationInboxService = NotificationInboxService(
      _notificationInboxRepository,
    );
    notificationInboxEvents = const [];
    notificationUnreadCount = 0;
  }

  int _advanceSessionGeneration(Session? value) {
    _sessionGeneration++;
    _activeHealthOwner = _healthOwnerFor(value);
    _careInvitationRefresh = null;
    _pushRegistration = null;
    _pushRegistrationRetryTimer?.cancel();
    _pushRegistrationRetryTimer = null;
    _pushRegistrationRetryAttempt = 0;
    pushDeviceRegistrationRetryDelay = null;
    if (value != null ||
        (pushDeviceRegistrationState !=
                PushDeviceRegistrationState.unregistered &&
            pushDeviceRegistrationState !=
                PushDeviceRegistrationState.unregisterRetryPending)) {
      pushDeviceRegistrationState = PushDeviceRegistrationState.idle;
      pushDeviceRegistrationIssueCode = null;
    }
    _invalidateDeviceSync();
    _measurementTimeout?.cancel();
    _measurementTimeout = null;
    _activeMeasurementMetric = null;
    _activeMeasurementSessionGeneration = null;
    measurementProgress = 0;
    measurementSamples = const [];
    _clearAccountScopedMemory();
    _switchNotificationOwner(value);
    return _sessionGeneration;
  }

  void _clearAccountScopedMemory() {
    healthRecords = const [];
    sportRecords = const [];
    healthWarningAlerts = const [];
    activeHealthWarningAlert = null;
    activeCareInvitationAlert = null;
    activeSport = null;
    sportPaused = false;
    liveSportData = const {};
    careMembers = const [];
    careInvitations = const [];
    memberProfile = const {};
    aiMessages = const [];
    _aiSessionIds.clear();
    orders = const [];
    addresses = const [];
    notifications = const [];
    remoteNotificationUnreadCount = null;
    cloudSyncStatus = session == null ? '未登录，数据仅保存在本机' : '尚未上传';
  }

  Future<bool> _switchHealthOwnerAndLoad(
    Session? value, {
    required int expectedGeneration,
    bool loadCache = true,
  }) async {
    try {
      await _healthStore.switchOwner(_healthOwnerFor(value));
      if (!_isCurrentSessionGeneration(expectedGeneration)) return false;
      if (!loadCache) return true;
      await _refreshHealthRecordCache(expectedGeneration: expectedGeneration);
      if (!_isCurrentSessionGeneration(expectedGeneration)) return false;
      final alerts = await _healthStore.healthWarningAlerts();
      if (!_isCurrentSessionGeneration(expectedGeneration)) return false;
      final sports = await _healthStore.localSportRecords();
      if (!_isCurrentSessionGeneration(expectedGeneration)) return false;
      healthWarningAlerts = alerts;
      sportRecords = sports;
      return true;
    } catch (_) {
      if (_isCurrentSessionGeneration(expectedGeneration)) {
        _clearAccountScopedMemory();
        storageStatus = '本机数据暂时无法读取';
      }
      return false;
    }
  }

  bool _isCurrentSessionGeneration(int value) =>
      !_disposed && value == _sessionGeneration;

  Future<void> _ensureStableSessionOwnerKey() async {
    final current = session;
    if (current == null ||
        current.memberId.trim().isNotEmpty ||
        current.accountKey.trim().isNotEmpty) {
      return;
    }
    final stabilized = current.copyWith(
      accountKey: 'local-${const Uuid().v4()}',
    );
    final replaced = await _vault.writeSessionIfUnchanged(current, stabilized);
    if (replaced) {
      session = stabilized;
      return;
    }
    final latest = await _vault.readSession();
    if (latest == null ||
        (latest.memberId.trim().isEmpty && latest.accountKey.trim().isEmpty)) {
      throw StateError('Unable to establish a stable session owner');
    }
    session = latest;
  }

  static bool _isPendingCareInvitation(Map<String, Object?> invitation) {
    final raw = invitation['examine_status'] ?? invitation['examineStatus'];
    if (raw is num) return raw.toInt() == 0;
    final value = '${raw ?? ''}'.trim().toLowerCase();
    return value == '0' || value == 'pending' || value == 'waiting';
  }

  static String? _careInvitationId(Map<String, Object?> invitation) {
    final value = '${invitation['id'] ?? invitation['invitation_id'] ?? ''}'
        .trim();
    return RegExp(r'^[A-Za-z0-9._:-]{1,160}$').hasMatch(value) ? value : null;
  }

  List<SportMode> get availableSportModes {
    final reported = capabilities?.sportModes;
    if (connectedDevice == null ||
        !_hasResolvedDeviceCapabilities ||
        reported == null) {
      return const [];
    }
    return SportMode.values.where(reported.contains).toList(growable: false);
  }

  Future<void> initialize() async {
    _deviceStates = deviceMachine.changes.listen((_) => notifyListeners());
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none) &&
          session != null) {
        unawaited(synchronizeCloud());
      }
    });
    var healthStoreRecoveryPending = false;
    try {
      await _healthStore.initialize();
      _notificationStorageReady = true;
      final recoveryStatus = _healthStore;
      final recoveryNotice = recoveryStatus is HealthStoreRecoveryStatus
          ? (recoveryStatus as HealthStoreRecoveryStatus).recoveryNotice
          : null;
      healthStoreRecoveryPending = recoveryStatus is HealthStoreRecoveryStatus
          ? (recoveryStatus as HealthStoreRecoveryStatus).recoveryPending
          : false;
      storageStatus = recoveryNotice ?? '数据已安全保存在本机';
    } catch (_) {
      storageStatus = '本机数据暂时无法读取';
    }
    _pushReceivedEvents = _notificationService.receivedEvents.listen(
      (payload) =>
          unawaited(_handleNotificationPayload(payload).catchError((_) {})),
    );
    _pushOpenedEvents = _notificationService.openedEvents.listen(
      (payload) => unawaited(
        _handleNotificationPayload(payload, opened: true).catchError((_) {}),
      ),
    );
    _pushPermissionEvents = _notificationService.permissionChanges.listen((
      enabled,
    ) {
      if (_disposed || session == null || !_privacyConsentGranted) return;
      notificationPermissionEnabled = enabled;
      if (enabled) {
        unawaited(_registerPushDevice(resetBackoff: true));
      }
      notifyListeners();
    });
    _pushRegistrationReadyEvents = _notificationService.registrationReadyEvents
        .listen((_) {
          if (_disposed || session == null || !_privacyConsentGranted) return;
          unawaited(_registerPushDevice(resetBackoff: true));
        });
    try {
      await _notificationService.initialize();
    } catch (_) {
      // Push is optional; login and local health data remain available.
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
    var sessionReadSucceeded = false;
    try {
      session = await _vault.readSession();
      await _ensureStableSessionOwnerKey();
      sessionReadSucceeded = true;
    } catch (_) {
      errorMessage = '安全存储初始化失败';
    }
    try {
      _privacyConsentGranted = await _vault.readPrivacyConsentGranted();
    } catch (_) {
      _privacyConsentGranted = false;
    }
    if (_notificationStorageReady &&
        sessionReadSucceeded &&
        !healthStoreRecoveryPending) {
      try {
        final migrationHandled = await _vault
            .readLegacyHealthMigrationHandled();
        if (!migrationHandled) {
          final persistedSession = session;
          if (persistedSession != null && !isGlobalEdition) {
            // v5 and earlier had no account column. Only the account already
            // persisted when this migration is first observed may adopt those
            // records; a later login never inherits another user's history.
            await _healthStore.adoptLegacyData(
              healthOwnerId: _healthOwnerFor(persistedSession),
              notificationOwnerId: _notificationOwnerFor(persistedSession),
            );
          }
          await _vault.writeLegacyHealthMigrationHandled();
        }
      } catch (_) {
        storageStatus = '本机旧版本数据暂时无法读取';
      }
    }
    final sessionGeneration = _advanceSessionGeneration(session);
    if (_notificationStorageReady) {
      await _switchHealthOwnerAndLoad(
        session,
        expectedGeneration: sessionGeneration,
      );
    }
    if (session != null && _privacyConsentGranted) {
      try {
        await _notificationService.activateAfterPrivacyConsent();
        notificationPermissionEnabled = await _notificationService
            .isPermissionEnabled();
      } catch (_) {
        notificationPermissionEnabled = false;
      }
    } else {
      notificationPermissionEnabled = false;
    }
    if (_notificationStorageReady) await _refreshNotificationInboxState();
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
    if (_allowAutomaticWearableRestore) {
      unawaited(restoreWearableConnection());
    }
    isBooting = false;
    notifyListeners();
    unawaited(refreshAiArticles());
    if (session != null) {
      if (_api is CloudHealthRecordReader) {
        unawaited(synchronizeCloud());
      }
      unawaited(refreshHealthWarningCloudState());
      unawaited(refreshCare());
      unawaited(refreshCareInvitations());
      unawaited(_registerPushDevice(resetBackoff: true));
      unawaited(_refreshRemoteNotificationUnreadCount());
      unawaited(refreshMemberProfile());
      unawaited(refreshActivityGoals());
      _scheduleCareInvitationPoll(const Duration(seconds: 30));
    }
  }

  Future<bool> login(
    String username,
    String password, {
    bool privacyConsentGranted = false,
  }) async {
    if (isBusy) return false;
    if (username.trim().isEmpty || password.isEmpty) {
      errorMessage = '请输入账号和密码';
      notifyListeners();
      return false;
    }
    return _guard(() async {
      _accountTransitioning = true;
      try {
        await _drainCloudSync();
        session = await _api.login(username.trim(), password);
        await _prepareAuthenticatedNotificationSession(
          privacyConsentGranted: privacyConsentGranted,
        );
        isPreviewMode = false;
        await refreshCare();
        await refreshCareInvitations();
        await _refreshRemoteNotificationUnreadCount();
        await refreshMemberProfile();
        await refreshActivityGoals();
        unawaited(refreshHealthWarningCloudState());
        _careInvitationPollBackoffIndex = 0;
        _scheduleCareInvitationPoll(const Duration(seconds: 30));
      } finally {
        await _finishAccountTransition();
      }
    });
  }

  Future<bool> loginWithWechat({required bool privacyConsentGranted}) async {
    if (isBusy || _disposed) return false;
    if (!privacyConsentGranted) {
      errorMessage = '请先同意用户协议与隐私政策';
      notifyListeners();
      return false;
    }
    final api = _api;
    if (api is! SaydianWechatAuthApi) {
      errorMessage = '微信登录暂不可用，请使用手机号登录';
      notifyListeners();
      return false;
    }
    final generation = ++_wechatLoginGeneration;
    bool isCurrent() => !_disposed && generation == _wechatLoginGeneration;
    isBusy = true;
    isWechatLoginInProgress = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _vault.writePrivacyConsentGranted(true);
      if (!isCurrent()) return false;
      _privacyConsentGranted = true;
      final authorization = await _wechatAuthBridge.authorize();
      if (authorization == null || !isCurrent()) return false;
      final authenticated = await (api as SaydianWechatAuthApi).loginWithWechat(
        code: authorization.code,
      );
      if (!isCurrent()) return false;
      _accountTransitioning = true;
      await _drainCloudSync();
      if (!isCurrent()) return false;
      await _vault.writeSession(authenticated);
      if (!isCurrent()) return false;
      session = authenticated;
      await _prepareAuthenticatedNotificationSession(
        privacyConsentGranted: true,
        canContinue: isCurrent,
      );
      if (!isCurrent()) return false;
      isPreviewMode = false;
      await refreshCare();
      if (!isCurrent()) return false;
      await refreshCareInvitations();
      if (!isCurrent()) return false;
      await _refreshRemoteNotificationUnreadCount();
      if (!isCurrent()) return false;
      await refreshMemberProfile();
      if (!isCurrent()) return false;
      await refreshActivityGoals();
      if (!isCurrent()) return false;
      unawaited(refreshHealthWarningCloudState());
      _careInvitationPollBackoffIndex = 0;
      _scheduleCareInvitationPoll(const Duration(seconds: 30));
      return true;
    } on PlatformException catch (error) {
      if (isCurrent()) {
        errorMessage = switch (error.code) {
          'WECHAT_NOT_INSTALLED' => '请先安装微信',
          'WECHAT_UNSUPPORTED' => '请更新微信后重试',
          'WECHAT_AUTH_DENIED' => '未同意微信授权',
          'WECHAT_AUTH_TIMEOUT' => '微信授权已超时，请重试',
          'WECHAT_AUTH_SEND_FAILED' => '无法调起微信，请稍后重试',
          'WECHAT_AUTH_CONFIG_MISSING' => '微信登录暂不可用，请使用手机号登录',
          _ => '微信登录失败，请重试',
        };
      }
      return false;
    } on ApiException catch (error) {
      if (isCurrent()) {
        errorMessage = error.statusCode == 404 || error.statusCode == 405
            ? '微信登录暂不可用，请使用手机号登录'
            : _apiErrorMessage(error, fallback: '微信登录失败，请重试');
      }
      return false;
    } catch (_) {
      if (isCurrent()) errorMessage = '微信登录暂不可用，请使用手机号登录';
      return false;
    } finally {
      if (isCurrent()) {
        await _finishAccountTransition();
        isBusy = false;
        isWechatLoginInProgress = false;
        notifyListeners();
      }
    }
  }

  void cancelWechatLogin({bool force = false}) {
    if (!isWechatLoginInProgress || (!force && !canCancelWechatLogin)) return;
    ++_wechatLoginGeneration;
    isWechatLoginInProgress = false;
    isBusy = false;
    _accountTransitioning = false;
    unawaited(_wechatAuthBridge.cancel());
    if (!_disposed) notifyListeners();
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
    bool privacyConsentGranted = false,
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
      _accountTransitioning = true;
      try {
        await _drainCloudSync();
        await _vault.writePrivacyConsentGranted(privacyConsentGranted);
        _privacyConsentGranted = privacyConsentGranted;
        session = smsApi == null
            ? await _api.register(mobile.trim(), password)
            : await smsApi.registerWithSms(
                mobile: mobile.trim(),
                code: code!.trim(),
                password: password,
                nickname: nickname?.trim().isNotEmpty == true
                    ? nickname!.trim()
                    : 'Say Ring 用户${mobile.trim().substring(7)}',
              );
        await _prepareAuthenticatedNotificationSession(
          privacyConsentGranted: privacyConsentGranted,
        );
        isPreviewMode = false;
        await refreshCare();
        await refreshCareInvitations();
        await _refreshRemoteNotificationUnreadCount();
        await refreshMemberProfile();
        await refreshActivityGoals();
        _careInvitationPollBackoffIndex = 0;
        _scheduleCareInvitationPoll(const Duration(seconds: 30));
      } finally {
        await _finishAccountTransition();
      }
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
      _accountTransitioning = true;
      try {
        await _drainCloudSync();
        session = await (api as SaydianSmsAuthApi).resetPassword(
          mobile: normalized,
          code: code.trim(),
          password: password,
        );
        await _prepareAuthenticatedNotificationSession(
          privacyConsentGranted: _privacyConsentGranted,
        );
        isPreviewMode = false;
        await _refreshRemoteNotificationUnreadCount();
        _careInvitationPollBackoffIndex = 0;
        _scheduleCareInvitationPoll(const Duration(seconds: 30));
      } finally {
        await _finishAccountTransition();
      }
    });
  }

  Future<void> _prepareAuthenticatedNotificationSession({
    required bool privacyConsentGranted,
    bool Function()? canContinue,
  }) async {
    await _ensureStableSessionOwnerKey();
    if (canContinue?.call() == false) return;
    _privacyConsentGranted = privacyConsentGranted;
    await _vault.writePrivacyConsentGranted(privacyConsentGranted);
    if (canContinue?.call() == false) return;
    final previousDevice = connectedDevice;
    final sameOwner =
        session != null && _activeHealthOwner == _healthOwnerFor(session);
    final disconnected = await _pauseWearableForAccountTransition();
    if (canContinue?.call() == false) return;
    final generation = _advanceSessionGeneration(session);
    final storageReady = await _switchHealthOwnerAndLoad(
      session,
      expectedGeneration: generation,
    );
    if (!_isCurrentSessionGeneration(generation)) return;
    if (storageReady && sameOwner && previousDevice != null && disconnected) {
      _accountWearableResume = (device: previousDevice, generation: generation);
    }
    if (!privacyConsentGranted || session == null) {
      notificationPermissionEnabled = false;
      await _notificationService.deactivate();
    } else {
      try {
        await _notificationService.activateAfterPrivacyConsent();
        notificationPermissionEnabled = await _notificationService
            .isPermissionEnabled();
      } catch (_) {
        notificationPermissionEnabled = false;
      }
      unawaited(_registerPushDevice(resetBackoff: true));
    }
    if (_notificationStorageReady) await _refreshNotificationInboxState();
  }

  Future<bool> _pauseWearableForAccountTransition() async {
    _accountWearableResume = null;
    _wearableAccountRecoveryAllowed = false;
    final hasNativeSession =
        connectedDevice != null ||
        _wearableConnectInFlight != null ||
        _wearableRestoreInFlight != null ||
        deviceState != DeviceConnectionState.disconnected ||
        _wearableNeedsDisconnect;
    _connectedDeviceSessionGeneration = null;
    _invalidateDeviceSync();
    final metric = _activeMeasurementMetric;
    _measurementTimeout?.cancel();
    _measurementTimeout = null;
    _activeMeasurementMetric = null;
    _activeMeasurementSessionGeneration = null;
    measurementSamples = const [];
    measurementProgress = 0;
    if (!hasNativeSession) return true;
    _wearableNeedsDisconnect = true;
    if (metric != null) {
      try {
        await _wearable
            .stopMeasurement(metric)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Disconnect below remains required even when stopping a measurement fails.
      }
    }
    try {
      await disconnectDevice();
      // A connect/authentication callback may finish after native disconnect.
      // Drain it before opening another account or reconnecting the same owner.
      await _wearableConnectInFlight;
      return true;
    } catch (_) {
      sdkStatus = '请在设备页重新连接戒指';
      return false;
    }
  }

  Future<void> _finishAccountTransition() async {
    final resume = _accountWearableResume;
    _accountWearableResume = null;
    _accountTransitioning = false;
    if (resume != null &&
        session != null &&
        _isCurrentSessionGeneration(resume.generation)) {
      // Same-owner reauthentication is an explicit fresh native connection,
      // not reassignment of the old connection generation.
      await connectDevice(resume.device);
    }
    if (session != null && _api is CloudHealthRecordReader) {
      unawaited(synchronizeCloud());
    }
  }

  void enterPreview() {
    isPreviewMode = true;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    cancelWechatLogin(force: true);
    isBusy = true;
    _accountTransitioning = true;
    notifyListeners();
    try {
      await _pauseWearableForAccountTransition();
      await _drainCloudSync();
      if (session != null) {
        await _unregisterPushDevice();
        await _api.logout();
      } else {
        await _vault.clearSession();
      }
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '退出失败，请稍后重试');
    } finally {
      try {
        await _vault.clearSession();
        await _vault.writePrivacyConsentGranted(false);
      } catch (_) {
        // The in-memory session is still cleared immediately below.
      }
      session = null;
      _privacyConsentGranted = false;
      final generation = _advanceSessionGeneration(null);
      await _switchHealthOwnerAndLoad(
        null,
        expectedGeneration: generation,
        loadCache: false,
      );
      isPreviewMode = false;
      memberProfile = const {};
      careMembers = const [];
      careInvitations = const [];
      aiMessages = const [];
      _aiSessionIds.clear();
      notifications = const [];
      remoteNotificationUnreadCount = null;
      pendingNotificationRoute = null;
      _careInvitationPollTimer?.cancel();
      notificationInboxEvents = const [];
      notificationUnreadCount = 0;
      await _notificationService.setBadge(0);
      await _notificationService.deactivate();
      orders = const [];
      addresses = const [];
      selectedTab = 0;
      _accountTransitioning = false;
      isBusy = false;
      if (_notificationStorageReady) await _refreshNotificationInboxState();
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() => _guard(() async {
    _accountTransitioning = true;
    try {
      await _drainCloudSync();
      if (session == null) {
        throw const ApiException('快速体验账号无需注销');
      }
      final notificationInboxToClear = _notificationInboxService;
      await _unregisterPushDevice();
      await _api.deleteAccount();
      await _pauseWearableForAccountTransition();
      await _vault.writePrivacyConsentGranted(false);
      session = null;
      _privacyConsentGranted = false;
      final generation = _advanceSessionGeneration(null);
      await _switchHealthOwnerAndLoad(
        null,
        expectedGeneration: generation,
        loadCache: false,
      );
      isPreviewMode = false;
      _careInvitationPollTimer?.cancel();
      pendingNotificationRoute = null;
      careMembers = const [];
      careInvitations = const [];
      remoteNotificationUnreadCount = null;
      if (_notificationStorageReady) await notificationInboxToClear.clear();
      notificationInboxEvents = const [];
      notificationUnreadCount = 0;
      await _notificationService.setBadge(0);
      await _notificationService.deactivate();
    } finally {
      _accountTransitioning = false;
    }
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
    deviceScanIssue = null;
    scannedDevices = const [];
    try {
      if (!await _ensureBluetoothPermissions()) {
        deviceScanIssue = DeviceScanIssue.permissionsRequired;
        errorMessage = '允许相关权限后使用';
        notifyListeners();
        return;
      }
      await _cancelPendingWearableRestore();
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
      deviceScanIssue = switch (error.code) {
        'LOCATION_SERVICE_DISABLED' => DeviceScanIssue.locationServiceDisabled,
        'BLE_PERMISSION_DENIED' ||
        'BLE_PERMISSION_REQUIRED' ||
        'BLUETOOTH_PERMISSION_REQUIRED' => DeviceScanIssue.permissionsRequired,
        _ => null,
      };
      errorMessage = _wearableErrorMessage(error, fallback: '暂时无法查找戒指');
      deviceMachine.transition(DeviceConnectionState.error);
    } catch (_) {
      errorMessage = '暂时无法查找戒指，请稍后重试';
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
    if (!statuses.values.every((status) => status.isGranted)) return false;
    // Android 11 and older also gate BLE scan results on the system location
    // switch. Check before either vendor scanner starts; permissions alone do
    // not prove that scanning is available. Android 12+ uses nearby devices.
    if (android.version.sdkInt <= 30 &&
        await Permission.locationWhenInUse.serviceStatus !=
            ServiceStatus.enabled) {
      throw PlatformException(
        code: 'LOCATION_SERVICE_DISABLED',
        message: '请开启手机定位后再查找戒指',
      );
    }
    return true;
  }

  Future<void> connectDevice(DeviceInfo device) async {
    if (_disposed ||
        _accountTransitioning ||
        _wearableConnectInFlight != null) {
      return;
    }
    final connecting = _connectDevice(device);
    _wearableConnectInFlight = connecting;
    try {
      await connecting;
    } finally {
      if (identical(_wearableConnectInFlight, connecting)) {
        _wearableConnectInFlight = null;
      }
    }
  }

  Future<void> _connectDevice(DeviceInfo device) async {
    final sessionGeneration = _sessionGeneration;
    bool isCurrent() =>
        !_accountTransitioning &&
        _isCurrentSessionGeneration(sessionGeneration);
    errorMessage = null;
    _invalidateDeviceSync();
    _latestDeviceDetails = null;
    try {
      if (_wearableNeedsDisconnect) await disconnectDevice();
      await _cancelPendingWearableRestore();
      if (!isCurrent()) return;
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
      if (!isCurrent()) return;
      _wearableAccountRecoveryAllowed = true;
      _connectedDeviceSessionGeneration = sessionGeneration;
      connectedDevice = _mergeDeviceDetails(device);
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.loading;
      deviceMachine.transition(DeviceConnectionState.authenticating);
      await refreshDeviceCapabilities(announceFailure: false);
      if (!isCurrent() || connectedDevice?.id != device.id) return;
      deviceMachine.transition(DeviceConnectionState.syncing);
      syncStatus = '正在同步设备数据';
      deviceMachine.transition(DeviceConnectionState.ready);
      // Authentication is the connection boundary. Historical data is a
      // background follow-up and must not keep the add-device page spinning.
      unawaited(_syncInitialDeviceData(device.id));
    } on WearableSdkNotConfigured catch (_) {
      if (!isCurrent()) return;
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      sdkStatus = '设备连接服务暂时不可用';
      errorMessage = '此功能暂时无法使用，请稍后再试';
      deviceMachine.transition(DeviceConnectionState.error);
    } on PlatformException catch (error) {
      if (!isCurrent()) return;
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
      if (!isCurrent()) return;
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      errorMessage = '连接失败，请将戒指靠近手机后重试';
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
    final generation = _sessionGeneration;
    bool isCurrent() =>
        !_accountTransitioning &&
        _isCurrentSessionGeneration(generation) &&
        connectedDevice?.id == deviceId;
    capabilities = null;
    deviceCapabilityState = DeviceCapabilityState.loading;
    notifyListeners();
    try {
      final reported = await _wearable.getCapabilities();
      if (!isCurrent()) return false;
      capabilities = reported;
      deviceCapabilityState = DeviceCapabilityState.ready;
      notifyListeners();
      return true;
    } on PlatformException catch (error) {
      if (!isCurrent()) return false;
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.unavailable;
      if (announceFailure) {
        errorMessage = _wearableErrorMessage(error, fallback: '暂时无法读取此戒指的功能');
      }
    } catch (_) {
      if (!isCurrent()) return false;
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.unavailable;
      if (announceFailure) errorMessage = '暂时无法读取此戒指的功能';
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

  Future<bool> syncDeviceData() async {
    final device = connectedDevice;
    if (device == null) {
      errorMessage = '请先连接戒指';
      notifyListeners();
      return false;
    }
    if (isDeviceSyncing) return false;
    final succeeded = await _syncDeviceData(device.id, initial: false);
    if (succeeded) {
      unawaited(synchronizeCloud());
    }
    return succeeded;
  }

  Future<bool> _syncDeviceData(String deviceId, {required bool initial}) async {
    if (_accountTransitioning ||
        connectedDevice?.id != deviceId ||
        isDeviceSyncing) {
      return false;
    }
    final sessionGeneration = _sessionGeneration;
    _connectedDeviceSessionGeneration ??= sessionGeneration;
    if (_connectedDeviceSessionGeneration != sessionGeneration) return false;
    final generation = ++_deviceSyncGeneration;
    isDeviceSyncing = true;
    var succeeded = false;
    deviceSyncProgress = 0;
    syncStatus = '正在读取戒指数据';
    _clearDeviceSyncError();
    notifyListeners();
    try {
      final receivedRecords = await _wearable.syncHealthData();
      if (!_isDeviceSyncCurrent(generation, deviceId, sessionGeneration)) {
        return false;
      }
      final records = deduplicateHealthRecords(
        receivedRecords
            .map(sanitizeWearableTransportRecord)
            .where(hasSaneWearableTransportValues),
      );
      await _healthStore.upsert(records);
      if (!_isDeviceSyncCurrent(generation, deviceId, sessionGeneration)) {
        return false;
      }
      await _refreshHealthRecordCache(expectedGeneration: sessionGeneration);
      if (!_isDeviceSyncCurrent(generation, deviceId, sessionGeneration)) {
        return false;
      }
      for (final record in records) {
        _evaluateHealthWarning(record, expectedGeneration: sessionGeneration);
      }
      syncStatus = records.isEmpty ? '设备暂无新数据' : '已同步 ${records.length} 条';
      succeeded = true;
    } on PlatformException catch (error) {
      if (!_isDeviceSyncCurrent(generation, deviceId, sessionGeneration)) {
        return false;
      }
      syncStatus = '设备已连接，${initial ? '首次数据同步失败' : '历史数据同步失败'}';
      _deviceSyncErrorMessage =
          '设备已连接，但${_wearableErrorMessage(error, fallback: initial ? '首次数据同步失败' : '历史数据同步失败')}';
      errorMessage = _deviceSyncErrorMessage;
    } catch (_) {
      if (!_isDeviceSyncCurrent(generation, deviceId, sessionGeneration)) {
        return false;
      }
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
    return succeeded &&
        _isDeviceSyncCurrent(generation, deviceId, sessionGeneration);
  }

  bool _isDeviceSyncCurrent(
    int generation,
    String deviceId,
    int sessionGeneration,
  ) =>
      !_disposed &&
      !_accountTransitioning &&
      _deviceSyncGeneration == generation &&
      _isCurrentSessionGeneration(sessionGeneration) &&
      _connectedDeviceSessionGeneration == sessionGeneration &&
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
    await _cancelPendingWearableRestore();
    _invalidateDeviceSync();
    try {
      await _wearable.disconnect();
      _wearableNeedsDisconnect = false;
    } finally {
      connectedDevice = null;
      _connectedDeviceSessionGeneration = null;
      _latestDeviceDetails = null;
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      deviceFeatureData = const {};
      deviceFeatureBusy = const {};
      if (deviceState != DeviceConnectionState.disconnected) {
        deviceMachine.transition(DeviceConnectionState.disconnected);
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
        _connectedDeviceSessionGeneration = null;
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
        errorMessage = '戒指连接已断开，请重新连接';
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
      measurementErrorMessage = '另一项戒指测量尚未结束，请稍后重试';
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
      errorMessage = '请先连接戒指';
      notifyListeners();
      return false;
    }
    if (!(capabilities?.supportsManualMeasurement(metric) ?? false)) {
      errorMessage = '当前设备不支持${metric.label}测量';
      notifyListeners();
      return false;
    }
    if (isDeviceSyncing) {
      measurementErrorMessage = '戒指数据正在同步，请稍后再测量';
      errorMessage = measurementErrorMessage;
      notifyListeners();
      return false;
    }
    try {
      final sessionGeneration = _sessionGeneration;
      _activeMeasurementMetric = metric;
      _activeMeasurementSessionGeneration = sessionGeneration;
      deviceMachine.transition(DeviceConnectionState.measuring);
      await _wearable.startMeasurement(metric);
      if (!_isCurrentSessionGeneration(sessionGeneration) ||
          _activeMeasurementSessionGeneration != sessionGeneration ||
          _activeMeasurementMetric != metric ||
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
      _activeMeasurementSessionGeneration = null;
      measurementErrorMessage = '此功能暂时无法使用，请稍后再试';
      errorMessage = measurementErrorMessage;
      if (deviceState == DeviceConnectionState.measuring) {
        deviceMachine.transition(DeviceConnectionState.ready);
      }
    } on PlatformException catch (error) {
      _activeMeasurementMetric = null;
      _activeMeasurementSessionGeneration = null;
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
      _activeMeasurementSessionGeneration = null;
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
    _activeMeasurementSessionGeneration = null;
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
  }) async {
    final generation = _sessionGeneration;
    final records = await _healthStore.range(
      metric: metric,
      start: start,
      end: end,
    );
    if (!_isCurrentSessionGeneration(generation)) return const [];
    return deduplicateHealthRecords(
      ringPreferredHealthRecords(
        records.where(hasSaneWearableTransportValues),
        preferredDeviceId: connectedDevice?.id,
      ),
    );
  }

  void setUnits({String? distance, String? temperature}) {
    if (distance != null) distanceUnit = distance;
    if (temperature != null) temperatureUnit = temperature;
    notifyListeners();
  }

  Future<void> _handleMeasurementTimeout(HealthMetric metric) async {
    final generation = _activeMeasurementSessionGeneration;
    if (_activeMeasurementMetric != metric ||
        generation == null ||
        !_isCurrentSessionGeneration(generation)) {
      return;
    }
    _activeMeasurementMetric = null;
    _activeMeasurementSessionGeneration = null;
    _measurementTimeout = null;
    measurementErrorMessage = '长时间未检测到有效结果，请确认戒指已贴合手指后重新测量';
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
    // Native owns the 150-second W9S result timeout. This longer Flutter
    // watchdog prevents a race while the 500 Hz stream is settling at 100%.
    HealthMetric.ecg => const Duration(seconds: 160),
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
      final api = _api;
      if (api is SaydianHealthCloudApi && session != null) {
        try {
          await (api as SaydianHealthCloudApi).saveHealthWarningSettings(
            settings,
          );
        } on FeatureNotConfiguredException {
          // The old service has no cloud rules. Preserve local reminders until
          // the new compatibility service is switched on.
        } on ApiException catch (error) {
          if (error.statusCode != 404 && error.statusCode != 405) rethrow;
        }
      }
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

  Future<void> refreshHealthWarningCloudState() async {
    final api = _api;
    if (api is! SaydianHealthCloudApi || session == null) return;
    final expectedGeneration = _sessionGeneration;
    try {
      final cloudApi = api as SaydianHealthCloudApi;
      final results = await Future.wait<Object?>([
        cloudApi.getHealthWarningSettings(),
        cloudApi.getHealthWarningAlerts(),
      ]);
      if (_disposed ||
          session == null ||
          expectedGeneration != _sessionGeneration) {
        return;
      }
      final settings = results[0];
      if (settings is HealthWarningSettings) {
        // The deployed endpoint stores switches plus the heart-rate threshold.
        // Blood-pressure and temperature thresholds remain local App settings.
        final mergedSettings = HealthWarningSettings(
          heartRateEnabled: settings.heartRateEnabled,
          heartRateUpper: settings.heartRateUpper,
          bloodPressureEnabled: settings.bloodPressureEnabled,
          systolicUpper: healthWarningSettings.systolicUpper,
          diastolicUpper: healthWarningSettings.diastolicUpper,
          temperatureEnabled: settings.temperatureEnabled,
          temperatureUpper: healthWarningSettings.temperatureUpper,
        );
        healthWarningSettings = mergedSettings;
        await _vault.writeHealthWarningSettings(mergedSettings);
      }
      final remoteAlerts = results[1] as List<HealthWarningAlert>;
      final merged = <String, HealthWarningAlert>{
        for (final alert in healthWarningAlerts) alert.id: alert,
        for (final alert in remoteAlerts) alert.id: alert,
      };
      healthWarningAlerts = merged.values.toList()
        ..sort((left, right) => right.triggeredAt.compareTo(left.triggeredAt));
      notifyListeners();
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) return;
      // Background refresh failure must not hide already available local
      // warnings or block the rest of app startup.
    }
  }

  Future<bool> submitFeedback({
    required String category,
    required String content,
    String contact = '',
  }) async {
    if (session == null) {
      errorMessage = '请先登录后提交反馈';
      notifyListeners();
      return false;
    }
    final api = _api;
    if (api is! SaydianFeedbackApi) {
      errorMessage = '此功能暂时无法使用，请稍后再试';
      notifyListeners();
      return false;
    }
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await (api as SaydianFeedbackApi).submitFeedback(
        category: category,
        content: content,
        contact: contact,
      );
      return true;
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '反馈提交失败，请稍后重试');
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void dismissHealthWarningAlert() {
    final alert = activeHealthWarningAlert;
    if (alert == null) return;
    activeHealthWarningAlert = null;
    unawaited(markHealthWarningRead(alert));
    notifyListeners();
  }

  String healthWarningEventId(HealthWarningAlert alert) =>
      'health-warning-${_stableIdentifierHash(alert.id)}';

  Future<void> markHealthWarningRead(HealthWarningAlert alert) =>
      markNotificationEventRead(healthWarningEventId(alert));

  Future<bool> startSport(SportMode mode) async {
    if (connectedDevice == null) {
      errorMessage = '请先连接戒指后再开始运动';
      notifyListeners();
      return false;
    }
    final reportedModes = capabilities?.sportModes;
    if (_hasResolvedDeviceCapabilities &&
        reportedModes != null &&
        !reportedModes.contains(mode)) {
      errorMessage = '当前戒指不支持从 APP 开启${mode.label}';
      notifyListeners();
      return false;
    }
    errorMessage = null;
    try {
      await _wearable.startSport(mode);
      activeSport = mode;
      sportPaused = false;
      liveSportData = const {};
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
      sportPaused = false;
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

  Future<bool> setSportPaused(bool paused) async {
    if (activeSport == null || capabilities?.supportsSportPause != true) {
      errorMessage = '当前戒指不支持暂停运动';
      notifyListeners();
      return false;
    }
    final bridge = _wearable;
    if (bridge is! WearableSportPauseBridge) {
      errorMessage = '当前戒指不支持暂停运动';
      notifyListeners();
      return false;
    }
    try {
      if (paused) {
        await (bridge as WearableSportPauseBridge).pauseSport();
      } else {
        await (bridge as WearableSportPauseBridge).resumeSport();
      }
      sportPaused = paused;
      errorMessage = null;
      notifyListeners();
      return true;
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(error, fallback: '运动状态切换失败');
    } catch (_) {
      errorMessage = '运动状态切换失败，请稍后重试';
    }
    notifyListeners();
    return false;
  }

  Future<void> refreshSportRecords() async {
    final generation = _sessionGeneration;
    await Future<void>.delayed(Duration.zero);
    if (!_isCurrentSessionGeneration(generation)) return;
    final localRecords = await _healthStore.localSportRecords();
    if (!_isCurrentSessionGeneration(generation)) return;
    if (connectedDevice == null) {
      sportRecords = localRecords;
      notifyListeners();
      return;
    }
    sportRecords = localRecords;
    try {
      final records = await _wearable.readSportRecords();
      if (!_isCurrentSessionGeneration(generation)) return;
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
      if (!_isCurrentSessionGeneration(generation)) return;
      errorMessage = _wearableErrorMessage(error, fallback: '读取运动记录失败');
    } catch (_) {
      if (!_isCurrentSessionGeneration(generation)) return;
      errorMessage = '运动记录读取失败，请稍后重试';
    }
    notifyListeners();
  }

  Future<void> saveLocalSportRecord(SportRecord record) async {
    final generation = _sessionGeneration;
    await _healthStore.saveSportRecord(record);
    if (!_isCurrentSessionGeneration(generation)) return;
    await refreshSportRecords();
  }

  Future<void> refreshDeviceSettings() {
    final activeRefresh = _deviceSettingsRefresh;
    if (activeRefresh != null) return activeRefresh;

    late final Future<void> refresh;
    refresh = _refreshDeviceSettings().whenComplete(() {
      if (!identical(_deviceSettingsRefresh, refresh)) return;
      _deviceSettingsRefresh = null;
      if (_disposed) return;
      isDeviceSettingsLoading = false;
      notifyListeners();
    });
    _deviceSettingsRefresh = refresh;
    return refresh;
  }

  Future<void> _refreshDeviceSettings() async {
    await Future<void>.delayed(Duration.zero);
    if (_disposed) return;
    if (connectedDevice == null) {
      autoMeasureSettings = const {};
      autoMeasureIntervals = const {};
      heartRateWarningSupported = false;
      deviceSettingsStatus = '请先连接戒指';
      notifyListeners();
      return;
    }
    final expectedDeviceId = connectedDevice!.id;
    isDeviceSettingsLoading = true;
    deviceSettingsStatus = '正在读取戒指设置';
    notifyListeners();
    try {
      Map<String, bool> settings;
      try {
        settings = await _wearable.readAutoMeasureSettings();
      } on PlatformException catch (error) {
        if (!_isTransientDeviceSettingsError(error)) rethrow;
        if (_disposed || connectedDevice?.id != expectedDeviceId) return;
        deviceSettingsStatus = '戒指正在准备设置，正在重新读取';
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (_disposed || connectedDevice?.id != expectedDeviceId) return;
        settings = await _wearable.readAutoMeasureSettings();
      }
      if (_disposed || connectedDevice?.id != expectedDeviceId) return;
      autoMeasureSettings = settings;
      var partialRead = false;
      final bridge = _wearable;
      if (bridge is WearableAutoMeasureIntervalBridge) {
        try {
          autoMeasureIntervals =
              await (bridge as WearableAutoMeasureIntervalBridge)
                  .readAutoMeasureIntervals();
        } on PlatformException {
          partialRead = true;
        } catch (_) {
          partialRead = true;
        }
      } else {
        autoMeasureIntervals = const {};
      }
      try {
        final warning = await _wearable.readHeartRateWarning();
        heartRateWarningSupported = warning != null;
        if (warning != null && warning > 0) {
          final bounded = warning.clamp(70, 185).toInt();
          heartRateWarning = (bounded ~/ 5) * 5;
        }
      } on PlatformException {
        partialRead = true;
      } catch (_) {
        partialRead = true;
      }
      if (_disposed || connectedDevice?.id != expectedDeviceId) return;
      deviceSettingsStatus = settings.isEmpty && !heartRateWarningSupported
          ? '当前戒指未提供可设置的健康检测项目'
          : partialRead
          ? '主要设置已读取，部分项目可稍后刷新'
          : '设置已同步';
    } on PlatformException catch (error) {
      deviceSettingsStatus = autoMeasureSettings.isEmpty
          ? _wearableErrorMessage(error, fallback: '读取戒指设置失败，请点击重试')
          : '刷新失败，已显示上次读取的设置';
    } catch (_) {
      deviceSettingsStatus = autoMeasureSettings.isEmpty
          ? '戒指设置读取失败，请稍后重试'
          : '刷新失败，已显示上次读取的设置';
    }
    if (!_disposed) notifyListeners();
  }

  bool _isTransientDeviceSettingsError(PlatformException error) => const {
    'AUTO_MEASURE_READ_FAILED',
    'AUTO_MEASURE_READ_TIMEOUT',
    'WEARABLE_ERROR',
  }.contains(error.code);

  Future<void> setAutoMeasureSetting(String type, bool enabled) async {
    if (connectedDevice == null) {
      errorMessage = '请先连接戒指';
      notifyListeners();
      return;
    }
    try {
      await _wearable.setAutoMeasureSetting(type, enabled);
      autoMeasureSettings = {...autoMeasureSettings, type: enabled};
      deviceSettingsStatus = '设置已写入戒指';
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(error, fallback: '写入戒指设置失败');
    }
    notifyListeners();
  }

  Future<void> setAutoMeasureInterval(String type, int minutes) async {
    if (connectedDevice == null) {
      errorMessage = '请先连接戒指';
      notifyListeners();
      return;
    }
    final bridge = _wearable;
    if (bridge is! WearableAutoMeasureIntervalBridge) {
      errorMessage = '当前戒指不支持调整监测间隔';
      notifyListeners();
      return;
    }
    try {
      await (bridge as WearableAutoMeasureIntervalBridge)
          .setAutoMeasureInterval(type, minutes);
      final current = autoMeasureIntervals[type];
      if (current != null) {
        autoMeasureIntervals = {
          ...autoMeasureIntervals,
          type: AutoMeasureIntervalSetting(
            minutes: minutes,
            stepMinutes: current.stepMinutes,
            canModify: current.canModify,
          ),
        };
      }
      deviceSettingsStatus = '监测间隔已写入戒指';
    } on PlatformException catch (error) {
      errorMessage = _wearableErrorMessage(error, fallback: '监测间隔设置失败');
    }
    notifyListeners();
  }

  Future<void> _cancelPendingWearableRestore() async {
    _wearableRestoreGeneration++;
    final pending = _wearableRestoreInFlight;
    if (pending == null) return;
    try {
      await _wearable.stopScan().timeout(const Duration(seconds: 3));
    } catch (_) {
      // The restore may already be connecting. Waiting below still prevents
      // an old target from racing a user-selected device.
    }
    try {
      await pending;
    } catch (_) {
      // Restore failures are already translated into controller status.
    }
  }

  Future<void> restoreWearableConnection() async {
    if (!_allowAutomaticWearableRestore ||
        _disposed ||
        _accountTransitioning ||
        !_privacyConsentGranted ||
        !_wearableAccountRecoveryAllowed ||
        connectedDevice != null ||
        deviceState != DeviceConnectionState.disconnected) {
      return;
    }
    final active = _wearableRestoreInFlight;
    if (active != null) {
      await active;
      return;
    }
    final generation = _wearableRestoreGeneration;
    late final Future<void> restore;
    restore = _runWearableConnectionRestore(generation);
    _wearableRestoreInFlight = restore;
    try {
      await restore;
    } finally {
      if (identical(_wearableRestoreInFlight, restore)) {
        _wearableRestoreInFlight = null;
      }
    }
  }

  Future<void> _runWearableConnectionRestore(int generation) async {
    final bridge = _wearable;
    if (bridge is! WearableConnectionRecoveryBridge) return;
    try {
      final device = await (bridge as WearableConnectionRecoveryBridge)
          .restoreConnection(
            profile: WearableUserProfile.fromMember(
              memberProfile,
              targetSteps: stepGoal,
            ),
          );
      if (_disposed || generation != _wearableRestoreGeneration) {
        if (device != null && connectedDevice == null) {
          try {
            await _wearable.disconnect();
          } catch (_) {
            // The stale native session is best-effort cleanup. The pending
            // manual action will still perform its own guarded disconnect.
          }
        }
        return;
      }
      if (device == null || connectedDevice != null) return;
      await _restoreReconnectedDevice(device.toJson());
    } on PlatformException catch (error) {
      if (generation != _wearableRestoreGeneration) return;
      if (error.code == 'NO_SAVED_DEVICE') return;
      sdkStatus = _wearableErrorMessage(error, fallback: '戒指自动重连失败');
      notifyListeners();
    } catch (_) {
      if (generation != _wearableRestoreGeneration) return;
      sdkStatus = '戒指自动重连失败，可在设备页重新连接';
      notifyListeners();
    }
  }

  Future<void> setHeartRateWarning(int value) async {
    if (connectedDevice == null) {
      errorMessage = '请先连接戒指';
      notifyListeners();
      return;
    }
    try {
      await _wearable.setHeartRateWarning(value);
      heartRateWarning = value;
      deviceSettingsStatus = '心率预警已写入戒指';
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
      // Never guess a device-family profile: a wrong binary compatibility
      // tuple can make a valid watch-face file fail or damage the transfer.
      return const {};
    }
  }

  bool get usesNativeWatchFaceMarket =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      _wearable is WearableNativeWatchFaceBridge;

  Future<List<NativeWatchFaceCatalogItem>> readNativeWatchFaceCatalog() async {
    if (connectedDevice == null || !usesNativeWatchFaceMarket) {
      throw UnsupportedError('当前平台不支持原生显示样式目录');
    }
    return (_wearable as WearableNativeWatchFaceBridge)
        .getNativeWatchFaceCatalog();
  }

  Future<NativeWatchFaceDownload> downloadNativeWatchFace(
    String catalogId,
  ) async {
    if (connectedDevice == null || !usesNativeWatchFaceMarket) {
      throw UnsupportedError('当前平台不支持原生显示样式下载');
    }
    return (_wearable as WearableNativeWatchFaceBridge).downloadNativeWatchFace(
      catalogId,
    );
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
    if (_syncing || _disposed || _accountTransitioning) return;
    if (session == null) {
      cloudSyncStatus = '未登录，数据仅保存在本机';
      if (!_disposed) notifyListeners();
      return;
    }
    final generation = _sessionGeneration;
    final completion = Completer<void>();
    final activeFuture = completion.future;
    _activeCloudSync = activeFuture;
    _syncing = true;
    try {
      final result = await _syncService.synchronizeNow(
        isCurrent: () =>
            !_accountTransitioning && _isCurrentSessionGeneration(generation),
      );
      if (!_isCurrentSessionGeneration(generation)) return;
      var downloaded = 0;
      final api = _api;
      if (api is CloudHealthRecordReader) {
        final reader = api as CloudHealthRecordReader;
        try {
          downloaded = await _pullCloudHealthRecords(reader, generation);
        } on ApiException catch (error) {
          if (!_isCurrentSessionGeneration(generation)) return;
          cloudSyncStatus = result.uploaded > 0
              ? '本机数据已上传，云端记录暂时无法读取'
              : _apiErrorMessage(error, fallback: '云端记录暂时无法读取');
          return;
        }
      }
      cloudSyncStatus =
          result.message ?? '已上传 ${result.uploaded} 条，读取 $downloaded 条云端记录';
    } on ApiException catch (error) {
      if (!_isCurrentSessionGeneration(generation)) return;
      cloudSyncStatus = _apiErrorMessage(error, fallback: '数据上传失败，请稍后重试');
    } finally {
      _syncing = false;
      if (!completion.isCompleted) completion.complete();
      if (identical(_activeCloudSync, activeFuture)) {
        _activeCloudSync = null;
      }
      if (_isCurrentSessionGeneration(generation)) notifyListeners();
    }
  }

  Future<int> _pullCloudHealthRecords(
    CloudHealthRecordReader reader,
    int generation,
  ) async {
    String? before;
    final cursors = <String>{};
    var received = 0;
    for (var pageNumber = 0; pageNumber < 100; pageNumber++) {
      if (!_isCurrentSessionGeneration(generation)) return received;
      final page = await reader.getCloudHealthRecords(before: before);
      if (!_isCurrentSessionGeneration(generation)) return received;
      await _healthStore.upsertSynced(page.records);
      if (!_isCurrentSessionGeneration(generation)) return received;
      received += page.records.length;
      final next = page.nextCursor;
      if (next == null) {
        await _refreshHealthRecordCache(expectedGeneration: generation);
        return received;
      }
      if (next.isEmpty || !cursors.add(next)) {
        throw const ApiException(
          'Cloud health history could not be completed.',
          code: 'INVALID_HEALTH_CURSOR',
        );
      }
      before = next;
    }
    throw const ApiException(
      'Cloud health history is larger than this device can load at once.',
      code: 'HEALTH_HISTORY_LIMIT',
    );
  }

  Future<void> _drainCloudSync() async {
    final active = _activeCloudSync;
    if (active == null) return;
    try {
      await active;
    } catch (_) {
      // Account switching must proceed after a failed upload as well.
    }
  }

  Future<void> refreshCare() async {
    final generation = _sessionGeneration;
    if (session == null) {
      careMembers = const [];
      careStatus = '请先登录';
      careErrorMessage = null;
      notifyListeners();
      return;
    }
    careStatus = '加载中';
    careErrorMessage = null;
    notifyListeners();
    try {
      final sourceMembers = await _api.getCareMembers();
      if (!_isCurrentSessionGeneration(generation)) return;
      careMembers = _careMembersWithoutCurrentAccount(sourceMembers);
      careStatus = '已加载';
      if (kDebugMode) {
        debugPrint(
          'Care members refreshed: source=${sourceMembers.length}, '
          'visible=${careMembers.length}, signedInMemberId='
          '${session?.memberId.trim().isNotEmpty == true ? 'set' : 'empty'}',
        );
      }
    } on ApiException catch (error) {
      if (!_isCurrentSessionGeneration(generation)) return;
      careErrorMessage = _apiErrorMessage(error, fallback: '关爱数据暂时无法读取');
      errorMessage = careErrorMessage;
      careStatus = error is FeatureNotConfiguredException ? '服务暂不可用' : '加载失败';
      if (kDebugMode) {
        debugPrint(
          'Care members refresh failed: status=${error.statusCode ?? 'none'}, '
          'code=${error.code ?? 'none'}',
        );
      }
    }
    if (_isCurrentSessionGeneration(generation)) notifyListeners();
  }

  Future<void> refreshCareInvitations() {
    final active = _careInvitationRefresh;
    if (active != null) return active;
    final operation = _refreshCareInvitationsNow();
    _careInvitationRefresh = operation;
    return operation.whenComplete(() {
      if (identical(_careInvitationRefresh, operation)) {
        _careInvitationRefresh = null;
      }
    });
  }

  Future<void> _refreshCareInvitationsNow() async {
    final generation = _sessionGeneration;
    if (session == null) {
      careInvitations = const [];
      careInvitationStatus = '请先登录';
      notifyListeners();
      return;
    }
    final previousPendingIds = pendingCareInvitations
        .map(_careInvitationId)
        .where((id) => id != null)
        .cast<String>()
        .toSet();
    final careApi = _api is SaydianCareApi ? _api as SaydianCareApi : null;
    if (careApi == null) {
      careInvitationStatus = '服务暂不可用';
      notifyListeners();
      return;
    }
    try {
      final fetched = await careApi.getCareInvitations();
      if (!_isCurrentSessionGeneration(generation)) return;
      careInvitations = fetched;
      careInvitationStatus = pendingCareInvitations.isEmpty ? '暂无待处理' : '已加载';
      await _reconcileCareInvitationEvents(
        pendingCareInvitations
            .map(_careInvitationId)
            .whereType<String>()
            .toSet(),
        previouslyPendingIds: previousPendingIds,
        processedIds: careInvitations
            .where((invitation) {
              final status =
                  '${invitation['examine_status'] ?? invitation['examineStatus'] ?? ''}'
                      .trim();
              return status == '1' || status == '2';
            })
            .map(_careInvitationId)
            .whereType<String>()
            .toSet(),
        expectedGeneration: generation,
      );
      await _ingestNewCareInvitations(
        previousPendingIds,
        expectedGeneration: generation,
      );
      _careInvitationPollBackoffIndex = 0;
    } on ApiException catch (error) {
      if (!_isCurrentSessionGeneration(generation)) return;
      careInvitationStatus = _apiErrorMessage(error, fallback: '关爱邀请暂时无法读取');
      _careInvitationPollBackoffIndex = (_careInvitationPollBackoffIndex + 1)
          .clamp(0, 3);
    }
    if (_isCurrentSessionGeneration(generation)) notifyListeners();
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
    await markNotificationEventRead('care-invitation-$id');
    await refreshCareInvitations();
    await refreshCare();
  });

  int get careShareSessionGeneration => _sessionGeneration;

  bool isCareShareSessionCurrent(int generation) =>
      _isCurrentSessionGeneration(generation) &&
      !_accountTransitioning &&
      session != null;

  Future<Set<String>> loadCareShareSettings({
    required int memberId,
    int type = 0,
  }) async {
    final generation = _sessionGeneration;
    if (!isCareShareSessionCurrent(generation)) {
      throw const ApiException('账号已变化，请重新查看', code: 'STALE_CARE_SESSION');
    }
    final careApi = _api is SaydianCareApi ? _api as SaydianCareApi : null;
    if (careApi == null) {
      throw const FeatureNotConfiguredException('共享设置暂时无法使用，请稍后再试');
    }
    try {
      final values = await careApi.getCareShareSettings(
        type: type,
        memberId: memberId,
      );
      if (!isCareShareSessionCurrent(generation)) {
        throw const ApiException('账号已变化，请重新查看', code: 'STALE_CARE_SESSION');
      }
      return values;
    } catch (_) {
      if (!isCareShareSessionCurrent(generation)) {
        throw const ApiException('账号已变化，请重新查看', code: 'STALE_CARE_SESSION');
      }
      rethrow;
    }
  }

  Future<bool> saveCareShareSettings({
    required int memberId,
    required Set<String> settings,
    int type = 0,
  }) async {
    final generation = _sessionGeneration;
    if (!isCareShareSessionCurrent(generation) ||
        _careShareSaveGeneration == generation) {
      return false;
    }
    final submitted = Set<String>.unmodifiable(settings);
    _careShareSaveGeneration = generation;
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final careApi = _api is SaydianCareApi ? _api as SaydianCareApi : null;
      if (careApi == null) {
        throw const FeatureNotConfiguredException('共享设置暂时无法使用，请稍后再试');
      }
      await careApi.saveCareShareSettings(
        type: type,
        memberId: memberId,
        settings: submitted,
      );
      return isCareShareSessionCurrent(generation);
    } catch (error) {
      if (isCareShareSessionCurrent(generation)) {
        errorMessage = error is ApiException
            ? _apiErrorMessage(error, fallback: '保存未确认，请重新读取后重试')
            : '保存未确认，请重新读取后重试';
      }
      return false;
    } finally {
      if (isCareShareSessionCurrent(generation) &&
          _careShareSaveGeneration == generation) {
        _careShareSaveGeneration = null;
        isBusy = false;
        notifyListeners();
      }
    }
  }

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
    final generation = _sessionGeneration;
    if (session == null) {
      memberProfile = const {};
      notifyListeners();
      return;
    }
    try {
      final profile = await _api.getMemberProfile();
      if (!_isCurrentSessionGeneration(generation)) return;
      memberProfile = profile;
    } on ApiException catch (error) {
      if (!_isCurrentSessionGeneration(generation)) return;
      errorMessage = _apiErrorMessage(error, fallback: '个人资料暂时无法读取');
    }
    if (_isCurrentSessionGeneration(generation)) notifyListeners();
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
      errorMessage = '头像暂时无法上传，请稍后重试';
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
    final generation = _sessionGeneration;
    if (session == null) return;
    try {
      final goals = await _api.getActivityGoals();
      if (!_isCurrentSessionGeneration(generation)) return;
      stepGoal = num.tryParse('${goals['steps'] ?? ''}')?.toInt() ?? stepGoal;
      distanceGoal =
          num.tryParse('${goals['juli'] ?? ''}')?.toDouble() ?? distanceGoal;
      calorieGoal =
          num.tryParse('${goals['reliang'] ?? ''}')?.toInt() ?? calorieGoal;
    } on ApiException catch (error) {
      if (!_isCurrentSessionGeneration(generation)) return;
      errorMessage = _apiErrorMessage(error, fallback: '目标暂时无法读取');
    }
    if (_isCurrentSessionGeneration(generation)) notifyListeners();
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

  Future<bool> shouldExplainNotificationPermission() async {
    if (!notificationServiceConfigured ||
        session == null ||
        !_privacyConsentGranted) {
      return false;
    }
    return _notificationService.shouldExplainPermission();
  }

  Future<void> markNotificationPermissionExplanationShown() =>
      _notificationService.markPermissionExplanationShown();

  Future<void> requestNotificationPermission() async {
    if (session == null) return;
    if (!_privacyConsentGranted) {
      errorMessage = '请先阅读并同意用户协议与隐私政策';
      if (!_disposed) notifyListeners();
      return;
    }
    await _notificationService.activateAfterPrivacyConsent();
    await _notificationService.requestPermission();
    notificationPermissionEnabled = await _notificationService
        .isPermissionEnabled();
    if (notificationPermissionEnabled) {
      unawaited(_registerPushDevice(resetBackoff: true));
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> openNotificationSettings() =>
      _notificationService.openSettings();

  void setAppForeground(bool foreground) {
    _appIsForeground = foreground;
    if (!foreground) {
      _careInvitationPollTimer?.cancel();
      dismissCareInvitationAlert();
      return;
    }
    _scheduleCareInvitationPoll(const Duration(seconds: 30));
  }

  Future<void> handleAppResumed() async {
    if (_disposed) return;
    _appIsForeground = true;
    if (session != null && _privacyConsentGranted) {
      try {
        await _notificationService.activateAfterPrivacyConsent();
        notificationPermissionEnabled = await _notificationService
            .isPermissionEnabled();
      } catch (_) {
        notificationPermissionEnabled = false;
      }
    } else {
      notificationPermissionEnabled = false;
    }
    final operations = <Future<void>>[restoreWearableConnection()];
    if (session != null) {
      operations.addAll([
        refreshCareInvitations(),
        _refreshRemoteNotificationUnreadCount(),
      ]);
      unawaited(_registerPushDevice(resetBackoff: true));
    }
    await Future.wait(operations);
    _scheduleCareInvitationPoll(const Duration(seconds: 30));
    if (!_disposed) notifyListeners();
  }

  NotificationRouteIntent? consumePendingNotificationRoute() {
    if (session == null) return null;
    final value = pendingNotificationRoute;
    if (value == null) return null;
    pendingNotificationRoute = null;
    notifyListeners();
    return value;
  }

  void dismissCareInvitationAlert() {
    if (activeCareInvitationAlert == null) return;
    activeCareInvitationAlert = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> openCareInvitationAlert() async {
    final event = activeCareInvitationAlert;
    if (session == null || event == null) return;
    final generation = _sessionGeneration;
    await markNotificationEventRead(event.eventId);
    if (!_isCurrentSessionGeneration(generation)) return;
    pendingNotificationRoute = const NotificationRouteService().resolve(event);
    notifyListeners();
  }

  Future<void> markNotificationEventRead(String eventId) async {
    if (!_notificationStorageReady) return;
    final generation = _sessionGeneration;
    final inbox = _notificationInboxService;
    final remoteEventId = notificationInboxEvents
        .where((event) => event.eventId == eventId)
        .map((event) => event.remoteEventId)
        .whereType<String>()
        .firstOrNull;
    await inbox.markRead(eventId);
    if (!_isCurrentSessionGeneration(generation)) return;
    await _refreshNotificationInboxState();
    unawaited(
      _markRemoteNotificationEventReadBestEffort(
        remoteEventId ?? eventId,
        expectedGeneration: generation,
      ),
    );
  }

  Future<void> markAllHealthWarningsRead() async {
    if (!_notificationStorageReady) return;
    final generation = _sessionGeneration;
    final unread = notificationInboxEvents
        .where(
          (event) =>
              event.type == NotificationEventType.healthWarning &&
              !event.isRead,
        )
        .toList(growable: false);
    for (final event in unread) {
      await _notificationInboxService.markRead(event.eventId);
      if (event.source != NotificationEventSource.device) {
        unawaited(
          _markRemoteNotificationEventReadBestEffort(
            event.remoteEventId ?? event.eventId,
            expectedGeneration: generation,
          ),
        );
      }
    }
    await _refreshNotificationInboxState();
  }

  Future<void> _registerPushDevice({bool resetBackoff = false}) {
    final generation = _sessionGeneration;
    if (resetBackoff) _resetPushRegistrationBackoff();
    final active = _pushRegistration;
    if (active != null && _pushRegistrationGeneration == generation) {
      return active;
    }
    final operation = _registerPushDeviceNow(generation);
    _pushRegistration = operation;
    _pushRegistrationGeneration = generation;
    return operation.whenComplete(() {
      if (identical(_pushRegistration, operation)) {
        _pushRegistration = null;
        _pushRegistrationGeneration = null;
      }
    });
  }

  Future<void> _registerPushDeviceNow(int generation) async {
    final notificationApi = _api is SaydianNotificationApi
        ? _api as SaydianNotificationApi
        : null;
    if (session == null ||
        !_privacyConsentGranted ||
        !_notificationService.isActivated) {
      return;
    }
    if (notificationApi == null || !_notificationService.isConfigured) {
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.unavailable,
        generation: generation,
        issueCode: notificationApi == null
            ? 'api_not_supported'
            : 'client_not_configured',
        log: true,
      );
      return;
    }
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => null,
    };
    if (platform == null) {
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.unavailable,
        generation: generation,
        issueCode: 'platform_not_supported',
        log: true,
      );
      return;
    }
    try {
      final priorInstallationUnbound = await _retryPendingPushUnregister(
        notificationApi,
        generation,
      );
      if (!_isCurrentSessionGeneration(generation)) return;
      if (!priorInstallationUnbound) {
        // Do not register the same installation/RID to a new account while an
        // older account association may still exist. The server contract does
        // not guarantee that POST atomically replaces every prior owner.
        _schedulePushRegistrationRetry(
          generation,
          issueCode: 'prior_unbind_pending',
        );
        return;
      }
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.waitingForRegistrationId,
        generation: generation,
      );
      final registrationId = await _notificationService.registrationId();
      if (!_isCurrentSessionGeneration(generation)) return;
      if (registrationId == null || registrationId.trim().isEmpty) {
        _schedulePushRegistrationRetry(
          generation,
          issueCode: 'registration_id_pending',
        );
        return;
      }
      final package = await PackageInfo.fromPlatform();
      if (!_isCurrentSessionGeneration(generation)) return;
      final installationId = await _notificationService.installationId();
      if (!_isCurrentSessionGeneration(generation)) return;
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.registering,
        generation: generation,
      );
      final registered = await notificationApi.registerPushDevice(
        installationId: installationId,
        registrationId: registrationId,
        platform: platform,
        appVersion: package.version,
        buildNumber: int.tryParse(package.buildNumber),
      );
      if (!_isCurrentSessionGeneration(generation)) return;
      if (!registered) {
        _schedulePushRegistrationRetry(
          generation,
          issueCode: 'server_rejected',
        );
        return;
      }
      final pending = await _vault.readPendingPushUnregisterInstallationId();
      if (!_isCurrentSessionGeneration(generation)) return;
      if (pending == installationId) {
        await _vault.clearPendingPushUnregisterInstallationId();
      }
      _resetPushRegistrationBackoff();
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.registered,
        generation: generation,
      );
    } on ApiException {
      _schedulePushRegistrationRetry(generation, issueCode: 'api_error');
    } on PlatformException {
      _schedulePushRegistrationRetry(generation, issueCode: 'platform_error');
    } on TimeoutException {
      _schedulePushRegistrationRetry(generation, issueCode: 'timeout');
    } catch (_) {
      _schedulePushRegistrationRetry(generation, issueCode: 'unexpected_error');
    }
  }

  void _resetPushRegistrationBackoff() {
    _pushRegistrationRetryTimer?.cancel();
    _pushRegistrationRetryTimer = null;
    _pushRegistrationRetryAttempt = 0;
    pushDeviceRegistrationRetryDelay = null;
  }

  void _schedulePushRegistrationRetry(
    int generation, {
    required String issueCode,
  }) {
    if (_disposed ||
        !_isCurrentSessionGeneration(generation) ||
        session == null ||
        !_privacyConsentGranted) {
      return;
    }
    if (_pushRegistrationRetryTimer?.isActive ?? false) return;
    if (_pushRegistrationRetryAttempt >= _pushRegistrationRetryDelays.length) {
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.failed,
        generation: generation,
        issueCode: issueCode,
        log: true,
      );
      return;
    }
    final configuredDelay =
        _pushRegistrationRetryDelays[_pushRegistrationRetryAttempt];
    final delay = configuredDelay.isNegative ? Duration.zero : configuredDelay;
    _pushRegistrationRetryAttempt++;
    _setPushDeviceRegistrationState(
      PushDeviceRegistrationState.retryScheduled,
      generation: generation,
      issueCode: issueCode,
      retryDelay: delay,
      log: true,
    );
    _pushRegistrationRetryTimer = Timer(delay, () {
      _pushRegistrationRetryTimer = null;
      if (_disposed || !_isCurrentSessionGeneration(generation)) return;
      unawaited(_registerPushDevice());
    });
  }

  void _setPushDeviceRegistrationState(
    PushDeviceRegistrationState state, {
    int? generation,
    String? issueCode,
    Duration? retryDelay,
    bool log = false,
  }) {
    if (generation != null && !_isCurrentSessionGeneration(generation)) return;
    pushDeviceRegistrationState = state;
    pushDeviceRegistrationIssueCode = issueCode;
    pushDeviceRegistrationRetryDelay = retryDelay;
    if (log) {
      debugPrint(
        '[push-device] state=${state.name} '
        'issue=${issueCode ?? 'none'} '
        'attempt=$_pushRegistrationRetryAttempt '
        'retry_ms=${retryDelay?.inMilliseconds ?? 0}',
      );
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _unregisterPushDevice() async {
    final notificationApi = _api is SaydianNotificationApi
        ? _api as SaydianNotificationApi
        : null;
    if (!_notificationService.isConfigured) {
      _setPushDeviceRegistrationState(PushDeviceRegistrationState.unregistered);
      return;
    }
    if (notificationApi == null) {
      try {
        final installationId = await _notificationService.installationId();
        await _vault.writePendingPushUnregisterInstallationId(installationId);
      } catch (_) {
        // The state below remains observable without exposing identifiers.
      }
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.unregisterRetryPending,
        issueCode: 'api_not_supported',
        log: true,
      );
      return;
    }
    try {
      final installationId = await _notificationService.installationId();
      await _vault.writePendingPushUnregisterInstallationId(installationId);
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.unregistering,
      );
      final removed = await notificationApi.unregisterPushDevice(
        installationId: installationId,
      );
      if (removed) {
        await _vault.clearPendingPushUnregisterInstallationId();
        _setPushDeviceRegistrationState(
          PushDeviceRegistrationState.unregistered,
        );
      } else {
        _setPushDeviceRegistrationState(
          PushDeviceRegistrationState.unregisterRetryPending,
          issueCode: 'server_rejected',
          log: true,
        );
      }
    } on ApiException {
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.unregisterRetryPending,
        issueCode: 'api_error',
        log: true,
      );
    } on PlatformException {
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.unregisterRetryPending,
        issueCode: 'platform_error',
        log: true,
      );
    } catch (_) {
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.unregisterRetryPending,
        issueCode: 'unexpected_error',
        log: true,
      );
    }
  }

  Future<bool> _retryPendingPushUnregister(
    SaydianNotificationApi notificationApi,
    int generation,
  ) async {
    final installationId = await _vault
        .readPendingPushUnregisterInstallationId();
    if (!_isCurrentSessionGeneration(generation)) return false;
    if (installationId == null) return true;
    try {
      final removed = await notificationApi.unregisterPushDevice(
        installationId: installationId,
      );
      if (!_isCurrentSessionGeneration(generation)) return false;
      if (removed &&
          await _vault.readPendingPushUnregisterInstallationId() ==
              installationId &&
          _isCurrentSessionGeneration(generation)) {
        await _vault.clearPendingPushUnregisterInstallationId();
        return true;
      }
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.unregisterRetryPending,
        generation: generation,
        issueCode: 'server_rejected',
        log: true,
      );
    } on ApiException {
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.unregisterRetryPending,
        generation: generation,
        issueCode: 'api_error',
        log: true,
      );
    } catch (_) {
      _setPushDeviceRegistrationState(
        PushDeviceRegistrationState.unregisterRetryPending,
        generation: generation,
        issueCode: 'unexpected_error',
        log: true,
      );
    }
    return false;
  }

  Future<void> _markRemoteNotificationEventReadBestEffort(
    String eventId, {
    int? expectedGeneration,
  }) async {
    final generation = expectedGeneration ?? _sessionGeneration;
    final notificationApi = _api is SaydianNotificationApi
        ? _api as SaydianNotificationApi
        : null;
    if (session == null ||
        notificationApi == null ||
        !_isCurrentSessionGeneration(generation)) {
      return;
    }
    try {
      final marked = await notificationApi.markNotificationEventRead(
        eventId: eventId,
      );
      if (marked && _isCurrentSessionGeneration(generation)) {
        await _refreshRemoteNotificationUnreadCount();
      }
    } on ApiException {
      // The optional stable event-id endpoint may not be deployed yet.
    } catch (_) {
      // Local read state and navigation must not be blocked by the server.
    }
  }

  Future<void> _refreshRemoteNotificationUnreadCount() async {
    final generation = _sessionGeneration;
    final repository = _notificationInboxRepository;
    final notificationApi = _api is SaydianNotificationApi
        ? _api as SaydianNotificationApi
        : null;
    if (session == null || notificationApi == null) {
      remoteNotificationUnreadCount = null;
      await _refreshNotificationInboxState();
      return;
    }
    try {
      final unreadCount = await notificationApi.getNotificationUnreadCount();
      if (!_isCurrentSessionGeneration(generation) ||
          !identical(repository, _notificationInboxRepository)) {
        return;
      }
      remoteNotificationUnreadCount = unreadCount;
      if (remoteNotificationUnreadCount == 0 && _notificationStorageReady) {
        final readAt = DateTime.now().toUtc();
        for (final event in await repository.list()) {
          if (!_isCurrentSessionGeneration(generation) ||
              !identical(repository, _notificationInboxRepository)) {
            return;
          }
          // The legacy unread endpoint does not include care invitations.
          // Only an explicit read or the invitation's real status may clear
          // those events; an aggregate zero is not an acknowledgement.
          if (event.source != NotificationEventSource.device &&
              event.type != NotificationEventType.careInvitation &&
              !event.isRead) {
            await repository.markRead(eventId: event.eventId, readAt: readAt);
          }
        }
      }
    } on ApiException {
      if (!_isCurrentSessionGeneration(generation)) return;
      remoteNotificationUnreadCount = null;
    }
    if (!_isCurrentSessionGeneration(generation)) return;
    await _refreshNotificationInboxState();
  }

  Future<void> _refreshNotificationInboxState() async {
    final generation = _sessionGeneration;
    if (!_notificationStorageReady) {
      notificationInboxEvents = const [];
      notificationUnreadCount = remoteNotificationUnreadCount ?? 0;
      return;
    }
    final repository = _notificationInboxRepository;
    final events = await repository.list();
    if (!_isCurrentSessionGeneration(generation) ||
        !identical(repository, _notificationInboxRepository)) {
      return;
    }
    notificationInboxEvents = events;
    final activeCareEventId = activeCareInvitationAlert?.eventId;
    if (activeCareEventId != null &&
        !events.any(
          (event) => event.eventId == activeCareEventId && !event.isRead,
        )) {
      activeCareInvitationAlert = null;
    }
    final localDeviceHealthUnread = notificationInboxEvents
        .where(
          (event) =>
              event.type == NotificationEventType.healthWarning &&
              event.source == NotificationEventSource.device &&
              !event.isRead,
        )
        .length;
    final localServerMirrorUnread = notificationInboxEvents
        .where(
          (event) =>
              event.source != NotificationEventSource.device && !event.isRead,
        )
        .length;
    final remoteUnread = remoteNotificationUnreadCount;
    // Aggregate counts have no IDs with which to calculate an exact union.
    // Keep known unread events as a floor, without summing duplicate mirrors.
    final serverUnread =
        remoteUnread == null || remoteUnread < localServerMirrorUnread
        ? localServerMirrorUnread
        : remoteUnread;
    notificationUnreadCount = localDeviceHealthUnread + serverUnread;
    unawaited(_notificationService.setBadge(notificationUnreadCount));
    if (!_disposed) notifyListeners();
  }

  Future<NotificationEvent?> _ingestNotificationPayload(
    Map<String, Object?> payload, {
    bool showLocalNotification = false,
    int? expectedGeneration,
  }) {
    final generation = expectedGeneration ?? _sessionGeneration;
    final completer = Completer<NotificationEvent?>();
    _notificationIngestTail = _notificationIngestTail.then((_) async {
      try {
        completer.complete(
          await _ingestNotificationPayloadNow(
            payload,
            showLocalNotification: showLocalNotification,
            expectedGeneration: generation,
          ),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<NotificationEvent?> _ingestNotificationPayloadNow(
    Map<String, Object?> payload, {
    required bool showLocalNotification,
    required int expectedGeneration,
  }) async {
    if (!_notificationStorageReady ||
        !_isCurrentSessionGeneration(expectedGeneration) ||
        session == null) {
      return null;
    }
    final repository = _notificationInboxRepository;
    final inbox = _notificationInboxService;
    final before = await repository.list();
    if (!_isCurrentSessionGeneration(expectedGeneration) ||
        !identical(repository, _notificationInboxRepository)) {
      return null;
    }
    final event = await inbox.ingest(payload);
    if (!_isCurrentSessionGeneration(expectedGeneration) ||
        !identical(repository, _notificationInboxRepository)) {
      return null;
    }
    if (event == null) return null;
    final isNew = !before.any((item) => item.eventId == event.eventId);
    if (isNew && event.source != NotificationEventSource.device) {
      // A newly delivered server event is newer than the last unread-count
      // snapshot. Fall back to the local mirror until the next successful
      // authoritative refresh, otherwise a cached zero would hide the badge.
      remoteNotificationUnreadCount = null;
    }
    if (isNew &&
        _appIsForeground &&
        !event.isRead &&
        event.type == NotificationEventType.careInvitation) {
      activeCareInvitationAlert = event;
    }
    await _refreshNotificationInboxState();
    if (!_isCurrentSessionGeneration(expectedGeneration)) return null;
    if (isNew && showLocalNotification) {
      final entityId = event.entityId ?? event.eventId;
      switch (event.type) {
        case NotificationEventType.healthWarning:
          await _notificationService.showHealthWarning(
            eventId: event.eventId,
            entityId: entityId,
            createdAt: event.createdAt,
            unreadCount: notificationUnreadCount,
          );
        case NotificationEventType.careInvitation:
          await _notificationService.showCareInvitation(
            eventId: event.eventId,
            entityId: entityId,
            createdAt: event.createdAt,
            unreadCount: notificationUnreadCount,
          );
        case NotificationEventType.system:
          break;
      }
    }
    return event;
  }

  Future<void> _handleNotificationPayload(
    Map<String, Object?> payload, {
    bool opened = false,
  }) async {
    final generation = _sessionGeneration;
    final normalizedPayload = Map<String, Object?>.from(payload);
    if ('${normalizedPayload['event_id'] ?? ''}'.trim().isEmpty) return;
    final parsed = NotificationEvent.tryParse(normalizedPayload);
    if (kDebugMode) {
      debugPrint(
        '[push-route] opened=$opened parsed=${parsed != null} '
        'authenticated=${session != null}',
      );
    }
    if (parsed != null &&
        parsed.type == NotificationEventType.careInvitation &&
        parsed.entityId != null) {
      normalizedPayload['remote_event_id'] = parsed.eventId;
      normalizedPayload['event_id'] = 'care-invitation-${parsed.entityId}';
    }
    if (session == null) {
      if (opened && parsed != null) {
        pendingNotificationRoute = _notificationRouteService.resolve(parsed);
        if (!_disposed) notifyListeners();
      }
      return;
    }
    final deliveryKind = '${normalizedPayload['_delivery_kind'] ?? ''}'
        .trim()
        .toLowerCase();
    final systemAlreadyPresented =
        switch (normalizedPayload['_system_already_presented']) {
          true => true,
          final num value => value.toInt() == 1,
          final String value =>
            value.trim().toLowerCase() == 'true' || value == '1',
          _ => false,
        };
    final event = await _ingestNotificationPayload(
      normalizedPayload,
      showLocalNotification:
          !opened && deliveryKind == 'data' && !systemAlreadyPresented,
      expectedGeneration: generation,
    );
    if (event == null || !_isCurrentSessionGeneration(generation)) return;
    if (opened) {
      await _notificationInboxService.markRead(event.eventId);
      if (!_isCurrentSessionGeneration(generation)) return;
      pendingNotificationRoute = _notificationRouteService.resolve(event);
      await _refreshNotificationInboxState();
      unawaited(
        _markRemoteNotificationEventReadBestEffort(
          parsed?.eventId ?? event.eventId,
          expectedGeneration: generation,
        ),
      );
      if (!_disposed) notifyListeners();
    }
    if (event.type == NotificationEventType.careInvitation) {
      unawaited(refreshCareInvitations());
    }
  }

  Future<void> _ingestNewCareInvitations(
    Set<String> previousIds, {
    required int expectedGeneration,
  }) async {
    if (!_isCurrentSessionGeneration(expectedGeneration)) return;
    for (final invitation in pendingCareInvitations) {
      if (!_isCurrentSessionGeneration(expectedGeneration)) return;
      final id = _careInvitationId(invitation);
      if (id == null || previousIds.contains(id)) continue;
      await _ingestNotificationPayload(
        <String, Object?>{
          'schema_version': NotificationEvent.schemaVersion,
          'event_id': 'care-invitation-$id',
          'event_type': NotificationEventType.careInvitation.wireName,
          'entity_id': id,
          'source': NotificationEventSource.polling.wireName,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        showLocalNotification: true,
        expectedGeneration: expectedGeneration,
      );
    }
  }

  Future<void> _reconcileCareInvitationEvents(
    Set<String> pendingIds, {
    required Set<String> previouslyPendingIds,
    required Set<String> processedIds,
    required int expectedGeneration,
  }) async {
    if (!_notificationStorageReady ||
        !_isCurrentSessionGeneration(expectedGeneration)) {
      return;
    }
    final repository = _notificationInboxRepository;
    final readAt = DateTime.now().toUtc();
    var changed = false;
    for (final event in await repository.list()) {
      if (!_isCurrentSessionGeneration(expectedGeneration) ||
          !identical(repository, _notificationInboxRepository)) {
        return;
      }
      if (event.type != NotificationEventType.careInvitation ||
          event.isRead ||
          event.entityId == null ||
          (!previouslyPendingIds.contains(event.entityId) &&
              !processedIds.contains(event.entityId)) ||
          (event.entityId != null && pendingIds.contains(event.entityId))) {
        continue;
      }
      await repository.markRead(eventId: event.eventId, readAt: readAt);
      changed = true;
    }
    if (changed) await _refreshNotificationInboxState();
  }

  void _scheduleCareInvitationPoll([Duration? delay]) {
    _careInvitationPollTimer?.cancel();
    if (_disposed || !_appIsForeground || session == null) return;
    const delays = <Duration>[
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(seconds: 120),
      Duration(seconds: 300),
    ];
    final nextDelay = delay ?? delays[_careInvitationPollBackoffIndex];
    _careInvitationPollTimer = Timer(nextDelay, () async {
      if (_disposed || !_appIsForeground || session == null) return;
      try {
        await refreshCareInvitations();
        await _refreshRemoteNotificationUnreadCount();
      } finally {
        _scheduleCareInvitationPoll();
      }
    });
  }

  Future<void> refreshNotifications() async {
    await refreshNotificationHistory();
    await _refreshRemoteNotificationUnreadCount();
    await _refreshNotificationInboxState();
  }

  Future<void> refreshNotificationHistory({bool allPages = false}) async {
    final generation = _sessionGeneration;
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
        final fetched = await _api.getNotifications();
        if (!_isCurrentSessionGeneration(generation)) return;
        notifications = fetched;
      } else {
        final merged = <Map<String, Object?>>[];
        final seen = <String>{};
        for (var page = 1; page <= 100; page++) {
          final values = await _api.getNotifications(page: page);
          if (!_isCurrentSessionGeneration(generation)) return;
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
        if (!_isCurrentSessionGeneration(generation)) return;
        notifications = merged;
      }
      notificationStatus = notifications.isEmpty ? '暂无消息' : '已加载';
    } on ApiException catch (error) {
      if (!_isCurrentSessionGeneration(generation)) return;
      notificationStatus = _apiErrorMessage(error, fallback: '消息暂时无法加载');
    }
    if (_isCurrentSessionGeneration(generation)) notifyListeners();
  }

  Future<Map<String, Object?>> loadNotification(int id) async {
    Map<String, Object?> value;
    try {
      value = await _api.getNotification(id);
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error, fallback: '消息暂时无法加载');
      notifyListeners();
      return const {};
    }
    final notificationApi = _api is SaydianNotificationApi
        ? _api as SaydianNotificationApi
        : null;
    if (notificationApi != null && id > 0) {
      try {
        await notificationApi.markNotificationRead(id: id);
        await _refreshRemoteNotificationUnreadCount();
      } on ApiException {
        // The detail remains usable if the optional read endpoint is absent.
      }
    }
    return value;
  }

  Future<Map<String, Object?>> loadCareMemberPreview(
    int id, {
    DateTime? day,
    int? memberId,
  }) async {
    final generation = _sessionGeneration;
    if (_accountTransitioning) return const {};
    try {
      final value = await _api.getCareMemberPreview(
        id: id,
        day: formatCareCalendarDay(day),
        memberId: memberId,
      );
      if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
        return const {};
      }
      return value;
    } on ApiException catch (error) {
      if (!_isCurrentSessionGeneration(generation) ||
          _accountTransitioning ||
          error.code == 'STALE_CARE_SESSION') {
        return const {};
      }
      final message = _apiErrorMessage(error, fallback: '对方数据暂时无法读取');
      errorMessage = message;
      notifyListeners();
      return <String, Object?>{'loadError': message};
    }
  }

  Future<void> refreshAiMessages({required int app}) async {
    final generation = _sessionGeneration;
    final owner = session;
    await Future<void>.delayed(Duration.zero);
    if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
      return;
    }
    if (session == null) {
      aiMessages = const [];
      errorMessage = '请先登录后使用 AI 管家';
      notifyListeners();
      return;
    }
    errorMessage = null;
    try {
      final messages = await _api.getAiMessages(app: app);
      if (!_isCurrentAccountRequest(generation, owner)) return;
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
      if (!_isCurrentAccountRequest(generation, owner)) return;
      errorMessage = _apiErrorMessage(error, fallback: '暂时无法开始对话');
    }
    notifyListeners();
  }

  Future<bool> sendAiMessage({
    required int app,
    required String message,
  }) async {
    final normalized = message.trim();
    if (normalized.isEmpty || _accountTransitioning || isBusy) return false;
    final generation = _sessionGeneration;
    final owner = session;
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
      if (!_isCurrentAccountRequest(generation, owner)) return false;
      aiMessages = [...aiMessages, reply];
      final sessionValue = reply['session_id']?.toString();
      if (sessionValue?.isNotEmpty ?? false) _aiSessionIds[app] = sessionValue!;
      return true;
    } on ApiException catch (error) {
      if (!_isCurrentAccountRequest(generation, owner)) return false;
      errorMessage = _apiErrorMessage(error, fallback: '消息发送失败，请稍后重试');
      aiMessages = [
        ...aiMessages.take(aiMessages.length - 1),
        <String, Object?>{...aiMessages.last, 'send_failed': true},
      ];
      return false;
    } finally {
      if (_isCurrentAccountRequest(generation, owner)) {
        isBusy = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentAccountRequest(int generation, Session? owner) =>
      _isCurrentSessionGeneration(generation) &&
      !_accountTransitioning &&
      owner != null &&
      session != null &&
      _healthOwnerFor(owner) == _healthOwnerFor(session);

  Future<void> loadOrders(int? status) async {
    final generation = _sessionGeneration;
    final owner = session;
    await Future<void>.delayed(Duration.zero);
    if (!_isCurrentSessionGeneration(generation) || _accountTransitioning) {
      return;
    }
    if (session == null) {
      orders = const [];
      orderStatus = '请先登录';
      notifyListeners();
      return;
    }
    orderStatus = '正在加载';
    notifyListeners();
    try {
      final loaded = await _api.getOrders(status: status);
      if (!_isCurrentAccountRequest(generation, owner)) return;
      orders = loaded;
      orderStatus = orders.isEmpty ? '暂无订单' : '已加载';
    } on ApiException catch (error) {
      if (!_isCurrentAccountRequest(generation, owner)) return;
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

  Future<AppPaymentResult?> startShopPayment({
    required AppPaymentProvider provider,
    required int orderId,
    required num money,
  }) async {
    if (session == null) {
      errorMessage = '请先登录后支付订单';
      notifyListeners();
      return null;
    }
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _requiredShopApi.createShopPayment(
        provider: provider.name,
        orderId: orderId,
        money: money,
      );
      if (provider == AppPaymentProvider.wechat) {
        final signed = AppPaymentPayloadParser.wechat(response);
        if (signed.isEmpty) throw const ApiException('微信支付信息不完整，请稍后重试');
        await _paymentBridge.startWechat(signed);
        return null;
      }
      final signedOrder = AppPaymentPayloadParser.alipay(response);
      if (signedOrder.isEmpty) {
        throw const ApiException('支付宝支付信息不完整，请稍后重试');
      }
      return await _paymentBridge.startAlipay(signedOrder);
    } on ApiException catch (error) {
      errorMessage = _shopPaymentErrorMessage(error);
      return null;
    } on PlatformException catch (error) {
      errorMessage = userFacingMessage(error.message, fallback: '暂时无法支付，请稍后重试');
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  String _shopPaymentErrorMessage(ApiException error) {
    final message = error.message.trim();
    final normalized = message.toLowerCase();
    if ((error.statusCode ?? 0) >= 500 ||
        normalized.contains('internal server error')) {
      return '支付服务暂不可用，请稍后重试';
    }
    if (message.contains('授权有误') || message.contains('配置')) {
      return '支付暂不可用，请稍后重试';
    }
    return _apiErrorMessage(error, fallback: '支付暂不可用，请稍后重试');
  }

  Future<AppPaymentResult?> takeWechatPaymentResult() async {
    try {
      return await _paymentBridge.takeWechatResult();
    } on PlatformException {
      return null;
    }
  }

  SaydianHealthReportApi get _requiredHealthReportApi {
    final api = _api;
    if (api is SaydianHealthReportApi) return api as SaydianHealthReportApi;
    throw const FeatureNotConfiguredException('健康档案暂时无法使用，请稍后再试');
  }

  String get _healthReportPlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  Future<HealthReportDashboard> loadHealthReportDashboard() async {
    if (session == null) throw const ApiException('请先登录后查看健康档案');
    final api = _requiredHealthReportApi;
    final profileFuture = api.getHealthProfile();
    final eligibilityFuture = api.getHealthReportEligibility();
    final entitlementFuture = api.getHealthReportEntitlements();
    final offersFuture = api.getHealthReportOffers(
      platform: _healthReportPlatform,
    );
    final reportsFuture = api.getHealthReports();
    return HealthReportDashboard(
      profile: await profileFuture,
      eligibility: await eligibilityFuture,
      entitlements: await entitlementFuture,
      offers: await offersFuture,
      reports: await reportsFuture,
    );
  }

  Future<void> setHealthAnalysisConsent(bool granted, {String? version}) async {
    if (session == null) throw const ApiException('请先登录后管理健康分析授权');
    if (isGlobalEdition &&
        granted &&
        (version == null || version.trim().isEmpty)) {
      throw const FeatureNotConfiguredException(
        'Health analysis is not available yet.',
      );
    }
    await _requiredHealthReportApi.setHealthAnalysisConsent(
      granted: granted,
      version: isGlobalEdition
          ? (granted ? version! : '')
          : 'health-ai-analysis-v1',
    );
  }

  Future<HealthReportSummary> createHealthReport() async {
    if (session == null) throw const ApiException('请先登录后生成健康报告');
    return _requiredHealthReportApi.createHealthReport();
  }

  Future<HealthReportSummary> retryHealthReport(String reportId) async {
    if (session == null) throw const ApiException('请先登录后重试健康报告');
    return _requiredHealthReportApi.retryHealthReport(reportId);
  }

  Future<Map<String, Object?>> loadFullHealthReport(String reportId) async {
    if (session == null) throw const ApiException('请先登录后查看健康报告');
    return _requiredHealthReportApi.getFullHealthReport(reportId);
  }

  Future<Uint8List> exportHealthReport(String reportId) async {
    if (session == null) throw const ApiException('请先登录后导出健康报告');
    return _requiredHealthReportApi.exportHealthReport(reportId);
  }

  Future<HealthPurchaseFlowResult> startHealthPurchase({
    required HealthReportOffer offer,
    required HealthReportSummary report,
    AppPaymentProvider? androidProvider,
  }) async {
    if (session == null) throw const ApiException('请先登录后购买健康报告');
    if (!report.needsPayment) {
      throw const ApiException('当前报告不需要购买');
    }
    final platform = _healthReportPlatform;
    final isApple = platform == 'ios';
    if (!isApple && androidProvider == null) {
      throw const ApiException('请选择支付方式');
    }
    final channel = isApple
        ? 'apple_iap'
        : androidProvider == AppPaymentProvider.wechat
        ? 'wechat_app'
        : 'alipay_app';
    final businessType = offer.isMembership
        ? 'health_membership'
        : 'health_report';
    final intent = await _requiredHealthReportApi.createHealthPayment(
      businessType: businessType,
      businessId: offer.isMembership ? '' : report.id,
      offerId: offer.id,
      channel: channel,
      platform: platform,
      idempotencyKey: 'health:${offer.id}:${report.id}:${const Uuid().v4()}',
    );
    if (isApple) return _startAppleHealthPurchase(intent);
    return _startAndroidHealthPurchase(intent, androidProvider!);
  }

  Future<HealthPurchaseFlowResult> _startAppleHealthPurchase(
    HealthPaymentIntent intent,
  ) async {
    final productId = '${intent.invoke['productId'] ?? ''}'.trim();
    final accountToken = '${intent.invoke['appAccountToken'] ?? ''}'.trim();
    if (productId.isEmpty || accountToken != intent.id) {
      throw const ApiException('苹果购买信息不完整，请稍后重试');
    }
    final transaction = await _storeKitPurchaseBridge.purchase(
      productId: productId,
      appAccountToken: accountToken,
    );
    switch (transaction.state) {
      case StoreKitPurchaseState.cancelled:
        return HealthPurchaseFlowResult(
          state: HealthPurchaseFlowState.cancelled,
          intent: intent,
          message: '已取消购买',
        );
      case StoreKitPurchaseState.pending:
        return HealthPurchaseFlowResult(
          state: HealthPurchaseFlowState.pendingApproval,
          intent: intent,
          message: '购买正在等待确认，确认后会自动更新',
        );
      case StoreKitPurchaseState.verified:
        if (transaction.appAccountToken != intent.id ||
            transaction.transactionId.isEmpty ||
            transaction.signedTransactionInfo.isEmpty) {
          throw const ApiException('苹果购买结果与当前订单不一致');
        }
        final verified = await _requiredHealthReportApi
            .verifyAppleHealthPayment(
              paymentIntentId: intent.id,
              signedTransactionInfo: transaction.signedTransactionInfo,
            );
        if (verified.status != HealthPaymentStatus.succeeded) {
          return HealthPurchaseFlowResult(
            state: HealthPurchaseFlowState.awaitingConfirmation,
            intent: verified,
            message: '购买结果正在确认，请稍后刷新',
          );
        }
        await _storeKitPurchaseBridge.finish(transaction.transactionId);
        return HealthPurchaseFlowResult(
          state: HealthPurchaseFlowState.succeeded,
          intent: verified,
          message: '购买成功，报告正在生成',
        );
    }
  }

  Future<HealthPurchaseFlowResult> _startAndroidHealthPurchase(
    HealthPaymentIntent intent,
    AppPaymentProvider provider,
  ) async {
    if (provider == AppPaymentProvider.wechat) {
      final signed = AppPaymentPayloadParser.wechat(intent.invoke);
      if (signed.isEmpty) throw const ApiException('微信支付信息不完整，请稍后重试');
      await _paymentBridge.startWechat(signed);
      return HealthPurchaseFlowResult(
        state: HealthPurchaseFlowState.awaitingConfirmation,
        intent: intent,
        message: '已打开微信，完成支付后返回查看结果',
      );
    }
    final signedOrder = AppPaymentPayloadParser.alipay(intent.invoke);
    if (signedOrder.isEmpty) {
      throw const ApiException('支付宝支付信息不完整，请稍后重试');
    }
    final result = await _paymentBridge.startAlipay(signedOrder);
    if (result.isCancelled) {
      return HealthPurchaseFlowResult(
        state: HealthPurchaseFlowState.cancelled,
        intent: intent,
        message: '已取消支付',
      );
    }
    return HealthPurchaseFlowResult(
      state: HealthPurchaseFlowState.awaitingConfirmation,
      intent: intent,
      message: result.isSuccess ? '支付结果正在确认' : '请确认支付结果后刷新',
    );
  }

  Future<HealthPaymentIntent> refreshHealthPayment(String paymentIntentId) {
    if (session == null) throw const ApiException('请先登录后查看支付结果');
    return _requiredHealthReportApi.getHealthPayment(paymentIntentId);
  }

  Future<int> restoreAppleHealthPurchases() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw const FeatureNotConfiguredException('当前设备无需恢复苹果购买');
    }
    if (session == null) throw const ApiException('请先登录后恢复购买');
    final transactions = await _storeKitPurchaseBridge.restorePurchases();
    var restored = 0;
    for (final transaction in transactions) {
      try {
        final intent = await _requiredHealthReportApi.verifyAppleHealthPayment(
          paymentIntentId: transaction.appAccountToken,
          signedTransactionInfo: transaction.signedTransactionInfo,
        );
        if (intent.status == HealthPaymentStatus.succeeded) {
          await _storeKitPurchaseBridge.finish(transaction.transactionId);
          restored++;
        }
      } on ApiException {
        // A transaction may belong to another app account. Keep it unfinished
        // and do not reveal account details; the matching account can restore it.
      }
    }
    return restored;
  }

  String healthReportErrorMessage(Object error) {
    if (error is ApiException) {
      return _apiErrorMessage(error, fallback: '健康档案暂时无法使用，请稍后重试');
    }
    if (error is PlatformException) {
      return switch (error.code) {
        'STOREKIT_CANCELLED' => '已取消购买',
        'STOREKIT_NOT_AVAILABLE' => '苹果购买暂时无法使用，请稍后再试',
        'STOREKIT_PRODUCT_UNAVAILABLE' => '当前购买方案暂时不可用，请刷新后重试',
        'STOREKIT_UNVERIFIED' => '购买结果验证失败，请使用恢复购买重试',
        _ =>
          error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : '支付暂时无法完成，请稍后重试',
      };
    }
    return '健康档案暂时无法使用，请稍后重试';
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
    final api = _api;
    if (session != null && api is SaydianShopCartApi) {
      shopCart = await (api as SaydianShopCartApi).addShopCartItem(
        skuId: skuId,
        quantity: quantity,
      );
      await _vault.writeShopCart(shopCart);
      notifyListeners();
      return;
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
    final api = _api;
    if (session != null && api is SaydianShopCartApi) {
      try {
        if (quantity <= 0) {
          shopCart = await (api as SaydianShopCartApi).deleteShopCartItems([
            skuId,
          ]);
        } else {
          final stock = _cartInt(next[index]['stock']) ?? quantity;
          final normalized = quantity.clamp(1, stock < 1 ? 1 : stock);
          shopCart = await (api as SaydianShopCartApi)
              .updateShopCartItemQuantity(skuId: skuId, quantity: normalized);
        }
        await _vault.writeShopCart(shopCart);
        notifyListeners();
        return;
      } on ApiException catch (error) {
        errorMessage = _apiErrorMessage(error, fallback: '购物车更新失败，请稍后重试');
        notifyListeners();
        return;
      }
    }
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
    final skuIds = shopCart
        .map((item) => _cartInt(item['sku_id']))
        .whereType<int>()
        .toSet();
    await removeShopCartItems(skuIds);
  }

  Future<void> removeShopCartItems(Iterable<int> skuIds) async {
    final selected = skuIds.toSet();
    if (selected.isEmpty) return;
    final api = _api;
    if (session != null && api is SaydianShopCartApi) {
      try {
        shopCart = await (api as SaydianShopCartApi).deleteShopCartItems(
          selected,
        );
        await _vault.writeShopCart(shopCart);
        notifyListeners();
        return;
      } on ApiException catch (error) {
        // An order created from the server cart consumes its rows. Keep the
        // successful order flow usable even if the follow-up delete reports
        // that those rows no longer exist.
        errorMessage = _apiErrorMessage(error, fallback: '购物车同步失败，请稍后刷新');
      }
    }
    shopCart = shopCart
        .where((item) => !selected.contains(_cartInt(item['sku_id'])))
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
    await _vault.writeShopCart(shopCart);
    notifyListeners();
  }

  Future<void> refreshShopCart() async {
    final api = _api;
    if (session == null || api is! SaydianShopCartApi) return;
    try {
      shopCart = await (api as SaydianShopCartApi).getShopCartItems();
      await _vault.writeShopCart(shopCart);
      notifyListeners();
    } on ApiException {
      // Preserve the cached cart while offline; checkout will surface a
      // concrete server error if the user continues.
    }
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
    return userFacingMessage(error.message, fallback: fallback);
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
      'ECG_RESULT_TIMEOUT',
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
      'BLE_PERMISSION_DENIED' => '允许相关权限后使用',
      'LOCATION_SERVICE_DISABLED' => '请开启手机定位后再查找戒指',
      'DEVICE_NOT_FOUND' => '戒指已离开搜索范围，请重新搜索',
      'NOT_CONNECTED' => '连接戒指后使用',
      'UNSUPPORTED_METRIC' ||
      'MEASUREMENT_NOT_AVAILABLE' ||
      'FEATURE_UNSUPPORTED' => '当前戒指不支持此功能',
      'FEATURE_UNAVAILABLE' ||
      'DEVICE_SETTINGS_NOT_CONFIGURED' ||
      'SPORT_NOT_CONFIGURED' => '请在戒指上操作',
      'SDK_NOT_CONFIGURED' => '此功能暂时无法使用，请稍后再试',
      'CONNECT_FAILED' || 'CONNECTION_DROPPED' => '连接失败，请确认戒指未连接其他手机后重试',
      'YUCHENG_SYNC_TIMEOUT' => '数据同步超时，可稍后重试',
      'NETWORK_ERROR' || 'NETWORK_UNAVAILABLE' => '网络不可用，请检查后重试',
      _ => null,
    };
    if (mappedMessage != null) return mappedMessage;
    if (nativeMessage != null && nativeMessage.isNotEmpty) {
      return userFacingMessage(nativeMessage, fallback: fallback);
    }
    return fallback;
  }

  Future<bool> _guard(Future<void> Function() operation) async {
    isBusy = true;
    errorMessage = null;
    lastApiError = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } on ApiException catch (error) {
      lastApiError = error;
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
    if (_disposed || _accountTransitioning) return;
    if (!_wearableAccountRecoveryAllowed &&
        event.type != 'scanDevice' &&
        !(_wearableConnectInFlight != null && event.type == 'deviceDetails')) {
      return;
    }
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
        syncStatus = '正在读取戒指数据 ${(deviceSyncProgress * 100).round()}%';
      }
    } else if (event.type == 'healthRecord') {
      final eventGeneration =
          _activeMeasurementSessionGeneration ??
          _connectedDeviceSessionGeneration;
      if (connectedDevice == null ||
          eventGeneration == null ||
          !_isCurrentSessionGeneration(eventGeneration)) {
        return;
      }
      try {
        var record = HealthRecord.fromJson(event.payload);
        String nativeId(String id) =>
            id.replaceFirst(RegExp(r'^(veepoo|yucheng):'), '').toLowerCase();
        if (nativeId(record.deviceId) != nativeId(connectedDevice!.id)) return;
        if (_activeMeasurementMetric == record.metric &&
            record.origin == MeasurementOrigin.watchHistory) {
          record = record.copyWith(origin: MeasurementOrigin.appMeasurement);
        }
        record = sanitizeWearableTransportRecord(record);
        if (!hasSaneWearableTransportValues(record)) {
          _finishRejectedWearableMeasurement(record);
        } else {
          unawaited(
            _saveWearableRecord(record, expectedGeneration: eventGeneration),
          );
        }
      } catch (_) {
        errorMessage = '收到无法识别的设备数据';
      }
    } else if (event.type == 'healthDataReady') {
      if (connectedDevice != null &&
          _connectedDeviceSessionGeneration == _sessionGeneration &&
          !isDeviceSyncing) {
        unawaited(syncDeviceData());
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
            '${event.payload['deviceState'] ?? ''}' != 'UNPASS_WEAR' &&
            (event.payload['wear'] as num?)?.toInt() != 1;
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
      final activeDeviceId = connectedDevice?.id.trim() ?? '';
      final eventDeviceId = '${event.payload['deviceId'] ?? ''}'.trim();
      // A delayed disconnect from a previous watch must not clear a newer
      // active session. Native transports include deviceId whenever the
      // callback can be attributed to a specific device.
      if (activeDeviceId.isNotEmpty &&
          eventDeviceId.isNotEmpty &&
          activeDeviceId.toLowerCase() != eventDeviceId.toLowerCase()) {
        return;
      }
      _invalidateDeviceSync();
      connectedDevice = null;
      _connectedDeviceSessionGeneration = null;
      _latestDeviceDetails = null;
      capabilities = null;
      activeSport = null;
      sportPaused = false;
      liveSportData = const {};
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
        fallback: '戒指连接出现问题，请稍后重试',
      );
      errorMessage = resolvedMessage;
      if (_isMeasurementErrorCode(errorCode) && activeSport == null) {
        _measurementTimeout?.cancel();
        _measurementTimeout = null;
        _activeMeasurementMetric = null;
        _activeMeasurementSessionGeneration = null;
        measurementProgress = 0;
        measurementSamples = const [];
        measurementWearConfirmed = false;
        measurementErrorMessage = resolvedMessage;
        if (deviceState == DeviceConnectionState.measuring) {
          deviceMachine.transition(DeviceConnectionState.ready);
        }
      }
    } else if (event.type == 'sportData') {
      if (activeSport != null) {
        liveSportData = {
          ...liveSportData,
          for (final entry in event.payload.entries)
            if (entry.value is num) entry.key: entry.value! as num,
        };
      }
    } else if (event.type == 'sportState') {
      final value = '${event.payload['value'] ?? ''}';
      final mode = SportMode.tryFromWire('${event.payload['mode'] ?? ''}');
      if (value == 'stopped') {
        activeSport = null;
        sportPaused = false;
        if (deviceState == DeviceConnectionState.measuring) {
          deviceMachine.transition(DeviceConnectionState.ready);
        }
        unawaited(refreshSportRecords());
      } else if (value == 'running' || value == 'paused') {
        if (mode != null) activeSport = mode;
        sportPaused = value == 'paused';
        if (activeSport != null && deviceState == DeviceConnectionState.ready) {
          deviceMachine.transition(DeviceConnectionState.measuring);
        }
      }
    }
    notifyListeners();
  }

  void _finishRejectedWearableMeasurement(HealthRecord record) {
    if (_activeMeasurementMetric != record.metric) return;
    _measurementTimeout?.cancel();
    _measurementTimeout = null;
    _activeMeasurementMetric = null;
    _activeMeasurementSessionGeneration = null;
    measurementProgress = 0;
    measurementSamples = const [];
    measurementWearConfirmed = false;
    measurementErrorMessage = switch (record.metric) {
      HealthMetric.ecg => '心电信号质量不足，请保持正确佩戴并持续接触电极后重试',
      _ => '${record.metric.label}测量结果无效，请保持正确佩戴后重试',
    };
    errorMessage = measurementErrorMessage;
    if (deviceState == DeviceConnectionState.measuring) {
      deviceMachine.transition(DeviceConnectionState.ready);
    }
  }

  Future<void> _restoreReconnectedDevice(Map<String, Object?> payload) async {
    if (_disposed ||
        _accountTransitioning ||
        !_wearableAccountRecoveryAllowed) {
      return;
    }
    final sessionGeneration = _sessionGeneration;
    final device = DeviceInfo.fromMap(payload);
    if (device.id.trim().isEmpty ||
        deviceState != DeviceConnectionState.disconnected) {
      return;
    }
    _latestDeviceDetails = device;
    errorMessage = null;
    try {
      deviceMachine.transition(DeviceConnectionState.connecting);
      if (!_isCurrentSessionGeneration(sessionGeneration)) return;
      _connectedDeviceSessionGeneration = sessionGeneration;
      connectedDevice = _mergeDeviceDetails(device);
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.loading;
      deviceMachine.transition(DeviceConnectionState.authenticating);
      await refreshDeviceCapabilities(announceFailure: false);
      if (!_isCurrentSessionGeneration(sessionGeneration) ||
          _accountTransitioning ||
          !_wearableAccountRecoveryAllowed ||
          connectedDevice?.id != device.id) {
        return;
      }
      deviceMachine.transition(DeviceConnectionState.syncing);
      syncStatus = '设备已自动重连';
      deviceMachine.transition(DeviceConnectionState.ready);
      notifyListeners();
      unawaited(_syncInitialDeviceData(device.id));
    } on PlatformException catch (error) {
      connectedDevice = null;
      _connectedDeviceSessionGeneration = null;
      capabilities = null;
      deviceCapabilityState = DeviceCapabilityState.disconnected;
      errorMessage = _wearableErrorMessage(error, fallback: '设备重连失败');
      if (deviceState != DeviceConnectionState.error) {
        deviceMachine.transition(DeviceConnectionState.error);
      }
      notifyListeners();
    } catch (_) {
      connectedDevice = null;
      _connectedDeviceSessionGeneration = null;
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
    final updated = scannedDevices.toList(growable: true);
    final existingIndex = updated.indexWhere(
      (existing) => existing.id == device.id,
    );
    if (existingIndex >= 0) {
      updated[existingIndex] = device;
    } else {
      updated.add(device);
    }
    scannedDevices = List.unmodifiable(updated);
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
      battery: details.battery ?? device.battery,
      batteryPercent: details.batteryPercent ?? device.batteryPercent,
      rssi: device.rssi ?? details.rssi,
      lastSyncAt: device.lastSyncAt ?? details.lastSyncAt,
    );
  }

  Future<void> _saveWearableRecord(
    HealthRecord record, {
    required int expectedGeneration,
  }) async {
    if (!_isCurrentSessionGeneration(expectedGeneration) ||
        !hasSaneWearableTransportValues(record)) {
      return;
    }
    final shouldStopMeasurement = _activeMeasurementMetric == record.metric;
    if (shouldStopMeasurement) {
      _measurementTimeout?.cancel();
      _measurementTimeout = null;
      _activeMeasurementMetric = null;
      _activeMeasurementSessionGeneration = null;
      measurementErrorMessage = null;
    }

    // Surface a valid device result immediately. Encrypted storage can take a
    // noticeable amount of time on a physical phone and must not leave the
    // measurement dialog looking as if the watch is still measuring.
    final byId = <String, HealthRecord>{
      for (final item in healthRecords) item.id: item,
      record.id: record,
    };
    healthRecords = deduplicateHealthRecords(byId.values);
    if (healthRecords.length > 200) {
      healthRecords = healthRecords.take(200).toList(growable: false);
    }
    _evaluateHealthWarning(record, expectedGeneration: expectedGeneration);
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
      if (!_isCurrentSessionGeneration(expectedGeneration)) return;
      await _healthStore.upsertImmediate(record);
      if (!_isCurrentSessionGeneration(expectedGeneration)) return;
      await _refreshHealthRecordCache(expectedGeneration: expectedGeneration);
      if (!_isCurrentSessionGeneration(expectedGeneration)) return;
      notifyListeners();
      unawaited(synchronizeCloud());
    } catch (error) {
      debugPrint('Health record persistence failed: ${error.runtimeType}');
      errorMessage = '测量结果已显示，但暂时无法保存到本机';
      if (_isCurrentSessionGeneration(expectedGeneration)) notifyListeners();
    }
  }

  void _evaluateHealthWarning(
    HealthRecord record, {
    required int expectedGeneration,
  }) {
    if (!_isCurrentSessionGeneration(expectedGeneration)) return;
    if (record.measuredAt.isBefore(
      DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    )) {
      return;
    }
    if (healthWarningAlerts.any((item) => item.id == record.id)) return;
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
      triggeredAt: record.measuredAt.toLocal(),
      origin: record.origin,
    );
    healthWarningAlerts = [
      alert,
      ...healthWarningAlerts.where((item) => item.id != alert.id),
    ];
    unawaited(_healthStore.saveHealthWarningAlert(alert));
    final entityId = _stableIdentifierHash(record.id);
    unawaited(
      _ingestNotificationPayload(
        <String, Object?>{
          'schema_version': NotificationEvent.schemaVersion,
          'event_id': 'health-warning-$entityId',
          'event_type': NotificationEventType.healthWarning.wireName,
          'entity_id': entityId,
          'source': NotificationEventSource.device.wireName,
          'created_at': record.measuredAt.toUtc().toIso8601String(),
        },
        showLocalNotification: true,
        expectedGeneration: expectedGeneration,
      ),
    );
    activeHealthWarningAlert = alert;
  }

  Future<void> _refreshHealthRecordCache({
    required int expectedGeneration,
  }) async {
    final storedRecent = await _healthStore.recent();
    if (!_isCurrentSessionGeneration(expectedGeneration)) return;
    final storedLatest = await _healthStore.latestForEachMetric();
    if (!_isCurrentSessionGeneration(expectedGeneration)) return;
    final invalidIds = [...storedRecent, ...storedLatest]
        .where((record) => !hasSaneWearableTransportValues(record))
        .map((record) => record.id)
        .toSet();
    if (invalidIds.isNotEmpty) {
      await _healthStore.markInvalid(invalidIds);
      if (!_isCurrentSessionGeneration(expectedGeneration)) return;
    }
    final recent = storedRecent.where(hasSaneWearableTransportValues);
    final latest = storedLatest.where(hasSaneWearableTransportValues);
    final byId = <String, HealthRecord>{
      for (final record in recent) record.id: record,
      for (final record in latest) record.id: record,
    };
    healthRecords = deduplicateHealthRecords(
      ringPreferredHealthRecords(
        byId.values,
        preferredDeviceId: connectedDevice?.id,
      ),
    );
  }

  @override
  void dispose() {
    ++_wechatLoginGeneration;
    if (isWechatLoginInProgress) unawaited(_wechatAuthBridge.cancel());
    _disposed = true;
    _wearableRestoreGeneration++;
    _measurementTimeout?.cancel();
    _careInvitationPollTimer?.cancel();
    _pushRegistrationRetryTimer?.cancel();
    _invalidateDeviceSync();
    unawaited(_wearableEvents?.cancel());
    unawaited(_deviceStates?.cancel());
    unawaited(_connectivity?.cancel());
    unawaited(_pushReceivedEvents?.cancel());
    unawaited(_pushOpenedEvents?.cancel());
    unawaited(_pushPermissionEvents?.cancel());
    unawaited(_pushRegistrationReadyEvents?.cancel());
    unawaited(_notificationService.dispose());
    deviceMachine.dispose();
    unawaited(_healthStore.close());
    super.dispose();
  }
}

int? _cartInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}');

String _stableIdentifierHash(String source) {
  final normalized = source.trim();
  if (normalized.length <= 120 &&
      RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(normalized)) {
    return normalized;
  }
  return sha256.convert(utf8.encode(source)).toString();
}

String formatCareCalendarDay(DateTime? day, {DateTime? now}) {
  final selected =
      day ?? (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${selected.year.toString().padLeft(4, '0')}-'
      '${twoDigits(selected.month)}-${twoDigits(selected.day)}';
}
