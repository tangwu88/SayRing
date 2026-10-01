import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/global_auth_page.dart';

GlobalAuthCapabilities _capabilities({
  String? version = 'reviewed-test-v1',
}) => GlobalAuthCapabilities(
  email: false,
  sms: false,
  smsCountries: const {},
  supportedLocales: const ['en', 'fr'],
  recoveryEmail: true,
  consentVersion: version,
  legal: {
    'userAgreement':
        '/global/api/saydian-app/v2/content/legal/say_ring_user_agreement?version=$version&locale=en',
    'privacyPolicy':
        '/global/api/saydian-app/v2/content/legal/say_ring_privacy_policy?version=$version&locale=en',
  },
);

class _AuthController extends Fake implements AppController {
  _AuthController({this.loadCapabilities});
  final Future<GlobalAuthCapabilities> Function()? loadCapabilities;
  int capabilityCalls = 0;
  int loginCalls = 0;
  int resetCalls = 0;
  bool? accepted;
  String? resetVersion;

  @override
  Future<GlobalAuthCapabilities> globalAuthCapabilities() {
    capabilityCalls++;
    return loadCapabilities?.call() ?? Future.value(_capabilities());
  }

  @override
  Future<bool> login(
    String username,
    String password, {
    bool privacyConsentGranted = false,
  }) async {
    loginCalls++;
    accepted = privacyConsentGranted;
    return true;
  }

  @override
  Future<VerificationChallenge> requestGlobalVerification({
    required GlobalAccountIdentity identity,
    required String purpose,
    required String locale,
  }) async => const VerificationChallenge(
    id: 'synthetic-reset-challenge',
    expiresIn: 300,
    retryAfter: 0,
    maskedIdentifier: 'q***@example.com',
  );

  @override
  Future<bool> completeGlobalVerification({
    required VerificationChallenge challenge,
    required String code,
    required String password,
    required bool resetPassword,
    required String locale,
    required bool privacyConsentGranted,
    String? consentVersion,
  }) async {
    expect(resetPassword, isTrue);
    resetCalls++;
    accepted = privacyConsentGranted;
    resetVersion = consentVersion;
    return true;
  }

  @override
  Future<Map<String, Object?>> globalLegalDocument(String path) async => {
    'documentType': 'say_ring_user_agreement',
    'version': 'reviewed-test-v1',
    'locale': 'en',
    'reviewed': true,
    'contentHtml': '<p>Synthetic reviewed test document only.</p>',
  };
}

Widget _host(
  AppController controller, {
  bool reset = false,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: GlobalAuthPage(controller: controller, resetPassword: reset),
);

Future<void> _fill(WidgetTester tester, {bool reset = false}) async {
  await tester.tap(find.text('Email').first);
  await tester.pump();
  await tester.enterText(
    find.byKey(const Key('auth-contact')),
    'qa@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('auth-password')),
    'Synthetic123',
  );
  if (reset) {
    await tester.enterText(
      find.byKey(const Key('auth-confirm-password')),
      'Synthetic123',
    );
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  tester.testTextInput.hide();
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

CheckboxListTile _consent(WidgetTester tester) =>
    tester.widget(find.byKey(const Key('auth-consent')));

void main() {
  setUp(() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
  });

  testWidgets('existing-account login requires an explicit unchecked agreement', (
    tester,
  ) async {
    final controller = _AuthController();
    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    expect(_consent(tester).value, isFalse);
    await _fill(tester);
    await _tap(tester, 'auth-submit');
    expect(controller.loginCalls, 0);
    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    await _tap(tester, 'auth-consent');
    await _tap(tester, 'auth-submit');
    await tester.pumpAndSettle();
    // Both registration methods are disabled, but existing accounts can log in.
    expect(controller.loginCalls, 1);
    expect(controller.accepted, isTrue);
  });

  for (final version in <String?>[null, '', '   ']) {
    testWidgets('missing published consent version blocks login: <$version>', (
      tester,
    ) async {
      final controller = _AuthController(
        loadCapabilities: () async => _capabilities(version: version),
      );
      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();
      expect(_consent(tester).onChanged, isNull);
      await _fill(tester);
      await _tap(tester, 'auth-submit');
      expect(controller.loginCalls, 0);
      expect(controller.accepted, isNull);
    });
  }

  testWidgets('unavailable capabilities cannot be bypassed by login', (
    tester,
  ) async {
    final controller = _AuthController(
      loadCapabilities: () async =>
          throw const ApiException('Synthetic unavailable', statusCode: 503),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    await _fill(tester);
    expect(_consent(tester).onChanged, isNull);
    await _tap(tester, 'auth-submit');
    expect(controller.loginCalls, 0);
  });

  testWidgets(
    'late capabilities cannot grant consent or replace the current locale response',
    (tester) async {
      final first = Completer<GlobalAuthCapabilities>();
      final second = Completer<GlobalAuthCapabilities>();
      var calls = 0;
      final controller = _AuthController(
        loadCapabilities: () => calls++ == 0 ? first.future : second.future,
      );
      await tester.pumpWidget(_host(controller));
      await tester.pump();
      await _fill(tester);
      expect(_consent(tester).onChanged, isNull);
      await _tap(tester, 'auth-submit');
      expect(controller.loginCalls, 0);
      await tester.pumpWidget(_host(controller, locale: const Locale('fr')));
      await tester.pump();
      second.complete(_capabilities(version: null));
      await tester.pumpAndSettle();
      first.complete(_capabilities());
      await tester.pumpAndSettle();
      expect(controller.capabilityCalls, 2);
      expect(_consent(tester).value, isFalse);
      expect(_consent(tester).onChanged, isNull);
      expect(controller.loginCalls, 0);
    },
  );

  testWidgets('changing language clears an earlier agreement', (tester) async {
    final controller = _AuthController();
    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    await _tap(tester, 'auth-consent');
    expect(_consent(tester).value, isTrue);
    await tester.pumpWidget(_host(controller, locale: const Locale('fr')));
    await tester.pumpAndSettle();
    expect(_consent(tester).value, isFalse);
    expect(controller.capabilityCalls, 2);
    expect(controller.loginCalls, 0);
  });

  testWidgets(
    'reading legal content never counts as consent and return clears old agreement',
    (tester) async {
      final controller = _AuthController();
      await tester.pumpWidget(_host(controller));
      await tester.pumpAndSettle();
      await _tap(tester, 'auth-consent');
      expect(_consent(tester).value, isTrue);
      final terms = find.widgetWithText(TextButton, 'Terms of Service');
      await tester.ensureVisible(terms);
      await tester.tap(terms);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-legal-page')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_consent(tester).value, isFalse);
      expect(controller.capabilityCalls, 3);
      expect(controller.loginCalls, 0);
    },
  );

  testWidgets(
    'verified password reset cannot create a session without consent',
    (tester) async {
      final controller = _AuthController();
      await tester.pumpWidget(_host(controller, reset: true));
      await tester.pumpAndSettle();
      await _fill(tester, reset: true);
      final sendCode = find.widgetWithText(TextButton, 'Send code');
      await tester.ensureVisible(sendCode);
      await tester.tap(sendCode);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('auth-code')), '123456');
      await _tap(tester, 'auth-submit');
      expect(controller.resetCalls, 0);
      await _tap(tester, 'auth-consent');
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(controller.resetCalls, 1);
      expect(controller.accepted, isTrue);
      expect(controller.resetVersion, 'reviewed-test-v1');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
