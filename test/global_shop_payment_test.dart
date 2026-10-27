import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_payment_bridge.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/global_shop_payment_page.dart';

const _orderId = 'a39f05c7-bd59-43bb-bc2d-228e0fc1d56a';
Session _session(String owner) => Session(
  accessToken: 'synthetic',
  refreshToken: '',
  expiresAt: DateTime.utc(2030),
  memberId: owner,
  accountKey: 'global:$owner',
  displayName: 'Synthetic',
);
Map<String, Object?> _order() => {
  'id': _orderId,
  'orderNo': 'SYNTHETIC-ORDER',
  'status': 'PENDING_PAYMENT',
  'currency': 'CNY',
  'currencyExponent': 2,
  'payableCents': 1200,
  'readOnly': false,
  'allowedActions': ['PAY'],
};

class _Api extends Fake
    implements SaydianApi, GlobalCommerceApi, GlobalShopPaymentApi {
  bool enabled = true, readOnly = false;
  int created = 0;
  void Function(String)? at;
  Map<String, Object?> overrides = {};
  @override
  Future<Map<String, Object?>> getGlobalCommerceCapabilities() async {
    at?.call('capabilities');
    return {
      'checkout': {'enabled': true, 'currency': 'CNY', 'currencyExponent': 2},
      'maintenance': {'readOnly': readOnly},
      'payments': [
        for (final channel in ['wechat_app', 'alipay_app'])
          {
            'channel': channel,
            'enabled': enabled,
            'environments': ['android'],
            'reason': 'App payment not configured',
          },
      ],
    };
  }

  @override
  Future<Map<String, Object?>> getGlobalShopOrder(String id) async {
    at?.call('order');
    return _order();
  }

  @override
  Future<Map<String, Object?>> createGlobalShopPayment({
    required String orderId,
    required String channel,
    required String platform,
    required String idempotencyKey,
  }) async {
    created++;
    at?.call('intent');
    return {
      'id': 'synthetic-intent',
      'businessType': 'commerce_order',
      'businessId': orderId,
      'channel': channel,
      'status': 'pending',
      'currency': 'CNY',
      'amountCents': 1200,
      'invoke': channel == 'wechat_app'
          ? {
              'appId': 'synthetic-app',
              'partnerId': 'synthetic-merchant',
              'prepayId': 'synthetic-prepay',
              'nonceStr': 'synthetic-nonce',
              'timeStamp': '123',
              'sign': 'synthetic-sign',
            }
          : {'orderString': 'synthetic-provider-signed-order'},
      ...overrides,
    };
  }
}

class _Wearable extends Fake implements WearableBridge {}

class _Bridge extends Fake implements AppPaymentBridge {
  int launched = 0;
  @override
  Future<AppPaymentResult?> takeWechatResult() async => null;
  @override
  Future<void> startWechat(Map<String, Object?> signedParameters) async {
    launched++;
  }

  @override
  Future<AppPaymentResult> startAlipay(String signedOrder) async {
    launched++;
    return const AppPaymentResult(
      code: '9000',
      message: 'synthetic success',
      raw: {},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  AppController controller(_Api api, _Bridge bridge) {
    final value = AppController(
      MemorySessionVault(),
      api,
      MemoryHealthStore(),
      _Wearable(),
      paymentBridge: bridge,
      commerceEnabled: true,
    )..session = _session('owner-a');
    addTearDown(value.dispose);
    return value;
  }

  for (final provider in AppPaymentProvider.values) {
    test(
      'native $provider accepts only the signed intent and leaves order pending',
      () async {
        final api = _Api();
        final bridge = _Bridge();
        final c = controller(api, bridge);
        await c.startGlobalShopPayment(
          orderId: _orderId,
          provider: provider,
          idempotencyKey: 'synthetic-attempt',
        );
        expect(api.created, 1);
        expect(bridge.launched, 1);
        expect(
          (await api.getGlobalShopOrder(_orderId))['status'],
          'PENDING_PAYMENT',
        );
      },
    );
  }
  for (final mode in ['unconfigured', 'maintenance', 'ios']) {
    test('$mode cannot create an intent or invoke a payment app', () async {
      final api = _Api()
        ..enabled = mode != 'unconfigured'
        ..readOnly = mode == 'maintenance';
      final bridge = _Bridge();
      final c = controller(api, bridge);
      if (mode == 'ios') {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      }
      await expectLater(
        c.startGlobalShopPayment(
          orderId: _orderId,
          provider: AppPaymentProvider.wechat,
          idempotencyKey: 'synthetic-attempt',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(api.created, 0);
      expect(bridge.launched, 0);
    });
  }
  for (final phase in ['capabilities', 'order', 'intent']) {
    test(
      'owner change during $phase rejects the old payment before SDK dispatch',
      () async {
        final api = _Api();
        final bridge = _Bridge();
        final c = controller(api, bridge);
        api.at = (step) {
          if (step == phase) c.session = _session('owner-b');
        };
        await expectLater(
          c.startGlobalShopPayment(
            orderId: _orderId,
            provider: AppPaymentProvider.wechat,
            idempotencyKey: 'synthetic-attempt',
          ),
          throwsA(isA<ApiException>()),
        );
        expect(bridge.launched, 0);
      },
    );
  }
  for (final invalid in <Map<String, Object?>>[
    {'businessId': 'another-order'},
    {'currency': 'USD'},
    {'amountCents': 1201},
    {'channel': 'alipay_app'},
    {'status': 'succeeded'},
    {'invoke': <String, Object?>{}},
  ]) {
    test('mismatched intent $invalid never reaches native payment', () async {
      final api = _Api()..overrides = invalid;
      final bridge = _Bridge();
      final c = controller(api, bridge);
      await expectLater(
        c.startGlobalShopPayment(
          orderId: _orderId,
          provider: AppPaymentProvider.wechat,
          idempotencyKey: 'synthetic-attempt',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(bridge.launched, 0);
    });
  }
  test(
    'payment transport uses authenticated global V2 and never trusts a client amount',
    () async {
      final vault = MemorySessionVault()..session = _session('owner-a');
      late Map<String, Object?> body;
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          expect(request.url.host, 'app.saydian.cn');
          expect(
            request.url.path,
            '/global/api/saydian-app/v2/billing/payments',
          );
          expect(request.headers['Authorization'], 'Bearer synthetic');
          body = (jsonDecode(request.body) as Map).cast<String, Object?>();
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {'id': 'synthetic'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await api.createGlobalShopPayment(
        orderId: _orderId,
        channel: 'wechat_app',
        platform: 'android',
        idempotencyKey: 'synthetic-attempt',
      );
      expect(body, {
        'businessType': 'commerce_order',
        'businessId': _orderId,
        'channel': 'wechat_app',
        'platform': 'android',
        'idempotencyKey': 'synthetic-attempt',
      });
    },
  );

  testWidgets(
    'unconfigured checkout is honest and readable at 332dp with large text',
    (tester) async {
      tester.view.physicalSize = const Size(332, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api()..enabled = false;
      final bridge = _Bridge();
      final c = controller(api, bridge);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(332, 740),
              textScaler: TextScaler.linear(2),
            ),
            child: GlobalShopPaymentPage(controller: c, orderId: _orderId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('global-payment-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('未配置'), findsNothing);
      expect(find.textContaining('当前暂无可用的支付方式'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(bridge.launched, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
