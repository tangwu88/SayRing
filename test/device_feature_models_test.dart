import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';

void main() {
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
