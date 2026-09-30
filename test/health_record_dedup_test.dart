import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_record_dedup.dart';
import 'package:saydian_app/domain/models.dart';

void main() {
  test('same watch metric and second keeps the richer record', () {
    final measuredAt = DateTime.utc(2026, 8, 28, 8, 30, 15, 120);
    final result = deduplicateHealthRecords([
      _record('first', measuredAt, const {'value': 78}, quality: 'poor'),
      _record(
        'richer',
        measuredAt.add(const Duration(milliseconds: 600)),
        const {'value': 78, 'confidence': 95},
        quality: 'good',
      ),
    ]);

    expect(result, hasLength(1));
    expect(result.single.id, 'richer');
  });

  test('different devices and different seconds remain separate', () {
    final measuredAt = DateTime.utc(2026, 8, 28, 8, 30, 15);
    final result = deduplicateHealthRecords([
      _record('watch-a', measuredAt, const {'value': 78}),
      _record('watch-b', measuredAt, const {'value': 78}, deviceId: 'W9S-B'),
      _record('next-second', measuredAt.add(const Duration(seconds: 1)), const {
        'value': 79,
      }),
    ]);

    expect(result, hasLength(3));
  });

  test('QRing v3 current activity slot can grow between repeated syncs', () {
    final date = DateTime.utc(2026, 9, 30, 5, 15);
    for (final metric in [
      HealthMetric.steps,
      HealthMetric.distance,
      HealthMetric.calories,
    ]) {
      final first = _record('old', date, const {
        'value': 10,
      }, metric: metric).copyWith(sourceVendor: 'qring', rawVersion: 3);
      final next = _record('new', date, const {
        'value': 20,
      }, metric: metric).copyWith(sourceVendor: 'qring', rawVersion: 3);
      expect(deduplicateHealthRecords([first, next]).single.id, 'new');
      expect(deduplicateHealthRecords([next, first]).single.id, 'new');
      expect(
        deduplicateHealthRecords([first, next, next]).single.values['value'],
        20,
      );
    }
  });

  test('QRing activity tie break does not alter other measurements', () {
    final first = _record('old', DateTime.utc(2026, 9, 30), const {
      'value': 72,
    }).copyWith(sourceVendor: 'qring', rawVersion: 3);
    final next = _record('new', first.measuredAt, const {
      'value': 80,
    }).copyWith(sourceVendor: 'qring', rawVersion: 3);
    expect(deduplicateHealthRecords([first, next]).single.id, 'old');
  });
}

HealthRecord _record(
  String id,
  DateTime measuredAt,
  Map<String, num> values, {
  String quality = 'device_reported',
  String deviceId = 'W9S-A',
  HealthMetric metric = HealthMetric.heartRate,
}) => HealthRecord(
  id: id,
  metric: metric,
  values: values,
  unit: 'bpm',
  measuredAt: measuredAt,
  timezone: '+08:00',
  deviceId: deviceId,
  firmwareVersion: 'test',
  quality: quality,
  source: MeasurementSource.wearable,
  rawVersion: 1,
);
