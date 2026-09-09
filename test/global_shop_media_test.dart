import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/shop_pages.dart';

const _blockedMedia = [
  'http://sd.cc/watch.jpg',
  'https://sd.cc/watch.jpg',
  'https://app.saidian.cc/watch.jpg',
  'https://app.saydian.cn/files/domestic-watch.jpg',
];
const _allowedMedia = {
  '/files/relative-watch.jpg':
      'https://app.saydian.cn/global/files/relative-watch.jpg',
  'https://app.saydian.cn/global/files/watch.jpg':
      'https://app.saydian.cn/global/files/watch.jpg',
  'https://cdn.example.invalid/watch.jpg':
      'https://cdn.example.invalid/watch.jpg',
};

class _ShopMediaController extends Fake implements AppController {
  @override
  bool get isGlobalEdition => true;

  @override
  Future<Map<String, Object?>> loadShopHome() async => {
    'items': [
      {
        'type': 'tabs',
        'value': [
          {
            'name': 'Test category',
            'list': [
              for (final (index, url) in [
                ..._blockedMedia,
                ..._allowedMedia.keys,
              ].indexed)
                {
                  'id': index + 1,
                  'name': 'Test product ${index + 1}',
                  'picture': url,
                  'price': 1,
                },
            ],
          },
        ],
      },
    ],
  };

  @override
  Future<Map<String, Object?>> loadShopProduct(int id) async => {
    'id': id,
    'name': 'Test product',
    'price': 1,
    'intro': [
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
    .widgetList<Image>(find.byType(Image))
    .map((image) => image.image)
    .whereType<NetworkImage>()
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
      expect(uri.path, startsWith('/global/'));
    }
  }
}

void main() {
  testWidgets(
    'global product list blocks domestic pictures and keeps global media',
    (tester) async {
      await _pumpShop(tester, ShopHomePage(controller: _ShopMediaController()));

      expect(find.text('Test product 7'), findsOneWidget);
      expect(
        find.byIcon(Icons.image_not_supported_outlined),
        findsNWidgets(_blockedMedia.length),
      );
      _expectOnlyAllowedMedia(_networkImageUrls(tester));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('global product HTML cannot create domestic NetworkImage URLs', (
    tester,
  ) async {
    await _pumpShop(
      tester,
      ShopProductPage(controller: _ShopMediaController(), productId: 1),
    );

    expect(find.text('Test description'), findsOneWidget);
    final urls = _networkImageUrls(tester);
    // The existing HTML renderer uses an empty source for filtered images.
    // Verify all HTML images were exercised, not merely an unbuilt detail.
    expect(urls, hasLength(_blockedMedia.length + _allowedMedia.length));
    expect(urls.where((url) => url.isEmpty), hasLength(_blockedMedia.length));
    _expectOnlyAllowedMedia(urls);
    expect(tester.takeException(), isNull);
  });
}
