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

// Existing authenticated owner's HR05 only. Back up privately before driving;
// restore normal main afterward, without uninstalling. No credentials in logs.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'owned HR05 pages and reminder readback restoration',
    (tester) async {
      final app = AppController.production();
      final report = <String, Object?>{};
      final checks = <String>[];
      Future<void> save() async {
        final dir = await getApplicationDocumentsDirectory();
        await File(
          '${dir.path}/hr05-acceptance-private.json',
        ).writeAsString(jsonEncode({'checks': checks, ...report}), flush: true);
      }

      Future<void> checked(String name) async {
        checks.add(name);
        debugPrint('HR05 ACCEPTANCE: $name');
        await save();
      }

      Future<void> pump([int seconds = 1]) => tester
          .pump(Duration(seconds: seconds))
          .timeout(const Duration(seconds: 15));
      try {
        runApp(SaydianApp(controller: app));
        await app.initialize().timeout(const Duration(seconds: 45));
        await pump();
        expect(app.isAuthenticated, true);
        expect(app.isPreviewMode, false);
        final owner = app.session!.accountKey;
        final target = app.rememberedDevice!;
        expect(target.name.toUpperCase(), contains('HR05'));
        expect(target.id, startsWith('coolwear:'));
        void sameTarget() {
          expect(app.session?.accountKey, owner);
          expect(app.connectedDevice?.id, target.id);
        }

        app.selectTab(0);
        await pump(2);
        expect(find.byKey(const Key('dashboard-today-health')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await checked('authenticated_home');
        await binding.takeScreenshot('hr05-home');
        final sleepEntry = find.byKey(const Key('home-sleep-overview-entry'));
        await tester.scrollUntilVisible(
          sleepEntry,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(sleepEntry);
        await pump(2);
        expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('hr05-sleep');
        final previous = find.byKey(const Key('sleep-previous-day'));
        if (previous.evaluate().isNotEmpty) {
          await tester.tap(previous);
          await pump();
          await tester.tap(find.byKey(const Key('sleep-latest-day')));
          await pump();
        }
        expect(tester.takeException(), isNull);
        await checked('sleep_page_date_navigation');
        await tester.binding.handlePopRoute();
        await pump();
        app.selectTab(2);
        await pump();
        expect(find.byKey(const Key('my-page')), findsOneWidget);
        await checked('my_page');
        app.selectTab(1);
        await pump();
        expect(find.byKey(const Key('device-page')), findsOneWidget);
        await checked('device_page');
        for (
          var i = 0;
          i < 100 &&
              (app.connectedDevice?.id != target.id ||
                  app.deviceCapabilityState != DeviceCapabilityState.ready ||
                  app.isDeviceSyncing);
          i++
        ) {
          await pump();
        }
        sameTarget();
        expect(app.deviceCapabilityState, DeviceCapabilityState.ready);
        expect(app.isDeviceSyncing, false);
        report['features'] = app.visibleDeviceFeatures
            .map((e) => e.name)
            .toList();
        report['syncStatus'] = app.syncStatus;
        await checked('owned_luckring_handshake_idle');
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day);
        report['activity'] = {
          for (final metric in [
            HealthMetric.steps,
            HealthMetric.distance,
            HealthMetric.calories,
          ])
            metric.name: (await app.loadHealthRecords(
              metric: metric,
              start: day.subtract(const Duration(days: 7)),
              end: day.add(const Duration(days: 1)),
            )).map((r) => r.toJson()).toList(),
        };
        final sleep = await app.loadSleepDays(
          start: day.subtract(const Duration(days: 7)),
          end: day,
        );
        for (final record in sleep) {
          if (record.sleepTimeline != null) {
            expect(record.values, record.sleepTimeline!.summaryValues);
          }
        }
        report['sleep'] = sleep.map((r) => r.toJson()).toList();
        await checked('real_saved_activity_sleep_snapshot');
        // Discovery uses read-only, bounded SDK requests before exposing controls.
        for (var i = 0; i < 24; i++) {
          await pump();
        }
        report['featuresAfterProbes'] = app.visibleDeviceFeatures
            .map((e) => e.name)
            .toList();
        expect(
          app.availabilityFor(DeviceFeature.callReminder).isReady,
          true,
          reason: 'Actual HR05 SDK must advertise reminder support',
        );
        final original = await app.readDeviceFeature(
          DeviceFeature.callReminder,
        );
        report['reminderOriginal'] = original;
        expect(original['incomingCall'], isA<bool>(), reason: app.errorMessage);
        await checked('reminder_original_read');
        try {
          sameTarget();
          final changed = !(original['incomingCall']! as bool);
          expect(
            await app.writeDeviceFeature(DeviceFeature.callReminder, {
              'incomingCall': changed,
            }),
            true,
            reason: app.errorMessage,
          );
          final readback = await app.readDeviceFeature(
            DeviceFeature.callReminder,
          );
          report['reminderChanged'] = readback;
          expect(readback['incomingCall'], changed, reason: app.errorMessage);
          await checked('reminder_write_fresh_readback');
        } finally {
          sameTarget();
          final restored = await app.writeDeviceFeature(
            DeviceFeature.callReminder,
            {'incomingCall': original['incomingCall']},
          );
          report['restoreWriteAccepted'] = restored;
          final readback = await app.readDeviceFeature(
            DeviceFeature.callReminder,
          );
          report['reminderRestored'] = readback;
          await save();
          expect(restored, true, reason: app.errorMessage);
          expect(
            readback['incomingCall'],
            original['incomingCall'],
            reason: app.errorMessage,
          );
          await checked('reminder_original_restored_readback');
        }
        final messages = await app.readDeviceFeature(
          DeviceFeature.notifications,
        );
        report['messageSettings'] = messages;
        expect(messages['reminderStyle'], anyOf('device', 'connection'));
        await checked('message_actual_state_or_explicit_unknown');
        // Unknown original message state cannot safely be toggled and restored.
        if (const bool.fromEnvironment('SAYRING_QA_ENABLE_MESSAGES')) {
          sameTarget();
          expect(
            await app.writeDeviceFeature(DeviceFeature.notifications, {
              'enabled': true,
              if (messages['snapshotRevision'] != null)
                'snapshotRevision': messages['snapshotRevision'],
            }),
            true,
            reason: app.errorMessage,
          );
          final actual = await app.readDeviceFeature(
            DeviceFeature.notifications,
          );
          report['messageEnabledByUserRequest'] = actual;
          expect(actual['enabled'], true, reason: app.errorMessage);
          await checked('message_enabled_and_retained_by_user_request');
        } else if (messages['enabled'] is bool) {
          try {
            expect(
              await app.writeDeviceFeature(DeviceFeature.notifications, {
                'enabled': messages['enabled'] != true,
                if (messages['snapshotRevision'] != null)
                  'snapshotRevision': messages['snapshotRevision'],
              }),
              true,
              reason: app.errorMessage,
            );
            final actual = await app.readDeviceFeature(
              DeviceFeature.notifications,
            );
            expect(actual['enabled'], messages['enabled'] != true);
            await checked('message_write_confirmation');
          } finally {
            sameTarget();
            final current = await app.readDeviceFeature(
              DeviceFeature.notifications,
            );
            expect(
              await app.writeDeviceFeature(DeviceFeature.notifications, {
                'enabled': messages['enabled'],
                if (current['snapshotRevision'] != null)
                  'snapshotRevision': current['snapshotRevision'],
              }),
              true,
              reason: app.errorMessage,
            );
            final restored = await app.readDeviceFeature(
              DeviceFeature.notifications,
            );
            expect(restored['enabled'], messages['enabled']);
            await checked('message_original_restored');
          }
        } else {
          report['messageWriteSkipped'] =
              'Original state unknown; read-only UI verification';
        }
        if (app.availabilityFor(DeviceFeature.healthReminders).isReady) {
          var original = await app.readDeviceFeature(
            DeviceFeature.healthReminders,
          );
          if (const bool.fromEnvironment('SAYRING_QA_RESTORE_SEDENTARY_ZERO')) {
            // Explicit one-time recovery for the prior SDK serialization failure.
            // Require that the entire fresh schedule still matches that test.
            final rows = (original['items']! as List).cast<Map>();
            final row = rows.singleWhere((r) => r['id'] == 'sedentary');
            expect(row['enabled'], false);
            expect(row['startMinutes'], 480);
            expect(row['endMinutes'], 1200);
            expect(row['noonOff'], 1);
            expect(row['repeatMask'], anyOf(0, 128));
            if (row['repeatMask'] == 128) {
              expect(
                await app.writeDeviceFeature(DeviceFeature.healthReminders, {
                  ...row.cast<String, Object?>(),
                  'repeatMask': 0,
                  'snapshotRevision': original['snapshotRevision'],
                }),
                true,
                reason: app.errorMessage,
              );
              original = await app.readDeviceFeature(
                DeviceFeature.healthReminders,
              );
              expect(
                (original['items']! as List).cast<Map>().singleWhere(
                  (r) => r['id'] == 'sedentary',
                )['repeatMask'],
                0,
              );
            }
            await checked('prior_sdk_repeat_zero_restored');
          }
          report['statusReminderOriginal'] = original;
          final items = (original['items']! as List).cast<Map>();
          for (final item in items) {
            try {
              final before = await app.readDeviceFeature(
                DeviceFeature.healthReminders,
              );
              expect(
                await app.writeDeviceFeature(DeviceFeature.healthReminders, {
                  ...item.cast<String, Object?>(),
                  'enabled': item['enabled'] != true,
                  'snapshotRevision': before['snapshotRevision'],
                }),
                true,
                reason: app.errorMessage,
              );
              final actual = await app.readDeviceFeature(
                DeviceFeature.healthReminders,
              );
              final changed = (actual['items']! as List)
                  .cast<Map>()
                  .singleWhere((r) => r['id'] == item['id']);
              expect(changed['enabled'], item['enabled'] != true);
              await checked('status_${item['id']}_write_readback');
            } finally {
              sameTarget();
              final before = await app.readDeviceFeature(
                DeviceFeature.healthReminders,
              );
              expect(
                await app.writeDeviceFeature(DeviceFeature.healthReminders, {
                  ...item.cast<String, Object?>(),
                  'snapshotRevision': before['snapshotRevision'],
                }),
                true,
                reason: app.errorMessage,
              );
              final actual = await app.readDeviceFeature(
                DeviceFeature.healthReminders,
              );
              expect(
                (actual['items']! as List).cast<Map>().singleWhere(
                  (r) => r['id'] == item['id'],
                ),
                item,
              );
              await checked('status_${item['id']}_original_restored');
            }
          }
        }
        if (app.availabilityFor(DeviceFeature.alarms).isReady) {
          final alarms = await app.readDeviceFeature(DeviceFeature.alarms);
          report['alarmsOriginal'] = alarms;
          // Preserve nonempty schedules without replacing the entire list.
          if ((alarms['items']! as List).isEmpty) {
            try {
              expect(
                await app.writeDeviceFeature(DeviceFeature.alarms, {
                  'operation': 'add',
                  'hour': 12,
                  'minute': 30,
                  'enabled': false,
                  'label': '',
                  'repeatDays': <int>[],
                  'snapshotRevision': alarms['snapshotRevision'],
                }),
                true,
                reason: app.errorMessage,
              );
              final actual = await app.readDeviceFeature(DeviceFeature.alarms);
              expect((actual['items']! as List).single['enabled'], false);
              await checked('disabled_alarm_add_readback');
            } finally {
              sameTarget();
              final before = await app.readDeviceFeature(DeviceFeature.alarms);
              final items = before['items']! as List;
              if (items.isNotEmpty) {
                expect(items.length, 1);
                expect(items.single['enabled'], false);
                expect(
                  await app.writeDeviceFeature(DeviceFeature.alarms, {
                    'operation': 'delete',
                    'id': items.single['id'],
                    'snapshotRevision': before['snapshotRevision'],
                  }),
                  true,
                  reason: app.errorMessage,
                );
              }
              final actual = await app.readDeviceFeature(DeviceFeature.alarms);
              expect(actual['items'], isEmpty);
              await checked('original_empty_alarm_list_restored');
            }
          }
        }
        await app.refreshDeviceSettings();
        report['monitoringOriginal'] = app.autoMeasureSettings;
        report['intervalsOriginal'] = {
          for (final e in app.autoMeasureIntervals.entries)
            e.key: e.value.minutes,
        };
        expect(
          app.autoMeasureIntervals,
          isNotEmpty,
          reason: app.deviceSettingsStatus,
        );
        final type = app.autoMeasureIntervals.keys.firstWhere(
          (key) => app.autoMeasureSettings[key] == true,
          orElse: () => '',
        );
        if (type.isNotEmpty) {
          final original = app.autoMeasureIntervals[type]!;
          final originalSwitches = Map<String, bool>.from(
            app.autoMeasureSettings,
          );
          try {
            final change = original.choices.firstWhere(
              (m) => m != original.minutes,
            );
            await app.setAutoMeasureInterval(type, change);
            expect(
              app.autoMeasureIntervals[type]?.minutes,
              change,
              reason: app.errorMessage,
            );
            await app.refreshDeviceSettings();
            expect(app.autoMeasureSettings, originalSwitches);
            await checked('shared_monitoring_frequency_fresh_readback');
          } finally {
            sameTarget();
            await app.setAutoMeasureInterval(type, original.minutes);
            await app.refreshDeviceSettings();
            expect(
              app.autoMeasureIntervals[type]?.minutes,
              original.minutes,
              reason: app.errorMessage,
            );
            expect(app.autoMeasureSettings, originalSwitches);
            await checked('monitoring_frequency_and_switches_restored');
          }
        }
        final entry = find.byKey(
          const ValueKey('device-feature-call_reminder'),
        );
        await tester.scrollUntilVisible(
          entry,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(entry);
        await pump(2);
        for (
          var i = 0;
          i < 35 && app.deviceFeatureBusy.contains(DeviceFeature.callReminder);
          i++
        ) {
          await pump();
        }
        expect(find.text('在戒指提醒手机来电'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('hr05-reminder-restored');
        await checked('reminder_settings_ui');
      } finally {
        report['syncBusyAtEnd'] = app.isDeviceSyncing;
        report['errorAtEnd'] = app.errorMessage;
        await save();
        binding.reportData = {...?binding.reportData, 'checks': checks};
        app.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
