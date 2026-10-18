import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/read_only_health_features.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';

void main() {
  test('default, expired and explicitly closed features fail closed', () {
    var now = DateTime.utc(2026, 10, 18);
    final features = ReadOnlyHealthFeatures(now: () => now);
    final policy = WellnessReleasePolicy(
      enabled: true,
      readOnlyFeatures: features,
    );
    expect(policy.allowsMetric(HealthMetric.heartRate), isFalse);
    features.replace({HealthMetric.heartRate}, const Duration(seconds: 60));
    expect(policy.allowsMetric(HealthMetric.heartRate), isTrue);
    expect(policy.allowsMetric(HealthMetric.bloodOxygen), isFalse);
    now = now.add(const Duration(seconds: 60));
    expect(policy.allowsMetric(HealthMetric.heartRate), isFalse);
    expect(policy.allowsMetric(HealthMetric.sleep), isTrue);
    features.replace({HealthMetric.hrv}, const Duration(minutes: 5));
    features.close();
    expect(policy.allowsMetric(HealthMetric.hrv), isFalse);
  });

  test('remote configuration cannot exceed the fixed read-only ceiling', () {
    final features = ReadOnlyHealthFeatures();
    for (final metric in HealthMetric.values) {
      if (ReadOnlyHealthFeatures.supportedMetrics.contains(metric)) continue;
      expect(
        () => features.replace({metric}, const Duration(seconds: 60)),
        throwsFormatException,
      );
    }
    for (final validity in [
      Duration.zero,
      const Duration(seconds: -1),
      const Duration(seconds: 301),
    ]) {
      expect(
        () => features.replace({HealthMetric.hrv}, validity),
        throwsFormatException,
      );
    }
    expect(features.metrics, isEmpty);
  });

  test(
    'grants are immutable, do not add health values and do not change Android',
    () {
      final features = ReadOnlyHealthFeatures();
      final requested = {HealthMetric.heartRate};
      features.replace(requested, const Duration(seconds: 60));
      requested.add(HealthMetric.bloodGlucose);
      expect(features.metrics, {HealthMetric.heartRate});
      expect(() => features.metrics.clear(), throwsUnsupportedError);
      final policy = WellnessReleasePolicy(
        enabled: true,
        readOnlyFeatures: features,
      );
      final original = HealthRecord(
        id: 'synthetic-only',
        metric: HealthMetric.heartRate,
        values: const {'value': 70, 'risk': 99},
        unit: 'bpm',
        measuredAt: DateTime.utc(2026, 10, 18),
        timezone: '+08:00',
        deviceId: 'synthetic-ring',
        firmwareVersion: 'synthetic',
        quality: 'unknown',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      );
      expect(policy.projectRecord(original)!.values, {'value': 70});
      expect(original.values, {'value': 70, 'risk': 99});
      features.close();
      expect(policy.projectRecord(original), isNull);
      expect(
        const WellnessReleasePolicy().projectRecord(original),
        same(original),
      );
    },
  );
}
