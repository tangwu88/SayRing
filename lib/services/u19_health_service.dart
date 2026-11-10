import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/u19_health_features.dart';
import 'api_client.dart';
import 'wearable_bridge.dart';

/// U19 的失败和撤销只关闭自身许可，不撤销已确认的戒指读取权限。
class U19HealthFeatureService extends ChangeNotifier {
  U19HealthFeatureService({
    required this.features,
    required this.api,
    required this.bridge,
  });
  final U19HealthFeatures features;
  final SayRingU19HealthApi api;
  final WearableU19HealthPolicyBridge bridge;
  Timer? _refreshTimer;
  Timer? _expiryTimer;
  Future<void>? _pending;
  Future<void> _native = Future.value();
  bool _disposed = false;
  bool _foreground = true;
  int _revision = 0;

  Future<void> _configure(U19HealthSnapshot? snapshot, Duration validity) {
    final operation = _native.then(
      (_) => bridge.configureU19HealthMetrics(
        snapshot?.readMetrics ?? const {},
        snapshot?.manualMetrics ?? const {},
        validity: validity,
      ),
    );
    _native = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    return _pending ??= _refresh().whenComplete(() => _pending = null);
  }

  Future<void> _refresh() async {
    // 前台恢复时先撤销已经到期的旧会话，再接受新许可，不能跨过过期屏障。
    if (features.hasLease && !features.active) await _close();
    var revision = _revision;
    final before = features.generation;
    try {
      final snapshot = await api.getU19HealthFeatures();
      if (_disposed || revision != _revision) return;
      if (!snapshot.readMetrics.containsAll(features.readMetrics) ||
          !snapshot.manualMetrics.containsAll(features.manualMetrics)) {
        await _close();
        if (_disposed) return;
        revision = _revision;
      }
      final wait = Stopwatch()..start();
      await _configure(snapshot, snapshot.validity);
      if (_disposed || revision != _revision) return;
      final remaining = snapshot.validity - wait.elapsed;
      if (remaining <= Duration.zero) {
        await _close();
        return;
      }
      features.replace(snapshot, remaining);
      _expiryTimer?.cancel();
      _expiryTimer = Timer(remaining, () => unawaited(_close()));
      if (before != features.generation) notifyListeners();
    } catch (_) {
      if (!_disposed && revision == _revision) await _close();
    } finally {
      if (!_disposed && _foreground) {
        _refreshTimer?.cancel();
        _refreshTimer = Timer(
          const Duration(seconds: 30),
          () => unawaited(refresh()),
        );
      }
    }
  }

  Future<void> _close() async {
    if (_disposed) return;
    _revision++;
    final before = features.generation;
    features.close();
    _expiryTimer?.cancel();
    if (before != features.generation) notifyListeners();
    try {
      await _configure(null, Duration.zero);
    } catch (_) {
      /* 原生许可独立到期。 */
    }
  }

  void setForeground(bool value) {
    _foreground = value;
    _refreshTimer?.cancel();
    if (value) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    features.close();
    unawaited(_configure(null, Duration.zero).catchError((Object _) {}));
    super.dispose();
  }
}
