import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

abstract interface class SaydianNotificationApi {
  Future<bool> registerPushDevice({
    required String installationId,
    required String registrationId,
    required String platform,
    String? appVersion,
    int? buildNumber,
  });
  Future<bool> unregisterPushDevice({required String installationId});
  Future<int?> getNotificationUnreadCount();
  Future<bool> markNotificationRead({required int id});
  Future<bool> markNotificationEventRead({required String eventId});
}

abstract interface class SaydianProfileUploadApi {
  Future<String> uploadProfileImage(String filePath);
}

abstract interface class SaydianHealthCloudApi {
  Future<HealthWarningSettings?> getHealthWarningSettings();
  Future<List<HealthWarningAlert>> getHealthWarningAlerts();
  Future<void> saveHealthWarningSettings(HealthWarningSettings settings);
}

abstract interface class SaydianFeedbackApi {
  Future<String> submitFeedback({
    required String category,
    required String content,
    String contact = '',
  });
}

class SaydianApiClient
    implements
        SaydianApi,
        SaydianFileApi,
        SaydianSmsAuthApi,
        SaydianArticleApi,
        SaydianShopApi,
        SaydianCareApi,
        SaydianNotificationApi,
        SaydianProfileUploadApi,
        SaydianHealthCloudApi,
        SaydianFeedbackApi {
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
  final Map<String, Future<Session>> _refreshingSessions = {};

  static const _requestTimeout = Duration(seconds: 20);
  static const _aiReplyTimeout = Duration(seconds: 75);

  Uri _uri(String path, [Map<String, String>? query]) =>
      _baseUri.resolve(path).replace(queryParameters: query);

  @override
  Future<Session> login(String username, String password) => _authenticate(
    '/api/v1/site/login',
    {'username': username, 'password': password, 'group': 'app'},
    accountKey: _stableLoginAccountKey(username),
  );

  @override
  Future<Session> register(String mobile, String password) => _authenticate(
    '/api/v1/site/register',
    {'mobile': mobile, 'password': password, 'group': 'app'},
    accountKey: _stableLoginAccountKey(mobile),
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
  }, accountKey: _stableLoginAccountKey(mobile));

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
  }, accountKey: _stableLoginAccountKey(mobile));

  @override
  Future<Session> refreshSession(Session session) {
    final refreshKey = _stableSessionAccountKey(session);
    final pending = _refreshingSessions[refreshKey];
    if (pending != null) return pending;
    final refresh = _authenticate(
      '/api/v1/site/refresh',
      {'refresh_token': session.refreshToken, 'group': 'app'},
      fallback: session,
      accountKey: session.accountKey,
      expectedSession: session,
    );
    _refreshingSessions[refreshKey] = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshingSessions[refreshKey], refresh)) {
        _refreshingSessions.remove(refreshKey);
      }
    });
  }

  String _stableLoginAccountKey(String identifier) => sha256
      .convert(
        utf8.encode('saydian-account:${identifier.trim().toLowerCase()}'),
      )
      .toString();

  String _stableSessionAccountKey(Session session) {
    final memberId = session.memberId.trim();
    if (memberId.isNotEmpty) return 'member:$memberId';
    final accountKey = session.accountKey.trim();
    if (accountKey.isNotEmpty) return 'account:$accountKey';
    return 'unresolved:${identityHashCode(session)}';
  }

  Future<Session> _authenticate(
    String path,
    Map<String, String> fields, {
    Session? fallback,
    String? accountKey,
    Session? expectedSession,
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
      accountKey: accountKey?.trim().isNotEmpty == true
          ? accountKey!.trim()
          : fallback?.accountKey ?? '',
    );
    if (session.accessToken.isEmpty) {
      throw const ApiException('登录响应缺少 access_token');
    }
    if (expectedSession == null) {
      await _vault.writeSession(session);
    } else {
      final replaced = await _vault.writeSessionIfUnchanged(
        expectedSession,
        session,
      );
      if (!replaced) {
        throw const ApiException(
          '登录账号已切换，已忽略旧账号刷新',
          code: 'STALE_SESSION_REFRESH',
        );
      }
    }
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
  Future<bool> registerPushDevice({
    required String installationId,
    required String registrationId,
    required String platform,
    String? appVersion,
    int? buildNumber,
  }) async {
    final normalizedInstallationId = _validatedInstallationId(installationId);
    final normalizedPlatform = platform.trim().toLowerCase();
    final normalizedRegistrationId = registrationId.trim();
    if (!const {'ios', 'android'}.contains(normalizedPlatform) ||
        normalizedRegistrationId.isEmpty ||
        normalizedRegistrationId.length > 8192 ||
        (buildNumber != null && buildNumber <= 0)) {
      throw const ApiException('推送设备信息不完整');
    }
    final normalizedVersion = appVersion?.trim();
    if (normalizedVersion != null && normalizedVersion.length > 64) {
      throw const ApiException('应用版本信息不正确');
    }
    final response = await _authorizedPostJson(
      '/api/v1/member/push-devices',
      <String, Object?>{
        'installation_id': normalizedInstallationId,
        'platform': normalizedPlatform,
        'provider': 'jpush',
        'registration_id': normalizedRegistrationId,
        if (normalizedVersion != null && normalizedVersion.isNotEmpty)
          'app_version': normalizedVersion,
        'build': ?buildNumber,
      },
    );
    return _decodeOptionalNotificationMutation(response);
  }

  @override
  Future<bool> unregisterPushDevice({required String installationId}) async {
    final normalizedInstallationId = _validatedInstallationId(installationId);
    final response = await _authorizedDelete(
      '/api/v1/member/push-devices/${Uri.encodeComponent(normalizedInstallationId)}',
    );
    return _decodeOptionalNotificationMutation(response);
  }

  @override
  Future<int?> getNotificationUnreadCount() async {
    var response = await _authorizedGet('/api/v1/member/notify/statistics');
    if (_isOptionalNotificationEndpointUnavailableResponse(response)) {
      response = await _authorizedGet('/api/v1/member/notify/unread-count');
    }
    if (_isOptionalNotificationEndpointUnavailableResponse(response)) {
      return null;
    }
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        response.body.trim().isEmpty) {
      return null;
    }
    Map<String, Object?> payload;
    try {
      payload = _decode(response);
    } on ApiException catch (error) {
      if (_isOptionalNotificationEndpointUnavailable(error.statusCode)) {
        return null;
      }
      rethrow;
    }
    final count = _notificationUnreadCount(payload);
    if (count == null || count < 0) {
      throw const ApiException('消息未读数响应格式不正确');
    }
    return count;
  }

  @override
  Future<bool> markNotificationRead({required int id}) async {
    if (id <= 0) throw const ApiException('消息标识不正确');
    var response = await _authorizedGet('/api/v1/member/notify/$id');
    if (_isOptionalNotificationEndpointUnavailableResponse(response)) {
      response = await _authorizedPostJson(
        '/api/v1/member/notify/$id/read',
        const <String, Object?>{},
      );
    }
    return _decodeOptionalNotificationMutation(response);
  }

  @override
  Future<bool> markNotificationEventRead({required String eventId}) async {
    final normalizedEventId = _validatedNotificationEventId(eventId);
    final encodedEventId = Uri.encodeComponent(normalizedEventId);
    var response = await _authorizedGet(
      '/api/v1/member/notify/$encodedEventId',
    );
    if (_isOptionalNotificationEndpointUnavailableResponse(response)) {
      response = await _authorizedPostJson(
        '/api/v1/member/notify/$encodedEventId/read',
        const <String, Object?>{},
      );
    }
    return _decodeOptionalNotificationMutation(response);
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

    try {
      final request = <String, Object?>{
        'address_id': addressId,
        'buyer_message': buyerMessage.trim(),
        'items': items,
        'point': point,
      };
      final response = await _authorizedPostJson(
        '/api/inv-shop/v1/order/order/create-batch',
        request,
        headers: {
          'Idempotency-Key': sha256
              .convert(utf8.encode(jsonEncode(request)))
              .toString(),
        },
      );
      return _data(_decode(response));
    } on ApiException catch (error) {
      if (!_isOptionalNotificationEndpointUnavailable(error.statusCode)) {
        rethrow;
      }
    }

    // The old service has no multi-product endpoint. Keep its existing
    // per-SKU behavior only while the compatibility endpoint is unavailable.
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
      // The delivered payment contract uses 1 for WeChat and 2 for Alipay.
      // Keep these values as strings because the endpoint is a multipart
      // form and validates the documented string fields.
      'wechat' => '1',
      'alipay' => '2',
      _ => throw const ApiException('不支持的支付方式'),
    };
    final response = await _authorizedPostFields('/api/v1/pay', {
      'pay_type': payType,
      'jump': '0',
      'trade_type': 'app',
      'order_group': 'order',
      // The server must still verify the payable amount against the order;
      // this client value only follows the documented signing contract.
      'data': jsonEncode({
        'order_id': '$orderId',
        'money': money.toStringAsFixed(2),
      }),
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
  Future<HealthWarningSettings?> getHealthWarningSettings() async {
    final response = await _authorizedGet(
      '/api/saydian-app/v2/health/warning-rules',
    );
    final rules = _list(_decode(response));
    if (rules.isEmpty) return null;
    Map<String, Object?>? rule(String metric) {
      for (final item in rules) {
        if ('${item['metric'] ?? ''}' == metric) return item;
      }
      return null;
    }

    final defaults = const HealthWarningSettings();
    final heartRate = rule('heart_rate');
    final bloodPressure = rule('blood_pressure');
    final temperature = rule('temperature');
    return HealthWarningSettings(
      heartRateEnabled: _booleanOrDefault(
        heartRate?['enabled'],
        defaults.heartRateEnabled,
      ),
      heartRateUpper:
          (heartRate?['highThreshold'] as num?)?.toInt() ??
          defaults.heartRateUpper,
      bloodPressureEnabled: _booleanOrDefault(
        bloodPressure?['enabled'],
        defaults.bloodPressureEnabled,
      ),
      systolicUpper:
          (bloodPressure?['highThreshold'] as num?)?.toInt() ??
          defaults.systolicUpper,
      diastolicUpper:
          (bloodPressure?['secondaryHighThreshold'] as num?)?.toInt() ??
          defaults.diastolicUpper,
      temperatureEnabled: _booleanOrDefault(
        temperature?['enabled'],
        defaults.temperatureEnabled,
      ),
      temperatureUpper:
          (temperature?['highThreshold'] as num?)?.toDouble() ??
          defaults.temperatureUpper,
    );
  }

  @override
  Future<void> saveHealthWarningSettings(HealthWarningSettings settings) async {
    final response = await _authorizedPostJson(
      '/api/saydian-app/v2/health/warning-rules',
      {
        'rules': [
          {
            'metric': 'heart_rate',
            'enabled': settings.heartRateEnabled,
            'highThreshold': settings.heartRateUpper,
          },
          {
            'metric': 'blood_pressure',
            'enabled': settings.bloodPressureEnabled,
            'highThreshold': settings.systolicUpper,
            'secondaryHighThreshold': settings.diastolicUpper,
          },
          {
            'metric': 'temperature',
            'enabled': settings.temperatureEnabled,
            'highThreshold': settings.temperatureUpper,
          },
        ],
      },
    );
    _decode(response);
  }

  @override
  Future<List<HealthWarningAlert>> getHealthWarningAlerts() async {
    final response = await _authorizedGet(
      '/api/saydian-app/v2/health/warnings',
      {'limit': '100'},
    );
    final data = _data(_decode(response));
    final items = data['items'] is List ? data['items'] as List : const [];
    return items
        .whereType<Map>()
        .map((raw) {
          final item = raw.map((key, value) => MapEntry('$key', value));
          final metricWire = '${item['metric'] ?? ''}';
          final metric = HealthMetric.fromWire(
            metricWire == 'temperature' ? 'body_temperature' : metricWire,
          );
          final rule = item['rule'] is Map ? item['rule'] as Map : const {};
          final direction = '${rule['direction'] ?? ''}' == 'low' ? '低于' : '超过';
          return HealthWarningAlert(
            id: '${item['eventId'] ?? ''}',
            metric: metric,
            title: '${metric.label}提醒',
            message: '该记录$direction你设置的提醒值，请留意近期变化。',
            triggeredAt:
                DateTime.tryParse('${item['observedAt'] ?? ''}')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
            origin: MeasurementOrigin.unknown,
          );
        })
        .where((alert) => alert.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<String> submitFeedback({
    required String category,
    required String content,
    String contact = '',
  }) async {
    final response =
        await _authorizedPostJson('/api/saydian-app/v2/support/feedback', {
          'category': category.trim(),
          'content': content.trim(),
          if (contact.trim().isNotEmpty) 'contact': contact.trim(),
        });
    final data = _data(_decode(response));
    final id = '${data['id'] ?? ''}'.trim();
    if (id.isEmpty) throw const ApiException('反馈提交结果不完整，请稍后重试');
    return id;
  }

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    try {
      return await _uploadHealthBatchV2(batch);
    } on ApiException catch (error) {
      if (!_isOptionalNotificationEndpointUnavailable(error.statusCode)) {
        rethrow;
      }
      return _uploadMiniProgramHealthRecords(batch);
    }
  }

  Future<BatchUploadResult> _uploadHealthBatchV2(SyncBatch batch) async {
    if (batch.records.isEmpty) {
      return BatchUploadResult(
        acceptedIds: const {},
        rejected: const {},
        nextCursor: batch.cursor,
      );
    }
    if (batch.records.length > 200) {
      throw const ApiException('每次最多同步 200 条健康记录');
    }
    final records = <Map<String, Object?>>[];
    for (final record in batch.records) {
      Map<String, Object?>? ecgArtifact;
      if (record.metric == HealthMetric.ecg && record.samples.isNotEmpty) {
        ecgArtifact = await _uploadEcgArtifactV2(record);
      }
      records.add(_healthRecordV2(record, ecgArtifact: ecgArtifact));
    }
    final body = <String, Object?>{
      if (batch.cursor != null) 'cursor': batch.cursor,
      'records': records,
    };
    final idempotencyKey = sha256
        .convert(utf8.encode(jsonEncode(body)))
        .toString();
    final response = await _authorizedPostJson(
      '/api/saydian-app/v2/health/records/batch',
      body,
      headers: {'Idempotency-Key': idempotencyKey},
    );
    final data = _data(_decode(response));
    final accepted = (data['acceptedIds'] as List? ?? const [])
        .map((value) => '$value')
        .where((value) => value.isNotEmpty)
        .toSet();
    final rejected = <String, String>{};
    for (final item in (data['rejected'] as List? ?? const [])) {
      if (item is! Map) continue;
      final id = '${item['id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      rejected[id] = '${item['message'] ?? '健康数据同步失败，请稍后重试'}';
    }
    return BatchUploadResult(
      acceptedIds: accepted,
      rejected: rejected,
      nextCursor: data['nextCursor']?.toString(),
    );
  }

  Map<String, Object?> _healthRecordV2(
    HealthRecord record, {
    Map<String, Object?>? ecgArtifact,
  }) {
    final quality = switch (record.quality.toLowerCase()) {
      'good' || 'valid' => 'valid',
      'poor' || 'suspect' => 'suspect',
      'invalid' => 'invalid',
      _ => 'unknown',
    };
    return <String, Object?>{
      'id': record.id,
      'metric': record.metric == HealthMetric.bodyTemperature
          ? 'temperature'
          : record.metric.wireName,
      'observedAt': record.measuredAt.toUtc().toIso8601String(),
      'timezoneOffsetMinutes': _timezoneOffsetMinutes(record),
      'values': record.values,
      if (record.unit.trim().isNotEmpty) 'unit': record.unit,
      'quality': quality,
      'source': <String, Object?>{
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        if (record.deviceId.trim().isNotEmpty) 'deviceId': record.deviceId,
        if (record.firmwareVersion.trim().isNotEmpty)
          'firmware': record.firmwareVersion,
      },
      'ecgArtifact': ?ecgArtifact,
    };
  }

  int _timezoneOffsetMinutes(HealthRecord record) {
    final match = RegExp(
      r'^([+-])(\d{2}):(\d{2})$',
    ).firstMatch(record.timezone.trim());
    if (match == null) {
      return record.measuredAt.toLocal().timeZoneOffset.inMinutes;
    }
    final minutes =
        int.parse(match.group(2)!) * 60 + int.parse(match.group(3)!);
    return match.group(1) == '-' ? -minutes : minutes;
  }

  bool _booleanOrDefault(Object? value, bool fallback) {
    return value is bool ? value : fallback;
  }

  Future<Map<String, Object?>> _uploadEcgArtifactV2(HealthRecord record) async {
    final bytes = gzip.encode(utf8.encode(jsonEncode(record.samples)));
    final digest = sha256.convert(bytes).toString();
    final response = await _withAuthorizationRetry((session) {
      final request =
          http.MultipartRequest('POST', _uri('/api/saydian-app/v2/files/ecg'))
            ..headers.addAll(_authorizationHeaders(session))
            ..fields['sha256'] = digest
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: '${record.id}.json.gz',
              ),
            );
      return _sendMultipart(request);
    });
    final data = _data(_decode(response));
    final objectKey = '${data['uploadObjectKey'] ?? ''}'.trim();
    if (objectKey.isEmpty) {
      throw const ApiException('心电数据上传结果不完整，请稍后重试');
    }
    return <String, Object?>{
      'sampleRateHz': (record.values['sampleFrequency'] ?? 250).toInt(),
      'sampleCount': record.samples.length,
      'sha256': digest,
      'uploadObjectKey': objectKey,
    };
  }

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

  Future<http.Response> _authorizedDelete(String path) =>
      _withAuthorizationRetry(
        (session) => _performRequest(
          () => _client.delete(
            _uri(path),
            headers: _authorizationHeaders(session),
          ),
        ),
      );

  String _validatedInstallationId(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^[A-Za-z0-9._:-]{1,160}$').hasMatch(normalized)) {
      throw const ApiException('推送设备信息不完整');
    }
    return normalized;
  }

  String _validatedNotificationEventId(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^[A-Za-z0-9._:-]{1,160}$').hasMatch(normalized)) {
      throw const ApiException('消息事件标识不正确');
    }
    return normalized;
  }

  bool _decodeOptionalNotificationMutation(http.Response response) {
    if (_isOptionalNotificationEndpointUnavailableResponse(response)) {
      return false;
    }
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        response.body.trim().isEmpty) {
      return true;
    }
    try {
      _decode(response);
      return true;
    } on ApiException catch (error) {
      if (_isOptionalNotificationEndpointUnavailable(error.statusCode)) {
        return false;
      }
      rethrow;
    }
  }

  int? _notificationUnreadCount(Map<String, Object?> payload) {
    final data = payload['data'];
    final directValue = switch (data) {
      Map<Object?, Object?> map => map['unread_count'] ?? map['count'],
      num value => value,
      String value => value,
      _ => payload['unread_count'],
    };
    final directCount = _notificationCountValue(directValue);
    if (directCount != null) return directCount;
    if (data is! Map<Object?, Object?>) return null;

    final hasAnnounceCount = data.containsKey('announce_count');
    final hasRemindCount = data.containsKey('remind_count');
    if (!hasAnnounceCount && !hasRemindCount) return null;
    final announceCount = hasAnnounceCount
        ? _notificationCountValue(data['announce_count'])
        : 0;
    final remindCount = hasRemindCount
        ? _notificationCountValue(data['remind_count'])
        : 0;
    if (announceCount == null || remindCount == null) return null;
    return announceCount + remindCount;
  }

  int? _notificationCountValue(Object? value) => switch (value) {
    int count when count >= 0 => count,
    num count when count.isFinite && count == count.toInt() && count >= 0 =>
      count.toInt(),
    String count => switch (int.tryParse(count.trim())) {
      final parsed? when parsed >= 0 => parsed,
      _ => null,
    },
    _ => null,
  };

  bool _isOptionalNotificationEndpointUnavailable(int? statusCode) =>
      statusCode == 404 || statusCode == 405;

  bool _isOptionalNotificationEndpointUnavailableResponse(
    http.Response response,
  ) {
    if (_isOptionalNotificationEndpointUnavailable(response.statusCode)) {
      return true;
    }
    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map) return false;
      final rawCode = payload['code'];
      final code = switch (rawCode) {
        int value => value,
        num value when value.isFinite && value == value.toInt() =>
          value.toInt(),
        String value => int.tryParse(value.trim()),
        _ => null,
      };
      return _isOptionalNotificationEndpointUnavailable(code);
    } on FormatException {
      return false;
    }
  }

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
      final current = await _vault.readSession();
      if (current == null ||
          current.accessToken != refreshed.accessToken ||
          current.memberId != refreshed.memberId ||
          current.accountKey != refreshed.accountKey) {
        return response;
      }
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
    final chinaDayStart = _chinaDayStartEpochSeconds(day);
    if (chinaDayStart == null) return const [];
    final date = '$chinaDayStart';
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

int? _chinaDayStartEpochSeconds(String day) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final dayOfMonth = int.parse(match.group(3)!);
  final utcCalendarDay = DateTime.utc(year, month, dayOfMonth);
  if (utcCalendarDay.year != year ||
      utcCalendarDay.month != month ||
      utcCalendarDay.day != dayOfMonth) {
    return null;
  }
  final chinaMidnightUtc = utcCalendarDay.subtract(const Duration(hours: 8));
  return chinaMidnightUtc.millisecondsSinceEpoch ~/ 1000;
}
