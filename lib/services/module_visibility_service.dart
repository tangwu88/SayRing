import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/module_visibility.dart';
import 'api_client.dart';

class ModuleVisibilityService extends ChangeNotifier {
  ModuleVisibilityService({required this.lease, required this.api});
  final ModuleVisibilityLease lease;
  final SayRingModuleVisibilityApi api;
  Future<void>? _pending;
  Timer? _refreshTimer;
  Timer? _expiryTimer;
  bool _foreground = true;
  bool _disposed = false;

  Future<void> refresh() => _disposed
      ? Future.value()
      : _pending ??= _refresh().whenComplete(() => _pending = null);

  Future<void> _refresh() async {
    if (lease.expired) _close();
    if (_disposed) return;
    final started = Stopwatch()..start();
    final before = lease.generation;
    try {
      final snapshot = await api.getModuleVisibility().timeout(
        const Duration(seconds: 15),
      );
      if (_disposed) return;
      final validity = snapshot.validity - started.elapsed;
      if (validity <= Duration.zero) {
        _close();
      } else {
        lease.replace(snapshot.modules, validity);
        _expiryTimer?.cancel();
        _expiryTimer = Timer(validity, _close);
        if (before != lease.generation) notifyListeners();
      }
    } catch (_) {
      if (!_disposed) _close();
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

  void _close() {
    _expiryTimer?.cancel();
    lease.close();
    if (!_disposed) notifyListeners();
  }

  void setForeground(bool value) {
    _foreground = value;
    _refreshTimer?.cancel();
    if (value && !_disposed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    lease.close();
    super.dispose();
  }
}
