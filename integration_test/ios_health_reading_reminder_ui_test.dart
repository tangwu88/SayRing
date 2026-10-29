import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/reading_reminder.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/health_reminder_center.dart';

/// Existing account only. Exercise configuration and labelled preview without
/// fabricating a health reading, event, notification or sensor command.
void main() => registerReadingReminderUiAcceptance();

void registerReadingReminderUiAcceptance({
  String requiredModel = '',
  bool requireVibration = true,
}) {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'XR numeric reminders and labelled full red preview preserve data',
    (tester) async {
      final app = AppController.production();
      final proof = <String, Object?>{};
      String? owner;
      String? target;
      ReadingReminderSettings? originalSettings;
      Set<String>? originalEvents;
      Future<void> settle() async {
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await tester.pump().timeout(const Duration(seconds: 15));
        }
      }

      Future<void> tapVisible(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
        await settle();
        await tester.tap(finder.hitTestable());
        await settle();
      }

      try {
        runApp(SaydianApp(controller: app));
        await app.initialize().timeout(const Duration(seconds: 60));
        owner = app.homeHealthCardOwner;
        target = app.rememberedDevice?.id;
        final model = (app.rememberedDevice?.name ?? '')
            .toUpperCase()
            .replaceAll(RegExp(r'[\s_-]+'), '');
        expect(
          requiredModel.isEmpty
              ? model.contains('R7PRO') || model.contains('HR05')
              : model.contains(requiredModel),
          isTrue,
          reason: 'Only the existing R7 Pro/HR05 target',
        );
        expect(app.canSaveHealthReminder, isTrue);
        originalSettings = app.readingReminderSettings;
        originalEvents = app.healthReminderEvents.map((e) => e.id).toSet();
        app.selectTab(0);
        await settle();
        await tapVisible(find.byKey(const Key('health-reminder-entry')));
        expect(find.byType(HealthReminderCenterPage), findsOneWidget);
        await binding.takeScreenshot('xr-reading-settings-private');
        bool supported(HealthMetric metric) =>
            app.capabilities?.manualMetrics?.contains(metric) == true &&
            app.canMeasureHealthMetric(metric);
        final visible = {
          'high_heart_rate': supported(HealthMetric.heartRate),
          'low_heart_rate': supported(HealthMetric.heartRate),
          'low_blood_oxygen': supported(HealthMetric.bloodOxygen),
        };
        proof['visibleReadingKinds'] = visible;
        for (final entry in visible.entries) {
          final kind = entry.key;
          final toggle = find.byKey(Key('reading-reminder-$kind-enabled'));
          if (!entry.value) {
            expect(toggle, findsNothing);
            continue;
          }
          await tapVisible(toggle);
          final enabled = tester.widget<Switch>(toggle).value;
          expect(app.homeHealthCardOwner, owner);
          expect(app.rememberedDevice?.id, target);
          await tapVisible(toggle);
          expect(tester.widget<Switch>(toggle).value, !enabled);
        }
        proof['numericCardsMatchCapabilities'] = true;
        proof['visibleSwitchesSaveAndRestore'] = true;
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await settle();
        if (visible['high_heart_rate'] == true) {
          await tapVisible(
            find.byKey(const Key('reading-reminder-high_heart_rate-limit')),
          );
          expect(
            find.byKey(const Key('reading-limit-editor-value')),
            findsOneWidget,
          );
          final before = app.readingReminderSettings.high;
          await tester.tap(find.byTooltip(before < 200 ? '提高阈值' : '降低阈值'));
          await settle();
          final save = find.byKey(const Key('reading-limit-save'));
          await tester.ensureVisible(save);
          await settle();
          await tester.tap(save.hitTestable());
          await settle();
          expect(
            app.readingReminderSettings.high,
            before < 200 ? before + 1 : before - 1,
          );
          proof['customThresholdSaved'] = true;
        }
        for (
          var i = 0;
          i < 90 &&
              (app.isDeviceSyncing ||
                  (requireVibration &&
                      !app.healthReminderRingVibrationAvailable));
          i++
        ) {
          await Future<void>.delayed(const Duration(seconds: 1));
          await tester.pump().timeout(const Duration(seconds: 15));
        }
        proof['ringVibrationAvailable'] =
            app.healthReminderRingVibrationAvailable;
        final vibrationSwitch = find.byKey(
          const Key('reading-reminder-ring-vibration'),
        );
        expect(
          vibrationSwitch,
          app.healthReminderRingVibrationAvailable
              ? findsOneWidget
              : findsNothing,
        );
        proof['vibrationSwitchMatchesCapability'] = true;
        for (
          var i = 0;
          i < 70 &&
              app.deviceFeatureBusy.contains(DeviceFeature.healthReminders);
          i++
        ) {
          await Future<void>.delayed(const Duration(seconds: 1));
          await tester.pump().timeout(const Duration(seconds: 15));
        }
        final raw =
            app.deviceFeatureData[DeviceFeature.healthReminders]?['items'];
        final rows = raw is List
            ? raw
                  .whereType<Map>()
                  .map((r) => r.map((k, v) => MapEntry('$k', v)))
                  .where(canDisplayRingReminder)
                  .toList()
            : const <Map<String, Object?>>[];
        final ready = app
            .availabilityFor(DeviceFeature.healthReminders)
            .isReady;
        final daily = {
          'health-reminder-sedentary':
              ready && rows.any((r) => r['id'] == 'sedentary'),
          'health-reminder-other-ring-settings':
              ready && rows.any((r) => r['id'] != 'sedentary'),
        };
        if (daily.values.any((value) => value)) {
          await tester.scrollUntilVisible(
            find.byKey(const Key('health-reminder-ring-settings')),
            160,
            scrollable: find.byType(Scrollable).first,
          );
          await settle();
        }
        for (final entry in daily.entries) {
          expect(
            find.byKey(Key(entry.key)),
            entry.value ? findsOneWidget : findsNothing,
          );
        }
        proof['dailyEntriesMatchActualSettings'] = daily;
        expect(app.connectedDevice?.id, target);
        if (requireVibration) {
          expect(app.healthReminderRingVibrationAvailable, isTrue);
        }
        final beforePulseEvents = app.healthReminderEvents
            .map((e) => e.id)
            .toSet();
        final inboxBeforePulse = app.notificationInboxEvents
            .map((e) => e.eventId)
            .toSet();
        final vibrationBeforePreview =
            app.readingReminderSettings.ringVibrationEnabled;
        final previewShouldVibrate =
            vibrationBeforePreview && app.healthReminderRingVibrationAvailable;
        proof['ringVibrationEnabledAtAttempt'] = vibrationBeforePreview;
        Map<String, Object?>? callBefore;
        if (app.availabilityFor(DeviceFeature.callReminder).isReady) {
          callBefore = await app.readDeviceFeature(DeviceFeature.callReminder);
        }
        var pulse = const RingReminderHapticResult();
        for (final scale in [1.0, 2.0]) {
          if (scale == 2) {
            // Only the first explicit preview requests a pulse. The large-text
            // visual check is muted even if the first action was unconfirmed.
            expect(
              await app.saveReadingReminderSettings(
                app.readingReminderSettings.copyWith(
                  ringVibrationEnabled: false,
                ),
                expectedOwner: owner,
              ),
              isTrue,
            );
          }
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await settle();
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await settle();
          await binding.takeScreenshot(
            'xr-reading-settings-scale-${scale.toInt()}-private',
          );
          await tapVisible(find.byKey(const Key('reading-reminder-preview')));
          expect(
            find.byKey(const Key('global-reading-reminder')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('reading-reminder-preview-label')),
            findsOneWidget,
          );
          expect(app.activeHealthWarningAlert, isNull);
          if (scale == 1 && previewShouldVibrate) {
            final status = find.byKey(
              const Key('reading-preview-vibration-status'),
            );
            expect(status, findsOneWidget);
            pulse = await tester
                .widget<FutureBuilder<RingReminderHapticResult>>(status)
                .future!
                .timeout(const Duration(seconds: 35));
            proof['pulseFromPreview'] = true;
          } else {
            expect(
              find.byKey(const Key('reading-preview-vibration-status')),
              findsNothing,
            );
          }
          expect(
            app.healthReminderEvents.map((e) => e.id).toSet(),
            originalEvents,
          );
          await binding.takeScreenshot(
            'xr-reading-red-preview-scale-${scale.toInt()}-private',
          );
          final close = find.byKey(const Key('reading-reminder-close'));
          expect(close.hitTestable(), findsOneWidget);
          await settle();
          await tester.tap(close.hitTestable());
          await settle();
          expect(
            find.byKey(const Key('global-reading-reminder')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
        proof['normalAndLargeTextPreviewClosed'] = true;
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await settle();
        expect(
          await app.saveReadingReminderSettings(
            app.readingReminderSettings.copyWith(
              ringVibrationEnabled: vibrationBeforePreview,
            ),
            expectedOwner: owner,
          ),
          isTrue,
        );
        proof['pulseDiagnostics'] = app.connectionDiagnostics.toList();
        proof['ringPulseAccepted'] = pulse.accepted;
        proof['ringPulseAcknowledged'] = pulse.acknowledged;
        if (callBefore?.containsKey('incomingCall') == true) {
          final after = await app.readDeviceFeature(DeviceFeature.callReminder);
          proof['incomingCallSettingPreserved'] =
              after['incomingCall'] == callBefore!['incomingCall'];
          expect(proof['incomingCallSettingPreserved'], isTrue);
        }
        expect(
          app.healthReminderEvents.map((e) => e.id).toSet(),
          beforePulseEvents,
        );
        expect(
          app.notificationInboxEvents.map((e) => e.eventId).toSet(),
          inboxBeforePulse,
        );
        debugPrint(
          'XR HEALTH: real R7 pulse accepted=${pulse.accepted} acknowledged=${pulse.acknowledged}',
        );
        final transitions = <String>[];
        void observeLink() {
          final state =
              '${app.deviceState.name}:${app.connectedDevice?.id == target}';
          if (transitions.isEmpty || transitions.last != state) {
            transitions.add(state);
          }
        }

        app.addListener(observeLink);
        observeLink();
        final diagnosticsBefore = app.connectionDiagnostics.length;
        final stable = Stopwatch()..start();
        try {
          for (var i = 0; i < 36; i++) {
            await Future<void>.delayed(const Duration(seconds: 5));
            await tester.pump().timeout(const Duration(seconds: 15));
            observeLink();
            if (i % 3 == 0) {
              await app.refreshConnectedDeviceDetails(quiet: true);
            }
            if (i % 12 == 11) {
              debugPrint('XR HEALTH: stationary link sampling ${i + 1}/36');
            }
          }
        } finally {
          app.removeListener(observeLink);
          proof['stationarySeconds'] = stable.elapsedMilliseconds / 1000;
          proof['stationaryStates'] = transitions;
          proof['connectionDiagnostics'] = app.connectionDiagnostics
              .skip(diagnosticsBefore)
              .toList();
        }
        proof['stationaryTargetStayedConnected'] = transitions.every(
          (s) => s.endsWith(':true'),
        );
        expect(
          proof['stationaryTargetStayedConnected'],
          isTrue,
          reason:
              'No intentional disconnection or reconnect in the stationary window',
        );
        debugPrint('XR HEALTH: stationary R7 connection window completed');
        if (previewShouldVibrate) {
          expect(pulse.accepted, isTrue);
          expect(pulse.acknowledged, isTrue);
        }
        proof['noFakeReadingOrEvents'] = app.healthReminderEvents
            .map((e) => e.id)
            .toSet()
            .difference(originalEvents)
            .isEmpty;
        debugPrint(
          'XR HEALTH: numeric controls and labelled preview completed',
        );
      } finally {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        if (originalSettings != null && owner == app.homeHealthCardOwner) {
          proof['originalSettingsRestored'] = await app
              .saveReadingReminderSettings(
                originalSettings,
                expectedOwner: owner!,
              );
        }
        proof['ownerUnchanged'] = owner == app.homeHealthCardOwner;
        proof['targetUnchanged'] = target == app.rememberedDevice?.id;
        if (originalEvents != null) {
          proof['eventIdsPreserved'] = app.healthReminderEvents
              .map((e) => e.id)
              .toSet()
              .containsAll(originalEvents);
        }
        binding.reportData = {
          ...?binding.reportData,
          'readingReminderUi': proof,
        };
        final documents = await getApplicationDocumentsDirectory();
        await File(
          '${documents.path}/reading-reminder-ui-private.json',
        ).writeAsString(jsonEncode(proof), flush: true);
        app.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 9)),
  );
}
