import 'models.dart';

/// Pinned CoolWear v1 and iOS QRing v3 adapters copied raw SDK counts without
/// an established kcal contract. Older records may already be labelled kcal;
/// their provenance still takes priority over that unverified label.
/// Preserve the payload, but exclude these counts from kcal goals/statistics.
/// QRing Android v2 has its own conversion and is not affected.
bool hasUnconfirmedCalorieUnit(HealthRecord record) {
  if (record.metric != HealthMetric.calories ||
      record.source != MeasurementSource.wearable) {
    return false;
  }
  final vendor = record.sourceVendor.trim().toLowerCase();
  if (vendor == 'coolwear') {
    return record.unit.trim().toLowerCase() != 'kcal' || record.rawVersion == 1;
  }
  if (vendor != 'qring') return false;
  if (record.unit.trim().toLowerCase() != 'kcal') return true;
  return record.rawVersion == 3 &&
      ((record.sourceApp == 'say-ring' &&
              record.sourceDeviceCategory == 'ring') ||
          record.id.contains('|calories|v3|'));
}
