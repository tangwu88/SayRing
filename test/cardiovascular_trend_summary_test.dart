import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/ring_experience.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/cardiovascular_trend_summary.dart';
import 'package:saydian_app/ui/cardiovascular_insights.dart';

DateTime day(int n) => DateTime(2026, 1, n);

PressureSample pressure(
  int n,
  int upper, {
  String source = 'reference',
  int hour = 12,
}) => PressureSample(
  at: DateTime(2026, 1, n, hour),
  systolic: upper,
  diastolic: 78,
  source: source,
);

HealthRecord sample(
  HealthMetric m,
  int n,
  num v, {
  String device = 'a',
  int hour = 10,
  String zone = '+00:00',
  String? unit,
  String vendor = '',
  int version = 2,
  String quality = 'valid',
}) {
  final instant = DateTime.utc(2026, 1, n, hour);
  return HealthRecord(
    id: '$device-${m.name}-$instant-$v',
    metric: m,
    values: {'value': v},
    unit:
        unit ??
        switch (m) {
          HealthMetric.heartRate => 'bpm',
          HealthMetric.sleep => 'h',
          _ => 'steps',
        },
    measuredAt: instant,
    timezone: zone,
    deviceId: device,
    firmwareVersion: '',
    quality: quality,
    source: MeasurementSource.wearable,
    rawVersion: version,
    sourceModel: 'Model $device',
    sourceVendor: vendor,
  );
}

CardiovascularSummary summary(
  List<PressureSample> bp,
  List<HealthRecord> data, {
  String? preferred,
}) => CardiovascularSummary(
  start: day(8),
  end: day(14),
  previousStart: day(1),
  readings: bp,
  contextRecords: data,
  now: DateTime.utc(2026, 1, 14, 23),
  preferredDeviceId: preferred,
);

void main() {
  test(
    'uses current pressure sources only, including when the previous period had readings',
    () {
      final r = summary([
        pressure(2, 124, source: 'b'),
        pressure(9, 119),
        pressure(12, 125, source: 'a'),
        pressure(16, 123),
      ], []);
      expect(r.sources, ['a', 'reference']);
      expect(summary([pressure(3, 121)], []).pressure, isEmpty);
    },
  );

  test(
    'cuff uses overlap, a wearable uses only its own source; missing dates do not become zero',
    () {
      final r = summary(
        [pressure(8, 125), pressure(9, 125), pressure(8, 128, source: 'b')],
        [
          sample(HealthMetric.heartRate, 8, 60),
          sample(HealthMetric.heartRate, 8, 80, hour: 11),
          sample(HealthMetric.heartRate, 9, 80),
          sample(HealthMetric.heartRate, 10, 90, device: 'b'),
          sample(
            HealthMetric.heartRate,
            8,
            99,
            device: 'b',
            quality: 'invalid',
          ),
          sample(HealthMetric.heartRate, 11, 230, unit: 'ms'),
          sample(HealthMetric.heartRate, 17, 65),
        ],
        preferred: 'b',
      );
      final hr = r.contextFor('reference').single;
      expect(hr.deviceId, 'a');
      expect(hr.values, {day(8): 70.0, day(9): 80.0});
      expect(r.contextFor('b').single.values, {day(10): 90.0});
    },
  );

  test(
    'uses stored sleep days and wearable display times across midnight, preserving zero steps only when observed',
    () {
      final r = summary([], [
        sample(HealthMetric.sleep, 7, 6.25, hour: 20, zone: '+08:00'),
        sample(HealthMetric.sleep, 7, 28, hour: 21, zone: '+08:00'),
        sample(HealthMetric.heartRate, 8, 63, hour: 1, zone: '-08:00'),
        sample(HealthMetric.heartRate, 8, 68, hour: 18, zone: '-08:00'),
        sample(HealthMetric.steps, 8, 0),
        sample(
          HealthMetric.steps,
          10,
          200,
          hour: 11,
          vendor: 'qring',
          version: 3,
        ),
        sample(
          HealthMetric.steps,
          10,
          350,
          hour: 15,
          vendor: 'qring',
          version: 3,
        ),
        sample(
          HealthMetric.steps,
          10,
          350,
          hour: 15,
          vendor: 'qring',
          version: 3,
        ),
        sample(HealthMetric.steps, 11, 45, hour: 10, vendor: 'qring'),
        sample(HealthMetric.steps, 11, 31, hour: 12, vendor: 'qring'),
      ]);
      final by = {for (final s in r.contextFor(null)) s.metric: s};
      expect(by[HealthMetric.sleep]!.values, {day(8): 375.0});
      expect(by[HealthMetric.heartRate]!.period(day(8), day(14)), {
        day(8): 68.0,
      });
      expect(by[HealthMetric.steps]!.values, {
        day(8): 0.0,
        day(10): 350.0,
        day(11): 76.0,
      });
    },
  );

  for (final lang in ['zh', 'en']) {
    testWidgets(
      'integrates paired dates and guards changes on sparse or unpaired evidence ($lang)',
      (t) async {
        late BuildContext c;
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                c = context;
                return const SizedBox();
              },
            ),
          ),
        );
        await t.pumpAndSettle();
        final copy = await CardioInsightCopy.load();
        expect(copy, isNotNull);
        final zh = lang == 'zh';
        List<String> insights(
          List<PressureSample> bp,
          List<HealthRecord> data,
        ) {
          final r = summary(bp, data);
          return cardioInsights(
            c,
            copy!,
            r,
            pressureDays(r.pressure['reference'] ?? []),
            r.contextFor('reference'),
            pressureReadFailed: false,
          );
        }

        final bp = [
          for (final n in [1, 2, 3]) pressure(n, 120),
          for (final n in [8, 9, 10]) pressure(n, 130),
          pressure(11, 190),
        ];
        final hr = [
          for (final n in [1, 2, 3]) sample(HealthMetric.heartRate, n, 62),
          for (final n in [8, 9, 10]) sample(HealthMetric.heartRate, n, 72),
          sample(HealthMetric.heartRate, 12, 95),
        ];
        var lines = insights(bp, hr);
        expect(lines.first, contains('25 mmHg'));
        expect(lines.last, contains('10 mmHg'));
        expect(lines.last, contains('62 bpm'));
        expect(lines.last, contains('72 bpm'));
        expect(lines.join(), isNot(contains('{')));
        final aligned = insights(bp.where((p) => p.at.day != 11).toList(), hr);
        expect(aligned.last, isNot(contains('mmHg')));
        expect(aligned.last, contains('72 bpm'));
        lines = insights(bp, hr.where((r) => r.measuredAt.day != 2).toList());
        expect(lines.last, isNot(contains('62 bpm')));
        expect(lines.last, contains('130/78'));
        lines = insights(
          [pressure(8, 119)],
          [sample(HealthMetric.sleep, 8, 7.25)],
        );
        expect(lines.last, contains('119/78'));
        expect(lines.last, contains(zh ? '7 小时 15 分钟' : '7 h 15 min'));
        lines = insights(
          [pressure(8, 119)],
          [sample(HealthMetric.sleep, 9, 7.25)],
        );
        expect(lines.last, contains(zh ? '不同日期' : 'different dates'));
        lines = insights([], hr);
        expect(lines.last, contains('62 bpm'));
        lines = insights([], [sample(HealthMetric.heartRate, 9, 67)]);
        expect(lines.last, contains('67 bpm'));
        expect(insights([], []), isEmpty);
      },
    );
  }
}
