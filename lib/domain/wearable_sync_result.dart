import 'dart:collection';

import 'models.dart';

/// Extends the existing list contract without discarding per-metric evidence.
class WearableSyncResult extends ListBase<HealthRecord> {
  WearableSyncResult(
    List<HealthRecord> records,
    Map<String, String> statuses, {
    this.historyDays,
    Map<String, String> receipts = const {},
    Set<String> protocolChecks = const {},
  }) : _records = List.of(records),
       statuses = Map.unmodifiable(statuses),
       receipts = Map.unmodifiable(receipts),
       protocolChecks = Set.unmodifiable(protocolChecks);

  final List<HealthRecord> _records;
  final Map<String, String> statuses;
  final Map<String, String> receipts;

  /// Optional protocols not negotiated by the ring's legacy capability bits.
  /// Keep these unknown without failing confirmed ranges or writing a full
  /// history checkpoint. A missing required range still fails normally.
  final Set<String> protocolChecks;

  /// Actual SDK day range; completeness still requires per-metric evidence.
  final int? historyDays;
  bool get confirmedRanges =>
      statuses.isNotEmpty &&
      statuses.values.every(
        (value) => value == 'complete' || value == 'no_data',
      );
  bool get complete => confirmedRanges && protocolChecks.isEmpty;
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
