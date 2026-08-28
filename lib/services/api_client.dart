import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/models.dart';
import 'secure_vault.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final Object? code;

  @override
  String toString() => message;
}

class FeatureNotConfiguredException extends ApiException {
  const FeatureNotConfiguredException(super.message, {super.statusCode});
}

class BatchUploadResult {
  const BatchUploadResult({
    required this.acceptedIds,
    required this.rejected,
    required this.nextCursor,
  });

  final Set<String> acceptedIds;
  final Map<String, String> rejected;
  final String? nextCursor;
}

abstract interface class SaydianApi {
  Future<Session> login(String username, String password);
  Future<Session> register(String mobile, String password);
  Future<List<Map<String, Object?>>> getCareMembers();
  Future<Map<String, Object?>> getCareMemberPreview({
    required int id,
    required String day,
    int? memberId,
  });
  Future<Map<String, Object?>> addCare(String mobile);
  Future<Map<String, Object?>> getMemberProfile();
  Future<void> saveMemberProfile({
    required String nickname,
    required int gender,
    required String birthday,
    required double height,
    required double weight,
    String? headPortrait,
  });
  Future<Map<String, Object?>> getActivityGoals();
  Future<void> saveActivityGoals({
    required int steps,
    required double distance,
    required int calories,
  });
  Future<List<Map<String, Object?>>> getArticles();
  Future<Map<String, Object?>> getArticle(int id);
  Future<Map<String, Object?>> getSingleArticle(int id);
  Future<List<Map<String, Object?>>> getNotifications({int page = 1});
  Future<Map<String, Object?>> getNotification(int id);
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  });
  Future<Map<String, Object?>> sendAiMessage({
    required int app,
    required String message,
    String? sessionId,
  });
  Future<List<Map<String, Object?>>> getOrders({int? status});
  Future<Map<String, Object?>> getOrderDetail(int id);
  Future<List<Map<String, Object?>>> getAddresses();
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch);
  Future<void> logout();
  Future<void> deleteAccount();
}

abstract interface class SaydianFileApi {
  Future<String> uploadImage(String filePath);
}

abstract interface class SaydianSmsAuthApi {
  Future<void> sendSmsCode({required String mobile, required String usage});
  Future<Session> registerWithSms({
    required String mobile,
    required String code,
    required String password,
    required String nickname,
  });
  Future<Session> resetPassword({
    required String mobile,
    required String code,
    required String password,
  });
  Future<Session> refreshSession(Session session);
}

abstract interface class SaydianArticleApi {
  Future<List<Map<String, Object?>>> getArticleCategories({int parentId = 3});
  Future<List<Map<String, Object?>>> getArticlesByCategory({
    int? categoryId,
    int page = 1,
  });
}

abstract interface class SaydianShopApi {
  Future<Map<String, Object?>> getShopHome();
  Future<Map<String, Object?>> getShopProduct(int id);
  Future<Map<String, Object?>> previewShopOrder({
    required List<Map<String, int>> items,
  });
  Future<Map<String, Object?>> createShopOrder({
    required List<Map<String, int>> items,
    required int addressId,
    String buyerMessage = '',
    num point = 0,
  });
  Future<Map<String, Object?>> createShopPayment({
    required String provider,
    required int orderId,
    required num money,
  });
  Future<void> confirmOrderReceipt(int orderId);
  Future<void> applyOrderRefund({
    required int orderProductId,
    required int refundType,
    required num amount,
    required String reason,
  });
  Future<Map<String, Object?>> getAddress(int id);
  Future<Map<String, Object?>> saveAddress({
    int? id,
    required String realname,
    required String mobile,
    required String addressDetails,
    required bool isDefault,
    required String region,
    required int provinceId,
    required int cityId,
    required int areaId,
  });
  Future<List<Map<String, Object?>>> getOrderExpress(int orderId);
}

abstract interface class SaydianCareApi {
  Future<List<Map<String, Object?>>> getCareInvitations();
  Future<void> respondCareInvitation({required int id, required bool accepted});
  Future<Set<String>> getCareShareSettings({
    required int type,
    required int memberId,
  });
  Future<void> saveCareShareSettings({
    required int type,
    required int memberId,
    required Set<String> settings,
  });
}

abstract interface class SaydianProfileUploadApi {
  Future<String> uploadProfileImage(String filePath);
}

class SaydianApiClient
    implements
        SaydianApi,
        SaydianFileApi,
        SaydianSmsAuthApi,
        SaydianArticleApi,
        SaydianShopApi,
        SaydianCareApi,
        SaydianProfileUploadApi {
  SaydianApiClient(this._vault, {http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri =
          baseUri ??
          Uri.parse(
            const String.fromEnvironment(
              'SAYDIAN_API_BASE_URL',
              defaultValue: 'https://app.saidian.cc',
            ),
          );

  final SessionVault _vault;
  final http.Client _client;
  final Uri _baseUri;
  final Map<int, int> _careMemberIds = <int, int>{};
  Future<Session>? _refreshingSession;

  static const _requestTimeout = Duration(seconds: 20);
  static const _aiReplyTimeout = Duration(seconds: 75);

  Uri _uri(String path, [Map<String, String>? query]) =>
      _baseUri.resolve(path).replace(queryParameters: query);

  @override
  Future<Session> login(String username, String password) => _authenticate(
    '/api/v1/site/login',
    {'username': username, 'password': password, 'group': 'app'},
  );

  @override
  Future<Session> register(String mobile, String password) => _authenticate(
    '/api/v1/site/register',
    {'mobile': mobile, 'password': password, 'group': 'app'},
  );

  @override
  Future<void> sendSmsCode({
    required String mobile,
    required String usage,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/v1/site/sms-code'))
      ..fields.addAll({'mobile': mobile.trim(), 'usage': usage});
    _decode(await _sendMultipart(request));
  }

  @override
  Future<Session> registerWithSms({
    required String mobile,
    required String code,
    required String password,
    required String nickname,
  }) => _authenticate('/api/v1/site/register', {
    'mobile': mobile.trim(),
    'code': code.trim(),
    'password': password,
    'password_repetition': password,
    'nickname': nickname.trim(),
    'group': 'app',
  });

  @override
  Future<Session> resetPassword({
    required String mobile,
    required String code,
    required String password,
  }) => _authenticate('/api/v1/site/up-pwd', {
    'mobile': mobile.trim(),
    'code': code.trim(),
    'password': password,
    'password_repetition': password,
    'group': 'app',
  });

  @override
  Future<Session> refreshSession(Session session) {
    final pending = _refreshingSession;
    if (pending != null) return pending;
    final refresh = _authenticate('/api/v1/site/refresh', {
      'refresh_token': session.refreshToken,
      'group': 'app',
    }, fallback: session);
    _refreshingSession = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshingSession, refresh)) _refreshingSession = null;
    });
  }

  Future<Session> _authenticate(
    String path,
    Map<String, String> fields, {
    Session? fallback,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..fields.addAll(fields);
    final response = await _sendMultipart(request);
    final payload = _decode(response);
    final data = _data(payload);
    final member = data['member'];
    final memberMap = member is Map ? member : const <Object?, Object?>{};
    final rawExpiration = (data['expiration_time'] as num?)?.toInt() ?? 43200;
    final now = DateTime.now().toUtc();
    final expiresAt = rawExpiration > 1000000000
        ? DateTime.fromMillisecondsSinceEpoch(
            rawExpiration > 1000000000000
                ? rawExpiration
                : rawExpiration * 1000,
            isUtc: true,
          )
        : now.add(Duration(seconds: rawExpiration));
    final session = Session(
      accessToken: '${data['access_token'] ?? ''}',
      refreshToken: '${data['refresh_token'] ?? fallback?.refreshToken ?? ''}',
      expiresAt: expiresAt,
      memberId: '${memberMap['id'] ?? fallback?.memberId ?? ''}',
      displayName:
          '${memberMap['nickname'] ?? memberMap['username'] ?? fallback?.displayName ?? '赛电用户'}',
    );
    if (session.accessToken.isEmpty) {
      throw const ApiException('登录响应缺少 access_token');
    }
    await _vault.writeSession(session);
    return session;
  }

  @override
  Future<List<Map<String, Object?>>> getCareMembers() async {
    final response = await _authorizedGet('/api/v1/member/care/my');
    Map<String, Object?> payload;
    try {
      payload = _decode(response);
    } on ApiException catch (error) {
      // The current backend can return a missing-route business code inside
      // an HTTP 200 response. Treat both transport and business 404/405 as
      // the documented optional-endpoint state so the local queue is kept.
      if (error.statusCode == 404 || error.statusCode == 405) {
        throw FeatureNotConfiguredException(
          '远程关爱接口暂未配置',
          statusCode: error.statusCode,
        );
      }
      rethrow;
    }
    final data = payload['data'];
    final rawList = data is List
        ? data
        : data is Map && data['list'] is List
        ? data['list'] as List
        : const [];
    if (kDebugMode) {
      final shape = data is Map
          ? 'mapKeys=${data.keys.map((key) => '$key').join(',')}'
          : 'type=${data.runtimeType}';
      debugPrint('Care member response: $shape, rows=${rawList.length}');
    }
    final members = rawList
        .whereType<Map>()
        .map((value) {
          final relation = value.map((key, value) => MapEntry('$key', value));
          // The mini-program renders `item.member`. Keep that as the primary
          // contract, while accepting the two relation aliases returned by
          // older deployments of the same endpoint.
          final rawMember =
              relation['member'] ??
              relation['to_member'] ??
              relation['care_member'];
          final member = rawMember is Map
              ? rawMember.map((key, value) => MapEntry('$key', value))
              : const <String, Object?>{};
          // The care endpoint currently returns the complete member row.  Keep
          // only fields that are needed by the family-care UI so credentials and
          // other account internals never enter application state.
          final safeMember = <String, Object?>{
            for (final key in const [
              'id',
              'nickname',
              'mobile',
              'head_portrait',
              'gender',
            ])
              if (member.containsKey(key)) key: member[key],
          };
          final rawAvatar = '${safeMember['head_portrait'] ?? ''}'.trim();
          if (rawAvatar.isNotEmpty) {
            safeMember['head_portrait'] = _absoluteMediaUrl(rawAvatar);
          }
          return <String, Object?>{
            for (final key in const [
              'id',
              'member_id',
              'to_member_id',
              'status',
              'created_at',
            ])
              if (relation.containsKey(key)) key: relation[key],
            'member': safeMember,
            'nickname': safeMember['nickname'],
            'mobile': safeMember['mobile'],
            'head_portrait': safeMember['head_portrait'],
          };
        })
        .toList(growable: false);
    _careMemberIds.clear();
    for (final relation in members) {
      final relationId = int.tryParse('${relation['id'] ?? ''}');
      final member = relation['member'];
      // Match the mini-program contract exactly. `id` identifies the care
      // relation and is used by care/preview; `to_member_id` identifies the
      // observed member and is used by every health-detail endpoint.
      final memberId =
          int.tryParse('${relation['to_member_id'] ?? ''}') ??
          (member is Map ? int.tryParse('${member['id'] ?? ''}') : null);
      if (relationId != null && memberId != null) {
        _careMemberIds[relationId] = memberId;
      }
    }
    return members;
  }

  @override
  Future<Map<String, Object?>> addCare(String mobile) async {
    final normalized = mobile.trim();
    if (!RegExp(r'^\d{6,20}$').hasMatch(normalized)) {
      throw const ApiException('请输入正确的手机号');
    }
    final response = await _authorizedPostJson('/api/v1/member/care', {
      'mobile': normalized,
    });
    return _data(_decode(response));
  }

  @override
  Future<Map<String, Object?>> getMemberProfile() async {
    final response = await _authorizedGet('/api/v1/member/member/my');
    return _data(_decode(response));
  }

  @override
  Future<void> saveMemberProfile({
    required String nickname,
    required int gender,
    required String birthday,
    required double height,
    required double weight,
    String? headPortrait,
  }) async {
    final response = await _authorizedPostFields('/api/v1/member/member/save', {
      'nickname': nickname.trim(),
      'gender': '$gender',
      'birthday': birthday,
      // The deployed member module follows the original mini-program form
      // contract and validates numeric profile values as strings.
      'height': _profileNumber(height),
      'weight': _profileNumber(weight),
      if (headPortrait?.isNotEmpty ?? false) 'head_portrait': headPortrait!,
    });
    _decode(response);
  }

  String _profileNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  @override
  Future<String> uploadImage(String filePath) async {
    if (filePath.trim().isEmpty) throw const ApiException('请选择头像图片');
    final response = await _withAuthorizationRetry((session) async {
      final request = http.MultipartRequest('POST', _uri('/api/v1/file/images'))
        ..headers.addAll(_authorizationHeaders(session));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      return _sendMultipart(request);
    });
    final data = _data(_decode(response));
    final rawUrl = '${data['url'] ?? data['path'] ?? ''}'.trim();
    if (rawUrl.isEmpty) {
      throw const ApiException('头像上传失败，请稍后重试');
    }
    return _absoluteMediaUrl(rawUrl);
  }

  @override
  Future<String> uploadProfileImage(String filePath) => uploadImage(filePath);

  @override
  Future<Map<String, Object?>> getActivityGoals() async {
    final response = await _authorizedGet(
      '/api/v1/member/member-mubiao/preview',
    );
    return _data(_decode(response));
  }

  @override
  Future<void> saveActivityGoals({
    required int steps,
    required double distance,
    required int calories,
  }) async {
    final response = await _authorizedPostFields(
      '/api/v1/member/member-mubiao',
      {'steps': '$steps', 'juli': '$distance', 'reliang': '$calories'},
    );
    _decode(response);
  }

  @override
  Future<List<Map<String, Object?>>> getArticles() async {
    final response = await _performRequest(
      () => _client.get(_uri('/api/rf-article/article/index')),
    );
    return _normalizeArticles(_list(_decode(response)));
  }

  @override
  Future<List<Map<String, Object?>>> getArticleCategories({
    int parentId = 3,
  }) async {
    final response = await _performRequest(
      () => _client.get(
        _uri('/api/rf-article/article-cate/index', {'pid': '$parentId'}),
      ),
    );
    return _list(_decode(response));
  }

  @override
  Future<List<Map<String, Object?>>> getArticlesByCategory({
    int? categoryId,
    int page = 1,
  }) async {
    final response = await _performRequest(
      () => _client.get(
        _uri('/api/rf-article/article/index', {
          if (categoryId != null) 'cate_id': '$categoryId',
          'page': '$page',
        }),
      ),
    );
    return _normalizeArticles(_list(_decode(response)));
  }

  @override
  Future<Map<String, Object?>> getArticle(int id) async {
    final response = await _performRequest(
      () => _client.get(_uri('/api/rf-article/article/view', {'id': '$id'})),
    );
    return _normalizeArticle(_data(_decode(response)));
  }

  @override
  Future<Map<String, Object?>> getSingleArticle(int id) async {
    final response = await _performRequest(
      () => _client.get(
        _uri('/api/rf-article/article-single/view', {'id': '$id'}),
      ),
    );
    return _data(_decode(response));
  }

  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async {
    final response = await _authorizedGet('/api/v1/member/notify', {
      'page': '$page',
    });
    return _list(_decode(response));
  }

  @override
  Future<Map<String, Object?>> getNotification(int id) async {
    final response = await _authorizedGet('/api/v1/member/notify/$id');
    return _data(_decode(response));
  }

  @override
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  }) async {
    final response = await _authorizedGet('/api/rf-article/chat/index', {
      'app': '$app',
      'page': '$page',
    });
    return _list(_decode(response));
  }

  @override
  Future<Map<String, Object?>> sendAiMessage({
    required int app,
    required String message,
    String? sessionId,
  }) async {
    final response =
        await _authorizedPostJsonWithTimeout('/api/rf-article/chat/create', {
          'app': app,
          'message': message.trim(),
          if (sessionId?.isNotEmpty ?? false) 'session_id': sessionId!,
        }, _aiReplyTimeout);
    return _data(_decode(response));
  }

  @override
  Future<List<Map<String, Object?>>> getOrders({int? status}) async {
    final response = await _authorizedGet(
      '/api/inv-shop/v1/member/order/index',
      {'page': '1', if (status != null) 'synthesize_status': '$status'},
    );
    return _list(_decode(response));
  }

  @override
  Future<Map<String, Object?>> getOrderDetail(int id) async {
    final response = await _authorizedGet(
      '/api/inv-shop/v1/member/order/view',
      {'id': '$id'},
    );
    return _data(_decode(response));
  }

  @override
  Future<List<Map<String, Object?>>> getAddresses() async {
    final response = await _authorizedGet('/api/v1/member/address', const {
      'page': '1',
    });
    return _list(_decode(response));
  }

  @override
  Future<Map<String, Object?>> getShopHome() async {
    final response = await _performRequest(
      () => _client.get(_uri('/api/v1/pages', const {'code': 'SHOP_HOME'})),
    );
    return _data(_decode(response));
  }

  @override
  Future<Map<String, Object?>> getShopProduct(int id) async {
    final response = await _performRequest(
      () => _client.get(
        _uri('/api/inv-shop/v1/product/product/view', {'id': '$id'}),
      ),
    );
    return _data(_decode(response));
  }

  @override
  Future<Map<String, Object?>> previewShopOrder({
    required List<Map<String, int>> items,
  }) async {
    if (items.isEmpty) throw const ApiException('请选择要结算的商品');
    if (items.length == 1) return _previewSingleShopOrder(items.single);

    // The deployed shop service only accepts one buy_now item per preview.
    // Compose the checkout summary from authoritative per-SKU previews so the
    // cart can still support selecting several products without inventing
    // prices or shipping costs on the client.
    final previews = await Future.wait(items.map(_previewSingleShopOrder));
    final first = previews.first;
    final products = <Map<String, Object?>>[];
    var productMoney = 0.0;
    var shippingMoney = 0.0;
    for (final preview in previews) {
      final rawProducts = preview['products'];
      if (rawProducts is List) {
        products.addAll(
          rawProducts.whereType<Map>().map(
            (item) => item.map(
              (key, value) => MapEntry<String, Object?>('$key', value),
            ),
          ),
        );
      }
      final summary = preview['preview'];
      if (summary is Map) {
        productMoney += _shopNumber(summary['product_money']);
        shippingMoney += _shopNumber(summary['shipping_money']);
      }
    }
    final firstSummary = first['preview'];
    return <String, Object?>{
      ...first,
      'products': products,
      'preview': <String, Object?>{
        if (firstSummary is Map)
          ...firstSummary.map(
            (key, value) => MapEntry<String, Object?>('$key', value),
          ),
        'product_money': productMoney,
        'shipping_money': shippingMoney,
      },
      'multiple_orders': true,
      'order_count': items.length,
    };
  }

  Future<Map<String, Object?>> _previewSingleShopOrder(
    Map<String, int> item,
  ) async {
    final data = jsonEncode(item);
    final response = await _authorizedGet(
      '/api/inv-shop/v1/order/order/preview',
      {'type': 'buy_now', 'data': data, 'is_channel': '0'},
    );
    return _data(_decode(response));
  }

  @override
  Future<Map<String, Object?>> createShopOrder({
    required List<Map<String, int>> items,
    required int addressId,
    String buyerMessage = '',
    num point = 0,
  }) async {
    if (items.isEmpty) throw const ApiException('请选择要结算的商品');
    if (items.length == 1) {
      return _createSingleShopOrder(
        item: items.single,
        addressId: addressId,
        buyerMessage: buyerMessage,
        point: point,
      );
    }

    // The backend has no multi-product order endpoint. Create one server order
    // per selected SKU and return a single aggregate result to the UI. Points
    // are applied once to avoid spending the requested amount repeatedly.
    final orders = <Map<String, Object?>>[];
    final createdSkuIds = <int>[];
    ApiException? partialFailure;
    for (var index = 0; index < items.length; index++) {
      try {
        orders.add(
          await _createSingleShopOrder(
            item: items[index],
            addressId: addressId,
            buyerMessage: buyerMessage,
            point: index == 0 ? point : 0,
          ),
        );
        final skuId = items[index]['sku_id'];
        if (skuId != null) createdSkuIds.add(skuId);
      } on ApiException catch (error) {
        if (orders.isEmpty) rethrow;
        partialFailure = error;
        break;
      }
    }
    final orderIds = orders
        .map((order) => _shopInt(order['id'] ?? order['order_id']))
        .whereType<int>()
        .toList(growable: false);
    return <String, Object?>{
      ...orders.first,
      'orders': orders,
      'order_ids': orderIds,
      'created_sku_ids': createdSkuIds,
      'multiple_orders': true,
      if (partialFailure != null) 'partial_failure': partialFailure.message,
    };
  }

  Future<Map<String, Object?>> _createSingleShopOrder({
    required Map<String, int> item,
    required int addressId,
    required String buyerMessage,
    required num point,
  }) async {
    final response =
        await _authorizedPostJson('/api/inv-shop/v1/order/order/create', {
          'merchant_id': 0,
          'is_channel': 0,
          'address_id': addressId,
          'buyer_message': buyerMessage.trim(),
          'data': jsonEncode(item),
          'shipping_type': 1,
          'type': 'buy_now',
          'point': point,
        });
    return _data(_decode(response));
  }

  @override
  Future<Map<String, Object?>> createShopPayment({
    required String provider,
    required int orderId,
    required num money,
  }) async {
    if (orderId <= 0 || money <= 0) {
      throw const ApiException('订单金额或编号异常，请刷新后重试');
    }
    final payType = switch (provider) {
      // RageFrame PayTypeEnum: WeChat = 100, Alipay = 101. Values 1 and 2
      // mean balance/cash and cannot generate APP payment parameters.
      'wechat' => 100,
      'alipay' => 101,
      _ => throw const ApiException('不支持的支付方式'),
    };
    final response = await _authorizedPostJson('/api/v1/pay', {
      'pay_type': payType,
      'jump': 0,
      'trade_type': 'app',
      'order_group': 'order',
      // The server reads and verifies the payable amount from the order.
      // Never trust a client-supplied amount for payment signing.
      'data': jsonEncode({'order_id': orderId}),
    });
    return _data(_decode(response));
  }

  double _shopNumber(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  int? _shopInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  @override
  Future<void> confirmOrderReceipt(int orderId) async {
    final response = await _authorizedPostFields(
      '/api/inv-shop/v1/member/order/take-delivery',
      {'id': '$orderId'},
    );
    _decode(response);
  }

  @override
  Future<void> applyOrderRefund({
    required int orderProductId,
    required int refundType,
    required num amount,
    required String reason,
  }) async {
    final response = await _authorizedPostFields(
      '/api/inv-shop/v1/member/order-product/refund-apply',
      {
        'id': '$orderProductId',
        'refund_type': '$refundType',
        'refund_require_money': '$amount',
        'refund_reason': reason.trim(),
      },
    );
    _decode(response);
  }

  @override
  Future<Map<String, Object?>> getAddress(int id) async {
    final response = await _authorizedGet('/api/v1/member/address/$id');
    return _data(_decode(response));
  }

  @override
  Future<Map<String, Object?>> saveAddress({
    int? id,
    required String realname,
    required String mobile,
    required String addressDetails,
    required bool isDefault,
    required String region,
    required int provinceId,
    required int cityId,
    required int areaId,
  }) async {
    final body = <String, Object?>{
      'realname': realname.trim(),
      'mobile': mobile.trim(),
      'address_details': addressDetails.trim(),
      'is_default': isDefault ? 1 : 0,
      'region': region,
      'province_id': provinceId,
      'city_id': cityId,
      'area_id': areaId,
    };
    final response = id == null
        ? await _authorizedPostJson('/api/v1/member/address', body)
        : await _authorizedPutJson('/api/v1/member/address/$id', body);
    return _data(_decode(response));
  }

  @override
  Future<List<Map<String, Object?>>> getOrderExpress(int orderId) async {
    final response = await _authorizedGet(
      '/api/inv-shop/v1/member/order-product-express/details',
      {'order_id': '$orderId'},
    );
    final data = _data(_decode(response));
    final rawList = data['data'];
    if (rawList is! List) return const [];
    return rawList
        .whereType<Map>()
        .map((value) => value.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) =>
      _uploadMiniProgramHealthRecords(batch);

  Future<BatchUploadResult> _uploadMiniProgramHealthRecords(
    SyncBatch batch,
  ) async {
    final accepted = <String>{};
    final rejected = <String, String>{};
    final activityRecords = batch.records
        .where(
          (record) => const {
            HealthMetric.steps,
            HealthMetric.distance,
            HealthMetric.calories,
          }.contains(record.metric),
        )
        .toList(growable: false);
    if (activityRecords.isNotEmpty) {
      try {
        num latest(HealthMetric metric) {
          final records =
              activityRecords
                  .where((record) => record.metric == metric)
                  .toList()
                ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
          return records.isEmpty
              ? 0
              : records.last.values['value'] ??
                    records.last.values.values.firstOrNull ??
                    0;
        }

        final response = await _authorizedPostJson('/api/v1/member/jrjk', {
          'steps_num': latest(HealthMetric.steps),
          'reliang_num': latest(HealthMetric.calories),
          'juli_num': latest(HealthMetric.distance),
        });
        _decode(response);
        accepted.addAll(activityRecords.map((record) => record.id));
      } on ApiException catch (error) {
        for (final record in activityRecords) {
          rejected[record.id] = error.message;
        }
      }
    }

    const dailyMetrics = <HealthMetric>{
      HealthMetric.sleep,
      HealthMetric.heartRate,
      HealthMetric.bloodOxygen,
      HealthMetric.bloodPressure,
      HealthMetric.bloodGlucose,
      HealthMetric.bodyTemperature,
      HealthMetric.hrv,
    };
    final dailyGroups = <String, List<HealthRecord>>{};
    for (final record in batch.records) {
      if (!dailyMetrics.contains(record.metric)) continue;
      final key = _miniProgramDailyDateKey(record.measuredAt.toLocal());
      dailyGroups.putIfAbsent(key, () => <HealthRecord>[]).add(record);
    }
    if (dailyGroups.isNotEmpty) {
      final dailyRecords = dailyGroups.values.expand((records) => records);
      try {
        final orderedKeys = dailyGroups.keys.toList()..sort();
        final response = await _authorizedPostJson(
          '/api/v1/member/daily-date',
          {
            'dailyDate': [
              for (final key in orderedKeys)
                _miniProgramDailyRow(dailyGroups[key]!),
            ],
          },
        );
        _decode(response);
        accepted.addAll(dailyRecords.map((record) => record.id));
      } on ApiException catch (error) {
        for (final record in dailyRecords) {
          rejected[record.id] = error.message;
        }
      } catch (_) {
        for (final record in dailyRecords) {
          rejected[record.id] = '健康数据同步失败，请稍后重试';
        }
      }
    }

    for (final record in batch.records) {
      if (accepted.contains(record.id) || rejected.containsKey(record.id)) {
        continue;
      }
      try {
        await _uploadMiniProgramHealthRecord(record);
        accepted.add(record.id);
      } on ApiException catch (error) {
        rejected[record.id] = error.message;
      } catch (_) {
        rejected[record.id] = '健康数据同步失败，请稍后重试';
      }
    }
    return BatchUploadResult(
      acceptedIds: accepted,
      rejected: rejected,
      nextCursor: batch.cursor,
    );
  }

  String _miniProgramDailyDateKey(DateTime local) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:00';
  }

  Map<String, Object?> _miniProgramDailyRow(List<HealthRecord> records) {
    final ordered = [...records]
      ..sort((left, right) => left.measuredAt.compareTo(right.measuredAt));
    final local = ordered.last.measuredAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');

    HealthRecord? latest(HealthMetric metric) {
      for (final record in ordered.reversed) {
        if (record.metric == metric) return record;
      }
      return null;
    }

    num? primary(HealthMetric metric) {
      final record = latest(metric);
      return record?.values['value'] ?? record?.values.values.firstOrNull;
    }

    final heartRate = primary(HealthMetric.heartRate);
    final oxygen = primary(HealthMetric.bloodOxygen);
    final glucose = primary(HealthMetric.bloodGlucose);
    final temperature = primary(HealthMetric.bodyTemperature);
    final hrv = primary(HealthMetric.hrv);
    final pressure = latest(HealthMetric.bloodPressure);
    final sleep = latest(HealthMetric.sleep);
    final sleepMinutes = ((sleep?.values['value'] ?? 0) * 60).round();
    final deepMinutes = ((sleep?.values['deepHours'] ?? 0) * 60).round();
    final lightMinutes = ((sleep?.values['lightHours'] ?? 0) * 60).round();

    // Keep the field names and value shapes identical to pages/app/home.ts in
    // the original mini program. The care-member preview endpoints read these
    // legacy fields directly; normalized APP-only keys are not sufficient.
    return <String, Object?>{
      'date': _miniProgramDailyDateKey(local),
      'h': two(local.hour),
      'isHourse': local.minute == 0 ? 1 : 0,
      'hourse': '${two(local.hour)}:${two(local.minute)}',
      'step': 0,
      'sleepData': sleep == null
          ? null
          : <String, Object?>{
              'allSleepTime': sleepMinutes,
              'deepSleepTime': deepMinutes,
              'lowSleepTime': lightMinutes,
              'wakeCount': (sleep.values['wakeCount'] ?? 0).round(),
            },
      'heartReat': heartRate,
      'respirationRate': null,
      'sleepAmountActivity': null,
      'sleepStatus': null,
      'meiTuo': null,
      'pressure': null,
      'bloodLiquid': null,
      'bloodPressure': pressure == null
          ? null
          : <String, Object?>{
              'bloodPressureHigh': pressure.values['systolic'],
              'bloodPressureLow': pressure.values['diastolic'],
            },
      'bloodGlucose': glucose,
      'bloodOxygen': oxygen == null
          ? null
          : <String, Object?>{
              'oxygens': [oxygen, 0, 0],
            },
      'bodyTemperature': temperature == null
          ? null
          : <String, Object?>{'bodyTemperature': temperature},
      'pulseReat': heartRate == null ? null : [heartRate],
      'HRVData': hrv == null ? null : [hrv],
    };
  }

  Future<void> _uploadMiniProgramHealthRecord(HealthRecord record) async {
    http.Response response;
    switch (record.metric) {
      case HealthMetric.bodyComposition:
        final values = record.values;
        response = await _authorizedPostJson('/api/v1/member/bodycomposition', {
          'data': <String, Object?>{
            'BMI': values['bmi'],
            'bodyFatRate': values['bodyFatRate'],
            'fatRate': values['fatMass'],
            'FFM': values['fatFreeMass'],
            'muscleRate': values['muscleRate'],
            'muscleMass': values['muscleMass'],
            'subcutaneousFat': values['subcutaneousFat'],
            'bodyWater': values['bodyWaterRate'],
            'waterContent': values['waterMass'],
            'skeletalMuscleRate': values['skeletalMuscleRate'],
            'boneMass': values['boneMass'],
            'proteinProportion': values['proteinRate'],
            'proteinMass': values['proteinMass'],
            'basalMetabolicRate': values['basalMetabolicRate'],
          }..removeWhere((_, value) => value == null),
        });
        break;
      case HealthMetric.bloodComposition:
        final values = record.values;
        response = await _authorizedPostJson(
          '/api/v1/member/bloodcomposition',
          {
            'data': <String, Object?>{
              'uricAcidVal': values['uricAcid'],
              'cholesterol': values['totalCholesterol'],
              'triacylglycerol': values['triglycerides'],
              'highDensity': values['highDensityLipoprotein'],
              'lowDensity': values['lowDensityLipoprotein'],
            }..removeWhere((_, value) => value == null),
          },
        );
        break;
      case HealthMetric.ecg:
        response = await _authorizedPostJson('/api/v1/member/e-c-g', {
          'data': <String, Object?>{
            ...record.values,
            'date': record.measuredAt.toLocal().toIso8601String(),
            'rawVersion': record.rawVersion,
            'origin': record.origin.wireName,
          },
          'totalArray': record.samples,
        });
        break;
      case HealthMetric.sleep:
      case HealthMetric.steps:
      case HealthMetric.distance:
      case HealthMetric.calories:
      case HealthMetric.heartRate:
      case HealthMetric.bloodOxygen:
      case HealthMetric.bloodPressure:
      case HealthMetric.bloodGlucose:
      case HealthMetric.bodyTemperature:
      case HealthMetric.hrv:
        return;
    }
    _decode(response);
  }

  @override
  Future<void> logout() async {
    try {
      final response = await _authorizedPostJson(
        '/api/v1/site/logout',
        const {},
      );
      if (response.statusCode == 404 || response.statusCode == 405) {
        throw FeatureNotConfiguredException(
          '服务端退出接口未配置，已仅清除本机会话',
          statusCode: response.statusCode,
        );
      }
      _decode(response);
    } finally {
      await _vault.clearSession();
    }
  }

  @override
  Future<void> deleteAccount() async {
    final response = await _authorizedPostJson(
      '/api/v1/member/account/delete',
      const {'confirm': true},
    );
    if (response.statusCode == 404 || response.statusCode == 405) {
      throw FeatureNotConfiguredException(
        '账号注销接口未配置',
        statusCode: response.statusCode,
      );
    }
    _decode(response);
    await _vault.clearSession();
  }

  Future<http.Response> _authorizedGet(
    String path, [
    Map<String, String>? query,
  ]) => _withAuthorizationRetry(
    (session) => _performRequest(
      () => _client.get(
        _uri(path, query),
        headers: _authorizationHeaders(session),
      ),
    ),
  );

  Future<http.Response> _authorizedPostJson(
    String path,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) => _withAuthorizationRetry(
    (session) => _performRequest(
      () => _client.post(
        _uri(path),
        headers: {
          ..._authorizationHeaders(session),
          'Content-Type': 'application/json',
          ...headers,
        },
        body: jsonEncode(body),
      ),
    ),
  );

  Future<http.Response> _authorizedPostJsonWithTimeout(
    String path,
    Map<String, Object?> body,
    Duration timeout,
  ) => _withAuthorizationRetry(
    (session) => _performRequest(
      () => _client.post(
        _uri(path),
        headers: {
          ..._authorizationHeaders(session),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
      timeout: timeout,
    ),
  );

  Future<http.Response> _authorizedPostFields(
    String path,
    Map<String, String> fields,
  ) => _withAuthorizationRetry((session) {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_authorizationHeaders(session))
      ..fields.addAll(fields);
    return _sendMultipart(request);
  });

  Future<http.Response> _authorizedPutJson(
    String path,
    Map<String, Object?> body,
  ) => _withAuthorizationRetry(
    (session) => _performRequest(
      () => _client.put(
        _uri(path),
        headers: {
          ..._authorizationHeaders(session),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    ),
  );

  Future<http.Response> _withAuthorizationRetry(
    Future<http.Response> Function(Session session) request,
  ) async {
    final session = await _requiredSession();
    final response = await request(session);
    if (!_isUnauthorizedResponse(response) ||
        session.refreshToken.trim().isEmpty) {
      return response;
    }
    try {
      final refreshed = await refreshSession(session);
      return request(refreshed);
    } on ApiException {
      // Preserve the original protected-resource response so the caller shows
      // the backend's useful authentication message. A failed refresh is not
      // retried again and never clears the long-lived local session silently.
      return response;
    }
  }

  bool _isUnauthorizedResponse(http.Response response) {
    if (response.statusCode == 401) return true;
    try {
      final payload = jsonDecode(response.body);
      return payload is Map && payload['code'] is num && payload['code'] == 401;
    } on FormatException {
      return false;
    }
  }

  Future<http.Response> _sendMultipart(http.MultipartRequest request) async {
    final streamed = await _performRequest(() => _client.send(request));
    return _performRequest(() => http.Response.fromStream(streamed));
  }

  Map<String, String> _authorizationHeaders(Session session) => {
    'Authorization': 'Bearer ${session.accessToken}',
    // The original mini-program sends both headers. Some legacy member and
    // article modules still read `token` directly instead of the Bearer header.
    'token': session.accessToken,
  };

  String _absoluteMediaUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final parsed = Uri.tryParse(trimmed);
    if (parsed?.hasScheme ?? false) {
      return trimmed
          .replaceFirst('http://sd.cc/', 'https://app.saidian.cc/')
          .replaceFirst('https://sd.cc/', 'https://app.saidian.cc/');
    }
    return _baseUri
        .resolve(trimmed.startsWith('/') ? trimmed : '/$trimmed')
        .toString();
  }

  Future<T> _performRequest<T>(
    Future<T> Function() request, {
    Duration timeout = _requestTimeout,
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException('网络连接超时，请检查网络后重试', code: 'NETWORK_TIMEOUT');
    } on http.ClientException {
      throw const ApiException('网络连接失败，请检查网络后重试', code: 'NETWORK_UNAVAILABLE');
    }
  }

  Future<Session> _requiredSession() async {
    final session = await _vault.readSession();
    if (session == null) throw const ApiException('请先登录', statusCode: 401);
    if (session.expiresAt.isBefore(
      DateTime.now().toUtc().add(const Duration(minutes: 5)),
    )) {
      if (session.refreshToken.trim().isEmpty) {
        throw const ApiException('登录凭证不可刷新，请重新登录', statusCode: 401);
      }
      return refreshSession(session);
    }
    return session;
  }

  Map<String, Object?> _decode(http.Response response) {
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException('服务器返回了无法解析的数据', statusCode: response.statusCode);
    }
    if (decoded is! Map) {
      throw ApiException('服务器响应格式不正确', statusCode: response.statusCode);
    }
    final payload = decoded.map((key, value) => MapEntry('$key', value));
    final code = payload['code'];
    final businessStatus = code is num && code >= 400 && code < 600
        ? code.toInt()
        : response.statusCode;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (code is num && code.toInt() != 200)) {
      throw ApiException(
        '${payload['message'] ?? '请求失败'}',
        statusCode: businessStatus,
        code: code,
      );
    }
    return payload;
  }

  Map<String, Object?> _data(Map<String, Object?> payload) {
    final data = payload['data'];
    if (data is! Map) return <String, Object?>{};
    return data.map((key, value) => MapEntry('$key', value));
  }

  List<Map<String, Object?>> _list(Map<String, Object?> payload) {
    final data = payload['data'];
    final values = data is List
        ? data
        : data is Map && data['list'] is List
        ? data['list'] as List
        : const [];
    return values
        .whereType<Map>()
        .map((value) => value.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  List<Map<String, Object?>> _normalizeArticles(
    List<Map<String, Object?>> articles,
  ) => articles.map(_normalizeArticle).toList();

  Map<String, Object?> _normalizeArticle(Map<String, Object?> article) {
    final cover = article['cover'];
    if (cover is! String ||
        (cover != 'http://sd.cc' && !cover.startsWith('http://sd.cc/'))) {
      return article;
    }
    return <String, Object?>{
      ...article,
      'cover': cover.replaceFirst('http://sd.cc', 'https://app.saidian.cc'),
    };
  }

  @override
  Future<Map<String, Object?>> getCareMemberPreview({
    required int id,
    required String day,
    int? memberId,
  }) async {
    Map<String, Object?> aggregate = const {};
    ApiException? aggregateError;
    try {
      final response = await _authorizedGet('/api/v1/member/care/preview', {
        'id': '$id',
        'day': day,
      });
      aggregate = _data(_decode(response));
    } on ApiException catch (error) {
      aggregateError = error;
    }
    final targetMemberId = memberId ?? _careMemberIds[id];
    if (targetMemberId == null) {
      if (aggregateError != null) throw aggregateError;
      return aggregate;
    }
    final detail = await _getCareMemberHealthDetails(
      memberId: targetMemberId,
      day: day,
    );
    if (aggregate.isEmpty && detail.isEmpty && aggregateError != null) {
      throw aggregateError;
    }
    return _mergeCarePreview(aggregate, detail);
  }

  Future<List<Map<String, Object?>>> _getCareMemberHealthDetails({
    required int memberId,
    required String day,
  }) async {
    final parsedDay = DateTime.tryParse(day);
    if (parsedDay == null) return const [];
    final localDay = DateTime(parsedDay.year, parsedDay.month, parsedDay.day);
    final date = '${localDay.millisecondsSinceEpoch ~/ 1000}';
    Object? sharedDailyRows;
    var sharedDailyRowsAvailable = false;
    try {
      final response = await _authorizedGet(
        '/api/v1/member/daily-date/preview',
        {'selectmember': '$memberId', 'date': date},
      );
      final payload = _decode(response);
      sharedDailyRows = payload['data'];
      sharedDailyRowsAvailable = true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 ||
          error.code == 'NETWORK_TIMEOUT' ||
          error.code == 'NETWORK_UNAVAILABLE') {
        rethrow;
      }
    }
    const specs =
        <({String title, String endpoint, String? type, String unit})>[
          (
            title: '心率',
            endpoint: '/api/v1/member/daily-date/preview',
            type: 'pulseReat',
            unit: '次/分',
          ),
          (
            title: '血压',
            endpoint: '/api/v1/member/daily-date/preview',
            type: 'BloodPressure',
            unit: 'mmHg',
          ),
          (
            title: '血糖',
            endpoint: '/api/v1/member/daily-date/preview',
            type: 'BloodGlucose',
            unit: 'mmol/L',
          ),
          (
            title: '血氧',
            endpoint: '/api/v1/member/daily-date/preview',
            type: 'bloodOxygen',
            unit: '%',
          ),
          (
            title: '体温',
            endpoint: '/api/v1/member/daily-date/preview',
            type: 'BodyTemperature',
            unit: '℃',
          ),
          (
            title: 'HRV',
            endpoint: '/api/v1/member/daily-date/preview',
            type: 'HRV',
            unit: 'ms',
          ),
          (
            title: '睡眠',
            endpoint: '/api/v1/member/daily-date/preview',
            type: 'sleep',
            unit: '',
          ),
          (
            title: '心电',
            endpoint: '/api/v1/member/e-c-g/preview',
            type: null,
            unit: '',
          ),
          (
            title: '身体成分',
            endpoint: '/api/v1/member/bodycomposition/preview',
            type: null,
            unit: '',
          ),
          (
            title: '血液成分',
            endpoint: '/api/v1/member/bloodcomposition/preview',
            type: null,
            unit: '',
          ),
        ];
    final result = <Map<String, Object?>>[];
    for (final spec in specs) {
      try {
        final response = await _authorizedGet(spec.endpoint, {
          'selectmember': '$memberId',
          if (spec.type != null) 'type': spec.type!,
          'date': date,
        });
        final payload = _decode(response);
        final normalized = _normalizeCareMetric(
          title: spec.title,
          type: spec.type ?? spec.endpoint,
          unit: spec.unit,
          raw: payload['data'],
        );
        result.add(
          spec.endpoint == '/api/v1/member/daily-date/preview' &&
                  normalized['state'] != 'ready' &&
                  sharedDailyRowsAvailable
              ? _normalizeCareRawFallback(
                  title: spec.title,
                  type: spec.type ?? spec.endpoint,
                  unit: spec.unit,
                  raw: sharedDailyRows,
                )
              : normalized,
        );
      } on ApiException catch (error) {
        if (error.statusCode == 401 ||
            error.code == 'NETWORK_TIMEOUT' ||
            error.code == 'NETWORK_UNAVAILABLE') {
          rethrow;
        }
        if (spec.endpoint == '/api/v1/member/daily-date/preview' &&
            sharedDailyRowsAvailable) {
          result.add(
            _normalizeCareRawFallback(
              title: spec.title,
              type: spec.type ?? spec.endpoint,
              unit: spec.unit,
              raw: sharedDailyRows,
            ),
          );
          continue;
        }
        result.add(<String, Object?>{
          'title': spec.title,
          'metricType': spec.type ?? spec.endpoint,
          'unit': spec.unit,
          'state': 'unavailable',
          'tips': error.statusCode == 403
              ? '${spec.title}未获共享授权'
              : '${spec.title}服务暂不可用，请稍后重试',
          'records': const <Object?>[],
        });
      }
    }
    return result;
  }

  Map<String, Object?> _normalizeCareMetric({
    required String title,
    required String type,
    required String unit,
    required Object? raw,
  }) {
    final payload = raw is Map
        ? raw.map((key, value) => MapEntry('$key', value))
        : const <String, Object?>{};
    final rawRecords = <Map<String, Object?>>[];
    final directRows = raw is List
        ? raw
        : payload['list'] is List
        ? payload['list'] as List
        : payload['data'] is List
        ? payload['data'] as List
        : const [];
    rawRecords.addAll(directRows.whereType<Map>().map(_decodeCareRawRecord));

    final categories = payload['categories'];
    final series = payload['series'];
    if (rawRecords.isEmpty && categories is List && series is List) {
      for (var index = 0; index < categories.length; index++) {
        final record = <String, Object?>{'time': categories[index]};
        for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
          final rawSeries = series[seriesIndex];
          if (rawSeries is! Map) continue;
          final values = rawSeries['data'];
          if (values is! List || index >= values.length) continue;
          final name =
              '${rawSeries['name'] ?? rawSeries['title'] ?? '数值${seriesIndex + 1}'}';
          _putCareSeriesValue(
            record: record,
            title: title,
            seriesName: name,
            seriesIndex: seriesIndex,
            value: values[index],
          );
        }
        if (title == '睡眠') _putCareSleepTotal(record);
        if (record.length > 1) rawRecords.add(record);
      }
    }

    final normalizedRecords = title == '心电'
        ? rawRecords.map(_normalizeCareEcgRecord)
        : rawRecords;
    final records = normalizedRecords
        .where((record) => _careRecordHasReading(title, record))
        .toList(growable: false);
    final values = records
        .map((record) => _careMetricReading(title, record))
        .whereType<num>()
        .toList(growable: false);
    final pressureValues = title == '血压'
        ? records.map(_carePressureReading).whereType<(num, num)>().toList()
        : const <(num, num)>[];
    final latestIndex = _latestCareRecordIndex(records);
    Object? latest;
    Object? average;
    Object? maximum;
    Object? minimum;
    if (pressureValues.isNotEmpty) {
      String pair(num high, num low) =>
          '${_careApiNumber(high)}/${_careApiNumber(low)}';
      final latestPressure = _carePressureReading(records[latestIndex]);
      if (latestPressure != null) {
        latest = pair(latestPressure.$1, latestPressure.$2);
      }
      average = pair(
        pressureValues.map((value) => value.$1).reduce((a, b) => a + b) /
            pressureValues.length,
        pressureValues.map((value) => value.$2).reduce((a, b) => a + b) /
            pressureValues.length,
      );
      maximum = pair(
        pressureValues.map((value) => value.$1).reduce((a, b) => a > b ? a : b),
        pressureValues.map((value) => value.$2).reduce((a, b) => a > b ? a : b),
      );
      minimum = pair(
        pressureValues.map((value) => value.$1).reduce((a, b) => a < b ? a : b),
        pressureValues.map((value) => value.$2).reduce((a, b) => a < b ? a : b),
      );
    } else if (values.isNotEmpty) {
      latest = _careMetricReading(title, records[latestIndex]);
      maximum = values.reduce((a, b) => a > b ? a : b);
      minimum = values.reduce((a, b) => a < b ? a : b);
      average = values.reduce((a, b) => a + b) / values.length;
    }
    return <String, Object?>{
      'title': title,
      'metricType': type,
      'unit': unit,
      'state': records.isEmpty ? 'empty' : 'ready',
      'tips': records.isEmpty ? '当日暂无记录' : '共 ${records.length} 条记录',
      'records': records,
      'latest': ?latest,
      'max': ?maximum,
      'min': ?minimum,
      'avg': ?average,
    };
  }

  Map<String, Object?> _normalizeCareRawFallback({
    required String title,
    required String type,
    required String unit,
    required Object? raw,
  }) {
    final normalized = _normalizeCareMetric(
      title: title,
      type: type,
      unit: unit,
      raw: raw,
    );
    if (normalized['state'] == 'ready') return normalized;
    return <String, Object?>{...normalized, 'tips': '对方当日没有可共享的该项记录'};
  }

  Map<String, Object?> _decodeCareRawRecord(Map<Object?, Object?> row) =>
      row.map((key, value) => MapEntry('$key', _decodeCareRawValue(value)));

  Map<String, Object?> _normalizeCareEcgRecord(Map<String, Object?> record) {
    final normalized = <String, Object?>{...record};
    for (final key in const ['data', 'ecgData', 'item', 'result']) {
      final nested = record[key];
      if (nested is! Map) continue;
      for (final entry in nested.entries) {
        normalized.putIfAbsent('${entry.key}', () => entry.value);
      }
    }

    num? firstNumber(List<String> keys) {
      for (final key in keys) {
        final value = _carePositiveNumber(normalized[key]);
        if (value != null) return value;
      }
      return null;
    }

    final heartRate = firstNumber(const [
      'meanHeartRate',
      'aveHeart',
      'heartRate',
      'heart',
      'value',
    ]);
    final hrv = firstNumber(const ['averageHRV', 'aveHrv', 'hrv', 'HRVData']);
    final qt = firstNumber(const [
      'averageTimeInterval',
      'aveQT',
      'qtTime',
      'qt',
    ]);
    final frequency = firstNumber(const [
      'sampleFrequency',
      'frequency',
      'uploadFrequency',
    ]);
    if (heartRate != null) normalized['meanHeartRate'] = heartRate;
    if (hrv != null) normalized['averageHRV'] = hrv;
    if (qt != null) normalized['averageTimeInterval'] = qt;
    if (frequency != null && frequency >= 50 && frequency <= 1000) {
      normalized['sampleFrequency'] = frequency.toInt();
    }

    for (final key in const [
      'samples',
      'totalArray',
      'filterSignals',
      'waveformData',
    ]) {
      final samples = _careNumericSeries(normalized[key]);
      if (samples.length > 1) {
        normalized['samples'] = samples;
        break;
      }
    }
    normalized['origin'] = MeasurementOrigin.remoteMember.wireName;
    return normalized;
  }

  List<num> _careNumericSeries(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item is num ? item : num.tryParse('$item'))
        .whereType<num>()
        .where(
          (item) =>
              item.toDouble().isFinite &&
              item.toInt() != 2147483647 &&
              item.abs() < 1000000000,
        )
        .toList(growable: false);
  }

  Object? _decodeCareRawValue(Object? value) {
    if (value is String) {
      final text = value.trim();
      final isJsonContainer =
          (text.startsWith('{') && text.endsWith('}')) ||
          (text.startsWith('[') && text.endsWith(']')) ||
          (text.startsWith('"') && text.endsWith('"'));
      if (!isJsonContainer) return value;
      try {
        return _decodeCareRawValue(jsonDecode(text));
      } on FormatException {
        return value;
      }
    }
    if (value is List) {
      return value.map(_decodeCareRawValue).toList(growable: false);
    }
    if (value is Map) return _decodeCareRawRecord(value);
    return value;
  }

  void _putCareSeriesValue({
    required Map<String, Object?> record,
    required String title,
    required String seriesName,
    required int seriesIndex,
    required Object? value,
  }) {
    final decodedValue = _decodeCareRawValue(value);
    if (title == '血压') {
      final normalized = seriesName.toLowerCase();
      final high =
          normalized.contains('收缩') ||
          normalized.contains('高压') ||
          normalized.contains('systolic') ||
          normalized.contains('high');
      final low =
          normalized.contains('舒张') ||
          normalized.contains('低压') ||
          normalized.contains('diastolic') ||
          normalized.contains('low');
      if (high || (!low && seriesIndex == 0)) {
        record['bloodPressureHigh'] = decodedValue;
      } else if (low || seriesIndex == 1) {
        record['bloodPressureLow'] = decodedValue;
      } else {
        record[seriesName] = decodedValue;
      }
      return;
    }
    final canonicalKey = switch (title) {
      '心率' => 'pulseReat',
      '血糖' => 'bloodGlucose',
      '血氧' => 'bloodOxygen',
      '体温' => 'bodyTemperature',
      'HRV' => 'HRVData',
      _ => null,
    };
    if (canonicalKey != null && seriesIndex == 0) {
      record[canonicalKey] = decodedValue;
    } else {
      record[seriesName] = decodedValue;
    }
  }

  void _putCareSleepTotal(Map<String, Object?> record) {
    final values = record.entries
        .where((entry) => entry.key != 'time')
        .map((entry) => (entry.key, _carePositiveNumber(entry.value)))
        .where((entry) => entry.$2 != null)
        .toList(growable: false);
    if (values.isEmpty) return;
    num? total;
    for (final entry in values) {
      if (entry.$1.contains('总') ||
          entry.$1.contains('时长') ||
          entry.$1.toLowerCase().contains('total')) {
        total = entry.$2;
        break;
      }
    }
    record['sleepMinutes'] =
        total ?? values.map((entry) => entry.$2!).reduce((a, b) => a + b);
  }

  int _latestCareRecordIndex(List<Map<String, Object?>> records) {
    if (records.isEmpty) return 0;
    var latestIndex = records.length - 1;
    int? latestTime;
    for (var index = 0; index < records.length; index++) {
      final time = _careRecordTime(records[index]);
      if (time != null && (latestTime == null || time > latestTime)) {
        latestTime = time;
        latestIndex = index;
      }
    }
    return latestIndex;
  }

  int? _careRecordTime(Map<String, Object?> record) {
    for (final key in const [
      'timestamp',
      'measuredAt',
      'created_at',
      'updated_at',
      'date',
      'time',
      'hourse',
      'h',
    ]) {
      final value = record[key];
      if (value is num) {
        final numeric = value.toInt();
        if (numeric > 1000000000000) return numeric;
        if (numeric > 1000000000) return numeric * 1000;
        if (numeric >= 0 && numeric < 86400) return numeric;
      }
      final text = '${value ?? ''}'.trim();
      if (text.isEmpty) continue;
      final numeric = int.tryParse(text);
      if (numeric != null) {
        if (numeric > 1000000000000) return numeric;
        if (numeric > 1000000000) return numeric * 1000;
      }
      final clock = RegExp(
        r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
      ).firstMatch(text);
      if (clock != null) {
        final hour = int.parse(clock.group(1)!);
        final minute = int.parse(clock.group(2)!);
        final second = int.tryParse(clock.group(3) ?? '') ?? 0;
        if (hour < 24 && minute < 60 && second < 60) {
          return hour * 3600 + minute * 60 + second;
        }
      }
      final parsed = DateTime.tryParse(text);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return null;
  }

  bool _careRecordHasReading(String title, Map<String, Object?> record) {
    if (title == '血压') return _carePressureReading(record) != null;
    if (_careMetricReading(title, record) != null) return true;
    const metadata = <String>{
      'id',
      'member_id',
      'memberId',
      'merchant_id',
      'status',
      'day',
      'date',
      'time',
      'h',
      'hourse',
      'isHourse',
      'created_at',
      'updated_at',
    };
    if (title != '身体成分' && title != '血液成分' && title != '心电') {
      return false;
    }
    return record.entries.any(
      (entry) =>
          !metadata.contains(entry.key) &&
          _careContainsPositiveValue(entry.value),
    );
  }

  num? _careMetricReading(String title, Map<String, Object?> record) {
    final raw = switch (title) {
      '心率' => record['pulseReat'] ?? record['heartReat'] ?? record['value'],
      '血糖' => record['bloodGlucose'] ?? record['value'],
      '血氧' => record['bloodOxygen'] ?? record['oxygen'] ?? record['value'],
      '体温' =>
        record['bodyTemperature'] ?? record['temperature'] ?? record['value'],
      'HRV' => record['HRVData'] ?? record['hrv'] ?? record['value'],
      '睡眠' => record['sleepData'] ?? record['sleepMinutes'] ?? record['value'],
      '心电' =>
        record['meanHeartRate'] ??
            (record['ecgData'] is Map
                ? (record['ecgData'] as Map)['meanHeartRate']
                : null),
      _ => record['value'],
    };
    return _carePositiveNumber(
      raw,
      preferredKeys: switch (title) {
        '血氧' => const ['oxygens', 'bloodOxygen', 'value'],
        '体温' => const ['bodyTemperature', 'temperature', 'value'],
        '睡眠' => const ['allSleepTime', 'sleepMinutes', 'value'],
        _ => const [],
      },
    );
  }

  (num, num)? _carePressureReading(Map<String, Object?> record) {
    final pressure = record['bloodPressure'];
    final nested = pressure is Map
        ? pressure.map((key, value) => MapEntry('$key', value))
        : const <String, Object?>{};
    final pair = pressure is List && pressure.length >= 2
        ? (_carePositiveNumber(pressure[0]), _carePositiveNumber(pressure[1]))
        : pressure is String
        ? _carePressureStringPair(pressure)
        : null;
    final high = _carePositiveNumber(
      record['bloodPressureHigh'] ??
          record['highPressure'] ??
          record['systolic'] ??
          nested['bloodPressureHigh'] ??
          nested['highPressure'] ??
          nested['high'] ??
          nested['systolic'] ??
          pair?.$1,
    );
    final low = _carePositiveNumber(
      record['bloodPressureLow'] ??
          record['lowPressure'] ??
          record['diastolic'] ??
          nested['bloodPressureLow'] ??
          nested['lowPressure'] ??
          nested['low'] ??
          nested['diastolic'] ??
          pair?.$2,
    );
    return high == null || low == null ? null : (high, low);
  }

  (num?, num?)? _carePressureStringPair(String value) {
    final match = RegExp(
      r'^\s*(\d{2,3}(?:\.\d+)?)\s*[/,\-]\s*(\d{2,3}(?:\.\d+)?)\s*$',
    ).firstMatch(value);
    if (match == null) return null;
    return (num.tryParse(match.group(1)!), num.tryParse(match.group(2)!));
  }

  num? _carePositiveNumber(
    Object? value, {
    List<String> preferredKeys = const [],
  }) {
    if (value is num) return value.isFinite && value > 0 ? value : null;
    if (value is String) {
      final parsed = num.tryParse(value.trim());
      return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
    }
    if (value is List) {
      for (final item in value) {
        final parsed = _carePositiveNumber(item, preferredKeys: preferredKeys);
        if (parsed != null) return parsed;
      }
      return null;
    }
    if (value is Map) {
      for (final key in preferredKeys) {
        final parsed = _carePositiveNumber(
          value[key],
          preferredKeys: preferredKeys,
        );
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  bool _careContainsPositiveValue(Object? value) {
    if (_carePositiveNumber(value) != null) return true;
    if (value is List) return value.any(_careContainsPositiveValue);
    if (value is Map) return value.values.any(_careContainsPositiveValue);
    return false;
  }

  String _careApiNumber(num value) {
    final numeric = value.toDouble();
    if (numeric == numeric.roundToDouble()) return '${numeric.round()}';
    return numeric
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Map<String, Object?> _mergeCarePreview(
    Map<String, Object?> aggregate,
    List<Map<String, Object?>> detail,
  ) {
    final existing = aggregate['daily'] is List
        ? (aggregate['daily'] as List)
              .whereType<Map>()
              .map((row) => row.map((key, value) => MapEntry('$key', value)))
              .toList()
        : <Map<String, Object?>>[];
    final byTitle = <String, Map<String, Object?>>{
      for (final item in detail) '${item['title'] ?? ''}': item,
    };
    final merged = <Map<String, Object?>>[];
    for (final item in existing) {
      final title = '${item['title'] ?? ''}';
      final details = byTitle.remove(title);
      merged.add(details ?? item);
    }
    merged.addAll(byTitle.values);
    final today = aggregate['jrjk'] is List
        ? (aggregate['jrjk'] as List)
              .whereType<Map>()
              .map((item) => item.map((key, value) => MapEntry('$key', value)))
              .where(
                (item) => !_careHealthTitles.contains('${item['title'] ?? ''}'),
              )
              .toList(growable: false)
        : const <Map<String, Object?>>[];
    return <String, Object?>{
      ...aggregate,
      'fallback': aggregate.isEmpty && detail.isNotEmpty,
      'jrjk': today,
      'daily': merged,
    };
  }

  static const _careHealthTitles = <String>{
    '心率',
    '血压',
    '血糖',
    '血氧',
    '体温',
    'HRV',
    '睡眠',
    '心电',
    '身体成分',
    '血液成分',
  };

  @override
  Future<List<Map<String, Object?>>> getCareInvitations() async {
    final response = await _authorizedGet('/api/v1/member/care');
    final session = await _vault.readSession();
    final ownMemberId = int.tryParse(session?.memberId ?? '');
    return _list(_decode(response))
        .where((invite) {
          if (ownMemberId == null) return true;
          final inviterId = _shopInt(invite['member_id']);
          final recipientId = _shopInt(invite['to_member_id']);
          // `/member/care` returns both incoming invitations and relations
          // created by the signed-in account. Only incoming rows belong in
          // the invitation/share-authorization flow.
          return recipientId == ownMemberId && inviterId != ownMemberId;
        })
        .map((invite) {
          final inviterId = _shopInt(invite['member_id']);
          final candidates = <Object?>[
            invite['inviter'],
            invite['from_member'],
            invite['fromMember'],
            invite['member'],
          ];
          Map<String, Object?>? inviter;
          for (final candidate in candidates) {
            if (candidate is! Map) continue;
            final map = candidate.map(
              (key, value) => MapEntry<String, Object?>('$key', value),
            );
            final candidateId = _shopInt(map['id'] ?? map['member_id']);
            // Some backend builds incorrectly nest the invitation recipient as
            // `member`. Never present the signed-in user as their own inviter.
            if (candidateId == null ||
                candidateId == ownMemberId ||
                (inviterId != null && candidateId != inviterId)) {
              continue;
            }
            inviter = <String, Object?>{
              'id': candidateId,
              'nickname': '${map['nickname'] ?? ''}'.trim(),
              'mobile': '${map['mobile'] ?? ''}'.trim(),
              'head_portrait': '${map['head_portrait'] ?? map['avatar'] ?? ''}'
                  .trim(),
            };
            break;
          }
          return <String, Object?>{
            'id': invite['id'],
            'member_id': invite['member_id'],
            'to_member_id': invite['to_member_id'],
            'examine_status': invite['examine_status'],
            'status': invite['status'],
            'inviter_id': inviterId,
            'member': inviter ?? const <String, Object?>{},
          };
        })
        .toList(growable: false);
  }

  @override
  Future<void> respondCareInvitation({
    required int id,
    required bool accepted,
  }) async {
    final response = await _authorizedPostJson('/api/v1/member/care/save', {
      'id': id,
      'examine_status': accepted ? 1 : 2,
    });
    _decode(response);
  }

  @override
  Future<Set<String>> getCareShareSettings({
    required int type,
    required int memberId,
  }) async {
    final response = await _authorizedGet(
      '/api/v1/member/care-setting/preview',
      {'type': '$type', 'to_member_id': '$memberId'},
    );
    final data = _data(_decode(response));
    final raw = data['setting'];
    Object? decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        decoded = const <Object?>[];
      }
    }
    return decoded is List ? decoded.map((value) => '$value').toSet() : {};
  }

  @override
  Future<void> saveCareShareSettings({
    required int type,
    required int memberId,
    required Set<String> settings,
  }) async {
    final response = await _authorizedPostJson('/api/v1/member/care-setting', {
      'type': type,
      'to_member_id': memberId,
      'setting': settings.toList()..sort(),
    });
    _decode(response);
  }
}
