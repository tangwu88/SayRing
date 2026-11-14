import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/home_health_cards.dart';
import 'global_storage_scope.dart';
import 'safe_secure_storage.dart';

abstract interface class SessionVault {
  Future<Session?> readSession();
  Future<void> writeSession(Session session);
  Future<bool> writeSessionIfUnchanged(Session expected, Session replacement);
  Future<void> clearSession();
  Future<bool> clearSessionIfUnchanged(Session expected);
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
  Future<Map<String, Object?>?> readGlobalCommerceDraft(
    String owner,
    String key,
  );
  Future<void> writeGlobalCommerceDraft(
    String owner,
    String key,
    Map<String, Object?> value,
  );
  Future<void> clearGlobalCommerceDraft(String owner, String key);
  Future<String> databaseKey({bool existingDatabase = false});
}

abstract interface class SayRingAppDisplayVault {
  Future<bool?> readSayRingHideAi();
  Future<void> writeSayRingHideAi(bool value);
}

abstract interface class HomeHealthCardsVault {
  Future<HomeHealthCardLayout> readHomeHealthCards(String owner);
  Future<void> writeHomeHealthCards(String owner, HomeHealthCardLayout layout);
}

/// A decision request is one-shot: the server intentionally does not replay a
/// lost destructive authorization. Keep uncertainty across BLE/app lifetimes.
enum RingInitializationStage {
  decisionRequired,
  decisionUnknown,
  resetAttempted,
  historyClearAcknowledged,
}

abstract interface class RingInitializationVault {
  Future<RingInitializationStage?> readRingInitializationStage(
    String owner,
    String deviceId,
  );
  Future<void> writeRingInitializationStage(
    String owner,
    String deviceId,
    RingInitializationStage stage,
  );
  Future<void> clearRingInitializationStage(String owner, String deviceId);
}

/// 首次绑定请求与状态原子保存；旧的未知状态没有编号时不得补造编号重试。
abstract interface class RingInitializationOperationVault {
  Future<String?> readRingInitializationOperationId(
    String owner,
    String deviceId,
  );
  Future<void> writeRingInitializationRequest(
    String owner,
    String deviceId,
    String operationId,
  );
}

bool isValidRingInitializationOperationId(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
).hasMatch(value);

({RingInitializationStage stage, String? operationId})
_decodeRingInitialization(String raw) {
  final legacy = RingInitializationStage.values.where((s) => s.name == raw);
  if (legacy.isNotEmpty) return (stage: legacy.single, operationId: null);
  final value = jsonDecode(raw);
  if (value is! Map ||
      value['version'] != 2 ||
      value['operationId'] is! String ||
      !isValidRingInitializationOperationId(value['operationId'] as String)) {
    throw const FormatException('Invalid ring initialization request');
  }
  final stage = RingInitializationStage.values.firstWhere(
    (s) => s.name == value['stage'],
    orElse: () =>
        throw const FormatException('Invalid ring initialization stage'),
  );
  return (stage: stage, operationId: value['operationId'] as String);
}

abstract interface class SyncDiagnosticsVault {
  Future<Map<String, Object?>?> readSyncDiagnostics(String owner);
  Future<void> writeSyncDiagnostics(String owner, Map<String, Object?> value);
}

class SecureSessionVault
    implements
        SessionVault,
        SayRingAppDisplayVault,
        HomeHealthCardsVault,
        RingInitializationVault,
        SyncDiagnosticsVault,
        RingInitializationOperationVault {
  SecureSessionVault([FlutterSecureStorage? storage])
    : storageNamespace = null,
      _storage = storage ?? safeSecureStorage;
  SecureSessionVault.global({
    FlutterSecureStorage? storage,
    String? storageNamespace,
  }) : storageNamespace = globalStorageNamespace(storageNamespace),
       _storage = storage ?? safeSecureStorage;

  final String? storageNamespace;
  String _syncDiagnosticKey(String owner) =>
      '$_prefix.sync-diagnostics.v1.${sha256.convert(utf8.encode(owner))}';
  @override
  Future<Map<String, Object?>?> readSyncDiagnostics(String owner) async {
    final raw = await _storage.read(key: _syncDiagnosticKey(owner));
    if (raw == null) return null;
    final value = jsonDecode(raw);
    return value is Map ? value.map((k, v) => MapEntry('$k', v)) : null;
  }

  @override
  Future<void> writeSyncDiagnostics(String owner, Map<String, Object?> value) =>
      _storage.write(key: _syncDiagnosticKey(owner), value: jsonEncode(value));
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

  String _globalCommerceDraftKey(String owner, String key) {
    final digest = sha256.convert(utf8.encode('$owner\u0000$key'));
    return '$_prefix.commerce-draft.v1.$digest';
  }

  final FlutterSecureStorage _storage;

  String _ringInitializationKey(String owner, String deviceId) =>
      '$_prefix.say-ring.initialization.v1.'
      '${sha256.convert(utf8.encode('$owner\u0000$deviceId'))}';

  @override
  Future<RingInitializationStage?> readRingInitializationStage(
    String owner,
    String deviceId,
  ) async {
    final raw = await _storage.read(
      key: _ringInitializationKey(owner, deviceId),
    );
    if (raw == null) return null;
    return _decodeRingInitialization(raw).stage;
  }

  @override
  Future<void> writeRingInitializationStage(
    String owner,
    String deviceId,
    RingInitializationStage stage,
  ) async {
    final key = _ringInitializationKey(owner, deviceId);
    final raw = await _storage.read(key: key);
    final operationId = raw == null
        ? null
        : _decodeRingInitialization(raw).operationId;
    await _storage.write(
      key: key,
      value: operationId == null
          ? stage.name
          : jsonEncode({
              'version': 2,
              'stage': stage.name,
              'operationId': operationId,
            }),
    );
  }

  @override
  Future<String?> readRingInitializationOperationId(
    String owner,
    String deviceId,
  ) async {
    final raw = await _storage.read(
      key: _ringInitializationKey(owner, deviceId),
    );
    return raw == null ? null : _decodeRingInitialization(raw).operationId;
  }

  @override
  Future<void> writeRingInitializationRequest(
    String owner,
    String deviceId,
    String operationId,
  ) async {
    if (!isValidRingInitializationOperationId(operationId)) {
      throw const FormatException('Invalid ring operation ID');
    }
    final key = _ringInitializationKey(owner, deviceId);
    final raw = await _storage.read(key: key);
    final state = raw == null ? null : _decodeRingInitialization(raw);
    if (state?.stage != RingInitializationStage.decisionRequired ||
        (state?.operationId != null && state!.operationId != operationId)) {
      throw StateError('Cannot replace an uncertain ring decision');
    }
    // 一个安全存储值同时保存状态和编号，避免崩溃后状态在、编号丢失。
    await _storage.write(
      key: key,
      value: jsonEncode({
        'version': 2,
        'stage': RingInitializationStage.decisionRequired.name,
        'operationId': operationId,
      }),
    );
  }

  @override
  Future<void> clearRingInitializationStage(String owner, String deviceId) =>
      _storage.delete(key: _ringInitializationKey(owner, deviceId));

  String _homeHealthCardsKey(String owner) =>
      '$_prefix.say-ring.home-health-cards.v1.${sha256.convert(utf8.encode(owner))}';

  @override
  Future<HomeHealthCardLayout> readHomeHealthCards(String owner) async {
    final raw = await _storage.read(key: _homeHealthCardsKey(owner));
    if (raw == null) return HomeHealthCardLayout();
    try {
      return HomeHealthCardLayout.fromJson(jsonDecode(raw));
    } on FormatException {
      return HomeHealthCardLayout();
    }
  }

  @override
  Future<void> writeHomeHealthCards(
    String owner,
    HomeHealthCardLayout layout,
  ) => _storage.write(
    key: _homeHealthCardsKey(owner),
    value: jsonEncode(layout.toJson()),
  );

  @override
  Future<bool?> readSayRingHideAi() async =>
      switch (await _storage.read(key: '$_prefix.say-ring.hide-ai.v1')) {
        'true' => true,
        'false' => false,
        _ => null,
      };

  @override
  Future<void> writeSayRingHideAi(bool value) => _storage.write(
    key: '$_prefix.say-ring.hide-ai.v1',
    value: value.toString(),
  );
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
  Future<bool> clearSessionIfUnchanged(Session expected) =>
      _withSessionLock(() async {
        if (!_sameSession(await _readSessionDirect(), expected)) return false;
        await _storage.delete(key: _sessionKey);
        return true;
      });

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
  Future<Map<String, Object?>?> readGlobalCommerceDraft(
    String owner,
    String key,
  ) async {
    final raw = await _storage.read(
      key: _globalCommerceDraftKey(owner.trim(), key.trim()),
    );
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return null;
      return value.map((key, value) => MapEntry('$key', value));
    } on FormatException {
      await clearGlobalCommerceDraft(owner, key);
      return null;
    }
  }

  @override
  Future<void> writeGlobalCommerceDraft(
    String owner,
    String key,
    Map<String, Object?> value,
  ) => _storage.write(
    key: _globalCommerceDraftKey(owner.trim(), key.trim()),
    value: jsonEncode(value),
  );

  @override
  Future<void> clearGlobalCommerceDraft(String owner, String key) =>
      _storage.delete(key: _globalCommerceDraftKey(owner.trim(), key.trim()));

  @override
  Future<String> databaseKey({bool existingDatabase = false}) async {
    final existing = await _storage.read(key: _databaseKey);
    if (existing != null && existing.length >= 24) return existing;
    if (existingDatabase) {
      throw StateError('Encryption key unavailable for existing database');
    }
    final generated = const Uuid().v4() + const Uuid().v4();
    await _storage.write(key: _databaseKey, value: generated);
    return generated;
  }
}

class MemorySessionVault
    implements
        SessionVault,
        SayRingAppDisplayVault,
        HomeHealthCardsVault,
        RingInitializationVault,
        SyncDiagnosticsVault,
        RingInitializationOperationVault {
  final _syncDiagnostics = <String, Map<String, Object?>>{};
  @override
  Future<Map<String, Object?>?> readSyncDiagnostics(String owner) async =>
      _syncDiagnostics[owner] == null ? null : Map.of(_syncDiagnostics[owner]!);
  @override
  Future<void> writeSyncDiagnostics(
    String owner,
    Map<String, Object?> value,
  ) async {
    _syncDiagnostics[owner] = Map.of(value);
  }

  final Map<String, RingInitializationStage> ringInitializationStages = {};
  final Map<String, String> ringInitializationOperationIds = {};

  @override
  Future<String?> readRingInitializationOperationId(
    String owner,
    String deviceId,
  ) async => ringInitializationOperationIds['$owner\u0000$deviceId'];

  @override
  Future<void> writeRingInitializationRequest(
    String owner,
    String deviceId,
    String operationId,
  ) async {
    final key = '$owner\u0000$deviceId';
    if (!isValidRingInitializationOperationId(operationId) ||
        ringInitializationStages[key] !=
            RingInitializationStage.decisionRequired ||
        (ringInitializationOperationIds[key] != null &&
            ringInitializationOperationIds[key] != operationId)) {
      throw StateError('Cannot replace an uncertain ring decision');
    }
    ringInitializationOperationIds[key] = operationId;
  }

  @override
  Future<RingInitializationStage?> readRingInitializationStage(
    String owner,
    String deviceId,
  ) async => ringInitializationStages['$owner\u0000$deviceId'];

  @override
  Future<void> writeRingInitializationStage(
    String owner,
    String deviceId,
    RingInitializationStage stage,
  ) async {
    ringInitializationStages['$owner\u0000$deviceId'] = stage;
  }

  @override
  Future<void> clearRingInitializationStage(
    String owner,
    String deviceId,
  ) async {
    ringInitializationStages.remove('$owner\u0000$deviceId');
    ringInitializationOperationIds.remove('$owner\u0000$deviceId');
  }

  final Map<String, HomeHealthCardLayout> homeHealthCards = {};

  @override
  Future<HomeHealthCardLayout> readHomeHealthCards(String owner) async =>
      homeHealthCards[owner] ?? HomeHealthCardLayout();

  @override
  Future<void> writeHomeHealthCards(
    String owner,
    HomeHealthCardLayout layout,
  ) async {
    homeHealthCards[owner] = layout;
  }

  bool? sayRingHideAi;

  @override
  Future<bool?> readSayRingHideAi() async => sayRingHideAi;

  @override
  Future<void> writeSayRingHideAi(bool value) async => sayRingHideAi = value;

  Session? session;
  HealthWarningSettings healthWarningSettings = const HealthWarningSettings();
  String key = 'test-database-key-that-is-long-enough';
  List<Map<String, Object?>> shopCart = const [];
  String? pendingPushUnregisterInstallationId;
  bool privacyConsentGranted = false;
  bool legacyHealthMigrationHandled = false;
  final Map<String, Map<String, Object?>> globalCommerceDrafts = {};

  String _commerceDraftKey(String owner, String key) => '$owner\u0000$key';

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<bool> clearSessionIfUnchanged(Session expected) async {
    if (!_sameSession(session, expected)) return false;
    session = null;
    return true;
  }

  @override
  Future<String> databaseKey({bool existingDatabase = false}) async => key;

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

  @override
  Future<Map<String, Object?>?> readGlobalCommerceDraft(
    String owner,
    String key,
  ) async {
    final value = globalCommerceDrafts[_commerceDraftKey(owner, key)];
    return value == null ? null : Map<String, Object?>.from(value);
  }

  @override
  Future<void> writeGlobalCommerceDraft(
    String owner,
    String key,
    Map<String, Object?> value,
  ) async {
    globalCommerceDrafts[_commerceDraftKey(owner, key)] =
        Map<String, Object?>.from(value);
  }

  @override
  Future<void> clearGlobalCommerceDraft(String owner, String key) async {
    globalCommerceDrafts.remove(_commerceDraftKey(owner, key));
  }
}

bool _sameSession(Session? left, Session right) =>
    left != null &&
    left.accessToken == right.accessToken &&
    left.refreshToken == right.refreshToken &&
    left.memberId == right.memberId &&
    left.accountKey == right.accountKey;
