import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../domain/models.dart';
import '../domain/sync_diagnostics.dart';
import '../domain/sync_read_evidence.dart';
import 'api_client.dart';
import 'secure_vault.dart';

/// One account's first connection only. A server reservation and an encrypted
/// local marker survive reinstall/reconnect independently from health storage.
/// Collection and retries never await or alter a BLE/measurement operation.
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
  String? _guestConnectionKind;
  String _connectionId = const Uuid().v4(), _reportId = const Uuid().v4();
  Stopwatch _elapsed = Stopwatch()..start();
  final List<SyncDiagnosticEvent> _events = [];
  Map<String, Object?> _lastSnapshot = {};
  Map<String, Object?>? _metadata;
  Future<void> _tasks = Future.value();
  Timer? _initialTimer, _retryTimer;
  int _generation = 0, _tasksPending = 0;
  bool _disposed = false,
      _attemptStarted = false,
      _frozen = false,
      _closed = false,
      _draftScheduled = false;
  String? lastReportId, status;
  bool _reservationAccepted = false;
  String? _collectionMember, _collectionAccount;
  Map<String, Object?>? _readEvidence;
  bool get canCollectReadEvidence =>
      _reservationAccepted &&
      session()?.memberId == _collectionMember &&
      session()?.accountKey == _collectionAccount &&
      !_disposed &&
      allowed() &&
      _attemptStarted &&
      !_closed &&
      !_frozen &&
      _metadata?['schemaVersion'] == 3;
  void recordReadEvidence(Map<String, Object?> evidence) {
    if (!canCollectReadEvidence || !isBoundedSyncReadEvidence(evidence)) return;
    _readEvidence = jsonDecode(jsonEncode(evidence)) as Map<String, Object?>;
  }

  bool get busy => _tasksPending > 0;
  bool get hasContext => _owner != null;
  int get connectionGeneration => _generation;
  List<SyncDiagnosticEvent> get events => List.unmodifiable(_events);

  static Future<Map<String, Object?>> _packageMetadata() async {
    final package = await PackageInfo.fromPlatform();
    String? osVersion;
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
        if (RegExp(r'^\d{1,2}(\.\d{1,4}){0,3}$').hasMatch(release)) {
          osVersion = release;
        }
      } catch (_) {
        /* Optional OS information is never a connection gate. */
      }
    }
    return {
      'osMajor': ?osMajor,
      'osVersion': ?osVersion,
      'appVersion': package.version,
      'buildNumber': int.tryParse(package.buildNumber) ?? 0,
      if (phone.isNotEmpty) 'phone': phone,
    };
  }

  bool _current(int generation, Session expected) =>
      !_disposed &&
      allowed() &&
      generation == _generation &&
      session()?.accountKey == expected.accountKey &&
      session()?.memberId == expected.memberId;

  Map<String, Object?> _boundedMetadata(
    Map<String, Object?> details, {
    required int version,
    required String platform,
    required String language,
  }) {
    final rawPhone = details['phone'];
    final phone = boundedDiagnosticPhone({
      if (rawPhone is Map) ...rawPhone,
      if (language.isNotEmpty) 'locale': language,
    }, platform);
    return {
      'schemaVersion': version,
      for (final key in ['appVersion', 'buildNumber', 'osMajor', 'osVersion'])
        if (details[key] != null) key: details[key],
      if (version >= 2 && phone.isNotEmpty) 'phone': phone,
    };
  }

  Future<Map<String, Object?>> _firstConnectionMetadata(
    Session expected,
  ) async {
    final details = await metadata().timeout(const Duration(seconds: 3));
    var version = 1;
    final remote = api;
    if (remote is SyncDiagnosticsVersionsApi) {
      try {
        final negotiated = await (remote as SyncDiagnosticsVersionsApi)
            .syncDiagnosticSchema(expected);
        if (negotiated == 2 || negotiated == 3) version = negotiated;
      } catch (_) {
        // A failed optional capability lookup keeps the existing V1 payload.
      }
    }
    return _boundedMetadata(
      details,
      version: version,
      platform: '${_lastSnapshot['platform']}',
      language: locale(),
    );
  }

  Future<Map<String, Object?>?> guestConnection(String language) async {
    if (_disposed ||
        _owner != 'anonymous' ||
        session() != null ||
        _guestConnectionKind == null ||
        !_events.any(
          (event) =>
              event.stage == SyncDiagnosticStage.connect &&
              (event.state == SyncDiagnosticState.ok ||
                  event.state == SyncDiagnosticState.failed),
        )) {
      return null;
    }
    final generation = _generation;
    final captured = _capture();
    try {
      final details = await metadata().timeout(const Duration(seconds: 3));
      if (_disposed || generation != _generation || session() != null) {
        return null;
      }
      final report = {
        ...captured,
        ..._boundedMetadata(
          details,
          version: 2,
          platform: '${captured['platform']}',
          language: language,
        ),
        'mode': 'automatic',
        'connectionKind': _guestConnectionKind,
      };
      return isBoundedDiagnosticReport(report) ? report : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _enqueue(Future<void> Function() task) {
    _tasksPending++;
    final result = _tasks
        .then((_) => task())
        .catchError((Object _) {
          // Diagnostic errors have no UI, health-upload or authentication effect.
        })
        .whenComplete(() {
          _tasksPending--;
        });
    _tasks = result;
    return result;
  }

  void begin(
    String owner,
    String? target, {
    bool connectionAttempt = false,
    String? connectionKind,
  }) {
    if (_owner != owner) {
      clear();
      _owner = owner;
    }
    if (owner == 'anonymous' && session() == null) {
      if (connectionKind != null) {
        _generation++;
        _target = target;
        _guestConnectionKind = connectionKind;
        _connectionId = const Uuid().v4();
        _reportId = const Uuid().v4();
        _elapsed = Stopwatch()..start();
        _events.clear();
      }
      return;
    }
    if (!connectionAttempt ||
        !allowed() ||
        session() == null ||
        api is! FirstConnectionDiagnosticsApi ||
        api is! SyncDiagnosticsApi ||
        vault is! SyncDiagnosticsVault) {
      return;
    }
    if (_attemptStarted) {
      if (!_closed && !_frozen && _target != target) {
        // Freeze the first target's last observed state, never the new target.
        _events.add(
          SyncDiagnosticEvent(
            SyncDiagnosticStage.connect,
            SyncDiagnosticState.blocked,
            SyncDiagnosticCode.cancelled,
            _elapsed.elapsedMilliseconds,
          ),
        );
        completeInitialSync(_generation, useLastSnapshot: true);
      }
      return;
    }
    _attemptStarted = true;
    _target = target;
    _connectionId = const Uuid().v4();
    _reportId = const Uuid().v4();
    _elapsed = Stopwatch()..start();
    _events.clear();
    _lastSnapshot = Map.of(snapshot());
    final generation = _generation, expected = session()!;
    _initialTimer = Timer(
      const Duration(minutes: 3),
      () => completeInitialSync(generation),
    );
    unawaited(
      _enqueue(() async {
        if (!_current(generation, expected)) return;
        final store = vault as SyncDiagnosticsVault;
        final state = await store.readSyncDiagnostics(owner) ?? {};
        if (!_current(generation, expected)) return;
        if (state['firstAttempt'] is Map) {
          // A later connection may only retry the frozen first summary.
          _closed = true;
          _frozen = true;
          _initialTimer?.cancel();
          final first = Map<String, Object?>.from(state['firstAttempt'] as Map);
          first['frozen'] = true;
          state['firstAttempt'] = first;
          await store.writeSyncDiagnostics(owner, state);
          if (_current(generation, expected)) {
            await _retryState(state, generation, expected, owner);
          }
          return;
        }
        final details = await _firstConnectionMetadata(expected);
        if (!_current(generation, expected)) return;
        _metadata = details;
        state['firstAttempt'] = {
          'connectionId': _connectionId,
          'frozen': false,
        };
        state['draft'] = _capture();
        await store.writeSyncDiagnostics(owner, state);
        if (_current(generation, expected)) {
          await _retryState(state, generation, expected, owner);
        }
      }),
    );
  }

  Map<String, Object?> _capture() => {
    ..._lastSnapshot,
    ...?_metadata,
    'schemaVersion': _metadata?['schemaVersion'] ?? 1,
    'product': 'say-ring',
    'mode': 'first_connection',
    'connectionId': _connectionId,
    'reportId': _reportId,
    'stages': _events.take(16).map((e) => e.toJson()).toList(),
    if (_metadata?['schemaVersion'] == 3 && _readEvidence != null)
      'readEvidence': _readEvidence,
  };

  void record(
    SyncDiagnosticStage stage,
    SyncDiagnosticState state, {
    SyncDiagnosticCode code = SyncDiagnosticCode.none,
    int? received,
    int? saved,
    int? uploaded,
    int? rejected,
  }) {
    final guest =
        _owner == 'anonymous' &&
        session() == null &&
        _guestConnectionKind != null;
    if (_disposed ||
        (!guest && (!allowed() || !_attemptStarted || _closed || _frozen))) {
      return;
    }
    _events.removeWhere((e) => e.stage == stage);
    _events.add(
      SyncDiagnosticEvent(
        stage,
        state,
        code,
        _elapsed.elapsedMilliseconds,
        received: received,
        saved: saved,
        uploaded: uploaded,
        rejected: rejected,
      ),
    );
    _lastSnapshot = Map.of(snapshot());
    if (guest) return;
    if (stage == SyncDiagnosticStage.connect &&
        state == SyncDiagnosticState.failed) {
      completeInitialSync(_generation);
      return;
    }
    if (_draftScheduled) return;
    _draftScheduled = true;
    final generation = _generation, expected = session();
    if (expected == null) {
      _draftScheduled = false;
      return;
    }
    unawaited(
      _enqueue(() async {
        try {
          if (!_current(generation, expected) || _frozen || _closed) return;
          final state =
              await (vault as SyncDiagnosticsVault).readSyncDiagnostics(
                _owner!,
              ) ??
              {};
          if (!_current(generation, expected) || _frozen || _closed) return;
          if ((state['firstAttempt'] as Map?)?['connectionId'] !=
              _connectionId) {
            return;
          }
          state['draft'] = _capture();
          await (vault as SyncDiagnosticsVault).writeSyncDiagnostics(
            _owner!,
            state,
          );
        } finally {
          if (generation == _generation) _draftScheduled = false;
        }
      }),
    );
  }

  void completeInitialSync(int generation, {bool useLastSnapshot = false}) {
    if (_disposed ||
        generation != _generation ||
        !_attemptStarted ||
        _frozen ||
        _closed) {
      return;
    }
    _frozen = true;
    _initialTimer?.cancel();
    if (!useLastSnapshot) _lastSnapshot = Map.of(snapshot());
    final captured = jsonDecode(jsonEncode(_capture())) as Map<String, Object?>;
    final expected = session(), owner = _owner;
    if (expected == null || owner == null) return;
    unawaited(
      _enqueue(() async {
        if (!_current(generation, expected)) return;
        final state =
            await (vault as SyncDiagnosticsVault).readSyncDiagnostics(owner) ??
            {};
        if (!_current(generation, expected)) return;
        final first = Map<String, Object?>.from(
          state['firstAttempt'] as Map? ?? {},
        );
        if (first['connectionId'] != captured['connectionId']) return;
        first['frozen'] = true;
        state['firstAttempt'] = first;
        state['draft'] = {...captured, ...?_metadata};
        await (vault as SyncDiagnosticsVault).writeSyncDiagnostics(
          owner,
          state,
        );
        if (_current(generation, expected)) {
          await _retryState(state, generation, expected, owner);
        }
      }),
    );
  }

  void authorizeFirstBinding(String target, String operationId) {
    if (!_attemptStarted ||
        _target != target ||
        _disposed ||
        session() == null ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(operationId)) {
      return;
    }
    final generation = _generation, expected = session()!, owner = _owner!;
    unawaited(
      _enqueue(() async {
        if (!_current(generation, expected)) return;
        final state =
            await (vault as SyncDiagnosticsVault).readSyncDiagnostics(owner) ??
            {};
        if (!_current(generation, expected)) return;
        final first = Map<String, Object?>.from(
          state['firstAttempt'] as Map? ?? {},
        );
        if (first['connectionId'] != _connectionId ||
            first['completed'] == true) {
          return;
        }
        // A genuine existing first-binding receipt repairs only the diagnostic
        // reservation race; it never requests another initialization decision.
        first['firstBindingOperationId'] = operationId;
        if (first['reason'] == 'has_binding_history') first.remove('refused');
        state['firstAttempt'] = first;
        state.remove('retryAfter');
        _closed = first['refused'] == true;
        await (vault as SyncDiagnosticsVault).writeSyncDiagnostics(
          owner,
          state,
        );
        if (_current(generation, expected)) {
          await _retryState(state, generation, expected, owner);
        }
      }),
    );
  }

  Future<void> _retryState(
    Map<String, Object?> state,
    int generation,
    Session expected,
    String owner,
  ) async {
    if (!_current(generation, expected)) return;
    final first = Map<String, Object?>.from(
      state['firstAttempt'] as Map? ?? {},
    );
    if (first['completed'] == true ||
        first['refused'] == true ||
        first['connectionId'] is! String) {
      return;
    }
    final deadline = state['retryAfter'];
    if (deadline is int && deadline > clock().millisecondsSinceEpoch) {
      _scheduleRetry(deadline, generation, expected);
      return;
    }
    final store = vault as SyncDiagnosticsVault;
    try {
      if (first['accepted'] != true) {
        final result = await (api as FirstConnectionDiagnosticsApi)
            .beginFirstConnectionDiagnostics(
              expected,
              first['connectionId'] as String,
              firstBindingOperationId:
                  first['firstBindingOperationId'] as String?,
            );
        if (!_current(generation, expected)) return;
        if (result['connectionId'] != first['connectionId'] ||
            result['accepted'] is! bool) {
          throw StateError('Unknown first-connection receipt');
        }
        if (result['accepted'] != true) {
          first['refused'] = true;
          first['reason'] = result['reason'] == 'has_binding_history'
              ? 'has_binding_history'
              : 'already_started';
          state['firstAttempt'] = first;
          _closed = true;
          _initialTimer?.cancel();
          await store.writeSyncDiagnostics(owner, state);
          return;
        }
        _reservationAccepted = true;
        _collectionMember = expected.memberId;
        _collectionAccount = expected.accountKey;
        first['accepted'] = true;
        first.remove('refused');
        state['firstAttempt'] = first;
        if (first['connectionId'] == _connectionId && !_frozen) {
          _closed = false;
          if (_initialTimer?.isActive != true) {
            _initialTimer = Timer(
              const Duration(minutes: 3),
              () => completeInitialSync(generation),
            );
          }
        }
        await store.writeSyncDiagnostics(owner, state);
      }
      if (!_current(generation, expected) || first['frozen'] != true) return;
      final pending = state['pending'];
      final draft =
          pending is Map &&
              pending['mode'] == 'first_connection' &&
              pending['connectionId'] == first['connectionId']
          ? pending
          : state['draft'];
      if (draft is! Map) return;
      final captured = draft.map((k, v) => MapEntry('$k', v));
      final report = captured['schemaVersion'] == 1
          ? syncDiagnosticForV1(captured)
          : captured;
      if (report['mode'] != 'first_connection' ||
          report['connectionId'] != first['connectionId'] ||
          !isBoundedDiagnosticReport(report)) {
        return;
      }
      state['pending'] = jsonDecode(jsonEncode(report));
      await store.writeSyncDiagnostics(owner, state);
      if (!_current(generation, expected)) return;
      final response = await (api as SyncDiagnosticsApi).submitSyncDiagnostics(
        expected,
        report,
      );
      if (!_current(generation, expected)) return;
      if (response['reportId'] != report['reportId'] ||
          response['accepted'] is! bool) {
        throw StateError('Unconfirmed diagnostic receipt');
      }
      if (response['accepted'] == true) {
        first['completed'] = true;
        state['firstAttempt'] = first;
        state.remove('pending');
        state.remove('draft');
        state.remove('retryAfter');
        lastReportId = report['reportId'] as String;
        _closed = true;
        _retryTimer?.cancel();
      } else if (const {
        'first_connection_only',
        'already_reported',
        'collection_not_active',
        'report_conflict',
      }.contains(response['reason'])) {
        first['refused'] = true;
        state['firstAttempt'] = first;
        _closed = true;
        _retryTimer?.cancel();
      } else {
        final retry = response['retryAfterSeconds'];
        state['retryAfter'] =
            clock().millisecondsSinceEpoch +
            Duration(
              seconds: retry is num ? retry.toInt().clamp(60, 86400) : 900,
            ).inMilliseconds;
      }
      await store.writeSyncDiagnostics(owner, state);
      if (state['retryAfter'] is int) {
        _scheduleRetry(state['retryAfter'] as int, generation, expected);
      }
    } catch (_) {
      if (!_current(generation, expected)) return;
      state['retryAfter'] = clock()
          .add(const Duration(minutes: 15))
          .millisecondsSinceEpoch;
      try {
        await store.writeSyncDiagnostics(owner, state);
        _scheduleRetry(state['retryAfter'] as int, generation, expected);
      } catch (_) {}
    }
  }

  void _scheduleRetry(int deadline, int generation, Session expected) {
    _retryTimer?.cancel();
    if (!_current(generation, expected)) return;
    _retryTimer = Timer(
      Duration(
        milliseconds: (deadline - clock().millisecondsSinceEpoch).clamp(
          1000,
          86400000,
        ),
      ),
      () {
        if (_current(generation, expected)) flushPending();
      },
    );
  }

  void flushPending() {
    final expected = session(), owner = _owner, generation = _generation;
    if (expected == null ||
        owner == null ||
        !allowed() ||
        api is! FirstConnectionDiagnosticsApi ||
        api is! SyncDiagnosticsApi ||
        vault is! SyncDiagnosticsVault) {
      return;
    }
    unawaited(
      _enqueue(() async {
        if (!_current(generation, expected)) return;
        final state =
            await (vault as SyncDiagnosticsVault).readSyncDiagnostics(owner) ??
            {};
        if (_current(generation, expected)) {
          await _retryState(state, generation, expected, owner);
        }
      }),
    );
  }

  Future<String?> send({
    String mode = 'manual',
    bool pendingOnly = false,
  }) async {
    // Kept for the retired internal page/API ABI, with no manual data upload.
    if (pendingOnly) flushPending();
    return '首次连接摘要由系统自动提交，无需手动操作';
  }

  void clear({String? discardPendingFor}) {
    _generation++;
    _initialTimer?.cancel();
    _retryTimer?.cancel();
    _owner = null;
    _target = null;
    _guestConnectionKind = null;
    _metadata = null;
    _reservationAccepted = false;
    _collectionMember = _collectionAccount = null;
    _readEvidence = null;
    _attemptStarted = false;
    _closed = false;
    _frozen = false;
    _draftScheduled = false;
    _events.clear();
    _lastSnapshot = {};
    lastReportId = null;
    status = null;
  }

  void dispose() {
    _disposed = true;
    clear();
  }
}
