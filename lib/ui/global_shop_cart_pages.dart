import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../domain/global_commerce.dart';
import '../l10n/global_locale_controller.dart';
import '../services/api_client.dart';
import '../services/app_controller.dart';
import 'global_shop_widgets.dart';

class GlobalShopCartPage extends StatefulWidget {
  const GlobalShopCartPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<GlobalShopCartPage> createState() => _GlobalShopCartPageState();
}

class _GlobalShopCartPageState extends State<GlobalShopCartPage> {
  Map<String, Object?> _cart = const {};
  GlobalCommerceCapabilities _capabilities =
      GlobalCommerceCapabilities.unavailable;
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;
  int _generation = 0;

  List<Map<String, Object?>> get _items => commerceRows(_cart['items']);
  List<Map<String, Object?>> get _selected => _items
      .where((item) => item['selected'] == true && item['available'] == true)
      .toList(growable: false);
  int get _selectedQuantity => _selected.fold(
    0,
    (total, item) => total + (commerceCents(item['quantity']) ?? 1),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final values = await Future.wait<Object>([
        widget.controller.loadGlobalShopCart(),
        widget.controller.loadGlobalCommerceCapabilities(),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _cart = values[0] as Map<String, Object?>;
        _capabilities = GlobalCommerceCapabilities.fromJson(
          values[1] as Map<String, Object?>,
        );
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _update(
    Map<String, Object?> item, {
    required int quantity,
    required bool selected,
  }) async {
    if (_busy) return;
    final sku = commerceMap(item['sku']);
    final skuId = commerceId(item['skuId'] ?? item['sku_id'] ?? sku['id']);
    final stock = commerceCents(sku['stock']);
    if (skuId.isEmpty || quantity < 1 || (stock != null && quantity > stock)) {
      _message(context.l10n.outOfStock);
      return;
    }
    setState(() => _busy = true);
    try {
      final cart = await widget.controller.updateGlobalShopCartItem(
        skuId: skuId,
        quantity: quantity,
        selected: selected,
      );
      if (mounted) setState(() => _cart = cart);
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map<String, Object?> item) async {
    if (_busy) return;
    final id = commerceId(item['id']);
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      final cart = await widget.controller.removeGlobalShopCartItem(id);
      if (mounted) setState(() => _cart = cart);
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkout() async {
    final items = _selected
        .map((item) {
          final sku = commerceMap(item['sku']);
          return <String, Object?>{
            'skuId': commerceId(item['skuId'] ?? item['sku_id'] ?? sku['id']),
            'quantity': commerceCents(item['quantity']) ?? 1,
            'sku': sku,
            'product': commerceMap(sku['product']),
          };
        })
        .where((item) => commerceId(item['skuId']).isNotEmpty)
        .toList();
    if (items.isEmpty) {
      _message(context.l10n.selectItemsToContinue);
      return;
    }
    final orderId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GlobalShopCheckoutPage(
          controller: widget.controller,
          items: items,
          capabilities: _capabilities,
        ),
      ),
    );
    if (!mounted) return;
    if (orderId?.isNotEmpty == true) {
      _message(context.l10n.orderPlaced);
      await _load();
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-shop-cart-page'),
    appBar: AppBar(title: Text(context.l10n.cart)),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? GlobalShopRetry(onRetry: _load)
        : _items.isEmpty
        ? _EmptyCart(onBrowse: () => Navigator.of(context).pop())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 124),
              children: [for (final item in _items) _cartItem(item)],
            ),
          ),
    bottomNavigationBar: _items.isEmpty
        ? null
        : SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Color(0x16000000), blurRadius: 12),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, _) {
                  final summary = Text(
                    context.l10n.selectedItems(_selectedQuantity),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  );
                  final action = FilledButton(
                    key: const Key('global-cart-checkout'),
                    onPressed: _busy || _selected.isEmpty ? null : _checkout,
                    child: Text(context.l10n.checkout),
                  );
                  if (MediaQuery.textScalerOf(context).scale(16) >= 26) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [summary, const SizedBox(height: 8), action],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: summary),
                      action,
                    ],
                  );
                },
              ),
            ),
          ),
  );

  Widget _cartItem(Map<String, Object?> item) {
    final sku = commerceMap(item['sku']);
    final product = commerceMap(sku['product']);
    final quantity = commerceCents(item['quantity']) ?? 1;
    final stock = commerceCents(sku['stock']);
    final available = item['available'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: item['selected'] == true,
              onChanged: _busy || !available
                  ? null
                  : (value) => _update(
                      item,
                      quantity: quantity,
                      selected: value == true,
                    ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 72,
                child: GlobalShopImage(
                  commerceText(sku['image']).isNotEmpty
                      ? commerceText(sku['image'])
                      : commerceText(product['coverImage']),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commerceText(product['displayName']).isNotEmpty
                        ? commerceText(product['displayName'])
                        : commerceText(product['name']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    commerceText(sku['specification']).isNotEmpty
                        ? commerceText(sku['specification'])
                        : context.l10n.defaultVariant,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    globalShopMoney(
                      context,
                      _capabilities.withCurrency({
                        ...sku,
                        'priceCents': sku['salePriceCents'],
                      }),
                    ),
                    style: const TextStyle(
                      color: Color(0xFFBE092D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton.outlined(
                        visualDensity: VisualDensity.compact,
                        onPressed: _busy || quantity <= 1
                            ? null
                            : () => _update(
                                item,
                                quantity: quantity - 1,
                                selected: item['selected'] == true,
                              ),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$quantity',
                          textAlign: TextAlign.center,
                          semanticsLabel: context.l10n.quantity,
                        ),
                      ),
                      IconButton.outlined(
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            _busy ||
                                !available ||
                                (stock != null && quantity >= stock)
                            ? null
                            : () => _update(
                                item,
                                quantity: quantity + 1,
                                selected: item['selected'] == true,
                              ),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: context.l10n.delete,
                        onPressed: _busy ? null : () => _remove(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  if (!available)
                    Text(
                      context.l10n.outOfStock,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 52),
          const SizedBox(height: 16),
          Text(context.l10n.cartEmpty),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onBrowse,
            child: Text(context.l10n.returnShop),
          ),
        ],
      ),
    ),
  );
}

class GlobalShopCheckoutPage extends StatefulWidget {
  const GlobalShopCheckoutPage({
    required this.controller,
    required this.items,
    required this.capabilities,
    super.key,
  });

  final AppController controller;
  final List<Map<String, Object?>> items;
  final GlobalCommerceCapabilities capabilities;

  @override
  State<GlobalShopCheckoutPage> createState() => _GlobalShopCheckoutPageState();
}

class _GlobalShopCheckoutPageState extends State<GlobalShopCheckoutPage> {
  List<Map<String, Object?>> _addresses = const [];
  List<Map<String, Object?>> _coupons = const [];
  Map<String, Object?>? _address;
  Map<String, Object?>? _coupon;
  Map<String, Object?>? _quote;
  late GlobalCommerceCapabilities _capabilities;
  final _remark = TextEditingController();
  final _points = TextEditingController(text: '0.00');
  bool _loading = true;
  bool _quoting = false;
  bool _quoteFailed = false;
  bool _submitting = false;
  bool _submissionUncertain = false;
  bool _failed = false;
  int _quoteGeneration = 0;
  String? _idempotencyKey;
  Map<String, Object?>? _frozenRequest;

  @override
  void initState() {
    super.initState();
    _capabilities = widget.capabilities;
    unawaited(_load());
  }

  @override
  void dispose() {
    _remark.dispose();
    _points.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final values = await Future.wait<Object?>([
        widget.controller.loadGlobalShopAddresses(),
        widget.controller.loadGlobalShopCoupons(),
        widget.controller.loadGlobalCommerceCapabilities(),
        _readDraft(),
      ]);
      if (!mounted) return;
      _addresses = values[0] as List<Map<String, Object?>>;
      _coupons = values[1] as List<Map<String, Object?>>;
      _capabilities = GlobalCommerceCapabilities.fromJson(
        values[2] as Map<String, Object?>,
      );
      _address = _addresses.cast<Map<String, Object?>?>().firstWhere(
        (item) => item?['isDefault'] == true,
        orElse: () => _addresses.isEmpty ? null : _addresses.first,
      );
      if (!_restoreDraft(commerceMap(values[3]))) await _refreshQuote();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, Object?>> get _orderItems => widget.items
      .map(
        (item) => <String, Object?>{
          'skuId': commerceId(item['skuId']),
          'quantity': commerceCents(item['quantity']) ?? 1,
        },
      )
      .where((item) => commerceId(item['skuId']).isNotEmpty)
      .toList(growable: false);

  String get _draftKey {
    final canonical =
        _orderItems.map((row) => Map<String, Object?>.from(row)).toList()..sort(
          (left, right) =>
              commerceId(left['skuId']).compareTo(commerceId(right['skuId'])),
        );
    return 'checkout:${sha256.convert(utf8.encode(jsonEncode(canonical)))}';
  }

  Future<Map<String, Object?>?> _readDraft() async {
    try {
      return widget.controller.readGlobalShopDraft(_draftKey);
    } catch (_) {
      return null;
    }
  }

  bool _restoreDraft(Map<String, Object?> saved) {
    final request = commerceMap(saved['request']);
    final savedItems =
        commerceRows(request['items'])
            .map(
              (row) => <String, Object?>{
                'skuId': commerceId(row['skuId']),
                'quantity': commerceCents(row['quantity']) ?? 0,
              },
            )
            .toList()
          ..sort(
            (left, right) =>
                commerceId(left['skuId']).compareTo(commerceId(right['skuId'])),
          );
    final expectedItems =
        _orderItems.map((row) => Map<String, Object?>.from(row)).toList()..sort(
          (left, right) =>
              commerceId(left['skuId']).compareTo(commerceId(right['skuId'])),
        );
    final key = commerceText(request['idempotencyKey']);
    final fingerprint = commerceText(request['expectedQuote']);
    final addressId = commerceId(request['addressId']);
    if (saved['version'] != 1 ||
        !RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(key) ||
        !RegExp(r'^q1:[a-f0-9]{64}$').hasMatch(fingerprint) ||
        addressId.isEmpty ||
        jsonEncode(savedItems) != jsonEncode(expectedItems)) {
      return false;
    }
    _frozenRequest = request;
    _idempotencyKey = key;
    _submissionUncertain = true;
    _quote = commerceMap(saved['quote']);
    _address = _addresses.cast<Map<String, Object?>?>().firstWhere(
      (row) => commerceId(row?['id']) == addressId,
      orElse: () => <String, Object?>{'id': addressId},
    );
    final couponId = commerceId(request['couponClaimId']);
    _coupon = couponId.isEmpty
        ? null
        : _coupons.cast<Map<String, Object?>?>().firstWhere(
            (row) => commerceId(row?['id']) == couponId,
            orElse: () => null,
          );
    _points.text = ((commerceCents(request['pointCents']) ?? 0) / 100)
        .toStringAsFixed(2);
    _remark.text = commerceText(request['buyerRemark']);
    return true;
  }

  Future<void> _clearDraft() async {
    try {
      await widget.controller.clearGlobalShopDraft(_draftKey);
    } catch (_) {
      // The server idempotency key still prevents a duplicate if secure
      // storage is temporarily unavailable during cleanup.
    }
  }

  int _pointCents() {
    final value = double.tryParse(_points.text.trim());
    return value == null || !value.isFinite || value < 0
        ? 0
        : (value * 100).round();
  }

  Future<void> _refreshQuote() async {
    final address = _address;
    if (address == null || _orderItems.isEmpty) {
      if (mounted) {
        setState(() {
          _quote = null;
          _quoteFailed = false;
        });
      }
      return;
    }
    final generation = ++_quoteGeneration;
    setState(() {
      _quoting = true;
      _quote = null;
      _quoteFailed = false;
    });
    try {
      final result = await widget.controller.previewGlobalShopOrder(
        addressId: commerceId(address['id']),
        items: _orderItems,
        couponClaimId: _coupon == null ? null : commerceId(_coupon!['id']),
        pointCents: _pointCents(),
        buyerRemark: _remark.text,
      );
      final quote = commerceMap(result['quote']);
      if (quote.isEmpty) throw StateError('missing quote');
      if (mounted && generation == _quoteGeneration) {
        setState(() => _quote = quote);
      }
    } catch (_) {
      if (mounted && generation == _quoteGeneration) {
        setState(() {
          _quote = null;
          _quoteFailed = true;
        });
      }
    } finally {
      if (mounted && generation == _quoteGeneration) {
        setState(() => _quoting = false);
      }
    }
  }

  Future<void> _chooseAddress() async {
    final selected = await Navigator.of(context).push<Map<String, Object?>>(
      MaterialPageRoute(
        builder: (_) => GlobalShopAddressesPage(
          controller: widget.controller,
          selectMode: true,
          capabilities: _capabilities,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _address = selected);
    await _refreshQuote();
  }

  Future<void> _placeOrder() async {
    if (_submitting ||
        (_frozenRequest == null && (_quote == null || _address == null))) {
      return;
    }
    setState(() => _submitting = true);
    var request = _frozenRequest;
    if (request == null) {
      final fingerprint = commerceText(_quote!['fingerprint']);
      if (!RegExp(r'^q1:[a-f0-9]{64}$').hasMatch(fingerprint)) {
        setState(() => _submitting = false);
        _message(context.l10n.checkoutPriceChanged);
        await _refreshQuote();
        return;
      }
      final key = _idempotencyKey ??= 'app-${const Uuid().v4()}';
      request = <String, Object?>{
        'addressId': commerceId(_address!['id']),
        'items': _orderItems,
        'expectedQuote': fingerprint,
        'idempotencyKey': key,
        if (_coupon != null) 'couponClaimId': commerceId(_coupon!['id']),
        'pointCents': _pointCents(),
        if (_remark.text.trim().isNotEmpty) 'buyerRemark': _remark.text.trim(),
      };
      try {
        await widget.controller.writeGlobalShopDraft(_draftKey, {
          'version': 1,
          'request': request,
          'quote': _quote,
        });
        _frozenRequest = request;
      } catch (_) {
        _idempotencyKey = null;
        if (mounted) {
          setState(() => _submitting = false);
          _message(context.l10n.serviceUnavailable);
        }
        return;
      }
    }
    try {
      final order = await widget.controller.placeGlobalShopOrder(
        addressId: commerceId(request['addressId']),
        items: commerceRows(request['items']),
        expectedQuote: commerceText(request['expectedQuote']),
        idempotencyKey: commerceText(request['idempotencyKey']),
        couponClaimId: commerceId(request['couponClaimId']).isEmpty
            ? null
            : commerceId(request['couponClaimId']),
        pointCents: commerceCents(request['pointCents']) ?? 0,
        buyerRemark: commerceText(request['buyerRemark']),
      );
      final id = commerceId(order['id']);
      if (id.isEmpty) throw StateError('missing order');
      await _clearDraft();
      if (mounted) Navigator.of(context).pop(id);
    } on ApiException catch (error) {
      final deterministic =
          error.code == 'quote_changed' ||
          (error.statusCode != null &&
              error.statusCode! >= 400 &&
              error.statusCode! < 500 &&
              error.code != 'order_in_progress');
      if (deterministic) {
        _idempotencyKey = null;
        _frozenRequest = null;
        await _clearDraft();
        if (mounted) {
          setState(() => _submissionUncertain = false);
          _message(
            error.code == 'quote_changed'
                ? context.l10n.checkoutPriceChanged
                : context.l10n.serviceUnavailable,
          );
        }
        if (error.code == 'quote_changed') await _refreshQuote();
      } else if (mounted) {
        setState(() => _submissionUncertain = true);
        _message(context.l10n.orderSubmissionUncertain);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submissionUncertain = true);
        _message(context.l10n.orderSubmissionUncertain);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    _ => 'android',
  };

  bool get _canPlaceOrder =>
      !_submitting &&
      !_quoting &&
      (_frozenRequest != null || (_address != null && _quote != null)) &&
      _capabilities.checkoutEnabled &&
      !_capabilities.readOnly &&
      _capabilities.hasNativePayment(_platform);

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-shop-checkout-page'),
    appBar: AppBar(title: Text(context.l10n.confirmOrder)),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? GlobalShopRetry(onRetry: _load)
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
            children: [
              _addressCard(),
              const SizedBox(height: 12),
              _itemsCard(),
              const SizedBox(height: 12),
              _benefitsCard(),
              const SizedBox(height: 12),
              _totalsCard(),
              const SizedBox(height: 12),
              if (_submissionUncertain)
                GlobalShopNotice(text: context.l10n.orderSubmissionUncertain)
              else if (!_capabilities.checkoutEnabled || _capabilities.readOnly)
                GlobalShopNotice(text: context.l10n.marketUnavailable)
              else if (!_capabilities.hasNativePayment(_platform))
                GlobalShopNotice(text: context.l10n.paymentUnavailable),
            ],
          ),
    bottomNavigationBar: _loading || _failed
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                key: const Key('global-place-order'),
                onPressed: _canPlaceOrder ? _placeOrder : null,
                child: Text(
                  _submitting
                      ? context.l10n.loading
                      : _submissionUncertain
                      ? context.l10n.retry
                      : context.l10n.placeOrder,
                ),
              ),
            ),
          ),
  );

  Widget _addressCard() => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _submitting || _submissionUncertain ? null : _chooseAddress,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: _address == null
                  ? Text(context.l10n.chooseDeliveryAddress)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${commerceText(_address!['name'])}  ${commerceText(_address!['mobile'])}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(_addressText(_address!)),
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );

  Widget _itemsCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.productInfo,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final item in widget.items) _checkoutItem(item),
        ],
      ),
    ),
  );

  Widget _checkoutItem(Map<String, Object?> item) {
    final sku = commerceMap(item['sku']);
    final product = commerceMap(item['product']);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox.square(
        dimension: 52,
        child: GlobalShopImage(
          commerceText(sku['image']).isNotEmpty
              ? commerceText(sku['image'])
              : commerceText(product['coverImage']),
        ),
      ),
      title: Text(
        commerceText(product['displayName']).isNotEmpty
            ? commerceText(product['displayName'])
            : commerceText(product['name']),
      ),
      subtitle: Text(
        '${commerceText(sku['specification']).isEmpty ? context.l10n.defaultVariant : commerceText(sku['specification'])} × ${commerceCents(item['quantity']) ?? 1}',
      ),
    );
  }

  Widget _benefitsCard() {
    final available = _coupons.where((row) => row['usedAt'] == null).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.coupons,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _coupon == null ? null : commerceId(_coupon!['id']),
              decoration: InputDecoration(labelText: context.l10n.ownedCoupons),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(context.l10n.noCoupon),
                ),
                for (final claim in available)
                  DropdownMenuItem<String?>(
                    value: commerceId(claim['id']),
                    child: Text(
                      commerceText(commerceMap(claim['coupon'])['name']),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _submitting || _submissionUncertain
                  ? null
                  : (id) {
                      setState(() {
                        _coupon = id == null
                            ? null
                            : available.firstWhere(
                                (row) => commerceId(row['id']) == id,
                              );
                      });
                      unawaited(_refreshQuote());
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _points,
              enabled: !_submitting && !_submissionUncertain,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: context.l10n.pointsToUse),
              onSubmitted: (_) => _refreshQuote(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remark,
              enabled: !_submitting && !_submissionUncertain,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.l10n.orderNote,
                hintText: context.l10n.noteToSeller,
              ),
              onSubmitted: (_) => _refreshQuote(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting || _quoting || _submissionUncertain
                    ? null
                    : _refreshQuote,
                child: Text(context.l10n.refreshOrderTotal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalsCard() {
    final quote = _quote;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _quoting
            ? const Center(child: CircularProgressIndicator())
            : quote == null
            ? _quoteFailed
                  ? Column(
                      children: [
                        Text(context.l10n.serviceUnavailable),
                        TextButton(
                          onPressed: _submissionUncertain
                              ? null
                              : _refreshQuote,
                          child: Text(context.l10n.retry),
                        ),
                      ],
                    )
                  : Text(context.l10n.chooseAddressForTotal)
            : Column(
                children: [
                  _moneyLine(
                    context.l10n.itemsSubtotal,
                    quote,
                    'subtotalCents',
                  ),
                  _moneyLine(
                    context.l10n.discount,
                    quote,
                    'couponDiscountCents',
                    minus: true,
                  ),
                  _moneyLine(
                    context.l10n.points,
                    quote,
                    'pointDiscountCents',
                    minus: true,
                  ),
                  _moneyLine(context.l10n.shippingFee, quote, 'shippingCents'),
                  const Divider(),
                  _moneyLine(
                    context.l10n.amountDue,
                    quote,
                    'payableCents',
                    strong: true,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _moneyLine(
    String label,
    Map<String, Object?> quote,
    String key, {
    bool minus = false,
    bool strong = false,
  }) {
    final cents = commerceCents(quote[key]) ?? 0;
    final text = globalShopMoney(
      context,
      _capabilities.withCurrency({...quote, 'priceCents': cents}),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '${minus && cents > 0 ? '−' : ''}$text',
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              fontSize: strong ? 18 : null,
              color: strong ? const Color(0xFFBE092D) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class GlobalShopAddressesPage extends StatefulWidget {
  const GlobalShopAddressesPage({
    required this.controller,
    this.selectMode = false,
    this.capabilities,
    super.key,
  });

  final AppController controller;
  final bool selectMode;
  final GlobalCommerceCapabilities? capabilities;

  @override
  State<GlobalShopAddressesPage> createState() =>
      _GlobalShopAddressesPageState();
}

class _GlobalShopAddressesPageState extends State<GlobalShopAddressesPage> {
  List<Map<String, Object?>> _items = const [];
  late GlobalCommerceCapabilities _capabilities;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _capabilities =
        widget.capabilities ?? GlobalCommerceCapabilities.unavailable;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final items = await widget.controller.loadGlobalShopAddresses();
      var capabilities = _capabilities;
      if (widget.capabilities == null) {
        try {
          capabilities = GlobalCommerceCapabilities.fromJson(
            await widget.controller.loadGlobalCommerceCapabilities(),
          );
        } catch (_) {
          // Existing addresses remain readable when market capabilities are
          // temporarily unavailable. Creation and editing stay disabled.
        }
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _capabilities = capabilities;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, Object?>? item]) async {
    if (_capabilities.countryCodes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.marketUnavailable)));
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GlobalShopAddressEditPage(
          controller: widget.controller,
          address: item,
          capabilities: _capabilities,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _delete(Map<String, Object?> item) async {
    final id = commerceId(item['id']);
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteAddressPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.deleteGlobalShopAddress(id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.serviceUnavailable)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-shop-addresses-page'),
    appBar: AppBar(
      title: Text(context.l10n.deliveryAddresses),
      actions: [
        IconButton(
          tooltip: context.l10n.newAddress,
          onPressed: _loading || _capabilities.countryCodes.isEmpty
              ? null
              : _edit,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? GlobalShopRetry(onRetry: _load)
        : _items.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _capabilities.countryCodes.isEmpty
                  ? GlobalShopNotice(text: context.l10n.marketUnavailable)
                  : FilledButton.icon(
                      onPressed: _edit,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: Text(context.l10n.newAddress),
                    ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_capabilities.countryCodes.isEmpty) ...[
                  GlobalShopNotice(text: context.l10n.marketUnavailable),
                  const SizedBox(height: 12),
                ],
                for (final item in _items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: widget.selectMode
                          ? () => Navigator.of(context).pop(item)
                          : _capabilities.countryCodes.isEmpty
                          ? null
                          : () => _edit(item),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${commerceText(item['name'])}  ${commerceText(item['mobile'])}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(_addressText(item)),
                                  if (item['isDefault'] == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          context.l10n.defaultAddress,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!widget.selectMode)
                              PopupMenuButton<String>(
                                onSelected: (value) => value == 'edit'
                                    ? _edit(item)
                                    : _delete(item),
                                itemBuilder: (_) => [
                                  if (_capabilities.countryCodes.isNotEmpty)
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(context.l10n.editAddress),
                                    ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(context.l10n.delete),
                                  ),
                                ],
                              )
                            else
                              const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}

class GlobalShopAddressEditPage extends StatefulWidget {
  const GlobalShopAddressEditPage({
    required this.controller,
    required this.capabilities,
    this.address,
    super.key,
  });

  final AppController controller;
  final GlobalCommerceCapabilities capabilities;
  final Map<String, Object?>? address;

  @override
  State<GlobalShopAddressEditPage> createState() =>
      _GlobalShopAddressEditPageState();
}

class _GlobalShopAddressEditPageState extends State<GlobalShopAddressEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _province;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _detail;
  late final TextEditingController _postalCode;
  late String _country;
  late bool _isDefault;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final address = widget.address ?? const <String, Object?>{};
    final countries = widget.capabilities.countryCodes;
    _country = commerceText(address['countryCode']);
    if (_country.isEmpty && countries.isNotEmpty) {
      _country = countries.first;
    }
    _name = TextEditingController(text: commerceText(address['name']));
    final savedPhone = commerceText(
      address['mobile'],
    ).replaceAll(RegExp(r'[\s()-]'), '');
    _phone = TextEditingController(
      text: savedPhone.startsWith('+86') ? savedPhone.substring(3) : savedPhone,
    );
    _province = TextEditingController(text: commerceText(address['province']));
    _city = TextEditingController(text: commerceText(address['city']));
    _district = TextEditingController(text: commerceText(address['district']));
    _detail = TextEditingController(text: commerceText(address['detail']));
    _postalCode = TextEditingController(
      text: commerceText(address['postalCode']),
    );
    _isDefault = address['isDefault'] == true;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _province,
      _city,
      _district,
      _detail,
      _postalCode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _normalizedPhone() {
    final raw = _phone.text.replaceAll(RegExp(r'[\s()-]'), '');
    return RegExp(r'^1\d{10}$').hasMatch(raw) ? '+86$raw' : raw;
  }

  Future<void> _save() async {
    if (_busy ||
        !widget.capabilities.countryCodes.contains(_country) ||
        !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.controller.saveGlobalShopAddress({
        'countryCode': _country,
        'name': _name.text.trim(),
        'mobile': _normalizedPhone(),
        'province': _province.text.trim(),
        'city': _city.text.trim(),
        'district': _district.text.trim(),
        'detail': _detail.text.trim(),
        'postalCode': _postalCode.text.trim(),
        'isDefault': _isDefault,
      }, id: commerceId(widget.address?['id']));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.serviceUnavailable)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? value) =>
      value?.trim().isEmpty != false ? context.l10n.requiredField : null;

  @override
  Widget build(BuildContext context) {
    final supportedCountries = widget.capabilities.countryCodes;
    final countries = <String>{
      ...supportedCountries,
      if (_country.isNotEmpty) _country,
    }.toList(growable: false);
    final marketSupported = supportedCountries.contains(_country);
    return Scaffold(
      key: const Key('global-shop-address-edit-page'),
      appBar: AppBar(
        title: Text(
          widget.address == null
              ? context.l10n.newAddress
              : context.l10n.editAddress,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (countries.isEmpty)
              GlobalShopNotice(text: context.l10n.marketUnavailable)
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _country,
                decoration: InputDecoration(
                  labelText: context.l10n.countryRegion,
                ),
                items: [
                  for (final country in countries)
                    DropdownMenuItem(value: country, child: Text(country)),
                ],
                onChanged: _busy || supportedCountries.isEmpty
                    ? null
                    : (value) => setState(() => _country = value ?? _country),
              ),
            if (_country.isNotEmpty && !marketSupported) ...[
              const SizedBox(height: 8),
              GlobalShopNotice(text: context.l10n.marketUnavailable),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: context.l10n.recipient),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: InputDecoration(
                labelText: context.l10n.phoneNumber,
                hintText: '请输入11位手机号',
              ),
              validator: (value) =>
                  RegExp(
                    r'^1\d{10}$',
                  ).hasMatch(value?.replaceAll(RegExp(r'[\s()-]'), '') ?? '')
                  ? null
                  : context.l10n.invalidPhone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _province,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: context.l10n.province),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: context.l10n.city),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _district,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: context.l10n.district),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _detail,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.l10n.streetAddress,
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _postalCode,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: context.l10n.postalCode),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.defaultAddress),
              value: _isDefault,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _isDefault = value),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const Key('global-address-save'),
            onPressed: _busy || !marketSupported ? null : _save,
            child: Text(_busy ? context.l10n.loading : context.l10n.save),
          ),
        ),
      ),
    );
  }
}

String _addressText(Map<String, Object?> address) => [
  commerceText(address['countryCode']),
  commerceText(address['province']),
  commerceText(address['city']),
  commerceText(address['district']),
  commerceText(address['detail']),
  commerceText(address['postalCode']),
].where((value) => value.isNotEmpty).join(' ');
