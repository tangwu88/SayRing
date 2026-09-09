import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
