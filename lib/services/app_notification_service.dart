import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';
import 'package:uuid/uuid.dart';

import 'global_storage_scope.dart';
import 'notification_payload.dart';

abstract interface class AppNotificationService {
  bool get isConfigured;
  bool get isActivated;
  Stream<Map<String, Object?>> get receivedEvents;
  Stream<Map<String, Object?>> get openedEvents;
  Stream<bool> get permissionChanges;
  Stream<void> get registrationReadyEvents;

  Future<void> initialize();
  Future<void> activateAfterPrivacyConsent();
  Future<void> deactivate();
  Future<String?> registrationId();
  Future<String> installationId();
  Future<bool> isPermissionEnabled();
  Future<bool> shouldExplainPermission();
  Future<void> markPermissionExplanationShown();
  Future<void> requestPermission();
  Future<void> openSettings();
  Future<void> setBadge(int value);
  Future<void> showHealthWarning({
    required String eventId,
    required String entityId,
    required DateTime createdAt,
    required int unreadCount,
  });
  Future<void> showCareInvitation({
    required String eventId,
    required String entityId,
    required DateTime createdAt,
    required int unreadCount,
  });
  Future<void> dispose();
}

final class JPushAppNotificationService implements AppNotificationService {
  JPushAppNotificationService({
    JPushFlutterInterface? jpush,
    FlutterSecureStorage? storage,
    String? storageNamespace,
    String? appKey,
    this._registrationTimeout = const Duration(seconds: 5),
    this._permissionResolutionTimeout = const Duration(seconds: 4),
    this._permissionPollInterval = const Duration(milliseconds: 250),
  }) : _jpush = jpush ?? JPush.newJPush(),
       _storage = storage ?? const FlutterSecureStorage(),
       _storageNamespace = globalStorageNamespace(storageNamespace),
       _configuredAppKey = appKey ?? _appKey;

  static const _appKey = String.fromEnvironment('JPUSH_APP_KEY');
  String get _installationKey =>
      'saydian.global.env.$_storageNamespace.push.installation-id.v1';
  String get _permissionExplanationKey =>
      'saydian.global.env.$_storageNamespace.push.permission-explained.v1';

  final JPushFlutterInterface _jpush;
  final FlutterSecureStorage _storage;
  final String _storageNamespace;
  final String _configuredAppKey;
  final Duration _registrationTimeout;
  final Duration _permissionResolutionTimeout;
  final Duration _permissionPollInterval;
  final StreamController<Map<String, Object?>> _received =
      StreamController.broadcast();
  final StreamController<Map<String, Object?>> _opened =
      StreamController.broadcast();
  final StreamController<bool> _permissionChanges =
      StreamController.broadcast();
  final StreamController<void> _registrationReady =
      StreamController.broadcast();
  bool _handlersInitialized = false;
  bool _setupCompleted = false;
  bool _active = false;
  bool _nativeConnected = false;
  Future<void>? _activation;
  Future<String?>? _registrationLookup;
  Future<void>? _launchNotificationLookup;
  bool _launchNotificationChecked = false;
  Completer<bool>? _permissionDecision;

  @override
  bool get isConfigured => _configuredAppKey.trim().isNotEmpty;

  @override
  bool get isActivated => _active;

  @override
  Stream<Map<String, Object?>> get receivedEvents => _received.stream;

  @override
  Stream<Map<String, Object?>> get openedEvents => _opened.stream;

  @override
  Stream<bool> get permissionChanges => _permissionChanges.stream;

  @override
  Stream<void> get registrationReadyEvents => _registrationReady.stream;

  @override
  Future<void> initialize() async {
    if (_handlersInitialized || !isConfigured) return;
    _handlersInitialized = true;
    _jpush.addEventHandler(
      onReceiveNotification: (value) async => _emit(
        value,
        _received,
        deliveryKind: 'notification',
        systemAlreadyPresented: true,
      ),
      onOpenNotification: (value) async => _emit(
        value,
        _opened,
        deliveryKind: 'notification',
        systemAlreadyPresented: true,
      ),
      onReceiveMessage: (value) async => _emit(
        value,
        _received,
        deliveryKind: 'data',
        systemAlreadyPresented: false,
      ),
      onReceiveNotificationAuthorization: (value) async {
        _handlePermissionAuthorization(value);
      },
      onNotifyMessageUnShow: (value) async => _emit(
        value,
        _received,
        deliveryKind: 'data',
        systemAlreadyPresented: false,
      ),
      onConnected: (value) async => _handleConnection(value),
      onInAppMessageClick: (value) async => _emit(
        value,
        _opened,
        deliveryKind: 'in_app',
        systemAlreadyPresented: true,
      ),
      onInAppMessageShow: (_) async {},
      onNotifyButtonClick: (value) async => _emit(
        value,
        _opened,
        deliveryKind: 'notification',
        systemAlreadyPresented: true,
      ),
      onCommandResult: (_) async {},
      onReceiveDeviceToken: (_) async {},
      onVoipMessage: (_) async {},
    );
  }

  @override
  Future<void> activateAfterPrivacyConsent() async {
    if (!isConfigured) return;
    if (_active) {
      unawaited(_consumeLaunchNotificationIfNeeded());
      return;
    }
    final pending = _activation;
    if (pending != null) return pending;
    final operation = _activateNow();
    _activation = operation;
    return operation.whenComplete(() {
      if (identical(_activation, operation)) _activation = null;
    });
  }

  Future<void> _activateNow() async {
    await initialize();
    _jpush.setAuth(enable: true);
    _jpush.setCollectControl(
      imsi: false,
      mac: false,
      wifi: false,
      bssid: false,
      ssid: false,
      imei: false,
      cell: false,
      gps: false,
    );
    // The plugin documents that this option must be configured before setup.
    _jpush.setBackgroundEnable(enable: true);
    if (_setupCompleted) {
      await _jpush.resumePush().timeout(_registrationTimeout);
    } else {
      _jpush.setup(
        appKey: _configuredAppKey,
        channel: 'production',
        production: kReleaseMode,
        // The vendor SDK prints AppKey and Registration ID when its debug
        // logger is enabled. Connection state is already exposed through the
        // sanitized onConnected/registration state maintained by this service,
        // so verbose native logging must stay disabled in every build mode.
        debug: false,
      );
      _setupCompleted = true;
    }
    _jpush.setUnShowAtTheForeground(unShow: false);
    _active = true;
    if (_nativeConnected) _emitRegistrationReady();
    unawaited(_consumeLaunchNotificationIfNeeded());
  }

  Future<void> _consumeLaunchNotificationIfNeeded() {
    if (_launchNotificationChecked || !_active) return Future<void>.value();
    final pending = _launchNotificationLookup;
    if (pending != null) return pending;
    final operation = () async {
      try {
        final raw = await _jpush.getLaunchAppNotification().timeout(
          _registrationTimeout,
        );
        _launchNotificationChecked = true;
        if (raw.isNotEmpty) {
          _emit(
            Map<String, dynamic>.from(raw),
            _opened,
            deliveryKind: 'notification',
            systemAlreadyPresented: true,
          );
        }
      } catch (_) {
        // Retry on the next foreground activation if the native launch payload
        // is not ready yet. A successful empty result is consumed once.
      }
    }();
    _launchNotificationLookup = operation;
    return operation.whenComplete(() {
      if (identical(_launchNotificationLookup, operation)) {
        _launchNotificationLookup = null;
      }
    });
  }

  @override
  Future<void> deactivate() async {
    final pending = _activation;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Continue with the local privacy state even if activation failed.
      }
    }
    if (!_active) return;
    _active = false;
    _nativeConnected = false;
    try {
      await _jpush.stopPush().timeout(_registrationTimeout);
    } catch (_) {
      // Server-side unbinding remains the authoritative account boundary.
    }
    _jpush.setAuth(enable: false);
  }

  @override
  Future<String?> registrationId() async {
    if (!isConfigured || !_active) return null;
    var operation = _registrationLookup;
    if (operation == null) {
      operation = _readRegistrationId();
      _registrationLookup = operation;
      unawaited(
        operation.whenComplete(() {
          if (identical(_registrationLookup, operation)) {
            _registrationLookup = null;
          }
        }),
      );
    }
    return operation.timeout(_registrationTimeout, onTimeout: () => null);
  }

  Future<String?> _readRegistrationId() async {
    try {
      final value = (await _jpush.getRegistrationID()).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> installationId() async {
    final existing = (await _storage.read(key: _installationKey))?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await _storage.write(key: _installationKey, value: generated);
    return generated;
  }

  @override
  Future<bool> isPermissionEnabled() async {
    if (!isConfigured || !_active) return false;
    try {
      return await _jpush.isNotificationEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> shouldExplainPermission() async =>
      await _storage.read(key: _permissionExplanationKey) != 'shown';

  @override
  Future<void> markPermissionExplanationShown() =>
      _storage.write(key: _permissionExplanationKey, value: 'shown');

  @override
  Future<void> requestPermission() async {
    await markPermissionExplanationShown();
    if (!isConfigured || !_active) return;
    if (await isPermissionEnabled()) {
      _emitPermissionChange(true);
      return;
    }
    final decision = Completer<bool>();
    _permissionDecision = decision;
    if (Platform.isIOS) {
      _jpush.applyPushAuthority(
        const NotificationSettingsIOS(sound: true, alert: true, badge: true),
      );
    } else if (Platform.isAndroid) {
      _jpush.requestRequiredPermission();
    }
    final deadline = DateTime.now().add(_permissionResolutionTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.any<void>([
        decision.future.then<void>((_) {}),
        Future<void>.delayed(_permissionPollInterval),
      ]);
      if (await isPermissionEnabled()) {
        _emitPermissionChange(true);
        break;
      }
      if (decision.isCompleted) break;
    }
    if (identical(_permissionDecision, decision)) _permissionDecision = null;
  }

  @override
  Future<void> openSettings() async {
    if (isConfigured && _active) _jpush.openSettingsForNotification();
  }

  @override
  Future<void> setBadge(int value) async {
    if (!isConfigured || !_active) return;
    try {
      await _jpush.setBadge(value.clamp(0, 999));
    } catch (_) {
      // The in-app unread count remains authoritative.
    }
  }

  @override
  Future<void> showHealthWarning({
    required String eventId,
    required String entityId,
    required DateTime createdAt,
    required int unreadCount,
  }) => _showGenericLocalNotification(
    eventId: eventId,
    entityId: entityId,
    createdAt: createdAt,
    eventType: 'health_warning',
    title: 'Say Ring 健康提醒',
    content: '有新的健康预警，请打开 App 查看',
    badge: unreadCount,
  );

  @override
  Future<void> showCareInvitation({
    required String eventId,
    required String entityId,
    required DateTime createdAt,
    required int unreadCount,
  }) => _showGenericLocalNotification(
    eventId: eventId,
    entityId: entityId,
    createdAt: createdAt,
    eventType: 'care_invitation',
    title: 'Say Ring 远程关爱',
    content: '您有新的关爱请求，请打开 App 查看',
    badge: unreadCount,
  );

  Future<void> _showGenericLocalNotification({
    required String eventId,
    required String entityId,
    required DateTime createdAt,
    required String eventType,
    required String title,
    required String content,
    required int badge,
  }) async {
    if (!isConfigured || !_active || !await isPermissionEnabled()) return;
    final id = eventId.codeUnits.fold<int>(0, (value, unit) {
      return ((value * 31) + unit) & 0x7fffffff;
    });
    await _jpush.sendLocalNotification(
      LocalNotification(
        id: id == 0 ? 1 : id,
        title: title,
        content: content,
        fireTime: DateTime.now().add(const Duration(milliseconds: 150)),
        badge: badge.clamp(0, 999),
        extra: {
          'schema_version': '1',
          'event_id': eventId,
          'event_type': eventType,
          'entity_id': entityId,
          'source': 'local',
          'created_at': createdAt.toUtc().toIso8601String(),
        },
      ),
    );
  }

  void _emit(
    Map<String, dynamic> raw,
    StreamController<Map<String, Object?>> target, {
    required String deliveryKind,
    required bool systemAlreadyPresented,
  }) {
    final normalized = normalizeJPushPayload(raw);
    if (kDebugMode) {
      debugPrint(
        '[push-callback] opened=${identical(target, _opened)} '
        'kind=$deliveryKind parsed=${normalized != null} '
        'type=${normalized?['event_type'] ?? 'unsupported'}',
      );
    }
    if (normalized != null && !target.isClosed) {
      // These fields are set after normalizing untrusted extras so the server
      // cannot suppress or duplicate the client-side system notification.
      normalized['_delivery_kind'] = deliveryKind;
      normalized['_system_already_presented'] = systemAlreadyPresented;
      target.add(normalized);
    }
  }

  void _handlePermissionAuthorization(Map<String, dynamic> value) {
    final raw = value['isEnabled'] ?? value['enabled'] ?? value['status'];
    final enabled = raw == true || raw == 1 || '$raw'.toLowerCase() == 'true';
    _emitPermissionChange(enabled);
    final decision = _permissionDecision;
    if (decision != null && !decision.isCompleted) decision.complete(enabled);
  }

  void _emitPermissionChange(bool enabled) {
    if (!_permissionChanges.isClosed) _permissionChanges.add(enabled);
  }

  void _handleConnection(Map<String, dynamic> value) {
    final raw = value['result'] ?? value['connected'] ?? value['isConnected'];
    _nativeConnected =
        raw == true || raw == 1 || '$raw'.trim().toLowerCase() == 'true';
    if (_nativeConnected && _active) _emitRegistrationReady();
  }

  void _emitRegistrationReady() {
    if (!_registrationReady.isClosed) _registrationReady.add(null);
  }

  @override
  Future<void> dispose() async {
    await deactivate();
    await _received.close();
    await _opened.close();
    await _permissionChanges.close();
    await _registrationReady.close();
  }
}

final class DisabledAppNotificationService implements AppNotificationService {
  const DisabledAppNotificationService();

  @override
  bool get isConfigured => false;
  @override
  bool get isActivated => false;
  @override
  Stream<Map<String, Object?>> get receivedEvents => const Stream.empty();
  @override
  Stream<Map<String, Object?>> get openedEvents => const Stream.empty();
  @override
  Stream<bool> get permissionChanges => const Stream.empty();
  @override
  Stream<void> get registrationReadyEvents => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> activateAfterPrivacyConsent() async {}
  @override
  Future<void> deactivate() async {}
  @override
  Future<String?> registrationId() async => null;
  @override
  Future<String> installationId() async => 'disabled-installation';
  @override
  Future<bool> isPermissionEnabled() async => false;
  @override
  Future<bool> shouldExplainPermission() async => false;
  @override
  Future<void> markPermissionExplanationShown() async {}
  @override
  Future<void> requestPermission() async {}
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> setBadge(int value) async {}
  @override
  Future<void> showHealthWarning({
    required String eventId,
    required String entityId,
    required DateTime createdAt,
    required int unreadCount,
  }) async {}
  @override
  Future<void> showCareInvitation({
    required String eventId,
    required String entityId,
    required DateTime createdAt,
    required int unreadCount,
  }) async {}
  @override
  Future<void> dispose() async {}
}

@visibleForTesting
Map<String, Object?>? normalizeJPushPayload(Map<String, dynamic> raw) {
  final root = _stringMap(raw);
  final initial = _decodeMap(root['extras'] ?? root['extra']) ?? root;
  final source = _findBusinessPayload(initial) ?? initial;
  return normalizeNotificationBusinessPayload(
    source,
    receivedAt: DateTime.now(),
  );
}

Map<String, Object?>? _findBusinessPayload(
  Map<String, Object?> value, [
  int depth = 0,
]) {
  if (depth > 4) return null;
  if (value.containsKey('event_type') ||
      value.containsKey('event_id') ||
      value.containsKey('eventId') ||
      value.containsKey('schema_version')) {
    return value;
  }
  for (final key in const <String>[
    'cn.jpush.android.EXTRA',
    'extra',
    'extras',
  ]) {
    final nested = _decodeMap(value[key]);
    if (nested == null) continue;
    final resolved = _findBusinessPayload(nested, depth + 1);
    if (resolved != null) return resolved;
  }
  for (final entry in value.entries) {
    if (!entry.key.toLowerCase().endsWith('.extra')) continue;
    final nested = _decodeMap(entry.value);
    if (nested == null) continue;
    final resolved = _findBusinessPayload(nested, depth + 1);
    if (resolved != null) return resolved;
  }
  return null;
}

Map<String, Object?>? _decodeMap(Object? value) {
  Object? decoded = value;
  for (var depth = 0; depth < 3 && decoded is String; depth++) {
    final text = decoded.trim();
    if (text.isEmpty) return null;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
  return decoded is Map ? _stringMap(decoded) : null;
}

Map<String, Object?> _stringMap(Map<Object?, Object?> value) =>
    value.map((key, item) => MapEntry('$key', item));
