import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS discovers and connects the physical W9 by stable UUID', (
    tester,
  ) async {
    final controller = AppController.production();
    await controller.initialize();
    if (!controller.isAuthenticated) controller.enterPreview();
    addTearDown(() async {
      if (controller.connectedDevice != null) {
        await controller.disconnectDevice();
      }
      controller.dispose();
    });

    DeviceInfo? w9;
    for (var attempt = 0; attempt < 3 && w9 == null; attempt += 1) {
      await controller.scanDevices();
      for (final device in controller.scannedDevices) {
        debugPrint(
          'W9_SCAN:${device.name}:${device.nativeId}:${device.identifierLabel}:${device.rssi}',
        );
        final normalized = device.name.toUpperCase().replaceAll(
          RegExp(r'[^A-Z0-9]'),
          '',
        );
        if (normalized == 'SDWATCHW9' &&
            (w9 == null || (device.rssi ?? -999) > (w9.rssi ?? -999))) {
          w9 = device;
        }
      }
      if (w9 == null) await tester.pump(const Duration(seconds: 2));
    }

    expect(w9, isNotNull, reason: '三轮扫描后仍未发现 SD-Watch-W9');
    expect(w9!.sdkSource, WearableSdkSource.veepoo);
    expect(
      w9.nativeId,
      matches(RegExp(r'^[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}$')),
      reason: 'iOS W9 必须使用 CoreBluetooth UUID 路由',
    );
    expect(w9.macAddress, isNull, reason: '扫描地址不得冒充手表 MAC');

    await controller.connectDevice(w9);
    await _waitUntil(
      tester,
      () => controller.deviceState == DeviceConnectionState.ready,
      const Duration(seconds: 40),
    );
    expect(controller.connectedDevice?.id, w9.id);
    expect(controller.connectedDevice?.name, 'SD-Watch-W9');
    expect(await controller.refreshConnectedDeviceDetails(), isTrue);
    expect(controller.connectedDevice?.id, w9.id);
    debugPrint(
      'W9_CONNECTED:${controller.connectedDevice?.identifierLabel}:'
      '${controller.connectedDevice?.firmwareVersion ?? ''}',
    );

    await _waitUntil(
      tester,
      () => !controller.isDeviceSyncing,
      const Duration(seconds: 55),
    );
    expect(controller.deviceState, DeviceConnectionState.ready);
    debugPrint('W9_SYNC:${controller.syncStatus}');
  });
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(condition(), isTrue);
}
