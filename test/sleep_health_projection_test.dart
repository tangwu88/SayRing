import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';
import 'package:saydian_app/services/sleep_health_projection.dart';

HealthRecord _summary(String device, {num hours = 9}) => HealthRecord(
  id: 'legacy-$device',
  metric: HealthMetric.sleep,
  values: {'value': hours},
  unit: 'h',
  measuredAt: DateTime.utc(2026, 9, 30, 16),
  timezone: '+08:00',
  deviceId: device,
  firmwareVersion: 'verified-firmware',
  quality: 'unknown',
  source: MeasurementSource.wearable,
  origin: MeasurementOrigin.watchHistory,
  rawVersion: 1,
);

SleepTimeline _day({
  String device = 'qring:confirmed',
  int revision = 1,
  bool empty = false,
}) => SleepTimeline(
  deviceId: device,
  sdkDate: '2026-10-01',
  timezone: '+08:00',
  readAt: DateTime.utc(2026, 10, 1, 1),
  revision: revision,
  sessions: empty
      ? []
      : [
          SleepSession(
            kind: SleepSessionKind.night,
            segments: [
              SleepStageSegment(
                startAt: DateTime.utc(2026, 9, 30, 15),
                endAt: DateTime.utc(2026, 9, 30, 16),
                stage: SleepStage.deep,
                rawStage: 3,
              ),
            ],
          ),
        ],
);

void main() {
  test(
    'confirmed timeline replaces stale daily summary only in read model',
    () {
      final old = _summary('qring:confirmed');
      final projected = projectSleepRecords(
        summaries: [old],
        timelines: [_day()],
      );
      expect(projected, hasLength(1));
      expect(projected.single.values['value'], 1);
      expect(projected.single.firmwareVersion, 'verified-firmware');
      expect(projected.single.sleepTimeline!.revision, 1);
      expect(projected.single.id, startsWith('sleep-view-'));
      expect(old.values['value'], 9);
      expect(old.sleepTimeline, isNull);
    },
  );

  test('explicit empty day is not a zero sleep record', () {
    expect(
      projectSleepRecords(
        summaries: [_summary('qring:confirmed')],
        timelines: [_day(empty: true)],
      ),
      isEmpty,
    );
  });

  test('higher persisted revision wins, not input order or cloud summary', () {
    final projected = projectSleepRecords(
      summaries: [_summary('qring:confirmed')],
      timelines: [_day(revision: 2), _day(revision: 1)],
    );
    expect(projected.single.sleepTimeline!.revision, 2);
  });

  test('other device and other SDK history remain available', () {
    final projected = projectSleepRecords(
      summaries: [_summary('qring:other'), _summary('coolwear:other')],
      timelines: [_day()],
    );
    expect(projected, hasLength(3));
    expect(projected.map((record) => record.deviceId), contains('qring:other'));
    expect(
      projected.map((record) => record.deviceId),
      contains('coolwear:other'),
    );
  });

  test('saved timezone and SDK day do not depend on host timezone', () {
    final projected = projectSleepRecords(summaries: [], timelines: [_day()]);
    expect(sleepRecordSdkDate(projected.single), '2026-10-01');
    expect(projected.single.measuredAt, DateTime.utc(2026, 9, 30, 16));
  });

  test(
    'actual stage summary without segments is retained without a timeline',
    () {
      final summaryOnly = SleepTimeline(
        deviceId: 'qring:one',
        sdkDate: '2026-10-01',
        timezone: '+08:00',
        readAt: DateTime.utc(2026, 10, 1, 12),
        sessions: const [],
        rawSummary: const {
          'totalSeconds': 18000,
          'deepSeconds': 3600,
          'lightSeconds': 10800,
          'awakeSeconds': 3600,
        },
      );
      final projected = projectSleepRecords(
        summaries: [],
        timelines: [summaryOnly],
      );
      expect(projected.single.values['value'], 4);
      expect(projected.single.values['awakeMinutes'], 60);
      expect(projected.single.sleepTimeline!.sessions, isEmpty);
      expect(projected.single.values, isNot(contains('score')));
    },
  );
}
