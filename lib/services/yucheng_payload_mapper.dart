import '../domain/feature_models.dart';
import '../domain/models.dart';
import 'yucheng_product_client.dart';

class YuchengPayloadMapper {
  const YuchengPayloadMapper._();

  static DeviceCapabilities capabilities(Map<String, Object?> f) {
    final metrics = <HealthMetric>{};
    if (f['isSupportStep'] == true) {
      metrics.addAll([
        HealthMetric.steps,
        HealthMetric.distance,
        HealthMetric.calories,
      ]);
    }
    if (f['isSupportSleep'] == true) metrics.add(HealthMetric.sleep);
    if (f['isSupportHeartRate'] == true) metrics.add(HealthMetric.heartRate);
    if (f['isSupportBloodPressure'] == true) {
      metrics.add(HealthMetric.bloodPressure);
    }
    if (f['isSupportBloodOxygen'] == true) {
      metrics.add(HealthMetric.bloodOxygen);
    }
    if (f['isSupportTemperature'] == true) {
      metrics.add(HealthMetric.bodyTemperature);
    }
    if (f['isSupportBloodGlucose'] == true) {
      metrics.add(HealthMetric.bloodGlucose);
    }
    if (f['isSupportHRV'] == true) metrics.add(HealthMetric.hrv);
    final manualMetrics = <HealthMetric>{};
    void addManual(String key, HealthMetric metric) {
      if (f[key] == true) manualMetrics.add(metric);
    }

    addManual('isSupportStartHeartRateMeasurement', HealthMetric.heartRate);
    addManual(
      'isSupportStartBloodPressureMeasurement',
      HealthMetric.bloodPressure,
    );
    addManual('isSupportStartBloodOxygenMeasurement', HealthMetric.bloodOxygen);
    addManual(
      'isSupportStartBodyTemperatureMeasurement',
      HealthMetric.bodyTemperature,
    );
    addManual(
      'isSupportStartBloodGlucoseMeasurement',
      HealthMetric.bloodGlucose,
    );
    final features = <DeviceFeature>{};
    void add(String key, DeviceFeature feature) {
      if (f[key] == true) features.add(feature);
    }

    add('isSupportFindDevice', DeviceFeature.findWatch);
    add('isSupportCamera', DeviceFeature.camera);
    add('isSupportCall', DeviceFeature.phoneCalls);
    add('isSupportAddressBook', DeviceFeature.contacts);
    add('isSupportAlarm', DeviceFeature.alarms);
    add('isSupportWeather', DeviceFeature.weather);
    add('isSupportHealthMonitoring', DeviceFeature.healthMonitoring);
    add('isSupportScreen', DeviceFeature.screenDisplay);
    add('isSupportWatchFace', DeviceFeature.watchFaces);
    const implementedFeatures = {
      DeviceFeature.findWatch,
      DeviceFeature.camera,
      DeviceFeature.watchFaces,
    };
    return DeviceCapabilities(
      metrics: metrics,
      manualMetrics: manualMetrics,
      features: features,
      integratedFeatures: features.intersection(implementedFeatures),
      supportsBackgroundSync: true,
      supportsWatchFaces: features.contains(DeviceFeature.watchFaces),
      supportsOta: f['isSupportOta'] == true,
    );
  }

  static List<HealthRecord> healthRecords({
    required String deviceId,
    required String firmwareVersion,
    required Map<int, List<Map<String, Object?>>> rowsByType,
  }) {
    final output = <HealthRecord>[];
    for (final entry in rowsByType.entries) {
      for (final row in entry.value) {
        final seconds = _num(row['startTimeStamp'])?.toInt();
        if (seconds == null || seconds <= 0) continue;
        final at = DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
          isUtc: true,
        );
        void add(HealthMetric metric, Map<String, num> values) {
          if (values.isEmpty || values.values.any((v) => v <= 0)) return;
          output.add(
            HealthRecord(
              id: 'yc-${metric.wireName}-$seconds',
              metric: metric,
              values: values,
              unit: metric.defaultUnit,
              measuredAt: at,
              timezone: '+00:00',
              deviceId: deviceId,
              firmwareVersion: firmwareVersion,
              quality: 'sdk',
              source: MeasurementSource.wearable,
              rawVersion: 1,
            ),
          );
        }

        if (entry.key == YuchengHealthDataType.step) {
          final steps = _num(row['step']);
          if (steps != null) add(HealthMetric.steps, {'value': steps});
          final distance = _num(row['distance']);
          if (distance != null) {
            add(HealthMetric.distance, {'value': distance / 1000});
          }
          final calories = _num(row['calories']);
          if (calories != null) add(HealthMetric.calories, {'value': calories});
        } else if (entry.key == YuchengHealthDataType.sleep) {
          final total =
              (_num(row['deepSleepSeconds']) ?? 0) +
              (_num(row['lightSleepSeconds']) ?? 0) +
              (_num(row['remSleepSeconds']) ?? 0);
          add(HealthMetric.sleep, {'value': total / 3600});
        } else if (entry.key == YuchengHealthDataType.heartRate) {
          final v = _num(row['heartRate']);
          if (v != null) add(HealthMetric.heartRate, {'value': v});
        } else if (entry.key == YuchengHealthDataType.bloodPressure) {
          final s = _num(row['systolicBloodPressure']),
              d = _num(row['diastolicBloodPressure']);
          if (s != null && d != null) {
            add(HealthMetric.bloodPressure, {'systolic': s, 'diastolic': d});
          }
        } else if (entry.key == YuchengHealthDataType.combined) {
          final values = <Object?, HealthMetric>{
            'bloodOxygen': HealthMetric.bloodOxygen,
            'bloodGlucose': HealthMetric.bloodGlucose,
            'temperature': HealthMetric.bodyTemperature,
            'hrv': HealthMetric.hrv,
          };
          for (final e in values.entries) {
            final v = _num(row[e.key]);
            if (v != null) add(e.value, {'value': v});
          }
        }
      }
    }
    return output;
  }

  static List<SportRecord> sportRecords(List<Map<String, Object?>> rows) =>
      rows.map((row) {
        final seconds = _num(row['startTimeStamp'])?.toInt() ?? 0;
        final mode = switch (_num(row['sportType'])?.toInt()) {
          0x03 => SportMode.cycling,
          0x10 => SportMode.walking,
          0x1B => SportMode.hiking,
          _ => SportMode.running,
        };
        return SportRecord(
          id: 'yc-sport-$seconds',
          mode: mode,
          startedAt: seconds > 0
              ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
              : null,
          durationSeconds: _num(row['sportTime'])?.toInt() ?? 0,
          distanceKm: (_num(row['distance']) ?? 0) / 1000,
          calories: (_num(row['calories']) ?? 0).toDouble(),
        );
      }).toList();

  static num? _num(Object? value) =>
      value is num ? value : num.tryParse('$value');
}
