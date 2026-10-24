import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';

import 'ios_auth_entry_smoke_test.dart' as auth;
import 'ios_read_only_page_walkthrough_test.dart' as pages;

// Real production owner and data only. No new binding, reset, OTP or settings writes.
void main() {
  auth.main();
  pages.main();
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'existing owned ring full sync and dashboard slow drag',
    (tester) async {
      final app = AppController.production();
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      expect(app.isAuthenticated || app.isLocalMode, isTrue);
      final owner = app.session?.accountKey;
      final target = app.rememberedDevice;
      expect(
        target,
        isNotNull,
        reason:
            'Requires the existing owned ring; never auto-select a new target',
      );
      app.selectTab(1);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await binding.takeScreenshot('sayring-ios-reconnect-before-1135');
      // The user authorized checking/retrying this exact existing binding.
      // Use the public reconnect action, never scan-select another target.
      if (app.connectedDevice?.id != target!.id) {
        await app.reconnectDevice().timeout(const Duration(seconds: 60));
      }
      for (
        var i = 0;
        i < 180 &&
            (app.connectedDevice?.id != target.id || app.capabilities == null);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
      }
      if (app.connectedDevice?.id != target.id) {
        // SDK text logs omit peripheral IDs. Diagnose identity through the
        // public scan result, without adopting a similarly named ring.
        await app.scanDevices().timeout(const Duration(seconds: 45));
        final probe = <String, Object?>{
          'scanCount': app.scannedDevices.length,
          'savedTargetAdvertised': app.scannedDevices.any(
            (device) => device.id.toUpperCase() == target.id.toUpperCase(),
          ),
          'savedTargetRssi': [
            for (final device in app.scannedDevices)
              if (device.id.toUpperCase() == target.id.toUpperCase())
                device.rssi,
          ],
          'scanIssue': app.deviceScanIssue?.name,
          'scanError': app.errorMessage != null,
        };
        binding.reportData = {...?binding.reportData, 'connectionProbe': probe};
        // Counts/status only; never print account, device ID or health samples.
        // ignore: avoid_print
        print('iOS existing-target connection probe: $probe');
        await app.stopDeviceScan();
      }
      await binding.takeScreenshot('sayring-ios-reconnect-after-1135');
      expect(app.session?.accountKey, owner);
      expect(app.rememberedDevice?.id, target.id);
      expect(app.connectedDevice?.id, target.id);
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
      expect(app.errorMessage, isNull);
      app.selectTab(0);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final scroll = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scroll).position;
      position.jumpTo(0);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('sayring-ios-home-1135');
      if (position.maxScrollExtent > 300) {
        position.jumpTo(position.maxScrollExtent.clamp(0, 800).toDouble());
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(tester.getCenter(scroll));
        var before = position.pixels;
        for (var i = 0; i < 400 && position.pixels > 2; i++) {
          await gesture.moveBy(const Offset(0, 1));
          await tester.pump(const Duration(milliseconds: 16));
          final after = position.pixels;
          expect(
            after,
            lessThanOrEqualTo(before + .5),
            reason: 'Slow downward drag must not reverse the scroll position',
          );
          before = after;
        }
        await gesture.up();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      binding.reportData = {
        ...?binding.reportData,
        'ringChecks': [
          'same_owner_and_target',
          'real_complete_history_sync',
          'real_dashboard_slow_drag',
        ],
      };
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
