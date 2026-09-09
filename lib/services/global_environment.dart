/// First-party App V2 endpoints. Paths never fall back to legacy API routes.
abstract final class GlobalEnvironment {
  static const origin = 'https://app.saydian.cn';
  static const apiPrefix = '/api/saydian-app/v2';
  static const locales = [
    'en',
    'zh-Hans',
    'zh-Hant',
    'de',
    'fr',
    'es',
    'ja',
    'ko',
  ];
  static const packageId = 'cn.saydian.app.global';

  static Uri get configuredOrigin {
    const raw = String.fromEnvironment(
      'SAYDIAN_API_BASE_URL',
      defaultValue: origin,
    );
    return validateOrigin(
      raw,
      allowLocalDebug: const bool.fromEnvironment(
        'SAYDIAN_ALLOW_LOCAL_DEBUG_API',
      ),
      isProduct: const bool.fromEnvironment('dart.vm.product'),
    );
  }

  static Uri validateOrigin(
    String raw, {
    required bool allowLocalDebug,
    required bool isProduct,
  }) {
    final uri = Uri.parse(raw);
    final localDebug =
        !isProduct &&
        allowLocalDebug &&
        uri.scheme == 'http' &&
        {'10.0.2.2', '127.0.0.1', 'localhost'}.contains(uri.host) &&
        uri.hasPort;
    final production = uri.scheme == 'https' && uri.host == 'app.saydian.cn';
    if ((!production && !localDebug) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path != '' && uri.path != '/')) {
      throw ArgumentError(
        'SAYDIAN_API_BASE_URL must use the approved production origin',
      );
    }
    return uri;
  }

  static Uri resolve(Uri origin, String path, [Map<String, String>? query]) {
    final decodedPath = Uri.decodeComponent(path.split(RegExp(r'[?#]')).first);
    if (decodedPath
            .split('/')
            .any((segment) => segment == '..' || segment == '.') ||
        decodedPath.contains('\\')) {
      throw ArgumentError('Path traversal is not accepted');
    }
    final relative = Uri.parse(path);
    if (relative.hasScheme ||
        relative.hasAuthority ||
        relative.pathSegments.contains('..')) {
      throw ArgumentError('Only relative first-party paths are accepted');
    }
    final normalizedPath = '/${relative.path.replaceFirst(RegExp(r'^/+'), '')}';
    if (normalizedPath != apiPrefix &&
        !normalizedPath.startsWith('$apiPrefix/')) {
      throw ArgumentError('App V2 API path required');
    }
    final normalized = relative.replace(path: normalizedPath);
    final result = origin.resolveUri(normalized);
    final resolved = query == null
        ? result
        : result.replace(queryParameters: query);
    if (resolved.path != apiPrefix &&
        !resolved.path.startsWith('$apiPrefix/')) {
      throw ArgumentError('App V2 API path required');
    }
    return resolved;
  }

  static String media(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || input.trim().isEmpty) return '';
    if (uri.hasScheme || uri.hasAuthority) {
      if ({'sd.cc', 'app.saidian.cc'}.contains(uri.host)) return '';
      if (uri.host == 'app.saydian.cn' &&
          uri.path != apiPrefix &&
          !uri.path.startsWith('$apiPrefix/')) {
        return '';
      }
      return uri.scheme == 'https' ? uri.toString() : '';
    }
    try {
      return resolve(Uri.parse(origin), input.trim()).toString();
    } on ArgumentError {
      return '';
    }
  }
}
