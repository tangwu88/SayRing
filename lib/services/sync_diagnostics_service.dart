import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../domain/models.dart';
import '../domain/sync_diagnostics.dart';
import 'api_client.dart';
import 'secure_vault.dart';

/// Account-scoped, small outbox. No timers, raw payloads or diagnostic-on-error
/// recursion; ordinary connection/measurement work never waits for this service.
class SyncDiagnosticsService {
  SyncDiagnosticsService({
    required this.vault,
    required this.api,
    required this.session,
    required this.allowed,
    required this.snapshot,
    required this.onChanged,
    this.locale = _noLocale,
    Future<Map<String, Object?>> Function()? metadata,
    DateTime Function()? clock,
  }) : metadata = metadata ?? _packageMetadata,
       clock = clock ?? DateTime.now;
  final SessionVault vault;
  final SaydianApi api;
  final Session? Function() session;
  final bool Function() allowed;
  final Map<String, Object?> Function() snapshot;
  final void Function() onChanged;
  final String Function() locale;
  static String _noLocale() => '';
  final Future<Map<String, Object?>> Function() metadata;
  final DateTime Function() clock;
  String? _owner, _target;
  String? _connectionKind;
  bool _successPending = false;
  String _connectionId = const Uuid().v4();
  Stopwatch _elapsed = Stopwatch()..start();
  final List<SyncDiagnosticEvent> _events = [];
  Map<String, Object?>? _metadata;
  Future<String?>? _inFlight;
  Future<void> _writes = Future.value();
  int _generation = 0;
  bool _disposed = false;
  String? lastReportId;
  String? status;
  bool get busy => _inFlight != null;
  bool get hasContext => _owner != null;
  List<SyncDiagnosticEvent> get events => List.unmodifiable(_events);

  static Future<Map<String, Object?>> _packageMetadata() async {
    final package = await PackageInfo.fromPlatform();
    int? osMajor;
    var phone = <String, Object?>{};
    if (!kIsWeb) {
      try {
        final info = DeviceInfoPlugin();
        var release = '';
        if (defaultTargetPlatform == TargetPlatform.android) {
          final android = await info.androidInfo;
          release = android.version.release;
          phone = {
            'brand': android.brand,
            'modelId': android.model,
            // Product codenames and personalized Android device names are not
            // verified retail names. Do not read either as a model name.
            'osBuild': android.id,
            'apiLevel': android.version.sdkInt,
          };
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final ios = await info.iosInfo;
          release = ios.systemVersion;
          phone = {
            'brand': 'Apple',
            'modelId': ios.utsname.machine,
            if (ios.modelName != ios.utsname.machine &&
                ios.modelName != ios.model)
              'modelName': ios.modelName,
          };
          try {
            final build = await const MethodChannel(
              'cn.saydian.ring/diagnostics',
            ).invokeMethod<String>('systemBuild');
            if (build != null) phone['osBuild'] = build;
          } on PlatformException {
            // iOS build numbers are optional on unsupported hosts.
          } on MissingPluginException {
            // Widgets and older platform bridges may not provide this method.
          }
        }
        phone['osVersion'] = release;
        osMajor = int.tryParse(
          RegExp(r'^\d{1,2}').firstMatch(release)?.group(0) ?? '',
        );
      } catch (_) {
        /* OS metadata is optional, never a reporting prerequisite. */
      }
    }
    return {
      'osMajor': ?osMajor,
      'appVersion': package.version,
      'buildNumber': int.tryParse(package.buildNumber) ?? 0,
      if (phone.isNotEmpty) 'phone': phone,
    };
  }

  void begin(String owner, String? target, {String? connectionKind}) {
    if (connectionKind == null &&
        _owner == owner &&
        _target == target &&
        _events.isNotEmpty) {
      return;
    }
    _generation++;
    _owner = owner;
    _target = target;
    _connectionKind = connectionKind;
    _successPending = false;
    _connectionId = const Uuid().v4();
    _elapsed = Stopwatch()..start();
    _events.clear();
    lastReportId = null;
    status = null;
    _inFlight = null;
  }

  void clear({String? discardPendingFor}) {
    _generation++;
    _owner = null;
    _target = null;
    _connectionKind = null;
    _successPending = false;
    _events.clear();
    lastReportId = null;
    status = null;
    _inFlight = null;
    final storage = vault;
    if (discardPendingFor == null ||
        discardPendingFor == 'anonymous' ||
        storage is! SyncDiagnosticsVault) {
      return;
    }
    final slot = storage as SyncDiagnosticsVault;
    // Serialize after any previous writes to this slot. Only the unsent
    // payload is removed; never delete health data or another owner's limits.
    _writes = _writes
        .catchError((Object _) {})
        .then((_) async {
          final state = await slot.readSyncDiagnostics(discardPendingFor);
          if (state == null || !state.containsKey('pending')) return;
          await slot.writeSyncDiagnostics(
            discardPendingFor,
            {...state}..remove('pending'),
          );
        })
        .catchError((Object _) {});
  }

  void record(
    SyncDiagnosticStage stage,
    SyncDiagnosticState state, {
    SyncDiagnosticCode code = SyncDiagnosticCode.none,
    int? received,
    int? saved,
    int? uploaded,
    int? rejected,
  }) {
    if (_disposed || _owner == null) return;
    final event = SyncDiagnosticEvent(
      stage,
      state,
      code,
      _elapsed.elapsedMilliseconds,
      received: received,
      saved: saved,
      uploaded: uploaded,
      rejected: rejected,
    );
    // Coalesce consecutive progress updates, retaining stage transitions.
    if (_events.isNotEmpty &&
        _events.last.stage == stage &&
        _events.last.state == state) {
      _events.removeLast();
    }
    _events.add(event);
    if (_events.length > 16) _events.removeAt(0);
    if (state == SyncDiagnosticState.failed ||
        state == SyncDiagnosticState.partial ||
        state == SyncDiagnosticState.blocked ||
        (state == SyncDiagnosticState.empty &&
            code == SyncDiagnosticCode.noData)) {
      unawaited(send(mode: 'automatic'));
    }
  }

  void connectionCompleted() {
    record(SyncDiagnosticStage.connect, SyncDiagnosticState.ok);
    _successPending = true;
  }

  // Called at real connection boundaries, after application state has the
  // correct capabilities, firmware and current owner. A native retry does not
  // open a new reporting channel or bypass the normal debounce.
  void flushConnection() {
    if (!_successPending || _disposed || _owner == null) return;
    _successPending = false;
    unawaited(send(mode: 'automatic', connectionOnly: true));
  }

  Future<Map<String, Object?>?> guestConnection(String locale) async {
    if (_disposed ||
        _owner != 'anonymous' ||
        session() != null ||
        _connectionKind == null ||
        !_events.any(
          (e) =>
              e.stage == SyncDiagnosticStage.connect &&
              (e.state == SyncDiagnosticState.ok ||
                  e.state == SyncDiagnosticState.failed),
        )) {
      return null;
    }
    final generation = _generation;
    final captured = _capture('automatic');
    try {
      final info = _metadata ??= await metadata().timeout(
        const Duration(seconds: 3),
      );
      if (_disposed || _generation != generation || session() != null) {
        return null;
      }
      final report = _withMetadata(captured, info, locale, version: 2);
      return isBoundedDiagnosticReport(report) ? report : null;
    } catch (_) {
      return null;
    }
  }

  bool _current(int generation, Session owner) =>
      !_disposed &&
      allowed() &&
      generation == _generation &&
      session()?.accountKey == owner.accountKey &&
      session()?.memberId == owner.memberId;

  Future<void> _write(
    String owner,
    Map<String, Object?> state,
    int generation,
    Session expected,
  ) {
    final next = _writes.catchError((Object _) {}).then((_) async {
      if (_current(generation, expected)) {
        await (vault as SyncDiagnosticsVault).writeSyncDiagnostics(
          owner,
          state,
        );
      }
    });
    _writes = next;
    return next;
  }

  Map<String, Object?> _capture(String mode) => {
    ...snapshot(),
    'schemaVersion': 1,
    'product': 'say-ring',
    'reportId': const Uuid().v4(),
    'connectionId': _connectionId,
    'mode': const {'automatic', 'manual', 'recovery'}.contains(mode)
        ? mode
        : 'manual',
    if (_connectionKind != null) 'connectionKind': _connectionKind,
    'stages': _events.map((e) => e.toJson()).toList(),
  };

  Map<String, Object?> _withMetadata(
    Map<String, Object?> captured,
    Map<String, Object?> metadata,
    String language, {
    required int version,
  }) {
    final rawPhone = metadata['phone'];
    final phone = boundedDiagnosticPhone({
      if (rawPhone is Map) ...rawPhone,
      if (language.isNotEmpty) 'locale': language,
    }, captured['platform']);
    return {
      ...captured,
      'schemaVersion': version,
      for (final key in ['appVersion', 'buildNumber', 'osMajor'])
        if (metadata[key] != null) key: metadata[key],
      if (version == 2 && phone.isNotEmpty) 'phone': phone,
    }..removeWhere((key, _) => version == 1 && key == 'connectionKind');
  }

  Future<String?> send({
    String mode = 'manual',
    bool pendingOnly = false,
    bool connectionOnly = false,
  }) {
    final active = _inFlight;
    if (active != null) return active;
    if (_disposed || !allowed() || session() == null) {
      return Future.value('登录并同意隐私政策后可提交诊断');
    }
    if (api is! SyncDiagnosticsApi ||
        vault is! SyncDiagnosticsVault ||
        _owner == null) {
      return Future.value('当前版本暂不支持提交诊断');
    }
    final captured = _capture(mode);
    final generation = _generation, expected = session()!, owner = _owner!;
    final task = _send(
      captured,
      generation,
      expected,
      owner,
      pendingOnly,
      connectionOnly,
    );
    _inFlight = task;
    onChanged();
    unawaited(
      task
          .then((message) {
            if (_current(generation, expected)) {
              status = message;
              onChanged();
            }
          })
          .whenComplete(() {
            if (identical(_inFlight, task)) {
              _inFlight = null;
              if (!_disposed) onChanged();
            }
          }),
    );
    return task;
  }

  Future<String?> _send(
    Map<String, Object?> captured,
    int generation,
    Session expected,
    String owner,
    bool pendingOnly,
    bool connectionOnly,
  ) async {
    Map<String, Object?> state = {};
    try {
      await _writes.catchError((Object _) {});
      if (!_current(generation, expected)) return null;
      state =
          await (vault as SyncDiagnosticsVault).readSyncDiagnostics(owner) ??
          {};
      if (!_current(generation, expected)) return null;
      final now = clock().millisecondsSinceEpoch;
      final pending = state['pending'];
      final isAutomatic = captured['mode'] == 'automatic';
      final deadlineKey = connectionOnly ? 'connectionAfter' : 'automaticAfter';
      if (pendingOnly && pending is! Map) return null;
      int deadline(String key) => state[key] is int ? state[key] as int : 0;
      if (now < deadline('retryAfter') ||
          (isAutomatic &&
              (now < deadline(deadlineKey) ||
                  now < deadline('unsupportedAfter')))) {
        return isAutomatic ? null : '提交较频繁，请稍后再试';
      }
      _metadata ??= await metadata().timeout(const Duration(seconds: 3));
      if (!_current(generation, expected)) return null;
      final report = pending is Map && (pendingOnly || connectionOnly)
          ? pending.map((k, v) => MapEntry('$k', v))
          : _withMetadata(captured, _metadata!, locale(), version: 2);
      if (!isBoundedDiagnosticReport(report)) return '诊断摘要无法提交，请稍后重试';
      state['pending'] = jsonDecode(jsonEncode(report));
      if (isAutomatic) {
        state[deadlineKey] = now + const Duration(minutes: 15).inMilliseconds;
      }
      await _write(owner, state, generation, expected);
      if (!_current(generation, expected)) return null;
      final remote = api as SyncDiagnosticsApi;
      final version = remote is SyncDiagnosticsVersionsApi
          ? await (remote as SyncDiagnosticsVersionsApi).syncDiagnosticSchema(
              expected,
            )
          : await remote.supportsSyncDiagnostics(expected)
          ? 1
          : 0;
      if (version == 0) {
        if (_current(generation, expected)) {
          state['unsupportedAfter'] =
              now + const Duration(hours: 24).inMilliseconds;
          await _write(owner, state, generation, expected);
        }
        return '后台诊断服务尚未更新，请稍后重试';
      }
      if (!_current(generation, expected)) return null;
      if (version == 1 && connectionOnly && pending is! Map) {
        // Successful connections are a V2 diagnostic; do not consume V1
        // failure-report quotas when a deployment is still on the old server.
        state.remove('pending');
        await _write(owner, state, generation, expected);
        return null;
      }
      final request = version == 2 ? report : syncDiagnosticForV1(report);
      final response = await remote.submitSyncDiagnostics(expected, request);
      if (!_current(generation, expected)) return null;
      if (response['reportId'] != report['reportId'] ||
          response['accepted'] is! bool) {
        throw StateError('Unconfirmed diagnostic receipt');
      }
      if (response['accepted'] == true) {
        state.remove('pending');
        state.remove('retryAfter');
        state.remove('unsupportedAfter');
        lastReportId = report['reportId'] as String;
        await _write(owner, state, generation, expected);
        return '诊断已提交，可将诊断编号提供给客服';
      }
      final retry = response['retryAfterSeconds'];
      state['retryAfter'] =
          now +
          Duration(
            seconds: retry is num ? retry.toInt().clamp(60, 3600) : 900,
          ).inMilliseconds;
      await _write(owner, state, generation, expected);
      return '提交较频繁，摘要已保留，可稍后重试';
    } catch (_) {
      // Retain a bounded outbox if dispatch failed. Never report a reporting
      // failure back into the diagnostic collector or affect health operations.
      if (_current(generation, expected)) {
        state['retryAfter'] = clock()
            .add(const Duration(minutes: 15))
            .millisecondsSinceEpoch;
        try {
          await _write(owner, state, generation, expected);
        } catch (_) {}
      }
      return '暂时无法提交诊断，已有摘要保留在本机';
    }
  }

  void flushPending() {
    if (!_disposed && allowed() && session() != null) {
      unawaited(send(mode: 'automatic', pendingOnly: true));
    }
  }

  void dispose() {
    _disposed = true;
    clear();
  }
}
