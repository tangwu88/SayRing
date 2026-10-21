import 'models.dart';

/// The pinned iOS QRing v3 adapter copied QCSportModel.calories unchanged and
/// labelled it kcal. That model does not establish a kcal conversion contract.
/// Preserve the payload, but do not compare its unverified value with kcal
/// goals or use it in kcal statistics. Android v2 already converts its slots.
bool hasUnconfirmedCalorieUnit(HealthRecord record) {
  if (record.metric != HealthMetric.calories ||
      record.source != MeasurementSource.wearable ||
      record.sourceVendor.toLowerCase() != 'qring') {
    return false;
  }
  if (record.unit.trim().toLowerCase() != 'kcal') return true;
  return record.rawVersion == 3 &&
      ((record.sourceApp == 'say-ring' &&
              record.sourceDeviceCategory == 'ring') ||
          record.id.contains('|calories|v3|'));
}
