import 'dart:async';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class WechatAuthorization {
  const WechatAuthorization({required this.code, required this.state});

  final String code;
  final String state;
}

abstract interface class WechatAuthBridge {
  /// Null means the user cancelled. Authorization is not an app session.
  Future<WechatAuthorization?> authorize({String? appId});
  Future<void> cancel();
}

class MethodChannelWechatAuthBridge implements WechatAuthBridge {
  MethodChannelWechatAuthBridge({
    MethodChannel? channel,
    this.timeout = const Duration(minutes: 2),
  }) : _channel = channel ?? const MethodChannel('cc.saidian/app_auth');

  final MethodChannel _channel;
  final Duration timeout;
  String? _pendingState;

  @override
  Future<WechatAuthorization?> authorize({String? appId}) async {
    if (_pendingState != null) {
      throw PlatformException(code: 'WECHAT_AUTH_BUSY');
    }
    final state =
        'sd_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}';
    _pendingState = state;
    try {
      final response = await _channel
          .invokeMapMethod<String, Object?>('authorizeWechat', {
            'state': state,
            if (appId?.trim().isNotEmpty == true) 'appId': appId!.trim(),
          })
          .timeout(timeout);
      if (_pendingState != state) return null;
      if (response?['state'] != state) {
        throw PlatformException(code: 'WECHAT_AUTH_INVALID');
      }
      if (response?['cancelled'] == true) return null;
      final code = response?['code'];
      if (code is! String || code.trim().isEmpty || code.length > 1024) {
        throw PlatformException(code: 'WECHAT_AUTH_INVALID');
      }
      return WechatAuthorization(code: code.trim(), state: state);
    } on TimeoutException {
      await cancel();
      throw PlatformException(code: 'WECHAT_AUTH_TIMEOUT');
    } finally {
      if (_pendingState == state) _pendingState = null;
    }
  }

  @override
  Future<void> cancel() async {
    final state = _pendingState;
    _pendingState = null;
    if (state == null) return;
    try {
      await _channel.invokeMethod<void>('cancelWechatAuthorization', {
        'state': state,
      });
    } on PlatformException {
      // Local cancellation still invalidates any delayed native response.
    } on MissingPluginException {
      // Safe during teardown when the Flutter engine has already detached.
    }
  }
}
