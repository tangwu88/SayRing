import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;
import 'package:intl/intl.dart';

import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';
import '../services/global_environment.dart';
import 'widgets/safe_network_image.dart';

/// International catalog is deliberately browse-only until market prices,
/// shipping and payment channels have all been accepted by the server.
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
    appBar: AppBar(title: Text(context.l10n.shop)),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.l10n.globalShopReadOnly),
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
                                  Text(globalCatalogPrice(context, product)),
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final value = await widget.controller.loadGlobalShopProduct(
        widget.productId,
      );
      if (mounted) setState(() => _product = value.isEmpty ? null : value);
    } catch (_) {
      if (mounted) setState(() => _product = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      key: const Key('global-shop-product-page'),
      appBar: AppBar(title: Text(context.l10n.productDetails)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : product == null
          ? _CatalogRetry(onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if ('${product['coverImage'] ?? ''}'.isNotEmpty)
                  SizedBox(
                    height: 220,
                    child: _CatalogImage('${product['coverImage']}'),
                  ),
                const SizedBox(height: 16),
                Text(
                  '${product['displayName'] ?? product['name'] ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if ('${product['subtitle'] ?? ''}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${product['subtitle']}'),
                  ),
                Text(context.l10n.globalShopReadOnly),
                const SizedBox(height: 16),
                for (final sku in _rows(product['skus']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${sku['specification'] ?? context.l10n.variant}',
                    ),
                    subtitle: Text(
                      globalCatalogPrice(context, {
                        ...product,
                        ...sku,
                        'priceCents': sku['salePriceCents'],
                      }),
                    ),
                  ),
                if (_rows(product['skus']).isEmpty)
                  Text(globalCatalogPrice(context, product)),
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
              ],
            ),
    );
  }
}

/// Missing currency metadata is not CNY, and missing amounts are never zero.
String globalCatalogPrice(BuildContext context, Map<String, Object?> row) {
  final amount = row['priceCents'];
  final currency = row['currency'];
  final exponent = row['currencyExponent'];
  if (amount is! int ||
      amount < 0 ||
      currency is! String ||
      !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
      exponent is! int ||
      exponent < 0 ||
      exponent > 4) {
    return context.l10n.globalShopPricePending;
  }
  return NumberFormat.currency(
    locale: Localizations.localeOf(context).toLanguageTag(),
    name: currency,
    symbol: currency,
    decimalDigits: exponent,
  ).format(amount / math.pow(10, exponent));
}

List<Map<String, Object?>> _rows(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => row.map((key, value) => MapEntry('$key', value)))
          .toList()
    : const [];

List<Widget> _detailWidgets(String source) {
  final document = html.parse(source);
  for (final element in document.querySelectorAll(
    'script,style,iframe,object,embed',
  )) {
    element.remove();
  }
  final text = document.body?.text.trim() ?? '';
  return [
    if (text.isNotEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text),
      ),
    for (final element in document.querySelectorAll('img'))
      if (element.attributes['src']?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _CatalogImage(element.attributes['src']!),
        ),
  ];
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
