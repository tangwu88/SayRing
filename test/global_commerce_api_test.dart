import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/global_environment.dart';
import 'package:saydian_app/services/secure_vault.dart';

http.Response _ok(Object? value) => http.Response(
  jsonEncode({'code': 200, 'data': value}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'catalog uses the isolated V2 route, real filters and opaque IDs',
    () async {
      const id = '42b1a6a5-278d-4a51-8e5d-16a0fd97e934';
      final calls = <Uri>[];
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        locale: () => 'de',
        client: MockClient((request) async {
          calls.add(request.url);
          expect(request.url.host, 'app.saydian.cn');
          expect(
            request.url.path,
            startsWith('${GlobalEnvironment.apiPrefix}/commerce/'),
          );
          expect(request.method, 'GET');
          expect(request.headers['Accept-Language'], 'de');
          if (request.url.path.endsWith('/products/$id')) {
            return _ok({
              'id': id,
              'name': 'Test',
              'skus': [
                {'id': 'opaque-sku', 'salePriceCents': 12345},
              ],
            });
          }
          if (request.url.path.endsWith('/home')) {
            return _ok({'categories': [], 'featured': []});
          }
          expect(request.url.queryParameters, {
            'page': '2',
            'pageSize': '30',
            'locale': 'de',
            'keyword': 'Watch',
            'categoryId': 'opaque-category',
          });
          return _ok({
            'items': [
              {'id': id, 'priceCents': 12345},
            ],
            'page': 2,
            'total': 31,
          });
        }),
      );
      await api.getShopHome();
      final list = await api.getGlobalShopProducts(
        keyword: ' Watch ',
        categoryId: 'opaque-category',
        page: 2,
      );
      expect((list['items'] as List).single, {'id': id, 'priceCents': 12345});
      final detail = await api.getGlobalShopProduct(id);
      expect(detail['id'], id);
      expect(detail.containsKey('currency'), isFalse);
      expect(detail.containsKey('price'), isFalse);
      expect(calls, hasLength(3));
    },
  );

  test(
    'server amount and currency metadata are never replaced or converted',
    () async {
      final original = {
        'id': 'item',
        'priceCents': 1005,
        'currency': 'KWD',
        'currencyExponent': 3,
      };
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((_) async => _ok(original)),
      );
      expect(await api.getGlobalShopProduct('item'), original);
    },
  );

  test(
    'authenticated commerce uses only App V2 routes and opaque IDs',
    () async {
      const productId = '42b1a6a5-278d-4a51-8e5d-16a0fd97e934';
      const skuId = 'a7e22cb2-8a4a-4113-88d9-c90066bcd459';
      const cartItemId = '304e7960-2ad3-40fd-8be2-a21bfe216bdb';
      const addressId = '25f24331-8d11-4e96-b843-7ce6f71f8f8b';
      const orderId = 'a39f05c7-bd59-43bb-bc2d-228e0fc1d56a';
      const orderItemId = 'c2e4a14d-1d03-42db-beaf-69750f00a2c7';
      const saleId = '54684d3e-fe4d-4a37-b081-0d1b99dd45a9';
      const couponId = '2fbd2bfa-1c2d-405b-bba8-bff4f449440d';
      final expectedQuote = 'q1:${List.filled(64, 'a').join()}';
      final vault = MemorySessionVault()
        ..session = Session(
          accessToken: 'global-access-token',
          refreshToken: 'global-refresh-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          memberId: 'global-member',
          displayName: 'Global member',
          accountKey: 'email:test@example.com',
        );
      final calls = <String>[];
      final bodies = <String, Map<String, Object?>>{};
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          expect(request.url.host, 'app.saydian.cn');
          expect(request.url.path, startsWith(GlobalEnvironment.apiPrefix));
          expect(
            request.headers['Authorization'],
            'Bearer global-access-token',
          );
          expect(request.headers.containsKey('token'), isFalse);
          expect(request.headers['Accept-Language'], 'en');
          final route = request.url.path.substring(
            GlobalEnvironment.apiPrefix.length,
          );
          final key = '${request.method} $route';
          calls.add(key);
          if (request.body.isNotEmpty) {
            bodies[key] = (jsonDecode(request.body) as Map).map(
              (key, value) => MapEntry('$key', value),
            );
          }
          if (request.method == 'GET' &&
              {
                '/commerce/addresses',
                '/commerce/orders',
                '/commerce/orders/$orderId/logistics',
                '/commerce/favorites',
                '/commerce/coupons',
              }.contains(route)) {
            return _ok(<Object?>[]);
          }
          return _ok({'id': 'saved'});
        }),
      );

      await api.getGlobalShopCart();
      await api.putGlobalShopCartItem(
        skuId: skuId,
        quantity: 2,
        selected: false,
        mode: 'increment',
      );
      await api.deleteGlobalShopCartItem(cartItemId);
      await api.getGlobalShopAddresses();
      await api.getGlobalShopAddress(addressId);
      await api.saveGlobalShopAddress({
        'countryCode': 'CN',
        'name': 'Test',
        'mobile': '+8613800138000',
        'detail': 'Address',
      });
      await api.saveGlobalShopAddress({
        'countryCode': 'CN',
        'name': 'Updated',
        'mobile': '+8613800138000',
        'detail': 'Address',
      }, id: addressId);
      await api.deleteGlobalShopAddress(addressId);
      await api.previewGlobalShopOrder(
        addressId: addressId,
        items: const [
          {'skuId': skuId, 'quantity': 2},
        ],
        couponClaimId: couponId,
        pointCents: 100,
        buyerRemark: 'Leave at reception',
      );
      await api.createGlobalShopOrder(
        addressId: addressId,
        items: const [
          {'skuId': skuId, 'quantity': 2},
        ],
        expectedQuote: expectedQuote,
        idempotencyKey: 'checkout-safe-key',
      );
      await api.getGlobalShopOrders(group: 'after_sales');
      await api.getGlobalShopOrder(orderId);
      await api.cancelGlobalShopOrder(orderId);
      await api.confirmGlobalShopOrderReceipt(orderId);
      await api.getGlobalShopOrderLogistics(orderId);
      await api.previewGlobalShopAfterSale(
        orderId: orderId,
        input: const {'type': 'REFUND_ONLY'},
      );
      await api.createGlobalShopAfterSale(
        orderId: orderId,
        input: const {'type': 'REFUND_ONLY', 'reason': 'Test'},
      );
      await api.submitGlobalShopReturnLogistics(
        orderId: orderId,
        saleId: saleId,
        input: const {
          'logisticsCompany': 'Carrier',
          'trackingNo': 'TRACKING-1',
          'version': 0,
        },
      );
      await api.getGlobalShopFavorites();
      await api.setGlobalShopFavorite(productId, true);
      await api.getGlobalShopCoupons();
      await api.getGlobalShopAvailableCoupons(page: 2);
      await api.claimGlobalShopCoupon(couponId);
      await api.claimGlobalShopCouponCode('SAVE_20');
      await api.getGlobalShopPoints(page: 2);
      await api.createGlobalShopReview(
        orderItemId: orderItemId,
        rating: 5,
        content: 'Works well',
      );

      expect(calls, contains('PATCH /commerce/addresses/$addressId'));
      expect(
        calls,
        contains('POST /commerce/orders/$orderId/after-sales/preview'),
      );
      expect(
        calls,
        contains(
          'POST /commerce/orders/$orderId/after-sales/$saleId/return-logistics',
        ),
      );
      expect(calls, contains('GET /commerce/coupons/available'));
      expect(calls, contains('POST /commerce/coupons/code/claim'));
      expect(calls, contains('GET /commerce/points'));
      expect(calls.every((call) => !call.contains('/storefront/')), isTrue);
      expect(bodies['POST /commerce/cart/items'], containsPair('skuId', skuId));
      expect(
        bodies['POST /commerce/orders'],
        containsPair('expectedQuote', expectedQuote),
      );
      expect(
        bodies['POST /commerce/coupons/code/claim'],
        containsPair('code', 'SAVE_20'),
      );
    },
  );

  test(
    'commerce validation blocks malformed writes before transport',
    () async {
      var calls = 0;
      final vault = MemorySessionVault()
        ..session = Session(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          memberId: 'member',
          displayName: 'Member',
        );
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((_) async {
          calls++;
          return _ok({});
        }),
      );
      final validQuote = 'q1:${List.filled(64, 'a').join()}';
      final invalid = <Future<Object?> Function()>[
        () => api.putGlobalShopCartItem(skuId: '', quantity: 1),
        () => api.putGlobalShopCartItem(skuId: 'sku', quantity: 0),
        () => api.createGlobalShopOrder(
          addressId: 'address',
          items: const [],
          expectedQuote: 'not-a-quote',
          idempotencyKey: 'valid-key',
        ),
        () => api.createGlobalShopOrder(
          addressId: 'address',
          items: const [],
          expectedQuote: validQuote,
          idempotencyKey: 'short',
        ),
        () => api.claimGlobalShopCouponCode('bad code'),
        () => api.getGlobalShopAvailableCoupons(page: 0),
        () => api.getGlobalShopPoints(page: 0),
        () => api.loadGlobalShopEvidence('not-an-evidence-id'),
        () => api.uploadGlobalShopEvidence('not-an-image.txt'),
        () => api.createGlobalShopReview(
          orderItemId: 'item',
          rating: 0,
          content: '',
        ),
      ];
      for (final invoke in invalid) {
        await expectLater(invoke, throwsA(isA<ApiException>()));
      }
      expect(calls, 0);
    },
  );

  test(
    'after-sales evidence stays private on App V2 with validated upload receipt',
    () async {
      const evidenceId = '22222222-2222-4222-8222-222222222222';
      final bytes = <int>[137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0];
      final directory = await Directory.systemTemp.createTemp(
        'saydian-commerce-evidence-',
      );
      final file = File('${directory.path}${Platform.pathSeparator}photo.png');
      await file.writeAsBytes(bytes, flush: true);
      final vault = MemorySessionVault()
        ..session = Session(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          memberId: 'member',
          displayName: 'Member',
          accountKey: 'member:test',
        );
      final calls = <http.Request>[];
      final progress = <double>[];
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          calls.add(request);
          expect(
            request.url.path,
            startsWith('${GlobalEnvironment.apiPrefix}/commerce/'),
          );
          expect(request.headers['Authorization'], 'Bearer token');
          expect(request.headers.containsKey('token'), isFalse);
          if (request.url.path.endsWith('/capabilities')) {
            return _ok({
              'enabled': true,
              'maxFiles': 9,
              'maxBytes': 10 * 1024 * 1024,
              'contentTypes': ['image/jpeg', 'image/png', 'image/webp'],
            });
          }
          if (request.method == 'POST') {
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data;'),
            );
            expect(latin1.decode(request.bodyBytes), contains('name="file"'));
            return _ok({
              'id': evidenceId,
              'byteSize': bytes.length,
              'contentType': 'image/png',
              'sha256': List.filled(64, 'a').join(),
            });
          }
          expect(request.url.path, endsWith('/after-sale-images/$evidenceId'));
          return http.Response.bytes(
            bytes,
            200,
            headers: {
              'content-type': 'image/png',
              'cache-control': 'private, no-store',
            },
          );
        }),
      );
      try {
        expect(
          (await api.getGlobalShopEvidenceCapabilities())['enabled'],
          isTrue,
        );
        expect(
          await api.uploadGlobalShopEvidence(
            file.path,
            onProgress: progress.add,
          ),
          containsPair('id', evidenceId),
        );
        expect(await api.loadGlobalShopEvidence(evidenceId), bytes);
        expect(progress, isNotEmpty);
        expect(progress.last, 1);
        expect(
          calls.every(
            (call) =>
                !call.url.path.contains('/storefront/') &&
                !call.url.path.contains('/saidian-mall/'),
          ),
          isTrue,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'invalid catalog response and invalid input are not empty success',
    () async {
      var calls = 0;
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((_) async {
          calls++;
          return _ok({'items': 'invalid'});
        }),
      );
      await expectLater(
        api.getGlobalShopProducts(),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.getGlobalShopProducts(page: 0),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.getGlobalShopProduct(' '),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
    },
  );

  test(
    'legacy commerce contracts never send requests or invent success',
    () async {
      var calls = 0;
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((_) async {
          calls++;
          return _ok({});
        }),
      );
      final invocations = <Future<Object?> Function()>[
        () => api.getShopProduct(12),
        () => api.getOrders(),
        () => api.getOrderDetail(12),
        () => api.getAddresses(),
        () => api.getAddress(12),
        () => api.getOrderExpress(12),
        () => api.getShopCartItems(),
        () => api.addShopCartItem(skuId: 12, quantity: 1),
        () => api.updateShopCartItemQuantity(skuId: 12, quantity: 2),
        () => api.deleteShopCartItems([12]),
        () => api.previewShopOrder(
          items: [
            {'sku_id': 12, 'num': 1},
          ],
        ),
        () => api.createShopOrder(
          items: [
            {'sku_id': 12, 'num': 1},
          ],
          addressId: 12,
        ),
        () => api.createShopPayment(provider: 'wechat', orderId: 12, money: 1),
        () => api.confirmOrderReceipt(12),
        () => api.applyOrderRefund(
          orderProductId: 12,
          refundType: 1,
          amount: 1,
          reason: 'test',
        ),
        () => api.saveAddress(
          realname: 'Test',
          mobile: '+12025550123',
          addressDetails: 'Test',
          isDefault: false,
          region: '',
          provinceId: 1,
          cityId: 1,
          areaId: 1,
        ),
      ];
      for (final invoke in invocations) {
        await expectLater(
          invoke(),
          throwsA(isA<FeatureNotConfiguredException>()),
        );
      }
      expect(calls, 0);
    },
  );
}
