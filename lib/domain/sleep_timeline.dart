import 'dart:convert';

import 'package:crypto/crypto.dart';

enum SleepStage { awake, light, deep, rem, unknown, notWorn }

enum SleepSessionKind { night, nap, unknown }

/// A device-reported interval, kept separately from numeric health summaries.
class SleepStageSegment {
  const SleepStageSegment({
    required this.startAt,
    required this.endAt,
    required this.stage,
    required this.rawStage,
    this.reportedMinutes,
  });

  final DateTime startAt;
  final DateTime endAt;
  final SleepStage stage;
  final int rawStage;
  final num? reportedMinutes;

  double get durationMinutes => endAt.difference(startAt).inSeconds / 60;
  bool get isAsleep =>
      const {SleepStage.light, SleepStage.deep, SleepStage.rem}.contains(stage);
  bool get isValid =>
      endAt.isAfter(startAt) &&
      durationMinutes <= 1440 &&
      (reportedMinutes == null ||
          (reportedMinutes!.isFinite &&
              reportedMinutes! >= 0 &&
              reportedMinutes! <= 1440));

  factory SleepStageSegment.fromJson(Map<String, Object?> json) =>
      SleepStageSegment(
        startAt: DateTime.parse('${json['startAt']}').toUtc(),
        endAt: DateTime.parse('${json['endAt']}').toUtc(),
        stage: SleepStage.values.firstWhere(
          (value) => value.name == json['stage'],
          orElse: () => SleepStage.unknown,
        ),
        rawStage: (json['rawStage'] as num?)?.toInt() ?? -1,
        reportedMinutes: json['reportedMinutes'] as num?,
      );

  Map<String, Object?> toJson() => {
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
    'stage': stage.name,
    'rawStage': rawStage,
    if (reportedMinutes != null) 'reportedMinutes': reportedMinutes,
  };
}

class SleepSession {
  SleepSession({
    required this.kind,
    required List<SleepStageSegment> segments,
    List<Map<String, Object?>> rawSegments = const [],
  }) : segments = List.unmodifiable(_normalizeSegments(segments)),
       rawSegments = List.unmodifiable(
         rawSegments.map((row) => Map<String, Object?>.unmodifiable(row)),
       );

  final SleepSessionKind kind;
  final List<SleepStageSegment> segments;

  /// Original SDK fields, including rows whose timestamps could not be parsed.
  final List<Map<String, Object?>> rawSegments;

  bool get hasSegments => segments.isNotEmpty;
  DateTime? get startedAt => hasSegments ? segments.first.startAt : null;
  DateTime? get endedAt => hasSegments ? segments.last.endAt : null;
  double minutesFor(SleepStage stage) => segments
      .where((segment) => segment.stage == stage)
      .fold(0.0, (total, segment) => total + segment.durationMinutes);
  double get deepMinutes => minutesFor(SleepStage.deep);
  double get lightMinutes => minutesFor(SleepStage.light);
  double get remMinutes => minutesFor(SleepStage.rem);
  double get awakeMinutes => minutesFor(SleepStage.awake);
  double get asleepMinutes => deepMinutes + lightMinutes + remMinutes;

  factory SleepSession.fromJson(Map<String, Object?> json) {
    final segments = <SleepStageSegment>[];
    for (final row in (json['segments'] as List? ?? const [])) {
      if (row is! Map) {
        throw const FormatException('Invalid sleep stage packet');
      }
      final segment = SleepStageSegment.fromJson(
        row.map((key, value) => MapEntry('$key', value)),
      );
      if (!segment.isValid) {
        throw const FormatException('Invalid sleep stage interval');
      }
      segments.add(segment);
    }
    return SleepSession(
      kind: SleepSessionKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => SleepSessionKind.unknown,
      ),
      segments: segments,
      rawSegments: (json['rawSegments'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => row.map((key, value) => MapEntry('$key', value)))
          .toList(),
    );
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'segments': segments.map((segment) => segment.toJson()).toList(),
    'rawSegments': rawSegments,
  };
}

/// One successful complete SDK day response, including an explicitly empty day.
class SleepTimeline {
  SleepTimeline({
    required this.deviceId,
    required this.sdkDate,
    required this.timezone,
    required this.readAt,
    required List<SleepSession> sessions,
    Map<String, num> rawSummary = const {},
    this.revision = 0,
  }) : sessions = List.unmodifiable(sessions),
       rawSummary = Map.unmodifiable(rawSummary) {
    if (deviceId.trim().isEmpty ||
        !isSdkDate(sdkDate) ||
        _offset(timezone) == null ||
        revision < 0 ||
        rawSummary.values.any((value) => !value.isFinite)) {
      throw const FormatException('Invalid sleep day identity or metadata');
    }
    const durationKeys = [
      'totalSeconds',
      'deepSeconds',
      'lightSeconds',
      'awakeSeconds',
      'remSeconds',
      'napSeconds',
    ];
    if (durationKeys.any((key) {
          final value = this.rawSummary[key];
          return value != null && (value < 0 || value > 86400);
        }) ||
        const [
              'deepSeconds',
              'lightSeconds',
              'awakeSeconds',
              'remSeconds',
            ].fold<num>(
              0,
              (total, key) => total + (this.rawSummary[key] ?? 0),
            ) >
            86400) {
      throw const FormatException('Invalid sleep day summary durations');
    }
    final all = this.sessions.expand((session) => session.segments).toList();
    all.sort((left, right) => left.startAt.compareTo(right.startAt));
    if (all.any(
          (segment) =>
              segment.endAt.isAfter(readAt.add(const Duration(minutes: 5))),
        ) ||
        List.generate(
          all.length > 1 ? all.length - 1 : 0,
          (index) => index,
        ).any((index) => all[index + 1].startAt.isBefore(all[index].endAt)) ||
        all.fold<double>(0, (sum, segment) => sum + segment.durationMinutes) >
            1440) {
      throw const FormatException('Invalid sleep day intervals');
    }
  }

  final String deviceId;

  /// The SDK's requested day, not an inferred bedtime or wake-up date.
  final String sdkDate;
  final String timezone;
  final DateTime readAt;
  final List<SleepSession> sessions;
  final Map<String, num> rawSummary;
  final int revision;

  bool get hasSegments => sessions.any((session) => session.hasSegments);
  bool get hasRawData =>
      hasSegments ||
      sessions.any((session) => session.rawSegments.isNotEmpty) ||
      const [
        'totalSeconds',
        'deepSeconds',
        'lightSeconds',
        'awakeSeconds',
        'remSeconds',
        'napSeconds',
        'reportedTotalMinutes',
      ].any((key) => (rawSummary[key] ?? 0) > 0);

  /// Actual stage aggregates can exist without recoverable segment timestamps.
  bool get hasConfirmedSummary => asleepMinutes > 0;
  double _sum(double Function(SleepSession) value) =>
      sessions.fold(0, (total, session) => total + value(session));
  double get asleepMinutes => deepMinutes + lightMinutes + remMinutes;
  double get awakeMinutes => minutesFor(SleepStage.awake);
  double get deepMinutes => minutesFor(SleepStage.deep);
  double get lightMinutes => minutesFor(SleepStage.light);
  double get remMinutes => minutesFor(SleepStage.rem);
  double minutesFor(SleepStage stage) {
    if (hasSegments) return _sum((session) => session.minutesFor(stage));
    final key = switch (stage) {
      SleepStage.deep => 'deepSeconds',
      SleepStage.light => 'lightSeconds',
      SleepStage.awake => 'awakeSeconds',
      SleepStage.rem => 'remSeconds',
      _ => null,
    };
    return key == null ? 0 : (rawSummary[key] ?? 0).toDouble() / 60;
  }

  Map<String, num> get summaryValues => {
    if (hasConfirmedSummary) ...{
      'value': asleepMinutes / 60,
      if (hasSegments || rawSummary.containsKey('deepSeconds'))
        'deepHours': deepMinutes / 60,
      if (hasSegments || rawSummary.containsKey('lightSeconds'))
        'lightHours': lightMinutes / 60,
      if (hasSegments || rawSummary.containsKey('remSeconds'))
        'remHours': remMinutes / 60,
      if (hasSegments || rawSummary.containsKey('awakeSeconds'))
        'awakeMinutes': awakeMinutes,
    } else if (awakeMinutes > 0)
      'awakeMinutes': awakeMinutes,
    if (hasRawData)
      for (final key in const ['score', 'efficiency', 'wakeCount'])
        if (_hasValidReportedMetric(key)) key: rawSummary[key]!,
  };

  bool _hasValidReportedMetric(String key) {
    final value = rawSummary[key];
    return value != null &&
        value >= 0 &&
        (key == 'wakeCount' ? value <= 1440 : value <= 100);
  }

  DateTime? get startedAt => _extreme((session) => session.startedAt, false);
  DateTime? get endedAt => _extreme((session) => session.endedAt, true);

  DateTime? _extreme(DateTime? Function(SleepSession) value, bool latest) {
    final dates = sessions.map(value).whereType<DateTime>().toList()..sort();
    return dates.isEmpty ? null : (latest ? dates.last : dates.first);
  }

  /// Shows the device-time interpretation saved when this packet was read.
  DateTime displayTime(DateTime instant) {
    final shifted = instant.toUtc().add(_offset(timezone)!);
    // Keep these display fields independent from the host timezone's DST gaps.
    return shifted;
  }

  String get contentHash {
    final canonical = _canonical({
      'deviceId': deviceId,
      'sdkDate': sdkDate,
      'timezone': timezone,
      'sessions': sessions.map((session) => session.toJson()).toList(),
      'rawSummary': rawSummary,
    });
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  SleepTimeline withRevision(int value) => SleepTimeline(
    deviceId: deviceId,
    sdkDate: sdkDate,
    timezone: timezone,
    readAt: readAt,
    sessions: sessions,
    rawSummary: rawSummary,
    revision: value,
  );

  factory SleepTimeline.fromJson(Map<String, Object?> json) => SleepTimeline(
    deviceId: '${json['deviceId'] ?? ''}',
    sdkDate: '${json['sdkDate'] ?? ''}',
    timezone: '${json['timezone'] ?? ''}',
    readAt: DateTime.parse('${json['readAt']}').toUtc(),
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    sessions: (json['sessions'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) => SleepSession.fromJson(
            row.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(),
    rawSummary: (json['rawSummary'] as Map? ?? const {}).map(
      (key, value) => MapEntry('$key', value as num),
    ),
  );

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'sdkDate': sdkDate,
    'timezone': timezone,
    'readAt': readAt.toUtc().toIso8601String(),
    'revision': revision,
    'sessions': sessions.map((session) => session.toJson()).toList(),
    'rawSummary': rawSummary,
  };

  static bool isSdkDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final date = DateTime.tryParse(value);
    return date != null && date.toIso8601String().substring(0, 10) == value;
  }

  static Duration? _offset(String value) {
    final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final hours = int.parse(match[2]!);
    final minutes = int.parse(match[3]!);
    if (hours > 14 || minutes > 59 || (hours == 14 && minutes != 0)) {
      return null;
    }
    final total = hours * 60 + minutes;
    return Duration(minutes: match[1] == '-' ? -total : total);
  }
}

List<SleepStageSegment> _normalizeSegments(List<SleepStageSegment> input) {
  // A partial/corrupt day must not become a confirmed empty replacement.
  if (input.any((segment) => !segment.isValid)) {
    throw const FormatException('Invalid sleep stage interval');
  }
  final valid = input;
  final boundaries =
      valid
          .expand((segment) => [segment.startAt.toUtc(), segment.endAt.toUtc()])
          .toSet()
          .toList()
        ..sort();
  final result = <SleepStageSegment>[];
  for (var index = 0; index + 1 < boundaries.length; index++) {
    final start = boundaries[index], end = boundaries[index + 1];
    final covering = valid.where(
      (segment) =>
          !segment.startAt.isAfter(start) && !segment.endAt.isBefore(end),
    );
    if (covering.isEmpty) continue;
    final stages = covering.map((segment) => segment.stage).toSet();
    final rawStages = covering.map((segment) => segment.rawStage).toSet();
    final stage = stages.length == 1 ? stages.single : SleepStage.unknown;
    final rawStage = rawStages.length == 1 ? rawStages.single : -1;
    final previous = result.lastOrNull;
    if (previous != null &&
        previous.endAt == start &&
        previous.stage == stage &&
        previous.rawStage == rawStage) {
      result.removeLast();
      result.add(
        SleepStageSegment(
          startAt: previous.startAt,
          endAt: end,
          stage: stage,
          rawStage: rawStage,
        ),
      );
    } else {
      result.add(
        SleepStageSegment(
          startAt: start,
          endAt: end,
          stage: stage,
          rawStage: rawStage,
        ),
      );
    }
  }
  return result;
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) {
    final items = value.map(_canonical).toList();
    items.sort((left, right) => jsonEncode(left).compareTo(jsonEncode(right)));
    return items;
  }
  return value;
}
