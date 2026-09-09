import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_report_models.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/health_reports_page.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/global_auth_page.dart';

const _categoryId = '736c4aad-0fe2-4602-98c5-9e1973fc08ec';
const _articleId = '1b31a3cb-77ee-4cc6-ad93-0a640e496817';

class _GlobalPageController extends Fake implements AppController {
  bool reviewed = false;
  bool mismatch = false;
  bool granted = false;
  String? selectedCategory;
  String? requestedArticle;
  String? grantedVersion;
  int grantCalls = 0;
  int createCalls = 0;
  int legacyCalls = 0;

  @override
  bool get isGlobalEdition => true;

  @override
  Future<GlobalAuthCapabilities> globalAuthCapabilities() async =>
      const GlobalAuthCapabilities(
        email: false,
        sms: false,
        smsCountries: {},
        supportedLocales: ['en'],
      );

  @override
  HealthWarningSettings get healthWarningSettings =>
      const HealthWarningSettings();

  @override
  List<Map<String, Object?>> get notifications => const [];

  @override
  String get notificationStatus => '已加载';

  @override
  List<HealthWarningAlert> get healthWarningAlerts => const [];

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  Future<void> refreshNotificationHistory({bool allPages = false}) async {}

  @override
  Future<void> markAllHealthWarningsRead() async {}

  @override
  Future<List<Map<String, Object?>>> loadGlobalArticleCategories() async => [
    {'id': _categoryId, 'title': 'Daily wellbeing'},
  ];

  @override
  Future<List<Map<String, Object?>>> loadGlobalArticles({
    String? categoryId,
    int page = 1,
  }) async {
    selectedCategory = categoryId;
    return [
      {'id': _articleId, 'title': 'Sleep and daily routines'},
    ];
  }

  @override
  Future<Map<String, Object?>> loadGlobalArticle(String id) async {
    requestedArticle = id;
    return {
      'id': id,
      'title': 'Sleep and daily routines',
      'contentHtml': '<p>Reviewed English article body.</p>',
    };
  }

  @override
  Future<Map<String, Object?>> loadArticle(int id) async {
    legacyCalls++;
    throw StateError('Domestic article APIs are forbidden in this test.');
  }

  @override
  Future<HealthReportDashboard> loadHealthReportDashboard() async =>
      HealthReportDashboard(
        profile: HealthProfileSummary.fromMap({
          'memberId': 'global-member',
          'analysisConsent': {
            'granted': granted,
            'version': grantedVersion,
            'availableVersion': reviewed ? 'reviewed-en-v2' : null,
            'document': reviewed
                ? {
                    'path':
                        '/api/saydian-app/v2/content/legal/health_ai_analysis',
                    'locale': 'en',
                    'version': 'reviewed-en-v2',
                  }
                : null,
          },
        }),
        eligibility: HealthReportEligibility.fromMap({
          'eligible': true,
          'consentRequired': !granted,
          'availableCredits': 1,
          'minimumDistinctDays': 3,
        }),
        entitlements: HealthReportEntitlements.fromMap({
          'availableReportCredits': 1,
        }),
        offers: const [],
        reports: [
          HealthReportSummary.fromMap({
            'id': 'existing-report',
            'status': 'ready',
            'freePreview': {
              'title': 'Existing English report',
              'summary': 'Saved report remains available.',
            },
          }),
        ],
      );

  @override
  Future<Map<String, Object?>> globalLegalDocument(String path) async => {
    'title': 'Reviewed health analysis information',
    'locale': 'en',
    'version': mismatch ? 'outdated-v1' : 'reviewed-en-v2',
    'contentHtml':
        '<p>Approved analysis information for this account.</p><script>doNotShowThis()</script>',
  };

  @override
  Future<void> setHealthAnalysisConsent(bool value, {String? version}) async {
    grantCalls++;
    granted = value;
    grantedVersion = version;
  }

  @override
  Future<HealthReportSummary> createHealthReport() async {
    createCalls++;
    return HealthReportSummary.fromMap({
      'id': 'new-report',
      'status': 'queued',
    });
  }

  @override
  String healthReportErrorMessage(Object error) =>
      'Unable to load health reports.';
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Locale locale = const Locale('en'),
  Size viewport = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'international support does not advertise domestic phone or WeChat',
    (tester) async {
      await _pump(tester, const CustomerServicePage(isGlobalEdition: true));
      expect(find.byKey(const Key('global-customer-service')), findsOneWidget);
      expect(find.text('4006386738'), findsNothing);
      expect(find.text('赛电'), findsNothing);
      expect(find.byIcon(Icons.wechat_rounded), findsNothing);
      expect(
        find.text(
          'This feature is temporarily unavailable. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'international security reset opens the global email and phone flow',
    (tester) async {
      final controller = _GlobalPageController();
      await _pump(tester, SecurityCenterPage(controller: controller));
      await tester.tap(find.byKey(const Key('security-reset-password')));
      await tester.pumpAndSettle();
      expect(find.byType(GlobalAuthPage), findsOneWidget);
      expect(
        tester
            .widget<GlobalAuthPage>(find.byType(GlobalAuthPage))
            .resetPassword,
        isTrue,
      );
      expect(find.byType(PasswordRecoveryPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in GlobalLocaleController.supportedLocales) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'health alert safety and controls fit ${locale.toLanguageTag()} at 375px and scale $scale',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final controller = _GlobalPageController();
          await _pump(
            tester,
            HealthWarningPage(controller: controller),
            locale: locale,
            viewport: const Size(375, 812),
          );
          final labels = AppLocalizations.of(
            tester.element(find.byType(HealthWarningPage)),
          )!;
          final pageScroll = find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .first;
          final heartSwitch = find.descendant(
            of: find.byKey(const Key('warning-heart-rate-switch')),
            matching: find.byType(Switch),
          );
          await tester.scrollUntilVisible(
            heartSwitch,
            180,
            scrollable: pageScroll,
          );
          await tester.pumpAndSettle();
          expect(find.text(labels.heartRateAlertLabel), findsOneWidget);
          expect(heartSwitch.hitTestable(), findsOneWidget);
          await tester.tap(heartSwitch);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text(labels.heartRateUpperLimit),
            180,
            scrollable: pageScroll,
          );
          expect(find.text(labels.heartRateUpperLimit), findsOneWidget);
          expect(find.text('120'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text(labels.seekProfessionalCare),
            220,
            scrollable: pageScroll,
          );
          expect(find.text(labels.seekProfessionalCare), findsOneWidget);
          expect(find.text(labels.watchHealthReference), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'international encyclopedia preserves UUID category and article IDs',
    (tester) async {
      final controller = _GlobalPageController();
      await _pump(tester, ArticleCategoryPage(controller: controller));
      expect(find.byKey(const Key('global-article-library')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('global-article-category-$_categoryId')),
      );
      await tester.pumpAndSettle();
      expect(controller.selectedCategory, _categoryId);
      await tester.tap(
        find.byKey(const ValueKey('global-article-$_articleId')),
      );
      await tester.pumpAndSettle();
      expect(controller.requestedArticle, _articleId);
      expect(controller.legacyCalls, 0);
      expect(find.text('Reviewed English article body.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no reviewed analysis document disables new analysis but keeps report history',
    (tester) async {
      final controller = _GlobalPageController();
      await _pump(tester, HealthProfilePage(controller: controller));
      await tester.scrollUntilVisible(
        find.byKey(const Key('health-report-generate')),
        240,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('health-report-generate')),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('health-analysis-consent-grant')),
        200,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('health-analysis-consent-grant')),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('Existing English report'),
        200,
      );
      expect(find.text('Existing English report'), findsOneWidget);
      expect(controller.grantCalls, 0);
      expect(controller.createCalls, 0);
    },
  );

  testWidgets(
    'analysis consent displays approved text and sends the explicit reviewed version',
    (tester) async {
      final controller = _GlobalPageController()..reviewed = true;
      await _pump(tester, HealthProfilePage(controller: controller));
      await tester.scrollUntilVisible(
        find.byKey(const Key('health-analysis-consent-grant')),
        240,
      );
      await tester.tap(find.byKey(const Key('health-analysis-consent-grant')));
      await tester.pumpAndSettle();
      expect(
        find.text('Approved analysis information for this account.'),
        findsOneWidget,
      );
      expect(find.textContaining('doNotShowThis'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('health-analysis-consent-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const Key('health-analysis-consent-checkbox')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('health-analysis-consent-confirm')),
      );
      await tester.pumpAndSettle();
      expect(controller.grantCalls, 1);
      expect(controller.grantedVersion, 'reviewed-en-v2');
      expect(controller.createCalls, 0);
    },
  );

  testWidgets('changed legal document version never grants analysis consent', (
    tester,
  ) async {
    final controller = _GlobalPageController()
      ..reviewed = true
      ..mismatch = true;
    await _pump(tester, HealthProfilePage(controller: controller));
    await tester.scrollUntilVisible(
      find.byKey(const Key('health-analysis-consent-grant')),
      240,
    );
    await tester.tap(find.byKey(const Key('health-analysis-consent-grant')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('health-analysis-consent-confirm')),
      findsNothing,
    );
    expect(controller.grantCalls, 0);
    expect(controller.createCalls, 0);
  });
}
