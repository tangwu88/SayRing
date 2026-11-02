import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/health_record_units.dart';
import 'package:saydian_app/domain/models.dart';
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
      Future<void> capture(String name) async {
        final bytes = await binding.takeScreenshot(name);
        final root = await getApplicationDocumentsDirectory();
        final directory = Directory('${root.path}/r8-sync-acceptance-screens');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(bytes, flush: true);
      }

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
        await capture('r8-initialization-sync-ready');
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
        await capture('r8-initialization-health-after-sync');
        if (const bool.fromEnvironment('SAYRING_QA_ACTIVITY_SLEEP')) {
          // Enable only after the user has confirmed walking with this ring.
          // Read actual records and pages; never create samples or settings.
          final now = DateTime.now();
          final today = app.healthRecords.where((record) {
            final date = record.measuredAt.toLocal();
            return record.deviceId == target.id &&
                date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          }).toList()..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
          final activity = <String, Object?>{};
          for (final metric in [
            HealthMetric.steps,
            HealthMetric.distance,
            HealthMetric.calories,
          ]) {
            final records = today.where((record) => record.metric == metric);
            expect(
              records,
              isNotEmpty,
              reason: 'Real current-day ${metric.wireName}',
            );
            final record = records.first;
            activity[metric.wireName] = {
              'values': record.values,
              'unit': record.unit,
              'source': record.source.name,
              'origin': record.origin.wireName,
              'measuredAt': record.measuredAt.toIso8601String(),
              'calorieUnitUnconfirmed': hasUnconfirmedCalorieUnit(record),
            };
            proof['currentDayActivity'] = activity;
            expect(record.source, MeasurementSource.wearable);
            expect(record.values.values.every((value) => value.isFinite), true);
            expect(record.unit, isNotEmpty);
            if (metric == HealthMetric.steps) {
              expect(
                record.values['value'],
                greaterThan(0),
                reason: 'User confirmed walking',
              );
            }
          }
          Future<void> settle() async {
            for (var i = 0; i < 4; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 300));
              await tester.pump().timeout(const Duration(seconds: 15));
            }
          }

          Future<void> tapVisible(Finder finder) async {
            await tester.scrollUntilVisible(
              finder,
              180,
              scrollable: find.byType(Scrollable).first,
            );
            await Scrollable.ensureVisible(
              tester.element(finder),
              alignment: .5,
            );
            await settle();
            await tester.tap(finder.hitTestable());
            await settle();
          }

          final visited = <String>[];
          proof['activitySleepPages'] = visited;
          for (final metric in [
            HealthMetric.steps,
            HealthMetric.distance,
            HealthMetric.calories,
          ]) {
            final label = find.descendant(
              of: find.byKey(const Key('dashboard-today-health')),
              matching: find.text(metric.label),
            );
            await tapVisible(label);
            expect(
              find.byKey(Key('health-trend-${metric.wireName}')),
              findsOneWidget,
            );
            for (final period in ['周', '月', '日']) {
              await tapVisible(find.text(period));
            }
            if (metric == HealthMetric.calories &&
                today.any(hasUnconfirmedCalorieUnit)) {
              await tapVisible(
                find.byKey(const Key('calorie-unit-unconfirmed')),
              );
              proof['unconfirmedCalorieUnitProtected'] = true;
            }
            expect(tester.takeException(), isNull);
            visited.add('${metric.wireName}-day-week-month');
            await capture('r8-${metric.wireName}-trend');
            await tester.binding.handlePopRoute();
            await settle();
          }
          final latestSleep = await app.loadLatestSleepDay();
          proof['latestSleepPresent'] = latestSleep != null;
          await tapVisible(find.byKey(const Key('home-sleep-overview-entry')));
          expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
          await tapVisible(find.byKey(const Key('sleep-previous-day')));
          await tapVisible(find.byKey(const Key('sleep-next-day')));
          expect(tester.takeException(), isNull);
          visited.add('sleep-overview-date-navigation');
          await capture('r8-sleep-overview');
          await tester.binding.handlePopRoute();
          await settle();
          expect(app.session?.accountKey, owner);
          expect(app.rememberedDevice?.id, target.id);
          expect(app.connectedDevice?.id, target.id);
        }
        expect(tester.takeException(), isNull);
        proof['acceptanceCompleted'] = true;
      } finally {
        binding.reportData = {...?binding.reportData, ...proof};
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
