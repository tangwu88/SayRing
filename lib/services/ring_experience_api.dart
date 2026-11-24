part of 'api_client.dart';

abstract interface class RingExperienceApi {
  Future<Map<String, Object?>> readRingCapabilities();

  Future<Map<String, Object?>> requestRing(
    Session expected,
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? data,
  });

  Future<Uint8List> readRingBytes(Session expected, String path, int maxBytes);
}

mixin RingExperienceTransport on SaydianApiClient implements RingExperienceApi {
  static const _root = '/api/saydian-app/v2/ring/';

  @override
  Future<Map<String, Object?>> readRingCapabilities() async {
    final request = http.Request('GET', _uri('${_root}capabilities'))
      ..followRedirects = false;
    final response = await _performRequest(
      () async => http.Response.fromStream(await _client.send(request)),
    );
    return _data(_decode(response));
  }

  String _ringPath(String value) {
    if (!RegExp(r'^[a-zA-Z0-9-]+(?:/[a-zA-Z0-9-]+)*$').hasMatch(value)) {
      throw const ApiException('无效的操作');
    }
    return _root + value;
  }

  @override
  Future<Map<String, Object?>> requestRing(
    Session expected,
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? data,
  }) async {
    final owner = _stableSessionAccountKey(expected);
    final response = await _withAuthorizationRetry((session) async {
      if (_stableSessionAccountKey(session) != owner) {
        throw const ApiException('账号已变化，请重新打开');
      }
      final headers = _authorizationHeaders(session);
      final uri = _uri(_ringPath(path), query);
      final request = http.Request(method, uri)
        ..followRedirects = false
        ..headers.addAll(headers);
      if (data != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(data);
      }
      final result = await _performRequest(
        () async => http.Response.fromStream(await _client.send(request)),
      );
      await _checkCareRequestOwner(owner);
      return result;
    });
    await _checkCareRequestOwner(owner);
    return _data(_decode(response));
  }

  @override
  Future<Uint8List> readRingBytes(
    Session expected,
    String path,
    int maxBytes,
  ) async {
    final owner = _stableSessionAccountKey(expected);
    final response = await _withAuthorizationRetry((session) async {
      if (_stableSessionAccountKey(session) != owner) {
        throw const ApiException('账号已变化，请重新打开');
      }
      final request = http.Request('GET', _uri(_ringPath(path)))
        ..followRedirects = false
        ..headers.addAll(_authorizationHeaders(session));
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final builder = BytesBuilder(copy: false);
      if (streamed.statusCode == 200 &&
          (streamed.contentLength ?? maxBytes) <= maxBytes) {
        await for (final chunk in streamed.stream.timeout(
          const Duration(seconds: 15),
        )) {
          if (builder.length + chunk.length > maxBytes) {
            throw const ApiException('文件超出允许大小');
          }
          builder.add(chunk);
        }
      } else {
        await streamed.stream.listen(null).cancel();
      }
      await _checkCareRequestOwner(owner);
      return http.Response.bytes(builder.takeBytes(), streamed.statusCode);
    });
    await _checkCareRequestOwner(owner);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw const ApiException('暂时无法读取文件');
    }
    return response.bodyBytes;
  }
}
