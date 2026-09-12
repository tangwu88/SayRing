import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_source_policy.dart';
import 'package:saydian_app/domain/models.dart';

HealthRecord _record(
  String id, {
  HealthMetric metric = HealthMetric.heartRate,
  num value = 72,
  String category = 'ring',
  String deviceId = 'ring-a',
  String measuredAt = '2026-09-13T01:00:00Z',
  String timezone = '+00:00',
}) => HealthRecord(
  id: id,
  metric: metric,
  values: {'value': value},
  unit: metric.defaultUnit,
  measuredAt: DateTime.parse(measuredAt),
  timezone: timezone,
  deviceId: deviceId,
  firmwareVersion: '',
  quality: 'valid',
  source: MeasurementSource.wearable,
  rawVersion: 1,
  sourceDeviceCategory: category,
);

void main() {
  test('ring wins per metric and missing ring metric falls back to watch', () {
    final selected = ringPreferredHealthRecords([
      _record('ring-heart'),
      _record('watch-heart', category: 'watch', deviceId: 'watch-a'),
      _record(
        'watch-oxygen',
        metric: HealthMetric.bloodOxygen,
        value: 98,
        category: 'watch',
        deviceId: 'watch-a',
      ),
    ]);
    expect(selected.map((record) => record.id), ['ring-heart', 'watch-oxygen']);
  });

  test('real zero is retained and latest cumulative snapshot wins', () {
    final selected = ringPreferredHealthRecords([
      _record(
        'zero',
        metric: HealthMetric.steps,
        value: 0,
        measuredAt: '2026-09-13T01:00:00Z',
      ),
      _record(
        'latest',
        metric: HealthMetric.steps,
        value: 12,
        measuredAt: '2026-09-13T02:00:00Z',
      ),
      _record(
        'watch',
        metric: HealthMetric.steps,
        value: 99,
        category: 'watch',
        deviceId: 'watch-a',
        measuredAt: '2026-09-13T03:00:00Z',
      ),
    ]);
    expect(selected.map((record) => record.id), ['latest']);
  });

  test('unknown historical source is retained without model guessing', () {
    final selected = ringPreferredHealthRecords([
      _record('ring'),
      _record('watch', category: 'watch', deviceId: 'watch-a'),
      _record('legacy', category: '', deviceId: ''),
    ]);
    expect(selected.map((record) => record.id), ['ring', 'legacy']);
  });

  test(
    'record timezone separates local dates and preferred device is honored',
    () {
      final selected = ringPreferredHealthRecords([
        _record(
          'day-one-watch',
          category: 'watch',
          deviceId: 'watch-a',
          measuredAt: '2026-09-12T23:30:00Z',
        ),
        _record(
          'day-two-ring-a',
          deviceId: 'ring-a',
          measuredAt: '2026-09-12T23:30:00Z',
          timezone: '+02:00',
        ),
        _record(
          'day-two-ring-b',
          deviceId: 'ring-b',
          measuredAt: '2026-09-12T23:31:00Z',
          timezone: '+02:00',
        ),
      ], preferredDeviceId: 'ring-a');
      expect(selected.map((record) => record.id), [
        'day-one-watch',
        'day-two-ring-a',
      ]);
    },
  );
}
