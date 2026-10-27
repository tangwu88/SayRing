import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/global_commerce.dart';
import '../services/api_client.dart';
import '../services/app_controller.dart';
import '../services/app_payment_bridge.dart';
import 'global_shop_widgets.dart';

class GlobalShopPaymentPage extends StatefulWidget {
  const GlobalShopPaymentPage({
    required this.controller,
    required this.orderId,
    super.key,
  });
  final AppController controller;
  final String orderId;

  @override
  State<GlobalShopPaymentPage> createState() => _GlobalShopPaymentPageState();
}

class _GlobalShopPaymentPageState extends State<GlobalShopPaymentPage>
    with WidgetsBindingObserver {
  late final String? _owner = widget.controller.session?.accountKey;
  Map<String, Object?>? _order;
  GlobalCommerceCapabilities _capabilities =
      GlobalCommerceCapabilities.unavailable;
  AppPaymentProvider? _selected;
  AppPaymentProvider? _launchedProvider;
  final _keys = <AppPaymentProvider, String>{};
  bool _loading = true,
      _paying = false,
      _checking = false,
      _failed = false,
      _closed = false;
  String? _message;
  bool get _current =>
      mounted &&
      !_closed &&
      _owner != null &&
      widget.controller.session?.accountKey == _owner;
  bool get _pending =>
      _order?['status'] == 'PENDING_PAYMENT' &&
      _order?['readOnly'] != true &&
      _order?['allowedActions'] is List &&
      (_order!['allowedActions'] as List).contains('PAY');

  bool _enabled(AppPaymentProvider provider) =>
      widget.controller.canStartGlobalShopPayment &&
      _capabilities.checkoutEnabled &&
      !_capabilities.readOnly &&
      _capabilities.paymentChannels.any(
        (item) =>
            item['channel'] ==
                (provider == AppPaymentProvider.wechat
                    ? 'wechat_app'
                    : 'alipay_app') &&
            item['enabled'] == true &&
            item['environments'] is List &&
            (item['environments'] as List).contains('android'),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_checkOwner);
    unawaited(_load());
  }

  void _checkOwner() {
    if (!mounted || _owner == widget.controller.session?.accountKey) return;
    setState(() {
      _closed = true;
      _order = null;
      _selected = null;
      _keys.clear();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_checkOwner);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await Future.wait([
        widget.controller.loadGlobalShopOrder(widget.orderId),
        widget.controller.loadGlobalCommerceCapabilities(),
      ]);
      if (!_current) return;
      setState(() {
        _order = result[0];
        _capabilities = GlobalCommerceCapabilities.fromJson(result[1]);
        if (_selected == null || !_enabled(_selected!)) {
          _selected = AppPaymentProvider.values.where(_enabled).firstOrNull;
        }
      });
    } catch (_) {
      if (_current) setState(() => _failed = true);
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _order != null && _current) {
      unawaited(_resumePayment());
    }
  }

  Future<void> _resumePayment() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!_current || _paying || _checking) return;
    final result = _launchedProvider == AppPaymentProvider.wechat
        ? await widget.controller.takeWechatPaymentResult()
        : null;
    if (!_current) return;
    if (result != null) _showResult(result);
    await _confirmOrder();
  }

  void _showResult(AppPaymentResult result) {
    if (!_current) return;
    setState(
      () => _message = result.isCancelled
          ? '已取消支付，订单仍可稍后付款'
          : result.isSuccess
          ? '正在确认付款结果，请稍候'
          : '付款尚未完成，请查看订单后重试',
    );
    if (result.isCancelled) _keys.remove(_selected);
  }

  Future<void> _pay() async {
    final provider = _selected;
    if (!_current ||
        _paying ||
        _checking ||
        !_pending ||
        provider == null ||
        !_enabled(provider)) {
      return;
    }
    setState(() {
      _paying = true;
      _message = null;
      _launchedProvider = provider;
    });
    try {
      final result = await widget.controller.startGlobalShopPayment(
        orderId: widget.orderId,
        provider: provider,
        idempotencyKey: _keys.putIfAbsent(
          provider,
          () => 'app-pay-${const Uuid().v4()}',
        ),
      );
      if (!_current) return;
      if (result != null) {
        _showResult(result);
      } else {
        setState(() => _message = '请在微信中完成付款，返回后将更新订单状态');
      }
    } on ApiException catch (error) {
      if (_current) {
        setState(() {
          _launchedProvider = null;
          _message = error.statusCode != null && error.statusCode! >= 500
              ? '支付暂时无法使用，请稍后重试'
              : error.message;
        });
      }
    } catch (_) {
      if (_current) {
        setState(() {
          _launchedProvider = null;
          _message = '支付暂时无法使用，请稍后重试';
        });
      }
    } finally {
      if (_current) setState(() => _paying = false);
    }
    if (_current) await _confirmOrder();
  }

  Future<void> _confirmOrder() async {
    if (!_current || _checking || _paying) return;
    setState(() => _checking = true);
    try {
      for (var attempt = 0; attempt < 4 && _current; attempt++) {
        final order = await widget.controller.loadGlobalShopOrder(
          widget.orderId,
        );
        if (!_current) return;
        setState(() => _order = order);
        if (!_pending) {
          setState(() => _message = '订单状态已更新，请返回查看订单详情');
          break;
        }
        if (attempt < 3) await Future<void>.delayed(const Duration(seconds: 2));
      }
    } catch (_) {
      if (_current) setState(() => _message = '订单状态暂未更新，请稍后刷新查看');
    } finally {
      if (_current) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_closed || _owner == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('订单付款')),
        body: const Center(child: Text('请登录后重新打开订单')),
      );
    }
    final order = _order ?? const <String, Object?>{};
    final cents = commerceCents(order['payableCents']);
    return Scaffold(
      key: const Key('global-shop-payment-page'),
      appBar: AppBar(title: const Text('订单付款')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? Center(
              child: TextButton(onPressed: _load, child: const Text('重新加载订单')),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  commerceText(order['orderNo']),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  globalShopMoney(
                    context,
                    _capabilities.withCurrency(order),
                    amountKey: 'payableCents',
                  ),
                  key: const Key('global-payment-amount'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                if (_pending) ...[
                  for (final provider in AppPaymentProvider.values)
                    Card(
                      child: ListTile(
                        key: Key('global-payment-${provider.name}'),
                        enabled: _enabled(provider) && !_paying && !_checking,
                        leading: Icon(
                          provider == AppPaymentProvider.wechat
                              ? Icons.chat_bubble_outline
                              : Icons.account_balance_wallet_outlined,
                        ),
                        title: Text(
                          provider == AppPaymentProvider.wechat
                              ? '微信支付'
                              : '支付宝支付',
                        ),
                        subtitle: _enabled(provider)
                            ? null
                            : const Text('暂不可用'),
                        trailing: _selected == provider
                            ? const Icon(Icons.check_circle_outline)
                            : null,
                        onTap: _enabled(provider) && !_paying && !_checking
                            ? () => setState(() => _selected = provider)
                            : null,
                      ),
                    ),
                  if (_selected == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('当前暂无可用的支付方式，请稍后再试或联系客服'),
                    ),
                ] else
                  const Text('订单状态已更新，请返回订单详情查看'),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(_message!),
                  ),
                TextButton.icon(
                  onPressed: _paying || _checking ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(_checking ? '正在核对订单状态…' : '刷新订单状态'),
                ),
              ],
            ),
      bottomNavigationBar: !_loading && !_failed && _pending
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton(
                key: const Key('global-payment-submit'),
                onPressed:
                    _selected != null &&
                        !_paying &&
                        !_checking &&
                        cents != null &&
                        cents > 0
                    ? _pay
                    : null,
                child: Text(
                  _paying
                      ? '正在打开支付…'
                      : _checking
                      ? '正在确认订单…'
                      : '确认付款',
                ),
              ),
            )
          : null,
    );
  }
}
