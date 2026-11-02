import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/app_controller.dart';

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
        final target = app.rememberedDevice!;
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
          await app.reconnectDevice().timeout(
            const Duration(seconds: 45),
          );
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
        expect(
          await app.syncDeviceData().timeout(const Duration(minutes: 3)),
          true,
        );
        proof['manualSyncCompleted'] = true;
        proof['receivedRecords'] = app.deviceSyncReceivedRecords;
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
        await binding.takeScreenshot('connection-hotfix-device-ready');
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
        await tester.pump();
        await binding.takeScreenshot('connection-hotfix-health');
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
