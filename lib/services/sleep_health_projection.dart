import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/models.dart';
import '../domain/sleep_timeline.dart';

/// Read-only view of confirmed local sleep days and legacy health summaries.
/// View records are never inserted into the generic health upload queue.
List<HealthRecord> projectSleepRecords({
  required Iterable<HealthRecord> summaries,
  required Iterable<SleepTimeline> timelines,
}) {
  final result = <HealthRecord>[];
  final byDay = <String, HealthRecord>{};
  for (final record in summaries) {
    if (record.metric != HealthMetric.sleep) continue;
    if (!record.deviceId.toLowerCase().startsWith('qring:') ||
        record.origin != MeasurementOrigin.watchHistory) {
      result.add(record);
      continue;
    }
    final key = _key(record.deviceId, sleepRecordSdkDate(record));
    final previous = byDay[key];
    if (previous == null ||
        record.measuredAt.isAfter(previous.measuredAt) ||
        (record.measuredAt == previous.measuredAt &&
            record.rawVersion > previous.rawVersion)) {
      byDay[key] = record;
    }
  }
  final confirmed = <String, SleepTimeline>{};
  for (final timeline in timelines) {
    final key = _key(timeline.deviceId, timeline.sdkDate);
    final previous = confirmed[key];
    if (previous == null || timeline.revision > previous.revision) {
      confirmed[key] = timeline;
    }
  }
  for (final entry in confirmed.entries) {
    final timeline = entry.value;
    final previous = byDay.remove(entry.key);
    // A successful explicitly empty SDK day is not a fabricated zero sample.
    if (!timeline.hasRawData) continue;
    // A new confirmed response must not inherit a stale score or duration that
    // this SDK response did not supply. Provenance can still use the old row.
    final values = timeline.summaryValues;
    final day = DateTime.parse(timeline.sdkDate);
    final dayStart = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).subtract(_timezoneOffset(timeline.timezone) ?? Duration.zero);
    result.add(
      HealthRecord(
        id: 'sleep-view-${sha256.convert(utf8.encode(entry.key))}',
        metric: HealthMetric.sleep,
        values: values,
        unit: 'h',
        measuredAt: dayStart,
        timezone: timeline.timezone,
        deviceId: timeline.deviceId,
        firmwareVersion: previous?.firmwareVersion ?? '',
        quality: previous?.quality ?? 'unknown',
        source: MeasurementSource.wearable,
        origin: MeasurementOrigin.watchHistory,
        rawVersion: 4,
        sourceModel: previous?.sourceModel ?? '',
        sourceVendor: previous?.sourceVendor ?? 'qring',
        sourceDeviceCategory: previous?.sourceDeviceCategory ?? 'ring',
        sourceApp: previous?.sourceApp ?? 'say-ring',
        sleepTimeline: timeline,
      ),
    );
  }
  result.addAll(byDay.values);
  result.sort((left, right) {
    final date = sleepRecordSdkDate(right).compareTo(sleepRecordSdkDate(left));
    return date != 0 ? date : right.measuredAt.compareTo(left.measuredAt);
  });
  return result;
}

String sleepRecordSdkDate(HealthRecord record) {
  final timeline = record.sleepTimeline;
  if (timeline != null) return timeline.sdkDate;
  final date = record.measuredAt.toUtc().add(
    _timezoneOffset(record.timezone) ?? Duration.zero,
  );
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _key(String deviceId, String date) => '${deviceId.toLowerCase()}|$date';

Duration? _timezoneOffset(String value) {
  final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final hours = int.parse(match[2]!);
  final minutes = int.parse(match[3]!);
  if (hours > 14 || minutes > 59 || (hours == 14 && minutes != 0)) return null;
  return Duration(minutes: (hours * 60 + minutes) * (match[1] == '-' ? -1 : 1));
}
