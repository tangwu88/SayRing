import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../domain/wellness_release_policy.dart';
import 'api_client.dart';
import 'wearable_bridge.dart';

/// Uniform first-party feature publication, not an App Review mode. Grants
/// are never persisted, and cannot add commands outside the native ceiling.
class ReadOnlyHealthFeatureService extends ChangeNotifier {
  ReadOnlyHealthFeatureService({
    required this.policy,
    required this.api,
    required this.bridge,
  });

  final WellnessReleasePolicy policy;
  final SayRingReadOnlyHealthApi api;
  final WearableReadOnlyHealthPolicyBridge bridge;
  Future<void>? _pending;
  Timer? _refreshTimer;
  Timer? _expiryTimer;
  bool _foreground = true;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _nativePending = Future.value();

  Future<void> _configure(Set<HealthMetric> metrics, Duration validity) {
    final operation = _nativePending.then(
      (_) => bridge.configureReadOnlyHealthMetrics(metrics, validity: validity),
    );
    _nativePending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    return _pending ??= _refresh().whenComplete(() => _pending = null);
  }

  Future<void> _refresh() async {
    final generation = _generation;
    final features = policy.readOnlyFeatures!;
    final before = features.metrics.toSet();
    try {
      final snapshot = await api.getReadOnlyHealthFeatures();
      if (_disposed || generation != _generation) return;
      await _configure(snapshot.metrics, snapshot.validity);
      if (_disposed || generation != _generation) return;
      features.replace(snapshot.metrics, snapshot.validity);
      _expiryTimer?.cancel();
      _expiryTimer = Timer(snapshot.validity, () => unawaited(_close()));
    } catch (_) {
      if (!_disposed && generation == _generation) await _close();
      return;
    } finally {
      if (!_disposed && _foreground) {
        _refreshTimer?.cancel();
        _refreshTimer = Timer(
          const Duration(seconds: 30),
          () => unawaited(refresh()),
        );
      }
    }
    if (!setEquals(before, features.metrics) && !_disposed) notifyListeners();
  }

  Future<void> _close() async {
    if (_disposed) return;
    _generation++;
    final hadGrant = policy.readOnlyFeatures!.expiresAt != null;
    policy.readOnlyFeatures!.close();
    _expiryTimer?.cancel();
    if (hadGrant) notifyListeners();
    try {
      await _configure(const <HealthMetric>{}, Duration.zero);
    } catch (_) {
      // Dart is already closed; each native adapter's monotonic lease expires.
    }
  }

  void setForeground(bool value) {
    _foreground = value;
    _refreshTimer?.cancel();
    if (!value) return;
    if (policy.readOnlyFeatures!.metrics.isEmpty) notifyListeners();
    unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    policy.readOnlyFeatures!.close();
    unawaited(_configure(const {}, Duration.zero).catchError((Object _) {}));
    super.dispose();
  }
}
