part of 'api_client.dart';

abstract interface class OnlineSupportApi {
  Future<Map<String, Object?>> supportRequest(
    String path, {
    Session? member,
    String? guestToken,
    Map<String, String>? query,
    Map<String, Object?>? body,
    Uint8List? photo,
    Future<void>? stop,
  });
  Stream<Map<String, Object?>> supportEvents(
    String conversation,
    int after, {
    Session? member,
    String? guestToken,
    required Future<void> stop,
  });
  Future<Uint8List> supportPhoto(
    String conversation,
    String attachment, {
    Session? member,
    String? guestToken,
    required Future<void> stop,
  });
}

mixin OnlineSupportTransport on SaydianApiClient implements OnlineSupportApi {
  String Function() get _locale;

  static const _prefix = '/api/saydian-app/v2/support';
  static final _id = RegExp(r'^[0-9a-fA-F-]{36}$');
  static final _path = RegExp(
    r'^(online-config|faq(?:/[0-9a-fA-F-]{36})?|guest|conversations(?:/[0-9a-fA-F-]{36}(?:/(?:events|messages|claim|read|handoff|diagnostic|attachments(?:/[0-9a-fA-F-]{36})?))?)?)$',
  );

  Future<Session?> _supportSession(Session? expected) async {
    if (expected == null) return null;
    final current = await _vault.readSession();
    if (current == null ||
        _stableSessionAccountKey(current) !=
            _stableSessionAccountKey(expected)) {
      throw const ApiException(
        'Account changed.',
        code: 'SUPPORT_OWNER_CHANGED',
      );
    }
    return current;
  }

  Future<http.StreamedResponse> _supportSend(
    http.BaseRequest Function(Map<String, String>) build, {
    required Session? member,
    required String? guestToken,
  }) async {
    Map<String, String> headers(Session? session) => {
      'Accept-Language': _locale(),
      if (session != null)
        'Authorization': 'Bearer ${session.accessToken}'
      else if (guestToken != null &&
          RegExp(r'^srguest\.[A-Za-z0-9_-]{32,120}$').hasMatch(guestToken))
        'Authorization': 'Bearer $guestToken',
    };
    var session = await _supportSession(member);
    Future<http.StreamedResponse> send() => _performRequest(
      () => _client.send(build(headers(session))..followRedirects = false),
    );
    var response = await send();
    if (response.statusCode == 401 &&
        session != null &&
        session.refreshToken.isNotEmpty) {
      await response.stream.drain<void>();
      // Reuse the ordinary single-flight refresh, only for this same member.
      await refreshSession(session);
      session = await _supportSession(member);
      response = await send();
    }
    return response;
  }

  @override
  Future<Map<String, Object?>> supportRequest(
    String path, {
    Session? member,
    String? guestToken,
    Map<String, String>? query,
    Map<String, Object?>? body,
    Uint8List? photo,
    Future<void>? stop,
  }) async {
    if (!_path.hasMatch(path) ||
        (photo != null &&
            (!path.endsWith('/attachments') ||
                photo.length > 5 * 1024 * 1024))) {
      throw const ApiException('Invalid support request.');
    }
    final uri = _uri('$_prefix/$path', query);
    final response = await _supportSend(
      (headers) {
        if (photo != null) {
          return http.AbortableMultipartRequest('POST', uri, abortTrigger: stop)
            ..headers.addAll(headers)
            ..fields['clientMessageId'] = '${body?['clientMessageId']}'
            ..fields['body'] = '${body?['body'] ?? ''}'
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                photo,
                filename: 'photo',
                contentType: http_parser.MediaType(
                  'application',
                  'octet-stream',
                ),
              ),
            );
        }
        final request = http.AbortableRequest(
          body == null ? 'GET' : 'POST',
          uri,
          abortTrigger: stop,
        )..headers.addAll(headers);
        if (body != null) {
          request.headers['Content-Type'] = 'application/json';
          request.body = jsonEncode(body);
        }
        return request;
      },
      member: member,
      guestToken: guestToken,
    );
    return _data(
      _decode(await _performRequest(() => http.Response.fromStream(response))),
    );
  }

  @override
  Stream<Map<String, Object?>> supportEvents(
    String conversation,
    int after, {
    Session? member,
    String? guestToken,
    required Future<void> stop,
  }) async* {
    if (!_id.hasMatch(conversation) || after < 0) return;
    final uri = _uri('$_prefix/conversations/$conversation/events', {
      'after': '$after',
    });
    final response = await _supportSend(
      (headers) => http.AbortableRequest('GET', uri, abortTrigger: stop)
        ..headers.addAll(headers)
        ..headers['Accept'] = 'text/event-stream',
      member: member,
      guestToken: guestToken,
    );
    if (response.statusCode != 200 ||
        response.headers['content-type']?.startsWith('text/event-stream') !=
            true) {
      final status = response.statusCode;
      await response.stream.drain<void>();
      throw ApiException('Support connection unavailable.', statusCode: status);
    }
    await for (final line
        in response.stream
            .timeout(const Duration(seconds: 32))
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.length > 480000) {
        throw const FormatException('Support event is too large.');
      }
      if (!line.startsWith('data: ')) continue;
      final value = jsonDecode(line.substring(6));
      if (value is Map<String, Object?>) yield value;
    }
  }

  @override
  Future<Uint8List> supportPhoto(
    String conversation,
    String attachment, {
    Session? member,
    String? guestToken,
    required Future<void> stop,
  }) async {
    if (!_id.hasMatch(conversation) || !_id.hasMatch(attachment)) {
      throw const ApiException('Photo unavailable.');
    }
    final uri = _uri(
      '$_prefix/conversations/$conversation/attachments/$attachment',
    );
    final response = await _supportSend(
      (headers) =>
          http.AbortableRequest('GET', uri, abortTrigger: stop)
            ..headers.addAll(headers),
      member: member,
      guestToken: guestToken,
    );
    if (response.statusCode != 200 ||
        response.headers['content-type']?.startsWith('image/jpeg') != true) {
      await response.stream.drain<void>();
      throw const ApiException('Photo unavailable.');
    }
    final result = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 12),
    )) {
      if (result.length + chunk.length > 5 * 1024 * 1024) {
        throw const FormatException('Photo is too large.');
      }
      result.add(chunk);
    }
    return result.takeBytes();
  }
}

class SupportGuestSession {
  const SupportGuestSession({
    required this.token,
    required this.conversation,
    required this.expiresAt,
    this.claimed = false,
  });
  final String token, conversation;
  final DateTime expiresAt;
  final bool claimed;
  bool get expired => !expiresAt.isAfter(DateTime.now());
  Map<String, Object?> toJson() => {
    'token': token,
    'conversation': conversation,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    if (claimed) 'claimed': true,
  };
  static SupportGuestSession? tryParse(Map<String, Object?> input) {
    final token = input['token'];
    final row = input['conversation'];
    final conversation = row is Map ? row['id'] : row;
    final expiry = DateTime.tryParse('${input['expiresAt']}');
    if (token is! String ||
        !RegExp(r'^srguest\.[A-Za-z0-9_-]{32,120}$').hasMatch(token) ||
        conversation is! String ||
        !OnlineSupportTransport._id.hasMatch(conversation) ||
        expiry == null) {
      return null;
    }
    return SupportGuestSession(
      token: token,
      conversation: conversation,
      expiresAt: expiry,
      claimed: input['claimed'] == true,
    );
  }
}
