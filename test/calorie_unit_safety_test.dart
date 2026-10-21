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
  deviceId: 'qring:synthetic',
  firmwareVersion: 'synthetic',
  quality: 'synthetic-only',
  source: MeasurementSource.wearable,
  sourceVendor: vendor,
  sourceDeviceCategory: 'ring',
  sourceApp: 'say-ring',
  rawVersion: version,
);
void main() {
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
