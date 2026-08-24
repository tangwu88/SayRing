import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/app_controller.dart';
import 'app_theme.dart';
import 'prototype_pages.dart';

class ShopHomePage extends StatefulWidget {
  const ShopHomePage({
    required this.controller,
    this.ordersPageBuilder,
    super.key,
  });

  final AppController controller;
  final WidgetBuilder? ordersPageBuilder;

  @override
  State<ShopHomePage> createState() => _ShopHomePageState();
}

class _ShopHomePageState extends State<ShopHomePage> {
  Map<String, Object?> _home = const {};
  bool _loading = true;
  String _keyword = '';
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final home = await widget.controller.loadShopHome();
    if (!mounted) return;
    setState(() {
      _home = home;
      _loading = false;
      _activeTab = 0;
    });
  }

  List<Map<String, Object?>> get _items => _mapList(_home['items']);

  List<String> get _banners {
    for (final item in _items) {
      if ('${item['type']}' != 'swiper') continue;
      final data = _map(item['data']);
      return _mapList(data['list'])
          .map((value) => '${value['url'] ?? ''}')
          .where((value) => value.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<Map<String, Object?>> get _tabs {
    for (final item in _items) {
      if ('${item['type']}' == 'tabs') return _mapList(item['value']);
    }
    return const [];
  }

  List<Map<String, Object?>> get _products {
    final tabs = _tabs;
    if (tabs.isEmpty) return const [];
    final index = _activeTab.clamp(0, tabs.length - 1);
    final products = _mapList(tabs[index]['list']);
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) return products;
    return products
        .where(
          (item) => '${item['name'] ?? ''}'.toLowerCase().contains(keyword),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('shop-page'),
      appBar: AppBar(
        title: const Text('赛电商城'),
        actions: [
          IconButton(
            tooltip: '购物车',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'shopping-cart'),
                builder: (_) => ShoppingCartPage(
                  controller: widget.controller,
                  ordersPageBuilder: widget.ordersPageBuilder,
                ),
              ),
            ),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
          if (widget.ordersPageBuilder != null)
            IconButton(
              tooltip: '我的订单',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: widget.ordersPageBuilder!),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _home.isEmpty
          ? _ShopFailure(
              message: widget.controller.errorMessage ?? '商城加载失败，请稍后重试',
              onRetry: _load,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: TextField(
                    key: const Key('shop-search'),
                    onChanged: (value) => setState(() => _keyword = value),
                    decoration: const InputDecoration(
                      hintText: '搜索商品',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                if (_banners.isNotEmpty)
                  SizedBox(
                    height: 112,
                    child: PageView.builder(
                      itemCount: _banners.length,
                      itemBuilder: (_, index) => Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ShopNetworkImage(url: _banners[index]),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        key: const Key('shop-category-list'),
                        width: 106,
                        color: const Color(0xFFF5F2F0),
                        child: ListView.builder(
                          itemCount: _tabs.length,
                          itemBuilder: (_, index) {
                            final selected = index == _activeTab;
                            return InkWell(
                              onTap: () => setState(() => _activeTab = index),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 64,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: selected ? Colors.white : null,
                                  border: Border(
                                    left: BorderSide(
                                      color: selected
                                          ? SaydianColors.brandRed
                                          : Colors.transparent,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${_tabs[index]['name'] ?? '商品'}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected
                                        ? SaydianColors.brandRed
                                        : SaydianColors.ink,
                                    fontWeight: selected
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: _products.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 90),
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 48,
                                      color: SaydianColors.outline,
                                    ),
                                    SizedBox(height: 10),
                                    Center(child: Text('当前分类暂无商品')),
                                  ],
                                )
                              : ListView.separated(
                                  key: const Key('shop-product-grid'),
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    4,
                                    14,
                                    24,
                                  ),
                                  itemCount: _products.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, index) => _ProductCard(
                                    product: _products[index],
                                    onTap: () => _openProduct(_products[index]),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _openProduct(Map<String, Object?> product) {
    final id = _asInt(product['id']);
    if (id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopProductPage(
          controller: widget.controller,
          productId: id,
          ordersPageBuilder: widget.ordersPageBuilder,
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Map<String, Object?> product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 104,
              child: ShopNetworkImage(url: '${product['picture'] ?? ''}'),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product['name'] ?? '商品'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '销量 ${product['sales'] ?? 0}',
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${_money(product['price'])}',
                      style: const TextStyle(
                        color: SaydianColors.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShopProductPage extends StatefulWidget {
  const ShopProductPage({
    required this.controller,
    required this.productId,
    this.ordersPageBuilder,
    super.key,
  });

  final AppController controller;
  final int productId;
  final WidgetBuilder? ordersPageBuilder;

  @override
  State<ShopProductPage> createState() => _ShopProductPageState();
}

class _ShopProductPageState extends State<ShopProductPage> {
  Map<String, Object?> _product = const {};
  Map<String, Object?>? _selectedSku;
  bool _loading = true;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final product = await widget.controller.loadShopProduct(widget.productId);
    if (!mounted) return;
    final skus = _mapList(product['sku']);
    setState(() {
      _product = product;
      _selectedSku = skus.isEmpty ? null : skus.first;
      _quantity = (_asInt(product['min_buy']) ?? 1).clamp(1, 999);
      _loading = false;
    });
  }

  List<Map<String, Object?>> get _skus => _mapList(_product['sku']);

  List<String> get _covers {
    final raw = _product['covers'];
    final values = raw is List
        ? raw
              .map((value) => '$value')
              .where((value) => value.isNotEmpty)
              .toList()
        : <String>[];
    final picture = '${_product['picture'] ?? ''}';
    if (values.isEmpty && picture.isNotEmpty) values.add(picture);
    return values;
  }

  int get _stock => _asInt(_selectedSku?['stock']) ?? 0;

  Future<void> _showPurchaseSheet({bool addToCart = false}) async {
    if (_selectedSku == null) {
      _showMessage('该商品暂无可购买规格');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '请选择规格',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sku in _skus)
                      ChoiceChip(
                        label: Text('${sku['name'] ?? '默认规格'}'),
                        selected: '${_selectedSku?['id']}' == '${sku['id']}',
                        onSelected: (_) {
                          setState(() {
                            _selectedSku = sku;
                            _quantity = 1;
                          });
                          setSheetState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text('库存 $_stock'),
                    const Spacer(),
                    IconButton.outlined(
                      onPressed: _quantity <= 1
                          ? null
                          : () {
                              setState(() => _quantity--);
                              setSheetState(() {});
                            },
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '$_quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: _quantity >= _stock
                          ? null
                          : () {
                              setState(() => _quantity++);
                              setSheetState(() {});
                            },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _stock <= 0
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            if (addToCart) {
                              unawaited(_addToCart());
                            } else {
                              _checkout();
                            }
                          },
                    child: Text(addToCart ? '加入购物车' : '立即购买'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _checkout() {
    final sku = _selectedSku;
    final skuId = _asInt(sku?['id']);
    if (sku == null || skuId == null) return;
    if (widget.controller.session == null) {
      _showMessage('请先登录后购买');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopCheckoutPage(
          controller: widget.controller,
          items: [_cartItem(_product, sku, _quantity)],
          ordersPageBuilder: widget.ordersPageBuilder,
        ),
      ),
    );
  }

  Future<void> _addToCart() async {
    final sku = _selectedSku;
    if (sku == null) return;
    try {
      await widget.controller.addToShopCart(
        product: _product,
        sku: sku,
        quantity: _quantity,
      );
      if (mounted) _showMessage('已加入购物车');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商品详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _product.isEmpty
          ? _ShopFailure(
              message: widget.controller.errorMessage ?? '商品详情加载失败',
              onRetry: _load,
            )
          : ColoredBox(
              color: const Color(0xFFF6F4F2),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  SizedBox(
                    height: 350,
                    child: _covers.isEmpty
                        ? const ShopNetworkImage(url: '')
                        : PageView.builder(
                            itemCount: _covers.length,
                            itemBuilder: (_, index) =>
                                ShopNetworkImage(url: _covers[index]),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_product['name'] ?? '商品'}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  '¥${_money(_selectedSku?['price'] ?? _product['price'])}',
                                  style: const TextStyle(
                                    color: SaydianColors.orange,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '销量 ${_product['sales'] ?? 0}',
                                  style: const TextStyle(
                                    color: SaydianColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ShopPromise(
                                  icon: Icons.verified_outlined,
                                  label: '品质保障',
                                ),
                                _ShopPromise(
                                  icon: Icons.local_shipping_outlined,
                                  label: '配送到家',
                                ),
                                _ShopPromise(
                                  icon: Icons.support_agent_outlined,
                                  label: '售后服务',
                                ),
                              ],
                            ),
                            if (_skus.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Card(
                                child: ListTile(
                                  onTap: _showPurchaseSheet,
                                  title: const Text('规格'),
                                  subtitle: Text(
                                    '${_selectedSku?['name'] ?? '请选择规格'}',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '商品详情',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _plainText('${_product['intro'] ?? ''}'),
                              style: const TextStyle(height: 1.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _product.isEmpty
          ? null
          : SafeArea(
              maintainBottomViewPadding: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: '返回商城',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.storefront_outlined),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: '客服',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(
                            name: 'customer-service',
                          ),
                          builder: (_) => const CustomerServicePage(),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showPurchaseSheet(addToCart: true),
                        child: const Text('加入购物车'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _showPurchaseSheet(),
                        child: const Text('立即购买'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ShopPromise extends StatelessWidget {
  const _ShopPromise({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: SaydianColors.brandRedSoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: SaydianColors.brandRed),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    ),
  );
}

class ShoppingCartPage extends StatelessWidget {
  const ShoppingCartPage({
    required this.controller,
    this.ordersPageBuilder,
    super.key,
  });

  final AppController controller;
  final WidgetBuilder? ordersPageBuilder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final items = controller.shopCart;
      final total = items.fold<double>(0, (sum, item) {
        return sum + _asDouble(item['price']) * (_asInt(item['quantity']) ?? 0);
      });
      return Scaffold(
        key: const Key('shopping-cart-page'),
        appBar: AppBar(
          title: Text('购物车${items.isEmpty ? '' : '（${items.length}）'}'),
          actions: [
            if (items.isNotEmpty)
              TextButton(
                onPressed: () => _confirmClear(context),
                child: const Text('清空'),
              ),
          ],
        ),
        body: items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.remove_shopping_cart_outlined,
                      size: 72,
                      color: SaydianColors.outline,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '购物车还是空的',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('去商城挑选适合您的健康设备吧'),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('返回商城'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _CartItemCard(
                  item: items[index],
                  onQuantityChanged: (quantity) {
                    final skuId = _asInt(items[index]['sku_id']);
                    if (skuId != null) {
                      unawaited(
                        controller.updateShopCartQuantity(skuId, quantity),
                      );
                    }
                  },
                ),
              ),
        bottomNavigationBar: items.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '合计 ¥${_money(total)}',
                          style: const TextStyle(
                            color: SaydianColors.brandRed,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      FilledButton(
                        key: const Key('cart-checkout'),
                        onPressed: () {
                          if (items.length != 1) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('当前商城暂不支持多件商品合并结算，请分别结算'),
                                ),
                              );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ShopCheckoutPage(
                                controller: controller,
                                items: items,
                                clearCartAfterCreate: true,
                                ordersPageBuilder: ordersPageBuilder,
                              ),
                            ),
                          );
                        },
                        child: const Text('去结算'),
                      ),
                    ],
                  ),
                ),
              ),
      );
    },
  );

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空购物车？'),
        content: const Text('已加入的商品将全部移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearShopCart();
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({required this.item, required this.onQuantityChanged});

  final Map<String, Object?> item;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final quantity = _asInt(item['quantity']) ?? 1;
    final stock = _asInt(item['stock']) ?? quantity;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 88,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ShopNetworkImage(url: '${item['picture'] ?? ''}'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['product_name'] ?? '商品'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['sku_name'] ?? ''}',
                    style: const TextStyle(color: SaydianColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '¥${_money(item['price'])}',
                          style: const TextStyle(
                            color: SaydianColors.brandRed,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton.outlined(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onQuantityChanged(quantity - 1),
                        icon: Icon(
                          quantity == 1 ? Icons.delete_outline : Icons.remove,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$quantity'),
                      ),
                      IconButton.outlined(
                        visualDensity: VisualDensity.compact,
                        onPressed: quantity >= stock
                            ? null
                            : () => onQuantityChanged(quantity + 1),
                        icon: const Icon(Icons.add),
                      ),
                    ],
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

class ShopCheckoutPage extends StatefulWidget {
  const ShopCheckoutPage({
    required this.controller,
    required this.items,
    this.clearCartAfterCreate = false,
    this.ordersPageBuilder,
    super.key,
  });

  final AppController controller;
  final List<Map<String, Object?>> items;
  final bool clearCartAfterCreate;
  final WidgetBuilder? ordersPageBuilder;

  @override
  State<ShopCheckoutPage> createState() => _ShopCheckoutPageState();
}

class _ShopCheckoutPageState extends State<ShopCheckoutPage> {
  final _message = TextEditingController();
  final _point = TextEditingController(text: '0');
  Map<String, Object?> _preview = const {};
  Map<String, Object?>? _address;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _message.dispose();
    _point.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final orderItems = _orderItems;
    if (orderItems.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final preview = await widget.controller.previewShopOrder(items: orderItems);
    if (!mounted) return;
    final address = _mapOrNull(preview['address']);
    setState(() {
      _preview = preview;
      _address = address;
      _loading = false;
    });
  }

  Map<String, Object?> get _summary => _map(_preview['preview']);
  Map<String, Object?> get _account => _map(_preview['account']);
  List<Map<String, Object?>> get _products => _mapList(_preview['products']);

  double get _shipping => _asDouble(_summary['shipping_money']);
  double get _productMoney => _asDouble(_summary['product_money']);
  double get _total => _shipping + _productMoney;

  List<Map<String, int>> get _orderItems => widget.items
      .map((item) {
        final skuId = _asInt(item['sku_id']);
        final quantity = _asInt(item['quantity']);
        if (skuId == null || quantity == null || quantity <= 0) return null;
        return <String, int>{'sku_id': skuId, 'num': quantity};
      })
      .whereType<Map<String, int>>()
      .toList(growable: false);

  Future<void> _chooseAddress() async {
    final selected = await Navigator.of(context).push<Map<String, Object?>>(
      MaterialPageRoute<Map<String, Object?>>(
        builder: (_) => ShopAddressBookPage(
          controller: widget.controller,
          selectMode: true,
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _address = selected);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final addressId = _asInt(_address?['id']);
    final orderItems = _orderItems;
    final point = num.tryParse(_point.text.trim()) ?? -1;
    final availablePoint = _asDouble(_account['money1']);
    if (addressId == null) {
      _showMessage('请选择收货地址');
      return;
    }
    if (orderItems.isEmpty) {
      _showMessage('商品规格信息有误');
      return;
    }
    if (point < 0 || point > availablePoint) {
      _showMessage('积分必须在 0～${_money(availablePoint)} 之间');
      return;
    }
    setState(() => _submitting = true);
    final order = await widget.controller.createShopOrder(
      items: orderItems,
      addressId: addressId,
      buyerMessage: _message.text,
      point: point,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    final orderId = _asInt(order['id'] ?? order['order_id']);
    if (orderId == null) {
      _showMessage(widget.controller.errorMessage ?? '提交订单失败');
      return;
    }
    if (widget.clearCartAfterCreate) {
      await widget.controller.clearShopCart();
      if (!mounted) return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ShopPaymentStatusPage(
          controller: widget.controller,
          orderId: orderId,
          ordersPageBuilder: widget.ordersPageBuilder,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('shop-checkout'),
      appBar: AppBar(title: const Text('确认订单')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _preview.isEmpty
          ? _ShopFailure(
              message: widget.controller.errorMessage ?? '订单信息加载失败',
              onRetry: _load,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                Card(
                  child: ListTile(
                    onTap: _chooseAddress,
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(
                      _address == null
                          ? '请选择收货地址'
                          : '${_address!['realname'] ?? ''}  ${_address!['mobile'] ?? ''}',
                    ),
                    subtitle: _address == null
                        ? null
                        : Text(_addressText(_address!)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '商品信息',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        for (final product in _products)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SizedBox.square(
                              dimension: 62,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ShopNetworkImage(
                                  url: '${product['product_picture'] ?? ''}',
                                ),
                              ),
                            ),
                            title: Text('${product['product_name'] ?? '商品'}'),
                            subtitle: Text('${product['sku_name'] ?? ''}'),
                            trailing: Text(
                              '¥${_money(product['product_money'])}\n×${product['num'] ?? 1}',
                              textAlign: TextAlign.right,
                            ),
                          ),
                        TextField(
                          controller: _message,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: '留言',
                            hintText: '给商家留言',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      controller: _point,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: '积分抵扣',
                        helperText: '可用积分：${_money(_account['money1'])}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _MoneyRow(label: '商品总额', value: _productMoney),
                        const SizedBox(height: 12),
                        _MoneyRow(label: '快递费用', value: _shipping),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _preview.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 9, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '合计 ¥${_money(_total)}',
                        style: const TextStyle(
                          color: SaydianColors.orange,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(_submitting ? '提交中…' : '提交订单'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        Text(
          '¥${_money(value)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class ShopPaymentStatusPage extends StatefulWidget {
  const ShopPaymentStatusPage({
    required this.controller,
    required this.orderId,
    this.ordersPageBuilder,
    super.key,
  });

  final AppController controller;
  final int orderId;
  final WidgetBuilder? ordersPageBuilder;

  @override
  State<ShopPaymentStatusPage> createState() => _ShopPaymentStatusPageState();
}

class _ShopPaymentStatusPageState extends State<ShopPaymentStatusPage> {
  Map<String, Object?> _order = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final order = await widget.controller.loadOrderDetail(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _asInt(_order['order_status']);
    return Scaffold(
      appBar: AppBar(title: const Text('订单结果')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Icon(
                    status == 0
                        ? Icons.schedule_rounded
                        : Icons.check_circle_rounded,
                    size: 72,
                    color: status == 0
                        ? SaydianColors.orange
                        : SaydianColors.green,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    status == 0 ? '订单提交成功，等待支付' : '订单状态已更新',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '订单号：${_order['order_sn'] ?? widget.orderId}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  if (status == 0)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: SaydianColors.orange,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '订单已提交，可在“我的订单”查看。当前请在微信小程序完成支付，支付状态会以订单页面显示为准。',
                                style: TextStyle(height: 1.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('刷新订单状态'),
                  ),
                  if (widget.ordersPageBuilder != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: widget.ordersPageBuilder!,
                        ),
                      ),
                      child: const Text('查看我的订单'),
                    ),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('返回商品详情'),
                  ),
                ],
              ),
            ),
    );
  }
}

class ShopAddressBookPage extends StatefulWidget {
  const ShopAddressBookPage({
    required this.controller,
    this.selectMode = false,
    super.key,
  });

  final AppController controller;
  final bool selectMode;

  @override
  State<ShopAddressBookPage> createState() => _ShopAddressBookPageState();
}

class _ShopAddressBookPageState extends State<ShopAddressBookPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await widget.controller.loadAddresses();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([Map<String, Object?>? address]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ShopAddressEditPage(
          controller: widget.controller,
          initialAddress: address,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? '选择收货地址' : '收货地址'),
        actions: [
          IconButton(
            tooltip: '新增地址',
            onPressed: _edit,
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final addresses = widget.controller.addresses;
                if (addresses.isEmpty) {
                  return _ShopFailure(
                    message: widget.controller.errorMessage ?? '暂无收货地址',
                    actionLabel: '新增地址',
                    onRetry: _edit,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final address = addresses[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            10,
                            8,
                            10,
                          ),
                          onTap: widget.selectMode
                              ? () => Navigator.pop(context, address)
                              : () => _edit(address),
                          leading: const CircleAvatar(
                            child: Icon(Icons.location_on_outlined),
                          ),
                          title: Text(
                            '${address['realname'] ?? ''}  ${address['mobile'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(_addressText(address)),
                          trailing: IconButton(
                            tooltip: '编辑',
                            onPressed: () => _edit(address),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增地址'),
      ),
    );
  }
}

class ShopAddressEditPage extends StatefulWidget {
  const ShopAddressEditPage({
    required this.controller,
    this.initialAddress,
    super.key,
  });

  final AppController controller;
  final Map<String, Object?>? initialAddress;

  @override
  State<ShopAddressEditPage> createState() => _ShopAddressEditPageState();
}

class _ShopAddressEditPageState extends State<ShopAddressEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _details;
  bool _isDefault = true;
  bool _loadingRegions = true;
  bool _saving = false;
  Map<String, String> _provinces = const {};
  Map<String, String> _cities = const {};
  Map<String, String> _areas = const {};
  String? _provinceCode;
  String? _cityCode;
  String? _areaCode;

  @override
  void initState() {
    super.initState();
    final address = widget.initialAddress ?? const <String, Object?>{};
    _name = TextEditingController(text: '${address['realname'] ?? ''}');
    _mobile = TextEditingController(text: '${address['mobile'] ?? ''}');
    _details = TextEditingController(
      text: '${address['address_details'] ?? ''}',
    );
    _isDefault = '${address['is_default'] ?? 1}' == '1';
    _provinceCode = _regionCode(address['province_id']);
    _cityCode = _regionCode(address['city_id']);
    _areaCode = _regionCode(address['area_id']);
    unawaited(_loadRegions());
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    final raw = await rootBundle.loadString('assets/china_regions.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _provinces = _stringMap(decoded['provinces']);
      _cities = _stringMap(decoded['cities']);
      _areas = _stringMap(decoded['areas']);
      if (!_provinces.containsKey(_provinceCode)) _provinceCode = null;
      if (!_availableCities.containsKey(_cityCode)) _cityCode = null;
      if (!_availableAreas.containsKey(_areaCode)) _areaCode = null;
      _loadingRegions = false;
    });
  }

  Map<String, String> get _availableCities {
    final code = _provinceCode;
    if (code == null || code.length < 2) return const {};
    final prefix = code.substring(0, 2);
    return Map.fromEntries(
      _cities.entries.where((entry) => entry.key.startsWith(prefix)),
    );
  }

  Map<String, String> get _availableAreas {
    final code = _cityCode;
    if (code == null || code.length < 4) return const {};
    final prefix = code.substring(0, 4);
    return Map.fromEntries(
      _areas.entries.where((entry) => entry.key.startsWith(prefix)),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_provinceCode == null || _cityCode == null || _areaCode == null) {
      _showMessage('请选择完整省、市、区县');
      return;
    }
    setState(() => _saving = true);
    final region = [
      _provinces[_provinceCode],
      _cities[_cityCode],
      _areas[_areaCode],
    ].whereType<String>().join(' ');
    final saved = await widget.controller.saveShopAddress(
      id: _asInt(widget.initialAddress?['id']),
      realname: _name.text,
      mobile: _mobile.text,
      addressDetails: _details.text,
      isDefault: _isDefault,
      region: region,
      provinceId: int.parse(_provinceCode!),
      cityId: int.parse(_cityCode!),
      areaId: int.parse(_areaCode!),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      Navigator.pop(context, true);
    } else {
      _showMessage(widget.controller.errorMessage ?? '保存地址失败');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialAddress == null ? '新增地址' : '编辑地址'),
      ),
      body: _loadingRegions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: '收货人'),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? '请填写收货人' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '手机号'),
                    validator: (value) =>
                        RegExp(r'^1\d{10}$').hasMatch(value?.trim() ?? '')
                        ? null
                        : '请输入正确的手机号',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('province-$_provinceCode'),
                    initialValue: _provinceCode,
                    decoration: const InputDecoration(labelText: '省/自治区'),
                    items: _provinces.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _provinceCode = value;
                      _cityCode = null;
                      _areaCode = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('city-$_provinceCode-$_cityCode'),
                    initialValue: _cityCode,
                    decoration: const InputDecoration(labelText: '城市'),
                    items: _availableCities.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: _provinceCode == null
                        ? null
                        : (value) => setState(() {
                            _cityCode = value;
                            _areaCode = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('area-$_cityCode-$_areaCode'),
                    initialValue: _areaCode,
                    decoration: const InputDecoration(labelText: '区/县'),
                    items: _availableAreas.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: _cityCode == null
                        ? null
                        : (value) => setState(() => _areaCode = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _details,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '详细地址'),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? '请填写详细地址' : null,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isDefault,
                    onChanged: (value) => setState(() => _isDefault = value),
                    title: const Text('设为默认地址'),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '保存中…' : '保存地址'),
                  ),
                ],
              ),
            ),
    );
  }
}

class ShopExpressPage extends StatefulWidget {
  const ShopExpressPage({
    required this.controller,
    required this.orderId,
    super.key,
  });

  final AppController controller;
  final int orderId;

  @override
  State<ShopExpressPage> createState() => _ShopExpressPageState();
}

class _ShopExpressPageState extends State<ShopExpressPage> {
  List<Map<String, Object?>> _shipments = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final shipments = await widget.controller.loadOrderExpress(widget.orderId);
    if (!mounted) return;
    setState(() {
      _shipments = shipments;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('物流信息')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shipments.isEmpty
          ? _ShopFailure(
              message: widget.controller.errorMessage ?? '暂无物流信息',
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _shipments.length,
                itemBuilder: (_, index) {
                  final shipment = _shipments[index];
                  final traces = _mapList(shipment['trace']);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${shipment['express_company'] ?? '快递'}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text('快递单号：${shipment['express_no'] ?? '--'}'),
                          const Divider(height: 28),
                          for (final trace in traces)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.radio_button_checked),
                              title: Text('${trace['remark'] ?? ''}'),
                              subtitle: Text('${trace['datetime'] ?? ''}'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class ShopNetworkImage extends StatelessWidget {
  const ShopNetworkImage({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFF0F2F5),
        child: Center(
          child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const ColoredBox(
              color: Color(0xFFF0F2F5),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFF0F2F5),
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      ),
    );
  }
}

class _ShopFailure extends StatelessWidget {
  const _ShopFailure({
    required this.message,
    required this.onRetry,
    this.actionLabel = '重新加载',
  });

  final String message;
  final FutureOr<void> Function() onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

Map<String, Object?> _cartItem(
  Map<String, Object?> product,
  Map<String, Object?> sku,
  int quantity,
) => {
  'product_id': product['id'],
  'sku_id': sku['id'],
  'product_name': product['name'],
  'sku_name': sku['name'],
  'picture': sku['picture'] ?? product['picture'],
  'price': sku['price'] ?? product['price'],
  'stock': sku['stock'],
  'quantity': quantity,
};

Map<String, Object?> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry('$key', value));
}

Map<String, Object?>? _mapOrNull(Object? value) {
  final result = _map(value);
  return result.isEmpty ? null : result;
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(_map).toList();
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry('$key', '$value'));
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String _money(Object? value) => _asDouble(value).toStringAsFixed(2);

String _plainText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .trim();

String _addressText(Map<String, Object?> address) =>
    '${address['address_name'] ?? address['region'] ?? ''} '
            '${address['address_details'] ?? ''}'
        .trim();

String? _regionCode(Object? value) {
  final parsed = _asInt(value);
  if (parsed == null || parsed <= 0) return null;
  return '$parsed';
}
