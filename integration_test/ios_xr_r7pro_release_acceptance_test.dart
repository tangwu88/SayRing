import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';

/// Actual existing owner/target only. Use the preserving Profile wrapper and
/// restore the normal main afterward. Health payloads remain private on-device.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'XR existing R7 Pro connection, activity and sleep acceptance',
    (tester) async {
      final app = AppController.production();
      final proof = <String, Object?>{};
      final private = <String, Object?>{};
      final clock = Stopwatch()..start();
      try {
        runApp(SaydianApp(controller: app));
        await app.initialize().timeout(const Duration(seconds: 60));
        final owner = app.session?.accountKey;
        final target = app.rememberedDevice;
        expect(owner != null, isTrue, reason: 'Existing member required');
        expect(target != null, isTrue, reason: 'Never choose or reset a ring');
        final model = target!.name.toUpperCase().replaceAll(
          RegExp(r'[\s_-]'),
          '',
        );
        expect(
          model.contains('HR05') || model.contains('R7PRO'),
          isTrue,
          reason: 'Use only the existing R7 Pro target',
        );
        Future<void> waitFor(bool Function() ready, int seconds) async {
          for (var i = 0; i < seconds * 2 && !ready(); i++) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            await tester.pump().timeout(const Duration(seconds: 15));
          }
        }

        Future<void> settle() async {
          // Live Bluetooth and dashboard animations need bounded frames.
          for (var i = 0; i < 3; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            await tester.pump().timeout(const Duration(seconds: 15));
          }
        }

        bool ready() =>
            app.connectedDevice?.id == target.id &&
            app.deviceCapabilityState == DeviceCapabilityState.ready;
        if (!ready()) {
          await app.reconnectDevice().timeout(const Duration(seconds: 60));
        }
        await waitFor(ready, 60);
        proof['exactTargetReady'] = ready();
        proof['connectionSeconds'] = clock.elapsedMilliseconds / 1000;
        proof['ownerUnchanged'] = app.session?.accountKey == owner;
        proof['targetUnchanged'] = app.rememberedDevice?.id == target.id;
        if (!ready()) {
          await app.scanDevices().timeout(const Duration(seconds: 45));
          proof['savedTargetAdvertised'] = app.scannedDevices.any(
            (d) => d.id.toUpperCase() == target.id.toUpperCase(),
          );
          proof['scanCount'] = app.scannedDevices.length;
          proof['scanIssue'] = app.deviceScanIssue?.name;
          await app.stopDeviceScan();
        }
        expect(
          ready(),
          isTrue,
          reason: 'Original target must complete the real handshake',
        );
        proof['batteryRead'] = app.connectedDevice?.battery?.updatedAt != null;
        proof['supportsHistorySync'] = app.capabilities?.supportsHistorySync;
        proof['historyMetrics'] = app.capabilities?.historyMetrics
            ?.map((m) => m.wireName)
            .toList();
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day);
        final start = day.subtract(const Duration(days: 7));
        final end = day.add(const Duration(days: 1));
        Future<Map<String, Object?>> snapshot() async => {
          for (final metric in [
            HealthMetric.steps,
            HealthMetric.distance,
            HealthMetric.calories,
            HealthMetric.sleep,
          ])
            metric.wireName:
                (await app.loadHealthRecords(
                      metric: metric,
                      start: start,
                      end: end,
                    ))
                    .where((r) => r.deviceId == target.id)
                    .map((r) => r.toJson())
                    .toList(),
        };
        private['before'] = await snapshot();
        await waitFor(() => !app.isDeviceSyncing, 90);
        proof['initialSyncFinished'] = !app.isDeviceSyncing;
        expect(app.isDeviceSyncing, isFalse);
        final syncClock = Stopwatch()..start();
        final complete = await app.syncDeviceData().timeout(
          const Duration(minutes: 2),
        );
        proof['manualSyncComplete'] = complete;
        proof['manualSyncSeconds'] = syncClock.elapsedMilliseconds / 1000;
        proof['syncErrorPresent'] = app.errorMessage != null;
        private['syncStatus'] = app.syncStatus;
        private['syncError'] = app.errorMessage;
        private['after'] = await snapshot();
        final steps = (await app.loadHealthRecords(
          metric: HealthMetric.steps,
          start: day,
          end: end,
        )).where((r) => r.deviceId == target.id).toList();
        proof['todayStepRecords'] = steps.length;
        proof['todayStepValuesSane'] = steps.every(
          (r) =>
              r.values['value'] != null &&
              r.values['value']!.isFinite &&
              r.values['value']! >= 0,
        );
        proof['uniqueActivityIds'] =
            steps.map((r) => r.id).toSet().length == steps.length;
        final sleep = await app.loadSleepDays(start: start, end: day);
        final latest = await app.loadLatestSleepDay();
        private['sleepDays'] = sleep.map((r) => r.toJson()).toList();
        private['latestSleep'] = latest?.toJson();
        proof['currentTargetSleepDays'] = sleep
            .where((r) => r.deviceId == target.id)
            .length;
        proof['latestSleepPresent'] = latest != null;
        proof['sleepRowsMatchTarget'] = sleep.every(
          (r) => r.deviceId == target.id,
        );
        proof['sleepSummariesMatchTimeline'] = sleep.every(
          (r) =>
              r.sleepTimeline == null ||
              r.values.length == r.sleepTimeline!.summaryValues.length &&
                  r.values.entries.every(
                    (e) => r.sleepTimeline!.summaryValues[e.key] == e.value,
                  ),
        );
        private['sleepReadStatuses'] = app.sleepReadStatuses;
        app.selectTab(0);
        await settle();
        expect(find.byKey(const Key('dashboard-today-health')), findsOneWidget);
        await binding.takeScreenshot('1141-r7pro-activity-private');
        final entry = find.byKey(const Key('home-sleep-overview-entry'));
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await settle();
        expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
        await binding.takeScreenshot('1141-r7pro-sleep-private');
        await tester.tap(find.byKey(const Key('sleep-previous-day')));
        await settle();
        await tester.tap(find.byKey(const Key('sleep-latest-day')));
        await settle();
        proof['sleepPageAndNavigation'] = true;
        proof['ownerUnchanged'] = app.session?.accountKey == owner;
        proof['targetUnchanged'] = app.rememberedDevice?.id == target.id;
        expect(tester.takeException(), isNull);
        expect(proof['ownerUnchanged'], isTrue);
        expect(proof['targetUnchanged'], isTrue);
        expect(proof['todayStepValuesSane'], isTrue);
        expect(proof['uniqueActivityIds'], isTrue);
        expect(proof['sleepRowsMatchTarget'], isTrue);
        expect(proof['sleepSummariesMatchTimeline'], isTrue);
        await tester.binding.handlePopRoute();
        await settle();
        final reconnects = <Map<String, Object?>>[];
        proof['softwareReconnects'] = reconnects;
        for (var round = 0; round < 2; round++) {
          await waitFor(() => !app.isDeviceSyncing, 90);
          expect(app.isDeviceSyncing, isFalse);
          app.selectTab(1);
          await settle();
          await app.disconnectDevice().timeout(const Duration(seconds: 30));
          expect(app.connectedDevice, isNull);
          expect(app.rememberedDevice?.id, target.id);
          await settle();
          final reconnect = find.byKey(const Key('device-reconnect'));
          await tester.ensureVisible(reconnect);
          final reconnectClock = Stopwatch()..start();
          await tester.tap(reconnect.hitTestable());
          await settle();
          await waitFor(() => ready() && !app.isDeviceReconnecting, 60);
          reconnects.add({
            'ready': ready(),
            'seconds': reconnectClock.elapsedMilliseconds / 1000,
            'ownerUnchanged': app.session?.accountKey == owner,
            'targetUnchanged': app.rememberedDevice?.id == target.id,
            'batteryRead': app.connectedDevice?.battery?.updatedAt != null,
          });
          expect(ready(), isTrue);
          expect(app.session?.accountKey, owner);
          expect(app.rememberedDevice?.id, target.id);
        }
        await waitFor(() => !app.isDeviceSyncing, 90);
        expect(app.isDeviceSyncing, isFalse);
        expect(
          complete,
          isTrue,
          reason: 'SDK must confirm full history, not only a current snapshot',
        );
      } finally {
        proof['elapsedSeconds'] = clock.elapsedMilliseconds / 1000;
        binding.reportData = {...?binding.reportData, 'r7proAcceptance': proof};
        final documents = await getApplicationDocumentsDirectory();
        await File(
          '${documents.path}/r7pro-release-acceptance-private.json',
        ).writeAsString(jsonEncode({'proof': proof, ...private}), flush: true);
        app.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
