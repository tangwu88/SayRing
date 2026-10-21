import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/health_record_units.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';

/// Only the existing owner's ring. Back up first; run through the preserving
/// Profile wrapper, then restore the normal main without uninstalling.
/// Health payloads stay in the app's private Documents directory, never logs.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'owned ring activity and sleep data validation',
    (tester) async {
      final observations = <String, Object?>{};
      final checks = <String>[];
      AppController? controller;
      void checked(String value) {
        checks.add(value);
        debugPrint('ACTIVITY SLEEP: $value');
      }

      Future<void> pumpFor(Duration duration) async {
        await tester.pump(duration).timeout(const Duration(seconds: 20));
      }

      Future<void> waitFor(bool Function() ready, String reason) async {
        for (var i = 0; i < 240 && !ready(); i++) {
          await pumpFor(const Duration(seconds: 1));
        }
        expect(ready(), isTrue, reason: reason);
      }

      try {
        runApp(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('数据核验中'))),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
        final vault = SecureSessionVault.global();
        final session = await vault.readSession();
        expect(
          session,
          isNotNull,
          reason: 'Existing account required; no login replacement',
        );
        final identity = session!.memberId.trim().isNotEmpty
            ? 'member:${session.memberId.trim()}'
            : 'account:${session.accountKey.trim()}';
        final owner = sha256
            .convert(utf8.encode('saydian-health-owner:$identity'))
            .toString();
        final store = EncryptedHealthStore(vault, globalEdition: true);
        final support = await getApplicationSupportDirectory();
        final database = await openDatabase(
          path.join(support.path, store.databaseFileName),
          password: await vault.databaseKey(),
          readOnly: true,
          singleInstance: false,
        );
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day);
        try {
          final raw = await database.query(
            'health_records',
            columns: ['payload'],
            where:
                'owner_id = ? AND metric IN (?, ?, ?, ?) AND measured_at >= ? AND synced != -1',
            whereArgs: [
              owner,
              'steps',
              'distance',
              'calories',
              'sleep',
              day.subtract(const Duration(days: 7)).toUtc().toIso8601String(),
            ],
            orderBy: 'measured_at ASC',
          );
          observations['savedRecordsBeforeStartup'] = raw
              .map((r) => jsonDecode(r['payload']! as String))
              .toList();
          checked('owned_database_read_only_snapshot');
        } finally {
          await database.close();
        }
        final app = AppController.production();
        controller = app;
        runApp(SaydianApp(controller: app));
        await Future<void>.delayed(const Duration(seconds: 1));
        await app.initialize().timeout(const Duration(seconds: 45));
        await pumpFor(const Duration(milliseconds: 100));
        expect(app.isAuthenticated, isTrue);
        expect(app.isPreviewMode, isFalse);
        expect(app.homeHealthCardOwner, owner);
        final target = app.rememberedDevice;
        expect(target, isNotNull);
        expect(target!.id.startsWith('qring:'), isTrue);
        await waitFor(
          () =>
              app.connectedDevice?.id == target.id &&
              app.deviceCapabilityState == DeviceCapabilityState.ready &&
              !app.isDeviceSyncing,
          'Existing owner-bound QRing handshake and initial sync',
        );
        checked('owned_qring_ready');
        Future<Map<String, Object?>> activity() async => {
          for (final metric in [
            HealthMetric.steps,
            HealthMetric.distance,
            HealthMetric.calories,
          ])
            metric.wireName: (await app.loadHealthRecords(
              metric: metric,
              start: day,
              end: DateTime(now.year, now.month, now.day + 1),
            )).map((r) => r.toJson()).toList(),
        };
        observations['activityBeforeSync'] = await activity();
        final complete = await app.syncDeviceData().timeout(
          const Duration(minutes: 3),
        );
        observations['syncConfirmed'] = complete;
        observations['syncStatus'] = app.syncStatus;
        observations['syncError'] = app.errorMessage;
        expect(app.session?.accountKey, session.accountKey);
        expect(app.connectedDevice?.id, target.id);
        observations['activityAfterSync'] = await activity();
        checked(
          complete ? 'activity_sync_confirmed' : 'activity_sync_incomplete',
        );
        app.selectTab(0);
        await pumpFor(const Duration(seconds: 2));
        expect(find.byKey(const Key('dashboard-today-health')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final todayCalories = await app.loadHealthRecords(
          metric: HealthMetric.calories,
          start: DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
          end: DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day + 1,
          ),
        );
        if (todayCalories.any(hasUnconfirmedCalorieUnit)) {
          expect(find.text('单位待确认'), findsWidgets);
          checked('home_unverified_calorie_unit_guard');
        } else {
          checked('home_no_unverified_current_day_calorie_sample');
        }
        await binding.takeScreenshot('activity-sleep-home');
        final sleep = await app.loadSleepDays(
          start: day.subtract(const Duration(days: 7)),
          end: day,
        );
        observations['sleepDays'] = sleep.map((r) => r.toJson()).toList();
        final latest = await app.loadLatestSleepDay();
        observations['latestSleep'] = latest?.toJson();
        for (final record in sleep) {
          expect(record.deviceId, target.id);
          final timeline = record.sleepTimeline;
          if (timeline != null) {
            expect(record.values, timeline.summaryValues);
            for (final session in timeline.sessions) {
              if (session.hasSegments) {
                expect(session.endedAt!.isAfter(session.startedAt!), isTrue);
              }
            }
          }
        }
        final entry = find.byKey(const Key('home-sleep-overview-entry'));
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await pumpFor(const Duration(seconds: 2));
        expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('activity-sleep-details');
        checked('saved_sleep_and_timeline_consistent');
        final previous = find.byKey(const Key('sleep-previous-day'));
        await tester.tap(previous);
        await pumpFor(const Duration(seconds: 1));
        await tester.tap(find.byKey(const Key('sleep-latest-day')));
        await pumpFor(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        checked('sleep_date_navigation');
        expect(
          complete,
          isTrue,
          reason: 'SDK must confirm complete history, not only early activity',
        );
      } finally {
        observations['finalSyncStatus'] = controller?.syncStatus;
        observations['finalSyncError'] = controller?.errorMessage;
        observations['finalSyncBusy'] = controller?.isDeviceSyncing;
        final document = await getApplicationDocumentsDirectory();
        await File(
          path.join(document.path, 'activity-sleep-validation-private.json'),
        ).writeAsString(
          jsonEncode({'checks': checks, ...observations}),
          flush: true,
        );
        binding.reportData = {...?binding.reportData, 'checks': checks};
        controller?.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
