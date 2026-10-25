import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/ui/global_code_login_page.dart';
import 'package:saydian_app/ui/pages.dart';

// Manual by default. Explicitly approved automation consumes an ephemeral private
// input once; never compile, log or export credentials or keychain contents.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'XR user sign-in persists and enables real account pages',
    (tester) async {
      final vault = SecureSessionVault.global();
      final before = await vault.readSession();
      final app = AppController.production();
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/xr-login-observer-20261025',
      );
      await dir.create(recursive: true);
      final proof = <String, Object?>{
        'beforePresent': before != null,
        'beforeExpired': before?.expiresAt.isBefore(DateTime.now().toUtc()),
        'beforeExpiryDeltaSeconds': before?.expiresAt
            .difference(DateTime.now().toUtc())
            .inSeconds,
      };
      Future<void> save() async {
        await File(
          '${dir.path}/proof.json',
        ).writeAsString(jsonEncode(proof), flush: true);
        binding.reportData = {
          ...?binding.reportData,
          'loginPersistence': proof,
        };
      }

      Future<void> settle() async {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump().timeout(const Duration(seconds: 15));
      }

      final api = GlobalSaydianApiClient(vault, locale: () => 'zh');
      await settle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      if (find.byType(GlobalCodeLoginPage).evaluate().isEmpty) {
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => GlobalCodeLoginPage(controller: app),
          ),
        );
        await settle();
      }
      proof['loginPageReady'] = find
          .byType(GlobalCodeLoginPage)
          .evaluate()
          .isNotEmpty;
      await save();
      // Status only. No identifiers, tokens, input values or credential hashes.
      // ignore: avoid_print
      print('XR login observer ready');
      if (const bool.fromEnvironment('SAYRING_QA_APPROVED_LOGIN')) {
        final input = File(
          '${(await getApplicationDocumentsDirectory()).path}/xr-login-input.private.json',
        );
        for (var i = 0; i < 60 && !await input.exists(); i++) {
          await settle();
        }
        expect(
          await input.exists(),
          isTrue,
          reason: 'Explicit approved private input required',
        );
        Map<String, dynamic> supplied;
        try {
          supplied =
              jsonDecode(await input.readAsString()) as Map<String, dynamic>;
        } finally {
          if (await input.exists()) await input.delete();
        }
        expect(supplied['consentApproved'], isTrue);
        expect(supplied['ageConfirmed'], isTrue);
        final identity = supplied.remove('identity') as String;
        final password = supplied.remove('password') as String;
        supplied.clear();
        binding.testTextInput.register();
        addTearDown(binding.testTextInput.unregister);
        if (identity.contains('@')) {
          await tester.tap(find.widgetWithText(ChoiceChip, '邮箱'));
          await settle();
        }
        await tester.enterText(
          find.byKey(const Key('code-login-contact')),
          identity,
        );
        await settle();
        expect(
          tester
                  .widget<TextField>(
                    find.byKey(const Key('code-login-contact')),
                  )
                  .controller
                  ?.text ==
              identity,
          isTrue,
          reason: 'Test contact input was not applied',
        );
        await tester.enterText(
          find.byKey(const Key('code-login-password')),
          password,
        );
        await settle();
        expect(
          tester
                  .widget<TextField>(
                    find.byKey(const Key('code-login-password')),
                  )
                  .controller
                  ?.text ==
              password,
          isTrue,
          reason: 'Test password input was not applied',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await settle();
        final scrollable = find
            .descendant(
              of: find.byKey(const Key('global-code-login-page')),
              matching: find.byType(Scrollable),
            )
            .first;
        for (final key in ['code-login-minimum-age', 'code-login-consent']) {
          final box = find.byKey(Key(key));
          await tester.scrollUntilVisible(box, 180, scrollable: scrollable);
          await Scrollable.ensureVisible(tester.element(box), alignment: .5);
          await settle();
          if (tester.widget<CheckboxListTile>(box).value != true) {
            await tester.tap(box.hitTestable());
            await settle();
          }
        }
        final submit = find.byKey(const Key('code-login-submit'));
        await tester.scrollUntilVisible(submit, 160, scrollable: scrollable);
        await Scrollable.ensureVisible(tester.element(submit), alignment: .5);
        await settle();
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
        await tester.tap(submit.hitTestable());
        proof['approvedAutomatedLoginSubmitted'] = true;
        proof['privateInputRemoved'] = !await input.exists();
        await save();
      }
      var changed = false;
      for (var i = 0; i < 240; i++) {
        await settle();
        final current = await vault.readSession();
        changed =
            current != null &&
            (current.accessToken != before?.accessToken ||
                current.refreshToken != before?.refreshToken ||
                current.expiresAt != before?.expiresAt);
        final loginError = app.lastApiError;
        if (loginError != null) {
          proof['loginAttemptStatus'] = loginError.statusCode;
          final code = '${loginError.code ?? ''}';
          if (RegExp(r'^[A-Za-z0-9_]{1,90}$').hasMatch(code)) {
            proof['loginAttemptCode'] = code;
          }
          await save();
        }
        if (!changed) continue;
        proof['sessionChanged'] = true;
        proof['ownerUnchanged'] =
            before == null || current.accountKey == before.accountKey;
        proof['newExpired'] = current.expiresAt.isBefore(
          DateTime.now().toUtc(),
        );
        proof['newExpiryDeltaSeconds'] = current.expiresAt
            .difference(DateTime.now().toUtc())
            .inSeconds;
        final reread = await SecureSessionVault.global().readSession();
        proof['freshVaultMatches'] =
            reread?.accessToken == current.accessToken &&
            reread?.refreshToken == current.refreshToken;
        await save();
        try {
          proof['profileLoaded'] = (await api.getMemberProfile().timeout(
            const Duration(seconds: 30),
          )).isNotEmpty;
        } on ApiException catch (error) {
          proof['profileStatus'] = error.statusCode;
          proof['profileLoaded'] = false;
        }
        await save();
        break;
      }
      proof['sessionChanged'] = changed;
      await save();
      expect(changed, isTrue, reason: 'No new persisted sign-in observed');
      expect(proof['newExpired'], isFalse);
      expect(proof['freshVaultMatches'], isTrue);
      expect(proof['profileLoaded'], isTrue);
      for (var i = 0; i < 90 && app.isBusy; i++) {
        await settle();
      }
      if (find.byType(GlobalCodeLoginPage).evaluate().isNotEmpty &&
          navigator.canPop()) {
        await tester.binding.handlePopRoute();
        await settle();
      }
      await app.refreshMemberProfile().timeout(const Duration(seconds: 30));
      expect(app.memberProfile, isNotEmpty);
      app.selectTab(2);
      await settle();
      await tester.tap(find.byKey(const Key('profile-header-card')));
      await settle();
      expect(find.byType(ProfileEditPage), findsOneWidget);
      for (
        var i = 0;
        i < 30 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await settle();
      }
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final field = tester.widget<TextField>(
        find.byKey(const Key('profile-nickname')),
      );
      expect(field.controller?.text, '${app.memberProfile['nickname'] ?? ''}');
      expect(tester.takeException(), isNull);
      proof['profilePageLoaded'] = true;
      await File(
        '${dir.path}/profile-private.png',
      ).writeAsBytes(await binding.takeScreenshot('login-observer-profile'));
      await tester.binding.handlePopRoute();
      await settle();
      app.selectTab(0);
      await settle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await settle();
      await tester.tap(
        find.byIcon(Icons.notifications_none_rounded).hitTestable(),
      );
      await settle();
      await app.refreshNotifications().timeout(const Duration(seconds: 30));
      expect(app.notificationStatus, anyOf('暂无消息', '已加载'));
      expect(tester.takeException(), isNull);
      proof['inboxLoaded'] = true;
      await File(
        '${dir.path}/inbox-private.png',
      ).writeAsBytes(await binding.takeScreenshot('login-observer-inbox'));
      await save();
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
