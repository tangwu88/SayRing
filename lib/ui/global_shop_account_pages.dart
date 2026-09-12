import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/global_commerce.dart';
import '../l10n/global_locale_controller.dart';
import '../services/api_client.dart';
import '../services/app_controller.dart';
import 'global_shop_cart_pages.dart';
import 'global_shop_widgets.dart';

typedef GlobalProductOpener = void Function(BuildContext context, String id);

class GlobalShopAccountPage extends StatelessWidget {
  const GlobalShopAccountPage({
    required this.controller,
    required this.openProduct,
    super.key,
  });

  final AppController controller;
  final GlobalProductOpener openProduct;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-shop-account-page'),
    appBar: AppBar(title: Text(context.l10n.shopAccount)),
    body: !controller.isAuthenticated
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                context.l10n.signInToShopHint,
                textAlign: TextAlign.center,
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AccountTile(
                icon: Icons.receipt_long_outlined,
                title: context.l10n.myOrders,
                onTap: () => _push(
                  context,
                  GlobalShopOrdersPage(
                    controller: controller,
                    openProduct: openProduct,
                  ),
                ),
              ),
              _AccountTile(
                icon: Icons.location_on_outlined,
                title: context.l10n.deliveryAddresses,
                onTap: () => _push(
                  context,
                  GlobalShopAddressesPage(controller: controller),
                ),
              ),
              _AccountTile(
                icon: Icons.favorite_border,
                title: context.l10n.favorites,
                onTap: () => _push(
                  context,
                  GlobalShopFavoritesPage(
                    controller: controller,
                    openProduct: openProduct,
                  ),
                ),
              ),
              _AccountTile(
                icon: Icons.confirmation_number_outlined,
                title: context.l10n.coupons,
                onTap: () => _push(
                  context,
                  GlobalShopCouponsPage(controller: controller),
                ),
              ),
              _AccountTile(
                icon: Icons.stars_outlined,
                title: context.l10n.points,
                onTap: () => _push(
                  context,
                  GlobalShopPointsPage(controller: controller),
                ),
              ),
              _AccountTile(
                icon: Icons.help_outline,
                title: context.l10n.helpCenter,
                onTap: () => _push(context, const GlobalShopHelpPage()),
              ),
            ],
          ),
  );

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      minTileHeight: 60,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class GlobalShopFavoritesPage extends StatefulWidget {
  const GlobalShopFavoritesPage({
    required this.controller,
    required this.openProduct,
    super.key,
  });

  final AppController controller;
  final GlobalProductOpener openProduct;

  @override
  State<GlobalShopFavoritesPage> createState() =>
      _GlobalShopFavoritesPageState();
}

class _GlobalShopFavoritesPageState extends State<GlobalShopFavoritesPage> {
  List<Map<String, Object?>> _items = const [];
  GlobalCommerceCapabilities _capabilities =
      GlobalCommerceCapabilities.unavailable;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final values = await Future.wait<Object>([
        widget.controller.loadGlobalShopFavorites(),
        widget.controller.loadGlobalCommerceCapabilities(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = values[0] as List<Map<String, Object?>>;
        _capabilities = GlobalCommerceCapabilities.fromJson(
          values[1] as Map<String, Object?>,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(Map<String, Object?> item) async {
    final id = commerceId(item['id']);
    if (id.isEmpty) return;
    try {
      await widget.controller.setGlobalShopFavorite(id, false);
      if (mounted) {
        setState(() => _items = _items.where((row) => row != item).toList());
      }
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-shop-favorites-page'),
    appBar: AppBar(title: Text(context.l10n.favorites)),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? GlobalShopRetry(onRetry: _load)
        : _items.isEmpty
        ? Center(child: Text(context.l10n.noFavorites))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (_, index) {
                final item = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    minTileHeight: 88,
                    leading: SizedBox.square(
                      dimension: 64,
                      child: GlobalShopImage(commerceText(item['coverImage'])),
                    ),
                    title: Text(
                      commerceText(item['displayName']).isNotEmpty
                          ? commerceText(item['displayName'])
                          : commerceText(item['name']),
                    ),
                    subtitle: Text(
                      globalShopMoney(
                        context,
                        _capabilities.withCurrency(item),
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: context.l10n.delete,
                      onPressed: () => _remove(item),
                      icon: const Icon(Icons.favorite),
                    ),
                    onTap: () {
                      final id = commerceId(item['id']);
                      if (id.isNotEmpty) widget.openProduct(context, id);
                    },
                  ),
                );
              },
            ),
          ),
  );
}

class GlobalShopCouponsPage extends StatefulWidget {
  const GlobalShopCouponsPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<GlobalShopCouponsPage> createState() => _GlobalShopCouponsPageState();
}

class _GlobalShopCouponsPageState extends State<GlobalShopCouponsPage> {
  final _code = TextEditingController();
  List<Map<String, Object?>> _owned = const [];
  List<Map<String, Object?>> _available = const [];
  bool _loading = true;
  bool _busy = false;
  bool _loadingMore = false;
  bool _failed = false;
  int _availablePage = 1;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final values = await Future.wait<Object>([
        widget.controller.loadGlobalShopCoupons(),
        widget.controller.loadGlobalShopAvailableCoupons(),
      ]);
      if (!mounted) return;
      setState(() {
        _owned = values[0] as List<Map<String, Object?>>;
        final available = values[1] as Map<String, Object?>;
        _available = commerceRows(available['items']);
        _availablePage = 1;
        _hasMore = commerceMap(available['pagination'])['hasMore'] == true;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _availablePage + 1;
      final value = await widget.controller.loadGlobalShopAvailableCoupons(
        page: next,
      );
      if (!mounted) return;
      setState(() {
        _available = [..._available, ...commerceRows(value['items'])];
        _availablePage = next;
        _hasMore = commerceMap(value['pagination'])['hasMore'] == true;
      });
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _claim(String id) async {
    if (_busy || id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.controller.claimGlobalShopCoupon(id);
      if (mounted) _message(context.l10n.claimed);
      await _load();
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeem() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{4,32}$').hasMatch(code)) {
      _message(context.l10n.invalidCouponCode);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.controller.claimGlobalShopCouponCode(code);
      _code.clear();
      if (mounted) _message(context.l10n.claimed);
      await _load();
    } catch (error) {
      final invalid =
          error is ApiException &&
          {400, 404, 409, 422}.contains(error.statusCode);
      if (mounted) {
        _message(
          invalid
              ? context.l10n.invalidCouponCode
              : context.l10n.serviceUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-shop-coupons-page'),
    appBar: AppBar(title: Text(context.l10n.coupons)),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? GlobalShopRetry(onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('global-coupon-code'),
                        controller: _code,
                        enabled: !_busy,
                        maxLength: 32,
                        decoration: InputDecoration(
                          labelText: context.l10n.couponCode,
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy ? null : _redeem,
                      child: Text(context.l10n.redeem),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.ownedCoupons,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_owned.isEmpty) Text(context.l10n.noCoupons),
                for (final claim in _owned)
                  _CouponCard(
                    coupon: commerceMap(claim['coupon']),
                    claimed: true,
                  ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.availableCoupons,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_available.isEmpty) Text(context.l10n.noCoupons),
                for (final coupon in _available)
                  _CouponCard(
                    coupon: coupon,
                    claimed: coupon['claimed'] == true,
                    onClaim:
                        _busy ||
                            coupon['claimed'] == true ||
                            coupon['available'] != true
                        ? null
                        : () => _claim(commerceId(coupon['id'])),
                  ),
                if (_hasMore)
                  OutlinedButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(
                      _loadingMore
                          ? context.l10n.loading
                          : context.l10n.globalShopLoadMore,
                    ),
                  ),
              ],
            ),
          ),
  );
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupon,
    required this.claimed,
    this.onClaim,
  });

  final Map<String, Object?> coupon;
  final bool claimed;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: const Icon(Icons.confirmation_number_outlined),
      title: Text(commerceText(coupon['name'])),
      subtitle: Text(
        '${globalShopDate(context, coupon['validFrom'])} – ${globalShopDate(context, coupon['validUntil'])}',
      ),
      trailing: onClaim != null
          ? TextButton(onPressed: onClaim, child: Text(context.l10n.claim))
          : Chip(
              label: Text(
                claimed ? context.l10n.claimed : context.l10n.unavailable,
              ),
            ),
    ),
  );
}

class GlobalShopPointsPage extends StatefulWidget {
  const GlobalShopPointsPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<GlobalShopPointsPage> createState() => _GlobalShopPointsPageState();
}

class _GlobalShopPointsPageState extends State<GlobalShopPointsPage> {
  Map<String, Object?>? _data;
  List<Map<String, Object?>> _items = const [];
  GlobalCommerceCapabilities _capabilities =
      GlobalCommerceCapabilities.unavailable;
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;
  int _page = 1;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _loadingMore || !_hasMore)) return;
    final nextPage = more ? _page + 1 : 1;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _failed = false;
      }
    });
    try {
      final values = await Future.wait<Object>([
        widget.controller.loadGlobalShopPoints(page: nextPage),
        if (!more) widget.controller.loadGlobalCommerceCapabilities(),
      ]);
      if (!mounted) return;
      final value = values[0] as Map<String, Object?>;
      final rows = commerceRows(value['items']);
      final pagination = commerceMap(value['pagination']);
      setState(() {
        _data = value;
        _items = more ? [..._items, ...rows] : rows;
        _page = nextPage;
        _hasMore = pagination['hasMore'] == true;
        if (!more) {
          _capabilities = GlobalCommerceCapabilities.fromJson(
            values[1] as Map<String, Object?>,
          );
        }
      });
    } catch (_) {
      if (mounted && !more) setState(() => _failed = true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      key: const Key('global-shop-points-page'),
      appBar: AppBar(title: Text(context.l10n.points)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed || data == null
          ? GlobalShopRetry(onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(context.l10n.pointsBalance),
                          const SizedBox(height: 8),
                          Text(
                            data['verified'] == true &&
                                    commerceCents(data['balanceCents']) != null
                                ? globalShopMoney(
                                    context,
                                    _capabilities.withCurrency({
                                      'priceCents': data['balanceCents'],
                                    }),
                                  )
                                : context.l10n.pointsUnavailable,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty) Text(context.l10n.noData),
                  for (final item in _items)
                    ListTile(
                      leading: Icon(
                        (commerceCents(item['deltaCents']) ?? 0) >= 0
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                      ),
                      title: Text(
                        _pointsLedgerLabel(context, commerceText(item['type'])),
                      ),
                      subtitle: Text(
                        globalShopDate(context, item['createdAt']),
                      ),
                      trailing: Text(
                        '${(commerceCents(item['deltaCents']) ?? 0) >= 0 ? '+' : '−'}${globalShopMoney(context, _capabilities.withCurrency({'priceCents': (commerceCents(item['deltaCents']) ?? 0).abs()}))}',
                      ),
                    ),
                  if (_hasMore)
                    OutlinedButton(
                      onPressed: _loadingMore ? null : () => _load(more: true),
                      child: Text(
                        _loadingMore
                            ? context.l10n.loading
                            : context.l10n.globalShopLoadMore,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class GlobalShopOrdersPage extends StatefulWidget {
  const GlobalShopOrdersPage({
    required this.controller,
    required this.openProduct,
    super.key,
  });

  final AppController controller;
  final GlobalProductOpener openProduct;

  @override
  State<GlobalShopOrdersPage> createState() => _GlobalShopOrdersPageState();
}

class _GlobalShopOrdersPageState extends State<GlobalShopOrdersPage> {
  List<Map<String, Object?>> _orders = const [];
  GlobalCommerceCapabilities _capabilities =
      GlobalCommerceCapabilities.unavailable;
  String _filter = 'all';
  bool _loading = true;
  bool _failed = false;
  int _generation = 0;

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
      final status = switch (_filter) {
        'payment' => 'PENDING_PAYMENT',
        'delivery' => 'SHIPPED',
        _ => null,
      };
      final group = switch (_filter) {
        'shipment' => 'pending_shipment',
        'after' => 'after_sales',
        _ => null,
      };
      final values = await Future.wait<Object>([
        widget.controller.loadGlobalShopOrders(status: status, group: group),
        widget.controller.loadGlobalCommerceCapabilities(),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _orders = values[0] as List<Map<String, Object?>>;
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

  void _setFilter(String value) {
    if (_filter == value) return;
    setState(() => _filter = value);
    unawaited(_load());
  }

  Future<void> _open(Map<String, Object?> order) async {
    final id = commerceId(order['id']);
    if (id.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GlobalShopOrderDetailPage(
          controller: widget.controller,
          orderId: id,
          openProduct: widget.openProduct,
          capabilities: _capabilities,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-shop-orders-page'),
    appBar: AppBar(title: Text(context.l10n.myOrders)),
    body: Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _filterChip('all', context.l10n.all),
              _filterChip('payment', context.l10n.awaitingPayment),
              _filterChip('shipment', context.l10n.awaitingShipment),
              _filterChip('delivery', context.l10n.awaitingDelivery),
              _filterChip('after', context.l10n.afterSales),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _failed
              ? GlobalShopRetry(onRetry: _load)
              : _orders.isEmpty
              ? Center(child: Text(context.l10n.noOrders))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _orders.length,
                    itemBuilder: (_, index) => _orderCard(_orders[index]),
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _filterChip(String value, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => _setFilter(value),
    ),
  );

  Widget _orderCard(Map<String, Object?> order) {
    final items = commerceRows(order['items']);
    final currencyRow = _capabilities.withCurrency(order);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${context.l10n.orderNumber} ${commerceText(order['orderNo'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _orderStatus(context, commerceText(order['status'])),
                    style: const TextStyle(
                      color: Color(0xFFBE092D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                items.isEmpty
                    ? context.l10n.orderItemsUnavailable
                    : items
                          .map(
                            (item) =>
                                commerceText(item['nameSnapshot']).isNotEmpty
                                ? commerceText(item['nameSnapshot'])
                                : context.l10n.productInfo,
                          )
                          .take(2)
                          .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(globalShopDate(context, order['createdAt'])),
                  ),
                  Text(
                    globalShopMoney(context, {
                      ...currencyRow,
                      'priceCents': order['payableCents'],
                    }),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlobalShopOrderDetailPage extends StatefulWidget {
  const GlobalShopOrderDetailPage({
    required this.controller,
    required this.orderId,
    required this.openProduct,
    required this.capabilities,
    super.key,
  });

  final AppController controller;
  final String orderId;
  final GlobalProductOpener openProduct;
  final GlobalCommerceCapabilities capabilities;

  @override
  State<GlobalShopOrderDetailPage> createState() =>
      _GlobalShopOrderDetailPageState();
}

class _GlobalShopOrderDetailPageState extends State<GlobalShopOrderDetailPage> {
  Map<String, Object?>? _order;
  late GlobalCommerceCapabilities _capabilities;
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _capabilities = widget.capabilities;
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
        widget.controller.loadGlobalShopOrder(widget.orderId),
        widget.controller.loadGlobalCommerceCapabilities(),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _order = values[0] as Map<String, Object?>;
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

  bool _can(String action) =>
      _order?['readOnly'] != true &&
      (_order?['allowedActions'] is List) &&
      (_order!['allowedActions'] as List).whereType<String>().contains(action);

  bool _canReturn(Map<String, Object?> sale) =>
      _order?['readOnly'] != true &&
      commerceId(sale['id']).isNotEmpty &&
      commerceCents(sale['version']) != null &&
      sale['executionOwner'] == 'NEW_SYSTEM' &&
      sale['status'] == 'WAITING_RETURN' &&
      {'RETURN_REFUND', 'EXCHANGE'}.contains(sale['type']);

  Future<void> _action(String action) async {
    if (_busy || !_can(action)) return;
    final isReceipt = action == 'CONFIRM_RECEIPT';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isReceipt
              ? context.l10n.confirmItemReceived
              : context.l10n.cancelOrderPrompt,
        ),
        content: isReceipt ? Text(context.l10n.confirmReceiptHint) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isReceipt
                  ? context.l10n.confirmReceipt
                  : context.l10n.cancelOrder,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (isReceipt) {
        await widget.controller.confirmGlobalShopOrderReceipt(widget.orderId);
      } else {
        await widget.controller.cancelGlobalShopOrder(widget.orderId);
      }
      await _load();
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(Map<String, Object?> item) async {
    var rating = 5;
    final text = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.writeReview),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: rating,
                items: [
                  for (var value = 5; value >= 1; value--)
                    DropdownMenuItem(value: value, child: Text('$value ★')),
                ],
                onChanged: (value) => setDialogState(() => rating = value ?? 5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                maxLength: 1000,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.l10n.writeReview,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.submitReview),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || text.text.trim().isEmpty || !mounted) {
      text.dispose();
      return;
    }
    try {
      await widget.controller.submitGlobalShopReview(
        orderItemId: commerceId(item['id']),
        rating: rating,
        content: text.text,
      );
      if (mounted) _message(context.l10n.saved);
      await _load();
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    } finally {
      text.dispose();
    }
  }

  Future<void> _returnLogistics(Map<String, Object?> sale) async {
    final company = TextEditingController(
      text: commerceText(sale['returnLogisticsCompany']),
    );
    final tracking = TextEditingController(
      text: commerceText(sale['returnTrackingNo']),
    );
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.returnLogistics),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: company,
              maxLength: 80,
              decoration: InputDecoration(labelText: context.l10n.carrier),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tracking,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: context.l10n.trackingNumber,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) {
      company.dispose();
      tracking.dispose();
      return;
    }
    final companyValue = company.text.trim();
    final trackingValue = tracking.text.trim();
    if (companyValue.isEmpty || trackingValue.isEmpty) {
      _message(context.l10n.requiredField);
      company.dispose();
      tracking.dispose();
      return;
    }
    try {
      await widget.controller.submitGlobalShopReturnLogistics(
        orderId: widget.orderId,
        saleId: commerceId(sale['id']),
        input: {
          'logisticsCompany': companyValue,
          'trackingNo': trackingValue,
          'version': commerceCents(sale['version']),
        },
      );
      await _load();
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    } finally {
      company.dispose();
      tracking.dispose();
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.orderDetails)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_failed || order == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.orderDetails)),
        body: GlobalShopRetry(onRetry: _load),
      );
    }
    final items = commerceRows(order['items']);
    final afterSales = commerceRows(order['afterSales']);
    final savedAddress = commerceMap(order['addressSnapshot']);
    final address = savedAddress.isNotEmpty
        ? savedAddress
        : <String, Object?>{
            'name': order['recipientName'],
            'mobile': order['recipientMobile'],
            'countryCode': order['countryCode'],
            'province': order['province'],
            'city': order['city'],
            'district': order['district'],
            'detail': order['addressDetail'],
            'postalCode': order['postalCode'],
          };
    final hasAddress = address.values.any(
      (value) => commerceText(value).isNotEmpty,
    );
    final currency = _capabilities.withCurrency(order);
    return Scaffold(
      key: const Key('global-shop-order-detail-page'),
      appBar: AppBar(title: Text(context.l10n.orderDetails)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _orderStatus(context, commerceText(order['status'])),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.l10n.orderNumber} ${commerceText(order['orderNo'])}',
                    ),
                    Text(
                      '${context.l10n.orderDate} ${globalShopDate(context, order['createdAt'])}',
                    ),
                    if (order['readOnly'] == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: GlobalShopNotice(
                          text: context.l10n.legacyOrderReadOnly,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (hasAddress)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(commerceText(address['name'])),
                  subtitle: Text(_addressSummary(address)),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(context.l10n.orderItemsUnavailable),
                      ),
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox.square(
                          dimension: 56,
                          child: GlobalShopImage(
                            commerceText(item['imageSnapshot']),
                          ),
                        ),
                        title: Text(commerceText(item['nameSnapshot'])),
                        subtitle: Text(
                          '${commerceText(item['specificationSnapshot'])} × ${commerceCents(item['quantity']) ?? 1}',
                        ),
                        trailing:
                            item['review'] == null &&
                                [
                                  'RECEIVED',
                                  'COMPLETED',
                                  'CLOSED',
                                ].contains(order['status']) &&
                                order['readOnly'] != true
                            ? TextButton(
                                onPressed: _busy ? null : () => _review(item),
                                child: Text(context.l10n.writeReview),
                              )
                            : null,
                        onTap: commerceId(item['productId']).isEmpty
                            ? null
                            : () => widget.openProduct(
                                context,
                                commerceId(item['productId']),
                              ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _amountRow(
                      context.l10n.itemsSubtotal,
                      currency,
                      order['subtotalCents'],
                    ),
                    _amountRow(
                      context.l10n.discount,
                      currency,
                      order['discountCents'],
                    ),
                    _amountRow(
                      context.l10n.points,
                      currency,
                      order['pointDiscountCents'],
                    ),
                    _amountRow(
                      context.l10n.shippingFee,
                      currency,
                      order['shippingCents'],
                    ),
                    const Divider(),
                    _amountRow(
                      context.l10n.amountDue,
                      currency,
                      order['payableCents'],
                      strong: true,
                    ),
                  ],
                ),
              ),
            ),
            if (afterSales.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.afterSales,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final sale in afterSales)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_afterSaleStatus(context, commerceText(sale['status']))} · ${_afterSaleType(context, commerceText(sale['type']))}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (commerceText(sale['afterSaleNo']).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(commerceText(sale['afterSaleNo'])),
                        ],
                        if (commerceText(sale['reason']).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(commerceText(sale['reason'])),
                        ],
                        if (commerceText(sale['description']).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${context.l10n.requestDetails}: ${commerceText(sale['description'])}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (commerceRows(sale['items']).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.afterSaleItems,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          for (final line in commerceRows(sale['items']))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                _orderItemName(
                                  context,
                                  items,
                                  commerceId(line['orderItemId']),
                                ),
                              ),
                              trailing: Text(
                                '× ${commerceCents(line['quantity']) ?? 1}',
                              ),
                            ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.afterSaleItemsUnavailable,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _amountRow(
                          context.l10n.requestedAmount,
                          currency,
                          sale['requestedCents'],
                        ),
                        if ((commerceCents(sale['pointReturnCents']) ?? 0) > 0)
                          _amountRow(
                            context.l10n.points,
                            currency,
                            sale['pointReturnCents'],
                          ),
                        if (commerceRows(sale['refunds']).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.refundProgress,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          for (final refund in commerceRows(sale['refunds']))
                            _amountRow(
                              _refundStatus(
                                context,
                                commerceText(refund['status']),
                              ),
                              currency,
                              refund['amountCents'],
                            ),
                        ] else if (commerceText(sale['status']) ==
                            'REFUNDING') ...[
                          const SizedBox(height: 8),
                          Text(context.l10n.refundResultPending),
                        ],
                        if (_afterSaleEvidenceIds(
                          sale['evidenceImages'],
                        ).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GlobalShopEvidenceGallery(
                            controller: widget.controller,
                            ids: _afterSaleEvidenceIds(sale['evidenceImages']),
                          ),
                        ],
                        if (commerceText(sale['returnTrackingNo']).isNotEmpty)
                          Text(
                            '${context.l10n.trackingNumber}: ${commerceText(sale['returnTrackingNo'])}',
                          ),
                        if (_canReturn(sale))
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _returnLogistics(sale),
                              child: Text(context.l10n.returnLogistics),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            if (_can('PAY'))
              GlobalShopNotice(text: context.l10n.paymentUnavailable),
            if (_can('CANCEL'))
              OutlinedButton(
                onPressed: _busy ? null : () => _action('CANCEL'),
                child: Text(context.l10n.cancelOrder),
              ),
            if (_can('CONFIRM_RECEIPT'))
              FilledButton(
                onPressed: _busy ? null : () => _action('CONFIRM_RECEIPT'),
                child: Text(context.l10n.confirmReceipt),
              ),
            if (commerceRows(order['shipments']).isNotEmpty)
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GlobalShopLogisticsPage(
                      controller: widget.controller,
                      orderId: widget.orderId,
                    ),
                  ),
                ),
                child: Text(context.l10n.viewShipping),
              ),
            if (_can('APPLY_AFTER_SALE'))
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => GlobalShopAfterSalePage(
                              controller: widget.controller,
                              orderId: widget.orderId,
                              eligibleItems: commerceRows(
                                order['afterSaleEligibleItems'],
                              ),
                              orderItems: items,
                              capabilities: _capabilities,
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      },
                child: Text(context.l10n.applyAfterSales),
              ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(
    String label,
    Map<String, Object?> currency,
    Object? cents, {
    bool strong = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          globalShopMoney(context, {...currency, 'priceCents': cents}),
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            fontSize: strong ? 18 : null,
          ),
        ),
      ],
    ),
  );
}

class GlobalShopLogisticsPage extends StatefulWidget {
  const GlobalShopLogisticsPage({
    required this.controller,
    required this.orderId,
    super.key,
  });
  final AppController controller;
  final String orderId;

  @override
  State<GlobalShopLogisticsPage> createState() =>
      _GlobalShopLogisticsPageState();
}

class _GlobalShopLogisticsPageState extends State<GlobalShopLogisticsPage> {
  List<Map<String, Object?>> _items = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final value = await widget.controller.loadGlobalShopOrderLogistics(
        widget.orderId,
      );
      if (mounted) setState(() => _items = value);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.viewShipping)),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? GlobalShopRetry(onRetry: _load)
        : _items.isEmpty
        ? Center(child: Text(context.l10n.noShippingUpdates))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final shipment in _items) _shipmentCard(shipment),
              ],
            ),
          ),
  );

  Widget _shipmentCard(Map<String, Object?> shipment) {
    final raw = shipment['traceJson'] ?? shipment['traces'];
    final traces = raw is Map ? commerceRows(raw['data']) : commerceRows(raw);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${commerceText(shipment['logisticsCompany'])}  ${commerceText(shipment['trackingNo'])}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (traces.isEmpty) Text(context.l10n.noShippingUpdates),
            for (final trace in traces)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.radio_button_checked, size: 16),
                title: Text(
                  commerceText(trace['context']).isNotEmpty
                      ? commerceText(trace['context'])
                      : commerceText(trace['description']),
                ),
                subtitle: Text(
                  commerceText(trace['time']).isNotEmpty
                      ? commerceText(trace['time'])
                      : globalShopDate(context, trace['createdAt']),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GlobalShopAfterSalePage extends StatefulWidget {
  const GlobalShopAfterSalePage({
    required this.controller,
    required this.orderId,
    required this.eligibleItems,
    required this.orderItems,
    required this.capabilities,
    super.key,
  });

  final AppController controller;
  final String orderId;
  final List<Map<String, Object?>> eligibleItems;
  final List<Map<String, Object?>> orderItems;
  final GlobalCommerceCapabilities capabilities;

  @override
  State<GlobalShopAfterSalePage> createState() =>
      _GlobalShopAfterSalePageState();
}

class _GlobalShopAfterSalePageState extends State<GlobalShopAfterSalePage> {
  final _reason = TextEditingController();
  final _description = TextEditingController();
  String _type = 'REFUND_ONLY';
  final Map<String, int> _quantities = {};
  Map<String, Object?>? _quote;
  Map<String, Object?>? _frozenRequest;
  String? _idempotencyKey;
  bool _busy = false;
  bool _quoteFailed = false;
  bool _submissionUncertain = false;
  bool _evidenceBlocked = false;
  List<String> _evidenceIds = const [];

  @override
  void initState() {
    super.initState();
    if (_eligibleItems.isNotEmpty) {
      _quantities[commerceId(_eligibleItems.first['orderItemId'])] = 1;
    }
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  List<Map<String, Object?>> get _eligibleItems => widget.eligibleItems
      .where(
        (item) =>
            commerceId(item['orderItemId']).isNotEmpty &&
            (commerceCents(item['quantityRemaining']) ?? 0) > 0,
      )
      .toList(growable: false);

  Map<String, Object?> get _input => {
    'type': _type,
    'items': [
      for (final item in _eligibleItems)
        if ((_quantities[commerceId(item['orderItemId'])] ?? 0) > 0)
          {
            'orderItemId': commerceId(item['orderItemId']),
            'quantity': _quantities[commerceId(item['orderItemId'])],
          },
    ],
  };

  String get _draftKey => 'after-sale:${widget.orderId}';

  Future<void> _restoreDraft() async {
    try {
      final saved = await widget.controller.readGlobalShopDraft(_draftKey);
      if (!mounted || saved == null || saved['version'] != 1) return;
      final request = commerceMap(saved['request']);
      final key = commerceText(request['idempotencyKey']);
      final type = commerceText(request['type']);
      final items = commerceRows(request['items']);
      final rawEvidence = request['evidenceFileIds'];
      if (rawEvidence is! List ||
          rawEvidence.any((value) => value is! String)) {
        return;
      }
      final evidenceIds = rawEvidence
          .map(commerceText)
          .where((id) => id.isNotEmpty)
          .toList();
      if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(key) ||
          !{'REFUND_ONLY', 'RETURN_REFUND', 'EXCHANGE'}.contains(type) ||
          items.isEmpty ||
          commerceText(request['reason']).isEmpty ||
          (commerceCents(request['orderVersion']) ?? -1) < 0 ||
          (commerceCents(request['requestedCents']) ?? -1) < 0 ||
          evidenceIds.length > 9 ||
          evidenceIds.toSet().length != evidenceIds.length ||
          evidenceIds.any(
            (id) => !RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
              caseSensitive: false,
            ).hasMatch(id),
          )) {
        return;
      }
      final eligible = {
        for (final row in _eligibleItems)
          commerceId(row['orderItemId']): _maxQuantity(
            commerceId(row['orderItemId']),
          ),
      };
      final quantities = <String, int>{};
      for (final item in items) {
        final id = commerceId(item['orderItemId']);
        final quantity = commerceCents(item['quantity']) ?? 0;
        if (!eligible.containsKey(id) ||
            quantity < 1 ||
            quantity > eligible[id]!) {
          return;
        }
        quantities[id] = quantity;
      }
      setState(() {
        _frozenRequest = request;
        _idempotencyKey = key;
        _submissionUncertain = true;
        _type = type;
        _quantities
          ..clear()
          ..addAll(quantities);
        _reason.text = commerceText(request['reason']);
        _description.text = commerceText(request['description']);
        _evidenceIds = evidenceIds;
        _quote = commerceMap(saved['quote']);
      });
    } catch (_) {
      // Missing or temporarily unavailable secure storage does not block a
      // new text-only request; no network write has happened in this path.
    }
  }

  Future<void> _clearDraft() async {
    try {
      await widget.controller.clearGlobalShopDraft(_draftKey);
    } catch (_) {
      // Retaining a stale draft is safe because the server idempotency key is
      // stable; reopening the page can only retry that same request.
    }
  }

  bool get _locked => _busy || _submissionUncertain;

  Map<String, Object?> _orderItem(String id) => widget.orderItems.firstWhere(
    (row) => commerceId(row['id']) == id,
    orElse: () => const {},
  );

  int _maxQuantity(String id) {
    final item = _eligibleItems.firstWhere(
      (row) => commerceId(row['orderItemId']) == id,
      orElse: () => const {},
    );
    return commerceCents(item['quantityRemaining']) ?? 1;
  }

  void _changeQuantity(String id, int delta) {
    if (_locked) return;
    final current = _quantities[id] ?? 0;
    final next = (current + delta).clamp(0, _maxQuantity(id));
    setState(() {
      _quantities[id] = next;
      _quote = null;
      _quoteFailed = false;
    });
  }

  Future<Map<String, Object?>> _requestQuote() => widget.controller
      .previewGlobalShopAfterSale(orderId: widget.orderId, input: _input);

  Future<void> _preview() async {
    if (_locked || commerceRows(_input['items']).isEmpty) return;
    setState(() {
      _busy = true;
      _quoteFailed = false;
    });
    try {
      final value = await _requestQuote();
      if (mounted) setState(() => _quote = value);
    } catch (_) {
      if (mounted) {
        setState(() => _quoteFailed = true);
        _message(context.l10n.serviceUnavailable);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _quoteSignature(Map<String, Object?> value) => jsonEncode([
    value['orderVersion'],
    value['type'],
    value['requestedCents'],
    value['merchandiseRefundCents'],
    value['shippingRefundCents'],
    value['pointReturnCents'],
    for (final line in commerceRows(value['items']))
      [
        line['orderItemId'],
        line['quantity'],
        line['amountCents'],
        line['pointReturnCents'],
      ],
  ]);

  Future<void> _submit() async {
    if (_busy ||
        _evidenceBlocked ||
        (_frozenRequest == null &&
            (_quote == null ||
                _reason.text.trim().isEmpty ||
                commerceRows(_input['items']).isEmpty))) {
      return;
    }
    setState(() => _busy = true);
    try {
      var request = _frozenRequest;
      if (request == null) {
        final displayed = _quoteSignature(_quote!);
        final refreshed = await _requestQuote();
        if (displayed != _quoteSignature(refreshed)) {
          if (mounted) {
            setState(() {
              _quote = refreshed;
              _quoteFailed = false;
            });
            _message(context.l10n.checkoutPriceChanged);
          }
          return;
        }
        final key = _idempotencyKey ??= 'app-as-${const Uuid().v4()}';
        request = <String, Object?>{
          ..._input,
          'reason': _reason.text.trim(),
          if (_description.text.trim().isNotEmpty)
            'description': _description.text.trim(),
          'orderVersion': refreshed['orderVersion'],
          'requestedCents': refreshed['requestedCents'],
          'evidenceFileIds': List<String>.of(_evidenceIds),
          'idempotencyKey': key,
        };
        try {
          await widget.controller.writeGlobalShopDraft(_draftKey, {
            'version': 1,
            'request': request,
            'quote': refreshed,
          });
          _frozenRequest = request;
        } catch (_) {
          _idempotencyKey = null;
          if (mounted) _message(context.l10n.serviceUnavailable);
          return;
        }
      }
      await widget.controller.createGlobalShopAfterSale(
        orderId: widget.orderId,
        input: request,
      );
      await _clearDraft();
      if (!mounted) return;
      _message(context.l10n.requestSubmitted);
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      final deterministic =
          error.statusCode != null &&
          error.statusCode! >= 400 &&
          error.statusCode! < 500 &&
          error.code != 'order_in_progress';
      if (deterministic) {
        _idempotencyKey = null;
        _frozenRequest = null;
        await _clearDraft();
        if (mounted) {
          setState(() {
            _submissionUncertain = false;
            _quote = null;
          });
          _message(context.l10n.serviceUnavailable);
        }
      } else if (mounted) {
        setState(() => _submissionUncertain = true);
        _message(context.l10n.afterSaleSubmissionUncertain);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submissionUncertain = true);
        _message(context.l10n.afterSaleSubmissionUncertain);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-shop-after-sale-page'),
    appBar: AppBar(title: Text(context.l10n.applyAfterSales)),
    body: _eligibleItems.isEmpty
        ? Center(child: Text(context.l10n.afterSalesUnavailable))
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              for (final available in _eligibleItems) _itemSelector(available),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: context.l10n.afterSalesType,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'REFUND_ONLY',
                    child: Text(context.l10n.refundOnly),
                  ),
                  DropdownMenuItem(
                    value: 'RETURN_REFUND',
                    child: Text(context.l10n.returnRefund),
                  ),
                  DropdownMenuItem(
                    value: 'EXCHANGE',
                    child: Text(context.l10n.exchange),
                  ),
                ],
                onChanged: _locked
                    ? null
                    : (value) => setState(() {
                        _type = value ?? _type;
                        _quote = null;
                        _quoteFailed = false;
                      }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                enabled: !_locked,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: context.l10n.afterSalesReason,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                enabled: !_locked,
                maxLength: 1000,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.l10n.describeProblem,
                ),
              ),
              GlobalShopEvidencePicker(
                controller: widget.controller,
                ids: _evidenceIds,
                locked: _locked,
                onChanged: (ids) {
                  if (!mounted || _locked) return;
                  setState(() => _evidenceIds = ids);
                },
                onBlockedChanged: (blocked) {
                  if (mounted && _evidenceBlocked != blocked) {
                    setState(() => _evidenceBlocked = blocked);
                  }
                },
              ),
              if (_quote != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _afterSaleAmount(
                          context.l10n.itemsSubtotal,
                          _quote!['merchandiseRefundCents'],
                        ),
                        _afterSaleAmount(
                          context.l10n.shippingFee,
                          _quote!['shippingRefundCents'],
                        ),
                        _afterSaleAmount(
                          context.l10n.points,
                          _quote!['pointReturnCents'],
                        ),
                        const Divider(),
                        _afterSaleAmount(
                          context.l10n.requestedAmount,
                          _quote!['requestedCents'],
                          strong: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_quoteFailed)
                GlobalShopNotice(text: context.l10n.serviceUnavailable),
              if (_submissionUncertain)
                GlobalShopNotice(
                  text: context.l10n.afterSaleSubmissionUncertain,
                ),
            ],
          ),
    bottomNavigationBar: _eligibleItems.isEmpty
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _quote == null && _frozenRequest == null
                  ? OutlinedButton(
                      onPressed:
                          _locked || commerceRows(_input['items']).isEmpty
                          ? null
                          : _preview,
                      child: Text(context.l10n.previewRequest),
                    )
                  : FilledButton(
                      onPressed:
                          _busy ||
                              _evidenceBlocked ||
                              (_frozenRequest == null &&
                                  _reason.text.trim().isEmpty)
                          ? null
                          : _submit,
                      child: Text(
                        _submissionUncertain
                            ? context.l10n.retry
                            : context.l10n.submitRequest,
                      ),
                    ),
            ),
          ),
  );

  Widget _itemSelector(Map<String, Object?> available) {
    final id = commerceId(available['orderItemId']);
    final item = _orderItem(id);
    final quantity = _quantities[id] ?? 0;
    final max = _maxQuantity(id);
    final name = commerceText(item['nameSnapshot']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? context.l10n.productInfo : name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (commerceText(item['specificationSnapshot']).isNotEmpty)
              Text(commerceText(item['specificationSnapshot'])),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, _) {
                final controls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.outlined(
                      onPressed: _locked || quantity <= 0
                          ? null
                          : () => _changeQuantity(id, -1),
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text('$quantity', textAlign: TextAlign.center),
                    ),
                    IconButton.outlined(
                      onPressed: _locked || quantity >= max
                          ? null
                          : () => _changeQuantity(id, 1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                );
                final remaining = Text('${context.l10n.quantity}: $max');
                if (MediaQuery.textScalerOf(context).scale(16) >= 26) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      remaining,
                      const SizedBox(height: 4),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: controls,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: remaining),
                    controls,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _afterSaleAmount(String label, Object? cents, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              globalShopMoney(
                context,
                widget.capabilities.withCurrency({'priceCents': cents}),
              ),
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

class GlobalShopHelpPage extends StatelessWidget {
  const GlobalShopHelpPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.helpCenter)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlobalShopNotice(text: context.l10n.shopHelpIntro),
        const SizedBox(height: 12),
        _help(
          context,
          context.l10n.shopHelpOrdering,
          context.l10n.shopHelpOrderingAnswer,
        ),
        _help(
          context,
          context.l10n.shopHelpPayment,
          context.l10n.shopHelpPaymentAnswer,
        ),
        _help(
          context,
          context.l10n.shopHelpAfterSales,
          context.l10n.shopHelpAfterSalesAnswer,
        ),
      ],
    ),
  );

  Widget _help(BuildContext context, String title, String body) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      title: Text(title),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(body)],
    ),
  );
}

String _orderStatus(BuildContext context, String status) => switch (status) {
  'PENDING_PAYMENT' => context.l10n.awaitingPayment,
  'PAID' ||
  'ERP_SYNCING' ||
  'WAITING_FULFILLMENT' => context.l10n.awaitingShipment,
  'SHIPPED' => context.l10n.awaitingDelivery,
  'RECEIVED' || 'COMPLETED' => context.l10n.orderCompleted,
  'CANCELLED' || 'CLOSED' => context.l10n.orderCancelled,
  'AFTER_SALE' => context.l10n.afterSales,
  'REFUNDED' => context.l10n.orderRefunded,
  _ => context.l10n.orderStatusPending,
};

String _afterSaleStatus(BuildContext context, String status) =>
    switch (status) {
      'WAITING_RETURN' => context.l10n.waitingForReturn,
      'COMPLETED' => context.l10n.orderCompleted,
      'REJECTED' => context.l10n.requestRejected,
      'CANCELLED' => context.l10n.orderCancelled,
      _ => context.l10n.requestProcessing,
    };

String _afterSaleType(BuildContext context, String type) => switch (type) {
  'REFUND_ONLY' => context.l10n.refundOnly,
  'RETURN_REFUND' => context.l10n.returnRefund,
  'EXCHANGE' => context.l10n.exchange,
  _ => context.l10n.afterSales,
};

String _refundStatus(BuildContext context, String status) => switch (status) {
  'SUCCEEDED' => context.l10n.orderRefunded,
  'FAILED' => context.l10n.requestRejected,
  'CANCELLED' => context.l10n.orderCancelled,
  _ => context.l10n.requestProcessing,
};

String _orderItemName(
  BuildContext context,
  List<Map<String, Object?>> items,
  String id,
) {
  for (final item in items) {
    if (commerceId(item['id']) == id) {
      final name = commerceText(item['nameSnapshot']);
      if (name.isNotEmpty) return name;
    }
  }
  return context.l10n.afterSaleItem;
}

String _pointsLedgerLabel(BuildContext context, String type) => switch (type) {
  'ORDER_DEDUCT' || 'ORDER_REDEMPTION' => context.l10n.discount,
  'ORDER_CANCEL_RETURN' ||
  'AFTER_SALE_RETURN' ||
  'FULL_REFUND_RETURN' => context.l10n.orderRefunded,
  _ => context.l10n.points,
};

List<String> _afterSaleEvidenceIds(Object? value) {
  if (value is! List) return const [];
  final ids = <String>{};
  final pattern = RegExp(
    r'^file:([0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$',
    caseSensitive: false,
  );
  for (final entry in value) {
    final match = pattern.firstMatch(commerceText(entry));
    if (match != null) ids.add(match.group(1)!.toLowerCase());
    if (ids.length == 9) break;
  }
  return ids.toList(growable: false);
}

String _addressSummary(Map<String, Object?> address) => [
  commerceText(address['name']),
  commerceText(address['mobile']),
  commerceText(address['countryCode']),
  commerceText(address['province']),
  commerceText(address['city']),
  commerceText(address['district']),
  commerceText(address['detail']),
  commerceText(address['postalCode']),
].where((value) => value.isNotEmpty).join(' ');
