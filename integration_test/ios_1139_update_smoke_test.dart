import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/global_code_login_page.dart';

import 'ios_profile_api_diagnostic_test.dart' as profile;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('1139 public phone and email password/code UI', (tester) async {
    final app = AppController.production();
    addTearDown(app.dispose);
    runApp(SaydianApp(controller: app));
    await app.initialize().timeout(const Duration(seconds: 60));
    final owner = app.session?.accountKey;
    final target = app.rememberedDevice?.id;
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final pushed = find
        .byKey(const Key('global-code-login-page'))
        .evaluate()
        .isEmpty;
    if (pushed) {
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => GlobalCodeLoginPage(controller: app),
            ),
          );
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }
    final page = find.byKey(const Key('global-code-login-page'));
    final l = AppLocalizations.of(tester.element(page))!;
    final capabilities = await app.globalAuthCapabilities();
    expect(capabilities.consentVersion, isNotEmpty);
    expect(
      capabilities.legal.keys,
      containsAll(['userAgreement', 'privacyPolicy']),
    );
    expect(find.byKey(const Key('code-login-password')), findsOneWidget);
    expect(find.byKey(const Key('code-login-code')), findsNothing);
    final email = find.widgetWithText(ChoiceChip, l.email);
    await tester.ensureVisible(email);
    await tester.tap(email);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('code-login-contact')))
          .keyboardType,
      TextInputType.emailAddress,
    );
    expect(find.byKey(const Key('code-login-password')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('code-login-mode')));
    await tester.tap(find.byKey(const Key('code-login-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('code-login-code')), findsOneWidget);
    expect(find.byKey(const Key('code-login-send')), findsOneWidget);
    await tester.tap(find.byKey(const Key('code-login-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('code-login-password')), findsOneWidget);
    await binding.takeScreenshot('ios-1139-public-email-password');
    expect(app.session?.accountKey, owner);
    expect(app.rememberedDevice?.id, target);
    expect(tester.takeException(), isNull);
    binding.reportData = {...?binding.reportData, 'publicLoginUi': true};
    if (pushed) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    '1139 existing target recovery and real complete sync',
    (tester) async {
      final app = AppController.production();
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      final owner = app.session?.accountKey;
      final target = app.rememberedDevice;
      expect(
        target,
        isNotNull,
        reason: 'Never select a new ring or reset an existing binding',
      );
      app.selectTab(1);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      if (app.connectedDevice?.id != target!.id) {
        await app.reconnectDevice().timeout(const Duration(seconds: 60));
      }
      for (var i = 0; i < 180 && app.connectedDevice?.id != target.id; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
      }
      if (app.connectedDevice?.id != target.id) {
        await app.scanDevices().timeout(const Duration(seconds: 45));
        final probe = {
          'count': app.scannedDevices.length,
          'savedTargetAdvertised': app.scannedDevices.any(
            (d) => d.id.toUpperCase() == target.id.toUpperCase(),
          ),
          'issue': app.deviceScanIssue?.name,
          'error': app.errorMessage != null,
        };
        binding.reportData = {...?binding.reportData, 'connectionProbe': probe};
        // Counts and status only, no account, device identifiers or health values.
        // ignore: avoid_print
        print('1139 connection probe: $probe');
        await app.stopDeviceScan();
      }
      await binding.takeScreenshot('ios-1139-existing-ring');
      expect(app.session?.accountKey, owner);
      expect(app.rememberedDevice?.id, target.id);
      expect(app.connectedDevice?.id, target.id);
      expect(app.capabilities?.supportsHistorySync, isTrue);
      for (var i = 0; i < 180 && app.isDeviceSyncing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
      }
      expect(app.isDeviceSyncing, isFalse);
      expect(
        await app.syncDeviceData().timeout(const Duration(minutes: 3)),
        isTrue,
      );
      expect(app.session?.accountKey, owner);
      expect(app.rememberedDevice?.id, target.id);
      expect(app.errorMessage, isNull);
      binding.reportData = {...?binding.reportData, 'completeRealSync': true};
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
  profile.main();
}
