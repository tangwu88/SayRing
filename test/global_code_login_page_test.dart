import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/brand_assets.dart';
import 'package:saydian_app/ui/global_code_login_page.dart';

class CodeLoginController extends Fake implements AppController {
  GlobalAccountIdentity? requested;
  GlobalAccountIdentity? signedIn;
  bool enteredDemo = false;

  @override
  void enterPreview() => enteredDemo = true;

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
  }) async {
    expect(privacyConsentGranted, isTrue);
    expect(appId, 'wx1234567890abcdef');
    expect(consentVersion, 'reviewed-test-v1');
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
  }) async {
    expect(challenge.id, 'wechat-phone-challenge');
    expect(code, '123456');
    bound = true;
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
      await tester.tap(find.byType(Checkbox));
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
    'iOS hides WeChat while keeping phone code sign-in available',
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
      expect(find.byKey(const Key('global-wechat-login')), findsNothing);
      expect(find.byKey(const Key('code-login-send')), findsOneWidget);
      expect(find.byKey(const Key('code-login-submit')), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
