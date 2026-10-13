import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';

void main() {
  test('sleep excludes awake and unknown and preserves SDK raw total', () {
    final timeline = _timeline([
      _segment(0, 60, SleepStage.deep, 1),
      _segment(60, 90, SleepStage.light, 2),
      _segment(90, 100, SleepStage.awake, 3),
      _segment(100, 115, SleepStage.rem, 4),
      _segment(115, 120, SleepStage.unknown, 5),
    ]);
    expect(timeline.asleepMinutes, 105);
    expect(timeline.awakeMinutes, 10);
    expect(timeline.minutesFor(SleepStage.unknown), 5);
    expect(timeline.rawSummary['totalSeconds'], 7200);
    expect(timeline.summaryValues['value'], 1.75);
    expect(timeline.summaryValues['score'], 82);
    expect(
      timeline.displayTime(timeline.startedAt!),
      DateTime.utc(2026, 9, 30, 22),
    );
    expect(timeline.displayTime(timeline.endedAt!), DateTime.utc(2026, 10, 1));
  });

  test(
    'partial conflicting overlap preserves both non-overlapping portions',
    () {
      final timeline = _timeline([
        _segment(0, 60, SleepStage.deep, 1),
        _segment(30, 90, SleepStage.light, 2),
      ]);
      expect(timeline.deepMinutes, 30);
      expect(timeline.lightMinutes, 30);
      expect(timeline.minutesFor(SleepStage.unknown), 30);
      expect(timeline.asleepMinutes, 60);
      expect(timeline.sessions.single.segments.length, 3);
    },
  );

  test('same-stage overlapping or duplicate intervals count only once', () {
    final timeline = _timeline([
      _segment(0, 60, SleepStage.deep, 1),
      _segment(0, 60, SleepStage.deep, 1),
      _segment(30, 90, SleepStage.deep, 1),
    ]);
    expect(timeline.deepMinutes, 90);
    expect(timeline.sessions.single.segments.length, 1);
  });

  test(
    'a conflicting night and nap response cannot replace a confirmed day',
    () {
      expect(
        () => SleepTimeline(
          deviceId: 'qring:device',
          sdkDate: '2026-10-01',
          timezone: '+08:00',
          readAt: DateTime.utc(2026, 10, 1, 18),
          sessions: [
            SleepSession(
              kind: SleepSessionKind.night,
              segments: [_segment(0, 60, SleepStage.deep, 1)],
            ),
            SleepSession(
              kind: SleepSessionKind.nap,
              segments: [_segment(30, 90, SleepStage.light, 2)],
            ),
          ],
        ),
        throwsFormatException,
      );
    },
  );

  test('empty completed SDK day has no invented zero health summary', () {
    final empty = SleepTimeline.fromJson({
      ..._timeline([]).toJson(),
      'rawSummary': <String, num>{},
    });
    expect(empty.hasSegments, isFalse);
    expect(empty.hasRawData, isFalse);
    expect(empty.hasConfirmedSummary, isFalse);
    expect(empty.summaryValues, isEmpty);
    expect(empty.startedAt, isNull);
    expect(empty.endedAt, isNull);
  });

  test('real SDK stage aggregates survive without fabricated timestamps', () {
    final summary = SleepTimeline.fromJson({
      ..._timeline([]).toJson(),
      'rawSummary': {
        'totalSeconds': 8100,
        'deepSeconds': 3600,
        'lightSeconds': 2700,
        'remSeconds': 900,
        'awakeSeconds': 900,
        'napSeconds': 600,
        'score': 82,
      },
    });
    expect(summary.hasSegments, isFalse);
    expect(summary.hasRawData, isTrue);
    expect(summary.hasConfirmedSummary, isTrue);
    expect(summary.asleepMinutes, 120);
    expect(summary.summaryValues['value'], 2);
    expect(summary.summaryValues['awakeMinutes'], 15);
    expect(summary.summaryValues['score'], 82);
    expect(summary.startedAt, isNull);
    expect(summary.endedAt, isNull);
    expect(summary.sessions, hasLength(1));
    expect(summary.sessions.single.segments, isEmpty);
  });

  test('totals-only data does not invent sleep or stage durations', () {
    final summary = SleepTimeline.fromJson({
      ..._timeline([]).toJson(),
      'rawSummary': {'totalSeconds': 8100, 'napSeconds': 600, 'score': 82},
    });
    expect(summary.hasRawData, isTrue);
    expect(summary.hasConfirmedSummary, isFalse);
    expect(summary.asleepMinutes, 0);
    expect(summary.summaryValues.containsKey('value'), isFalse);
    expect(summary.summaryValues.containsKey('deepHours'), isFalse);
    expect(summary.summaryValues['score'], 82);
    expect(summary.startedAt, isNull);
  });

  test('unknown intervals do not use conflicting raw aggregates as sleep', () {
    final summary = SleepTimeline.fromJson({
      ..._timeline([_segment(0, 60, SleepStage.unknown, 5)]).toJson(),
      'rawSummary': {'deepSeconds': 3600},
    });
    expect(summary.hasSegments, isTrue);
    expect(summary.hasRawData, isTrue);
    expect(summary.hasConfirmedSummary, isFalse);
    expect(summary.summaryValues.containsKey('value'), isFalse);
  });

  test('invalid SDK aggregate durations reject the complete day', () {
    for (final raw in [
      {'deepSeconds': -1},
      {'totalSeconds': 86401},
      {'deepSeconds': 50000, 'lightSeconds': 50000},
    ]) {
      expect(
        () => SleepTimeline.fromJson({
          ..._timeline([]).toJson(),
          'rawSummary': raw,
        }),
        throwsFormatException,
      );
    }
  });

  test(
    'snapshot hash ignores read time and storage revision but keeps raw packet',
    () {
      final first = _timeline([_segment(0, 60, SleepStage.deep, 1)]);
      final same = SleepTimeline.fromJson({
        ...first.toJson(),
        'readAt': '2026-10-02T18:00:00Z',
        'revision': 22,
      });
      expect(first.contentHash, same.contentHash);
      expect(SleepTimeline.fromJson(first.toJson()).toJson(), first.toJson());
      final changed = _timeline([_segment(0, 90, SleepStage.deep, 1)]);
      expect(changed.contentHash, isNot(first.contentHash));
    },
  );

  test('invalid calendar date, offset and future intervals are rejected', () {
    final valid = _timeline([]).toJson();
    expect(
      () => SleepTimeline.fromJson({...valid, 'sdkDate': '2026-02-31'}),
      throwsFormatException,
    );
    expect(
      () => SleepTimeline.fromJson({...valid, 'timezone': '+14:30'}),
      throwsFormatException,
    );
    expect(
      () => SleepTimeline.fromJson({
        ..._timeline([_segment(0, 60, SleepStage.deep, 1)]).toJson(),
        'readAt': '2026-09-30T13:00:00Z',
      }),
      throwsFormatException,
    );
  });

  test('malformed intervals reject the day instead of becoming empty', () {
    final packet = _timeline([_segment(0, 60, SleepStage.deep, 1)]).toJson();
    final session = (packet['sessions'] as List).single as Map;
    final segment = (session['segments'] as List).single as Map;
    segment['endAt'] = segment['startAt'];
    expect(() => SleepTimeline.fromJson(packet), throwsFormatException);
    expect(
      () => SleepSession(
        kind: SleepSessionKind.night,
        segments: [_segment(60, 0, SleepStage.deep, 1)],
      ),
      throwsFormatException,
    );
  });

  test(
    'HealthRecord round-trips optional timeline and reads legacy summaries',
    () {
      final record = HealthRecord(
        id: 'sleep',
        metric: HealthMetric.sleep,
        values: const {'value': 1},
        unit: 'h',
        measuredAt: DateTime.utc(2026, 10, 1),
        timezone: '+08:00',
        deviceId: 'qring:device',
        firmwareVersion: '1',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        rawVersion: 2,
        sleepTimeline: _timeline([_segment(0, 60, SleepStage.deep, 1)]),
      );
      final decoded = HealthRecord.fromJson(record.toJson());
      expect(
        decoded.sleepTimeline!.contentHash,
        record.sleepTimeline!.contentHash,
      );
      expect(
        decoded.copyWith(quality: 'unknown').sleepTimeline,
        decoded.sleepTimeline,
      );
      final old = record.toJson()..remove('sleepTimeline');
      expect(HealthRecord.fromJson(old).sleepTimeline, isNull);
    },
  );
}

SleepStageSegment _segment(int start, int end, SleepStage stage, int raw) =>
    SleepStageSegment(
      startAt: DateTime.utc(2026, 9, 30, 14).add(Duration(minutes: start)),
      endAt: DateTime.utc(2026, 9, 30, 14).add(Duration(minutes: end)),
      stage: stage,
      rawStage: raw,
      reportedMinutes: end - start,
    );

SleepTimeline _timeline(List<SleepStageSegment> segments) => SleepTimeline(
  deviceId: 'qring:device',
  sdkDate: '2026-10-01',
  timezone: '+08:00',
  readAt: DateTime.utc(2026, 10, 1, 18),
  sessions: [
    SleepSession(
      kind: SleepSessionKind.night,
      segments: segments,
      rawSegments: segments.map((segment) => segment.toJson()).toList(),
    ),
  ],
  rawSummary: const {'totalSeconds': 7200, 'score': 82},
);
