import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live payment endpoint returns APP payment contracts', (
    tester,
  ) async {
    final vault = SecureSessionVault();
    final session = await vault.readSession();
    expect(session, isNotNull, reason: '请先在真机 App 登录后再执行支付契约测试');

    await _probeProductionApiNetwork();

    final httpClient = _testHttpClient();
    final api = SaydianApiClient(vault, client: IOClient(httpClient));
    addTearDown(() => httpClient.close(force: true));
    final orders = await api.getOrders(status: 0);
    expect(orders, isNotEmpty, reason: '当前账号没有待付款订单，无法验证支付参数接口');

    final order = orders.firstWhere(
      (value) => _positiveInt(value['id'] ?? value['order_id']) != null,
      orElse: () => const <String, Object?>{},
    );
    final orderId = _positiveInt(order['id'] ?? order['order_id']);
    final money = _positiveNumber(
      order['order_money'] ?? order['pay_money'] ?? order['product_money'],
    );
    expect(orderId, isNotNull, reason: '待付款订单没有有效订单 ID');
    expect(money, isNotNull, reason: '待付款订单没有有效应付金额');

    for (final provider in const ['wechat', 'alipay']) {
      final response = await api.createShopPayment(
        provider: provider,
        orderId: orderId!,
        money: money!,
      );
      final config = response['config'];
      debugPrint(
        'PAYMENT_CONTRACT_QA:provider=$provider '
        'responseKeys=${response.keys.toList()..sort()} '
        'configType=${config.runtimeType} '
        'configKeys=${_safeMapKeys(config)}',
      );
      expect(config, isNotNull, reason: '$provider 支付接口成功响应但未返回 config');
      if (provider == 'wechat') {
        expect(
          _safeMapKeys(config),
          containsAll(<String>[
            'appid',
            'partnerid',
            'prepayid',
            'noncestr',
            'timestamp',
            'sign',
          ]),
          reason: '微信 APP 支付签名字段不完整',
        );
      } else {
        expect(
          _containsSignedOrder(config),
          isTrue,
          reason: '支付宝 APP 支付未返回服务端签名 orderString',
        );
      }
    }
  });
}

Future<void> _probeProductionApiNetwork() async {
  const proxy = String.fromEnvironment('SAIDIAN_TEST_HTTP_PROXY');
  const directIp = String.fromEnvironment('SAIDIAN_TEST_API_IP');
  try {
    if (proxy.isEmpty && directIp.isEmpty) {
      final addresses = await InternetAddress.lookup('app.saydian.cn');
      debugPrint(
        'PAYMENT_NETWORK_QA:dns=${addresses.map((value) => value.address).join(',')}',
      );
    } else if (proxy.isNotEmpty) {
      debugPrint('PAYMENT_NETWORK_QA:usingUsbProxy=true');
    } else {
      debugPrint('PAYMENT_NETWORK_QA:usingPinnedTestRoute=true');
    }
    final client = _testHttpClient();
    try {
      final request = await client.getUrl(Uri.parse('https://app.saydian.cn/'));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      debugPrint('PAYMENT_NETWORK_QA:httpsStatus=${response.statusCode}');
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }
  } catch (error) {
    debugPrint(
      'PAYMENT_NETWORK_QA:errorType=${error.runtimeType} error=$error',
    );
    rethrow;
  }
}

HttpClient _testHttpClient() {
  const proxy = String.fromEnvironment('SAIDIAN_TEST_HTTP_PROXY');
  const directIp = String.fromEnvironment('SAIDIAN_TEST_API_IP');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  if (proxy.isNotEmpty) {
    client.findProxy = (uri) => 'PROXY $proxy';
  } else if (directIp.isNotEmpty) {
    client.findProxy = (uri) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      final port = uri.hasPort ? uri.port : 443;
      final raw = await Socket.startConnect(InternetAddress(directIp), port);
      final secure = raw.socket.then<Socket>(
        (socket) => SecureSocket.secure(socket, host: uri.host),
      );
      return ConnectionTask.fromSocket(secure, raw.cancel);
    };
  }
  return client;
}

int? _positiveInt(Object? value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : null;
}

num? _positiveNumber(Object? value) {
  final parsed = value is num ? value : num.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : null;
}

List<String> _safeMapKeys(Object? value) {
  if (value is! Map) return const <String>[];
  return value.keys.map((key) => '$key').toList()..sort();
}

bool _containsSignedOrder(Object? value) {
  if (value is String) return value.trim().isNotEmpty;
  if (value is! Map) return false;
  for (final key in const [
    'config',
    'orderInfo',
    'order_info',
    'orderString',
    'order_string',
    'pay_info',
  ]) {
    if (_containsSignedOrder(value[key])) return true;
  }
  return false;
}
