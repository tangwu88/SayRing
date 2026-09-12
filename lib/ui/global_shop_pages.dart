import 'dart:async';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:share_plus/share_plus.dart';

import '../domain/global_commerce.dart';
import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';
import '../services/global_environment.dart';
import 'global_shop_account_pages.dart';
import 'global_shop_cart_pages.dart';
import 'global_shop_widgets.dart';
import 'widgets/safe_network_image.dart';

/// International storefront. Trading controls stay capability-gated by the
/// server while browsing remains available during market or payment downtime.
class GlobalShopHomePage extends StatefulWidget {
  const GlobalShopHomePage({required this.controller, super.key});
  final AppController controller;

  @override
  State<GlobalShopHomePage> createState() => _GlobalShopHomePageState();
}

class _GlobalShopHomePageState extends State<GlobalShopHomePage> {
  List<Map<String, Object?>> _categories = const [];
  List<Map<String, Object?>> _banners = const [];
  List<Map<String, Object?>> _products = const [];
  String? _category;
  String _keyword = '';
  int _page = 1;
  int _generation = 0;
  bool _loading = true;
  bool _failed = false;
  bool _hasMore = false;
  GlobalCommerceCapabilities _capabilities =
      GlobalCommerceCapabilities.unavailable;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load(loadHome: true));
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _generation++;
    super.dispose();
  }

  Future<void> _load({bool loadHome = false, bool more = false}) async {
    _searchTimer?.cancel();
    final generation = ++_generation;
    final requestedPage = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _failed = false;
      if (!more) _products = const [];
    });
    try {
      if (loadHome) {
        final home = await widget.controller.loadShopHome();
        if (!mounted || generation != _generation) return;
        if (home.isEmpty) throw StateError('Catalog unavailable');
        _categories = _rows(home['categories']);
        _banners = _rows(home['banners']);
        try {
          _capabilities = GlobalCommerceCapabilities.fromJson(
            await widget.controller.loadGlobalCommerceCapabilities(),
          );
        } catch (_) {
          _capabilities = GlobalCommerceCapabilities.unavailable;
        }
      }
      final result = await widget.controller.loadGlobalShopProducts(
        keyword: _keyword,
        categoryId: _category,
        page: requestedPage,
      );
      if (!mounted || generation != _generation) return;
      final rows = _rows(result['items']);
      final total = result['total'];
      setState(() {
        _products = more ? [..._products, ...rows] : rows;
        _page = requestedPage;
        _hasMore = total is int && _products.length < total && rows.isNotEmpty;
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

  void _search(String keyword) {
    _keyword = keyword;
    // Invalidate the previous response immediately, not after the debounce.
    _generation++;
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () => _load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-shop-page'),
    appBar: AppBar(
      title: Text(context.l10n.shop),
      actions: [
        IconButton(
          key: const Key('global-shop-cart-action'),
          tooltip: context.l10n.cart,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GlobalShopCartPage(controller: widget.controller),
            ),
          ),
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
        IconButton(
          key: const Key('global-shop-account-action'),
          tooltip: context.l10n.shopAccount,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GlobalShopAccountPage(
                controller: widget.controller,
                openProduct: _openProductId,
              ),
            ),
          ),
          icon: const Icon(Icons.person_outline),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            key: const Key('shop-search'),
            onChanged: _search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: context.l10n.searchProducts,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        if (!_capabilities.checkoutEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: GlobalShopNotice(text: context.l10n.globalShopBrowseNotice),
          ),
        if (_categories.isNotEmpty)
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _categoryChip(null, context.l10n.all),
                for (final category in _categories)
                  if (category['id'] is String)
                    _categoryChip(
                      category['id'] as String,
                      '${category['name'] ?? ''}',
                    ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(loadHome: true),
            child: ListView(
              key: const Key('global-shop-products'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (_keyword.trim().isEmpty && _category == null)
                  for (final banner in _banners)
                    if (banner['imageUrl'] is String)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          height: 112,
                          child: _CatalogImage('${banner['imageUrl']}'),
                        ),
                      ),
                for (final product in _products)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openProduct(product),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox.square(
                              dimension: 84,
                              child: _CatalogImage(
                                '${product['coverImage'] ?? ''}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${product['name'] ?? ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    globalCatalogPrice(
                                      context,
                                      _capabilities.withCurrency(product),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_failed)
                  _CatalogRetry(onRetry: () => _load(loadHome: true))
                else if (_products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      context.l10n.noData,
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (!_loading && !_failed && _hasMore)
                  OutlinedButton(
                    key: const Key('global-shop-more'),
                    onPressed: () => _load(more: true),
                    child: Text(context.l10n.globalShopLoadMore),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _categoryChip(String? id, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _category == id,
      onSelected: (_) {
        _category = id;
        unawaited(_load());
      },
    ),
  );

  void _openProduct(Map<String, Object?> product) {
    final id = product['id'];
    if (id is! String || id.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.serviceUnavailable)));
      return;
    }
    _openProductId(context, id);
  }

  void _openProductId(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GlobalShopProductPage(controller: widget.controller, productId: id),
      ),
    );
  }
}

class GlobalShopProductPage extends StatefulWidget {
  const GlobalShopProductPage({
    required this.controller,
    required this.productId,
    super.key,
  });
  final AppController controller;
  final String productId;

  @override
  State<GlobalShopProductPage> createState() => _GlobalShopProductPageState();
}

class _GlobalShopProductPageState extends State<GlobalShopProductPage> {
  Map<String, Object?>? _product;
  GlobalCommerceCapabilities _capabilities =
      GlobalCommerceCapabilities.unavailable;
  String? _selectedSkuId;
  String? _currentImage;
  int _quantity = 1;
  bool _loading = true;
  bool _busy = false;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait<Object>([
        widget.controller.loadGlobalShopProduct(widget.productId),
        widget.controller.loadGlobalCommerceCapabilities(),
      ]);
      final value = values[0] as Map<String, Object?>;
      final capabilities = GlobalCommerceCapabilities.fromJson(
        values[1] as Map<String, Object?>,
      );
      var favorite = value['favorite'] == true;
      if (widget.controller.isAuthenticated) {
        try {
          favorite = (await widget.controller.loadGlobalShopFavorites()).any(
            (item) => commerceId(item['id']) == widget.productId,
          );
        } catch (_) {
          // Favorite state is optional; product details remain usable.
        }
      }
      final skus = _rows(value['skus']);
      final selected = skus.cast<Map<String, Object?>?>().firstWhere(
        (sku) => (commerceCents(sku?['stock']) ?? 0) > 0,
        orElse: () => skus.isEmpty ? null : skus.first,
      );
      if (mounted) {
        final images = _productImages(value);
        setState(() {
          _product = value.isEmpty ? null : value;
          _capabilities = capabilities;
          _selectedSkuId = commerceId(selected?['id']);
          _currentImage = images.contains(_currentImage)
              ? _currentImage
              : (images.isEmpty ? null : images.first);
          _favorite = favorite;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _product = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, Object?>> get _skus => _rows(_product?['skus']);
  Map<String, Object?>? get _selectedSku {
    for (final sku in _skus) {
      if (commerceId(sku['id']) == _selectedSkuId) return sku;
    }
    return null;
  }

  bool get _available =>
      _selectedSku != null && (commerceCents(_selectedSku!['stock']) ?? 0) > 0;

  List<String> get _images => _productImages(_product);

  Future<void> _shareProduct() async {
    final product = _product;
    if (product == null || _busy) return;
    final name = commerceText(product['displayName']).isNotEmpty
        ? commerceText(product['displayName'])
        : commerceText(product['name']);
    final target = Uri.parse('${GlobalEnvironment.origin}/global/saidian-mall/')
        .replace(
          fragment:
              '/pages/product/index?id=${Uri.encodeQueryComponent(widget.productId)}',
        );
    try {
      final result = await SharePlus.instance.share(
        ShareParams(subject: name, text: '$name\n$target'),
      );
      if (mounted && result.status == ShareResultStatus.unavailable) {
        _message(context.l10n.serviceUnavailable);
      }
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    }
  }

  Future<void> _setFavorite() async {
    if (_busy || !widget.controller.isAuthenticated) return;
    setState(() => _busy = true);
    try {
      await widget.controller.setGlobalShopFavorite(
        widget.productId,
        !_favorite,
      );
      if (mounted) setState(() => _favorite = !_favorite);
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addToCart() async {
    final sku = _selectedSku;
    if (_busy || sku == null || !_available) return;
    if (!widget.controller.isAuthenticated) {
      _message(context.l10n.signInToShopHint);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.controller.updateGlobalShopCartItem(
        skuId: commerceId(sku['id']),
        quantity: _quantity,
        mode: 'increment',
      );
      if (mounted) _message(context.l10n.addedToCart);
    } catch (_) {
      if (mounted) _message(context.l10n.serviceUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyNow() async {
    final sku = _selectedSku;
    final product = _product;
    if (sku == null || product == null || !_available) return;
    if (!widget.controller.isAuthenticated) {
      _message(context.l10n.signInToShopHint);
      return;
    }
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GlobalShopCheckoutPage(
          controller: widget.controller,
          capabilities: _capabilities,
          items: [
            {
              'skuId': commerceId(sku['id']),
              'quantity': _quantity,
              'sku': sku,
              'product': product,
            },
          ],
        ),
      ),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      key: const Key('global-shop-product-page'),
      appBar: AppBar(
        title: Text(context.l10n.productDetails),
        actions: [
          if (product != null)
            IconButton(
              tooltip: context.l10n.shareProduct,
              onPressed: _busy ? null : _shareProduct,
              icon: const Icon(Icons.share_outlined),
            ),
          if (product != null && widget.controller.isAuthenticated)
            IconButton(
              key: const Key('global-product-favorite'),
              tooltip: context.l10n.favorites,
              onPressed: _busy ? null : _setFavorite,
              icon: Icon(_favorite ? Icons.favorite : Icons.favorite_border),
            ),
          IconButton(
            tooltip: context.l10n.cart,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    GlobalShopCartPage(controller: widget.controller),
              ),
            ),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : product == null
          ? GlobalShopRetry(onRetry: _load)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
              children: [
                if (_images.isNotEmpty) ...[
                  SizedBox(
                    height: 240,
                    child: _CatalogImage(_currentImage ?? _images.first),
                  ),
                  if (_images.length > 1) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final image = _images[index];
                          final selected = image == _currentImage;
                          return InkWell(
                            onTap: () => setState(() => _currentImage = image),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 64,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).dividerColor,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: _CatalogImage(image),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                if (_strings(product['tags']).isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in _strings(product['tags']))
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(tag),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  '${product['displayName'] ?? product['name'] ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if ('${product['subtitle'] ?? ''}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${product['subtitle']}'),
                  ),
                const SizedBox(height: 16),
                if (_skus.isNotEmpty)
                  Text(
                    context.l10n.selectVariant,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sku in _skus)
                      ChoiceChip(
                        label: Text(
                          commerceText(sku['specification']).isNotEmpty
                              ? commerceText(sku['specification'])
                              : context.l10n.defaultVariant,
                        ),
                        selected: commerceId(sku['id']) == _selectedSkuId,
                        onSelected: (_) => setState(() {
                          _selectedSkuId = commerceId(sku['id']);
                          _quantity = 1;
                          final image = commerceText(sku['image']);
                          if (image.isNotEmpty) _currentImage = image;
                        }),
                      ),
                  ],
                ),
                if (_selectedSku != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        globalCatalogPrice(
                          context,
                          _capabilities.withCurrency({
                            ...product,
                            ..._selectedSku!,
                            'priceCents': _selectedSku!['salePriceCents'],
                          }),
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFBE092D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((commerceCents(_selectedSku!['marketPriceCents']) ??
                              0) >
                          (commerceCents(_selectedSku!['salePriceCents']) ?? 0))
                        Text(
                          globalCatalogPrice(
                            context,
                            _capabilities.withCurrency({
                              ...product,
                              'priceCents': _selectedSku!['marketPriceCents'],
                            }),
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                decoration: TextDecoration.lineThrough,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _available
                        ? context.l10n.stockCount(
                            commerceCents(_selectedSku!['stock']) ?? 0,
                          )
                        : context.l10n.outOfStock,
                  ),
                  LayoutBuilder(
                    builder: (context, _) {
                      final controls = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.outlined(
                            onPressed: _quantity <= 1
                                ? null
                                : () => setState(() => _quantity--),
                            icon: const Icon(Icons.remove),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '$_quantity',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton.outlined(
                            onPressed:
                                !_available ||
                                    _quantity >=
                                        (commerceCents(
                                              _selectedSku!['stock'],
                                            ) ??
                                            0)
                                ? null
                                : () => setState(() => _quantity++),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      );
                      if (MediaQuery.textScalerOf(context).scale(16) >= 26) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n.quantity),
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
                          Text(context.l10n.quantity),
                          const Spacer(),
                          controls,
                        ],
                      );
                    },
                  ),
                ],
                if (_rows(product['skus']).isEmpty)
                  Text(globalCatalogPrice(context, product)),
                if (!_capabilities.checkoutEnabled) ...[
                  const SizedBox(height: 12),
                  GlobalShopNotice(text: context.l10n.marketUnavailable),
                ],
                for (final url
                    in (product['gallery'] is List
                            ? product['gallery'] as List
                            : const [])
                        .whereType<String>())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _CatalogImage(url),
                  ),
                ..._detailWidgets('${product['detailHtml'] ?? ''}'),
                if (_rows(product['reviews']).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.customerReviews,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final review in _rows(product['reviews']))
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              commerceText(
                                    commerceMap(review['user'])['nickname'],
                                  ).isNotEmpty
                                  ? commerceText(
                                      commerceMap(review['user'])['nickname'],
                                    )
                                  : 'Saydian',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_ratingStars(review['rating'])),
                            if (commerceText(review['content']).isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(commerceText(review['content'])),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
      bottomNavigationBar: _loading || product == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Color(0x16000000), blurRadius: 12),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(16) >= 26;
                    final add = OutlinedButton(
                      key: const Key('global-product-add-cart'),
                      onPressed: _busy || !_available ? null : _addToCart,
                      child: Text(context.l10n.addToCart),
                    );
                    final buy = FilledButton(
                      key: const Key('global-product-buy-now'),
                      onPressed:
                          _busy || !_available || !_capabilities.checkoutEnabled
                          ? null
                          : _buyNow,
                      child: Text(context.l10n.buyNow),
                    );
                    if (largeText) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: double.infinity, child: add),
                          const SizedBox(height: 8),
                          SizedBox(width: double.infinity, child: buy),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: add),
                        const SizedBox(width: 12),
                        Expanded(child: buy),
                      ],
                    );
                  },
                ),
              ),
            ),
    );
  }
}

/// Missing currency metadata is not CNY, and missing amounts are never zero.
String globalCatalogPrice(BuildContext context, Map<String, Object?> row) {
  return globalShopMoney(context, row);
}

List<Map<String, Object?>> _rows(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => row.map((key, value) => MapEntry('$key', value)))
          .toList()
    : const [];

List<String> _strings(Object? value) => value is List
    ? value
          .map(commerceText)
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];

List<String> _productImages(Map<String, Object?>? product) {
  if (product == null) return const [];
  final result = <String>{};
  void add(Object? value) {
    final text = commerceText(value);
    if (text.isNotEmpty) result.add(text);
  }

  add(product['coverImage']);
  for (final image in _strings(product['gallery'])) {
    add(image);
  }
  for (final sku in _rows(product['skus'])) {
    add(sku['image']);
  }
  return result.toList(growable: false);
}

String _ratingStars(Object? value) {
  final rating = commerceCents(value) ?? 0;
  final normalized = rating < 0 ? 0 : (rating > 5 ? 5 : rating);
  return '${List.filled(normalized, '★').join()}${List.filled(5 - normalized, '☆').join()}';
}

List<Widget> _detailWidgets(String source) {
  final document = html.parse(source);
  for (final element in document.querySelectorAll(
    'script,style,iframe,object,embed',
  )) {
    element.remove();
  }
  final widgets = <Widget>[];
  final text = StringBuffer();
  void flushText() {
    final value = text.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    text.clear();
    if (value.isEmpty) return;
    widgets.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(value),
      ),
    );
  }

  void visit(dom.Node node) {
    if (node is dom.Text) {
      text.write('${node.data} ');
      return;
    }
    if (node is! dom.Element) return;
    if (node.localName == 'img') {
      flushText();
      final source = node.attributes['src']?.trim() ?? '';
      if (source.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _CatalogImage(source),
          ),
        );
      }
      return;
    }
    if (node.localName == 'br') {
      text.write('\n');
      return;
    }
    final block = const {
      'p',
      'div',
      'section',
      'article',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'li',
    }.contains(node.localName);
    if (block) flushText();
    if (node.localName == 'li') text.write('• ');
    for (final child in node.nodes) {
      visit(child);
    }
    if (block) flushText();
  }

  for (final node in document.body?.nodes ?? const <dom.Node>[]) {
    visit(node);
  }
  flushText();
  return widgets;
}

class _CatalogImage extends StatelessWidget {
  const _CatalogImage(this.url);
  final String url;

  @override
  Widget build(BuildContext context) {
    final source = GlobalEnvironment.media(url);
    if (source.isEmpty) {
      return const Center(child: Icon(Icons.image_not_supported_outlined));
    }
    return SafeNetworkImage(
      source,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }
}

class _CatalogRetry extends StatelessWidget {
  const _CatalogRetry({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.serviceUnavailable, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: Text(context.l10n.retry)),
      ],
    ),
  );
}
