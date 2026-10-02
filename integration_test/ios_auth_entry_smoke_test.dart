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
  testWidgets('iPhone published legal and registration entry', (tester) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    await controller.initialize();
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
    await tester.tap(find.text('邮箱').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email-login-password')), findsOneWidget);

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

    final register = find.byKey(const Key('code-login-register'));
    await reveal(register);
    await tester.tap(register);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('global-auth-page')), findsOneWidget);
    await reveal(find.byKey(const Key('auth-minimum-age')));
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('auth-minimum-age')))
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('auth-consent')))
          .value,
      isFalse,
    );
    expect(
      tester.getCenter(find.byKey(const Key('auth-minimum-age'))).dy,
      tester.getCenter(find.byKey(const Key('auth-consent'))).dy,
    );
    expect(find.byKey(const Key('auth-confirm-password')), findsOneWidget);
    final submit = find.byKey(const Key('auth-submit'));
    await reveal(submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await binding.takeScreenshot('sayring-ios-register-20261002');
    final back = find.byKey(const Key('auth-toggle-mode'));
    await reveal(back);
    await tester.tap(back);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('global-code-login-page')), findsOneWidget);
    expect(find.byKey(const Key('local-ring-use-entry')), findsOneWidget);
    expect(find.byKey(const Key('global-wechat-login')), findsNothing);
    await binding.takeScreenshot('sayring-ios-login-20261002');
    expect(controller.session?.accountKey, ownerBefore);
    expect(tester.takeException(), isNull);
  });
}
