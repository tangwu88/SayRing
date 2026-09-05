import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_report_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_payment_bridge.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/storekit_purchase_bridge.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'Apple transaction finishes only after server confirms success',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final api = _HealthPaymentApi(
        verifyStatus: HealthPaymentStatus.succeeded,
      );
      final storeKit = _StoreKitBridge();
      final controller = _controller(api: api, storeKit: storeKit);
      addTearDown(controller.dispose);

      final result = await controller.startHealthPurchase(
        offer: _singleOffer,
        report: _awaitingReport,
      );

      expect(result.state, HealthPurchaseFlowState.succeeded);
      expect(api.lastChannel, 'apple_iap');
      expect(api.lastSignedTransaction, 'signed-jws');
      expect(storeKit.purchasedAccountToken, _paymentId);
      expect(storeKit.finished, ['transaction-1']);
    },
  );

  test(
    'Apple transaction remains unfinished while server confirmation is pending',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final api = _HealthPaymentApi(verifyStatus: HealthPaymentStatus.pending);
      final storeKit = _StoreKitBridge();
      final controller = _controller(api: api, storeKit: storeKit);
      addTearDown(controller.dispose);

      final result = await controller.startHealthPurchase(
        offer: _singleOffer,
        report: _awaitingReport,
      );

      expect(result.state, HealthPurchaseFlowState.awaitingConfirmation);
      expect(storeKit.finished, isEmpty);
    },
  );

  test('Android native success remains awaiting server confirmation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final api = _HealthPaymentApi(verifyStatus: HealthPaymentStatus.succeeded);
    final paymentBridge = _PaymentBridge();
    final controller = _controller(api: api, paymentBridge: paymentBridge);
    addTearDown(controller.dispose);

    final result = await controller.startHealthPurchase(
      offer: _singleOffer,
      report: _awaitingReport,
      androidProvider: AppPaymentProvider.alipay,
    );

    expect(paymentBridge.alipayOrder, 'signed-order');
    expect(api.lastChannel, 'alipay_app');
    expect(api.verifyCalls, 0);
    expect(result.state, HealthPurchaseFlowState.awaitingConfirmation);
    expect(result.message, contains('确认'));
  });
}

const _paymentId = '11111111-1111-4111-8111-111111111111';

const _singleOffer = HealthReportOffer(
  id: 'offer-12345678',
  code: 'single-report',
  title: '单次详细报告',
  description: '生成1份报告',
  entitlement: HealthReportEntitlement.singleReport,
  priceCents: 990,
  currency: 'CNY',
  creditCount: 1,
  durationDays: null,
  appleProductId: 'cc.saidian.report.single',
  version: 1,
);

const _awaitingReport = HealthReportSummary(
  id: 'report-12345678',
  status: HealthReportStatus.awaitingPayment,
  periodFrom: null,
  periodTo: null,
  validRecordCount: 8,
  distinctDays: 3,
  freePreview: {},
  aiGenerated: false,
  aiLabel: '健康数据概览',
  generatedAt: null,
  createdAt: null,
  needsPayment: true,
);

AppController _controller({
  required _HealthPaymentApi api,
  StoreKitPurchaseBridge? storeKit,
  AppPaymentBridge? paymentBridge,
}) =>
    AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _Wearable(),
        storeKitPurchaseBridge: storeKit,
        paymentBridge: paymentBridge,
      )
      ..session = Session(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime(2030),
        memberId: 'member-1',
        displayName: '测试用户',
      );

class _HealthPaymentApi extends Fake
    implements SaydianApi, SaydianHealthReportApi {
  _HealthPaymentApi({required this.verifyStatus});

  final HealthPaymentStatus verifyStatus;
  String? lastChannel;
  String? lastSignedTransaction;
  int verifyCalls = 0;

  @override
  Future<HealthPaymentIntent> createHealthPayment({
    required String businessType,
    required String businessId,
    required String offerId,
    required String channel,
    required String platform,
    required String idempotencyKey,
  }) async {
    lastChannel = channel;
    return _intent(
      status: HealthPaymentStatus.pending,
      channel: channel,
      invoke: channel == 'apple_iap'
          ? const {
              'productId': 'cc.saidian.report.single',
              'appAccountToken': _paymentId,
            }
          : const {'orderString': 'signed-order'},
    );
  }

  @override
  Future<HealthPaymentIntent> verifyAppleHealthPayment({
    required String paymentIntentId,
    required String signedTransactionInfo,
  }) async {
    verifyCalls++;
    expect(paymentIntentId, _paymentId);
    lastSignedTransaction = signedTransactionInfo;
    return _intent(
      status: verifyStatus,
      channel: 'apple_iap',
      invoke: const {},
    );
  }
}

class _StoreKitBridge implements StoreKitPurchaseBridge {
  String? purchasedAccountToken;
  final List<String> finished = [];

  @override
  Future<StoreKitTransaction> purchase({
    required String productId,
    required String appAccountToken,
  }) async {
    purchasedAccountToken = appAccountToken;
    return const StoreKitTransaction(
      state: StoreKitPurchaseState.verified,
      productId: 'cc.saidian.report.single',
      transactionId: 'transaction-1',
      appAccountToken: _paymentId,
      signedTransactionInfo: 'signed-jws',
    );
  }

  @override
  Future<List<StoreKitTransaction>> restorePurchases() async => const [];

  @override
  Future<bool> finish(String transactionId) async {
    finished.add(transactionId);
    return true;
  }
}

class _PaymentBridge implements AppPaymentBridge {
  String? alipayOrder;

  @override
  Future<AppPaymentResult> startAlipay(String signedOrder) async {
    alipayOrder = signedOrder;
    return const AppPaymentResult(code: '9000', message: 'success', raw: {});
  }

  @override
  Future<void> startWechat(Map<String, Object?> signedParameters) async {}

  @override
  Future<AppPaymentResult?> takeWechatResult() async => null;
}

class _Wearable extends Fake implements WearableBridge {}

HealthPaymentIntent _intent({
  required HealthPaymentStatus status,
  required String channel,
  required Map<String, Object?> invoke,
}) => HealthPaymentIntent(
  id: _paymentId,
  paymentNo: 'PAY1',
  businessType: 'health_report',
  businessId: _awaitingReport.id,
  channel: channel,
  status: status,
  amountCents: 990,
  currency: 'CNY',
  invoke: invoke,
  createdAt: DateTime(2026),
);
