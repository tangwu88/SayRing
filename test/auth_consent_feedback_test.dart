import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/ui/global_auth_page.dart';
import 'package:saydian_app/ui/global_code_login_page.dart';
import 'package:saydian_app/ui/widgets/auth_consent_feedback.dart';
import 'global_code_login_page_test.dart' as login;
import 'global_verified_registration_test.dart' as registration;

void main() {
  for (final register in [false, true]) {
    for (final email in [false, true]) {
      testWidgets(
        'missing agreement is visible for register=$register email=$email',
        (tester) async {
          tester.view
            ..physicalSize = const Size(332, 740)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final signIn = login.CodeLoginController();
          final signUp = registration.RegistrationController();
          final prefix = register ? 'auth' : 'code-login';
          final input = find.byKey(Key('$prefix-contact'));
          Future<void> tap(Finder finder) async {
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            await tester.tap(finder);
            await tester.pumpAndSettle();
          }

          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: register
                  ? GlobalAuthPage(
                      controller: signUp,
                      createAccount: true,
                      initialChannel: email
                          ? AccountChannel.email
                          : AccountChannel.sms,
                    )
                  : GlobalCodeLoginPage(controller: signIn),
            ),
          );
          await tester.pumpAndSettle();
          if (!register) {
            if (email) await tap(find.widgetWithText(ChoiceChip, '邮箱'));
            await tap(find.byKey(const Key('code-login-mode')));
          }
          await tester.enterText(
            input,
            email ? 'synthetic@example.invalid' : '13800138000',
          );
          await tap(find.byKey(Key('$prefix-minimum-age')));
          final send = register
              ? find.widgetWithText(TextButton, '获取验证码')
              : find.byKey(const Key('code-login-send'));
          await tap(send);
          expect(signIn.requested, isNull);
          expect(signUp.requested, isNull);
          expect(find.byType(SnackBar), findsOneWidget);
          final panel = tester.widget<AuthConsentFeedback>(
            find.byType(AuthConsentFeedback),
          );
          expect(panel.message, isNotNull);
          expect(
            tester
                .widget<CheckboxListTile>(find.byKey(Key('$prefix-consent')))
                .value,
            isFalse,
          );
          final rect = tester.getRect(find.byType(AuthConsentFeedback));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(740));
          // No automatic acceptance: only the explicit tap below permits OTP.
          await tap(find.byKey(Key('$prefix-consent')));
          expect(
            tester
                .widget<AuthConsentFeedback>(find.byType(AuthConsentFeedback))
                .message,
            isNull,
          );
          await tap(send);
          if (register) {
            expect(
              signUp.requested?.channel,
              email ? AccountChannel.email : AccountChannel.sms,
            );
          } else if (!email) {
            expect(signIn.requested?.channel, AccountChannel.sms);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
