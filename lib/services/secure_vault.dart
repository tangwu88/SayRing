import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'global_storage_scope.dart';

abstract interface class SessionVault {
  Future<Session?> readSession();
  Future<void> writeSession(Session session);
  Future<bool> writeSessionIfUnchanged(Session expected, Session replacement);
  Future<void> clearSession();
  Future<bool> readPrivacyConsentGranted();
  Future<void> writePrivacyConsentGranted(bool granted);
  Future<HealthWarningSettings> readHealthWarningSettings();
  Future<void> writeHealthWarningSettings(HealthWarningSettings settings);
  Future<List<Map<String, Object?>>> readShopCart();
  Future<void> writeShopCart(List<Map<String, Object?>> items);
  Future<String?> readPendingPushUnregisterInstallationId();
  Future<void> writePendingPushUnregisterInstallationId(String value);
  Future<void> clearPendingPushUnregisterInstallationId();
  Future<bool> readLegacyHealthMigrationHandled();
  Future<void> writeLegacyHealthMigrationHandled();
  Future<String> databaseKey();
}

class SecureSessionVault implements SessionVault {
  SecureSessionVault([FlutterSecureStorage? storage])
    : storageNamespace = null,
      _storage = storage ?? const FlutterSecureStorage();
  SecureSessionVault.global({
    FlutterSecureStorage? storage,
    String? storageNamespace,
  }) : storageNamespace = globalStorageNamespace(storageNamespace),
       _storage = storage ?? const FlutterSecureStorage();

  final String? storageNamespace;
  String get _prefix => storageNamespace == null
      ? 'saydian'
      : 'saydian.global.env.$storageNamespace';
  String get _sessionKey => '$_prefix.session.v1';
  String get _privacyConsentKey => '$_prefix.privacy-consent.v1';
  String get _databaseKey => '$_prefix.database.key.v1';
  String get _healthWarningKey => '$_prefix.health-warning.v1';
  String get _shopCartKey => '$_prefix.shop-cart.v1';
  String get _pendingPushUnregisterKey =>
      '$_prefix.push.pending-unregister-installation.v1';
  String get _legacyHealthMigrationHandledKey =>
      '$_prefix.health.legacy-migration-handled.v1';

  final FlutterSecureStorage _storage;
  Future<void> _sessionMutationQueue = Future<void>.value();

  Future<T> _withSessionLock<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _sessionMutationQueue = _sessionMutationQueue.catchError((_) {}).then((
      _,
    ) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Session?> _readSessionDirect() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return null;
      return Session.fromJson(
        value.map((key, value) => MapEntry('$key', value)),
      );
    } on FormatException {
      await _storage.delete(key: _sessionKey);
      return null;
    }
  }

  @override
  Future<Session?> readSession() => _withSessionLock(_readSessionDirect);

  @override
  Future<void> writeSession(Session session) => _withSessionLock(
    () => _storage.write(key: _sessionKey, value: jsonEncode(session.toJson())),
  );

  @override
  Future<bool> writeSessionIfUnchanged(Session expected, Session replacement) =>
      _withSessionLock(() async {
        final current = await _readSessionDirect();
        if (!_sameSession(current, expected)) return false;
        await _storage.write(
          key: _sessionKey,
          value: jsonEncode(replacement.toJson()),
        );
        return true;
      });

  @override
  Future<void> clearSession() =>
      _withSessionLock(() => _storage.delete(key: _sessionKey));

  @override
  Future<bool> readPrivacyConsentGranted() async =>
      await _storage.read(key: _privacyConsentKey) == 'granted';

  @override
  Future<void> writePrivacyConsentGranted(bool granted) => granted
      ? _storage.write(key: _privacyConsentKey, value: 'granted')
      : _storage.delete(key: _privacyConsentKey);

  @override
  Future<HealthWarningSettings> readHealthWarningSettings() async {
    final raw = await _storage.read(key: _healthWarningKey);
    if (raw == null || raw.isEmpty) return const HealthWarningSettings();
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return const HealthWarningSettings();
      return HealthWarningSettings.fromJson(
        value.map((key, value) => MapEntry('$key', value)),
      );
    } on FormatException {
      return const HealthWarningSettings();
    }
  }

  @override
  Future<void> writeHealthWarningSettings(HealthWarningSettings settings) =>
      _storage.write(
        key: _healthWarningKey,
        value: jsonEncode(settings.toJson()),
      );

  @override
  Future<List<Map<String, Object?>>> readShopCart() async {
    final raw = await _storage.read(key: _shopCartKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry('$key', value)))
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> writeShopCart(List<Map<String, Object?>> items) =>
      _storage.write(key: _shopCartKey, value: jsonEncode(items));

  @override
  Future<String?> readPendingPushUnregisterInstallationId() async {
    final value = await _storage.read(key: _pendingPushUnregisterKey);
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  Future<void> writePendingPushUnregisterInstallationId(String value) =>
      _storage.write(key: _pendingPushUnregisterKey, value: value.trim());

  @override
  Future<void> clearPendingPushUnregisterInstallationId() =>
      _storage.delete(key: _pendingPushUnregisterKey);

  @override
  Future<bool> readLegacyHealthMigrationHandled() async =>
      await _storage.read(key: _legacyHealthMigrationHandledKey) == 'handled';

  @override
  Future<void> writeLegacyHealthMigrationHandled() =>
      _storage.write(key: _legacyHealthMigrationHandledKey, value: 'handled');

  @override
  Future<String> databaseKey() async {
    final existing = await _storage.read(key: _databaseKey);
    if (existing != null && existing.length >= 24) return existing;
    final generated = const Uuid().v4() + const Uuid().v4();
    await _storage.write(key: _databaseKey, value: generated);
    return generated;
  }
}

class MemorySessionVault implements SessionVault {
  Session? session;
  HealthWarningSettings healthWarningSettings = const HealthWarningSettings();
  String key = 'test-database-key-that-is-long-enough';
  List<Map<String, Object?>> shopCart = const [];
  String? pendingPushUnregisterInstallationId;
  bool privacyConsentGranted = false;
  bool legacyHealthMigrationHandled = false;

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<String> databaseKey() async => key;

  @override
  Future<Session?> readSession() async => session;

  @override
  Future<bool> readPrivacyConsentGranted() async => privacyConsentGranted;

  @override
  Future<HealthWarningSettings> readHealthWarningSettings() async =>
      healthWarningSettings;

  @override
  Future<List<Map<String, Object?>>> readShopCart() async => shopCart;

  @override
  Future<void> writeSession(Session value) async => session = value;

  @override
  Future<bool> writeSessionIfUnchanged(
    Session expected,
    Session replacement,
  ) async {
    if (!_sameSession(session, expected)) return false;
    session = replacement;
    return true;
  }

  @override
  Future<void> writePrivacyConsentGranted(bool granted) async =>
      privacyConsentGranted = granted;

  @override
  Future<void> writeHealthWarningSettings(
    HealthWarningSettings settings,
  ) async => healthWarningSettings = settings;

  @override
  Future<void> writeShopCart(List<Map<String, Object?>> items) async =>
      shopCart = items;

  @override
  Future<String?> readPendingPushUnregisterInstallationId() async =>
      pendingPushUnregisterInstallationId;

  @override
  Future<void> writePendingPushUnregisterInstallationId(String value) async =>
      pendingPushUnregisterInstallationId = value.trim();

  @override
  Future<void> clearPendingPushUnregisterInstallationId() async =>
      pendingPushUnregisterInstallationId = null;

  @override
  Future<bool> readLegacyHealthMigrationHandled() async =>
      legacyHealthMigrationHandled;

  @override
  Future<void> writeLegacyHealthMigrationHandled() async =>
      legacyHealthMigrationHandled = true;
}

bool _sameSession(Session? left, Session right) =>
    left != null &&
    left.accessToken == right.accessToken &&
    left.refreshToken == right.refreshToken &&
    left.memberId == right.memberId &&
    left.accountKey == right.accountKey;
