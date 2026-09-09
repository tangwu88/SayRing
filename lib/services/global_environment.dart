import 'dart:convert';

import 'package:crypto/crypto.dart';

/// First-party App V2 endpoints. Paths never fall back to legacy API routes.
abstract final class GlobalEnvironment {
  static const origin = 'https://app.saydian.cn';
  static const apiPrefix = '/global/api/saydian-app/v2';
  static const canonicalApiPrefix = '/api/saydian-app/v2';
  static String get storageNamespace => sha256
      .convert(utf8.encode('${configuredOrigin.origin}$apiPrefix'))
      .toString();

  /// Canonical controller paths are mounted only on the isolated gateway.
  static String deployedPath(String path) =>
      path == canonicalApiPrefix || path.startsWith('$canonicalApiPrefix/')
      ? '$apiPrefix${path.substring(canonicalApiPrefix.length)}'
      : path;
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

  static Uri apiOrigin(Uri? override) => override == null
      ? configuredOrigin
      : validateOrigin(
          override.toString(),
          allowLocalDebug: const bool.fromEnvironment(
            'SAYDIAN_ALLOW_LOCAL_DEBUG_API',
          ),
          isProduct: const bool.fromEnvironment('dart.vm.product'),
        );

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
    final production =
        uri.scheme == 'https' &&
        uri.host == 'app.saydian.cn' &&
        uri.port == 443;
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
    if (!safeResourcePath(resolved)) {
      throw ArgumentError('Path traversal is not accepted');
    }
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
      return allowsFirstPartyResource(uri) ? uri.toString() : '';
    }
    try {
      if (uri.path.startsWith('/global/media/') ||
          uri.path.startsWith('/global/assets/')) {
        // Check the original path before URI resolution can normalize traversal.
        final rawPath = input.trim().split(RegExp(r'[?#]')).first;
        if (!_safePath(rawPath) || !safeResourcePath(uri)) return '';
        final resolved = configuredOrigin.resolveUri(uri);
        return allowsFirstPartyResource(resolved) ? resolved.toString() : '';
      }
      return resolve(configuredOrigin, deployedPath(input.trim())).toString();
    } on ArgumentError {
      return '';
    }
  }

  static bool safeResourcePath(Uri uri) {
    if (uri.userInfo.isNotEmpty || uri.hasFragment) return false;
    return _safePath(uri.path);
  }

  static bool _safePath(String path) {
    for (var round = 0; round < 4; round++) {
      if (path.contains('\\') ||
          path.split('/').any((part) => part == '.' || part == '..')) {
        return false;
      }
      if (!path.contains('%')) return true;
      try {
        final next = Uri.decodeComponent(path);
        if (next == path) return true;
        path = next;
      } on FormatException {
        return false;
      }
    }
    return false;
  }

  static bool allowsFirstPartyResource(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.origin == configuredOrigin.origin &&
      safeResourcePath(uri) &&
      (uri.path.startsWith('$apiPrefix/') ||
          uri.path.startsWith('/global/media/') ||
          uri.path.startsWith('/global/assets/'));
}
