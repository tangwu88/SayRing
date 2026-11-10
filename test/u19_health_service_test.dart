import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/u19_health_features.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/u19_health_service.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

class _Api implements SayRingU19HealthApi {
  U19HealthSnapshot snapshot = const U19HealthSnapshot(
    {HealthMetric.heartRate},
    {HealthMetric.heartRate},
    Duration(seconds: 1),
  );
  Object? failure;
  @override
  Future<U19HealthSnapshot> getU19HealthFeatures() async {
    if (failure != null) throw failure!;
    return snapshot;
  }
}

class _Bridge implements WearableU19HealthPolicyBridge {
  final calls = <Set<HealthMetric>>[];
  Completer<void>? gate;
  @override
  Future<void> configureU19HealthMetrics(
    Set<HealthMetric> reads,
    Set<HealthMetric> manual, {
    required Duration validity,
  }) async {
    calls.add(reads);
    await gate?.future;
  }
}

void main() {
  test(
    'no grant before native ACK; expiry notifies even after its clock has expired',
    () async {
      final api = _Api();
      final native = _Bridge()..gate = Completer();
      final f = U19HealthFeatures();
      final s = U19HealthFeatureService(features: f, api: api, bridge: native);
      var changes = 0;
      s.addListener(() => changes++);
      s.setForeground(false);
      addTearDown(s.dispose);
      final pending = s.refresh();
      await pumpEventQueue();
      expect(f.active, isFalse);
      native.gate!.complete();
      await pending;
      expect(f.active, isTrue);
      expect(changes, 1);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(f.active, isFalse);
      expect(changes, 2);
      expect(native.calls.last, isEmpty);
    },
  );
  test(
    'failed refresh immediately closes U19 and supersedes a pending native renewal',
    () async {
      final api = _Api();
      final native = _Bridge();
      final f = U19HealthFeatures();
      final s = U19HealthFeatureService(features: f, api: api, bridge: native);
      s.setForeground(false);
      addTearDown(s.dispose);
      await s.refresh();
      expect(f.active, isTrue);
      api.failure = const FormatException('fixture');
      await s.refresh();
      expect(f.readMetrics, isEmpty);
      expect(native.calls.last, isEmpty);
    },
  );
}
