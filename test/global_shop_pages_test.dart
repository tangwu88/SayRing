import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/global_shop_pages.dart';
import 'package:saydian_app/ui/shop_pages.dart';

class _Controller extends Fake implements AppController {
  final productRequests = <String>[];
  final filters = <String>[];
  Future<Map<String, Object?>> Function(String?, int)? products;

  @override
  bool get isGlobalEdition => true;
  @override
  Future<Map<String, Object?>> loadShopHome() async => {
    'banners': [],
    'categories': [
      {'id': 'category-id', 'name': 'Watches'},
    ],
    'featured': [
      {'id': 'uuid-featured', 'name': 'Featured watch'},
    ],
  };
  @override
  Future<Map<String, Object?>> loadGlobalShopProducts({
    String? keyword,
    String? categoryId,
    int page = 1,
  }) {
    filters.add('$keyword/$categoryId/$page');
    return products?.call(keyword, page) ??
        Future.value({
          'items': [
            {'id': 'uuid-watch', 'name': 'Catalog watch', 'priceCents': 1200},
          ],
          'total': 1,
        });
  }

  @override
  Future<Map<String, Object?>> loadGlobalShopProduct(String id) async {
    productRequests.add(id);
    return {
      'id': id,
      'displayName': 'Watch details',
      'skus': [
        {'id': 'uuid-sku', 'specification': 'Black', 'salePriceCents': 1200},
      ],
      'detailHtml':
          '<p>Real product description</p><script>do not display</script>',
    };
  }
}

Future<void> _pump(WidgetTester tester, Widget page, {double scale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (_, child) => MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'actual global shop entry renders V2 products and opens UUID details',
    (tester) async {
      final controller = _Controller();
      await _pump(tester, ShopHomePage(controller: controller));
      expect(find.byKey(const Key('global-shop-page')), findsOneWidget);
      expect(find.text('Catalog watch'), findsOneWidget);
      expect(find.text('Price to be confirmed'), findsOneWidget);
      expect(find.textContaining('¥'), findsNothing);
      expect(find.text('Buy now'), findsNothing);
      await tester.tap(find.text('Catalog watch'));
      await tester.pumpAndSettle();
      expect(controller.productRequests, ['uuid-watch']);
      expect(find.text('Watch details'), findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
      expect(find.text('Real product description'), findsOneWidget);
      expect(find.text('do not display'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Catalog watch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search rejects stale results and category uses server ID', (
    tester,
  ) async {
    final controller = _Controller();
    final old = Completer<Map<String, Object?>>();
    controller.products = (keyword, _) async {
      if (keyword == 'old') return old.future;
      return {
        'items': [
          {
            'id': 'uuid-new',
            'name': keyword?.isEmpty == false ? keyword : 'Initial',
          },
        ],
        'total': 1,
      };
    };
    await _pump(tester, ShopHomePage(controller: controller));
    await tester.enterText(find.byKey(const Key('shop-search')), 'old');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.enterText(find.byKey(const Key('shop-search')), 'new');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.pumpAndSettle();
    old.complete({
      'items': [
        {'id': 'uuid-old', 'name': 'STALE'},
      ],
      'total': 1,
    });
    await tester.pumpAndSettle();
    expect(find.text('STALE'), findsNothing);
    await tester.tap(find.text('Watches'));
    await tester.pumpAndSettle();
    expect(controller.filters.last, 'new/category-id/1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure is retryable and successful empty catalog is separate', (
    tester,
  ) async {
    final controller = _Controller();
    controller.products = (_, _) =>
        Future.error(StateError('internal server details'));
    await _pump(tester, ShopHomePage(controller: controller));
    expect(find.textContaining('internal server'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    controller.products = (_, _) async => {'items': [], 'total': 0};
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No data yet'), findsOneWidget);
  });

  testWidgets('catalog pagination uses next server page', (tester) async {
    final controller = _Controller();
    controller.products = (_, page) async => {
      'items': [
        {'id': 'uuid-$page', 'name': 'Page $page'},
      ],
      'total': 2,
    };
    await _pump(tester, ShopHomePage(controller: controller));
    await tester.tap(find.byKey(const Key('global-shop-more')));
    await tester.pumpAndSettle();
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.byKey(const Key('global-shop-more')), findsNothing);
  });

  testWidgets(
    'money requires actual currency and exponent; JPY and KWD retain minor units',
    (tester) async {
      final results = <String>[];
      await _pump(
        tester,
        Builder(
          builder: (context) {
            results.addAll([
              globalCatalogPrice(context, {'priceCents': 10}),
              globalCatalogPrice(context, {
                'priceCents': 0,
                'currency': 'USD',
                'currencyExponent': 2,
              }),
              globalCatalogPrice(context, {
                'priceCents': 1234,
                'currency': 'JPY',
                'currencyExponent': 0,
              }),
              globalCatalogPrice(context, {
                'priceCents': 1005,
                'currency': 'KWD',
                'currencyExponent': 3,
              }),
            ]);
            return const SizedBox();
          },
        ),
      );
      expect(results[0], 'Price to be confirmed');
      expect(results[1], contains('0.00'));
      expect(results[2], contains('1,234'));
      expect(results[3], contains('1.005'));
    },
  );

  for (final size in [const Size(375, 812), const Size(390, 844)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('global catalog and detail fit $size at scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _Controller();
        await _pump(tester, ShopHomePage(controller: controller), scale: scale);
        await tester.tap(find.text('Catalog watch'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
