import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/health_record_units.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_routing.dart';

// Existing owner and exact R8 only. No binding, reset, measurement or setting
// write. Software disconnect is not a distance/locked-screen recovery test.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'connection hotfix retained R8 smoke',
    (tester) async {
      final app = AppController.production();
      final proof = <String, Object?>{};
      Future<void> settlePage() async {
        for (var frame = 0; frame < 2; frame++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await tester.pump().timeout(const Duration(seconds: 15));
        }
      }

      Future<void> capture(String name) async {
        // Give the selected tab/route two real frames before capturing it.
        await settlePage();
        await binding.takeScreenshot(name);
      }

      Future<void> tapVisible(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
        await settlePage();
        await tester.tap(finder.hitTestable());
        await settlePage();
      }

      Future<void> recordBindingState(String phase) async {
        final state = <String, Object?>{
          'authenticated': app.isAuthenticated,
          'localMode': app.isLocalMode,
          'previewMode': app.isPreviewMode,
          'rememberedPresent': app.rememberedDevice != null,
          'connectedPresent': app.connectedDevice != null,
          'deviceState': app.deviceState.name,
          'capabilityState': app.deviceCapabilityState.name,
          'recovering': app.isWearableRecovering,
          'initializationPending': app.isRingInitializationPending,
          'sdkStatus': app.sdkStatus,
          'recoveryMessage': app.wearableRecoveryMessage,
        };
        try {
          state['privacyConsentGranted'] = await SecureSessionVault.global()
              .readPrivacyConsentGranted();
          state['privacyReadSucceeded'] = true;
        } catch (_) {
          state['privacyReadSucceeded'] = false;
        }
        try {
          // Diagnostic only: never adopt this raw saved object as a target,
          // change its owner or call a connection/reset method with it.
          final saved = await const SecureWearableTransportPreferenceStore()
              .readBinding();
          state['bindingReadSucceeded'] = true;
          state['savedBindingPresent'] = saved != null;
          state['savedOwnerPresent'] = saved?.ownerKey != null;
          state['savedOwnerMatches'] =
              saved?.ownerKey != null &&
              saved!.ownerKey == app.homeHealthCardOwner;
          state['savedNamePresent'] = saved?.deviceName != null;
          state['savedNameContainsR8'] =
              saved?.deviceName?.toUpperCase().contains('R8') ?? false;
          state['savedTransport'] = saved?.transport.name;
          state['savedNameMatchesRoute'] =
              saved?.deviceName != null &&
              WearableDeviceClassifier.routesTo(
                saved!.deviceName!,
                saved.transport,
              );
          final remembered = app.rememberedDevice;
          state['rememberedMatchesSaved'] =
              remembered != null &&
              saved != null &&
              remembered.id ==
                  RoutedDevice.scopedID(
                    saved.transport,
                    saved.nativeIdentifier,
                  );
        } catch (_) {
          state['bindingReadSucceeded'] = false;
        }
        proof[phase] = state;
      }

      Future<void> waitFor(
        bool Function() condition,
        String label, {
        int seconds = 120,
      }) async {
        final deadline = DateTime.now().add(Duration(seconds: seconds));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await tester.pump().timeout(const Duration(seconds: 15));
        }
        expect(condition(), true, reason: label);
        proof[label] = true;
      }

      try {
        runApp(SaydianApp(controller: app));
        await app.initialize().timeout(const Duration(seconds: 60));
        expect(
          app.isAuthenticated && !app.isLocalMode && !app.isPreviewMode,
          true,
        );
        final owner = app.session!.accountKey;
        await recordBindingState('bindingAfterInitialization');
        final bindingDeadline = DateTime.now().add(const Duration(seconds: 20));
        while (app.rememberedDevice == null &&
            app.connectedDevice == null &&
            DateTime.now().isBefore(bindingDeadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          final remaining = bindingDeadline.difference(DateTime.now());
          if (remaining <= Duration.zero) break;
          try {
            await tester.pump().timeout(remaining);
          } on TimeoutException {
            proof['bindingWaitFrameTimedOut'] = true;
            break;
          }
        }
        await recordBindingState('bindingAfterWait');
        final remembered = app.rememberedDevice;
        if (remembered == null) {
          proof['preconditionFailure'] =
              'ownerScopedRememberedTargetUnavailable';
          app.selectTab(1);
          try {
            await tester.pump().timeout(const Duration(seconds: 15));
            await capture('connection-hotfix-binding-unavailable');
            proof['bindingFailureScreenshotCaptured'] = true;
          } catch (_) {
            proof['bindingFailureScreenshotCaptured'] = false;
          }
        }
        expect(
          remembered,
          isNotNull,
          reason:
              'No owner-scoped remembered ring became available within 20 '
              'seconds. No target was selected, reset or adopted by this test.',
        );
        final target = remembered!;
        final settled = proof['bindingAfterWait']! as Map<String, Object?>;
        expect(
          settled['savedOwnerMatches'],
          true,
          reason: 'The saved target must belong to the signed-in owner.',
        );
        expect(
          settled['rememberedMatchesSaved'],
          true,
          reason: 'The controller target must match the saved exact target.',
        );
        expect(target.id.startsWith('qring:'), true);
        expect(target.name.toUpperCase().contains('R8'), true);
        await waitFor(
          () =>
              app.connectedDevice?.id == target.id &&
              app.deviceCapabilityState == DeviceCapabilityState.ready &&
              !app.isDeviceSyncing,
          'initialConnectionReady',
        );
        expect(app.isRingInitializationPending, false);
        final originalRecordIds = app.healthRecords.map((r) => r.id).toSet();
        final durations = <int>[];
        proof['softwareReconnectMilliseconds'] = durations;
        for (var round = 0; round < 2; round++) {
          await app.disconnectDevice().timeout(const Duration(seconds: 40));
          expect(app.connectedDevice, isNull);
          expect(app.rememberedDevice?.id, target.id);
          final clock = Stopwatch()..start();
          await app.reconnectDevice().timeout(const Duration(seconds: 45));
          await waitFor(
            () =>
                app.connectedDevice?.id == target.id &&
                app.deviceCapabilityState == DeviceCapabilityState.ready &&
                !app.isDeviceReconnecting,
            'reconnect${round + 1}Ready',
          );
          durations.add(clock.elapsedMilliseconds);
          await waitFor(
            () => !app.isDeviceSyncing,
            'reconnect${round + 1}SyncIdle',
          );
          expect(app.isRingInitializationPending, false);
          expect(app.session?.accountKey, owner);
        }
        app.selectTab(1);
        await waitFor(
          () => app.connectedDevice?.battery?.updatedAt != null,
          'realBatteryReceived',
        );
        expect(find.byKey(const Key('device-sync-data')), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('device-sync-data')))
              .onPressed,
          isNotNull,
        );
        final now = DateTime.now();
        final firstDay = DateTime(now.year, now.month, now.day - 6);
        final lastDay = DateTime(now.year, now.month, now.day);
        final endExclusive = DateTime(now.year, now.month, now.day + 1);
        const metrics = [
          HealthMetric.steps,
          HealthMetric.distance,
          HealthMetric.calories,
          HealthMetric.sleep,
        ];
        Future<Map<HealthMetric, List<HealthRecord>>> readTargetWindow() async {
          final result = <HealthMetric, List<HealthRecord>>{};
          for (final metric in metrics) {
            final records = metric == HealthMetric.sleep
                ? await app.loadSleepDays(start: firstDay, end: lastDay)
                : await app.loadHealthRecords(
                    metric: metric,
                    start: firstDay,
                    end: endExclusive,
                  );
            result[metric] =
                records.where((record) => record.deviceId == target.id).toList()
                  ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
          }
          return result;
        }

        final beforeWindow = await readTargetWindow();
        proof['recordWindowStart'] = firstDay.toIso8601String();
        proof['recordWindowEndExclusive'] = endExclusive.toIso8601String();
        proof['targetStoredCountsBeforeSync'] = {
          for (final metric in metrics)
            metric.wireName: beforeWindow[metric]!.length,
        };
        final completed = await app.syncDeviceData().timeout(
          const Duration(minutes: 3),
        );
        proof['manualSyncCompleted'] = completed;
        proof['syncStatusAfterManual'] = app.syncStatus;
        proof['syncIdleAfterManual'] = !app.isDeviceSyncing;
        proof['syncErrorAbsent'] = app.errorMessage == null;
        // UI-event counter only. iOS QRing does not emit syncRecords, so this
        // must never be presented as the SDK's returned/new-record count.
        proof['syncRecordsEventCount'] = app.deviceSyncReceivedRecords;
        proof['syncRecordsEventCountIsSdkReturnCount'] = false;
        // Capture statuses before loadSleepDays can add cached-day statuses.
        proof['sleepDayStatusesAfterManual'] = Map.of(app.sleepReadStatuses);
        expect(completed, true, reason: 'Require genuine complete SDK history');
        expect(app.isDeviceSyncing, false);
        expect(app.errorMessage, isNull);
        expect(app.session?.accountKey, owner);
        expect(app.connectedDevice?.id, target.id);
        final afterWindow = await readTargetWindow();
        proof['targetStoredCountsAfterSync'] = {
          for (final metric in metrics)
            metric.wireName: afterWindow[metric]!.length,
        };
        proof['newStoredRecordIdsByMetric'] = {
          for (final metric in metrics)
            metric.wireName: afterWindow[metric]!
                .map((record) => record.id)
                .toSet()
                .difference(
                  beforeWindow[metric]!.map((record) => record.id).toSet(),
                )
                .length,
        };
        proof['missingStoredRecordIdsByMetric'] = {
          for (final metric in metrics)
            metric.wireName: beforeWindow[metric]!
                .map((record) => record.id)
                .toSet()
                .difference(
                  afterWindow[metric]!.map((record) => record.id).toSet(),
                )
                .length,
        };
        for (final metric in metrics) {
          final beforeIds = beforeWindow[metric]!
              .map((record) => record.id)
              .toSet();
          final afterIds = afterWindow[metric]!
              .map((record) => record.id)
              .toSet();
          expect(
            afterIds.containsAll(beforeIds),
            true,
            reason: 'Preserve stored ${metric.wireName} records for target',
          );
        }
        final latestActivity = <String, Object?>{};
        for (final metric in metrics.where(
          (metric) => metric != HealthMetric.sleep,
        )) {
          final records = afterWindow[metric]!;
          if (records.isEmpty) {
            latestActivity[metric.wireName] = {'present': false};
            continue;
          }
          final record = records.first;
          expect(record.values.values.every((value) => value.isFinite), true);
          latestActivity[metric.wireName] = {
            'present': true,
            'values': record.values,
            'unit': record.unit,
            'source': record.source.name,
            'origin': record.origin.wireName,
            'measuredAt': record.measuredAt.toIso8601String(),
            'calorieUnitUnconfirmed': hasUnconfirmedCalorieUnit(record),
          };
        }
        proof['latestStoredActivityInWindow'] = latestActivity;
        final currentIds = app.healthRecords.map((r) => r.id).toSet();
        expect(currentIds.containsAll(originalRecordIds), true);
        proof['originalRecordCount'] = originalRecordIds.length;
        proof['retainedRecordCount'] = currentIds.length;
        proof['originalRecordsPreserved'] = true;
        proof['cameraOffered'] = app
            .availabilityFor(DeviceFeature.camera)
            .isReady;
        proof['gestureOffered'] = app
            .availabilityFor(DeviceFeature.gestureControl)
            .isReady;
        await capture('connection-hotfix-device-ready');
        // Observe genuine radio callbacks without generating writes or resets.
        for (var second = 0; second < 90; second++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          await tester.pump().timeout(const Duration(seconds: 15));
          expect(
            app.connectedDevice?.id,
            target.id,
            reason: 'nearby foreground observation',
          );
          expect(app.session?.accountKey, owner);
        }
        proof['foregroundStableSeconds'] = 90;
        app.selectTab(0);
        await capture('connection-hotfix-health');
        final visited = <String>[];
        proof['activitySleepPages'] = visited;
        final stepsLabel = find.descendant(
          of: find.byKey(const Key('dashboard-today-health')),
          matching: find.text(HealthMetric.steps.label),
        );
        await tapVisible(stepsLabel);
        expect(find.byKey(const Key('health-trend-steps')), findsOneWidget);
        for (final period in {'日': 'day', '周': 'week', '月': 'month'}.entries) {
          await tapVisible(find.text(period.key));
          expect(tester.takeException(), isNull);
          await capture('connection-hotfix-steps-${period.value}');
        }
        visited.add('steps-day-week-month');
        await tester.binding.handlePopRoute();
        await settlePage();
        final latestSleep = await app.loadLatestSleepDay();
        proof['latestSleepPresent'] = latestSleep != null;
        await tapVisible(find.byKey(const Key('home-sleep-overview-entry')));
        expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
        await tapVisible(find.byKey(const Key('sleep-previous-day')));
        await tapVisible(find.byKey(const Key('sleep-next-day')));
        expect(tester.takeException(), isNull);
        visited.add('sleep-overview-date-navigation');
        await capture('connection-hotfix-sleep-overview');
        await tester.binding.handlePopRoute();
        await settlePage();
        expect(app.session?.accountKey, owner);
        expect(app.rememberedDevice?.id, target.id);
        expect(app.connectedDevice?.id, target.id);
        expect(tester.takeException(), isNull);
        proof['acceptanceCompleted'] = true;
      } finally {
        binding.reportData = {...?binding.reportData, ...proof};
        final directory = await getApplicationDocumentsDirectory();
        await File(
          '${directory.path}/connection-hotfix-proof.json',
        ).writeAsString(jsonEncode(proof), flush: true);
        app.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
