part of 'api_client.dart';

abstract interface class GlobalAccountApi {
  Future<GlobalAuthCapabilities> getAuthCapabilities();
  Future<Map<String, Object?>> getGlobalLegalDocument(String path);
  Future<VerificationChallenge> requestVerification({
    required GlobalAccountIdentity identity,
    required String purpose,
    required String locale,
  });
  Future<Session> completeVerification({
    required String challengeId,
    required String code,
    required String password,
    required bool resetPassword,
    required String locale,
    String? nickname,
    String? consentVersion,
  });
}

abstract interface class GlobalCareApi {
  Future<List<GlobalCareRelationship>> globalCareRelationships();
  Future<void> globalInviteCare(String identifier);
  Future<void> globalRespondCare(String id, bool accepted);
  Future<void> globalShareCare(String id, Set<String> metrics);
  Future<void> globalRevokeCare(String id);
  Future<List<Map<String, Object?>>> globalCareRecords(
    String id,
    String metric,
    DateTime day,
  );
}

abstract interface class GlobalContentApi {
  Future<List<Map<String, Object?>>> getGlobalArticleCategories();
  Future<List<Map<String, Object?>>> getGlobalArticles({
    String? categoryId,
    int page = 1,
  });
  Future<Map<String, Object?>> getGlobalArticle(String id);
}

/// International transport. Only the deployed App V2 route family is accepted;
/// no legacy endpoint or credential fallback exists.
class GlobalSaydianApiClient extends SaydianApiClient
    with GlobalHealthApi
    implements GlobalAccountApi, GlobalCareApi, GlobalContentApi {
  GlobalSaydianApiClient(
    super.vault, {
    http.Client? client,
    Uri? baseUri,
    String Function()? locale,
  }) : _locale = locale ?? (() => 'en'),
       super(
         baseUri: baseUri ?? GlobalEnvironment.configuredOrigin,
         client: _GlobalHttpClient(
           client ?? http.Client(),
           baseUri ?? GlobalEnvironment.configuredOrigin,
         ),
       );

  final String Function() _locale;

  @override
  List<Map<String, Object?>> _list(Map<String, Object?> payload) {
    final data = payload['data'];
    final values = data is List
        ? data
        : data is Map
        ? (data['items'] ?? data['list'])
        : null;
    if (values is! List) {
      throw const ApiException('Unable to read this list. Please try again.');
    }
    return values
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  Future<Map<String, Object?>> _publicContent(
    String path, [
    Map<String, String>? query,
  ]) async => _decode(
    await _performRequest(
      () => _client.get(
        _uri('/api/saydian-app/v2/content/$path', {
          'locale': _locale(),
          ...?query,
        }),
        headers: {'Accept-Language': _locale()},
      ),
    ),
  );

  @override
  Future<List<Map<String, Object?>>> getGlobalArticleCategories() async =>
      _list(await _publicContent('categories'));

  @override
  Future<List<Map<String, Object?>>> getGlobalArticles({
    String? categoryId,
    int page = 1,
  }) async =>
      _list(
            await _publicContent('articles', {
              'categoryId': ?categoryId,
              'page': '$page',
              'pageSize': '30',
            }),
          )
          .map(
            (row) => <String, Object?>{
              ...row,
              'cover': _absoluteMediaUrl('${row['coverUrl'] ?? ''}'),
            },
          )
          .toList();

  @override
  Future<Map<String, Object?>> getGlobalArticle(String id) async {
    if (id.trim().isEmpty) throw const ApiException('Choose an article first.');
    final data = _data(
      await _publicContent('articles/${Uri.encodeComponent(id)}'),
    );
    return {
      ...data,
      'cover': _absoluteMediaUrl('${data['coverUrl'] ?? ''}'),
      'content': data['contentHtml'],
    };
  }

  @override
  Future<List<Map<String, Object?>>> getArticles() => getGlobalArticles();

  @override
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  }) async {
    final conversationId = 'saydian-global-$app';
    final conversations = _list(
      _decode(
        await _authorizedGet('/api/saydian-app/v2/ai/messages', {
          'sessionId': conversationId,
        }),
      ),
    );
    final rows = <Map<String, Object?>>[];
    for (final conversation in conversations) {
      final messages = conversation['messages'];
      if (messages is! List) continue;
      for (final message in messages.whereType<Map>()) {
        rows.add({
          ...message.cast<String, Object?>(),
          'message': message['content'],
          'my': message['role'] == 'user' ? 1 : 0,
          'session_id': conversationId,
        });
      }
    }
    // Legacy controller expects newest first, then reverses for display.
    return rows.reversed.toList();
  }

  @override
  Future<Map<String, Object?>> sendAiMessage({
    required int app,
    required String message,
    String? sessionId,
  }) async {
    final conversationId = sessionId?.isNotEmpty == true
        ? sessionId!
        : 'saydian-global-$app';
    final data = _data(
      _decode(
        await _authorizedPostJsonWithTimeout(
          '/api/saydian-app/v2/ai/messages',
          {
            'content': message.trim(),
            'sessionId': conversationId,
            'locale': _locale(),
          },
          SaydianApiClient._aiReplyTimeout,
        ),
      ),
    );
    return {
      ...data,
      'message': data['content'],
      'my': 0,
      'session_id': conversationId,
    };
  }

  @override
  Future<String> submitFeedback({
    required String category,
    required String content,
    String contact = '',
  }) async {
    final data = _data(
      _decode(
        await _authorizedPostJson('/api/saydian-app/v2/support/feedback', {
          'category': category,
          'content': content,
          'contact': contact,
        }),
      ),
    );
    final id = data['id'];
    if (id is! String || id.isEmpty) {
      throw const ApiException('Unable to send feedback. Please try again.');
    }
    return id;
  }

  String _carePath(String id, [String suffix = '']) {
    if (id.trim().isEmpty) {
      throw const ApiException('No care member was selected.');
    }
    return '/api/saydian-app/v2/care/relationships/${Uri.encodeComponent(id)}$suffix';
  }

  Future<List<Map<String, Object?>>> _globalRelationships() async => _list(
    _decode(await _authorizedGet('/api/saydian-app/v2/care/relationships')),
  );

  @override
  Future<List<GlobalCareRelationship>> globalCareRelationships() async =>
      (await _globalRelationships())
          .map(GlobalCareRelationship.fromJson)
          .toList(growable: false);

  @override
  Future<List<Map<String, Object?>>> getCareMembers() async =>
      (await _globalRelationships())
          .where(
            (row) => row['status'] == 'active' && row['direction'] == 'sent',
          )
          .map(
            (row) => <String, Object?>{
              ...row,
              'member_id': row['recipientMemberId'],
              'nickname': row['recipient'] is Map
                  ? (row['recipient'] as Map)['nickname']
                  : null,
            },
          )
          .toList();

  @override
  Future<List<Map<String, Object?>>> getCareInvitations() async =>
      (await _globalRelationships())
          .where((row) => row['direction'] == 'received')
          .map(
            (row) => <String, Object?>{
              ...row,
              'examine_status': switch (row['status']) {
                'pending' => 0,
                'active' => 1,
                _ => 2,
              },
            },
          )
          .toList();

  @override
  Future<void> globalInviteCare(String identifier) async {
    final identity = GlobalAccountIdentity.parse(identifier);
    _decode(
      await _authorizedPostJson('/api/saydian-app/v2/care/invitations', {
        'identifier': identity.identifier,
      }),
    );
  }

  @override
  Future<void> globalRespondCare(String id, bool accepted) async {
    _decode(
      await _authorizedPostJson(_carePath(id, '/respond'), {
        'accepted': accepted,
      }),
    );
  }

  @override
  Future<void> globalShareCare(String id, Set<String> metrics) async {
    _decode(
      await _authorizedPostJson(_carePath(id, '/permissions'), {
        'metrics': metrics.toList(),
      }),
    );
  }

  @override
  Future<void> globalRevokeCare(String id) async {
    _decode(await _authorizedDelete(_carePath(id)));
  }

  @override
  Future<List<Map<String, Object?>>> globalCareRecords(
    String id,
    String metric,
    DateTime day,
  ) async {
    final range = globalLocalDayRange(day);
    return _list(
      _decode(
        await _authorizedGet(_carePath(id, '/health'), {
          'metric': metric,
          'from': range.from.toIso8601String(),
          'to': range.to.toIso8601String(),
        }),
      ),
    );
  }

  @override
  Uri _uri(String path, [Map<String, String>? query]) =>
      GlobalEnvironment.resolve(_baseUri, path, query);

  @override
  Map<String, String> _authorizationHeaders(Session session) => {
    'Authorization': 'Bearer ${session.accessToken}',
    'Accept-Language': _locale(),
  };

  @override
  String _absoluteMediaUrl(String value) => GlobalEnvironment.media(value);

  @override
  Map<String, Object?> _normalizeArticle(Map<String, Object?> article) => {
    ...article,
    if (article['cover'] is String)
      'cover': _absoluteMediaUrl(article['cover'] as String),
  };

  @override
  Map<String, Object?> _decode(http.Response response) {
    try {
      return super._decode(response);
    } on ApiException catch (error) {
      String? key;
      try {
        final json = jsonDecode(response.body);
        if (json is Map && json['errorKey'] is String) {
          key = json['errorKey'] as String;
        }
      } on FormatException {
        /* Never expose raw upstream responses. */
      }
      throw ApiException(
        'This action could not be completed. Please try again.',
        statusCode: error.statusCode,
        code: key ?? error.code,
      );
    }
  }

  @override
  Future<Map<String, Object?>> getMemberProfile() async {
    final data = _data(
      _decode(await _authorizedGet('/api/saydian-app/v2/members/me')),
    );
    return {
      ...data,
      'head_portrait': _absoluteMediaUrl('${data['avatarUrl'] ?? ''}'),
      'gender': switch (data['gender']) {
        'male' => 1,
        'female' => 2,
        _ => 0,
      },
      'height': data['heightCm'],
      'weight': data['weightKg'],
      'mobile': data['phoneMasked'],
      'email': data['emailMasked'],
    };
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
    _decode(
      await _authorizedPutJson('/api/saydian-app/v2/members/me', {
        'nickname': nickname.trim(),
        'gender': switch (gender) {
          1 => 'male',
          2 => 'female',
          _ => 'unspecified',
        },
        if (birthday.isNotEmpty) 'birthday': birthday,
        'heightCm': height,
        'weightKg': weight,
        if (headPortrait != null && headPortrait.isNotEmpty)
          'avatarUrl': headPortrait,
        'locale': _locale(),
      }),
    );
  }

  @override
  Future<Map<String, Object?>> getActivityGoals() async {
    final data = _data(
      _decode(await _authorizedGet('/api/saydian-app/v2/members/me/goals')),
    );
    return {
      'steps': data['steps'],
      'reliang': data['caloriesKcal'],
      'juli': data['distanceMeters'] is num
          ? (data['distanceMeters'] as num) / 1000
          : null,
    };
  }

  @override
  Future<void> saveActivityGoals({
    required int steps,
    required double distance,
    required int calories,
  }) async {
    _decode(
      await _authorizedPutJson('/api/saydian-app/v2/members/me/goals', {
        'steps': steps,
        'distanceMeters': (distance * 1000).round(),
        'caloriesKcal': calories,
      }),
    );
  }

  @override
  Future<String> uploadImage(String filePath) async {
    final response = await _withAuthorizationRetry((session) async {
      final request =
          http.MultipartRequest(
              'POST',
              _uri('/api/saydian-app/v2/files', {'purpose': 'avatar'}),
            )
            ..headers.addAll(_authorizationHeaders(session))
            ..fields['purpose'] = 'avatar';
      final extension = filePath.toLowerCase().split('.').last;
      final mime = switch (extension) {
        'jpg' || 'jpeg' => 'jpeg',
        'png' => 'png',
        'webp' => 'webp',
        _ => null,
      };
      if (mime == null) {
        throw const ApiException('Choose a JPG, PNG or WebP image.');
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          contentType: http_parser.MediaType('image', mime),
        ),
      );
      return _sendMultipart(request);
    });
    final data = _data(_decode(response));
    final url = _absoluteMediaUrl('${data['url'] ?? ''}');
    if (url.isEmpty) {
      throw const ApiException('Unable to upload the photo. Please try again.');
    }
    return url;
  }

  @override
  Future<bool> registerPushDevice({
    required String installationId,
    required String registrationId,
    required String platform,
    String? appVersion,
    int? buildNumber,
  }) async {
    final data = _data(
      _decode(
        await _authorizedPostJson(
          '/api/saydian-app/v2/notifications/push-installations',
          {
            'installationId': _validatedInstallationId(installationId),
            'registrationId': registrationId,
            'platform': platform,
            'appVersion': appVersion,
            'buildNumber': buildNumber,
            'locale': _locale(),
          },
        ),
      ),
    );
    return data['registered'] == true;
  }

  @override
  Future<bool> unregisterPushDevice({required String installationId}) async {
    final id = _validatedInstallationId(installationId);
    final data = _data(
      _decode(
        await _authorizedDelete(
          '/api/saydian-app/v2/notifications/push-installations/${Uri.encodeComponent(id)}',
        ),
      ),
    );
    return data['unregistered'] == true;
  }

  @override
  Future<int?> getNotificationUnreadCount() async {
    final data = _data(
      _decode(
        await _authorizedGet('/api/saydian-app/v2/notifications/unread-count'),
      ),
    );
    return _notificationCountValue(data['unreadCount'] ?? data['count']);
  }

  @override
  Future<Session> loginWithWechat({required String code}) => Future.error(
    const FeatureNotConfiguredException(
      'Sign in with your email address or phone number.',
    ),
  );

  @override
  Future<Map<String, Object?>> createShopOrder({
    required List<Map<String, int>> items,
    required int addressId,
    String buyerMessage = '',
    num point = 0,
  }) => Future.error(
    const FeatureNotConfiguredException(
      'Shopping is not yet available in this region.',
    ),
  );

  @override
  Future<Map<String, Object?>> createShopPayment({
    required String provider,
    required int orderId,
    required num money,
  }) => Future.error(
    const FeatureNotConfiguredException(
      'Payments are not yet available in this region.',
    ),
  );

  Future<Map<String, Object?>> _globalPublic(
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final uri = _uri('/api/saydian-app/v2/$path');
    final headers = {
      'Accept-Language': _locale(),
      'Content-Type': 'application/json',
    };
    final response = await _performRequest(
      () => body == null
          ? _client.get(uri, headers: headers)
          : _client.post(uri, headers: headers, body: jsonEncode(body)),
    );
    return _data(_decode(response));
  }

  @override
  Future<GlobalAuthCapabilities> getAuthCapabilities() async =>
      const GlobalAuthCapabilities(
        email: false,
        sms: false,
        recoveryEmail: false,
        recoverySms: false,
        smsCountries: <String>{},
        supportedLocales: GlobalEnvironment.locales,
      );

  @override
  Future<Map<String, Object?>> getGlobalLegalDocument(String path) async {
    final parsed = Uri.parse(path);
    if (parsed.hasScheme ||
        parsed.hasAuthority ||
        !parsed.path.startsWith('/api/saydian-app/v2/content/legal/') ||
        parsed.pathSegments.contains('..')) {
      throw const ApiException('This document is not available.');
    }
    return _globalPublic(path.substring('/api/saydian-app/v2/'.length));
  }

  @override
  Future<VerificationChallenge> requestVerification({
    required GlobalAccountIdentity identity,
    required String purpose,
    required String locale,
  }) async {
    if (!{'register', 'reset_password'}.contains(purpose)) {
      throw const ApiException(
        'This action is not available.',
        code: 'INVALID_PURPOSE',
      );
    }
    throw const FeatureNotConfiguredException(
      'Verification is not available for this contact yet.',
    );
  }

  @override
  Future<Session> login(String username, String password) async {
    final identity = GlobalAccountIdentity.parse(username);
    return _globalAuthenticate('auth/login', {
      if (identity.channel == AccountChannel.email)
        'username': identity.identifier
      else
        'mobile': identity.identifier,
      'password': password,
    });
  }

  @override
  Future<Session> register(String mobile, String password) => Future.error(
    const ApiException(
      'Verify your email or phone number first.',
      code: 'VERIFICATION_REQUIRED',
    ),
  );

  // Legacy deep links must never bypass the purpose-bound global challenge.
  @override
  Future<void> sendSmsCode({required String mobile, required String usage}) =>
      Future.error(
        const ApiException(
          'Use the international sign-in page to verify your contact.',
          code: 'VERIFICATION_REQUIRED',
        ),
      );

  @override
  Future<Session> registerWithSms({
    required String mobile,
    required String code,
    required String password,
    required String nickname,
  }) => register(mobile, password);

  @override
  Future<Session> resetPassword({
    required String mobile,
    required String code,
    required String password,
  }) => register(mobile, password);

  @override
  Future<Session> completeVerification({
    required String challengeId,
    required String code,
    required String password,
    required bool resetPassword,
    required String locale,
    String? nickname,
    String? consentVersion,
  }) => Future.error(
    const FeatureNotConfiguredException(
      'Verification is not available for this contact yet.',
    ),
  );

  Future<Session> _globalAuthenticate(
    String path,
    Map<String, Object?> body, {
    Session? expectedSession,
  }) async {
    final data = await _globalPublic(path, body);
    final member = data['member'];
    final id = member is Map ? member['id'] : null;
    final access = data['accessToken'];
    final refresh = data['refreshToken'];
    final expiry = DateTime.tryParse('${data['expiresAt'] ?? ''}');
    if (id is! String ||
        id.trim().isEmpty ||
        access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        expiry == null) {
      throw const ApiException(
        'Unable to sign in. Please try again.',
        code: 'AUTH_IDENTITY_MISSING',
      );
    }
    final session = Session(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiry.toUtc(),
      memberId: id,
      displayName: '${(member as Map)['nickname'] ?? 'Saydian user'}',
      accountKey: 'global:member:$id',
    );
    if (expectedSession == null) {
      await _vault.writeSession(session);
    } else {
      if (expectedSession.memberId != id ||
          !await _vault.writeSessionIfUnchanged(expectedSession, session)) {
        throw const ApiException(
          'Your account has changed. Please try again.',
          code: 'STALE_SESSION_REFRESH',
        );
      }
    }
    return session;
  }

  @override
  Future<Session> refreshSession(Session session) {
    final key = 'global:${session.memberId}';
    final pending = _refreshingSessions[key];
    if (pending != null) return pending;
    final request = _globalAuthenticate('auth/refresh', {
      'refreshToken': session.refreshToken,
    }, expectedSession: session);
    _refreshingSessions[key] = request;
    return request.whenComplete(() {
      if (identical(_refreshingSessions[key], request)) {
        _refreshingSessions.remove(key);
      }
    });
  }

  @override
  Future<void> logout() async {
    try {
      _decode(
        await _withAuthorizationRetry(
          (session) => _performRequest(
            () => _client.post(
              _uri('/api/saydian-app/v2/auth/logout'),
              headers: _authorizationHeaders(session),
            ),
          ),
        ),
      );
    } finally {
      await _vault.clearSession();
    }
  }

  @override
  Future<void> deleteAccount() async {
    _decode(
      await _authorizedPostJson(
        '/api/saydian-app/v2/auth/delete-account',
        const {'confirm': true},
      ),
    );
    await _vault.clearSession();
  }
}

/// Never follow first-party redirects into another account environment.
class _GlobalHttpClient extends http.BaseClient {
  _GlobalHttpClient(this.inner, this.origin);
  final http.Client inner;
  final Uri origin;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != origin.origin ||
        request.url.userInfo.isNotEmpty ||
        (request.url.path != GlobalEnvironment.apiPrefix &&
            !request.url.path.startsWith('${GlobalEnvironment.apiPrefix}/'))) {
      throw const ApiException(
        'This service is not available.',
        code: 'GLOBAL_ENDPOINT_REJECTED',
      );
    }
    request.followRedirects = false;
    final response = await inner.send(request);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      await response.stream.drain<void>();
      throw const ApiException(
        'This service is not available.',
        code: 'GLOBAL_REDIRECT_REJECTED',
      );
    }
    return response;
  }

  @override
  void close() => inner.close();
}
