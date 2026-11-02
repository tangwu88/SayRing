import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';

// Continue the existing owner-bound R8's initialization. Never bind, clear,
// reset, replace an account, inject history or change an activity goal.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'existing R8 initialization and actual history sync',
    (tester) async {
      final app = AppController.production();
      final proof = <String, Object?>{};
      Future<void> waitFor(bool Function() condition, String label) async {
        for (var i = 0; i < 240 && !condition(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await tester.pump().timeout(const Duration(seconds: 15));
        }
        expect(condition(), isTrue, reason: label);
        proof[label] = true;
        debugPrint('R8 INITIALIZATION: $label');
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
              app.connectedDevice?.id == target.id && app.capabilities != null,
          'original_ring_connected',
        );
        final native = await const MethodChannel(
          'cc.saidian.ring/qring/commands',
        ).invokeMapMethod<String, Object?>('getCapabilities');
        proof['nativeHistoryAvailable'] = native?['supportsHistorySync'];
        proof['pendingInitialization'] = app.isRingInitializationPending;
        expect(native?['resolved'], true);
        expect(native?['supportsHistorySync'], true);
        await waitFor(
          () =>
              !app.isRingInitializationPending &&
              app.capabilities?.supportsHistorySync == true &&
              !app.isDeviceSyncing,
          'initialization_completed_and_history_available',
        );
        app.selectTab(1);
        await tester.pump(const Duration(seconds: 1));
        final button = find.byKey(const Key('device-sync-data'));
        expect(button, findsOneWidget);
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        proof['syncButtonEnabled'] = true;
        await binding.takeScreenshot('r8-initialization-sync-ready');
        final completed = await app.syncDeviceData().timeout(
          const Duration(minutes: 3),
        );
        proof['actualSyncCompleted'] = completed;
        proof['receivedRecords'] = app.deviceSyncReceivedRecords;
        expect(completed, true, reason: 'Require the real SDK completion');
        expect(app.isDeviceSyncing, false);
        expect(app.errorMessage, isNull);
        expect(app.session?.accountKey, owner);
        expect(app.rememberedDevice?.id, target.id);
        expect(app.connectedDevice?.id, target.id);
        proof['originalOwnerAndBindingPreserved'] = true;
        final byMetric = <String, int>{};
        for (final record in app.healthRecords.where(
          (record) => record.deviceId == target.id,
        )) {
          byMetric.update(
            record.metric.wireName,
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        }
        proof['storedRecordCountsForTarget'] = byMetric;
        app.selectTab(0);
        await tester.pump(const Duration(seconds: 1));
        await binding.takeScreenshot('r8-initialization-health-after-sync');
        expect(tester.takeException(), isNull);
      } finally {
        binding.reportData = proof;
        final directory = await getApplicationDocumentsDirectory();
        await File(
          '${directory.path}/r8-initialization-recovery-proof.json',
        ).writeAsString(jsonEncode(proof), flush: true);
        app.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
