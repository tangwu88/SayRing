import 'package:flutter/widgets.dart';

/// Filters watch shutter callbacks that arrive while the app is backgrounded
/// or while the vendor camera command is still being activated.
class CameraRemoteShutterGate {
  CameraRemoteShutterGate({
    required int initialSequence,
    this.activationGracePeriod = const Duration(seconds: 1),
  }) : _seenSequence = initialSequence;

  final Duration activationGracePeriod;

  int _seenSequence;
  bool _foreground = true;
  bool _armed = false;
  DateTime? _readyAt;

  void setLifecycleState(
    AppLifecycleState state, {
    required int currentSequence,
  }) {
    _foreground = state == AppLifecycleState.resumed;
    _seenSequence = currentSequence > _seenSequence
        ? currentSequence
        : _seenSequence;
    if (!_foreground) disarm(currentSequence: currentSequence);
  }

  void arm({required DateTime now, required int currentSequence}) {
    _seenSequence = currentSequence > _seenSequence
        ? currentSequence
        : _seenSequence;
    _armed = true;
    _readyAt = now.add(activationGracePeriod);
  }

  void disarm({required int currentSequence}) {
    _seenSequence = currentSequence > _seenSequence
        ? currentSequence
        : _seenSequence;
    _armed = false;
    _readyAt = null;
  }

  bool shouldCapture({required int sequence, required DateTime now}) {
    if (sequence <= _seenSequence) return false;
    _seenSequence = sequence;
    final readyAt = _readyAt;
    return _foreground && _armed && readyAt != null && !now.isBefore(readyAt);
  }
}
