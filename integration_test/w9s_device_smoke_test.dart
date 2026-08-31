import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('W9S physical device connection and safe feature smoke test', (
    tester,
  ) async {
    final bridge = MethodChannelWearableBridge(
      operationTimeout: const Duration(seconds: 35),
      syncTimeout: const Duration(seconds: 45),
    );
    var disconnected = false;
    DeviceInfo? latestDetails;
    final subscription = bridge.events.listen((event) {
      if (event.type == 'disconnected') disconnected = true;
      if (event.type == 'deviceDetails') {
        latestDetails = DeviceInfo.fromMap(event.payload);
      }
      debugPrint('W9S_EVENT:${event.type}:${event.payload.keys.join(',')}');
    });
    addTearDown(() async {
      await bridge.disconnect().catchError((_) {});
      await subscription.cancel();
    });

    final w9s = await _scanForW9s(bridge);
    await bridge.connect(w9s.id, profile: _profile);
    debugPrint('W9S_NATIVE_CONNECTED:name=${w9s.name} id=${w9s.id}');

    final capabilities = await bridge.getCapabilities();
    debugPrint(
      'W9S_CAPABILITIES:metrics=${_names(capabilities.metrics)} '
      'manual=${_names(capabilities.manualMetrics ?? const {})} '
      'features=${capabilities.features.map((item) => item.wireName).join(',')}',
    );
    expect(capabilities.metrics, isNotEmpty);

    final detailsBridge = bridge as WearableDeviceDetailsBridge;
    latestDetails = await detailsBridge.getConnectedDeviceDetails();
    final batteryDeadline = DateTime.now().add(const Duration(seconds: 12));
    while (latestDetails?.effectiveBattery == null &&
        DateTime.now().isBefore(batteryDeadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      latestDetails = await detailsBridge.getConnectedDeviceDetails();
    }
    final battery = latestDetails?.effectiveBattery;
    debugPrint(
      'W9S_BATTERY:value=${battery?.value} scale=${battery?.scale} '
      'charge=${battery?.chargeState.name}',
    );
    expect(disconnected, isFalse, reason: '读取 W9S 设备详情后发生断连');

    for (final metric in const [
      HealthMetric.ecg,
      HealthMetric.heartRate,
      HealthMetric.bloodOxygen,
      HealthMetric.bloodPressure,
      HealthMetric.bodyTemperature,
      HealthMetric.bloodGlucose,
      HealthMetric.bodyComposition,
      HealthMetric.bloodComposition,
    ].where(capabilities.supportsManualMeasurement)) {
      await bridge.startMeasurement(metric);
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(disconnected, isFalse, reason: '${metric.label}启动后 W9S 断连');
      await bridge.stopMeasurement(metric);
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(disconnected, isFalse, reason: '${metric.label}停止后 W9S 断连');
      debugPrint('W9S_MEASUREMENT_OK:${metric.wireName}');
    }

    var syncResult = 'ok';
    var recordCount = 0;
    try {
      final records = await bridge.syncHealthData();
      recordCount = records.length;
    } on TimeoutException {
      syncResult = 'timeout';
    } catch (error) {
      syncResult = error.runtimeType.toString();
    }
    debugPrint('W9S_SYNC_RESULT:$syncResult records=$recordCount');
    expect(disconnected, isFalse, reason: 'W9S 历史同步期间断连');

    await bridge.disconnect();
    await Future<void>.delayed(const Duration(seconds: 2));
    disconnected = false;
    final rediscovered = await _scanForW9s(bridge, preferredId: w9s.id);
    await bridge.connect(rediscovered.id, profile: _profile);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(disconnected, isFalse, reason: 'W9S 断开后重连失败');
    expect(rediscovered.id, w9s.id);
    debugPrint('W9S_RECONNECT_OK:${rediscovered.id}');
  });
}

const _profile = WearableUserProfile(
  gender: 1,
  heightCm: 170,
  weightKg: 65,
  birthYear: 1990,
  age: 36,
  targetSteps: 10000,
);

Future<DeviceInfo> _scanForW9s(
  WearableBridge bridge, {
  String? preferredId,
}) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    final devices = await bridge.scanDevices();
    debugPrint(
      'W9S_NATIVE_SCAN_$attempt:${devices.map((device) => device.name).join(',')}',
    );
    final matches = devices.where(_isW9s).toList()
      ..sort(
        (left, right) => (right.rssi ?? -999).compareTo(left.rssi ?? -999),
      );
    if (matches.isNotEmpty) {
      return matches.firstWhere(
        (device) => preferredId != null && device.id == preferredId,
        orElse: () => matches.first,
      );
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  fail('五轮扫描后仍未发现 W9S');
}

bool _isW9s(DeviceInfo device) {
  final normalized = device.name.toUpperCase().replaceAll(
    RegExp(r'[^A-Z0-9]'),
    '',
  );
  return normalized.contains('W9S');
}

String _names(Iterable<HealthMetric> metrics) =>
    metrics.map((metric) => metric.wireName).join(',');
