import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/global_auth_page.dart';

class RegistrationController extends Fake implements AppController {
  GlobalAccountIdentity? requested;
  int registrations = 0;
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
  }) async {
    expect(challenge.id, 'registration-challenge');
    expect(code, '123456');
    expect(password, 'Synthetic123');
    expect(resetPassword, isFalse);
    expect(ageConfirmed, isTrue);
    expect(privacyConsentGranted, isTrue);
    expect(consentVersion, 'reviewed-test-v1');
    registrations++;
    return true;
  }
}

void main() {
  for (final channel in AccountChannel.values) {
    testWidgets(
      '$channel registration requires both verified code and password',
      (tester) async {
        final controller = RegistrationController();
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
        await tester.enterText(find.byKey(const Key('auth-contact')), contact);
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
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
