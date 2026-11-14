import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_report_view.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';

final _start = DateTime.utc(2026, 10, 31, 15);
DateTime at(int minutes) => _start.add(Duration(minutes: minutes));

HealthRecord sleep({bool summary = false, bool windows = false}) =>
    HealthRecord(
      id: 'sleep',
      metric: HealthMetric.sleep,
      measuredAt: at(480),
      deviceId: 'fixture-r8',
      sourceVendor: 'qring',
      timezone: '+08:00',
      firmwareVersion: '1.2.3',
      values: {'value': 6},
      unit: 'h',
      quality: 'valid',
      source: MeasurementSource.wearable,
      rawVersion: 1,
      nightWindows: windows
          ? [
              {
                'kind': 'night',
                'startAt': '2026-10-31T23:00:00+08:00',
                'endAt': '2026-11-01T07:00:00+08:00',
              },
              {
                'kind': 'nap',
                'startAt': '2026-11-01T13:00:00+08:00',
                'endAt': '2026-11-01T13:20:00+08:00',
              },
            ]
          : const [],
      sleepTimeline: summary
          ? null
          : SleepTimeline(
              deviceId: 'fixture-r8',
              sdkDate: '2026-11-01',
              timezone: '+08:00',
              readAt: at(480),
              sessions: [
                SleepSession(
                  kind: SleepSessionKind.night,
                  segments: [
                    SleepStageSegment(
                      startAt: at(0),
                      endAt: at(120),
                      stage: SleepStage.light,
                      rawStage: 1,
                    ),
                    SleepStageSegment(
                      startAt: at(120),
                      endAt: at(126),
                      stage: SleepStage.awake,
                      rawStage: 0,
                    ),
                    SleepStageSegment(
                      startAt: at(130),
                      endAt: at(480),
                      stage: SleepStage.deep,
                      rawStage: 2,
                    ),
                  ],
                ),
              ],
            ),
    );

HealthRecord reading(
  int minute, {
  HealthMetric metric = HealthMetric.heartRate,
  double value = 67,
  String device = 'fixture-r8',
  String firmware = '1.2.3',
  String? algorithm,
  String time = 'sdk',
  bool contact = true,
  String quality = 'valid',
  MeasurementOrigin origin = MeasurementOrigin.watchHistory,
}) => HealthRecord(
  id: 'sample-$minute-${metric.name}-$value',
  metric: metric,
  measuredAt: at(minute),
  deviceId: device,
  sourceVendor: 'qring',
  firmwareVersion: firmware,
  unit: metric == HealthMetric.hrv ? 'ms' : 'bpm',
  quality: quality,
  values: {'value': value},
  timezone: '+08:00',
  source: MeasurementSource.wearable,
  origin: origin,
  rawVersion: 1,
  provenance: {
    'timeBasis': time,
    'contactVerified': contact,
    'intervalSeconds': 300,
    'algorithm': ?algorithm,
  },
);

void main() {
  test(
    'calendar windows retain SDK day across midnight, week and month edges',
    () {
      final main = mainSleepWindow(sleep())!;
      final day = DateTime(2026, 11, 1);
      expect(sleepMinutesFromSdkDay(main.clock(main.start), day), -60);
      expect(sleepMinutesFromSdkDay(main.clock(main.end), day), 420);
      final week = sleepPeriodRange(day, SleepReportPeriod.week);
      expect(week.start, DateTime(2026, 10, 26));
      expect(week.end, day);
      final leap = sleepPeriodRange(
        DateTime(2028, 2, 29),
        SleepReportPeriod.month,
      );
      expect(sleepDaysInRange(leap.start, leap.end), hasLength(29));
      expect(sleepObservationWindows(sleep(summary: true)), isEmpty);
      expect(
        sleepObservationWindows(sleep(summary: true, windows: true)).last.kind,
        SleepSessionKind.nap,
      );
    },
  );

  test('only genuine same-device asleep samples appear; gaps remain gaps', () {
    final results = sleepMetricSeries(sleep(), [
      reading(-1),
      reading(30, value: 66),
      reading(35, value: 68),
      reading(119),
      reading(121),
      reading(128),
      reading(140),
      reading(141, device: 'old-ring'),
      reading(142, time: 'received'),
      reading(143, contact: false),
      reading(144, quality: 'invalid'),
      reading(145, origin: MeasurementOrigin.appMeasurement),
      reading(146, firmware: '1.2.4'),
      reading(147, value: 62),
      reading(147, value: 70),
      reading(480),
    ]);
    expect(results, hasLength(2)); // firmware signatures must differ
    final series = results.singleWhere((s) => s.points.length > 1);
    expect(series.points.map((p) => p.at), [at(30), at(35), at(119), at(140)]);
    expect(series.minimum, 66);
    expect(series.connects(series.points[0], series.points[1]), isTrue);
    expect(series.connects(series.points[1], series.points[2]), isFalse);
    expect(series.connects(series.points[2], series.points[3]), isFalse);
  });

  test('unknown HRV stays hidden, RMSSD and SDNN remain separate', () {
    final results = sleepMetricSeries(sleep(), [
      reading(100, metric: HealthMetric.hrv, value: 32, algorithm: 'rmssd'),
      reading(105, metric: HealthMetric.hrv, value: 45, algorithm: 'sdnn'),
      reading(109, metric: HealthMetric.hrv, value: 34),
    ]);
    expect(results.map((s) => s.algorithm).toSet(), {'rmssd', 'sdnn'});
    expect(results.every((s) => s.points.length == 1), isTrue);
    expect(sleepMetricSeries(sleep(summary: true), [reading(100)]), isEmpty);
  });
}
