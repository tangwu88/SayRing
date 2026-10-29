import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/health_reminder_center.dart';

import 'ios_read_only_page_walkthrough_test.dart' as walkthrough;
import 'ios_xr_r7pro_release_acceptance_test.dart' as sync;
import 'ios_xr_secondary_pages_test.dart' as secondary;
import 'ios_camera_lifecycle_acceptance_test.dart' as camera;

// The current XR already owns and connects to R7 Pro. Never reset, unbind,
// replace its owner, save fictitious symptoms or open an emergency dialler.
// Use the preserving Profile runner and restore the normal main afterward.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'XR health reminders with the existing real owner',
    (tester) async {
      final app = AppController.production();
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      final owner = app.session?.accountKey;
      final target = app.rememberedDevice?.id;
      final eventsBefore = app.healthReminderEvents.map((e) => e.id).toSet();
      expect(owner, isNotNull);
      expect(target, isNotNull);
      final visited = <String>[];
      Future<void> settle() async {
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await tester.pump().timeout(const Duration(seconds: 15));
        }
      }

      Future<void> record(String label) async {
        expect(tester.takeException(), isNull, reason: label);
        visited.add(label);
        binding.reportData = {
          ...?binding.reportData,
          'healthReminderPages': visited,
        };
        await binding.takeScreenshot('xr-health-${visited.length}');
        debugPrint('XR HEALTH: $label');
      }

      Future<void> tapVisible(Finder finder) async {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await settle();
        await tester.scrollUntilVisible(
          finder,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
        await settle();
        await tester.tap(finder.hitTestable());
        await settle();
      }

      app.selectTab(0);
      await settle();
      await tapVisible(find.byKey(const Key('health-reminder-entry')));
      expect(find.byType(HealthReminderCenterPage), findsOneWidget);
      expect(
        find.byKey(const Key('health-reminder-availability')),
        findsOneWidget,
      );
      await app.refreshHealthReminderPermissions();
      await settle();
      expect(app.automaticHealthRemindersAvailable, isFalse);
      await record('提醒中心与真实通知权限状态');

      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await settle();
      await record('提醒中心放大文字');
      await tapVisible(find.byKey(const Key('health-reminder-urgent-help')));
      expect(find.byType(EmergencyHelpPage), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('emergency-dial')))
            .onPressed,
        isNull,
      );
      await record('急症求助未选地区时不拨号');
      await tester.binding.handlePopRoute();
      await settle();

      await tapVisible(
        find.byKey(const Key('health-reminder-record-symptoms')),
      );
      expect(find.byType(HealthReminderSymptomsPage), findsOneWidget);
      final save = find.byKey(const Key('health-reminder-save-symptoms'));
      await tester.scrollUntilVisible(
        save,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      final symptom = find.byKey(
        const Key('health-reminder-symptom-chest_discomfort'),
      );
      await tapVisible(symptom);
      await tester.scrollUntilVisible(
        save,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await record('症状草稿与空选择校验（不保存）');
      await tester.binding.handlePopRoute();
      await settle();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.handlePopRoute();
      await settle();
      expect(app.session?.accountKey, owner);
      expect(app.rememberedDevice?.id, target);
      expect(app.healthReminderEvents.map((e) => e.id).toSet(), eventsBefore);
      // Complete this controller's automatic read before the next case owns
      // the same native singleton. Disposing is not a sync-completion signal.
      for (var i = 0; i < 180 && app.isDeviceSyncing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump().timeout(const Duration(seconds: 15));
      }
      expect(app.isDeviceSyncing, isFalse);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  sync.main();
  camera.main();
  walkthrough.main();
  secondary.main();
}
