import 'package:flutter/services.dart';

enum AppPaymentProvider { wechat, alipay }

class AppPaymentResult {
  const AppPaymentResult({
    required this.code,
    required this.message,
    required this.raw,
  });

  final String code;
  final String message;
  final Map<String, Object?> raw;

  bool get isSuccess => code == '0' || code == '9000';
  bool get isCancelled => code == '-2' || code == '6001';

  factory AppPaymentResult.fromMap(Map<Object?, Object?> value) {
    final map = value.map((key, value) => MapEntry('$key', value));
    final code =
        '${map['code'] ?? map['errCode'] ?? map['resultStatus'] ?? ''}';
    final message = '${map['message'] ?? map['errStr'] ?? map['memo'] ?? ''}';
    return AppPaymentResult(code: code, message: message, raw: map);
  }
}

abstract interface class AppPaymentBridge {
  Future<void> startWechat(Map<String, Object?> signedParameters);
  Future<AppPaymentResult?> takeWechatResult();
  Future<AppPaymentResult> startAlipay(String signedOrder);
}

class MethodChannelAppPaymentBridge implements AppPaymentBridge {
  const MethodChannelAppPaymentBridge();

  static const _channel = MethodChannel('cc.saidian/app_payments');

  @override
  Future<void> startWechat(Map<String, Object?> signedParameters) async {
    final accepted = await _channel.invokeMethod<bool>(
      'startWechatPay',
      signedParameters,
    );
    if (accepted != true) throw PlatformException(code: 'WECHAT_PAY_NOT_SENT');
  }

  @override
  Future<AppPaymentResult?> takeWechatResult() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'takeWechatPayResult',
    );
    return result == null ? null : AppPaymentResult.fromMap(result);
  }

  @override
  Future<AppPaymentResult> startAlipay(String signedOrder) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'startAlipay',
      {'orderInfo': signedOrder},
    );
    if (result == null) {
      throw PlatformException(
        code: 'ALIPAY_EMPTY_RESULT',
        message: '支付宝未返回支付结果',
      );
    }
    return AppPaymentResult.fromMap(result);
  }
}
