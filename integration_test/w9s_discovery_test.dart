import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/wearable_routing.dart';
import 'package:saydian_app/services/yucheng_wearable_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Yuc SDK returns nearby devices on its own', (tester) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    }
    final bridge = YuchengWearableBridge();
    final devices = await bridge.scanDevices();
    debugPrint(
      'YUC_ONLY_DEVICES:${devices.map((device) => '${device.name}:${device.id}:${device.rssi}').join(',')}',
    );
    expect(devices, isNotEmpty, reason: 'Yuc SDK 单独扫描没有返回附近设备');
  });

  testWidgets('discovers nearby YC ring through the Yuc transport', (
    tester,
  ) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    await controller.initialize();
    if (!controller.isAuthenticated) controller.enterPreview();

    await controller.scanDevices();
    final devices = controller.scannedDevices;
    debugPrint(
      'DISCOVERED_DEVICES:${devices.map((device) => '${device.sdkSource.shortLabel}:${device.name}').join(',')}',
    );

    final matches = devices.where(
      (device) => WearableDeviceClassifier.routesTo(
        device.name,
        WearableTransport.yucheng,
      ),
    );
    expect(matches, isNotEmpty, reason: '没有发现处于广播状态的 YC 前缀戒指');
    expect(
      matches.every((device) => device.sdkSource == WearableSdkSource.yucheng),
      isTrue,
    );
    debugPrint(
      'YUC_ROUTING_OK:${matches.map((device) => '${device.id}:${device.name}').join(',')}',
    );
  });
}
