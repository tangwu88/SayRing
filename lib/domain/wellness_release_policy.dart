import 'feature_models.dart';
import 'models.dart';
import 'read_only_health_features.dart';
import 'sleep_timeline.dart';
import 'u19_health_features.dart';

/// Fixed iOS product ceiling plus explicitly published read-only features.
/// Device capability/ownership checks are still required independently.
/// Projection never mutates the original record or its persisted snapshot.
class WellnessReleasePolicy {
  const WellnessReleasePolicy({
    this.enabled = false,
    this.readOnlyFeatures,
    this.manualFeatures,
    this.u19Features,
    this.deviceId,
  });

  final bool enabled;
  final ReadOnlyHealthFeatures? readOnlyFeatures;
  final ManualHealthFeatures? manualFeatures;
  final U19HealthFeatures? u19Features;
  final String? deviceId;
  bool get isU19 => deviceId?.startsWith('urion:') == true;
  WellnessReleasePolicy forDevice(String? id) => WellnessReleasePolicy(
    enabled: enabled,
    readOnlyFeatures: readOnlyFeatures,
    manualFeatures: manualFeatures,
    u19Features: u19Features,
    deviceId: id,
  );

  static const activitySleepMetrics = <HealthMetric>{
    HealthMetric.steps,
    HealthMetric.distance,
    HealthMetric.calories,
    HealthMetric.sleep,
  };

  static const displayMetricOrder = <HealthMetric>[
    HealthMetric.bloodPressure,
    HealthMetric.heartRate,
    HealthMetric.hrv,
    HealthMetric.bloodOxygen,
    HealthMetric.bodyTemperature,
    HealthMetric.stress,
    HealthMetric.steps,
    HealthMetric.distance,
    HealthMetric.sleep,
  ];

  Set<HealthMetric>? get allowedMetrics => enabled
      ? {
          ...activitySleepMetrics,
          ...(isU19
              ? u19Features?.readMetrics ?? const <HealthMetric>{}
              : readOnlyFeatures?.metrics ?? const <HealthMetric>{}),
        }
      : null;

  bool allowsMetric(HealthMetric metric) =>
      !enabled || allowedMetrics!.contains(metric);

  bool allowsManualMeasurement(HealthMetric metric) =>
      !enabled ||
      (allowsMetric(metric) &&
          (isU19
                  ? u19Features?.manualMetrics.contains(metric)
                  : manualFeatures?.metrics.contains(metric)) ==
              true);

  bool allowsWireMetric(String wire) {
    if (!enabled) return true;
    final metric = HealthMetric.tryFromWire(wire);
    return metric != null && allowsMetric(metric);
  }

  bool allowsFeature(DeviceFeature feature) =>
      !enabled ||
      !const {
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
    final keys = metric == HealthMetric.sleep
        ? _sleepValues
        : metric == HealthMetric.bodyTemperature
        ? const {'value', 'skinTemperature'}
        : metric == HealthMetric.bloodPressure
        ? const {'systolic', 'diastolic', 'pulse'}
        : const {'value', 'hours'};
    return Map.unmodifiable({
      for (final entry in values.entries)
        if (allowsMetric(metric) && keys.contains(entry.key))
          entry.key: entry.value,
    });
  }

  HealthRecord? projectRecord(HealthRecord record) {
    if (!enabled) return record;
    // 云端使用账号散列设备键；来源由已校验的回读字段保留，不能靠当前连接猜填。
    final policy = forDevice(
      record.deviceId.startsWith('urion:') ||
              (record.sourceVendor == 'urion' &&
                  record.sourceDeviceCategory == 'watch')
          ? 'urion:${record.deviceId}'
          : record.deviceId,
    );
    if (!policy.allowsMetric(record.metric)) return null;
    final values = policy.projectValues(record.metric, record.values);
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
    // 运动心率与健康卡片复用真实的读取许可，不再用旧的整个 iOS 开关遮蔽。
    if (allowsMetric(HealthMetric.heartRate)) return record;
    return SportRecord(
      id: record.id,
      mode: record.mode,
      startedAt: record.startedAt,
      durationSeconds: record.durationSeconds,
      distanceKm: record.distanceKm,
      calories: record.calories,
      steps: record.steps,
      routePoints: record.routePoints,
      missingMetrics: {...record.missingMetrics, 'heartRate'},
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
        if (keys.contains(entry.key) ||
            (entry.key == 'heartRate' && allowsMetric(HealthMetric.heartRate)))
          entry.key: entry.value,
    });
  }
}
