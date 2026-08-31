import 'dart:convert';

import 'package:flutter/services.dart';

enum AppPaymentProvider { wechat, alipay }

/// Extracts provider-signed payment payloads without ever generating or
/// modifying a signature on the device. Backends in the delivered project use
/// several wrappers (`config`, `pay`, `params`, and string `data`), so the
/// parser validates the actual provider fields instead of assuming one shape.
abstract final class AppPaymentPayloadParser {
  static Map<String, Object?> wechat(Object? value) =>
      _findWechat(_decodeJsonContainer(value), depth: 0) ?? const {};

  static String alipay(Object? value) =>
      _findAlipay(_decodeJsonContainer(value), depth: 0);

  static const _wechatFieldAliases = <List<String>>[
    ['appId', 'appID', 'appid', 'app_id'],
    ['partnerId', 'partnerID', 'partnerid', 'partner_id', 'mchId', 'mch_id'],
    ['prepayId', 'prepayID', 'prepayid', 'prepay_id'],
    ['nonceStr', 'nonceString', 'noncestr', 'nonce_str'],
    ['timeStamp', 'timestamp', 'time_stamp'],
    ['sign', 'paySign', 'pay_sign', 'signature'],
  ];

  static const _nestedKeys = <String>[
    'config',
    'pay',
    'params',
    'pay_params',
    'payment',
    'payment_params',
    'wechat',
    'wxpay',
    'data',
    'result',
  ];

  static const _alipayStringKeys = <String>[
    'orderInfo',
    'order_info',
    'orderString',
    'order_string',
    'payInfo',
    'pay_info',
    ..._nestedKeys,
  ];

  static Map<String, Object?>? _findWechat(
    Object? value, {
    required int depth,
  }) {
    if (depth > 6) return null;
    final normalized = _decodeJsonContainer(value);
    if (normalized is! Map) return null;
    final map = normalized.map((key, value) => MapEntry('$key', value));
    final isComplete = _wechatFieldAliases.every(
      (aliases) => aliases.any((key) => _nonEmptyScalar(map[key])),
    );
    if (isComplete) return map;

    for (final key in _nestedKeys) {
      final result = _findWechat(map[key], depth: depth + 1);
      if (result != null) return result;
    }
    for (final nested in map.values.whereType<Map>()) {
      final result = _findWechat(nested, depth: depth + 1);
      if (result != null) return result;
    }
    return null;
  }

  static String _findAlipay(Object? value, {required int depth}) {
    if (depth > 6 || value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '';
      final decoded = _decodeJsonContainer(trimmed);
      if (decoded is! String) {
        return _findAlipay(decoded, depth: depth + 1);
      }
      return trimmed;
    }
    if (value is! Map) return '';
    final map = value.map((key, value) => MapEntry('$key', value));
    for (final key in _alipayStringKeys) {
      final nested = map[key];
      if (nested is String || nested is Map) {
        final result = _findAlipay(nested, depth: depth + 1);
        if (result.isNotEmpty) return result;
      }
    }
    return '';
  }

  static Object? _decodeJsonContainer(Object? value) {
    if (value is! String) return value;
    final trimmed = value.trim();
    if (!(trimmed.startsWith('{') && trimmed.endsWith('}'))) return trimmed;
    try {
      return jsonDecode(trimmed);
    } on FormatException {
      return trimmed;
    }
  }

  static bool _nonEmptyScalar(Object? value) {
    if (value is String) return value.trim().isNotEmpty;
    return value is num && value.toString().trim().isNotEmpty;
  }
}

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
