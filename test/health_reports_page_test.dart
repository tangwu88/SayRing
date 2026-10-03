import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_report_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_payment_bridge.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/health_reports_page.dart';

void main() {
  testWidgets(
    'insufficient health data explains missing days without payment action',
    (tester) async {
      final api = _HealthReportApi(
        eligibility: _eligibility(
          eligible: false,
          distinctDays: 1,
          missing: const ['还需要至少2天有效记录'],
        ),
      );
      final controller = _controller(api);
      addTearDown(controller.dispose);

      await _pumpPage(tester, controller);

      expect(find.text('再积累一些数据即可生成'), findsOneWidget);
      expect(find.text('还需要至少2天有效记录'), findsOneWidget);
      expect(find.textContaining('不会创建支付订单'), findsOneWidget);
      expect(find.byKey(const Key('health-report-generate')), findsNothing);
      expect(find.byKey(const Key('health-report-pay')), findsNothing);
    },
  );

  testWidgets('eligible member can select a real versioned report offer', (
    tester,
  ) async {
    final api = _HealthReportApi(
      eligibility: _eligibility(eligible: true, distinctDays: 4),
      reports: const [_awaitingReport],
    );
    final paymentBridge = _PaymentBridge();
    final controller = _controller(api, paymentBridge: paymentBridge);
    addTearDown(controller.dispose);

    await _pumpPage(tester, controller);
    await tester.scrollUntilVisible(
      find.byKey(const Key('health-report-generate')),
      250,
    );
    await tester.tap(find.byKey(const Key('health-report-generate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('选择报告方案'), findsOneWidget);
    expect(find.text('单次详细报告'), findsOneWidget);
    expect(find.text('¥9.90'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('health-report-pay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('health-report-pay')));
    await tester.pumpAndSettle();

    expect(api.paymentCreateCalls, 1);
    expect(paymentBridge.wechatCalls, 1);
    expect(find.byKey(const Key('health-payment-refresh')), findsOneWidget);
  });

  testWidgets('ring report summary retains protocol keys and unified labels', (
    tester,
  ) async {
    final api = _HealthReportApi(
      eligibility: _eligibility(eligible: false, distinctDays: 1),
      profileMetrics: const [
        HealthProfileMetric(
          metric: 'hrv',
          recordCount: 2,
          latestObservedAt: null,
          latestValue: 48,
        ),
        HealthProfileMetric(
          metric: 'body_temperature',
          recordCount: 3,
          latestObservedAt: null,
          latestValue: 32.4,
        ),
      ],
    );
    final controller = _controller(api);
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller);
    expect(find.text('心率变异性（HRV） 2条'), findsOneWidget);
    expect(find.text('皮肤温度 3条'), findsOneWidget);
    expect(find.text('体温 3条'), findsNothing);
    expect(api.profileMetrics.map((metric) => metric.metric), [
      'hrv',
      'body_temperature',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready report opens evidence-bounded detail and safety notice', (
    tester,
  ) async {
    final api = _HealthReportApi(
      eligibility: _eligibility(eligible: true, distinctDays: 4),
      reports: const [_readyReport],
    );
    final controller = _controller(api);
    addTearDown(controller.dispose);

    await _pumpPage(tester, controller);
    await tester.scrollUntilVisible(find.text('查看报告'), 280);
    final openButton = find.widgetWithText(TextButton, '查看报告');
    await tester.ensureVisible(openButton);
    await tester.pumpAndSettle();
    await tester.tap(openButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('health-report-detail')), findsOneWidget);
    expect(find.text('近30天记录整体较稳定。'), findsOneWidget);
    expect(find.text('保持规律作息。'), findsOneWidget);
    expect(find.textContaining('如有明显不适，请及时就医'), findsOneWidget);
    expect(find.byKey(const Key('health-report-share')), findsOneWidget);
  });
}

Future<void> _pumpPage(WidgetTester tester, AppController controller) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSaydianTheme(),
      home: HealthProfilePage(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

AppController _controller(
  _HealthReportApi api, {
  AppPaymentBridge? paymentBridge,
}) =>
    AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _Wearable(),
        paymentBridge: paymentBridge,
      )
      ..session = Session(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime(2030),
        memberId: 'member-1',
        displayName: '测试用户',
      );

HealthReportEligibility _eligibility({
  required bool eligible,
  required int distinctDays,
  List<String> missing = const [],
}) => HealthReportEligibility(
  eligible: eligible,
  periodFrom: DateTime(2026, 8, 1),
  periodTo: DateTime(2026, 8, 30),
  validRecordCount: eligible ? 12 : 1,
  distinctDays: distinctDays,
  minimumDistinctDays: 3,
  missing: missing,
  consentRequired: false,
  availableCredits: 0,
);

const _awaitingReport = HealthReportSummary(
  id: 'report-12345678',
  status: HealthReportStatus.awaitingPayment,
  periodFrom: null,
  periodTo: null,
  validRecordCount: 12,
  distinctDays: 4,
  freePreview: {'title': '近30天健康概览', 'summary': '已汇总4天有效数据。'},
  aiGenerated: false,
  aiLabel: '健康数据概览',
  generatedAt: null,
  createdAt: null,
  needsPayment: true,
);

const _readyReport = HealthReportSummary(
  id: 'report-12345678',
  status: HealthReportStatus.ready,
  periodFrom: null,
  periodTo: null,
  validRecordCount: 12,
  distinctDays: 4,
  freePreview: {'title': '近30天健康概览', 'summary': '报告已准备好。'},
  aiGenerated: true,
  aiLabel: 'AI生成的健康管理参考',
  generatedAt: null,
  createdAt: null,
  needsPayment: false,
);

class _HealthReportApi extends Fake
    implements SaydianApi, SaydianHealthReportApi {
  _HealthReportApi({
    required this.eligibility,
    this.reports = const [],
    this.profileMetrics = const [
      HealthProfileMetric(
        metric: 'heart_rate',
        recordCount: 8,
        latestObservedAt: null,
        latestValue: 72,
      ),
    ],
  });

  final HealthReportEligibility eligibility;
  final List<HealthReportSummary> reports;
  final List<HealthProfileMetric> profileMetrics;
  int paymentCreateCalls = 0;

  @override
  Future<HealthProfileSummary> getHealthProfile() async => HealthProfileSummary(
    memberId: 'member-1',
    periodFrom: DateTime(2026, 8, 1),
    periodTo: DateTime(2026, 8, 30),
    validRecordCount: eligibility.validRecordCount,
    distinctDays: eligibility.distinctDays,
    metricCount: eligibility.eligible ? 2 : 1,
    metrics: profileMetrics,
    devices: const [],
    activeWarningCount: 0,
    analysisConsentGranted: true,
    analysisConsentVersion: 'health-ai-analysis-v1',
  );

  @override
  Future<HealthReportEligibility> getHealthReportEligibility() async =>
      eligibility;

  @override
  Future<List<HealthReportSummary>> getHealthReports() async => reports;

  @override
  Future<List<HealthReportOffer>> getHealthReportOffers({
    required String platform,
  }) async => const [
    HealthReportOffer(
      id: 'offer-12345678',
      code: 'single-report',
      title: '单次详细报告',
      description: '生成1份详细报告',
      entitlement: HealthReportEntitlement.singleReport,
      priceCents: 990,
      currency: 'CNY',
      creditCount: 1,
      durationDays: null,
      appleProductId: 'cc.saidian.report.single',
      version: 1,
    ),
  ];

  @override
  Future<HealthReportEntitlements> getHealthReportEntitlements() async =>
      const HealthReportEntitlements(
        availableReportCredits: 0,
        membershipId: null,
        membershipExpiresAt: null,
        membershipRemainingCredits: 0,
      );

  @override
  Future<HealthReportSummary> createHealthReport() async =>
      reports.isEmpty ? _awaitingReport : reports.first;

  @override
  Future<Map<String, Object?>> getFullHealthReport(String reportId) async => {
    'id': reportId,
    'content': {
      'aiLabel': 'AI生成的健康管理参考',
      'overview': '近30天记录整体较稳定。',
      'trends': [
        {'metric': 'heart_rate', 'text': '有效记录范围内未见明显波动。'},
      ],
      'suggestions': ['保持规律作息。'],
      'limitations': ['仅基于当前可用的手表记录。'],
      'safetyNotice': '本报告不用于诊断或治疗；如有明显不适，请及时就医。',
    },
  };

  @override
  Future<HealthPaymentIntent> createHealthPayment({
    required String businessType,
    required String businessId,
    required String offerId,
    required String channel,
    required String platform,
    required String idempotencyKey,
  }) async {
    paymentCreateCalls++;
    return HealthPaymentIntent(
      id: 'payment-12345678',
      paymentNo: 'PAY1',
      businessType: businessType,
      businessId: businessId,
      channel: channel,
      status: HealthPaymentStatus.pending,
      amountCents: 990,
      currency: 'CNY',
      invoke: const {
        'appId': 'wx-test',
        'partnerId': 'partner',
        'prepayId': 'prepay',
        'nonceStr': 'test-only-nonce',
        'timeStamp': '1788912000',
        'sign': 'test-only-signature',
      },
      createdAt: DateTime(2026),
    );
  }
}

class _Wearable extends Fake implements WearableBridge {}

class _PaymentBridge implements AppPaymentBridge {
  int wechatCalls = 0;

  @override
  Future<void> startWechat(Map<String, Object?> signedParameters) async {
    wechatCalls++;
  }

  @override
  Future<AppPaymentResult?> takeWechatResult() async => null;

  @override
  Future<AppPaymentResult> startAlipay(String signedOrder) async =>
      const AppPaymentResult(code: '9000', message: 'success', raw: {});
}
