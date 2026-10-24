import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/health_record_units.dart';
import 'package:saydian_app/services/health_analysis.dart';

HealthRecord record(
  num value, {
  int version = 3,
  String vendor = 'qring',
  String unit = 'kcal',
}) => HealthRecord(
  id: '$vendor|calories|v$version|synthetic-$value',
  metric: HealthMetric.calories,
  values: {'value': value},
  unit: unit,
  measuredAt: DateTime(2026, 10, 21, 10),
  timezone: '+08:00',
  deviceId: '$vendor:synthetic',
  firmwareVersion: 'synthetic',
  quality: 'synthetic-only',
  source: MeasurementSource.wearable,
  sourceVendor: vendor,
  sourceDeviceCategory: 'ring',
  sourceApp: 'say-ring',
  rawVersion: version,
);
void main() {
  test('legacy and new CoolWear counts are not kcal in any trend period', () {
    for (final unit in ['kcal', 'unknown']) {
      for (final value in [0, 12, 98760]) {
        final r = record(value, vendor: 'coolwear', version: 1, unit: unit);
        final before = jsonEncode(r.toJson());
        expect(hasUnconfirmedCalorieUnit(r), isTrue);
        // Legacy payloads without optional app/category metadata are still v1.
        expect(
          hasUnconfirmedCalorieUnit(
            r.copyWith(sourceApp: '', sourceDeviceCategory: ''),
          ),
          isTrue,
        );
        for (final period in HealthTrendPeriod.values) {
          final data = const HealthAnalysisService().analyze(
            metric: HealthMetric.calories,
            records: [r],
            previousRecords: [r],
            period: period,
            anchor: DateTime(2026, 10, 21),
          );
          expect(data.points, isEmpty);
          expect(data.summary.average, isNull);
          expect(data.summary.previousAverage, isNull);
          expect(data.records, [r]);
        }
        expect(jsonEncode(r.toJson()), before);
      }
    }
  });

  test('unit safety is source and metric scoped, not a numeric threshold', () {
    final pending = record(12, vendor: ' CoolWear ', version: 1);
    expect(hasUnconfirmedCalorieUnit(pending), isTrue);
    for (final metric in [HealthMetric.steps, HealthMetric.distance]) {
      final other = HealthRecord.fromJson({
        ...pending.toJson(),
        'type': metric.wireName,
      });
      expect(hasUnconfirmedCalorieUnit(other), isFalse);
    }
    expect(
      hasUnconfirmedCalorieUnit(
        pending.copyWith(source: MeasurementSource.manual),
      ),
      isFalse,
    );
    expect(hasUnconfirmedCalorieUnit(record(98760, version: 2)), isFalse);
    expect(
      hasUnconfirmedCalorieUnit(record(98760, vendor: 'veepoo', version: 1)),
      isFalse,
    );
  });

  test(
    'iOS provenance is unverified for small, zero and large counts without rewriting payloads',
    () {
      for (final value in [0, 12, 98760]) {
        final r = record(value);
        final before = jsonEncode(r.toJson());
        expect(hasUnconfirmedCalorieUnit(r), isTrue);
        final data = const HealthAnalysisService().analyze(
          metric: HealthMetric.calories,
          records: [r],
          previousRecords: [r],
          period: HealthTrendPeriod.day,
          anchor: DateTime(2026, 10, 21),
        );
        expect(data.points, isEmpty);
        expect(data.summary.average, isNull);
        expect(data.summary.previousAverage, isNull);
        expect(data.records, [r]);
        expect(jsonEncode(r.toJson()), before);
      }
    },
  );
  test(
    'known Android kcal and other vendor records remain usable including zero',
    () {
      for (final r in [
        record(0, version: 2),
        record(120, version: 2),
        record(130, vendor: 'luckring'),
      ]) {
        expect(hasUnconfirmedCalorieUnit(r), isFalse);
        final data = const HealthAnalysisService().analyze(
          metric: HealthMetric.calories,
          records: [r, record(98760)],
          previousRecords: [],
          period: HealthTrendPeriod.day,
          anchor: DateTime(2026, 10, 21),
        );
        expect(data.points, hasLength(1));
        expect(data.points.single.value, r.values['value']);
        expect(data.records, hasLength(2));
      }
    },
  );
  test('unknown QRing unit does not silently become kcal', () {
    expect(
      hasUnconfirmedCalorieUnit(record(80, version: 4, unit: 'unknown')),
      isTrue,
    );
  });
}
