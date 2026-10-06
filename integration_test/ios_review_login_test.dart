import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bootstrap.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';

/// Production network/UI, isolated in-memory account and health stores.
/// Supply only an authorized review account via a private dart-define file.
/// Never include this test target or its credentials in a distribution build.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iPhone review email password login to production', (
    tester,
  ) async {
    const email = String.fromEnvironment('SAYRING_QA_REVIEW_EMAIL');
    const password = String.fromEnvironment('SAYRING_QA_REVIEW_PASSWORD');
    expect(
      email.isNotEmpty && password.isNotEmpty,
      isTrue,
      reason: 'An authorized private review account is required.',
    );

    final deviceVault = SecureSessionVault.global();
    final vault = MemorySessionVault();
    final api = GlobalSaydianApiClient(
      vault,
      locale: () => 'zh-Hans',
      healthReleasePolicy: const WellnessReleasePolicy(enabled: true),
    );
    final controller = AppController(
      vault,
      api,
      MemoryHealthStore(),
      createProductionWearableBridge(),
      allowAutomaticWearableRestore: false,
      generalAiEnabled: false,
      wellnessOnly: true,
    );
    // Attach the actual app view before querying native plugins. The normal
    // production entrypoint also renders first, then initializes storage.
    await tester.pumpWidget(SaydianApp(controller: controller));
    final originalSession = await tester.runAsync(deviceVault.readSession);
    addTearDown(() async {
      try {
        if (await vault.readSession() != null) await api.logout();
      } finally {
        controller.dispose();
        final after = await deviceVault.readSession();
        expect(
          after?.accessToken == originalSession?.accessToken,
          isTrue,
          reason: 'The existing device account must remain unchanged.',
        );
      }
    });
    await tester.runAsync(controller.initialize);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('global-code-login-page')), findsOneWidget);
    await tester.tap(find.text('邮箱').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('email-login-password')), findsOneWidget);
    expect(find.byKey(const Key('code-login-code')), findsNothing);
    expect(find.byKey(const Key('code-login-send')), findsNothing);
    await binding.takeScreenshot('sayring-1062-email-password-empty');

    Future<void> reveal(Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).last,
      );
    }

    await tester.enterText(find.byKey(const Key('code-login-contact')), email);
    await tester.enterText(
      find.byKey(const Key('email-login-password')),
      password,
    );
    for (final key in ['code-login-minimum-age', 'code-login-consent']) {
      final field = find.byKey(Key(key));
      await reveal(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
    }
    final submit = find.byKey(const Key('code-login-submit'));
    await reveal(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(
      controller.isAuthenticated,
      isTrue,
      reason: 'The real production review login must succeed.',
    );
    expect(controller.isPreviewMode, isFalse);
    expect(
      controller.memberProfile.isNotEmpty,
      isTrue,
      reason: 'The signed-in profile must be read from production.',
    );
    expect(find.byKey(const Key('global-code-login-page')), findsNothing);
    expect(controller.isWellnessOnly, isTrue);
    expect(controller.sleepAiEnabled, isFalse);
    expect(controller.healthAlertsAvailable, isFalse);
    expect(controller.shouldShowHealthMetric(HealthMetric.heartRate), isFalse);
    expect(
      controller.shouldShowHealthMetric(HealthMetric.bloodPressure),
      isFalse,
    );
    expect(controller.shouldShowHealthMetric(HealthMetric.ecg), isFalse);
    expect(find.text('心率'), findsNothing);
    expect(find.text('血压'), findsNothing);
    expect(find.text('健康百科'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
