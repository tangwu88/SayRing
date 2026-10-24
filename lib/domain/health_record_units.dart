import 'models.dart';

/// Pinned CoolWear v1 and iOS QRing v3 adapters copied raw SDK counts without
/// an established kcal contract. Older records may already be labelled kcal;
/// their provenance still takes priority over that unverified label.
/// Preserve the payload, but exclude these counts from kcal goals/statistics.
/// QRing Android v2 has its own conversion and is not affected.
bool hasUnconfirmedCalorieUnit(HealthRecord record) {
  if (record.metric != HealthMetric.calories ||
      record.source == MeasurementSource.manual) {
    return false;
  }
  // Cloud history may omit measurementSource and remain imported. That does
  // not establish a new unit contract for a known SDK payload. Old local
  // records can also predate optional vendor metadata; their persisted scoped
  // identity, rather than today's connected ring name, establishes provenance.
  var vendor = record.sourceVendor.trim().toLowerCase();
  if (vendor.isEmpty) {
    for (final candidate in ['coolwear', 'qring']) {
      final prefix = '$candidate:';
      if (record.deviceId.startsWith(prefix) &&
          record.deviceId.length > prefix.length) {
        vendor = candidate;
        break;
      }
    }
    // A legacy round trip may replace deviceId with an opaque key, but retain
    // the exact versioned identity emitted by the pinned iOS adapter.
    if (vendor.isEmpty &&
        record.rawVersion == 3 &&
        RegExp(r'^qring:[^|]+\|calories\|v3\|').hasMatch(record.id)) {
      vendor = 'qring';
    }
  }
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
