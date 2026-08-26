import 'dart:async';
import 'dart:convert';

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
    return rawList
        .whereType<Map>()
        .map((value) {
          final relation = value.map((key, value) => MapEntry('$key', value));
          final rawMember = relation['member'];
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
    final response = await _authorizedPostJson('/api/v1/member/member/save', {
      'nickname': nickname.trim(),
      'gender': gender,
      'birthday': birthday,
      // The member API validates these two fields as strings even though the
      // values are numeric. Keep the public Dart API typed and normalize only
      // at the transport boundary.
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
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    final response = await _authorizedPostJson(
      '/api/v1/member/health-records/batch',
      batch.toJson(),
      headers: {
        'Idempotency-Key':
            '${batch.records.firstOrNull?.id ?? 'empty'}-${batch.records.length}',
      },
    );
    if (response.statusCode == 404 || response.statusCode == 405) {
      return _uploadLegacyHealthRecords(batch);
    }
    Map<String, Object?> payload;
    try {
      payload = _decode(response);
    } on ApiException catch (error) {
      // The current backend can return a missing-route business code inside
      // an HTTP 200 response. Fall back to the same endpoints used by the
      // original mini program so care-member data is not silently stranded.
      if (error.statusCode == 404 || error.statusCode == 405) {
        return _uploadLegacyHealthRecords(batch);
      }
      rethrow;
    }
    final data = _data(payload);
    final accepted = data['accepted'];
    final rejected = data['rejected'];
    return BatchUploadResult(
      acceptedIds: accepted is List
          ? accepted.map((value) => '$value').toSet()
          : batch.records.map((record) => record.id).toSet(),
      rejected: rejected is List
          ? {
              for (final item in rejected.whereType<Map>())
                '${item['id']}': '${item['reason'] ?? '未知原因'}',
            }
          : const {},
      nextCursor: data['nextCursor']?.toString(),
    );
  }

  Future<BatchUploadResult> _uploadLegacyHealthRecords(SyncBatch batch) async {
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

    for (final record in batch.records) {
      if (accepted.contains(record.id) || rejected.containsKey(record.id)) {
        continue;
      }
      try {
        await _uploadLegacyHealthRecord(record);
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

  Future<void> _uploadLegacyHealthRecord(HealthRecord record) async {
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
          },
          'totalArray': record.samples,
        });
        break;
      case HealthMetric.sleep:
        // Sleep is uploaded from the vendor daily-data reader where its stage
        // payload is available. A summarized duration cannot be converted
        // back into that losslessly.
        throw const ApiException('睡眠分期数据需等待下次设备完整同步');
      case HealthMetric.steps:
      case HealthMetric.distance:
      case HealthMetric.calories:
        return;
      case HealthMetric.heartRate:
      case HealthMetric.bloodOxygen:
      case HealthMetric.bloodPressure:
      case HealthMetric.bloodGlucose:
      case HealthMetric.bodyTemperature:
      case HealthMetric.hrv:
        final local = record.measuredAt.toLocal();
        String two(int value) => value.toString().padLeft(2, '0');
        final value =
            record.values['value'] ?? record.values.values.firstOrNull;
        final daily = <String, Object?>{
          'date':
              '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}:00',
          'h': two(local.hour),
          'isHourse': local.minute == 0 ? 1 : 0,
          'hourse': '${two(local.hour)}:${two(local.minute)}',
          'step': 0,
          'bloodPressure': record.metric == HealthMetric.bloodPressure
              ? <String, Object?>{
                  'highPressure': record.values['systolic'],
                  'lowPressure': record.values['diastolic'],
                }
              : null,
          'bloodGlucose': record.metric == HealthMetric.bloodGlucose
              ? value
              : null,
          'bloodOxygen': record.metric == HealthMetric.bloodOxygen
              ? value
              : null,
          'bodyTemperature': record.metric == HealthMetric.bodyTemperature
              ? value
              : null,
          'pulseReat': record.metric == HealthMetric.heartRate ? value : null,
          'HRVData': record.metric == HealthMetric.hrv ? value : null,
        };
        response = await _authorizedPostJson('/api/v1/member/daily-date', {
          'dailyDate': [daily],
        });
        break;
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
  }) async {
    final response = await _authorizedGet('/api/v1/member/care/preview', {
      'id': '$id',
      'day': day,
    });
    return _data(_decode(response));
  }

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
