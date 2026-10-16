import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';

/// Real, already owner-bound R7 Ultra only. No account replacement, unbinding,
/// invented samples or physiological commands. Run only through the preserving
/// Profile wrapper; reinstall the normal production main afterward.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'owned R7 Ultra connection, sync, activity and sleep',
    (tester) async {
      debugPrint('R7 LIVE: test_entry');
      final controller = AppController.production();
      debugPrint('R7 LIVE: controller_created');
      final checks = <String>[];
      final issues = <String>[];
      final observations = <String, Object?>{};
      addTearDown(controller.dispose);
      final heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
        debugPrint(
          'R7 LIVE: heartbeat sync=${controller.isDeviceSyncing} '
          'frames=${binding.framesEnabled} lifecycle=${binding.lifecycleState}',
        );
      });
      addTearDown(heartbeat.cancel);

      Future<void> waitFor(bool Function() ready, String reason) async {
        for (var i = 0; i < 240 && !ready(); i++) {
          await tester
              .pump(const Duration(milliseconds: 500))
              .timeout(const Duration(seconds: 20));
        }
        expect(ready(), isTrue, reason: reason);
      }

      void record(String name) {
        checks.add(name);
        // Labels only, never account/device identifiers or health values.
        debugPrint('R7 LIVE: $name');
      }

      try {
        // Match production main: attach the App before asynchronous startup,
        // without waiting for a first frame before plugins can initialize.
        runApp(SaydianApp(controller: controller));
        await Future<void>.delayed(const Duration(seconds: 1));
        await controller.initialize().timeout(const Duration(seconds: 45));
        debugPrint('R7 LIVE: controller_initialized');
        await tester.pump().timeout(const Duration(seconds: 20));
        debugPrint('R7 LIVE: app_mounted');
        expect(controller.isAuthenticated, isTrue);
        expect(controller.isPreviewMode, isFalse);
        expect(controller.isLocalMode, isFalse);
        expect(controller.isWellnessOnly, isTrue);
        final owner = controller.session!.accountKey;
        final target = controller.rememberedDevice;
        expect(target, isNotNull, reason: 'Existing owner-bound ring required');
        expect(
          target!.name.toUpperCase().replaceAll(RegExp(r'[\s_-]'), ''),
          contains('R7ULTRA'),
        );

        void sameOwnerAndTarget() {
          expect(controller.session?.accountKey, owner);
          expect(controller.rememberedDevice?.id, target.id);
          if (controller.connectedDevice != null) {
            expect(controller.connectedDevice!.id, target.id);
            expect(
              controller.connectedDevice!.sdkSource,
              WearableSdkSource.coolwear,
            );
          }
        }

        await waitFor(
          () =>
              controller.connectedDevice?.id == target.id &&
              controller.deviceCapabilityState == DeviceCapabilityState.ready &&
              controller.connectedDevice?.battery?.updatedAt != null &&
              !controller.isDeviceSyncing,
          'Initial real handshake and bounded history read must finish',
        );
        sameOwnerAndTarget();
        observations['historyMetrics'] = controller.capabilities?.historyMetrics
            ?.map((m) => m.wireName)
            .toList();
        record('initial_owned_coolwear_handshake_and_battery');

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        Future<List<HealthRecord>> activity() async =>
            (await controller
                    .loadHealthRecords(
                      metric: HealthMetric.steps,
                      start: today.toUtc(),
                      end: DateTime(now.year, now.month, now.day + 1).toUtc(),
                    )
                    .timeout(const Duration(seconds: 30)))
                .where((r) => r.deviceId == target.id)
                .toList();
        record('before_activity_read');
        final first = await activity();
        record('activity_read_completed');
        observations['activityPresentBeforeManualSync'] = first.isNotEmpty;

        controller.selectTab(1);
        record('device_tab_selected');
        await tester.pump(const Duration(seconds: 1));
        record('device_tab_rendered');
        for (var round = 1; round <= 2; round++) {
          await waitFor(
            () => !controller.isDeviceSyncing,
            'Prior sync is busy',
          );
          final button = find.byKey(const Key('device-sync-data'));
          await tester.ensureVisible(button);
          expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
          if (round == 1) {
            await tester.tap(button);
            record('manual_sync_1_tapped');
            await tester.pump(const Duration(milliseconds: 100));
            await waitFor(
              () => !controller.isDeviceSyncing,
              'Manual sync timed out',
            );
          } else {
            final completed = await controller.syncDeviceData().timeout(
              const Duration(minutes: 2),
            );
            observations['manualSyncConfirmedComplete'] = completed;
            observations['manualSyncError'] = controller.errorMessage;
            if (!completed &&
                (controller.syncStatus == '暂无新增数据' ||
                    controller.errorMessage == null)) {
              issues.add('unconfirmed_sync_misrepresented_as_up_to_date');
            }
            if (controller.errorMessage?.contains('设备忙') ?? false) {
              issues.add('manual_sync_collides_with_battery_refresh');
            }
            await tester.pump(const Duration(milliseconds: 100));
          }
          sameOwnerAndTarget();
          observations['syncStatus$round'] = controller.syncStatus;
          final rows = await activity();
          expect(rows.map((r) => r.id).toSet().length, rows.length);
          for (final row in rows) {
            expect(row.source, MeasurementSource.wearable);
            expect(row.values['value']?.isFinite, isTrue);
            expect(row.values['value'], greaterThanOrEqualTo(0));
          }
          record('manual_sync_${round}_keeps_owner_and_valid_activity');
        }
        final rows = await activity();
        observations['activityPresentAfterSync'] = rows.isNotEmpty;
        observations['positiveActivityAfterWalk'] = rows.any(
          (r) => (r.values['value'] ?? 0) > 0,
        );
        if (rows.isEmpty) {
          issues.add('today_activity_missing_after_walk_and_sync');
        }

        controller.selectTab(0);
        await tester.pump(const Duration(seconds: 2));
        final steps = find.byKey(const ValueKey('health-metric-steps'));
        if (steps.evaluate().isNotEmpty ||
            controller.shouldShowHealthMetric(HealthMetric.steps)) {
          await tester.scrollUntilVisible(
            steps,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(steps);
          await tester.pump(const Duration(seconds: 2));
          expect(find.byKey(const Key('health-trend-steps')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await binding.takeScreenshot('r7-activity-private');
          record('activity_details_render_without_exception');
          await tester.binding.handlePopRoute();
          await tester.pump(const Duration(seconds: 1));
        } else {
          issues.add('activity_entry_missing_after_walk');
        }

        final sleep = await controller.loadSleepDays(
          start: today.subtract(const Duration(days: 30)),
          end: today,
        );
        final ownedSleep = sleep.where((r) => r.deviceId == target.id).toList();
        observations['ownedSleepSamplePresent'] = ownedSleep.isNotEmpty;
        expect(ownedSleep.map((r) => r.id).toSet().length, ownedSleep.length);
        for (final row in ownedSleep) {
          expect(row.metric, HealthMetric.sleep);
          expect(row.values['value']?.isFinite, isTrue);
          expect(row.values['value'], greaterThan(0));
          expect(row.values['value'], lessThanOrEqualTo(24));
        }
        final sleepEntry = find.byKey(const Key('home-sleep-overview-entry'));
        await tester.scrollUntilVisible(
          sleepEntry,
          -280,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(sleepEntry);
        await tester.pump(const Duration(seconds: 3));
        expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
        if (ownedSleep.isEmpty) {
          expect(find.textContaining('暂无'), findsWidgets);
          record('sleep_absent_samples_remain_unknown');
        }
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('r7-sleep-private');
        record('sleep_history_and_overview_render_without_exception');
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(seconds: 1));

        controller.selectTab(1);
        await tester.pump(const Duration(seconds: 1));
        for (var round = 1; round <= 3; round++) {
          await waitFor(
            () => !controller.isDeviceSyncing,
            'Wait before disconnect',
          );
          final oldBatteryTime =
              controller.connectedDevice!.battery!.updatedAt!;
          await controller.disconnectDevice();
          await tester.pump(const Duration(milliseconds: 300));
          expect(controller.connectedDevice, isNull);
          sameOwnerAndTarget();
          final reconnect = find.byKey(const Key('device-reconnect'));
          await tester.ensureVisible(reconnect);
          await tester.tap(reconnect);
          await tester.pump(const Duration(milliseconds: 100));
          await waitFor(
            () =>
                !controller.isDeviceReconnecting &&
                controller.connectedDevice?.id == target.id &&
                controller.deviceCapabilityState ==
                    DeviceCapabilityState.ready &&
                (controller.connectedDevice?.battery?.updatedAt?.isAfter(
                      oldBatteryTime,
                    ) ??
                    false),
            'Visible reconnect must complete a fresh owned handshake',
          );
          sameOwnerAndTarget();
          expect(tester.takeException(), isNull);
          record('software_disconnect_visible_reconnect_$round');
        }
        await waitFor(
          () => !controller.isDeviceSyncing,
          'Finish last bounded sync',
        );
        sameOwnerAndTarget();
        await binding.takeScreenshot('r7-connected-after-tests-private');
        expect(
          issues,
          isEmpty,
          reason: 'Real-device sync/activity issues require repair',
        );
      } finally {
        binding.reportData = {
          ...?binding.reportData,
          'checks': checks,
          'issues': issues,
          'observations': observations,
          'sleepOvernightAcceptance':
              'not_available_user_did_not_wear_last_night',
        };
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
