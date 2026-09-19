import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/global_code_login_page.dart';

class CodeLoginController extends Fake implements AppController {
  GlobalAccountIdentity? requested;
  GlobalAccountIdentity? signedIn;

  @override
  Future<GlobalAuthCapabilities> globalAuthCapabilities() async =>
      const GlobalAuthCapabilities(
        email: true,
        sms: true,
        loginEmail: false,
        loginSms: true,
        smsCountries: {'CN'},
        supportedLocales: ['en'],
        consentVersion: 'reviewed-test-v1',
      );

  @override
  Future<VerificationChallenge> requestGlobalLoginCode({
    required GlobalAccountIdentity identity,
    required String locale,
  }) async {
    requested = identity;
    return const VerificationChallenge(
      id: 'synthetic-challenge',
      expiresIn: 300,
      retryAfter: 0,
      maskedIdentifier: '+86********000',
    );
  }

  @override
  Future<bool> loginGlobalWithCode({
    required GlobalAccountIdentity identity,
    required VerificationChallenge challenge,
    required String code,
    required String locale,
    required String consentVersion,
    required bool privacyConsentGranted,
  }) async {
    expect(challenge.id, 'synthetic-challenge');
    expect(code, '123456');
    expect(consentVersion, 'reviewed-test-v1');
    expect(privacyConsentGranted, isTrue);
    signedIn = identity;
    return true;
  }
}

void main() {
  testWidgets('phone code login is default and has no registration/password', (
    tester,
  ) async {
    final controller = CodeLoginController();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GlobalCodeLoginPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('global-code-login-page')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsNothing);
    expect(find.byKey(const Key('auth-toggle-mode')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-wechat')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('code-login-wechat')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('code-login-wechat')))
          .onPressed,
      isNull,
    );
    expect(find.text('CN +86'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('code-login-send')))
          .onPressed,
      isNotNull,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('code-login-submit')))
          .onPressed,
      isNotNull,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-contact')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('code-login-send')));
    await tester.pump();
    expect(find.byKey(const Key('code-login-error')), findsOneWidget);
    expect(controller.requested, isNull);

    await tester.enterText(
      find.byKey(const Key('code-login-contact')),
      '13800138000',
    );
    await tester.tap(find.byKey(const Key('code-login-send')));
    await tester.pumpAndSettle();
    expect(controller.requested?.identifier, '+8613800138000');
    await tester.enterText(find.byKey(const Key('code-login-code')), '123456');
    await tester.ensureVisible(find.byKey(const Key('code-login-consent')));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('code-login-submit')));
    await tester.tap(find.byKey(const Key('code-login-submit')));
    await tester.pumpAndSettle();
    expect(controller.signedIn?.identifier, '+8613800138000');
    expect(tester.takeException(), isNull);
  });
}
