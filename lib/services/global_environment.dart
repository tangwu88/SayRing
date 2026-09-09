/// First-party global endpoints. Paths never fall back to the domestic origin.
abstract final class GlobalEnvironment {
  static const origin = 'https://app.saydian.cn';
  static const prefix = '/global';
  static const apiPrefix = '/global/api/saydian-app/v2';
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
    final uri = Uri.parse(raw);
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.host != 'app.saydian.cn' ||
        (uri.path != '' && uri.path != '/')) {
      throw ArgumentError(
        'SAYDIAN_API_BASE_URL must be https://app.saydian.cn',
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
    final globalPath = path.startsWith('$prefix/')
        ? path
        : '$prefix/${path.replaceFirst(RegExp(r'^/+'), '')}';
    final result = origin.resolve(globalPath).replace(queryParameters: query);
    if (!result.path.startsWith('$prefix/')) {
      throw ArgumentError('Global path required');
    }
    return result;
  }

  static String media(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || input.trim().isEmpty) return '';
    if (uri.hasScheme || uri.hasAuthority) {
      if ({'sd.cc', 'app.saidian.cc'}.contains(uri.host)) return '';
      if (uri.host == 'app.saydian.cn' && !uri.path.startsWith('$prefix/')) {
        return '';
      }
      return uri.scheme == 'https' ? uri.toString() : '';
    }
    return resolve(Uri.parse(origin), input.trim()).toString();
  }
}
