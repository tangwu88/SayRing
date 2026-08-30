import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/yucheng_payload_mapper.dart';
import 'package:saydian_app/services/yucheng_product_client.dart';

void main() {
  test('maps official Yucheng health rows without inventing values', () {
    final records = YuchengPayloadMapper.healthRecords(
      deviceId: 'yucheng:AA:01',
      firmwareVersion: '1.2.3',
      rowsByType: {
        YuchengHealthDataType.step: [
          {
            'startTimeStamp': 1786579200,
            'step': 4567,
            'distance': 3210,
            'calories': 198,
          },
        ],
        YuchengHealthDataType.heartRate: [
          {'startTimeStamp': 1786579260, 'heartRate': 72},
        ],
        YuchengHealthDataType.bloodPressure: [
          {
            'startTimeStamp': 1786579320,
            'systolicBloodPressure': 118,
            'diastolicBloodPressure': 76,
          },
        ],
      },
    );

    expect(
      records
          .where((r) => r.metric == HealthMetric.steps)
          .single
          .values['value'],
      4567,
    );
    expect(
      records
          .where((r) => r.metric == HealthMetric.distance)
          .single
          .values['value'],
      3.21,
    );
    expect(
      records
          .where((r) => r.metric == HealthMetric.heartRate)
          .single
          .values['value'],
      72,
    );
    expect(
      records
          .where((r) => r.metric == HealthMetric.bloodPressure)
          .single
          .values,
      {'systolic': 118, 'diastolic': 76},
    );
    final heartRate = records
        .where((record) => record.metric == HealthMetric.heartRate)
        .single;
    expect(heartRate.timezone, _localTimezone(heartRate.measuredAt));
  });

  test('skips missing or zero measurements', () {
    final records = YuchengPayloadMapper.healthRecords(
      deviceId: 'yucheng:1',
      firmwareVersion: '',
      rowsByType: {
        YuchengHealthDataType.combined: [
          {'startTimeStamp': 1786579320, 'bloodOxygen': 98},
        ],
      },
    );
    expect(records.map((r) => r.metric), [HealthMetric.bloodOxygen]);
  });

  test('maps W8 feature flags only when SDK reports support', () {
    final capabilities = YuchengPayloadMapper.capabilities({
      'isSupportHeartRate': true,
      'isSupportBloodOxygen': true,
      'isSupportTemperature': true,
      'isSupportBloodGlucose': true,
      'isSupportHRV': true,
      'isSupportStartHeartRateMeasurement': true,
      'isSupportStartBloodOxygenMeasurement': false,
      'isSupportFindDevice': true,
      'isSupportWatchFace': true,
      'isSupportSport': true,
      'isSupportOutdoorRunning': true,
      'isSupportOutdoorWalking': true,
      'isSupportRiding': true,
      'isSupportOnFoot': true,
      'isSupportMountaineering': true,
      'isSupportSportPause': true,
      'isSupportOta': true,
      'isSupportAlarm': false,
    });
    expect(capabilities.supports(HealthMetric.heartRate), isTrue);
    expect(capabilities.supports(HealthMetric.bloodOxygen), isTrue);
    expect(capabilities.supports(HealthMetric.bodyTemperature), isTrue);
    expect(capabilities.supports(HealthMetric.bloodGlucose), isTrue);
    expect(capabilities.supports(HealthMetric.hrv), isTrue);
    expect(
      capabilities.supportsManualMeasurement(HealthMetric.heartRate),
      isTrue,
    );
    expect(
      capabilities.supportsManualMeasurement(HealthMetric.bloodOxygen),
      isFalse,
    );
    expect(capabilities.supportsFeature(DeviceFeature.findWatch), isTrue);
    expect(capabilities.supportsFeature(DeviceFeature.watchFaces), isTrue);
    expect(capabilities.supportsFeature(DeviceFeature.alarms), isFalse);
    expect(capabilities.sportModes, {
      SportMode.running,
      SportMode.walking,
      SportMode.cycling,
      SportMode.hiking,
      SportMode.mountaineering,
    });
    expect(capabilities.supportsSportPause, isTrue);
  });

  test('does not invent W8 sport modes from the generic sport flag', () {
    final capabilities = YuchengPayloadMapper.capabilities({
      'isSupportHeartRate': true,
      'isSupportSport': true,
    });

    expect(capabilities.sportModes, isEmpty);
    expect(capabilities.supportsSportPause, isFalse);
  });

  test('maps W8 mountaineering history and its real watch values', () {
    final records = YuchengPayloadMapper.sportRecords([
      {
        'startTimeStamp': 1786579320,
        'sportType': 0x0B,
        'sportTime': 900,
        'steps': 1234,
        'distance': 1680,
        'calories': 88,
        'heartRate': 104,
        'minimumHeartRate': 78,
        'maximumHeartRate': 132,
      },
    ]);

    final record = records.single;
    expect(record.mode, SportMode.mountaineering);
    expect(record.durationSeconds, 900);
    expect(record.distanceKm, 1.68);
    expect(record.steps, 1234);
    expect(record.heartRate, 104);
    expect(record.minimumHeartRate, 78);
    expect(record.maximumHeartRate, 132);
  });
}

String _localTimezone(DateTime instant) {
  final totalMinutes = instant.toLocal().timeZoneOffset.inMinutes;
  final absoluteMinutes = totalMinutes.abs();
  final hours = (absoluteMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (absoluteMinutes % 60).toString().padLeft(2, '0');
  return '${totalMinutes < 0 ? '-' : '+'}$hours:$minutes';
}
