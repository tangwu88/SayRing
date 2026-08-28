import 'models.dart';

/// Removes duplicate transport rows without deleting the encrypted history.
///
/// W9S can report the same metric more than once during a single sync. The
/// server-generated record ids differ, so id-only de-duplication is not
/// sufficient. A metric, device and measured second identify one physical
/// sample; when duplicates exist, retain the richer and higher-quality row.
List<HealthRecord> deduplicateHealthRecords(Iterable<HealthRecord> records) {
  final selected = <String, HealthRecord>{};
  for (final record in records) {
    final device = record.deviceId.trim().isEmpty
        ? 'unknown-device'
        : record.deviceId.trim().toUpperCase();
    final second = record.measuredAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final key = '${record.metric.wireName}|$device|$second';
    final existing = selected[key];
    if (existing == null || _recordScore(record) > _recordScore(existing)) {
      selected[key] = record;
    }
  }
  final result = selected.values.toList(growable: false)
    ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  return result;
}

int _recordScore(HealthRecord record) {
  final quality = switch (record.quality.toLowerCase()) {
    'good' || 'excellent' || 'valid' => 30,
    'fair' || 'normal' => 20,
    'poor' || 'unknown' => 10,
    _ => 0,
  };
  final source = switch (record.source) {
    MeasurementSource.wearable => 6,
    MeasurementSource.manual => 4,
    MeasurementSource.imported => 2,
  };
  return quality +
      source +
      record.values.length * 2 +
      (record.samples.isNotEmpty ? 4 : 0) +
      record.rawVersion.clamp(0, 9);
}
