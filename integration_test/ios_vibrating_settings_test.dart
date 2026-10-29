import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/health_reminder_center.dart';
import 'package:saydian_app/ui/prototype_pages.dart';

// Authenticated owner's existing R7 Ultra only. No rebinding, login or
// synthetic device state. Run with the preserving wrapper; restore main.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'owned R7 Ultra actual reminder and frequency roundtrips',
    (tester) async {
      final app = AppController.production();
      final report = <String, Object?>{};
      final checks = <String>[];
      Future<void> checked(String name) async {
        checks.add(name);
        final dir = await getApplicationDocumentsDirectory();
        await File(
          '${dir.path}/r7-settings-private.json',
        ).writeAsString(jsonEncode({'checks': checks, ...report}), flush: true);
        debugPrint('R7 SETTINGS: $name');
      }

      try {
        runApp(SaydianApp(controller: app));
        await app.initialize().timeout(const Duration(seconds: 45));
        expect(app.isAuthenticated, true);
        expect(app.isPreviewMode, false);
        final owner = app.session!.accountKey;
        final target = app.rememberedDevice!;
        expect(target.id, startsWith('coolwear:'));
        expect(
          target.name.toUpperCase().replaceAll(RegExp(r'[\s_-]+'), ''),
          contains('R7ULTRA'),
        );
        void sameTarget() {
          expect(app.session?.accountKey, owner);
          expect(app.connectedDevice?.id, target.id);
        }

        for (
          var i = 0;
          i < 100 &&
              (app.connectedDevice?.id != target.id ||
                  app.isDeviceSyncing ||
                  !app.availabilityFor(DeviceFeature.callReminder).isReady);
          i++
        ) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        sameTarget();
        for (final feature in [
          DeviceFeature.callReminder,
          DeviceFeature.notifications,
          DeviceFeature.healthMonitoring,
        ]) {
          expect(
            app.availabilityFor(feature).isReady,
            true,
            reason: feature.name,
          );
        }
        report['features'] = app.visibleDeviceFeatures
            .map((e) => e.wireName)
            .toList();
        await checked('exact_owner_target_and_real_capabilities');
        final call = await app.readDeviceFeature(DeviceFeature.callReminder);
        report['callOriginal'] = call;
        report['callReadStatus'] = app.errorMessage;
        expect(call['incomingCall'], isA<bool>());
        try {
          expect(
            await app.writeDeviceFeature(DeviceFeature.callReminder, {
              'incomingCall': call['incomingCall'] != true,
            }),
            true,
            reason: app.errorMessage,
          );
          final changed = await app.readDeviceFeature(
            DeviceFeature.callReminder,
          );
          expect(changed['incomingCall'], call['incomingCall'] != true);
          await checked('call_fresh_readback_changed');
        } finally {
          sameTarget();
          expect(
            await app.writeDeviceFeature(DeviceFeature.callReminder, {
              'incomingCall': call['incomingCall'],
            }),
            true,
            reason: app.errorMessage,
          );
          final restored = await app.readDeviceFeature(
            DeviceFeature.callReminder,
          );
          expect(restored['incomingCall'], call['incomingCall']);
          report['callRestored'] = restored;
          await checked('call_original_restored');
        }
        final messages = await app.readDeviceFeature(
          DeviceFeature.notifications,
        );
        report['messages'] = messages;
        expect(messages['reminderStyle'], anyOf('connection', 'device'));
        // Preserve the unknown original switch. The UI exposes explicit choices.
        await checked('message_support_and_actual_or_unknown_state');
        if (app.availabilityFor(DeviceFeature.healthReminders).isReady) {
          final original = await app.readDeviceFeature(
            DeviceFeature.healthReminders,
          );
          report['healthReminderOriginal'] = original;
          final rows = (original['items']! as List).cast<Map>();
          expect(rows, isNotEmpty);
          Future<void> settle() async {
            await Future<void>.delayed(const Duration(milliseconds: 400));
            await tester.pump().timeout(const Duration(seconds: 15));
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

          app.selectTab(0);
          await settle();
          await tapVisible(find.byKey(const Key('health-reminder-entry')));
          expect(find.byType(HealthReminderCenterPage), findsOneWidget);
          await tapVisible(find.byKey(const Key('health-reminder-sedentary')));
          expect(
            tester
                .widget<DeviceFeaturePage>(find.byType(DeviceFeaturePage))
                .reminderView,
            RingReminderView.sedentary,
          );
          final sitting = find.byKey(const Key('ring-reminder-item-sedentary'));
          for (var i = 0; i < 80 && sitting.evaluate().isEmpty; i++) {
            await settle();
          }
          expect(
            sitting,
            findsOneWidget,
            reason: 'R7 Ultra must return real sedentary settings',
          );
          expect(
            find.byKey(const Key('ring-reminder-item-drinking')),
            findsNothing,
          );
          await tester.tap(sitting);
          await settle();
          expect(find.byKey(const Key('ring-reminder-editor')), findsOneWidget);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          await settle();
          await binding.takeScreenshot('15pm-sedentary-editor-large-private');
          expect(tester.takeException(), isNull);
          await tester.binding.handlePopRoute();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await settle();
          await tester.binding.handlePopRoute();
          await settle();
          await tester.binding.handlePopRoute();
          await settle();
          await checked(
            'home_sedentary_entry_filters_and_large_editor_cancelled_without_write',
          );
          for (final item in rows) {
            expect(item['enabled'], isA<bool>());
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
              expect(changed, {...item, 'enabled': item['enabled'] != true});
              await checked('status_${item['id']}_exact_schedule_readback');
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
        await app.refreshDeviceSettings();
        final originalSwitches = Map<String, bool>.from(
          app.autoMeasureSettings,
        );
        final originalIntervals = Map.of(app.autoMeasureIntervals);
        expect(originalIntervals, isNotEmpty, reason: app.deviceSettingsStatus);
        report['monitoringOriginal'] = originalSwitches;
        report['intervalsOriginal'] = {
          for (final e in originalIntervals.entries) e.key: e.value.minutes,
        };
        final type = originalIntervals.keys.first;
        final original = originalIntervals[type]!;
        try {
          final next = original.choices.firstWhere(
            (n) => n != original.minutes,
          );
          await app.setAutoMeasureInterval(type, next);
          await app.refreshDeviceSettings();
          expect(
            app.autoMeasureIntervals[type]?.minutes,
            next,
            reason: app.errorMessage,
          );
          expect(app.autoMeasureSettings, originalSwitches);
          await checked('shared_interval_changed_and_freshly_read');
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
          await checked('interval_and_all_switches_restored');
        }
        if (app.availabilityFor(DeviceFeature.gestureControl).isReady) {
          report['gesture'] = await app.readDeviceFeature(
            DeviceFeature.gestureControl,
          );
          await checked('gesture_read_only_no_unknown_mode_write');
        }
        expect(app.errorMessage, isNull);
        expect(app.isDeviceSyncing, false);
        await checked('settings_acceptance_complete');
      } finally {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        report['lifecycleAtEnd'] = binding.lifecycleState?.name;
        await checked('finished_preserving_owner_and_data');
        app.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
