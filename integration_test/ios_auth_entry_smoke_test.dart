import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/global_code_login_page.dart';

/// Read-only production contract and native UI smoke. Never creates an account,
/// sends an OTP, replaces an existing session, or changes health records.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('iPhone public phone/email entries and published legal', (
    tester,
  ) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    runApp(SaydianApp(controller: controller));
    for (
      var i = 0;
      i < 90 && binding.lifecycleState != AppLifecycleState.resumed;
      i++
    ) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
    }
    expect(binding.lifecycleState, AppLifecycleState.resumed);
    await controller.initialize().timeout(const Duration(seconds: 60));
    final ownerBefore = controller.session?.accountKey;
    final capabilities = await controller.globalAuthCapabilities();
    expect(capabilities.consentVersion?.isNotEmpty, isTrue);
    expect(
      capabilities.legal.keys,
      containsAll(['userAgreement', 'privacyPolicy']),
    );
    expect(capabilities.email || capabilities.sms, isTrue);

    await tester.pumpWidget(SaydianApp(controller: controller));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // Inspect the real login page without signing an existing user out.
    if (find.byKey(const Key('global-code-login-page')).evaluate().isEmpty) {
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => GlobalCodeLoginPage(controller: controller),
            ),
          );
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    Future<void> reveal(Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).last,
      );
    }

    expect(find.byKey(const Key('code-login-submit')), findsOneWidget);
    expect(find.byKey(const Key('code-login-register')), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    final email = find.byKey(const Key('ios-email-password-entry'));
    await reveal(email);
    await tester.tap(email);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email-login-password')), findsOneWidget);
    expect(find.byKey(const Key('code-login-code')), findsNothing);
    expect(find.byKey(const Key('code-login-send')), findsNothing);

    for (final label in ['用户协议', '隐私政策']) {
      final link = find.widgetWithText(TextButton, label);
      await reveal(link);
      await tester.tap(link);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key('global-legal-page')), findsOneWidget);
      expect(find.byKey(const Key('global-legal-retry')), findsNothing);
      expect(find.textContaining(capabilities.consentVersion!), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    await reveal(find.byKey(const Key('code-login-minimum-age')));
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('code-login-minimum-age')),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('code-login-consent')))
          .value,
      isFalse,
    );
    expect(find.text('我确认已满14周岁'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('code-login-minimum-age'))).dy,
      tester.getCenter(find.byKey(const Key('code-login-consent'))).dy,
    );
    final submit = find.byKey(const Key('code-login-submit'));
    await reveal(submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await binding.takeScreenshot('sayring-ios-email-entry-1135');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('global-code-login-page')), findsOneWidget);
    expect(find.byKey(const Key('local-ring-use-entry')), findsOneWidget);
    expect(find.byKey(const Key('global-wechat-login')), findsNothing);
    await binding.takeScreenshot('sayring-ios-login-1135');
    expect(controller.session?.accountKey, ownerBefore);
    expect(tester.takeException(), isNull);
    binding.reportData = {
      ...?binding.reportData,
      'loginChecks': [
        'published_legal_pair',
        'public_email_password_route',
        'phone_primary',
        'no_account_or_binding_replacement',
      ],
    };
  });
}
