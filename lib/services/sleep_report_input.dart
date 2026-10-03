import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/models.dart';
import '../domain/sleep_timeline.dart';
import 'sleep_health_projection.dart';

/// Aggregate-only AI payload. Raw stages, photos and hardware IDs stay local.
Map<String, Object?> sleepReportInput(HealthRecord record) {
  if (record.metric != HealthMetric.sleep || record.deviceId.isEmpty) {
    throw const FormatException('没有可分析的戒指睡眠数据');
  }
  final values = record.sleepTimeline?.summaryValues ?? record.values;
  final hours = values['value'];
  if (hours == null || !hours.isFinite || hours <= 0 || hours > 24) {
    throw const FormatException('没有有效睡眠数据，不能生成评分');
  }
  final timeline = record.sleepTimeline;
  final sessions =
      timeline?.sessions.where((session) => session.hasSegments).toList() ??
      <SleepSession>[];
  sessions.sort((a, b) => a.startedAt!.compareTo(b.startedAt!));
  final payload = <String, Object?>{
    'sdkDate': sleepRecordSdkDate(record),
    'timezone': record.timezone,
    'sourceKey': sha256
        .convert(utf8.encode(record.deviceId.toLowerCase()))
        .toString(),
    'totalSeconds': (hours * 3600).round(),
    for (final (source, target) in const [
      ('deepHours', 'deepSeconds'),
      ('lightHours', 'lightSeconds'),
      ('remHours', 'remSeconds'),
    ])
      if (values[source] != null) target: (values[source]! * 3600).round(),
    if (values['awakeMinutes'] != null)
      'awakeSeconds': (values['awakeMinutes']! * 60).round(),
    if (values['score'] != null) 'deviceScore': values['score']!.round(),
    if (values['wakeCount'] != null) 'wakeCount': values['wakeCount']!.round(),
    if (timeline?.hasSegments == true) ...{
      'unknownSeconds': (timeline!.minutesFor(SleepStage.unknown) * 60).round(),
      'notWornSeconds': (timeline.minutesFor(SleepStage.notWorn) * 60).round(),
    },
    'sessions': [
      for (final session in sessions)
        {
          'kind': session.kind.name,
          'startAt': _millisecondsUtc(session.startedAt!),
          'endAt': _millisecondsUtc(session.endedAt!),
          'asleepSeconds': (session.asleepMinutes * 60).round(),
        },
    ],
  };
  return payload;
}

String _millisecondsUtc(DateTime time) => DateTime.fromMillisecondsSinceEpoch(
  time.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

String sleepReportSourceHash(Map<String, Object?> input) {
  Object? sorted(Object? value) {
    if (value is List) return value.map(sorted).toList();
    if (value is Map) {
      final keys = value.keys.map((key) => '$key').toList()..sort();
      return {for (final key in keys) key: sorted(value[key])};
    }
    return value;
  }

  return sha256.convert(utf8.encode(jsonEncode(sorted(input)))).toString();
}
