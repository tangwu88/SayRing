import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';

void main() {
  test('routed device identifiers expose their SDK source and native id', () {
    const veepoo = DeviceInfo(id: 'veepoo:AA:BB', name: 'ET488');
    const yucheng = DeviceInfo(id: 'yucheng:W8-01', name: 'W8');

    expect(veepoo.sdkSource, WearableSdkSource.veepoo);
    expect(veepoo.sdkSource.shortLabel, 'Vep');
    expect(veepoo.nativeId, 'AA:BB');
    expect(yucheng.sdkSource, WearableSdkSource.yucheng);
    expect(yucheng.sdkSource.shortLabel, 'Yuc');
    expect(yucheng.nativeId, 'W8-01');
  });

  test('unrouted identifiers stay explicitly unmarked', () {
    const device = DeviceInfo(id: 'AA:BB', name: 'Legacy');

    expect(device.sdkSource, WearableSdkSource.unknown);
    expect(device.nativeId, 'AA:BB');
  });

  test('only real hardware addresses are labelled as MAC addresses', () {
    const iOSDevice = DeviceInfo(
      id: 'veepoo:36CE3B81-94C2-9B3F-C30F-BE9AB1EB2C7D',
      name: 'SD-WATCH-W9S',
    );
    const yucDevice = DeviceInfo(
      id: 'yucheng:F88A714C-1FD0-CBD9-126B-E098D1D63483',
      name: 'w8s 4DE9',
      hardwareAddress: '07:43:00:00:4D:E9',
    );
    const compactAddress = DeviceInfo(id: 'veepoo:5c8bbc6f26fc', name: 'ET488');

    expect(iOSDevice.macAddress, isNull);
    expect(iOSDevice.identifierLabel, 'iOS 连接标识 · 36CE3B81…B1EB2C7D');
    expect(yucDevice.macAddress, '07:43:00:00:4D:E9');
    expect(yucDevice.identifierLabel, 'MAC · 07:43:00:00:4D:E9');
    expect(compactAddress.macAddress, '5C:8B:BC:6F:26:FC');
  });

  test('normalizes corrupted W9-family scan names', () {
    final w9s = DeviceInfo.fromMap({
      'id': 'UUID-1',
      'name': '  SD-\u0000WATCH-W9S\uFFFD  ',
    });
    final w9 = DeviceInfo.fromMap({'id': 'UUID-2', 'name': 'sd_watch_w9'});

    expect(w9s.name, 'SD-Watch-W9S');
    expect(w9.name, 'SD-Watch-W9');
  });

  test('manual measurement support is independent from synced metrics', () {
    final capabilities = DeviceCapabilities.fromMap({
      'metrics': ['heart_rate', 'hrv'],
      'manualMetrics': ['heart_rate'],
    });

    expect(capabilities.supports(HealthMetric.hrv), isTrue);
    expect(capabilities.supportsManualMeasurement(HealthMetric.hrv), isFalse);
    expect(
      capabilities.supportsManualMeasurement(HealthMetric.heartRate),
      isTrue,
    );
  });

  test(
    'legacy capabilities keep their existing manual measurement behavior',
    () {
      final capabilities = DeviceCapabilities.fromMap({
        'metrics': ['heart_rate'],
      });

      expect(
        capabilities.supportsManualMeasurement(HealthMetric.heartRate),
        isTrue,
      );
    },
  );
}
