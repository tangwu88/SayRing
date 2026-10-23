import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';

// Existing owner-bound R21 only. No new binding/reset or explicit setting changes.
// Back up privately; drive the verified Profile binary with the preserving tool.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'owned R21 history capability and real sync',
    (tester) async {
      final app = AppController.production();
      final checks = <String>[];
      void checked(String label) {
        checks.add(label);
        debugPrint('R21 HISTORY: $label');
      }

      Future<void> waitFor(bool Function() ready, String reason) async {
        for (var i = 0; i < 300 && !ready(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await tester.pump();
        }
        expect(ready(), isTrue, reason: reason);
      }

      try {
        runApp(SaydianApp(controller: app));
        await waitFor(
          () => binding.lifecycleState == AppLifecycleState.resumed,
          '需要手机解锁并保持前台',
        );
        await app.initialize().timeout(const Duration(seconds: 45));
        expect(app.isAuthenticated, isTrue);
        final owner = app.session!.accountKey;
        final target = app.rememberedDevice!;
        expect(target.id.startsWith('qring:'), isTrue);
        expect(target.name.toUpperCase().startsWith('R21'), isTrue);
        checked('existing_R21_binding_preserved');
        await waitFor(
          () =>
              app.connectedDevice?.id == target.id && app.capabilities != null,
          '等待原绑定R21真实握手，不选择其它戒指',
        );

        final native = await const MethodChannel(
          'cc.saidian.ring/qring/commands',
        ).invokeMapMethod<String, Object?>('getCapabilities');
        expect(native?['resolved'], isTrue);
        expect(native?['supportsHistorySync'], isA<bool>());
        expect(native?['supportsHistorySync'], isTrue);
        expect(app.capabilities!.supportsHistorySync, isTrue);
        checked('native_codec_Boolean_and_Dart_capability_ready');
        await waitFor(() => !app.isDeviceSyncing, '等待本次自动历史读取结束');
        app.selectTab(1);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        final button = find.byKey(const Key('device-sync-data'));
        await tester.ensureVisible(button);
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(find.text('同步数据'), findsOneWidget);
        expect(find.text('此戒指历史同步暂未开放'), findsNothing);
        checked('device_sync_button_enabled');
        await binding.takeScreenshot('r21-history-sync-enabled');

        final complete = await app.syncDeviceData().timeout(
          const Duration(minutes: 3),
        );
        expect(app.session?.accountKey, owner);
        expect(app.rememberedDevice?.id, target.id);
        expect(app.connectedDevice?.id, target.id);
        expect(app.isDeviceSyncing, isFalse);
        expect(complete, isTrue, reason: '须有SDK完整历史回执，不能只凭按钮可点');
        expect(app.errorMessage, isNull);
        checked('real_history_sync_completed_for_same_owner_and_ring');
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await binding.takeScreenshot('r21-history-sync-completed');
        expect(tester.takeException(), isNull);
      } finally {
        binding.reportData = {...?binding.reportData, 'checks': checks};
        app.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
