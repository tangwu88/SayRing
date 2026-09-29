import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_record_validation.dart';
import 'package:saydian_app/domain/models.dart';

void main() {
  group('wearable transport sanity', () {
    test('rejects SDK sentinel values but keeps completed measurements', () {
      expect(_record(HealthMetric.heartRate, {'value': 1}).isSane, isFalse);
      expect(_record(HealthMetric.heartRate, {'value': 78}).isSane, isTrue);
      expect(_record(HealthMetric.bloodOxygen, {'value': 1}).isSane, isFalse);
      expect(_record(HealthMetric.bloodOxygen, {'value': 97}).isSane, isTrue);
      expect(
        _record(HealthMetric.bloodPressure, {
          'systolic': 1,
          'diastolic': 1,
        }).isSane,
        isFalse,
      );
      expect(
        _record(HealthMetric.bloodPressure, {
          'systolic': 126,
          'diastolic': 79,
        }).isSane,
        isTrue,
      );
      expect(
        _record(HealthMetric.bodyTemperature, {'value': 1}).isSane,
        isFalse,
      );
      expect(
        _record(HealthMetric.bodyTemperature, {'value': 35.9}).isSane,
        isTrue,
      );
      expect(_record(HealthMetric.stress, {'value': 0}).isSane, isFalse);
      expect(_record(HealthMetric.stress, {'value': 44}).isSane, isTrue);
      expect(_record(HealthMetric.stress, {'value': 101}).isSane, isFalse);
      expect(_record(HealthMetric.sleep, {'value': 395}).isSane, isFalse);
      expect(
        _record(HealthMetric.sleep, {
          'value': 6.58,
          'deepHours': 2,
          'remHours': 1.08,
          'awakeMinutes': 10,
          'score': 84,
          'efficiency': 91,
        }).isSane,
        isTrue,
      );
      expect(
        _record(HealthMetric.ecg, {
          'meanHeartRate': 255,
          'averageHRV': 85,
          'sampleFrequency': 500,
        }).isSane,
        isFalse,
      );
      expect(
        _record(HealthMetric.ecg, {
          'meanHeartRate': 88,
          'averageHRV': 85,
          'sampleFrequency': 500,
        }).isSane,
        isTrue,
      );
    });

    test('does not reinterpret manually entered data as an SDK sentinel', () {
      expect(
        _record(HealthMetric.heartRate, {
          'value': 1,
        }, source: MeasurementSource.manual).isSane,
        isTrue,
      );
    });

    test(
      'old QRing activity slot timestamps stay hidden until same-ID resync',
      () {
        final old = _record(HealthMetric.steps, {
          'value': 12,
        }).copyWith(sourceVendor: 'qring');
        expect(old.isSane, isFalse);
        expect(old.copyWith(rawVersion: 2).isSane, isTrue);
        expect(_record(HealthMetric.steps, {'value': 12}).isSane, isTrue);
      },
    );

    test('rejects calibrated ECG records without a usable waveform', () {
      final invalid = _record(
        HealthMetric.ecg,
        {'meanHeartRate': 80, 'sampleFrequency': 250},
        rawVersion: 2,
        samples: List<num>.generate(1000, (index) => index.isEven ? -8 : 8),
      );
      final valid = _record(
        HealthMetric.ecg,
        {'meanHeartRate': 80, 'sampleFrequency': 250},
        rawVersion: 2,
        samples: List<num>.generate(
          1000,
          (index) => 0.08 * (index % 20) / 20 + (index % 250 == 40 ? 1.1 : 0),
        ),
      );

      expect(invalid.isSane, isFalse);
      expect(valid.isSane, isTrue);
    });
  });
}

HealthRecord _record(
  HealthMetric metric,
  Map<String, num> values, {
  MeasurementSource source = MeasurementSource.wearable,
  int rawVersion = 1,
  List<num> samples = const [],
}) => HealthRecord(
  id: '${metric.wireName}-${values.values.join('-')}',
  metric: metric,
  values: values,
  unit: metric.defaultUnit,
  measuredAt: DateTime.utc(2026, 8, 15),
  timezone: '+08:00',
  deviceId: 'W9S',
  firmwareVersion: 'test',
  quality: 'device_reported',
  source: source,
  rawVersion: rawVersion,
  samples: samples,
);

extension on HealthRecord {
  bool get isSane => hasSaneWearableTransportValues(this);
}
