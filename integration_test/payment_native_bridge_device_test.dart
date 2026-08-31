import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS native payment bridge rejects unsafe configuration before launch',
    (tester) async {
      expect(Platform.isIOS, isTrue, reason: '本测试仅验证 iOS 原生支付通道');
      const channel = MethodChannel('cc.saidian/app_payments');

      await expectLater(
        channel.invokeMethod<bool>('startWechatPay', const {
          'appid': 'wx-payment-probe',
          'partnerid': 'merchant-probe',
          'prepayid': 'prepay-probe',
          'noncestr': 'nonce-probe',
          'timestamp': '1788000000',
          'sign': 'server-signature-probe',
        }),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'WECHAT_IOS_CONFIG_MISSING',
          ),
        ),
      );

      await expectLater(
        channel.invokeMethod<Object?>('startAlipay', const {'orderInfo': ''}),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'ALIPAY_CONFIG_INVALID',
          ),
        ),
      );
    },
  );
}
