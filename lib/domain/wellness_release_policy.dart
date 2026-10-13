import 'feature_models.dart';
import 'models.dart';
import 'sleep_timeline.dart';

/// Product scope for the activity-and-sleep iOS release. This is independent
/// of device capabilities, server configuration, account and stored history.
/// Projection never mutates the original record or its persisted snapshot.
class WellnessReleasePolicy {
  const WellnessReleasePolicy({this.enabled = false});

  final bool enabled;

  static const activitySleepMetrics = <HealthMetric>{
    HealthMetric.steps,
    HealthMetric.distance,
    HealthMetric.calories,
    HealthMetric.sleep,
  };

  Set<HealthMetric>? get allowedMetrics =>
      enabled ? activitySleepMetrics : null;

  bool allowsMetric(HealthMetric metric) =>
      !enabled || activitySleepMetrics.contains(metric);

  bool allowsWireMetric(String wire) {
    if (!enabled) return true;
    final metric = HealthMetric.tryFromWire(wire);
    return metric != null && allowsMetric(metric);
  }

  bool allowsFeature(DeviceFeature feature) =>
      !enabled ||
      !const {
        DeviceFeature.healthMonitoring,
        DeviceFeature.healthAssessment,
        DeviceFeature.healthReminders,
      }.contains(feature);

  static const _sleepValues = <String>{
    'value',
    'deepHours',
    'lightHours',
    'remHours',
    'awakeMinutes',
    'wakeCount',
    'movementCount',
  };

  static const _sleepSummary = <String>{
    'totalSeconds',
    'deepSeconds',
    'lightSeconds',
    'awakeSeconds',
    'remSeconds',
    'napSeconds',
    'reportedTotalMinutes',
    'wakeCount',
  };

  Map<String, num> projectValues(HealthMetric metric, Map<String, num> values) {
    if (!enabled) return values;
    final keys = metric == HealthMetric.sleep ? _sleepValues : const {'value'};
    return Map.unmodifiable({
      for (final entry in values.entries)
        if (allowsMetric(metric) && keys.contains(entry.key))
          entry.key: entry.value,
    });
  }

  HealthRecord? projectRecord(HealthRecord record) {
    if (!enabled) return record;
    if (!allowsMetric(record.metric)) return null;
    final values = projectValues(record.metric, record.values);
    final timeline = record.sleepTimeline;
    return record.copyWith(
      values: values,
      samples: const [],
      sleepTimeline: timeline == null ? null : projectTimeline(timeline),
    );
  }

  SleepTimeline projectTimeline(SleepTimeline timeline) {
    if (!enabled) return timeline;
    return SleepTimeline(
      deviceId: timeline.deviceId,
      sdkDate: timeline.sdkDate,
      timezone: timeline.timezone,
      readAt: timeline.readAt,
      revision: timeline.revision,
      sessions: timeline.sessions,
      rawSummary: {
        for (final entry in timeline.rawSummary.entries)
          if (_sleepSummary.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  SportRecord projectSport(SportRecord record) {
    if (!enabled) return record;
    return SportRecord(
      id: record.id,
      mode: record.mode,
      startedAt: record.startedAt,
      durationSeconds: record.durationSeconds,
      distanceKm: record.distanceKm,
      calories: record.calories,
      steps: record.steps,
      routePoints: record.routePoints,
    );
  }

  Map<String, num> projectSportValues(Map<String, num> values) {
    if (!enabled) return values;
    const keys = {
      'durationSeconds',
      'distanceKm',
      'distanceMeters',
      'calories',
      'caloriesCal',
      'steps',
      'speed',
      'pace',
    };
    return Map.unmodifiable({
      for (final entry in values.entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    });
  }
}
