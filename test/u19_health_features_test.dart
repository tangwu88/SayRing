import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/read_only_health_features.dart';
import 'package:saydian_app/domain/u19_health_features.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/domain/urion_pulse_record.dart';

Map<String, Object?> config({
  Object? read = const ['blood_pressure', 'heart_rate'],
  Object? manual = const ['blood_pressure'],
}) => {
  'product': 'say-ring',
  'platform': 'ios',
  'u19Health': {
    'schemaVersion': 1,
    'validForSeconds': 300,
    'readMetrics': read,
    'manualMetrics': manual,
  },
};
void main() {
  test(
    'U19 source lease leaves ring catalogue and data intact, and expires separately',
    () {
      var now = DateTime.utc(2026);
      final u19 = U19HealthFeatures(now: () => now);
      final ring = ReadOnlyHealthFeatures(now: () => now)
        ..replace({HealthMetric.hrv}, const Duration(minutes: 5));
      final policy = WellnessReleasePolicy(
        enabled: true,
        readOnlyFeatures: ring,
        u19Features: u19,
      );
      u19.replace(
        U19HealthSnapshot.fromMap(config()),
        const Duration(minutes: 1),
      );
      expect(
        policy
            .forDevice('urion:a')
            .allowsManualMeasurement(HealthMetric.bloodPressure),
        isTrue,
      );
      expect(
        policy.forDevice('qring:a').allowsMetric(HealthMetric.bloodPressure),
        isFalse,
      );
      expect(
        policy.forDevice('qring:a').allowsMetric(HealthMetric.hrv),
        isTrue,
      );
      expect(
        policy.forDevice('urion:a').projectValues(HealthMetric.bloodPressure, {
          'systolic': 120,
          'diastolic': 80,
          'pulse': 70,
        }),
        {'systolic': 120, 'diastolic': 80, 'pulse': 70},
      );
      now = now.add(const Duration(minutes: 2));
      expect(
        policy.forDevice('urion:a').allowsMetric(HealthMetric.bloodPressure),
        isFalse,
      );
      expect(
        policy.forDevice('qring:a').allowsMetric(HealthMetric.hrv),
        isTrue,
      );
    },
  );
  for (final bad in [
    config(read: ['ecg']),
    config(read: [], manual: ['heart_rate']),
    config(read: ['heart_rate', 'heart_rate']),
    <String, Object?>{'product': 'other', 'platform': 'ios', 'u19Health': {}},
    <String, Object?>{},
  ]) {
    test(
      'rejects malformed U19 scope $bad',
      () => expect(() => U19HealthSnapshot.fromMap(bad), throwsFormatException),
    );
  }
  test(
    'pulse history is idempotent and isolated by owner and target',
    () async {
      final store = MemoryHealthStore();
      final row = UrionPulseRecord(
        deviceId: 'urion:a',
        rawTimestamp: 100,
        bloodStasis: 2,
        qiBlood: 3,
        dampness: 4,
        measuredAt: DateTime.utc(2026),
      );
      await store.saveUrionPulseHistory([row, row], ownerId: 'one');
      expect(
        await store.readUrionPulseHistory(ownerId: 'one', deviceId: 'urion:a'),
        hasLength(1),
      );
      expect(
        await store.readUrionPulseHistory(ownerId: 'two', deviceId: 'urion:a'),
        isEmpty,
      );
      expect(
        await store.readUrionPulseHistory(ownerId: 'one', deviceId: 'urion:b'),
        isEmpty,
      );
    },
  );
}
