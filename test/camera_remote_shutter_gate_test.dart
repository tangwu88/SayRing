import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/camera_remote_shutter_gate.dart';

void main() {
  test('ignores callbacks received while app is backgrounded', () {
    final now = DateTime(2026, 8, 29, 15);
    final gate = CameraRemoteShutterGate(initialSequence: 3);
    gate.arm(now: now, currentSequence: 3);
    gate.setLifecycleState(AppLifecycleState.paused, currentSequence: 3);

    expect(
      gate.shouldCapture(sequence: 4, now: now.add(const Duration(seconds: 2))),
      isFalse,
    );

    gate.setLifecycleState(AppLifecycleState.resumed, currentSequence: 4);
    gate.arm(now: now.add(const Duration(seconds: 3)), currentSequence: 4);
    expect(
      gate.shouldCapture(sequence: 4, now: now.add(const Duration(seconds: 5))),
      isFalse,
    );
  });

  test('ignores activation callback and accepts one later shutter', () {
    final now = DateTime(2026, 8, 29, 15);
    final gate = CameraRemoteShutterGate(initialSequence: 10);
    gate.arm(now: now, currentSequence: 10);

    expect(
      gate.shouldCapture(
        sequence: 11,
        now: now.add(const Duration(milliseconds: 500)),
      ),
      isFalse,
    );
    expect(
      gate.shouldCapture(
        sequence: 12,
        now: now.add(const Duration(seconds: 2)),
      ),
      isTrue,
    );
    expect(
      gate.shouldCapture(
        sequence: 12,
        now: now.add(const Duration(seconds: 3)),
      ),
      isFalse,
    );
  });
}
