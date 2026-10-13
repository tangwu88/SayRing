import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';

void main() {
  test('history capability preserves integrated legacy bridge contracts', () {
    final legacy = DeviceCapabilities.fromMap(const {'metrics': []});
    expect(legacy.supportsHistorySync, isTrue);
    expect(legacy.supportsBackgroundSync, isFalse);
    expect(
      DeviceCapabilities.fromMap(legacy.toJson()).supportsHistorySync,
      isTrue,
    );
  });

  test('explicit or malformed history capability fails closed', () {
    for (final value in <Object?>[false, null, 'true', 1]) {
      final capabilities = DeviceCapabilities.fromMap({
        'metrics': ['heart_rate', 'blood_oxygen'],
        'manualMetrics': ['heart_rate', 'blood_oxygen'],
        'supportsHistorySync': value,
      });
      expect(capabilities.supportsHistorySync, isFalse);
      expect(
        DeviceCapabilities.fromMap(capabilities.toJson()).supportsHistorySync,
        isFalse,
      );
      expect(
        capabilities.supportsManualMeasurement(HealthMetric.heartRate),
        isTrue,
      );
    }
    expect(
      DeviceCapabilities.fromMap(const {
        'metrics': [],
        'supportsHistorySync': true,
      }).supportsHistorySync,
      isTrue,
    );
  });

  test('screen settings preserve device limits through the write map', () {
    final settings = DeviceScreenSettings.fromMap(const {
      'brightness': 3,
      'maximumBrightness': 5,
      'automaticBrightness': false,
      'brightnessSupported': true,
      'durationSeconds': 90,
      'minimumDurationSeconds': 5,
      'maximumDurationSeconds': 120,
      'raiseToWakeEnabled': true,
      'raiseToWakeSupported': true,
      'raiseToWakeCustomTimeSupported': true,
      'raiseToWakeStartMinutes': 420,
      'raiseToWakeEndMinutes': 1320,
    });

    expect(settings.toMap(), containsPair('minimumDurationSeconds', 5));
    expect(settings.toMap(), containsPair('maximumDurationSeconds', 120));
    expect(settings.toMap(), containsPair('raiseToWakeSupported', true));
    expect(
      settings.toMap(),
      containsPair('raiseToWakeCustomTimeSupported', true),
    );
  });
}
