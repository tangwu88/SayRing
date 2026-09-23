import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_interpretation.dart';
import 'package:saydian_app/domain/models.dart';

void main() {
  HealthRecord record(HealthMetric metric, Map<String, num> values) =>
      HealthRecord(
        id: 'test-${metric.name}',
        metric: metric,
        values: values,
        unit: metric == HealthMetric.bodyTemperature ? '℃' : '',
        measuredAt: DateTime.utc(2026, 8, 20),
        timezone: '+08:00',
        deviceId: 'veepoo:w9s',
        firmwareVersion: '00.20.01',
        quality: 'unknown',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      );

  test('ring skin temperature is not interpreted as core temperature', () {
    final result = interpretHealthRecord(
      record(HealthMetric.bodyTemperature, const {'value': 40.5}),
    );

    expect(result.title, contains('皮肤温度'));
    expect(result.detail, contains('不能作为核心体温'));
  });

  test('stress follows the ranges shown by LuckRing', () {
    expect(
      interpretHealthRecord(
        record(HealthMetric.stress, const {'value': 29}),
      ).title,
      contains('放松'),
    );
    expect(
      interpretHealthRecord(
        record(HealthMetric.stress, const {'value': 44}),
      ).title,
      contains('正常'),
    );
    expect(
      interpretHealthRecord(
        record(HealthMetric.stress, const {'value': 70}),
      ).title,
      contains('中等'),
    );
    expect(
      interpretHealthRecord(
        record(HealthMetric.stress, const {'value': 85}),
      ).title,
      contains('偏高'),
    );
  });

  test('ECG device flags produce a visible attention message', () {
    final result = interpretHealthRecord(
      record(HealthMetric.ecg, const {
        'meanHeartRate': 78,
        'deviceAbnormalFlags': 2,
      }),
    );

    expect(result.title, contains('需关注'));
    expect(result.detail, contains('不是医学诊断'));
  });

  test('body and blood component fields have distinct labels and units', () {
    final body = record(HealthMetric.bodyComposition, const {'bmi': 22.6});
    final blood = record(HealthMetric.bloodComposition, const {
      'uricAcid': 320,
    });

    expect(healthValueLabel('bmi', body.metric), 'BMI');
    expect(healthValueLabel('bodyFatRate', body.metric), '体脂率');
    expect(healthValueUnit('bodyFatRate', body), '%');
    expect(healthValueLabel('uricAcid', blood.metric), '尿酸');
    expect(healthValueUnit('uricAcid', blood), 'μmol/L');
  });
}
