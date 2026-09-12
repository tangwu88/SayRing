part of 'app_update_service.dart';

/// International manifests are opt-in, package-bound and never use legacy URLs.
class GlobalAppUpdateService extends AppUpdateService {
  GlobalAppUpdateService({
    super.client,
    super.targetPlatform,
    super.packageInfoLoader,
  }) : super(
         endpointUri: Uri.parse(
           '${GlobalEnvironment.origin}${GlobalEnvironment.apiPrefix}/support/app-update',
         ).replace(
           queryParameters: {'product': GlobalEnvironment.productId},
         ),
       );

  @override
  Future<AppUpdateInfo> check() async {
    final package = await loadCurrentPackage();
    final platform = switch (_targetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => throw const AppUpdateException(
        'Updates are unavailable on this device.',
      ),
    };
    if (package.packageName != GlobalEnvironment.packageId) {
      throw const AppUpdateException('This update is not for this app.');
    }
    final http.Response response;
    try {
      final request = http.Request('GET', _endpointUri!)
        ..followRedirects = false;
      NetworkAudit.record(
        request.url,
        request.method,
        'update_manifest',
        outcome: 'request_started',
      );
      final streamed = await _client.send(request).timeout(_requestTimeout);
      NetworkAudit.record(
        request.url,
        request.method,
        'update_manifest',
        status: streamed.statusCode,
        requestId: streamed.headers['x-request-id'],
      );
      response = await http.Response.fromStream(
        streamed,
      ).timeout(_requestTimeout);
    } catch (_) {
      throw const AppUpdateException('Check your connection and try again.');
    }
    if (response.statusCode != 200) {
      throw const AppUpdateException(
        'Updates are not available yet. Please try again later.',
      );
    }
    final Map manifest;
    try {
      final root = jsonDecode(response.body);
      if (root is! Map || root['code'] != 200 || root['data'] is! Map) {
        throw const FormatException();
      }
      manifest = root['data'] as Map;
    } catch (_) {
      throw const AppUpdateException(
        'Unable to check for updates. Please try again later.',
      );
    }
    if (manifest['realm'] != 'global' ||
        manifest['schemaVersion'] != 1 ||
        manifest['audience'] != 'internal_test' ||
        manifest['releases'] is! List) {
      throw const AppUpdateException('This update is not for this app.');
    }
    final matches = (manifest['releases'] as List)
        .whereType<Map>()
        .where((item) => item['platform'] == platform)
        .toList();
    if (matches.length != 1 ||
        matches.single['packageId'] != package.packageName) {
      throw const AppUpdateException('This update is not for this app.');
    }
    final release = matches.single;
    if (release['status'] != 'available' || release['destination'] is! Map) {
      throw const AppUpdateException(
        'Updates are not available yet. Please try again later.',
      );
    }
    final destination = release['destination'] as Map;
    final rawUrl = Uri.tryParse('${destination['url'] ?? ''}');
    final version = '${release['versionName'] ?? ''}';
    final build = release['buildNumber'];
    final published = DateTime.tryParse('${manifest['publishedAt'] ?? ''}');
    if (rawUrl == null ||
        version.isEmpty ||
        build is! int ||
        build <= 0 ||
        published == null) {
      throw const AppUpdateException(
        'Unable to check for updates. Please try again later.',
      );
    }
    final url = rawUrl.hasScheme
        ? rawUrl
        : Uri.parse(GlobalEnvironment.origin).resolveUri(rawUrl);
    final type = platform == 'ios'
        ? (destination['kind'] == 'testflight'
              ? AppUpdateDestinationType.testFlight
              : AppUpdateDestinationType.appStore)
        : AppUpdateDestinationType.androidApk;
    final info = AppUpdateInfo(
      currentVersion: package.version,
      currentBuild: int.tryParse(package.buildNumber) ?? 0,
      latestVersion: version,
      latestBuild: build,
      minimumSupportedBuild: 0,
      destinationType: type,
      destinationUri: url,
      releaseNotes: '',
      publishedAt: published.toUtc(),
      sha256: '${destination['sha256'] ?? ''}'.toLowerCase(),
    );
    if ((platform == 'android' && destination['kind'] != 'direct') ||
        (platform == 'ios' &&
            !{'app_store', 'testflight'}.contains(destination['kind'])) ||
        !validatePersisted(info)) {
      throw const AppUpdateException(
        'This update is not available for this app.',
      );
    }
    return info;
  }

  @override
  bool validatePersisted(AppUpdateInfo info) {
    final uri = info.destinationUri;
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    if (_targetPlatform == TargetPlatform.android) {
      return info.destinationType == AppUpdateDestinationType.androidApk &&
          _isAllowedGlobalApkUri(uri) &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(info.sha256 ?? '');
    }
    if (_targetPlatform == TargetPlatform.iOS &&
        info.destinationType == AppUpdateDestinationType.testFlight) {
      return uri.host == 'testflight.apple.com' &&
          RegExp(r'^/join/[A-Za-z0-9]+/?$').hasMatch(uri.path);
    }
    return _targetPlatform == TargetPlatform.iOS &&
        info.destinationType == AppUpdateDestinationType.appStore &&
        uri.host == 'apps.apple.com' &&
        _appStoreProductPath.hasMatch(uri.path);
  }
}

bool _isAllowedGlobalApkUri(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == Uri.parse(GlobalEnvironment.origin).host &&
    uri.port == 443 &&
    uri.userInfo.isEmpty &&
    !uri.hasQuery &&
    !uri.hasFragment &&
    RegExp(r'^/global/down/files/[A-Za-z0-9._-]+\.apk$').hasMatch(uri.path);
