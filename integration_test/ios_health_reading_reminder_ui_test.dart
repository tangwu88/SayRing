import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/reading_reminder.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/health_reminder_center.dart';

/// Existing account only. Exercise configuration and labelled preview without
/// fabricating a health reading, event, notification or sensor command.
void main() {
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
        expect(app.canSaveHealthReminder, isTrue);
        originalSettings = app.readingReminderSettings;
        originalEvents = app.healthReminderEvents.map((e) => e.id).toSet();
        app.selectTab(0);
        await settle();
        await tapVisible(find.byKey(const Key('health-reminder-entry')));
        expect(find.byType(HealthReminderCenterPage), findsOneWidget);
        await binding.takeScreenshot('xr-reading-settings-private');
        proof['threeNumericCards'] = true;
        for (final kind in [
          'high_heart_rate',
          'low_heart_rate',
          'low_blood_oxygen',
        ]) {
          final toggle = find.byKey(Key('reading-reminder-$kind-enabled'));
          await tapVisible(toggle);
          final enabled = tester.widget<Switch>(toggle).value;
          expect(app.homeHealthCardOwner, owner);
          expect(app.rememberedDevice?.id, target);
          await tapVisible(toggle);
          expect(tester.widget<Switch>(toggle).value, !enabled);
        }
        proof['threeSwitchesSaveAndRestore'] = true;
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await settle();
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
        for (final scale in [1.0, 2.0]) {
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
          expect(
            app.healthReminderEvents.map((e) => e.id).toSet(),
            originalEvents,
          );
          await binding.takeScreenshot(
            'xr-reading-red-preview-scale-${scale.toInt()}-private',
          );
          final close = find.byKey(const Key('dismiss-health-warning'));
          await tester.ensureVisible(close);
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
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
