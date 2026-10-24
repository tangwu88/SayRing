import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'existing owner target connects and confirms real full sync',
    (tester) async {
      final app = AppController.production();
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      final owner = app.session?.accountKey;
      final target = app.rememberedDevice;
      expect(target, isNotNull, reason: 'Never select or reset another ring');
      app.selectTab(1);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      if (app.connectedDevice?.id != target!.id) {
        await app.reconnectDevice().timeout(const Duration(seconds: 60));
      }
      for (var i = 0; i < 60 && app.connectedDevice?.id != target.id; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
      }
      if (app.connectedDevice?.id != target.id) {
        await app.scanDevices().timeout(const Duration(seconds: 45));
        binding.reportData = {
          ...?binding.reportData,
          'connectionProbe': {
            'count': app.scannedDevices.length,
            'savedTargetAdvertised': app.scannedDevices.any(
              (device) => device.id.toUpperCase() == target.id.toUpperCase(),
            ),
            'issue': app.deviceScanIssue?.name,
            'error': app.errorMessage != null,
          },
        };
        await app.stopDeviceScan();
      }
      expect(app.session?.accountKey, owner);
      expect(app.rememberedDevice?.id, target.id);
      expect(
        app.connectedDevice?.id == target.id,
        isTrue,
        reason: 'The exact existing ring must complete its actual handshake',
      );
      expect(app.capabilities?.supportsHistorySync, isTrue);
      for (var i = 0; i < 180 && app.isDeviceSyncing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
      }
      expect(app.isDeviceSyncing, isFalse);
      expect(
        await app.syncDeviceData().timeout(const Duration(minutes: 3)),
        isTrue,
      );
      expect(app.session?.accountKey, owner);
      expect(app.rememberedDevice?.id, target.id);
      binding.reportData = {...?binding.reportData, 'completeRealSync': true};
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
