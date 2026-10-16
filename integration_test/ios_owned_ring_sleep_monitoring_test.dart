import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/app_controller.dart';

/// Current owner-bound QRing or LuckRing only. No new samples or AI upload. Restore
/// every changed setting in finally; always run with the preserving wrapper.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'owned ring sleep and monitoring settings',
    (tester) async {
      final controller = AppController.production();
      addTearDown(controller.dispose);
      final checks = <String>[];
      final observations = <String, Object?>{};
      void checked(String label) {
        checks.add(label);
        debugPrint('SLEEP MONITOR: $label');
      }

      Future<void> waitFor(bool Function() ready) async {
        for (var i = 0; i < 180 && !ready(); i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(ready(), isTrue);
      }

      try {
        runApp(SaydianApp(controller: controller));
        checked('waiting_for_foreground');
        while (!binding.framesEnabled ||
            binding.lifecycleState != AppLifecycleState.resumed) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        checked('foreground_ready');
        await Future<void>.delayed(const Duration(seconds: 1));
        await controller.initialize().timeout(const Duration(seconds: 45));
        await tester.pump();
        expect(controller.isAuthenticated, isTrue);
        expect(controller.isWellnessOnly, isTrue);
        final owner = controller.session!.accountKey;
        final target = controller.rememberedDevice!;
        expect(
          target.id.startsWith('qring:') || target.id.startsWith('coolwear:'),
          isTrue,
        );
        void sameTarget() {
          expect(controller.session?.accountKey, owner);
          expect(controller.connectedDevice?.id, target.id);
        }

        await waitFor(
          () =>
              controller.connectedDevice?.id == target.id &&
              !controller.isDeviceSyncing &&
              controller.deviceCapabilityState == DeviceCapabilityState.ready,
        );
        sameTarget();
        checked('owned_handshake');
        await controller.refreshDeviceSettings().timeout(
          const Duration(seconds: 40),
        );
        sameTarget();
        expect(controller.autoMeasureSettings, isNotEmpty);
        expect(
          controller.visibleDeviceFeatures,
          contains(DeviceFeature.healthMonitoring),
        );
        if (const bool.hasEnvironment('SAYRING_RESTORE_OWNED_HEART')) {
          // Repair only this task's interrupted temporary write on the same
          // existing owner-bound target; never a firmware/product default.
          sameTarget();
          expect(target.id.startsWith('qring:'), isTrue);
          try {
            await const MethodChannel(
              'cc.saidian.ring/qring/commands',
            ).invokeMethod<void>('setAutoMeasureSetting', {
              'type': 'heartRate',
              'enabled': const bool.fromEnvironment(
                'SAYRING_RESTORE_OWNED_HEART',
              ),
            });
          } on PlatformException catch (error) {
            observations['restoreNativeError'] = error.code;
            observations['restoreNativeDetails'] = error.details;
            rethrow;
          }
          await controller.refreshDeviceSettings();
          checked('prior_interrupted_switch_restored');
        }
        final original = Map<String, bool>.from(controller.autoMeasureSettings);
        final originalIntervals = Map.of(controller.autoMeasureIntervals);
        observations['frequencyAvailable'] =
            controller.autoMeasureIntervals.isNotEmpty;
        checked('real_monitoring_read');
        controller.selectTab(1);
        await tester.pump(const Duration(seconds: 1));
        final entry = find.text('健康监测');
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pump(const Duration(milliseconds: 500));
        await waitFor(() => !controller.isDeviceSettingsLoading);
        expect(find.text('健康监测'), findsOneWidget);
        checked('monitoring_page_open');
        const type = 'heartRate';
        expect(original.containsKey(type), isTrue);
        try {
          sameTarget();
          await controller.setAutoMeasureSetting(type, !original[type]!);
          observations['switchWriteStatus'] = controller.deviceSettingsStatus;
          observations['switchWriteError'] = controller.errorMessage;
          expect(controller.autoMeasureSettings[type], !original[type]!);
          expect(controller.deviceSettingsStatus, contains('读回确认'));
          checked('switch_write_and_readback');
          final interval = originalIntervals[type];
          if (interval != null && interval.canModify) {
            if (controller.autoMeasureSettings[type] != true) {
              await controller.setAutoMeasureSetting(type, true);
            }
            final choices = interval.choices
                .where((value) => value != interval.minutes)
                .toList();
            expect(choices, isNotEmpty);
            final slower = choices
                .where((value) => value > interval.minutes)
                .firstOrNull;
            await controller.setAutoMeasureInterval(
              type,
              slower ?? choices.last,
            );
            expect(
              controller.autoMeasureIntervals[type]!.minutes,
              slower ?? choices.last,
            );
            expect(controller.deviceSettingsStatus, contains('读回确认'));
            checked('frequency_write_and_readback');
          }
        } finally {
          sameTarget();
          final interval = originalIntervals[type];
          if (interval != null && interval.canModify) {
            if (controller.autoMeasureSettings[type] != true) {
              await controller.setAutoMeasureSetting(type, true);
            }
            await controller.setAutoMeasureInterval(type, interval.minutes);
            expect(
              controller.autoMeasureIntervals[type]!.minutes,
              interval.minutes,
            );
          }
          await controller.setAutoMeasureSetting(type, original[type]!);
          await controller.refreshDeviceSettings();
          expect(controller.autoMeasureSettings, original);
          checked('original_settings_restored');
        }
        await binding.takeScreenshot('sleep-monitor-settings-private');
        Navigator.of(tester.element(find.text('健康监测'))).pop();
        await tester.pump(const Duration(milliseconds: 300));
        controller.selectTab(0);
        await tester.pump(const Duration(milliseconds: 500));
        final sleep = find.byKey(const Key('home-sleep-overview-entry'));
        await tester.ensureVisible(sleep);
        await tester.tap(sleep);
        await tester.pump(const Duration(seconds: 1));
        await waitFor(
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
        expect(find.text('最近一次睡眠'), findsOneWidget);
        final latest = await controller.loadLatestSleepDay();
        observations['hasActualSleep'] = latest != null;
        observations['sleepAiConfigured'] = controller.sleepAiEnabled;
        if (latest == null) {
          expect(find.textContaining('暂无'), findsWidgets);
          expect(find.byKey(const Key('sleep-ai-report-entry')), findsNothing);
        }
        checked('latest_sleep_or_honest_empty');
        await tester.tap(find.byKey(const Key('sleep-previous-day')));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('按日期查看'), findsOneWidget);
        await tester.tap(find.byKey(const Key('sleep-latest-day')));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('最近一次睡眠'), findsOneWidget);
        expect(tester.takeException(), isNull);
        sameTarget();
        checked('selected_date_and_latest_shortcut');
        await binding.takeScreenshot('sleep-monitor-overview-private');
      } finally {
        binding.reportData = {
          ...?binding.reportData,
          'checks': checks,
          'observations': observations,
          'overnightSleep': 'not_newly_collected_in_this_test',
          'aiProviderUpload': 'not_performed',
        };
      }
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
