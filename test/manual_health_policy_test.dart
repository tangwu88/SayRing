import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/read_only_health_features.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/read_only_health_service.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

const _three = {
  HealthMetric.heartRate,
  HealthMetric.hrv,
  HealthMetric.bloodOxygen,
};

class _Api extends Fake implements SayRingReadOnlyHealthApi {
  _Api([this.metrics = _three]);
  final Set<HealthMetric> metrics;
  @override
  Future<ReadOnlyHealthFeatureSnapshot> getReadOnlyHealthFeatures() async =>
      ReadOnlyHealthFeatureSnapshot(
        metrics: metrics,
        validity: Duration(minutes: 5),
      );
}

class _Bridge
    implements
        WearableReadOnlyHealthPolicyBridge,
        WearableManualHealthPolicyBridge {
  final manualCalls = <Set<HealthMetric>>[];
  Completer<void>? manualAck;
  bool failManual = false;
  @override
  Future<void> configureReadOnlyHealthMetrics(
    Set<HealthMetric> metrics, {
    required Duration validity,
  }) async {}
  @override
  Future<void> configureManualHealthMetrics(
    Set<HealthMetric> metrics, {
    required Duration validity,
  }) async {
    manualCalls.add(metrics.toSet());
    if (metrics.isNotEmpty && failManual) {
      throw StateError('synthetic-rejection');
    }
    if (metrics.isNotEmpty && manualAck != null) await manualAck!.future;
  }
}

void main() {
  test(
    'skin temperature requires read and native manual ACK and closes on revocation',
    () async {
      final policy = WellnessReleasePolicy(
        enabled: true,
        readOnlyFeatures: ReadOnlyHealthFeatures(),
        manualFeatures: ManualHealthFeatures(),
      );
      final bridge = _Bridge()..manualAck = Completer<void>();
      final service = ReadOnlyHealthFeatureService(
        policy: policy,
        api: _Api({
          ..._three,
          HealthMetric.bodyTemperature,
          HealthMetric.stress,
        }),
        bridge: bridge,
      );
      final refresh = service.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        policy.allowsManualMeasurement(HealthMetric.bodyTemperature),
        isFalse,
      );
      bridge.manualAck!.complete();
      await refresh;
      expect(bridge.manualCalls.single, {
        ..._three,
        HealthMetric.bodyTemperature,
      });
      expect(
        policy.allowsManualMeasurement(HealthMetric.bodyTemperature),
        isTrue,
      );
      expect(policy.allowsManualMeasurement(HealthMetric.stress), isFalse);
      service.dispose();
      expect(
        policy.allowsManualMeasurement(HealthMetric.bodyTemperature),
        isFalse,
      );
      await Future<void>.delayed(Duration.zero);
    },
  );
  testWidgets(
    'production iOS controller constructs with independent manual scope',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final controller = AppController.production(
          allowAutomaticWearableRestore: false,
        );
        addTearDown(controller.dispose);
        expect(controller.isWellnessOnly, isTrue);
        expect(controller.healthReleasePolicy.manualFeatures, isNotNull);
        expect(controller.healthReleasePolicy.manualFeatures!.metrics, isEmpty);
        expect(
          controller.canMeasureHealthMetric(HealthMetric.heartRate),
          isFalse,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test('renewal first exposes expired manual scope for cancellation', () async {
    var now = DateTime.utc(2026, 10, 18);
    final read = ReadOnlyHealthFeatures(now: () => now)
      ..replace(_three, const Duration(seconds: 1));
    final manual = ManualHealthFeatures(now: () => now)
      ..replace(_three, const Duration(seconds: 1));
    final policy = WellnessReleasePolicy(
      enabled: true,
      readOnlyFeatures: read,
      manualFeatures: manual,
    );
    now = now.add(const Duration(seconds: 1));
    final service = ReadOnlyHealthFeatureService(
      policy: policy,
      api: _Api(),
      bridge: _Bridge(),
    );
    final observed = <bool>[];
    service.addListener(
      () =>
          observed.add(policy.allowsManualMeasurement(HealthMetric.heartRate)),
    );
    await service.refresh();
    expect(observed, [false, true]);
    service.dispose();
    await Future<void>.delayed(Duration.zero);
  });
  test('read-only grant alone never authorizes manual commands', () {
    final read = ReadOnlyHealthFeatures()
      ..replace(_three, const Duration(minutes: 5));
    final policy = WellnessReleasePolicy(enabled: true, readOnlyFeatures: read);
    for (final metric in HealthMetric.values) {
      expect(policy.allowsManualMeasurement(metric), isFalse);
    }
  });

  test(
    'independent fixed manual catalogue needs both leases and expires closed',
    () {
      var now = DateTime.utc(2026, 10, 18);
      final read = ReadOnlyHealthFeatures(now: () => now);
      final manual = ManualHealthFeatures(now: () => now);
      final policy = WellnessReleasePolicy(
        enabled: true,
        readOnlyFeatures: read,
        manualFeatures: manual,
      );
      manual.replace(_three, const Duration(seconds: 60));
      expect(policy.allowsManualMeasurement(HealthMetric.heartRate), isFalse);
      read.replace({
        ..._three,
        HealthMetric.stress,
      }, const Duration(seconds: 60));
      for (final metric in HealthMetric.values) {
        expect(policy.allowsManualMeasurement(metric), _three.contains(metric));
      }
      expect(
        () =>
            manual.replace({HealthMetric.stress}, const Duration(seconds: 60)),
        throwsFormatException,
      );
      now = now.add(const Duration(seconds: 60));
      expect(policy.allowsManualMeasurement(HealthMetric.heartRate), isFalse);
    },
  );

  test(
    'new native manual ACK is required before either UI grant is published',
    () async {
      final policy = WellnessReleasePolicy(
        enabled: true,
        readOnlyFeatures: ReadOnlyHealthFeatures(),
        manualFeatures: ManualHealthFeatures(),
      );
      final bridge = _Bridge()..manualAck = Completer<void>();
      final service = ReadOnlyHealthFeatureService(
        policy: policy,
        api: _Api(),
        bridge: bridge,
      );
      final refresh = service.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(policy.allowsManualMeasurement(HealthMetric.heartRate), isFalse);
      bridge.manualAck!.complete();
      await refresh;
      expect(bridge.manualCalls.single, _three);
      expect(policy.allowsManualMeasurement(HealthMetric.heartRate), isTrue);
      service.dispose();
      expect(policy.allowsManualMeasurement(HealthMetric.heartRate), isFalse);
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('native manual rejection rolls back both independent scopes', () async {
    final policy = WellnessReleasePolicy(
      enabled: true,
      readOnlyFeatures: ReadOnlyHealthFeatures(),
      manualFeatures: ManualHealthFeatures(),
    );
    final bridge = _Bridge()..failManual = true;
    final service = ReadOnlyHealthFeatureService(
      policy: policy,
      api: _Api(),
      bridge: bridge,
    );
    await service.refresh();
    expect(policy.readOnlyFeatures!.metrics, isEmpty);
    expect(policy.manualFeatures!.metrics, isEmpty);
    expect(bridge.manualCalls.last, isEmpty);
    service.dispose();
    await Future<void>.delayed(Duration.zero);
  });
}
