import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/brand_assets.dart';
import 'package:saydian_app/ui/global_auth_page.dart';
import 'package:saydian_app/ui/global_code_login_page.dart';

class CodeLoginController extends Fake implements AppController {
  GlobalAccountIdentity? requested;
  GlobalAccountIdentity? signedIn;
  bool enteredDemo = false;
  String? passwordLoginEmail;
  String? passwordLoginPassword;
  bool passwordLoginConsent = false;
  bool passwordLoginResult = true;
  bool localOnlySupported = false;
  bool enteredLocalMode = false;
  bool capabilitiesFail = false;
  int capabilityRequests = 0;
  String? openedLegalPath;

  @override
  bool get supportsLocalOnlyUse => localOnlySupported;

  @override
  ApiException? get lastApiError => passwordLoginResult
      ? null
      : const ApiException('Invalid credentials', statusCode: 401);

  @override
  Future<bool> loginGlobalWithEmailPassword({
    required GlobalAccountIdentity identity,
    required String password,
    required String consentVersion,
    required String locale,
    required bool privacyConsentGranted,
  }) async {
    expect(identity.channel, AccountChannel.email);
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
    return const GlobalAuthCapabilities(
      email: true,
      sms: true,
      loginEmail: false,
      loginSms: true,
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
  testWidgets('registration opens from login and returns to primary login', (
    tester,
  ) async {
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
    await tester.tap(find.text('邮箱').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-register')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('code-login-register')));
    await tester.pumpAndSettle();
    final page = tester.widget<GlobalAuthPage>(find.byType(GlobalAuthPage));
    expect(page.createAccount, isTrue);
    expect(page.initialChannel, AccountChannel.email);
    await tester.scrollUntilVisible(
      find.byKey(const Key('auth-minimum-age')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
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
    final age = tester.getCenter(find.byKey(const Key('auth-minimum-age')));
    final consent = tester.getCenter(find.byKey(const Key('auth-consent')));
    expect(age.dy, consent.dy);
    await tester.scrollUntilVisible(
      find.byKey(const Key('auth-toggle-mode')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('auth-toggle-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('global-code-login-page')), findsOneWidget);
    expect(find.byType(GlobalAuthPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('email password requires age and consent before sign-in', (
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
    await tester.tap(find.text('邮箱'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email-login-password')), findsOneWidget);
    expect(find.byKey(const Key('code-login-send')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('code-login-contact')),
      'TEST@Example.com',
    );
    await tester.enterText(
      find.byKey(const Key('email-login-password')),
      'synthetic-password',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('code-login-submit')));
    await tester.tap(find.byKey(const Key('code-login-submit')));
    await tester.pump();
    expect(controller.passwordLoginEmail, isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-minimum-age')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('code-login-minimum-age')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('code-login-submit')));
    await tester.pump();
    expect(controller.passwordLoginEmail, isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-consent')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('code-login-consent')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('code-login-submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('code-login-submit')));
    await tester.tap(find.byKey(const Key('code-login-submit')));
    await tester.pumpAndSettle();
    expect(controller.passwordLoginEmail, 'test@example.com');
    expect(controller.passwordLoginPassword, 'synthetic-password');
    expect(controller.passwordLoginConsent, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid email credentials show a generic sign-in failure', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CodeLoginController()..passwordLoginResult = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GlobalCodeLoginPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('code-login-contact')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('email-login-password')),
      'synthetic-password',
    );
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
      find.byKey(const Key('code-login-submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('code-login-submit')));
    await tester.tap(find.byKey(const Key('code-login-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not sign in. Please check your details and try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

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
      await tester.scrollUntilVisible(
        find.byKey(const Key('global-wechat-login')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final wechatIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('global-wechat-login')),
          matching: find.byIcon(Icons.wechat_rounded),
        ),
      );
      expect(wechatIcon.color, const Color(0xFF07C160));
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
      expect(find.byKey(const Key('code-login-send')), findsOneWidget);
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
