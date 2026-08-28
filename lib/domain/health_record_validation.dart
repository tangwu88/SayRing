import 'ecg_waveform.dart';
import 'models.dart';

/// Rejects values that cannot be a completed wearable measurement.
///
/// These are deliberately broad transport-sanity limits, not clinical
/// reference ranges. Their purpose is to keep SDK progress and error sentinel
/// values (for example `1`) out of local history and cloud synchronization.
bool hasSaneWearableTransportValues(HealthRecord record) {
  if (record.source != MeasurementSource.wearable) return true;

  return switch (record.metric) {
    HealthMetric.heartRate => _inRange(record.values['value'], 20, 300),
    HealthMetric.bloodOxygen => _inRange(record.values['value'], 2, 100),
    HealthMetric.bloodPressure => _hasSaneBloodPressure(record.values),
    HealthMetric.bodyTemperature => _inRange(record.values['value'], 20, 45),
    HealthMetric.ecg => _hasSaneEcg(record),
    _ => true,
  };
}

/// Keeps objective ECG metrics when a device returns samples that cannot be
/// presented as a calibrated waveform. Invalid transport samples are never
/// drawn, but they must not make the accompanying heart-rate/HRV fields vanish.
HealthRecord sanitizeWearableTransportRecord(HealthRecord record) {
  if (record.source != MeasurementSource.wearable ||
      record.metric != HealthMetric.ecg ||
      record.origin != MeasurementOrigin.watchHistory ||
      record.rawVersion < 2) {
    return record;
  }
  final frequency = (record.values['sampleFrequency'] ?? 250).toInt().clamp(
    50,
    1000,
  );
  if (hasUsableEcgSignal(record.samples, sampleFrequency: frequency)) {
    return record;
  }
  return record.copyWith(rawVersion: 1, samples: const []);
}

bool _hasSaneEcg(HealthRecord record) {
  final values = record.values;
  final heartRate = values['meanHeartRate'] ?? values['averageHeartRate'];
  final hrv = values['averageHRV'] ?? values['hrv'];
  final frequency = values['sampleFrequency'];
  if (heartRate != null && !_inRange(heartRate, 30, 210)) return false;
  if (hrv != null && !_inRange(hrv, 1, 250)) return false;
  if (frequency != null && !_inRange(frequency, 50, 1000)) return false;
  if (record.rawVersion >= 2) {
    final sampleFrequency = (frequency ?? 250).toInt().clamp(50, 1000);
    if (!hasUsableEcgSignal(record.samples, sampleFrequency: sampleFrequency)) {
      return false;
    }
  }
  return heartRate != null || hrv != null;
}

bool _hasSaneBloodPressure(Map<String, num> values) {
  final systolic = values['systolic'];
  final diastolic = values['diastolic'];
  return _inRange(systolic, 60, 300) &&
      _inRange(diastolic, 20, 200) &&
      systolic! > diastolic!;
}

bool _inRange(num? value, num minimum, num maximum) =>
    value != null && value.isFinite && value >= minimum && value <= maximum;
