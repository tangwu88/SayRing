import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';
import 'package:saydian_app/services/health_analysis.dart';
import 'package:saydian_app/services/local_health_store.dart';

void main() {
  test(
    'month ranges use whole previous calendar month across unequal lengths',
    () {
      for (final example in [
        (anchor: DateTime(2026, 10, 15), previous: DateTime(2026, 9, 1)),
        (anchor: DateTime(2026, 3, 15), previous: DateTime(2026, 2, 1)),
        (anchor: DateTime(2024, 3, 15), previous: DateTime(2024, 2, 1)),
        (anchor: DateTime(2026, 1, 15), previous: DateTime(2025, 12, 1)),
      ]) {
        final range = HealthTrendRange.forPeriod(
          HealthTrendPeriod.month,
          example.anchor,
        );
        expect(
          range.start,
          DateTime(example.anchor.year, example.anchor.month),
        );
        expect(
          range.end,
          DateTime(example.anchor.year, example.anchor.month + 1),
        );
        expect(range.previousStart, example.previous);
        expect(range.previousEnd, range.start);
      }
    },
  );

  test('day and week range boundaries remain unchanged', () {
    final anchor = DateTime(2026, 10, 1, 15);
    final day = HealthTrendRange.forPeriod(HealthTrendPeriod.day, anchor);
    expect(day.start, DateTime(2026, 10, 1));
    expect(day.end, DateTime(2026, 10, 2));
    expect(day.previousStart, DateTime(2026, 9, 30));
    expect(day.previousEnd, day.start);
    final week = HealthTrendRange.forPeriod(HealthTrendPeriod.week, anchor);
    expect(week.start, DateTime(2026, 9, 28));
    expect(week.end, DateTime(2026, 10, 5));
    expect(week.previousStart, DateTime(2026, 9, 21));
    expect(week.previousEnd, week.start);
  });

  HealthRecord record({
    required String id,
    required HealthMetric metric,
    required DateTime at,
    required Map<String, num> values,
    String timezone = '+08:00',
    String deviceId = 'watch',
    SleepTimeline? sleepTimeline,
  }) => HealthRecord(
    id: id,
    metric: metric,
    values: values,
    unit: metric.defaultUnit,
    measuredAt: at,
    timezone: timezone,
    deviceId: deviceId,
    firmwareVersion: '1',
    quality: 'good',
    source: MeasurementSource.wearable,
    rawVersion: 1,
    sleepTimeline: sleepTimeline,
  );

  test(
    'sleep orders adjacent SDK dates before UTC across +14 and -12 offsets',
    () {
      // Rendering fixtures only: the newer saved SDK day has an earlier UTC start.
      const device = 'qring:00000000-0000-0000-0000-000000000001';
      final newer = record(
        id: 'newer-sdk-day',
        metric: HealthMetric.sleep,
        at: DateTime.utc(2026, 9, 30, 10),
        values: const {'value': 6},
        timezone: '+14:00',
        deviceId: device,
        sleepTimeline: SleepTimeline(
          deviceId: device,
          sdkDate: '2026-10-01',
          timezone: '+14:00',
          readAt: DateTime.utc(2026, 10, 1),
          sessions: const [],
        ),
      );
      final older = record(
        id: 'older-sdk-day',
        metric: HealthMetric.sleep,
        at: DateTime.utc(2026, 9, 30, 12),
        values: const {'value': 7},
        timezone: '-12:00',
        deviceId: device,
        sleepTimeline: SleepTimeline(
          deviceId: device,
          sdkDate: '2026-09-30',
          timezone: '-12:00',
          readAt: DateTime.utc(2026, 10, 1),
          sessions: const [],
        ),
      );
      expect(newer.measuredAt.isBefore(older.measuredAt), isTrue);
      final data = const HealthAnalysisService().analyze(
        metric: HealthMetric.sleep,
        records: [older, newer],
        previousRecords: const [],
        period: HealthTrendPeriod.week,
        anchor: DateTime(2026, 10, 1),
      );
      expect(data.records.map((row) => row.id), [
        'newer-sdk-day',
        'older-sdk-day',
      ]);
    },
  );

  test('legacy sleep also sorts by its saved-offset SDK date', () {
    final newer = record(
      id: 'newer-legacy-day',
      metric: HealthMetric.sleep,
      at: DateTime.utc(2026, 9, 30, 10),
      values: const {'value': 6},
      timezone: '+14:00',
    );
    final older = record(
      id: 'older-legacy-day',
      metric: HealthMetric.sleep,
      at: DateTime.utc(2026, 9, 30, 12),
      values: const {'value': 7},
      timezone: '-12:00',
    );
    final data = const HealthAnalysisService().analyze(
      metric: HealthMetric.sleep,
      records: [older, newer],
      previousRecords: const [],
      period: HealthTrendPeriod.week,
      anchor: DateTime(2026, 10, 1),
    );
    expect(data.records.map((row) => row.id), [
      'newer-legacy-day',
      'older-legacy-day',
    ]);
  });

  test(
    'non-sleep records retain UTC measurement ordering across saved offsets',
    () {
      final earlier = record(
        id: 'earlier-utc',
        metric: HealthMetric.heartRate,
        at: DateTime.utc(2026, 9, 30, 10),
        values: const {'value': 70},
        timezone: '+14:00',
      );
      final later = record(
        id: 'later-utc',
        metric: HealthMetric.heartRate,
        at: DateTime.utc(2026, 9, 30, 12),
        values: const {'value': 80},
        timezone: '-12:00',
      );
      final data = const HealthAnalysisService().analyze(
        metric: HealthMetric.heartRate,
        records: [earlier, later],
        previousRecords: const [],
        period: HealthTrendPeriod.week,
        anchor: DateTime(2026, 10, 1),
      );
      expect(data.records.map((row) => row.id), ['later-utc', 'earlier-utc']);
    },
  );

  test('day analysis deduplicates records and keeps timezone display time', () {
    final first = record(
      id: 'same',
      metric: HealthMetric.heartRate,
      at: DateTime.utc(2026, 8, 13, 0),
      values: const {'value': 70},
    );
    final replacement = record(
      id: 'same',
      metric: HealthMetric.heartRate,
      at: DateTime.utc(2026, 8, 13, 1),
      values: const {'value': 80},
    );
    final data = const HealthAnalysisService().analyze(
      metric: HealthMetric.heartRate,
      records: [first, replacement],
      previousRecords: const [],
      period: HealthTrendPeriod.day,
      anchor: DateTime(2026, 8, 13),
    );

    expect(data.summary.recordCount, 1);
    expect(data.points.single.value, 80);
    expect(data.points.single.at.hour, 9);
  });

  test('legacy Yuc UTC marker displays in the phone local timezone', () {
    final legacy = record(
      id: 'yc-heart_rate-legacy',
      metric: HealthMetric.heartRate,
      at: DateTime.utc(2026, 8, 13, 1, 5),
      values: const {'value': 80},
      timezone: '+00:00',
    );

    expect(
      HealthAnalysisService.displayTime(legacy),
      legacy.measuredAt.toLocal(),
    );
  });

  test(
    'blood pressure computes independent systolic and diastolic summary',
    () {
      final data = const HealthAnalysisService().analyze(
        metric: HealthMetric.bloodPressure,
        records: [
          record(
            id: '1',
            metric: HealthMetric.bloodPressure,
            at: DateTime.utc(2026, 8, 13, 1),
            values: const {'systolic': 120, 'diastolic': 80, 'pulse': 72},
          ),
          record(
            id: '2',
            metric: HealthMetric.bloodPressure,
            at: DateTime.utc(2026, 8, 13, 2),
            values: const {'systolic': 130, 'diastolic': 90, 'pulse': 75},
          ),
        ],
        previousRecords: const [],
        period: HealthTrendPeriod.day,
        anchor: DateTime(2026, 8, 13),
      );

      expect(data.summary.average, 125);
      expect(data.summary.secondaryAverage, 85);
      expect(data.points, hasLength(2));
    },
  );

  test(
    'week activity aggregates by local day and compares previous period',
    () {
      final data = const HealthAnalysisService().analyze(
        metric: HealthMetric.steps,
        records: [
          record(
            id: '1',
            metric: HealthMetric.steps,
            at: DateTime.utc(2026, 8, 10, 1),
            values: const {'value': 1000},
          ),
          record(
            id: '2',
            metric: HealthMetric.steps,
            at: DateTime.utc(2026, 8, 10, 2),
            values: const {'value': 500},
          ),
        ],
        previousRecords: [
          record(
            id: 'p1',
            metric: HealthMetric.steps,
            at: DateTime.utc(2026, 8, 3, 1),
            values: const {'value': 1000},
          ),
        ],
        period: HealthTrendPeriod.week,
        anchor: DateTime(2026, 8, 13),
      );

      expect(data.points.single.value, 1500);
      expect(data.summary.changeFromPrevious, 500);
    },
  );

  test('composite metrics expose only fields present in real records', () {
    final records = [
      record(
        id: '1',
        metric: HealthMetric.bodyComposition,
        at: DateTime.utc(2026, 8, 13),
        values: const {'BMI': 21.2, 'bodyFatPercentage': 18.5},
      ),
    ];

    expect(
      HealthAnalysisService.availableValueKeys(
        HealthMetric.bodyComposition,
        records,
      ),
      ['bmi', 'bodyFatRate'],
    );
  });

  test('body composition aliases merge old and current SDK field names', () {
    final records = [
      record(
        id: 'legacy',
        metric: HealthMetric.bodyComposition,
        at: DateTime.utc(2026, 8, 13, 8),
        values: const {
          'BMI': 21.2,
          'bodyFatPercentage': 18.5,
          'bodyMoisture': 56,
          'basalMetabolism': 1420,
        },
      ),
      record(
        id: 'current',
        metric: HealthMetric.bodyComposition,
        at: DateTime.utc(2026, 8, 13, 9),
        values: const {
          'bmi': 22.1,
          'bodyFatRate': 19.4,
          'bodyWaterRate': 55.2,
          'basalMetabolicRate': 1450,
          'muscleMass': 48.3,
        },
      ),
    ];

    expect(
      HealthAnalysisService.availableValueKeys(
        HealthMetric.bodyComposition,
        records,
      ),
      [
        'bmi',
        'bodyFatRate',
        'muscleMass',
        'bodyWaterRate',
        'basalMetabolicRate',
      ],
    );

    final analysis = const HealthAnalysisService().analyze(
      metric: HealthMetric.bodyComposition,
      records: records,
      previousRecords: const [],
      period: HealthTrendPeriod.day,
      anchor: DateTime(2026, 8, 13),
      selectedValueKey: 'bmi',
    );
    expect(analysis.points.map((point) => point.value), [21.2, 22.1]);
  });

  test(
    'memory store range is half-open and latest keeps sparse metrics',
    () async {
      final store = MemoryHealthStore();
      await store.initialize();
      await store.upsert([
        record(
          id: 'hr-old',
          metric: HealthMetric.heartRate,
          at: DateTime.utc(2026, 8, 12),
          values: const {'value': 70},
        ),
        record(
          id: 'hr-new',
          metric: HealthMetric.heartRate,
          at: DateTime.utc(2026, 8, 13),
          values: const {'value': 80},
        ),
        record(
          id: 'oxygen',
          metric: HealthMetric.bloodOxygen,
          at: DateTime.utc(2026, 7, 1),
          values: const {'value': 98},
        ),
      ]);

      final range = await store.range(
        metric: HealthMetric.heartRate,
        start: DateTime.utc(2026, 8, 12),
        end: DateTime.utc(2026, 8, 13),
      );
      final latest = await store.latestForEachMetric();

      expect(range.map((value) => value.id), ['hr-old']);
      expect(
        latest.map((value) => value.id),
        containsAll(['hr-new', 'oxygen']),
      );
    },
  );

  test('memory store returns every warning in newest-first order', () async {
    final store = MemoryHealthStore();
    await store.initialize();
    await store.saveHealthWarningAlert(
      HealthWarningAlert(
        id: 'older',
        metric: HealthMetric.bodyTemperature,
        title: '体温预警',
        message: '38.1 °C',
        triggeredAt: DateTime.utc(2026, 8, 24, 8),
      ),
    );
    await store.saveHealthWarningAlert(
      HealthWarningAlert(
        id: 'newer',
        metric: HealthMetric.heartRate,
        title: '心率预警',
        message: '121 bpm',
        triggeredAt: DateTime.utc(2026, 8, 25, 8),
      ),
    );

    final alerts = await store.healthWarningAlerts();

    expect(alerts.map((alert) => alert.id), ['newer', 'older']);
  });
}
