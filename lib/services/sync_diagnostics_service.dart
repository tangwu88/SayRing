import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  final Future<Map<String, Object?>> Function() metadata;
  final DateTime Function() clock;
  String? _owner, _target;
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
    if (!kIsWeb) {
      try {
        final info = DeviceInfoPlugin();
        final release = switch (defaultTargetPlatform) {
          TargetPlatform.android => (await info.androidInfo).version.release,
          TargetPlatform.iOS => (await info.iosInfo).systemVersion,
          _ => '',
        };
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
    };
  }

  void begin(String owner, String? target) {
    if (_owner == owner && _target == target && _events.isNotEmpty) return;
    _generation++;
    _owner = owner;
    _target = target;
    _connectionId = const Uuid().v4();
    _elapsed = Stopwatch()..start();
    _events.clear();
    lastReportId = null;
    status = null;
    _inFlight = null;
  }

  void clear() {
    _generation++;
    _owner = null;
    _target = null;
    _events.clear();
    lastReportId = null;
    status = null;
    _inFlight = null;
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

  Future<String?> send({String mode = 'manual', bool pendingOnly = false}) {
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
    final captured = <String, Object?>{
      ...snapshot(),
      'schemaVersion': 1,
      'product': 'say-ring',
      'reportId': const Uuid().v4(),
      'connectionId': _connectionId,
      'mode': const {'automatic', 'manual', 'recovery'}.contains(mode)
          ? mode
          : 'manual',
      'stages': _events.map((e) => e.toJson()).toList(),
    };
    final generation = _generation, expected = session()!, owner = _owner!;
    final task = _send(captured, generation, expected, owner, pendingOnly);
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
      if (pendingOnly && pending is! Map) return null;
      int deadline(String key) => state[key] is int ? state[key] as int : 0;
      if (now < deadline('retryAfter') ||
          (isAutomatic &&
              (now < deadline('automaticAfter') ||
                  now < deadline('unsupportedAfter')))) {
        return isAutomatic ? null : '提交较频繁，请稍后再试';
      }
      _metadata ??= await metadata().timeout(const Duration(seconds: 3));
      if (!_current(generation, expected)) return null;
      final report = pendingOnly && pending is Map
          ? pending.map((k, v) => MapEntry('$k', v))
          : <String, Object?>{...captured, ..._metadata!};
      if (!isBoundedDiagnosticReport(report)) return '诊断摘要无法提交，请稍后重试';
      state['pending'] = jsonDecode(jsonEncode(report));
      if (isAutomatic) {
        state['automaticAfter'] =
            now + const Duration(minutes: 15).inMilliseconds;
      }
      await _write(owner, state, generation, expected);
      if (!_current(generation, expected)) return null;
      final remote = api as SyncDiagnosticsApi;
      if (!await remote.supportsSyncDiagnostics(expected)) {
        if (_current(generation, expected)) {
          state['unsupportedAfter'] =
              now + const Duration(hours: 24).inMilliseconds;
          await _write(owner, state, generation, expected);
        }
        return '后台诊断服务尚未更新，请稍后重试';
      }
      if (!_current(generation, expected)) return null;
      final response = await remote.submitSyncDiagnostics(expected, report);
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
