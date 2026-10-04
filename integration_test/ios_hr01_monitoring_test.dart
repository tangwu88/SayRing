import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/app_controller.dart';

/// Real, already owner-bound HR01 only. No login replacement, invented data,
/// selection by name or permanent settings change. Results contain labels only.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'HR01 monitoring entry and verified switches',
    (tester) async {
      final controller = AppController.production();
      addTearDown(controller.dispose);
      await tester.pumpWidget(SaydianApp(controller: controller));
      await controller.initialize();
      final owner = controller.session?.accountKey;
      for (var attempt = 0; attempt < 120; attempt++) {
        if (controller.connectedDevice != null &&
            controller.capabilities?.supportsFeature(
                  DeviceFeature.healthMonitoring,
                ) ==
                true &&
            find.byType(NavigationBar).evaluate().isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(controller.connectedDevice?.name, 'HR01');
      expect(
        controller.availabilityFor(DeviceFeature.healthMonitoring).isReady,
        isTrue,
      );
      expect(
        find.byType(NavigationBar),
        findsOneWidget,
        reason: 'Wait for the real app shell, not only BLE readiness',
      );
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      final entry = find.text('健康监测');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await controller.refreshDeviceSettings();
      await tester.pumpAndSettle();
      const types = ['heartRate', 'heartRate24h', 'bloodOxygen'];
      expect(controller.autoMeasureSettings.keys, containsAll(types));
      expect(controller.autoMeasureIntervals, isEmpty);
      for (final type in types) {
        expect(
          find.byKey(ValueKey('device-health-auto-$type')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('device-health-auto-bodyTemperature')),
        findsNothing,
      );
      if (const bool.fromEnvironment('SAYRING_RESTORE_PERIODIC_HEART')) {
        // Only repair the setting changed by an earlier interrupted real test.
        // Not a firmware default or production automatic-enable behavior.
        for (var attempt = 0; attempt < 3; attempt++) {
          await controller.refreshDeviceSettings();
          await controller.setAutoMeasureSetting('heartRate', true);
          await controller.refreshDeviceSettings();
          if (controller.autoMeasureSettings['heartRate'] == true) break;
          await tester.pump(const Duration(seconds: 1));
        }
        expect(controller.autoMeasureSettings['heartRate'], isTrue);
      }
      final original = Map<String, bool>.from(controller.autoMeasureSettings);
      final checked = <String>[];
      try {
        for (final type in types) {
          final tile = find.byKey(ValueKey('device-health-auto-$type'));
          await tester.ensureVisible(tile);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(of: tile, matching: find.byType(Switch)),
          );
          await tester.pump();
          expect(
            controller.isDeviceSettingsWriting,
            isTrue,
            reason: 'The visible switch must invoke a real setting write',
          );
          for (
            var attempt = 0;
            controller.isDeviceSettingsWriting && attempt < 110;
            attempt++
          ) {
            await tester.pump(const Duration(milliseconds: 500));
          }
          expect(
            controller.deviceSettingsStatus,
            '设置已写入戒指',
            reason:
                'A later refresh must not turn a timed-out write into a pass',
          );
          await controller.refreshDeviceSettings();
          debugPrint(
            'MONITORING $type toggle: ${controller.deviceSettingsStatus}; ${controller.errorMessage}',
          );
          expect(controller.autoMeasureSettings[type], !original[type]!);
          for (final other in types.where((item) => item != type)) {
            expect(controller.autoMeasureSettings[other], original[other]);
          }
          await controller.setAutoMeasureSetting(type, original[type]!);
          debugPrint(
            'MONITORING $type restore: ${controller.deviceSettingsStatus}; ${controller.errorMessage}',
          );
          expect(controller.deviceSettingsStatus, '设置已写入戒指');
          await controller.refreshDeviceSettings();
          expect(controller.autoMeasureSettings, original);
          await tester.pumpAndSettle();
          checked.add(type);
        }
      } finally {
        // Always send original values, even when an earlier write timed out and
        // the UI cache did not learn whether the physical ring accepted it.
        for (final type in types) {
          for (var attempt = 0; attempt < 3; attempt++) {
            await tester.pump(const Duration(seconds: 1));
            await controller.setAutoMeasureSetting(type, original[type]!);
            debugPrint(
              'MONITORING cleanup $type: ${controller.deviceSettingsStatus}; ${controller.errorMessage}',
            );
            await controller.refreshDeviceSettings();
            if (controller.autoMeasureSettings[type] == original[type]) break;
          }
        }
        await controller.refreshDeviceSettings();
        expect(controller.autoMeasureSettings, original);
      }
      expect(controller.session?.accountKey, owner);
      expect(tester.takeException(), isNull);
      binding.reportData = {
        'verifiedSwitches': checked,
        'originalSettingsRestored': true,
      };
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
