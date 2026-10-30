import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/brand_assets.dart';
import 'package:saydian_app/ui/global_code_login_page.dart';

class CodeLoginController extends Fake implements AppController {
  GlobalAccountIdentity? requested;
  GlobalAccountIdentity? signedIn;
  bool enteredDemo = false;
  String? passwordLoginEmail;
  String? passwordLoginPassword;
  bool passwordLoginConsent = false;
  bool passwordLoginResult = true;
  ApiException? passwordLoginFailure;
  bool localOnlySupported = false;
  bool enteredLocalMode = false;
  bool capabilitiesFail = false;
  int capabilityRequests = 0;
  String? openedLegalPath;
  bool explicitCodeLoginAvailable = true;
  bool smsAutoRegistrationAvailable = true;
  int codeLoginCalls = 0;

  @override
  bool get supportsLocalOnlyUse => localOnlySupported;

  @override
  ApiException? get lastApiError => passwordLoginResult
      ? null
      : passwordLoginFailure ??
            const ApiException('Invalid credentials', statusCode: 401);

  @override
  Future<bool> loginGlobalWithPassword({
    required GlobalAccountIdentity identity,
    required String password,
    required String consentVersion,
    required String locale,
    required bool privacyConsentGranted,
  }) async {
    expect(consentVersion, 'reviewed-test-v1');
    passwordLoginEmail = identity.identifier;
    passwordLoginPassword = password;
    passwordLoginConsent = privacyConsentGranted;
    return passwordLoginResult;
  }

  @override
  void enterPreview() => enteredDemo = true;

  @override
  Future<void> enterLocalMode() async => enteredLocalMode = true;

  @override
  Future<GlobalAuthCapabilities> globalAuthCapabilities() async {
    capabilityRequests++;
    if (capabilitiesFail) throw const ApiException('Unavailable');
    return GlobalAuthCapabilities(
      email: true,
      sms: true,
      loginEmail: false,
      loginSms: true,
      explicitRegistrationCodeLogin: explicitCodeLoginAvailable,
      smsAutoRegistration: smsAutoRegistrationAvailable,
      smsCountries: {'CN'},
      supportedLocales: ['en'],
      consentVersion: 'reviewed-test-v1',
      legal: {
        'userAgreement':
            '/api/saydian-app/v2/content/legal/say_ring_user_agreement?version=reviewed-test-v1&locale=zh-Hans',
        'privacyPolicy':
            '/api/saydian-app/v2/content/legal/say_ring_privacy_policy?version=reviewed-test-v1&locale=zh-Hans',
      },
    );
  }

  @override
  Future<Map<String, Object?>> globalLegalDocument(String path) async {
    openedLegalPath = path;
    return {
      'documentType': path.contains('user_agreement')
          ? 'say_ring_user_agreement'
          : 'say_ring_privacy_policy',
      'version': 'reviewed-test-v1',
      'locale': 'zh-Hans',
      'reviewed': true,
      'contentHtml': '<p>Published Say Ring test agreement.</p>',
    };
  }

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
    bool ageConfirmed = false,
  }) async {
    codeLoginCalls++;
    expect(challenge.id, 'synthetic-challenge');
    expect(code, '123456');
    expect(consentVersion, 'reviewed-test-v1');
    expect(privacyConsentGranted, isTrue);
    expect(ageConfirmed, isTrue);
    signedIn = identity;
    return true;
  }
}

class WechatCodeLoginController extends CodeLoginController {
  final binding = const GlobalWechatPhoneBinding(
    ticket: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    expiresIn: 300,
    profileProof: 'signed-profile-proof',
  );
  GlobalAccountIdentity? bindingIdentity;
  bool bound = false;

  @override
  GlobalWechatPhoneBinding? get pendingGlobalWechatBinding => binding;

  @override
  String? get errorMessage => null;

  @override
  Future<GlobalAuthCapabilities> globalAuthCapabilities() async =>
      const GlobalAuthCapabilities(
        email: true,
        sms: true,
        loginEmail: false,
        loginSms: true,
        smsCountries: {'CN'},
        supportedLocales: ['zh-Hans'],
        consentVersion: 'reviewed-test-v1',
        wechatApp: GlobalWechatAppCapability(
          enabled: true,
          appId: 'wx1234567890abcdef',
          phoneBindingAvailable: true,
        ),
      );

  @override
  Future<bool> loginWithWechat({
    required bool privacyConsentGranted,
    String? appId,
    String? consentVersion,
    String? locale,
    bool ageConfirmed = false,
  }) async {
    expect(privacyConsentGranted, isTrue);
    expect(appId, 'wx1234567890abcdef');
    expect(consentVersion, 'reviewed-test-v1');
    expect(ageConfirmed, isTrue);
    return false;
  }

  @override
  Future<VerificationChallenge> requestGlobalWechatPhoneCode({
    required GlobalWechatPhoneBinding binding,
    required GlobalAccountIdentity identity,
    required String consentVersion,
    required String locale,
  }) async {
    bindingIdentity = identity;
    return const VerificationChallenge(
      id: 'wechat-phone-challenge',
      expiresIn: 300,
      retryAfter: 0,
      maskedIdentifier: '+86********000',
    );
  }

  @override
  Future<bool> bindGlobalWechatPhone({
    required GlobalWechatPhoneBinding binding,
    required VerificationChallenge challenge,
    required String code,
    required String consentVersion,
    required String locale,
    bool ageConfirmed = false,
  }) async {
    expect(challenge.id, 'wechat-phone-challenge');
    expect(code, '123456');
    expect(ageConfirmed, isTrue);
    bound = true;
    return true;
  }
}

void main() {
  for (final channel in ['手机号', '邮箱']) {
    for (final scenario in [
      (name: 'empty', password: '', error: 'empty', dispatch: false),
      (name: 'short', password: '1234567', error: 'length', dispatch: false),
      (name: 'long', password: 'a' * 73, error: 'length', dispatch: false),
      (
        name: 'UTF-8 overflow',
        password: '测' * 25,
        error: 'length',
        dispatch: false,
      ),
      (
        name: 'minimum',
        password: '12345678',
        error: 'credentials',
        dispatch: true,
      ),
      (
        name: 'maximum',
        password: 'a' * 72,
        error: 'credentials',
        dispatch: true,
      ),
      (
        name: 'UTF-8 boundary',
        password: '测' * 24,
        error: 'credentials',
        dispatch: true,
      ),
      (
        name: 'server length',
        password: 'synthetic-password',
        error: 'length',
        dispatch: true,
      ),
      (
        name: 'server unavailable',
        password: 'synthetic-password',
        error: 'service',
        dispatch: true,
      ),
    ]) {
      testWidgets(
        '$channel password login shows actionable ${scenario.name} feedback',
        (tester) async {
          final controller = CodeLoginController()
            ..passwordLoginResult = false
            ..passwordLoginFailure = scenario.error == 'length'
                ? const ApiException(
                    'private validation detail',
                    statusCode: 400,
                    code: 'invalid_password',
                  )
                : scenario.error == 'service'
                ? const ApiException('private service detail', statusCode: 503)
                : null;
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: GlobalCodeLoginPage(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          if (channel == '邮箱') {
            await tester.tap(find.widgetWithText(ChoiceChip, '邮箱'));
            await tester.pumpAndSettle();
          }
          await tester.enterText(
            find.byKey(const Key('code-login-contact')),
            channel == '邮箱' ? 'qa@example.com' : '13800138000',
          );
          await tester.enterText(
            find.byKey(const Key('code-login-password')),
            scenario.password,
          );
          for (final key in ['code-login-minimum-age', 'code-login-consent']) {
            final checkbox = find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Checkbox),
            );
            await tester.ensureVisible(checkbox);
            await tester.tap(checkbox);
            await tester.pump();
          }
          await tester.ensureVisible(
            find.byKey(const Key('code-login-submit')),
          );
          await tester.tap(find.byKey(const Key('code-login-submit')));
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(GlobalCodeLoginPage)),
          )!;
          final expected = switch (scenario.error) {
            'empty' => l.enterPassword,
            'length' => l.passwordRequirement,
            'service' => l.serviceUnavailable,
            _ => l.loginFailed,
          };
          expect(find.text(expected), findsOneWidget);
          if (scenario.error != 'service') {
            expect(find.text(l.serviceUnavailable), findsNothing);
          }
          expect(
            controller.passwordLoginPassword,
            scenario.dispatch ? scenario.password : null,
          );
          expect(controller.requested, isNull);
          expect(controller.codeLoginCalls, 0);
          expect(find.textContaining('private'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final scenario in [
    (password: false, accepted: true),
    (password: true, accepted: true),
    (password: true, accepted: false),
  ]) {
    final password = scenario.password;
    testWidgets(
      '${scenario.accepted ? 'successful' : 'failed'} ${password ? 'password' : 'SMS'} sign-in ${scenario.accepted ? 'dismisses' : 'retains'} a pushed login page',
      (tester) async {
        final controller = CodeLoginController()
          ..passwordLoginResult = scenario.accepted;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  key: const Key('open-pushed-login'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          GlobalCodeLoginPage(controller: controller),
                    ),
                  ),
                  child: const Text('账户首页'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('open-pushed-login')));
        await tester.pumpAndSettle();
        if (!password) {
          await tester.tap(find.byKey(const Key('code-login-mode')));
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.byKey(const Key('code-login-contact')),
          '13800138000',
        );
        if (password) {
          await tester.enterText(
            find.byKey(const Key('code-login-password')),
            'synthetic-password',
          );
        }
        for (final key in ['code-login-minimum-age', 'code-login-consent']) {
          final checkbox = find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Checkbox),
          );
          await tester.ensureVisible(checkbox);
          await tester.pumpAndSettle();
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
        }
        if (!password) {
          final send = find.byKey(const Key('code-login-send'));
          await tester.ensureVisible(send);
          await tester.pumpAndSettle();
          await tester.tap(send);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('code-login-code')),
            '123456',
          );
        }
        final submit = find.byKey(const Key('code-login-submit'));
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(controller.codeLoginCalls, password ? 0 : 1);
        expect(
          find.byKey(const Key('global-code-login-page')),
          scenario.accepted ? findsNothing : findsOneWidget,
        );
        if (scenario.accepted) {
          expect(find.byKey(const Key('open-pushed-login')), findsOneWidget);
        } else {
          expect(find.byKey(const Key('code-login-error')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final available in [true, false]) {
    testWidgets(
      'automatic registration hint follows the published SMS capability: $available',
      (tester) async {
        final controller = CodeLoginController()
          ..smsAutoRegistrationAvailable = available;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GlobalCodeLoginPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        const hint = Key('code-login-sms-auto-register-hint');
        expect(find.byKey(hint), findsNothing);
        await tester.tap(find.byKey(const Key('code-login-mode')));
        await tester.pumpAndSettle();
        expect(find.byKey(hint), available ? findsOneWidget : findsNothing);
        if (available) {
          expect(find.text('未注册的手机号将自动注册并登录'), findsOneWidget);
        }
        for (final key in ['code-login-minimum-age', 'code-login-consent']) {
          final checkbox = find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Checkbox),
          );
          expect(tester.widget<Checkbox>(checkbox).value, isFalse);
        }
        await tester.tap(find.widgetWithText(ChoiceChip, '邮箱'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('code-login-mode')));
        await tester.pumpAndSettle();
        expect(find.byKey(hint), findsNothing);
        expect(controller.requested, isNull);
        expect(controller.signedIn, isNull);
      },
    );
  }
  testWidgets(
    'old server cannot silently create passwordless users through new code login',
    (tester) async {
      final controller = CodeLoginController()
        ..explicitCodeLoginAvailable = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GlobalCodeLoginPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('code-login-mode')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('code-login-contact')),
        '13800138000',
      );
      for (final key in ['code-login-minimum-age', 'code-login-consent']) {
        final checkbox = find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(Checkbox),
        );
        await tester.ensureVisible(checkbox);
        await tester.pumpAndSettle();
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
      }
      final send = find.byKey(const Key('code-login-send'));
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(controller.requested, isNull);
      expect(find.byKey(const Key('code-login-error')), findsOneWidget);
    },
  );
  testWidgets('WeChat restores its outlined style below the phone form', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(364, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GlobalCodeLoginPage(controller: WechatCodeLoginController()),
      ),
    );
    await tester.pumpAndSettle();
    final wechat = find.byKey(const Key('global-wechat-login'));
    expect(tester.widget(wechat), isA<OutlinedButton>());
    final children =
        (tester.widget<ListView>(find.byType(ListView).first).childrenDelegate
                as SliverChildListDelegate)
            .children;
    expect(
      children.indexWhere((w) => w.key == const Key('global-wechat-login')),
      greaterThan(
        children.indexWhere((w) => w.key == const Key('code-login-submit')),
      ),
    );
    await tester.ensureVisible(wechat);
    await tester.pumpAndSettle();
    expect(wechat.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phone password is default and verified registration/recovery are available',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GlobalCodeLoginPage(controller: CodeLoginController()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(find.byKey(const Key('code-login-register')), findsNothing);
      expect(find.byKey(const Key('code-login-create')), findsOneWidget);
      expect(find.byKey(const Key('code-login-recover')), findsOneWidget);
      expect(find.byKey(const Key('code-login-password')), findsOneWidget);
      expect(find.byKey(const Key('code-login-code')), findsNothing);
      expect(find.text('未注册的手机号验证成功后将自动创建账号'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'iPhone account legal link uses current published product document',
    (tester) async {
      final controller = CodeLoginController()..localOnlySupported = true;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GlobalCodeLoginPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      final terms = find.widgetWithText(TextButton, '用户协议');
      await tester.scrollUntilVisible(
        terms,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(terms);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-legal-page')), findsOneWidget);
      expect(find.text('Published Say Ring test agreement.'), findsOneWidget);
      expect(controller.openedLegalPath, contains('say_ring_user_agreement'));
      expect(controller.openedLegalPath, contains('version=reviewed-test-v1'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('age and legal consent checkboxes share one row on phone width', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GlobalCodeLoginPage(controller: CodeLoginController()),
      ),
    );
    await tester.pumpAndSettle();

    final consentRow = find.byKey(const Key('code-login-consents-row'));
    expect(consentRow, findsOneWidget);
    expect(
      find.descendant(
        of: consentRow,
        matching: find.byKey(const Key('code-login-minimum-age')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: consentRow,
        matching: find.byKey(const Key('code-login-consent')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('local iPhone use is secondary to login and requires consent', (
    tester,
  ) async {
    final controller = CodeLoginController()
      ..localOnlySupported = true
      ..capabilitiesFail = true;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GlobalCodeLoginPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.capabilityRequests, 1);
    expect(find.byKey(const Key('code-login-contact')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('code-login-consent')))
          .onChanged,
      isNotNull,
    );
    expect(find.byKey(const Key('review-demo-entry')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('local-ring-use-entry')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('local-ring-use-entry')));
    await tester.pump();
    expect(controller.enteredLocalMode, isFalse);
    expect(find.text('请确认已满14周岁后继续'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-minimum-age')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('code-login-minimum-age')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('code-login-consent')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.tap(find.byKey(const Key('local-ring-use-entry')));
    await tester.pumpAndSettle();
    expect(controller.enteredLocalMode, isTrue);
  });

  testWidgets(
    'email tab restores password login without sending a verification code',
    (tester) async {
      final controller = CodeLoginController();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GlobalCodeLoginPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '邮箱'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('email-login-mode')), findsNothing);
      expect(find.byKey(const Key('code-login-password')), findsOneWidget);
      expect(find.byKey(const Key('code-login-code')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('code-login-contact')),
        'USER@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('code-login-password')),
        'synthetic-password',
      );
      for (final key in ['code-login-minimum-age', 'code-login-consent']) {
        final checkbox = find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(Checkbox),
        );
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pump();
      }
      await tester.ensureVisible(find.byKey(const Key('code-login-submit')));
      await tester.tap(find.byKey(const Key('code-login-submit')));
      await tester.pumpAndSettle();
      expect(controller.signedIn, isNull);
      expect(controller.passwordLoginEmail, 'user@example.com');
      expect(controller.requested, isNull);
    },
  );

  testWidgets('invalid China phone cannot dispatch a login code', (
    tester,
  ) async {
    final controller = CodeLoginController();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GlobalCodeLoginPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code-login-contact')), '123');
    await tester.tap(find.byKey(const Key('code-login-mode')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('code-login-minimum-age')));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('code-login-minimum-age')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('code-login-send')));
    await tester.tap(find.byKey(const Key('code-login-send')));
    await tester.pumpAndSettle();
    expect(controller.requested, isNull);
    expect(controller.signedIn, isNull);
    expect(find.byKey(const Key('code-login-error')), findsOneWidget);
  });

  testWidgets('phone can explicitly switch to verified-code login', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    expect(find.byKey(const Key('code-login-password')), findsOneWidget);
    await tester.tap(find.byKey(const Key('code-login-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-password')), findsNothing);
    expect(find.byKey(const Key('auth-toggle-mode')), findsNothing);
    expect(find.text('CN +86'), findsNothing);
    expect(find.text('请输入11位手机号'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('review-demo-entry')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('review-demo-entry')));
    await tester.pump();
    expect(controller.enteredDemo, isTrue);
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
    await tester.pump();
    expect(controller.requested, isNull);
    expect(
      find.text('Confirm that you are at least 14 years old to continue.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('code-login-minimum-age')));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('code-login-minimum-age')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('code-login-send')));
    await tester.tap(find.byKey(const Key('code-login-send')));
    await tester.pumpAndSettle();
    expect(controller.requested?.identifier, '+8613800138000');
    await tester.enterText(find.byKey(const Key('code-login-code')), '123456');
    await tester.ensureVisible(find.byKey(const Key('code-login-consent')));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('code-login-consent')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('code-login-submit')));
    await tester.tap(find.byKey(const Key('code-login-submit')));
    await tester.pumpAndSettle();
    expect(controller.signedIn?.identifier, '+8613800138000');
    expect(find.byKey(const Key('global-code-login-success')), findsOneWidget);
    expect(find.byKey(const Key('code-login-submit')), findsNothing);
    expect(controller.codeLoginCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'WeChat first authorization opens phone binding with send button',
    (tester) async {
      final controller = WechatCodeLoginController();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GlobalCodeLoginPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SaydianBrandLockup>(find.byType(SaydianBrandLockup))
            .color,
        Colors.black,
      );
      await tester.ensureVisible(find.byKey(const Key('code-login-consent')));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('code-login-consent')),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('code-login-minimum-age')),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('code-login-minimum-age')),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('global-wechat-login')));
      final wechatIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('global-wechat-login')),
          matching: find.byIcon(Icons.wechat_rounded),
        ),
      );
      expect(wechatIcon.icon, Icons.wechat_rounded);
      await tester.tap(find.byKey(const Key('global-wechat-login')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('global-wechat-phone-binding-page')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('wechat-bind-send')))
            .onPressed,
        isNotNull,
      );
      await tester.enterText(
        find.byKey(const Key('wechat-bind-phone')),
        '13800138000',
      );
      await tester.tap(find.byKey(const Key('wechat-bind-send')));
      await tester.pumpAndSettle();
      expect(controller.bindingIdentity?.identifier, '+8613800138000');
      await tester.enterText(
        find.byKey(const Key('wechat-bind-code')),
        '123456',
      );
      await tester.ensureVisible(find.byKey(const Key('wechat-bind-age')));
      await tester.tap(find.byKey(const Key('wechat-bind-age')));
      await tester.ensureVisible(find.byKey(const Key('wechat-bind-submit')));
      await tester.tap(find.byKey(const Key('wechat-bind-submit')));
      await tester.pumpAndSettle();
      expect(controller.bound, isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS keeps login primary and offers one no-login ring entry',
    (tester) async {
      final controller = WechatCodeLoginController()..localOnlySupported = true;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GlobalCodeLoginPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-wechat-login')), findsNothing);
      expect(find.byKey(const Key('code-login-password')), findsOneWidget);
      expect(find.byKey(const Key('code-login-contact')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('code-login-submit')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('local-ring-use-entry')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('code-login-submit')), findsOneWidget);
      expect(find.byKey(const Key('local-ring-use-entry')), findsOneWidget);
      expect(find.text('游客进入'), findsOneWidget);
      expect(find.text('可直接连接戒指；本机健康记录与账号云端数据分开保存。'), findsNothing);
      expect(find.byKey(const Key('review-demo-entry')), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS login page has a single local ring option gated by consent',
    (tester) async {
      final controller = CodeLoginController()..localOnlySupported = true;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GlobalCodeLoginPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('code-login-submit')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('code-login-submit')), findsOneWidget);
      expect(find.byKey(const Key('review-demo-entry')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('local-ring-use-entry')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('local-ring-use-entry')));
      await tester.pump();
      expect(controller.enteredLocalMode, isFalse);
      await tester.scrollUntilVisible(
        find.byKey(const Key('code-login-minimum-age')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('code-login-minimum-age')),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('code-login-consent')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('code-login-consent')),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('local-ring-use-entry')),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('local-ring-use-entry')));
      await tester.pumpAndSettle();
      expect(controller.enteredLocalMode, isTrue);
      expect(controller.passwordLoginEmail, isNull);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
