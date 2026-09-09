import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/global_auth_page.dart';

class NoWatch extends Fake implements WearableBridge {}

class NoCodeController extends Fake implements AppController {
  GlobalAccountIdentity? registeredIdentity;
  String? registeredPassword;
  String? registeredConsent;

  @override
  Future<GlobalAuthCapabilities>
  globalAuthCapabilities() async => const GlobalAuthCapabilities(
    email: true,
    sms: true,
    verificationRequired: false,
    smsCountries: {},
    supportedLocales: ['en'],
    consentVersion: 'reviewed-test-v1',
    legal: {
      'userAgreement':
          '/api/saydian-app/v2/content/legal/user_agreement?version=reviewed-test-v1&locale=en',
      'privacyPolicy':
          '/api/saydian-app/v2/content/legal/privacy_policy?version=reviewed-test-v1&locale=en',
    },
  );

  @override
  Future<bool> registerGlobalWithoutVerification({
    required GlobalAccountIdentity identity,
    required String password,
    required String locale,
    required bool privacyConsentGranted,
    String? consentVersion,
  }) async {
    registeredIdentity = identity;
    registeredPassword = password;
    registeredConsent = consentVersion;
    return privacyConsentGranted;
  }
}

Widget host(AppController controller, {bool reset = false, double scale = 1}) =>
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: GlobalAuthPage(controller: controller, resetPassword: reset),
    );

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('global auth renders English on compact screen at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vault = MemorySessionVault();
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 200,
              'data': {
                'realm': 'global',
                'registration': {
                  'email': false,
                  'sms': false,
                  'verificationRequired': true,
                },
                'supportedLocales': ['en'],
                'smsCountries': [],
              },
            }),
            200,
          ),
        ),
      );
      final controller = AppController(
        vault,
        api,
        MemoryHealthStore(),
        NoWatch(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller, scale: scale));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-auth-page')), findsOneWidget);
      expect(find.text('Email'), findsWidgets);
      expect(find.text('登录'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unconfigured registration never sends a code', (tester) async {
    final calls = <String>[];
    final vault = MemorySessionVault();
    final api = GlobalSaydianApiClient(
      vault,
      client: MockClient((request) async {
        calls.add(request.url.path);
        return http.Response(
          jsonEncode({
            'code': 200,
            'data': {
              'realm': 'global',
              'registration': {
                'email': false,
                'sms': false,
                'verificationRequired': true,
              },
              'smsCountries': [],
            },
          }),
          200,
        );
      }),
    );
    final controller = AppController(
      vault,
      api,
      MemoryHealthStore(),
      NoWatch(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('auth-toggle-mode')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('auth-toggle-mode')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('auth-contact')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('auth-contact')),
      'a@example.com',
    );
    final codeButton = find.widgetWithText(TextButton, 'Send code');
    if (codeButton.evaluate().isNotEmpty) {
      await tester.ensureVisible(codeButton);
      await tester.tap(codeButton);
      await tester.pumpAndSettle();
    }
    expect(calls, [endsWith('/auth/capabilities')]);
    expect(vault.session, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('temporary registration asks for no verification code', (
    tester,
  ) async {
    final controller = NoCodeController();
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('auth-toggle-mode')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('auth-toggle-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-code')), findsNothing);
    expect(find.text('Send code'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('auth-contact')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('auth-contact')),
      'qa@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'Synthetic123',
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm-password')),
      'Synthetic123',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('auth-consent')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('auth-submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(controller.registeredIdentity?.identifier, 'qa@example.com');
    expect(controller.registeredPassword, 'Synthetic123');
    expect(controller.registeredConsent, 'reviewed-test-v1');
    expect(tester.takeException(), isNull);
  });
  testWidgets('reset entry is the same international verified-contact form', (
    tester,
  ) async {
    final vault = MemorySessionVault();
    final api = GlobalSaydianApiClient(
      vault,
      client: MockClient((_) async => http.Response('', 503)),
    );
    final controller = AppController(
      vault,
      api,
      MemoryHealthStore(),
      NoWatch(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller, reset: true));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsWidgets);
    expect(find.byKey(const Key('auth-code')), findsOneWidget);
    expect(find.text('Email'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
