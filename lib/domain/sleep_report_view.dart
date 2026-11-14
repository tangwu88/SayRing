import 'dart:math' as math;

import 'health_record_validation.dart';
import 'models.dart';
import 'sleep_timeline.dart';

enum SleepReportPeriod { day, week, month }

DateTime sleepCalendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);
DateTime sleepCalendarAdd(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

({DateTime start, DateTime end}) sleepPeriodRange(
  DateTime day,
  SleepReportPeriod period,
) => switch (period) {
  SleepReportPeriod.day => (
    start: sleepCalendarDay(day),
    end: sleepCalendarDay(day),
  ),
  SleepReportPeriod.week => (
    start: sleepCalendarAdd(day, 1 - day.weekday),
    end: sleepCalendarAdd(day, 7 - day.weekday),
  ),
  SleepReportPeriod.month => (
    start: DateTime(day.year, day.month),
    end: DateTime(day.year, day.month + 1, 0),
  ),
};

Iterable<DateTime> sleepDaysInRange(DateTime first, DateTime last) sync* {
  var date = first;
  while (!date.isAfter(last)) {
    yield date;
    date = sleepCalendarAdd(date, 1);
  }
}

/// One real observation window. Timeline clocks retain the recorded offset;
/// SDK date stays associated with the wearable's date, not the phone zone.
class SleepObservationWindow {
  const SleepObservationWindow(this.start, this.end, this.kind, this.offset);
  final DateTime start, end;
  final SleepSessionKind kind;
  final Duration offset;
  DateTime clock(DateTime instant) => instant.toUtc().add(offset);
  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(end);
}

Duration? sleepRecordedOffset(String value) {
  final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final hours = int.parse(match[2]!), minutes = int.parse(match[3]!);
  if (hours > 14 || minutes > 59 || (hours == 14 && minutes != 0)) return null;
  return Duration(minutes: (hours * 60 + minutes) * (match[1] == '-' ? -1 : 1));
}

List<SleepObservationWindow> sleepObservationWindows(HealthRecord record) {
  final timeline = record.sleepTimeline;
  final offset = sleepRecordedOffset(timeline?.timezone ?? record.timezone);
  if (offset == null || record.deviceId.trim().isEmpty) return const [];
  if (timeline != null) {
    return [
      for (final s in timeline.sessions)
        if (s.startedAt != null && s.endedAt != null)
          SleepObservationWindow(s.startedAt!, s.endedAt!, s.kind, offset),
    ];
  }
  // Never manufacture times from a duration or assign a short record to naps.
  final result = <SleepObservationWindow>[];
  for (final raw in record.nightWindows) {
    if (raw['kind'] != 'night' && raw['kind'] != 'nap') continue;
    final start = _offsetInstant(raw['startAt']),
        end = _offsetInstant(raw['endAt']);
    if (start == null ||
        end == null ||
        !start.isBefore(end) ||
        end.difference(start) > const Duration(hours: 24)) {
      continue;
    }
    result.add(
      SleepObservationWindow(
        start,
        end,
        raw['kind'] == 'night' ? SleepSessionKind.night : SleepSessionKind.nap,
        offset,
      ),
    );
  }
  result.sort((a, b) => a.start.compareTo(b.start));
  for (var i = 1; i < result.length; i++) {
    if (result[i].start.isBefore(result[i - 1].end)) return const [];
  }
  return result;
}

DateTime? _offsetInstant(Object? value) =>
    value is String &&
        RegExp(r'(?:Z|[+-]\d\d:\d\d)$', caseSensitive: false).hasMatch(value)
    ? DateTime.tryParse(value)
    : null;

SleepObservationWindow? mainSleepWindow(HealthRecord record) {
  final windows = sleepObservationWindows(
    record,
  ).where((w) => w.kind != SleepSessionKind.nap).toList();
  windows.sort((a, b) {
    final kind =
        (b.kind == SleepSessionKind.night ? 1 : 0) -
        (a.kind == SleepSessionKind.night ? 1 : 0);
    return kind != 0
        ? kind
        : b.end.difference(b.start).compareTo(a.end.difference(a.start));
  });
  return windows.firstOrNull;
}

/// Minutes measured against the SDK date, so 23:00 and 01:00 remain close
/// across midnight, including on a phone currently in a different timezone.
int sleepMinutesFromSdkDay(DateTime localClock, DateTime sdkDay) =>
    DateTime.utc(
      localClock.year,
      localClock.month,
      localClock.day,
      localClock.hour,
      localClock.minute,
    ).difference(DateTime.utc(sdkDay.year, sdkDay.month, sdkDay.day)).inMinutes;

class SleepMetricPoint {
  const SleepMetricPoint(this.at, this.value, this.window, this.asleepRun);
  final DateTime at;
  final double value;
  final SleepObservationWindow window;
  final int asleepRun;
}

class SleepMetricSeries {
  const SleepMetricSeries({
    required this.metric,
    required this.unit,
    required this.signature,
    required this.algorithm,
    required this.points,
    required this.maxGapSeconds,
  });
  final HealthMetric metric;
  final String unit, signature, algorithm;
  final List<SleepMetricPoint> points;
  final int maxGapSeconds;
  double get mean =>
      points.fold<double>(0, (sum, p) => sum + p.value) / points.length;
  double get minimum => points.map((p) => p.value).reduce(math.min);
  double get maximum => points.map((p) => p.value).reduce(math.max);
  bool connects(SleepMetricPoint a, SleepMetricPoint b) =>
      identical(a.window, b.window) &&
      a.asleepRun == b.asleepRun &&
      b.at.difference(a.at).inSeconds <= maxGapSeconds;
}

List<SleepMetricSeries> sleepMetricSeries(
  HealthRecord sleep,
  Iterable<HealthRecord> candidates, {
  DateTime? now,
}) {
  final cutoff = now ?? DateTime.now();
  final windows = sleepObservationWindows(sleep)
      .where((w) => w.kind != SleepSessionKind.nap && !w.end.isAfter(cutoff))
      .toList();
  if (windows.isEmpty) return const [];
  final timeline = sleep.sleepTimeline;
  // Build contiguous asleep runs once. Clear/unknown/off-wrist and true
  // holes break the line even if there are samples just either side.
  final runs = <(DateTime, DateTime)>[];
  if (timeline != null) {
    for (final session in timeline.sessions.where(
      (s) => s.kind != SleepSessionKind.nap,
    )) {
      var firstOfSession = true;
      for (final segment in session.segments) {
        if (!segment.isAsleep) continue;
        if (!firstOfSession && runs.last.$2 == segment.startAt) {
          runs[runs.length - 1] = (runs.last.$1, segment.endAt);
        } else {
          runs.add((segment.startAt, segment.endAt));
        }
        firstOfSession = false;
      }
    }
    runs.sort((a, b) => a.$1.compareTo(b.$1));
  }
  int runAt(DateTime value) {
    var lo = 0, hi = runs.length - 1;
    while (lo <= hi) {
      final i = (lo + hi) ~/ 2;
      final (start, end) = runs[i];
      if (value.isBefore(start)) {
        hi = i - 1;
      } else if (!value.isBefore(end)) {
        lo = i + 1;
      } else {
        return i;
      }
    }
    return -1;
  }

  final groups =
      <
        String,
        List<({SleepMetricPoint point, HealthRecord record, String algorithm})>
      >{};
  for (final r in candidates) {
    if (r.deviceId != sleep.deviceId ||
        r.source != MeasurementSource.wearable ||
        r.origin != MeasurementOrigin.watchHistory ||
        !{'sdk', 'slot'}.contains(r.provenance['timeBasis']) ||
        r.provenance['contactVerified'] == false ||
        r.provenance['sdkQuality'] == 0 ||
        r.values['sdkQuality'] == 0 ||
        {
          'invalid',
          'suspect',
          'poor',
          'failed',
        }.contains(r.quality.toLowerCase()) ||
        (r.provenance['validCount'] is num &&
            (r.provenance['validCount'] as num) < 2) ||
        !hasSaneWearableTransportValues(r)) {
      continue;
    }
    if (sleep.sourceVendor.isNotEmpty &&
        r.sourceVendor.isNotEmpty &&
        sleep.sourceVendor != r.sourceVendor) {
      continue;
    }
    final window = windows.where((w) => w.contains(r.measuredAt)).firstOrNull;
    if (window == null) continue;
    final run = timeline == null ? 0 : runAt(r.measuredAt);
    if (run < 0) continue;
    final metric = r.metric;
    if (!{
      HealthMetric.heartRate,
      HealthMetric.hrv,
      HealthMetric.bloodOxygen,
    }.contains(metric)) {
      continue;
    }
    final declared = r.provenance['algorithm'];
    final algorithm = metric == HealthMetric.hrv
        ? (declared == 'sdnn' || declared == 'rmssd' ? declared as String : '')
        : '';
    if (metric == HealthMetric.hrv && algorithm.isEmpty) continue;
    final unit = metric == HealthMetric.hrv
        ? 'ms'
        : metric == HealthMetric.heartRate
        ? 'bpm'
        : '%';
    final value = (r.values[algorithm] ?? r.values['value'])?.toDouble();
    if (r.unit.trim().toLowerCase() != unit ||
        value == null ||
        !value.isFinite ||
        value <= 0 ||
        (metric == HealthMetric.hrv && value > 1000)) {
      continue;
    }
    final signature = [
      r.deviceId,
      r.sourceVendor,
      r.sourceModel,
      r.firmwareVersion,
      r.rawVersion,
      metric.name,
      unit,
      algorithm,
    ].join('|');
    (groups[signature] ??= []).add((
      point: SleepMetricPoint(r.measuredAt, value, window, run),
      record: r,
      algorithm: algorithm,
    ));
  }
  final result = <SleepMetricSeries>[];
  for (final entry in groups.entries) {
    final unique = <int, SleepMetricPoint>{};
    final conflicts = <int>{};
    final periods = <int>{};
    for (final row in entry.value) {
      final point = row.point, key = row.point.at.millisecondsSinceEpoch;
      if (unique[key] != null && unique[key]!.value != point.value) {
        conflicts.add(key);
      }
      unique[key] = point;
      final period = row.record.provenance['intervalSeconds'];
      if (period is num && period.isFinite && period >= 1 && period <= 3600) {
        periods.add(period.toInt());
      }
    }
    final points =
        unique.entries
            .where((e) => !conflicts.contains(e.key))
            .map((e) => e.value)
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    if (points.isEmpty) continue;
    final first = entry.value.first;
    // Unknown cadence is not evidence that consecutive samples were
    // continuous; show individual points rather than interpolating a line.
    result.add(
      SleepMetricSeries(
        metric: first.record.metric,
        unit: first.record.unit,
        signature: entry.key,
        algorithm: first.algorithm,
        points: points,
        maxGapSeconds: periods.length == 1 ? periods.single * 3 ~/ 2 : 0,
      ),
    );
  }
  result.sort((a, b) => a.metric.index.compareTo(b.metric.index));
  return result;
}
