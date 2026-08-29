import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/wearable_routing.dart';

void main() {
  test('parses percentage battery without losing low or charge state', () {
    final device = DeviceInfo.fromMap({
      'id': 'watch-1',
      'name': 'W9S',
      'battery': {
        'value': 19,
        'scale': 100,
        'isPercent': true,
        'low': true,
        'chargeState': 'charging',
        'updatedAt': '2026-08-29T08:00:00.123Z',
      },
    });

    expect(device.batteryPercent, 19);
    expect(device.effectiveBattery!.displayLabel, '19%');
    expect(device.effectiveBattery!.isLow, isTrue);
    expect(device.effectiveBattery!.isCharging, isTrue);
    expect(device.effectiveBattery!.updatedAt!.isUtc, isTrue);
  });

  test('four-grid battery is never converted to a percentage', () {
    final device = DeviceInfo.fromMap({
      'id': 'watch-1',
      'name': 'W9S',
      'batteryValue': 3,
      'batteryScale': 4,
      'batteryIsPercent': false,
      'batteryLow': null,
      'batteryChargeState': 'normal',
      'batteryUpdatedAt': '2026-08-29T08:00:00Z',
    });

    expect(device.batteryPercent, isNull);
    expect(device.effectiveBattery!.percent, isNull);
    expect(device.effectiveBattery!.displayLabel, '3/4 格');
    expect(device.effectiveBattery!.low, isNull);
  });

  test(
    'rejects inconsistent battery scale and keeps legacy percent support',
    () {
      final invalid = DeviceInfo.fromMap({
        'id': 'watch-1',
        'name': 'W9S',
        'battery': {
          'value': 3,
          'scale': 4,
          'isPercent': true,
          'chargeState': 'normal',
        },
        'batteryPercent': 75,
      });
      final legacy = DeviceInfo.fromMap({
        'id': 'watch-2',
        'name': 'ET488',
        'batteryPercent': 65,
      });

      expect(invalid.effectiveBattery, isNull);
      expect(legacy.effectiveBattery!.displayLabel, '65%');
    },
  );

  test('routing and JSON roundtrip preserve structured battery semantics', () {
    final native = DeviceInfo.fromMap({
      'id': 'ios-uuid',
      'name': 'W9S',
      'battery': {
        'value': 2,
        'scale': 4,
        'isPercent': false,
        'chargeState': 'full_unreliable',
        'updatedAt': '2026-08-29T08:00:00Z',
      },
    });
    final routed = RoutedDevice.fromDevice(
      WearableTransport.veepoo,
      native,
    ).display;
    final restored = DeviceInfo.fromMap(routed.toJson());

    expect(routed.id, 'veepoo:ios-uuid');
    expect(restored.effectiveBattery!.displayLabel, '2/4 格');
    expect(
      restored.effectiveBattery!.chargeState,
      DeviceBatteryChargeState.fullUnreliable,
    );
  });
}
