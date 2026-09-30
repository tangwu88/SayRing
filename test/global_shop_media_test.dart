import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/shop_pages.dart';
import 'package:saydian_app/ui/global_shop_pages.dart';
import 'package:saydian_app/ui/widgets/safe_network_image.dart';

const _blockedMedia = [
  'http://sd.cc/watch.jpg',
  'https://app.saidian.cc/watch.jpg',
  '/files/relative-watch.jpg',
  'https://app.saydian.cn/global/files/watch.jpg',
  'https://cdn.example.invalid/watch.jpg',
];
const _allowedMedia = {
  '/api/saydian-app/v2/files/relative-watch.jpg':
      'https://app.saydian.cn/global/api/saydian-app/v2/files/relative-watch.jpg',
  'https://app.saydian.cn/global/api/saydian-app/v2/files/watch.jpg':
      'https://app.saydian.cn/global/api/saydian-app/v2/files/watch.jpg',
};

class _ShopMediaController extends Fake implements AppController {
  @override
  bool get commerceEnabled => true;
  @override
  bool get isGlobalEdition => true;
  @override
  bool get isAuthenticated => false;

  @override
  Future<Map<String, Object?>> loadGlobalCommerceCapabilities() async => {
    'checkout': {
      'enabled': false,
      'countryCodes': ['CN'],
      'currency': 'CNY',
      'currencyExponent': 2,
    },
    'payments': <Object?>[],
    'maintenance': {'readOnly': false},
  };

  @override
  Future<Map<String, Object?>> loadShopHome() async => {
    'categories': [
      {'id': 'test-category', 'name': 'Test category'},
    ],
    'featured': [],
  };

  @override
  Future<Map<String, Object?>> loadGlobalShopProducts({
    String? keyword,
    String? categoryId,
    int page = 1,
  }) async => {
    'items': [
      for (final (index, url) in [
        ..._blockedMedia,
        ..._allowedMedia.keys,
      ].indexed)
        {
          'id': 'product-${index + 1}',
          'name': 'Test product ${index + 1}',
          'coverImage': url,
          'priceCents': 100,
        },
    ],
  };

  @override
  Future<Map<String, Object?>> loadGlobalShopProduct(String id) async => {
    'id': id,
    'name': 'Test product',
    'price': 1,
    'detailHtml': [
      '<p>Test description</p>',
      for (final url in [..._blockedMedia, ..._allowedMedia.keys])
        '<img src="$url">',
    ].join(),
  };
}

Future<void> _pumpShop(WidgetTester tester, Widget page) async {
  // Keep every fixture image mounted, including the lazy product list and
  // detail HTML below the cover. Flutter's test binding blocks actual HTTP.
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _networkImageUrls(WidgetTester tester) => tester
    .widgetList<Image>(find.byWidgetPredicate((widget) => widget is Image))
    .map((image) => image.image)
    .whereType<SafeNetworkImageProvider>()
    .map((provider) => provider.url)
    .toList();

void _expectOnlyAllowedMedia(List<String> urls) {
  expect(
    urls.where((url) => url.isNotEmpty),
    unorderedEquals(_allowedMedia.values),
  );
  for (final url in urls.where((url) => url.isNotEmpty)) {
    final uri = Uri.parse(url);
    expect(uri.scheme, 'https');
    expect({'sd.cc', 'app.saidian.cc'}, isNot(contains(uri.host)));
    if (uri.host == 'app.saydian.cn') {
      expect(uri.path, startsWith('/global/api/saydian-app/v2/'));
    }
  }
}

void main() {
  testWidgets(
    'global product list blocks domestic pictures and keeps global media',
    (tester) async {
      await _pumpShop(tester, ShopHomePage(controller: _ShopMediaController()));

      expect(find.text('Test product 7'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsWidgets);
      _expectOnlyAllowedMedia(_networkImageUrls(tester));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('global product HTML cannot create domestic NetworkImage URLs', (
    tester,
  ) async {
    await _pumpShop(
      tester,
      GlobalShopProductPage(
        controller: _ShopMediaController(),
        productId: 'product-1',
      ),
    );

    expect(find.text('Test description'), findsOneWidget);
    final urls = _networkImageUrls(tester);
    // Both list and detail use only validated first-party image providers.
    expect(urls, hasLength(_allowedMedia.length));
    _expectOnlyAllowedMedia(urls);
    expect(tester.takeException(), isNull);
  });
}
