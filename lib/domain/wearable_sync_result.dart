import 'dart:collection';

import 'models.dart';

/// Extends the existing list contract without discarding per-metric evidence.
class WearableSyncResult extends ListBase<HealthRecord> {
  WearableSyncResult(
    List<HealthRecord> records,
    Map<String, String> statuses, {
    this.historyDays,
    Map<String, String> receipts = const {},
  }) : _records = List.of(records),
       statuses = Map.unmodifiable(statuses),
       receipts = Map.unmodifiable(receipts);

  final List<HealthRecord> _records;
  final Map<String, String> statuses;
  final Map<String, String> receipts;

  /// Actual SDK day range; completeness still requires per-metric evidence.
  final int? historyDays;
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
