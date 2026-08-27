import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

void main() {
  test('care member list uses the mini-program member endpoint', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/member/care/my');
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getCareMembers(), isEmpty);
  });

  test('care member list keeps only safe identity fields', () async {
    final client = MockClient(
      (_) async => http.Response(
        '''{"code":200,"data":[{"id":7,"member_id":1,"to_member_id":2,
        "member":{"id":2,"nickname":"妈妈","mobile":"13800138000",
        "head_portrait":"/a.png","password_hash":"secret"}}]}''',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final member = (await api.getCareMembers()).single;
    expect(member['nickname'], '妈妈');
    expect(member['mobile'], '13800138000');
    expect(member['head_portrait'], 'https://example.invalid/a.png');
    expect(member.toString(), isNot(contains('password_hash')));
  });

  test(
    'care member identity accepts the legacy to_member relation alias',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          '''{"code":200,"data":[{"id":8,"to_member":{"id":3,
        "nickname":"爸爸","mobile":"13900139000","head_portrait":"avatar/b.png"}}]}''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      final member = (await api.getCareMembers()).single;
      expect(member['nickname'], '爸爸');
      expect(member['mobile'], '13900139000');
      expect(member['head_portrait'], 'https://example.invalid/avatar/b.png');
    },
  );

  test('add care uses the mini-program authenticated JSON contract', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/member/care');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      expect(request.headers['token'], 'test-access-token');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body), {'mobile': '13800138000'});
      return http.Response(
        '{"code":200,"message":"成功","data":{"id":9,"member_id":1,"to_member_id":2}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final result = await api.addCare('13800138000');

    expect(result['id'], 9);
    expect(result['to_member_id'], 2);
  });

  test('avatar upload follows the mini-program multipart contract', () async {
    final directory = await Directory.systemTemp.createTemp(
      'saydian-avatar-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}${Platform.pathSeparator}avatar.png');
    await image.writeAsBytes(const [0x89, 0x50, 0x4E, 0x47]);

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/file/images');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      expect(request.headers['token'], 'test-access-token');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      final multipartBody = latin1.decode(request.bodyBytes);
      expect(multipartBody, contains('name="file"'));
      expect(multipartBody, contains('filename="avatar.png"'));
      return http.Response(
        '{"code":200,"data":{"url":"/uploads/avatar.png"}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      await api.uploadImage(image.path),
      'https://example.invalid/uploads/avatar.png',
    );
  });

  test('add care rejects malformed mobile before making a request', () async {
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: MockClient((_) async => fail('request should not be sent')),
    );

    expect(() => api.addCare('abc'), throwsA(isA<ApiException>()));
  });

  test('AI chat and profile save mirror the mini-program JSON posts', () async {
    var requestIndex = 0;
    final client = MockClient((request) async {
      requestIndex++;
      expect(request.method, 'POST');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      expect(request.headers['token'], 'test-access-token');
      expect(request.headers['content-type'], contains('application/json'));
      final body = jsonDecode(request.body);
      if (requestIndex == 1) {
        expect(request.url.path, '/api/rf-article/chat/create');
        expect(body, {'app': 1, 'message': '你好', 'session_id': 'session-1'});
        return http.Response(
          '{"code":200,"data":{"message":"您好","session_id":"session-1"}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      expect(request.url.path, '/api/v1/member/member/save');
      expect(body, {
        'nickname': '测试用户',
        'gender': 1,
        'birthday': '1960-01-02',
        'height': '168.5',
        'weight': '62',
        'head_portrait': 'https://app.saidian.cc/avatar.png',
      });
      return http.Response('{"code":200,"data":{}}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      await api.sendAiMessage(app: 1, message: '你好', sessionId: 'session-1'),
      containsPair('message', '您好'),
    );
    await api.saveMemberProfile(
      nickname: '测试用户',
      gender: 1,
      birthday: '1960-01-02',
      height: 168.5,
      weight: 62,
      headPortrait: 'https://app.saidian.cc/avatar.png',
    );
    expect(requestIndex, 2);
  });

  test('profile avatar upload follows the mini-program file contract', () async {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}saidian-avatar-test.jpg',
    );
    await file.writeAsBytes(const [0xFF, 0xD8, 0xFF, 0xD9]);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/file/images');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      expect(request.headers['token'], 'test-access-token');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(latin1.decode(request.bodyBytes), contains('name="file"'));
      return http.Response(
        '{"code":200,"data":{"url":"/attachment/avatar/test.jpg"}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      await api.uploadProfileImage(file.path),
      'https://example.invalid/attachment/avatar/test.jpg',
    );
  });

  test('business error code is preserved when HTTP status is 200', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"code":401,"message":"Unauthorized","data":{}}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await expectLater(
      api.getCareMembers(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.code, 'code', 401),
      ),
    );
  });

  test(
    'missing health batch endpoint falls back to the mini-program daily route',
    () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        requestCount++;
        if (requestCount == 1) {
          expect(request.url.path, '/api/v1/member/health-records/batch');
          return http.Response(
            '{"code":404,"message":"页面未找到。","data":{}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.url.path, '/api/v1/member/daily-date');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final daily =
            (body['dailyDate'] as List).single as Map<String, dynamic>;
        expect(daily['pulseReat'], 72);
        return http.Response('{"code":200,"data":{}}', 200);
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );
      final record = HealthRecord(
        id: 'record-1',
        metric: HealthMetric.heartRate,
        values: const {'value': 72},
        unit: 'bpm',
        measuredAt: DateTime.utc(2026, 8, 13),
        timezone: '+08:00',
        deviceId: 'ET488',
        firmwareVersion: '1.0.0',
        quality: 'good',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      );

      final result = await api.uploadHealthBatch(
        SyncBatch(cursor: null, records: [record]),
      );
      expect(result.acceptedIds, {'record-1'});
      expect(result.rejected, isEmpty);
    },
  );

  test('health encyclopedia uses the mini-program public endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/rf-article/article/index');
      expect(request.url.queryParameters, isEmpty);
      return http.Response(
        '{"code":200,"data":[{"id":3,"title":"健康百科","cover":"http://sd.cc"}]}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final articles = await api.getArticles();

    expect(articles.single['id'], 3);
    expect(articles.single['cover'], 'https://app.saidian.cc');
  });

  test('article categories use parent id 3 by default', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/rf-article/article-cate/index');
      expect(request.url.queryParameters, {'pid': '3'});
      return http.Response(
        '{"code":200,"data":[{"id":8,"title":"慢病管理"}]}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final categories = await api.getArticleCategories();

    expect(categories.single['id'], 8);
  });

  test('category article list sends category and page parameters', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/rf-article/article/index');
      expect(request.url.queryParameters, {'cate_id': '8', 'page': '2'});
      return http.Response(
        '{"code":200,"data":{"list":[{"id":11,"cover":"http://sd.cc/uploads/cover.png"}]}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final articles = await api.getArticlesByCategory(categoryId: 8, page: 2);

    expect(articles.single['id'], 11);
    expect(
      articles.single['cover'],
      'https://app.saidian.cc/uploads/cover.png',
    );
  });

  test('unfiltered paged article list omits category parameter', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/rf-article/article/index');
      expect(request.url.queryParameters, {'page': '1'});
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getArticlesByCategory(), isEmpty);
  });

  test('network failures are normalized to an offline ApiException', () async {
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: MockClient(
        (request) async =>
            throw http.ClientException('Failed host lookup', request.url),
      ),
      baseUri: Uri.parse('https://example.invalid'),
    );

    await expectLater(
      api.getArticles(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'NETWORK_UNAVAILABLE')
            .having((error) => error.message, 'message', '网络连接失败，请检查网络后重试'),
      ),
    );
  });

  test('privacy agreement uses the single-article endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/rf-article/article-single/view');
      expect(request.url.queryParameters['id'], '3');
      return http.Response(
        '{"code":200,"data":{"id":3,"title":"隐私协议"}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect((await api.getSingleArticle(3))['title'], '隐私协议');
  });

  test('orders send the authenticated synthesize status contract', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/inv-shop/v1/member/order/index');
      expect(request.url.queryParameters['page'], '1');
      expect(request.url.queryParameters['synthesize_status'], '2');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getOrders(status: 2), isEmpty);
  });

  test('all orders omit the synthesize status filter', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
    final client = MockClient((request) async {
      expect(request.url.path, '/api/inv-shop/v1/member/order/index');
      expect(
        request.url.queryParameters.containsKey('synthesize_status'),
        isFalse,
      );
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getOrders(), isEmpty);
  });

  test('shop home uses the public SHOP_HOME page contract', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/pages');
      expect(request.url.queryParameters['code'], 'SHOP_HOME');
      expect(request.headers.containsKey('authorization'), isFalse);
      return http.Response(
        '{"code":200,"data":{"items":[{"type":"tabs"}]}}',
        200,
      );
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect((await api.getShopHome())['items'], isA<List>());
  });

  test('order preview sends the mini-program buy-now query contract', () async {
    final vault = _authenticatedVault();
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/inv-shop/v1/order/order/preview');
      expect(request.url.queryParameters['type'], 'buy_now');
      expect(request.url.queryParameters['is_channel'], '0');
      expect(jsonDecode(request.url.queryParameters['data']!), {
        'sku_id': 2975,
        'num': 2,
      });
      expect(request.headers['authorization'], 'Bearer test-access-token');
      return http.Response('{"code":200,"data":{"products":[]}}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      await api.previewShopOrder(
        items: const [
          {'sku_id': 2975, 'num': 2},
        ],
      ),
      contains('products'),
    );
  });

  test(
    'shop checkout composes a multi-product preview from server prices',
    () async {
      var requestCount = 0;
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: MockClient((request) async {
          requestCount++;
          final item = jsonDecode(request.url.queryParameters['data']!);
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {
                'address': {'id': 8},
                'account': {'money1': 0},
                'products': [
                  {'sku_id': item['sku_id'], 'product_name': '商品$requestCount'},
                ],
                'preview': {
                  'product_money': requestCount * 10,
                  'shipping_money': 2,
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        baseUri: Uri.parse('https://example.invalid'),
      );

      final preview = await api.previewShopOrder(
        items: const [
          {'sku_id': 2975, 'num': 1},
          {'sku_id': 2976, 'num': 1},
        ],
      );
      expect(requestCount, 2);
      expect(preview['multiple_orders'], isTrue);
      expect((preview['products'] as List), hasLength(2));
      expect((preview['preview'] as Map)['product_money'], 30);
      expect((preview['preview'] as Map)['shipping_money'], 4);
    },
  );

  test('create order sends the confirmed JSON checkout contract', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/inv-shop/v1/order/order/create');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['address_id'], 8);
      expect(body['shipping_type'], 1);
      expect(body['type'], 'buy_now');
      expect(body['buyer_message'], '请尽快发货');
      expect(jsonDecode(body['data'] as String), {'sku_id': 2975, 'num': 2});
      return http.Response('{"code":200,"data":{"id":99}}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final order = await api.createShopOrder(
      items: const [
        {'sku_id': 2975, 'num': 2},
      ],
      addressId: 8,
      buyerMessage: '请尽快发货',
    );
    expect(order['id'], 99);
  });

  test(
    'multi-select checkout creates one backend order per selected SKU',
    () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final data = jsonDecode(body['data'] as String) as Map<String, dynamic>;
        expect(body['point'], requestCount == 1 ? 5 : 0);
        return http.Response(
          jsonEncode({
            'code': 200,
            'data': {'id': 100 + requestCount, 'sku_id': data['sku_id']},
          }),
          200,
        );
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      final result = await api.createShopOrder(
        items: const [
          {'sku_id': 2975, 'num': 1},
          {'sku_id': 2976, 'num': 2},
        ],
        addressId: 8,
        buyerMessage: '',
        point: 5,
      );
      expect(requestCount, 2);
      expect(result['order_ids'], [101, 102]);
      expect(result['created_sku_ids'], [2975, 2976]);
    },
  );

  test(
    'confirm receipt and after-sales use authenticated shop routes',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('{"code":200,"data":{}}', 200);
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      await api.confirmOrderReceipt(424);
      await api.applyOrderRefund(
        orderProductId: 800,
        refundType: 2,
        amount: 99,
        reason: '商品无法正常使用',
      );

      expect(
        requests[0].url.path,
        '/api/inv-shop/v1/member/order/take-delivery',
      );
      expect(requests[0].body, contains('424'));
      expect(
        requests[1].url.path,
        '/api/inv-shop/v1/member/order-product/refund-apply',
      );
      expect(requests[1].body, contains('商品无法正常使用'));
    },
  );

  test('address create uses authenticated JSON region fields', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/member/address');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['realname'], '张三');
      expect(body['province_id'], 440000);
      expect(body['city_id'], 440300);
      expect(body['area_id'], 440305);
      expect(body['is_default'], 1);
      return http.Response('{"code":200,"data":{"id":8}}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      (await api.saveAddress(
        realname: '张三',
        mobile: '13800138000',
        addressDetails: '科技园 1 号',
        isDefault: true,
        region: '广东省 深圳市 南山区',
        provinceId: 440000,
        cityId: 440300,
        areaId: 440305,
      ))['id'],
      8,
    );
  });

  test('activity goals use the confirmed multipart field names', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/member/member-mubiao');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      expect(request.body, contains('name="steps"'));
      expect(request.body, contains('10000'));
      expect(request.body, contains('name="juli"'));
      expect(request.body, contains('6.5'));
      expect(request.body, contains('name="reliang"'));
      expect(request.body, contains('800'));
      return http.Response('{"code":200,"data":{}}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.saveActivityGoals(steps: 10000, distance: 6.5, calories: 800);
  });

  test('care invitation response uses the prototype status contract', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/member/care/save');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body), {'id': 19, 'examine_status': 2});
      return http.Response('{"code":200,"data":{}}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.respondCareInvitation(id: 19, accepted: false);
  });

  test('care invitations never expose the recipient as the inviter', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/member/care');
      return http.Response(
        '{"code":200,"data":{"list":[{"id":59,"member_id":82,"to_member_id":1,"examine_status":0,"member":{"id":1,"nickname":"当前账号","mobile":"13600136000","password_hash":"secret"}},{"id":60,"member_id":1,"to_member_id":90,"examine_status":1,"member":{"id":90,"nickname":"我邀请的人"}}]}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final invitations = await api.getCareInvitations();
    expect(invitations, hasLength(1));
    final invitation = invitations.single;
    expect(invitation['inviter_id'], 82);
    expect(invitation['member'], isEmpty);
    expect(invitation.containsKey('password_hash'), isFalse);
  });

  test('care share settings decode the server JSON list', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/member/care-setting/preview');
      expect(request.url.queryParameters, {'type': '2', 'to_member_id': '7'});
      return http.Response(
        '{"code":200,"data":{"setting":"[\\"heart_rate\\",\\"sleep\\"]"}}',
        200,
      );
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getCareShareSettings(type: 2, memberId: 7), {
      'heart_rate',
      'sleep',
    });
  });

  test('care share settings save a stable sorted JSON list', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/member/care-setting');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body), {
        'type': 2,
        'to_member_id': 7,
        'setting': ['heart_rate', 'sleep'],
      });
      return http.Response('{"code":200,"data":{}}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.saveCareShareSettings(
      type: 2,
      memberId: 7,
      settings: {'sleep', 'heart_rate'},
    );
  });

  test('SMS authentication uses the confirmed RageFrame contracts', () async {
    var requestIndex = 0;
    final client = MockClient((request) async {
      requestIndex++;
      expect(request.method, 'POST');
      if (requestIndex == 1) {
        expect(request.url.path, '/api/v1/site/sms-code');
        expect(request.body, contains('name="mobile"'));
        expect(request.body, contains('13800138000'));
        expect(request.body, contains('name="usage"'));
        expect(request.body, contains('register'));
        return http.Response('{"code":200,"data":{}}', 200);
      }
      if (requestIndex == 2) {
        expect(request.url.path, '/api/v1/site/register');
        for (final field in const [
          'mobile',
          'code',
          'password',
          'password_repetition',
          'nickname',
          'group',
        ]) {
          expect(request.body, contains('name="$field"'));
        }
      } else {
        expect(request.url.path, '/api/v1/site/up-pwd');
        expect(request.body, contains('name="code"'));
        expect(request.body, contains('up-password'));
      }
      return http.Response(
        '{"code":200,"data":{"access_token":"access","refresh_token":"refresh","expiration_time":43200,"member":{"id":7,"nickname":"测试用户"}}}',
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final vault = MemorySessionVault();
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.sendSmsCode(mobile: '13800138000', usage: 'register');
    await api.registerWithSms(
      mobile: '13800138000',
      code: '1234',
      password: 'register-password',
      nickname: '测试用户',
    );
    await api.resetPassword(
      mobile: '13800138000',
      code: '5678',
      password: 'up-password',
    );

    expect(requestIndex, 3);
    expect(vault.session?.accessToken, 'access');
  });

  test('expired access token is refreshed without losing login state', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'expired-access',
        refreshToken: 'long-lived-refresh',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        memberId: '7',
        displayName: '长期登录用户',
      );
    var requestIndex = 0;
    final client = MockClient((request) async {
      requestIndex++;
      if (requestIndex == 1) {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/site/refresh');
        expect(request.body, contains('long-lived-refresh'));
        expect(request.body, contains('name="group"'));
        return http.Response(
          '{"code":200,"data":{"access_token":"fresh-access","refresh_token":"fresh-refresh","expiration_time":43200,"member":{"id":7,"nickname":"长期登录用户"}}}',
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      expect(request.url.path, '/api/v1/member/care/my');
      expect(request.headers['authorization'], 'Bearer fresh-access');
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.getCareMembers();

    expect(requestIndex, 2);
    expect(vault.session?.accessToken, 'fresh-access');
    expect(vault.session?.refreshToken, 'fresh-refresh');
  });

  test('server-revoked access token refreshes once and retries request', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'revoked-access',
        refreshToken: 'long-lived-refresh',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
        memberId: '7',
        displayName: '长期登录用户',
      );
    var requestIndex = 0;
    final client = MockClient((request) async {
      requestIndex++;
      if (requestIndex == 1) {
        expect(request.url.path, '/api/v1/member/care/my');
        expect(request.headers['authorization'], 'Bearer revoked-access');
        return http.Response(
          '{"code":401,"message":"Your request was made with invalid credentials.","data":{}}',
          200,
        );
      }
      if (requestIndex == 2) {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/site/refresh');
        expect(request.body, contains('long-lived-refresh'));
        return http.Response(
          '{"code":200,"data":{"access_token":"fresh-access","refresh_token":"fresh-refresh","expiration_time":43200,"member":{"id":7,"nickname":"长期登录用户"}}}',
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      expect(request.url.path, '/api/v1/member/care/my');
      expect(request.headers['authorization'], 'Bearer fresh-access');
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getCareMembers(), isEmpty);

    expect(requestIndex, 3);
    expect(vault.session?.accessToken, 'fresh-access');
    expect(vault.session?.refreshToken, 'fresh-refresh');
  });
}

MemorySessionVault _authenticatedVault() =>
    MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
