import 'dart:collection';

import 'models.dart';

/// Extends the existing list contract without discarding per-metric evidence.
class WearableSyncResult extends ListBase<HealthRecord> {
  WearableSyncResult(List<HealthRecord> records, Map<String, String> statuses)
    : _records = List.of(records),
      statuses = Map.unmodifiable(statuses);

  final List<HealthRecord> _records;
  final Map<String, String> statuses;
  bool get complete =>
      statuses.isNotEmpty &&
      statuses.values.every(
        (value) => value == 'complete' || value == 'no_data',
      );
  bool get partial =>
      statuses.values.any((value) => value == 'partial' || value == 'failed') ||
      (!complete && isNotEmpty);
  @override
  int get length => _records.length;
  @override
  set length(int value) => _records.length = value;
  @override
  HealthRecord operator [](int index) => _records[index];
  @override
  void operator []=(int index, HealthRecord value) => _records[index] = value;
}
