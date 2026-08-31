import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/app_payment_bridge.dart';

void main() {
  group('AppPaymentPayloadParser', () {
    test('finds complete WeChat payload through backend aliases', () {
      final result = AppPaymentPayloadParser.wechat({
        'payStatus': false,
        'payment': {
          'pay_params': {
            'app_id': 'wx-production',
            'mch_id': 'merchant-1',
            'prepay_id': 'prepay-1',
            'nonce_str': 'nonce-1',
            'time_stamp': 1788000000,
            'pay_sign': 'server-signature',
          },
        },
      });

      expect(result['app_id'], 'wx-production');
      expect(result['prepay_id'], 'prepay-1');
      expect(result['pay_sign'], 'server-signature');
    });

    test('accepts JSON-encoded WeChat config but rejects partial fields', () {
      expect(
        AppPaymentPayloadParser.wechat({
          'config':
              '{"appid":"wx-production","partnerid":"merchant-1",'
              '"prepayid":"prepay-1","noncestr":"nonce-1",'
              '"timestamp":"1788000000","sign":"server-signature"}',
        }),
        isNotEmpty,
      );
      expect(
        AppPaymentPayloadParser.wechat({
          'config': {'appid': 'wx-production', 'prepayid': 'prepay-1'},
        }),
        isEmpty,
      );
    });

    test('keeps native and Flutter WeChat field aliases aligned', () {
      expect(
        AppPaymentPayloadParser.wechat({
          'appID': 'wx-test-app',
          'partnerID': 'merchant-2',
          'prepayID': 'prepay-2',
          'nonceString': 'nonce-2',
          'timeStamp': '1788000001',
          'signature': 'signed-value-2',
        }),
        isNotEmpty,
      );
    });

    test('finds Alipay order strings in all supported wrappers', () {
      expect(
        AppPaymentPayloadParser.alipay({
          'params': {'order_string': 'app_id=1&sign=server-signature'},
        }),
        'app_id=1&sign=server-signature',
      );
      expect(
        AppPaymentPayloadParser.alipay({
          'config': '{"orderInfo":"app_id=2&sign=server-signature"}',
        }),
        'app_id=2&sign=server-signature',
      );
      expect(AppPaymentPayloadParser.alipay({'payStatus': false}), isEmpty);
    });
  });

  test(
    'payment callback status recognizes provider success and cancellation',
    () {
      expect(
        AppPaymentResult.fromMap(const {'resultStatus': '9000'}).isSuccess,
        isTrue,
      );
      expect(
        AppPaymentResult.fromMap(const {'errCode': -2}).isCancelled,
        isTrue,
      );
      expect(
        AppPaymentResult.fromMap(const {'resultStatus': '6001'}).isCancelled,
        isTrue,
      );
    },
  );
}
