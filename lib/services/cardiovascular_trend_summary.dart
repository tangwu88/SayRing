import '../domain/health_record_dedup.dart';
import '../domain/health_record_validation.dart';
import '../domain/models.dart';
import '../domain/ring_experience.dart';
import 'health_analysis.dart';
import 'sleep_health_projection.dart';

/// One wearable, one metric and one calendar day per value. Sleep uses its SDK day.
class CardioContextSeries {
  CardioContextSeries(this.metric, this.deviceId, this.model, this.values);
  final HealthMetric metric;
  final String deviceId;
  final String model;
  final Map<DateTime, double> values;

  Map<DateTime, double> period(DateTime start, DateTime end) => {
    for (final entry in values.entries)
      if (!entry.key.isBefore(start) && !entry.key.isAfter(end))
        entry.key: entry.value,
  };
}

double cardioMean(Iterable<double> values) =>
    values.reduce((a, b) => a + b) / values.length;

class CardiovascularSummary {
  CardiovascularSummary({
    required this.start,
    required this.end,
    required this.previousStart,
    required List<PressureSample> readings,
    required Iterable<HealthRecord> contextRecords,
    required DateTime now,
    this.preferredDeviceId,
  }) {
    for (final row in readings) {
      final day = ringDate(row.at);
      if (row.source.isEmpty ||
          row.at.isAfter(now) ||
          day.isBefore(previousStart) ||
          day.isAfter(end) ||
          !PressureSample.validPair(row.systolic, row.diastolic)) {
        continue;
      }
      pressure.putIfAbsent(row.source, () => []).add(row);
    }
    pressure.removeWhere(
      (_, rows) => !rows.any((r) => !ringDate(r.at).isBefore(start)),
    );
    for (final rows in pressure.values) {
      rows.sort((a, b) => a.at.compareTo(b.at));
    }
    final groups =
        <(HealthMetric, String), Map<DateTime, List<HealthRecord>>>{};
    for (final r in deduplicateHealthRecords(contextRecords)) {
      if (!contextMetrics.contains(r.metric) ||
          r.source != MeasurementSource.wearable ||
          r.deviceId.trim().isEmpty ||
          r.quality.toLowerCase() == 'invalid' ||
          r.measuredAt.isAfter(now) ||
          !hasSaneWearableTransportValues(r) ||
          _value(r) == null) {
        continue;
      }
      final date = r.metric == HealthMetric.sleep
          ? DateTime.tryParse(sleepRecordSdkDate(r))
          : ringDate(HealthAnalysisService.displayTime(r));
      if (date == null || date.isBefore(previousStart) || date.isAfter(end)) {
        continue;
      }
      (groups.putIfAbsent((
        r.metric,
        r.deviceId,
      ), () => {})).putIfAbsent(date, () => []).add(r);
    }
    for (final entry in groups.entries) {
      final (metric, device) = entry.key;
      final daily = <DateTime, double>{};
      var model = '';
      for (final group in entry.value.entries) {
        final rows = group.value
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        final labels = rows
            .map((r) => r.sourceModel.trim())
            .where((s) => s.isNotEmpty);
        if (labels.isNotEmpty) model = labels.last;
        final values = rows.map((r) => _value(r)!);
        daily[group.key] = switch (metric) {
          HealthMetric.heartRate => cardioMean(values),
          // The sleep projection returns a daily summary. A later revision replaces it.
          HealthMetric.sleep => values.last,
          // Step slots and daily cumulative snapshots use different accounting.
          HealthMetric.steps => _stepTotal(rows),
          _ => throw StateError('Unexpected cardiovascular context metric'),
        };
      }
      _series.add(CardioContextSeries(metric, device, model, daily));
    }
  }

  static const contextMetrics = [
    HealthMetric.heartRate,
    HealthMetric.sleep,
    HealthMetric.steps,
  ];
  final DateTime start, end, previousStart;
  final String? preferredDeviceId;
  final pressure = <String, List<PressureSample>>{};
  final _series = <CardioContextSeries>[];

  List<String> get sources => pressure.keys.toList()
    ..sort((a, b) {
      final recent = pressure[b]!.last.at.compareTo(pressure[a]!.last.at);
      return recent != 0 ? recent : a.compareTo(b);
    });

  static double? _value(HealthRecord r) {
    final value = r.values['value']?.toDouble();
    final unit = r.unit.trim().toLowerCase();
    if (r.metric == HealthMetric.sleep && unit == 'h') {
      final minutes = r.sleepTimeline?.hasSegments == true
          ? r.sleepTimeline!.asleepMinutes
          : (value ?? 0) * 60;
      return minutes.isFinite && minutes > 0 && minutes <= 1440
          ? minutes
          : null;
    }
    if (value == null || !value.isFinite) return null;
    if (r.metric == HealthMetric.heartRate && unit == 'bpm') return value;
    if (r.metric == HealthMetric.steps &&
        (unit == 'steps' || unit == 'step') &&
        value >= 0 &&
        value == value.truncateToDouble()) {
      return value;
    }
    return null;
  }

  static double _stepTotal(List<HealthRecord> rows) {
    bool daily(HealthRecord r) {
      final vendor = r.sourceVendor.toLowerCase();
      if (vendor == 'qring') return r.rawVersion >= 3;
      return vendor == 'urion' ||
          (vendor == 'coolwear' && r.rawVersion >= 2) ||
          r.sourceDeviceCategory == 'ring' ||
          r.sourceDeviceCategory == 'watch';
    }

    final snapshots = rows.where(daily);
    return snapshots.isNotEmpty
        ? _value(snapshots.last)!
        : rows.fold(0.0, (sum, row) => sum + _value(row)!);
  }

  /// Exact device for wearable BP. For a cuff, choose one wearable per metric
  /// by overlapping dates, then preference and coverage. Never stitch devices.
  List<CardioContextSeries> contextFor(String? pressureSource) {
    final pressureDates = (pressure[pressureSource] ?? [])
        .map((row) => ringDate(row.at))
        .where((d) => !d.isBefore(start))
        .toSet();
    final selected = <CardioContextSeries>[];
    for (final metric in contextMetrics) {
      final candidates = _series
          .where(
            (s) =>
                s.metric == metric &&
                (pressureSource == null ||
                    pressureSource == 'reference' ||
                    s.deviceId == pressureSource) &&
                s.values.keys.any((day) => !day.isBefore(start)),
          )
          .toList();
      int coverage(CardioContextSeries s) =>
          s.values.keys.where((d) => !d.isBefore(start)).length;
      int overlap(CardioContextSeries s) =>
          s.values.keys.where(pressureDates.contains).length;
      candidates.sort((a, b) {
        final joint = overlap(b).compareTo(overlap(a));
        if (joint != 0) return joint;
        if (a.deviceId == preferredDeviceId) return -1;
        if (b.deviceId == preferredDeviceId) return 1;
        final days = coverage(b).compareTo(coverage(a));
        return days != 0 ? days : a.deviceId.compareTo(b.deviceId);
      });
      if (candidates.isNotEmpty) selected.add(candidates.first);
    }
    return selected;
  }
}
