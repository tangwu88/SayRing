import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_commerce.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/global_shop_account_pages.dart';
import 'package:saydian_app/ui/global_shop_cart_pages.dart';

const _skuId = '11111111-1111-4111-8111-111111111111';
const _orderId = '22222222-2222-4222-8222-222222222222';
const _addressId = '33333333-3333-4333-8333-333333333333';
const _itemA = '44444444-4444-4444-8444-444444444444';
const _itemB = '55555555-5555-4555-8555-555555555555';
final _quoteFingerprint = 'q1:${List.filled(64, 'a').join()}';

Map<String, Object?> _capabilities({bool nativePayment = true}) => {
  'checkout': {
    'enabled': true,
    'countryCodes': ['US'],
    'currency': 'USD',
    'currencyExponent': 2,
  },
  'payments': [
    if (nativePayment)
      {
        'channel': 'test_native',
        'enabled': true,
        'environments': ['android', 'ios'],
      },
  ],
  'maintenance': {'readOnly': false},
};

Map<String, Object?> _cart({int quantity = 2}) => {
  'items': [
    {
      'id': 'cart-item',
      'skuId': _skuId,
      'quantity': quantity,
      'selected': true,
      'available': true,
      'sku': {
        'id': _skuId,
        'specification': 'Black',
        'salePriceCents': 1299,
        'stock': 5,
        'product': {
          'id': 'product-id',
          'displayName': 'Saydian watch',
          'coverImage': '',
        },
      },
    },
  ],
};

List<Map<String, Object?>> get _checkoutItems => [
  {
    'skuId': _skuId,
    'quantity': 2,
    'sku': {
      'id': _skuId,
      'specification': 'Black',
      'salePriceCents': 1299,
      'stock': 5,
      'product': {'id': 'product-id', 'displayName': 'Saydian watch'},
    },
    'product': {'id': 'product-id', 'displayName': 'Saydian watch'},
  },
];

class _FlowController extends Fake implements AppController {
  final drafts = <String, Map<String, Object?>>{};
  final placed = <Map<String, Object?>>[];
  final afterSales = <Map<String, Object?>>[];
  final cartUpdates = <Map<String, Object?>>[];
  final couponPages = <int>[];
  final pointPages = <int>[];
  Object? placeError;
  Object? afterSaleError;
  bool nativePayment = true;
  bool capabilityFailure = false;

  @override
  bool get isAuthenticated => true;

  @override
  Future<Map<String, Object?>> loadGlobalCommerceCapabilities() async {
    if (capabilityFailure) {
      throw const ApiException('commerce_capabilities_unavailable');
    }
    return _capabilities(nativePayment: nativePayment);
  }

  @override
  Future<Map<String, Object?>> loadGlobalShopCart() async => _cart();

  @override
  Future<Map<String, Object?>> loadGlobalShopOrder(String id) async => {
    'id': id,
    'orderNo': 'GLOBAL-1001',
    'status': 'AFTER_SALE',
    'createdAt': '2026-09-13T00:00:00Z',
    'currency': 'USD',
    'currencyExponent': 2,
    'subtotalCents': 2598,
    'discountCents': 0,
    'pointDiscountCents': 0,
    'shippingCents': 0,
    'payableCents': 2598,
    'allowedActions': <String>[],
    'items': [
      {
        'id': _itemA,
        'productId': 'product-id',
        'nameSnapshot': 'Saydian watch',
        'specificationSnapshot': 'Black',
        'imageSnapshot': '',
        'quantity': 2,
        'review': {'id': 'review-id'},
      },
    ],
    'afterSales': [
      {
        'id': 'after-sale-id',
        'afterSaleNo': 'AS-1001',
        'type': 'RETURN_REFUND',
        'status': 'COMPLETED',
        'reason': 'Screen issue',
        'description': 'The display no longer turns on.',
        'requestedCents': 1234,
        'pointReturnCents': 100,
        'evidenceImages': <String>[],
        'items': [
          {'orderItemId': _itemA, 'quantity': 1},
        ],
        'refunds': [
          {'id': 'refund-id', 'status': 'SUCCEEDED', 'amountCents': 1234},
        ],
      },
    ],
  };

  @override
  Future<Map<String, Object?>> updateGlobalShopCartItem({
    required String skuId,
    required int quantity,
    bool selected = true,
    String mode = 'set',
  }) async {
    cartUpdates.add({
      'skuId': skuId,
      'quantity': quantity,
      'selected': selected,
      'mode': mode,
    });
    return _cart(quantity: quantity);
  }

  @override
  Future<Map<String, Object?>> removeGlobalShopCartItem(String id) async => {
    'items': <Object?>[],
  };

  @override
  Future<List<Map<String, Object?>>> loadGlobalShopAddresses() async => [
    {
      'id': _addressId,
      'name': 'Alex',
      'mobile': '+12025550123',
      'countryCode': 'US',
      'province': 'California',
      'city': 'San Francisco',
      'detail': '1 Market Street',
      'postalCode': '94105',
      'isDefault': true,
    },
  ];

  @override
  Future<List<Map<String, Object?>>> loadGlobalShopCoupons() async => [];

  @override
  Future<Map<String, Object?>> previewGlobalShopOrder({
    required String addressId,
    required List<Map<String, Object?>> items,
    String? couponClaimId,
    int pointCents = 0,
    String buyerRemark = '',
  }) async => {
    'quote': {
      'fingerprint': _quoteFingerprint,
      'currency': 'USD',
      'currencyExponent': 2,
      'subtotalCents': 2598,
      'couponDiscountCents': 0,
      'pointDiscountCents': 0,
      'shippingCents': 0,
      'payableCents': 2598,
    },
  };

  @override
  Future<Map<String, Object?>> placeGlobalShopOrder({
    required String addressId,
    required List<Map<String, Object?>> items,
    required String expectedQuote,
    required String idempotencyKey,
    String? couponClaimId,
    int pointCents = 0,
    String buyerRemark = '',
  }) async {
    placed.add({
      'addressId': addressId,
      'items': items,
      'expectedQuote': expectedQuote,
      'idempotencyKey': idempotencyKey,
      'couponClaimId': couponClaimId,
      'pointCents': pointCents,
      'buyerRemark': buyerRemark,
    });
    if (placeError case final error?) throw error;
    return {'id': _orderId};
  }

  @override
  Future<Map<String, Object?>?> readGlobalShopDraft(String key) async =>
      drafts[key];

  @override
  Future<void> writeGlobalShopDraft(
    String key,
    Map<String, Object?> value,
  ) async {
    drafts[key] = Map<String, Object?>.from(value);
  }

  @override
  Future<void> clearGlobalShopDraft(String key) async {
    drafts.remove(key);
  }

  @override
  Future<Map<String, Object?>> loadGlobalShopEvidenceCapabilities() async => {
    'enabled': false,
    'maxFiles': 9,
  };

  @override
  Future<Map<String, Object?>> previewGlobalShopAfterSale({
    required String orderId,
    required Map<String, Object?> input,
  }) async => {
    'orderVersion': 2,
    'type': input['type'],
    'items': input['items'],
    'merchandiseRefundCents': 1800,
    'shippingRefundCents': 0,
    'pointReturnCents': 0,
    'requestedCents': 1800,
  };

  @override
  Future<Map<String, Object?>> createGlobalShopAfterSale({
    required String orderId,
    required Map<String, Object?> input,
  }) async {
    afterSales.add(Map<String, Object?>.from(input));
    if (afterSaleError case final error?) throw error;
    return {'id': 'after-sale-id'};
  }

  @override
  Future<Map<String, Object?>> loadGlobalShopAvailableCoupons({
    int page = 1,
  }) async {
    couponPages.add(page);
    return {
      'items': [
        {
          'id': 'coupon-$page',
          'name': 'Coupon page $page',
          'available': true,
          'claimed': false,
          'validFrom': '2026-09-01T00:00:00Z',
          'validUntil': '2026-12-31T00:00:00Z',
        },
      ],
      'pagination': {'hasMore': page == 1},
    };
  }

  @override
  Future<Map<String, Object?>> loadGlobalShopPoints({int page = 1}) async {
    pointPages.add(page);
    return {
      'verified': true,
      'balanceCents': 2500,
      'items': [
        {
          'id': 'ledger-$page',
          'type': page == 1 ? 'ORDER_DEDUCT' : 'AFTER_SALE_RETURN',
          'deltaCents': page == 1 ? -500 : 300,
          'createdAt': '2026-09-13T00:00:00Z',
        },
      ],
      'pagination': {'hasMore': page == 1},
    };
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (_, child) => MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cart quantity totals and controls fit a narrow 2x layout', (
    tester,
  ) async {
    final controller = _FlowController();
    await _pump(
      tester,
      GlobalShopCartPage(controller: controller),
      size: const Size(375, 812),
      scale: 2,
    );
    expect(find.text('2 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(controller.cartUpdates.single, containsPair('quantity', 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unknown checkout result survives page restart and retries the same key',
    (tester) async {
      final controller = _FlowController()
        ..placeError = const ApiException('timeout');
      Widget page() => GlobalShopCheckoutPage(
        controller: controller,
        items: _checkoutItems,
        capabilities: GlobalCommerceCapabilities.fromJson(_capabilities()),
      );
      await _pump(tester, page());
      await tester.tap(find.byKey(const Key('global-place-order')));
      await tester.pumpAndSettle();
      expect(controller.placed, hasLength(1));
      final originalKey = controller.placed.single['idempotencyKey'];
      expect(controller.drafts, hasLength(1));
      expect(find.text('Try again'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _pump(tester, page());
      expect(find.text('Try again'), findsOneWidget);
      controller.placeError = null;
      await tester.tap(find.byKey(const Key('global-place-order')));
      await tester.pumpAndSettle();
      expect(controller.placed, hasLength(2));
      expect(controller.placed.last['idempotencyKey'], originalKey);
      expect(controller.drafts, isEmpty);
    },
  );

  testWidgets(
    'multi-item after-sales request persists and retries without duplication',
    (tester) async {
      final controller = _FlowController()
        ..afterSaleError = const ApiException('timeout');
      final capabilities = GlobalCommerceCapabilities.fromJson(_capabilities());
      Widget page() => GlobalShopAfterSalePage(
        controller: controller,
        orderId: _orderId,
        capabilities: capabilities,
        eligibleItems: const [
          {'orderItemId': _itemA, 'quantityRemaining': 2},
          {'orderItemId': _itemB, 'quantityRemaining': 3},
        ],
        orderItems: const [
          {
            'id': _itemA,
            'nameSnapshot': 'Watch A',
            'specificationSnapshot': 'Black',
          },
          {
            'id': _itemB,
            'nameSnapshot': 'Watch B',
            'specificationSnapshot': 'Silver',
          },
        ],
      );
      await _pump(tester, page());
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.enterText(find.byType(TextField).first, 'Screen issue');
      await tester.tap(find.text('Review request amount'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();
      expect(controller.afterSales, hasLength(1));
      final request = controller.afterSales.single;
      expect(request['items'], hasLength(2));
      expect(request['evidenceFileIds'], isEmpty);
      final originalKey = request['idempotencyKey'];
      expect(controller.drafts, hasLength(1));

      await tester.pumpWidget(const SizedBox());
      await _pump(tester, page());
      expect(find.text('Try again'), findsOneWidget);
      controller.afterSaleError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(controller.afterSales, hasLength(2));
      expect(controller.afterSales.last['idempotencyKey'], originalKey);
      expect(controller.drafts, isEmpty);
    },
  );

  testWidgets('coupon and point ledgers paginate and format server currency', (
    tester,
  ) async {
    final controller = _FlowController();
    await _pump(tester, GlobalShopCouponsPage(controller: controller));
    expect(find.text('Coupon page 1'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Coupon page 2'), findsOneWidget);
    expect(controller.couponPages, [1, 2]);

    await _pump(tester, GlobalShopPointsPage(controller: controller));
    expect(find.textContaining('25.00'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(controller.pointPages, [1, 2]);
    expect(find.textContaining('3.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'order detail shows after-sales items, notes and refund progress',
    (tester) async {
      final controller = _FlowController();
      await _pump(
        tester,
        GlobalShopOrderDetailPage(
          controller: controller,
          orderId: _orderId,
          openProduct: (_, _) {},
          capabilities: GlobalCommerceCapabilities.fromJson(_capabilities()),
        ),
        scale: 2,
      );
      await tester.scrollUntilVisible(
        find.text('Items in this request'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Saydian watch'), findsWidgets);
      expect(
        find.text('Request details: The display no longer turns on.'),
        findsOneWidget,
      );
      expect(find.text('Refund progress'), findsOneWidget);
      expect(find.textContaining('12.34'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'address editor never guesses a country when market data is absent',
    (tester) async {
      final controller = _FlowController();
      await _pump(
        tester,
        GlobalShopAddressEditPage(
          controller: controller,
          capabilities: GlobalCommerceCapabilities.unavailable,
        ),
      );
      expect(find.text('CN'), findsNothing);
      expect(
        find.text(
          'Ordering is not available for the selected delivery market yet.',
        ),
        findsOneWidget,
      );
      final save = tester.widget<FilledButton>(
        find.byKey(const Key('global-address-save')),
      );
      expect(save.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'existing addresses stay readable when market capabilities fail',
    (tester) async {
      final controller = _FlowController()..capabilityFailure = true;
      await _pump(tester, GlobalShopAddressesPage(controller: controller));

      expect(find.textContaining('Alex'), findsOneWidget);
      expect(find.textContaining('1 Market Street'), findsOneWidget);
      expect(
        find.text(
          'Ordering is not available for the selected delivery market yet.',
        ),
        findsOneWidget,
      );
      final addButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(addButton.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
