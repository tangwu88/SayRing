import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/ui/global_auth_page.dart';

class RegistrationController extends Fake implements AppController {
  GlobalAccountIdentity? requested;
  int registrations = 0;
  String? failureCode;
  int passwordLogins = 0;
  @override
  ApiException? get lastApiError => failureCode == null
      ? null
      : ApiException(
          'Synthetic registration completion error',
          code: failureCode,
        );

  @override
  Future<bool> login(
    String username,
    String password, {
    bool privacyConsentGranted = false,
  }) async {
    expect(username, requested!.identifier);
    expect(password, 'Synthetic123');
    expect(privacyConsentGranted, isTrue);
    passwordLogins++;
    return false;
  }

  @override
  Future<GlobalAuthCapabilities> globalAuthCapabilities() async =>
      const GlobalAuthCapabilities(
        email: true,
        sms: true,
        smsCountries: {'CN'},
        supportedLocales: ['en'],
        consentVersion: 'reviewed-test-v1',
      );
  @override
  Future<VerificationChallenge> requestGlobalVerification({
    required GlobalAccountIdentity identity,
    required String purpose,
    required String locale,
  }) async {
    expect(purpose, 'register');
    requested = identity;
    return const VerificationChallenge(
      id: 'registration-challenge',
      expiresIn: 300,
      retryAfter: 0,
      maskedIdentifier: 'synthetic-recipient',
    );
  }

  @override
  Future<bool> completeGlobalVerification({
    required VerificationChallenge challenge,
    required String code,
    required String password,
    required bool resetPassword,
    required String locale,
    required bool privacyConsentGranted,
    bool ageConfirmed = false,
    String? consentVersion,
    GlobalAccountIdentity? registrationIdentity,
  }) async {
    expect(challenge.id, 'registration-challenge');
    expect(code, '123456');
    expect(password, 'Synthetic123');
    expect(resetPassword, isFalse);
    expect(ageConfirmed, isTrue);
    expect(privacyConsentGranted, isTrue);
    expect(consentVersion, 'reviewed-test-v1');
    expect(registrationIdentity?.identifier, requested?.identifier);
    registrations++;
    return failureCode == null;
  }
}

void main() {
  for (final channel in AccountChannel.values) {
    for (final failure in [
      null,
      'ACCOUNT_CREATED_SIGN_IN_REQUIRED',
      'REGISTRATION_CONFIRMATION_REQUIRED',
    ]) {
      testWidgets(
        '$channel registration requires both verified code and password: $failure',
        (tester) async {
          final controller = RegistrationController()..failureCode = failure;
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: GlobalAuthPage(
                controller: controller,
                createAccount: true,
                initialChannel: channel,
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> tapKey(String key) async {
            final owner = find.byKey(Key(key));
            final checkbox = find.descendant(
              of: owner,
              matching: find.byType(Checkbox),
            );
            final finder = checkbox.evaluate().isEmpty ? owner : checkbox;
            tester.testTextInput.hide();
            await tester.pump();
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            await tester.tap(finder);
            await tester.pumpAndSettle();
          }

          final contact = channel == AccountChannel.email
              ? 'User@example.com'
              : '13800138000';
          await tester.enterText(
            find.byKey(const Key('auth-contact')),
            contact,
          );
          await tester.enterText(
            find.byKey(const Key('auth-password')),
            'Synthetic123',
          );
          await tester.enterText(
            find.byKey(const Key('auth-confirm-password')),
            'Synthetic123',
          );
          await tapKey('auth-minimum-age');
          await tapKey('auth-consent');
          expect(
            tester
                .widget<CheckboxListTile>(
                  find.byKey(const Key('auth-minimum-age')),
                )
                .value,
            isTrue,
          );
          expect(
            tester
                .widget<CheckboxListTile>(find.byKey(const Key('auth-consent')))
                .value,
            isTrue,
          );
          await tapKey('auth-submit');
          expect(controller.registrations, 0);
          final send = find.widgetWithText(TextButton, 'Send code');
          await tester.ensureVisible(send);
          await tester.tap(send);
          await tester.pumpAndSettle();
          expect(controller.requested?.channel, channel);
          expect(
            controller.requested?.identifier,
            channel == AccountChannel.email
                ? 'user@example.com'
                : '+8613800138000',
          );
          await tester.enterText(find.byKey(const Key('auth-code')), '123456');
          await tapKey('auth-submit');
          expect(controller.registrations, 1);
          if (failure != null) {
            expect(find.byKey(const Key('auth-code')), findsNothing);
            expect(
              find.byKey(const Key('auth-confirm-password')),
              findsNothing,
            );
            expect(
              find.text(
                failure == 'ACCOUNT_CREATED_SIGN_IN_REQUIRED'
                    ? 'Your account was created. Sign in with your password.'
                    : 'Registration could not be confirmed. Sign in with your password instead of registering again.',
              ),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<TextFormField>(find.byKey(const Key('auth-password')))
                  .controller!
                  .text,
              'Synthetic123',
            );
            expect(
              tester
                  .widget<CheckboxListTile>(
                    find.byKey(const Key('auth-consent')),
                  )
                  .value,
              isTrue,
            );
            await tapKey('auth-submit');
            expect(tester.takeException(), isNull);
            expect(controller.passwordLogins, 1);
            expect(controller.registrations, 1);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
