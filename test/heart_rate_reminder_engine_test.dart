import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_reminder.dart';
import 'package:saydian_app/domain/heart_rate_reminder_engine.dart';
import 'package:saydian_app/domain/models.dart';

// Synthetic engineering fixtures only. No clinical limits or device approval.
final _time = DateTime.utc(2026, 10, 27, 12);
const _device = DeviceInfo(
  id: 'synthetic-ring',
  name: 'Synthetic ring',
  model: 'fixture-model',
  firmwareVersion: 'fixture-fw',
);
HeartRateReminderRule _rule({
  DateTime? expires,
  String quality = 'fixture-valid',
}) => HeartRateReminderRule(
  version: 'fixture-only-v1',
  reviewReference: 'synthetic-test-not-medical-approval',
  expiresAt: expires ?? DateTime.utc(2030),
  platform: 'fixture-platform',
  model: 'fixture-model',
  firmware: 'fixture-fw',
  lower: 42,
  upper: 142,
  minimumSamples: 3,
  minimumSpan: const Duration(seconds: 2),
  maximumGap: const Duration(seconds: 1),
  maximumAge: const Duration(minutes: 1),
  acceptedQuality: {quality},
  context: HeartRateObservationContext.resting,
  recoverySamples: 3,
  recoverySpan: const Duration(seconds: 2),
);
HealthRecord _record(
  int second, {
  num value = 143,
  String? id,
  String quality = 'fixture-valid',
  String unit = 'bpm',
  MeasurementSource source = MeasurementSource.wearable,
  MeasurementOrigin origin = MeasurementOrigin.appMeasurement,
}) => HealthRecord(
  id: id ?? 'fixture-$second',
  metric: HealthMetric.heartRate,
  values: {'value': value},
  unit: unit,
  measuredAt: _time.add(Duration(seconds: second)),
  timezone: '+00:00',
  deviceId: _device.id,
  firmwareVersion: 'fixture-fw',
  quality: quality,
  source: source,
  origin: origin,
  rawVersion: 1,
);
HeartRateReminderCandidate? _observe(
  HeartRateReminderEngine engine,
  int second, {
  HealthRecord? record,
  String owner = 'synthetic-owner',
  DeviceInfo device = _device,
  String platform = 'fixture-platform',
  bool live = true,
  HeartRateObservationContext context = HeartRateObservationContext.resting,
}) => engine.observe(
  record: record ?? _record(second),
  owner: owner,
  device: device,
  platform: platform,
  now: _time.add(Duration(seconds: second)),
  live: live,
  context: context,
);

void main() {
  test('production default contains no implicit clinical thresholds', () {
    final engine = HeartRateReminderEngine();
    expect(engine.configuredAt(_time), isFalse);
    for (var i = 0; i < 10; i++) {
      expect(_observe(engine, i), isNull);
    }
  });
  for (final value in [143, 41]) {
    test('requires count and time window for synthetic value $value', () {
      final engine = HeartRateReminderEngine(rules: [_rule()]);
      expect(_observe(engine, 0, record: _record(0, value: value)), isNull);
      expect(_observe(engine, 1, record: _record(1, value: value)), isNull);
      final result = _observe(engine, 2, record: _record(2, value: value));
      expect(
        result?.details.kind,
        value == 143
            ? HealthReminderKind.highHeartRate
            : HealthReminderKind.lowHeartRate,
      );
      expect(result?.details.sampleIds, [
        'fixture-0',
        'fixture-1',
        'fixture-2',
      ]);
      expect(result?.details.measuredAt, _time.add(const Duration(seconds: 2)));
      expect(result?.details.reading, value.toDouble());
    });
  }
  for (final value in [42, 142, 80]) {
    test('equality boundaries do not create an event: $value', () {
      final engine = HeartRateReminderEngine(rules: [_rule()]);
      for (var i = 0; i < 4; i++) {
        expect(_observe(engine, i, record: _record(i, value: value)), isNull);
      }
    });
  }
  test('duplicates and out-of-order records cannot satisfy a window', () {
    final engine = HeartRateReminderEngine(rules: [_rule()]);
    _observe(engine, 0);
    expect(_observe(engine, 1, record: _record(0)), isNull);
    expect(_observe(engine, 1), isNull);
    expect(_observe(engine, 2, record: _record(0, id: 'out-of-order')), isNull);
    expect(_observe(engine, 2)?.details.sampleIds, [
      'fixture-0',
      'fixture-1',
      'fixture-2',
    ]);
    expect(_observe(engine, 3), isNull);
    expect(_observe(engine, 4), isNull);
  });
  test('sample gap restarts the event window', () {
    final engine = HeartRateReminderEngine(rules: [_rule()]);
    _observe(engine, 0);
    _observe(engine, 1);
    expect(_observe(engine, 10), isNull);
    expect(_observe(engine, 11), isNull);
    expect(_observe(engine, 12)?.details.sampleIds, [
      'fixture-10',
      'fixture-11',
      'fixture-12',
    ]);
  });
  test(
    'single within-range reading does not reset an already emitted episode',
    () {
      final engine = HeartRateReminderEngine(rules: [_rule()]);
      _observe(engine, 0);
      _observe(engine, 1);
      expect(_observe(engine, 2), isNotNull);
      expect(_observe(engine, 3, record: _record(3, value: 80)), isNull);
      for (var i = 4; i < 8; i++) {
        expect(_observe(engine, i), isNull);
      }
      for (var i = 8; i < 11; i++) {
        _observe(engine, i, record: _record(i, value: 80));
      }
      expect(_observe(engine, 11), isNull);
      expect(_observe(engine, 12), isNull);
      expect(_observe(engine, 13), isNotNull);
    },
  );
  for (final quality in ['unknown', 'bad']) {
    test('unaccepted quality interrupts confirmation: $quality', () {
      final engine = HeartRateReminderEngine(rules: [_rule()]);
      _observe(engine, 0);
      _observe(engine, 1);
      expect(_observe(engine, 2, record: _record(2, quality: quality)), isNull);
      expect(_observe(engine, 3), isNull);
      expect(_observe(engine, 4), isNull);
      expect(_observe(engine, 5), isNotNull);
    });
  }
  test('unknown quality cannot itself be approved as a reliable signal', () {
    expect(_rule(quality: 'UNKNOWN').validAt(_time), isFalse);
  });
  for (final kind in [
    'future',
    'stale',
    'wrong-unit',
    'manual',
    'remote',
    'history',
    'context',
    'anonymous',
    'platform',
    'device',
  ]) {
    test('rejects unsafe observation context: $kind', () {
      final engine = HeartRateReminderEngine(rules: [_rule()]);
      for (var i = 0; i < 5; i++) {
        final record = switch (kind) {
          'future' => _record(i + 1),
          'stale' => _record(i - 61),
          'wrong-unit' => _record(i, unit: '%'),
          'manual' => _record(i, source: MeasurementSource.manual),
          'remote' => _record(i, origin: MeasurementOrigin.remoteMember),
          _ => _record(i),
        };
        expect(
          _observe(
            engine,
            i,
            record: record,
            owner: kind == 'anonymous' ? 'anonymous' : 'owner',
            live: kind != 'history',
            platform: kind == 'platform'
                ? 'unapproved-platform'
                : 'fixture-platform',
            device: kind == 'device'
                ? const DeviceInfo(
                    id: 'other',
                    name: 'other',
                    model: 'fixture-model',
                    firmwareVersion: 'fixture-fw',
                  )
                : _device,
            context: kind == 'context'
                ? HeartRateObservationContext.unknown
                : HeartRateObservationContext.resting,
          ),
          isNull,
        );
      }
    });
  }
  test('expired rules do not create events', () {
    final engine = HeartRateReminderEngine(rules: [_rule(expires: _time)]);
    expect(engine.configuredAt(_time), isFalse);
    for (var i = 0; i < 5; i++) {
      expect(_observe(engine, i), isNull);
    }
  });
  test(
    'overlapping applicable rules fail closed instead of choosing the first',
    () {
      final engine = HeartRateReminderEngine(rules: [_rule(), _rule()]);
      expect(
        engine.supportsDevice(_device, 'fixture-platform', _time),
        isFalse,
      );
      for (var i = 0; i < 5; i++) {
        expect(_observe(engine, i), isNull);
      }
    },
  );
  test(
    'replay yields same event identity; account change cannot reuse evidence',
    () {
      final engine = HeartRateReminderEngine(rules: [_rule()]);
      _observe(engine, 0);
      _observe(engine, 1);
      final first = _observe(engine, 2)!;
      engine.reset();
      _observe(engine, 0);
      _observe(engine, 1);
      expect(_observe(engine, 2)?.id, first.id);
      expect(_observe(engine, 3, owner: 'owner-b'), isNull);
      expect(_observe(engine, 4, owner: 'owner-b'), isNull);
      expect(_observe(engine, 5, owner: 'owner-b')?.id, isNot(first.id));
    },
  );
}
