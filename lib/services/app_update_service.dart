import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'global_environment.dart';
import 'network_audit.dart';

part 'global_app_update_service.dart';

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUpdatePersistenceException extends AppUpdateException {
  const AppUpdatePersistenceException(this.info) : super('必要更新状态暂时无法保存');

  final AppUpdateInfo info;
}

enum AppUpdateDestinationType {
  appStore('app_store'),
  testFlight('testflight'),
  androidApk('android_apk'),
  androidStore('android_store');

  const AppUpdateDestinationType(this.wireName);

  final String wireName;

  static AppUpdateDestinationType? tryParse(Object? raw) {
    final value = '${raw ?? ''}'.trim();
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.currentBuild,
    required this.latestVersion,
    required this.latestBuild,
    required this.minimumSupportedBuild,
    required this.destinationType,
    required this.destinationUri,
    required this.releaseNotes,
    required this.publishedAt,
    this.title = '',
    this.forceUpdateRequested = false,
    this.sha256,
  });

  final String currentVersion;
  final int currentBuild;
  final String latestVersion;
  final int latestBuild;
  final int minimumSupportedBuild;
  final AppUpdateDestinationType destinationType;
  final Uri destinationUri;
  final String releaseNotes;
  final DateTime publishedAt;
  final String title;
  final bool forceUpdateRequested;
  final String? sha256;

  bool get hasUpdate =>
      latestBuild > currentBuild ||
      (latestBuild == currentBuild &&
          _compareVersions(latestVersion, currentVersion) > 0);

  bool get forceUpdate =>
      hasUpdate &&
      (forceUpdateRequested || currentBuild < minimumSupportedBuild);

  AppUpdateInfo withCurrentPackage(PackageInfo package) => AppUpdateInfo(
    currentVersion: package.version,
    currentBuild: int.tryParse(package.buildNumber) ?? 0,
    latestVersion: latestVersion,
    latestBuild: latestBuild,
    minimumSupportedBuild: minimumSupportedBuild,
    destinationType: destinationType,
    destinationUri: destinationUri,
    releaseNotes: releaseNotes,
    publishedAt: publishedAt,
    title: title,
    forceUpdateRequested: forceUpdateRequested,
    sha256: sha256,
  );

  Map<String, Object?> toPersistenceMap() => {
    'current_version': currentVersion,
    'current_build': currentBuild,
    'latest_version': latestVersion,
    'latest_build': latestBuild,
    'minimum_supported_build': minimumSupportedBuild,
    'destination_type': destinationType.wireName,
    'destination_url': destinationUri.toString(),
    'release_notes': releaseNotes,
    'published_at': publishedAt.toUtc().toIso8601String(),
    'title': title,
    'force_update': forceUpdateRequested,
    if (sha256 != null) 'sha256': sha256,
  };

  static AppUpdateInfo? fromPersistenceMap(Map<String, Object?> value) {
    final destinationType = AppUpdateDestinationType.tryParse(
      value['destination_type'],
    );
    final destinationUri = Uri.tryParse('${value['destination_url'] ?? ''}');
    final publishedAt = DateTime.tryParse('${value['published_at'] ?? ''}');
    final latestVersion = '${value['latest_version'] ?? ''}'.trim();
    final latestBuild = _asInt(value['latest_build']);
    final minimumSupportedBuild = _asInt(value['minimum_supported_build']);
    if (destinationType == null ||
        destinationUri == null ||
        destinationUri.scheme.toLowerCase() != 'https' ||
        destinationUri.host.isEmpty ||
        publishedAt == null ||
        latestVersion.isEmpty ||
        latestBuild <= 0 ||
        !value.containsKey('minimum_supported_build') ||
        minimumSupportedBuild < 0 ||
        minimumSupportedBuild > latestBuild) {
      return null;
    }
    final hash = '${value['sha256'] ?? ''}'.trim().toLowerCase();
    if (destinationType == AppUpdateDestinationType.androidApk &&
        hash.isNotEmpty &&
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      return null;
    }
    return AppUpdateInfo(
      currentVersion: '${value['current_version'] ?? ''}'.trim(),
      currentBuild: _asInt(value['current_build']),
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      minimumSupportedBuild: minimumSupportedBuild,
      destinationType: destinationType,
      destinationUri: destinationUri,
      releaseNotes: '${value['release_notes'] ?? ''}',
      publishedAt: publishedAt.toUtc(),
      title: '${value['title'] ?? ''}'.trim(),
      forceUpdateRequested: _asBool(value['force_update']),
      sha256: hash.isEmpty ? null : hash,
    );
  }
}

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Uri? endpointUri,
    @Deprecated('Use endpointUri; manifestUri is kept for legacy tests only.')
    Uri? manifestUri,
    TargetPlatform? targetPlatform,
    Future<PackageInfo> Function()? packageInfoLoader,
    Set<String>? allowedDestinationHosts,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       assert(endpointUri == null || manifestUri == null),
       _endpointUri =
           endpointUri ?? manifestUri ?? _configuredVersionEndpointUri(),
       _targetPlatform = targetPlatform ?? defaultTargetPlatform,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _allowedDestinationHosts = allowedDestinationHosts == null
           ? null
           : Set.unmodifiable(allowedDestinationHosts),
       _requestTimeout = Duration(microseconds: requestTimeout.inMicroseconds);

  final http.Client _client;
  final Uri? _endpointUri;
  final TargetPlatform _targetPlatform;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final Set<String>? _allowedDestinationHosts;
  final Duration _requestTimeout;

  bool get isConfigured => _endpointUri != null;

  Future<PackageInfo> loadCurrentPackage() => _packageInfoLoader();

  Future<AppUpdateInfo> check() async {
    final endpointUri = _endpointUri;
    if (endpointUri == null) {
      throw const AppUpdateException('在线更新服务暂未配置');
    }
    _requireHttps(endpointUri, '版本接口地址必须使用 HTTPS');

    final platformName = switch (_targetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => throw const AppUpdateException('当前平台不支持在线更新'),
    };
    final package = await _packageInfoLoader();
    final currentBuild = int.tryParse(package.buildNumber) ?? 0;
    final requestUri = endpointUri.replace(
      queryParameters: {
        ...endpointUri.queryParameters,
        'v': '$currentBuild',
        'platform': platformName,
      },
    );

    late http.Response response;
    late Uri finalEndpointUri;
    try {
      final streamed = await _getWithSafeRedirects(
        _client,
        requestUri,
        timeout: _requestTimeout,
        headers: const {'Accept': 'application/json'},
      );
      finalEndpointUri = _responseUrl(streamed) ?? requestUri;
      response = await http.Response.fromStream(
        streamed,
      ).timeout(_requestTimeout);
    } on TimeoutException {
      throw const AppUpdateException('获取版本信息超时，请稍后重试');
    } catch (_) {
      throw const AppUpdateException('暂时无法获取版本信息');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AppUpdateException('暂时无法获取版本信息');
    }
    if (!_isSameHttpsOrigin(endpointUri, finalEndpointUri)) {
      throw const AppUpdateException('版本接口重定向到了不可信地址');
    }

    final Map<String, Object?> root;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      root = decoded.map((key, value) => MapEntry('$key', value));
    } catch (_) {
      throw const AppUpdateException('版本信息格式不正确');
    }

    if (root.containsKey('code') || root.containsKey('data')) {
      return _parseBackendResponse(
        root,
        platformName: platformName,
        package: package,
        endpointUri: endpointUri,
      );
    }

    // Preserve legacy release-manifest support for existing QA artifacts.
    // Production builds now use the backend version endpoint by default.
    final release = _selectRelease(root, platformName);
    if (_asInt(release['schema_version']) != 1 ||
        '${release['channel'] ?? ''}'.trim() != 'production' ||
        '${release['platform'] ?? ''}'.trim().toLowerCase() != platformName) {
      throw const AppUpdateException('版本信息与当前平台不匹配');
    }

    final latestVersion = '${release['latest_version'] ?? ''}'.trim();
    final latestBuild = _asInt(release['latest_build']);
    final minimumSupportedBuild = _asInt(release['minimum_supported_build']);
    final releaseNotes = '${release['release_notes'] ?? ''}'.trim();
    final publishedAt = DateTime.tryParse(
      '${release['published_at'] ?? ''}'.trim(),
    );
    final destinationRaw = release['destination'];
    if (latestVersion.isEmpty ||
        latestBuild <= 0 ||
        minimumSupportedBuild <= 0 ||
        minimumSupportedBuild > latestBuild ||
        publishedAt == null ||
        destinationRaw is! Map) {
      throw const AppUpdateException('版本信息缺少必要字段');
    }
    final destination = destinationRaw.map(
      (key, value) => MapEntry('$key', value),
    );
    final destinationType = AppUpdateDestinationType.tryParse(
      destination['type'],
    );
    final destinationUri = Uri.tryParse('${destination['url'] ?? ''}'.trim());
    if (destinationType == null || destinationUri == null) {
      throw const AppUpdateException('更新目标配置不正确');
    }
    _validateDestination(
      destinationType,
      destinationUri,
      endpointUri: endpointUri,
    );

    final hash = '${release['sha256'] ?? destination['sha256'] ?? ''}'
        .trim()
        .toLowerCase();
    if (destinationType == AppUpdateDestinationType.androidApk &&
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const AppUpdateException('Android 安装包缺少有效 SHA-256');
    }

    return AppUpdateInfo(
      currentVersion: package.version,
      currentBuild: int.tryParse(package.buildNumber) ?? 0,
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      minimumSupportedBuild: minimumSupportedBuild,
      destinationType: destinationType,
      destinationUri: destinationUri,
      releaseNotes: releaseNotes,
      publishedAt: publishedAt.toUtc(),
      sha256: hash.isEmpty ? null : hash,
    );
  }

  AppUpdateInfo _parseBackendResponse(
    Map<String, Object?> root, {
    required String platformName,
    required PackageInfo package,
    required Uri endpointUri,
  }) {
    if (_asInt(root['code']) != 200) {
      final message = '${root['message'] ?? ''}'.trim();
      throw AppUpdateException(message.isEmpty ? '暂时无法获取版本信息' : message);
    }

    final publishedAt =
        _asDateTime(root['timestamp']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final rawData = root['data'];
    if (rawData == null) {
      return _currentPackageInfo(
        package,
        platformName: platformName,
        endpointUri: endpointUri,
        publishedAt: publishedAt,
      );
    }
    if (rawData is! Map) {
      throw const AppUpdateException('版本信息格式不正确');
    }
    final release = rawData.map((key, value) => MapEntry('$key', value));
    if (release.containsKey('status') && _asInt(release['status']) != 1) {
      return _currentPackageInfo(
        package,
        platformName: platformName,
        endpointUri: endpointUri,
        publishedAt: publishedAt,
      );
    }

    final latestBuild = _asInt(release['version']);
    final latestVersion = '${release['version_code'] ?? ''}'.trim();
    final minimumSupportedBuild = _asInt(release['lowwer']);
    if (latestBuild <= 0 ||
        latestVersion.isEmpty ||
        minimumSupportedBuild < 0 ||
        minimumSupportedBuild > latestBuild) {
      throw const AppUpdateException('版本信息缺少必要字段');
    }

    final destinationType = switch (platformName) {
      'ios' => AppUpdateDestinationType.appStore,
      'android' => switch (_asInt(release['android_type'])) {
        0 => AppUpdateDestinationType.androidStore,
        1 => AppUpdateDestinationType.androidApk,
        _ => throw const AppUpdateException('Android 更新方式配置不正确'),
      },
      _ => throw const AppUpdateException('当前平台不支持在线更新'),
    };
    final destinationUri = _resolveBackendDestination(
      endpointUri,
      platformName == 'ios' ? release['ios'] : release['android'],
    );
    if (destinationUri == null) {
      throw AppUpdateException(
        platformName == 'ios' ? 'iOS 下载地址未配置' : 'Android 下载地址未配置',
      );
    }
    _validateDestination(
      destinationType,
      destinationUri,
      endpointUri: endpointUri,
    );

    final hash = '${release['sha256'] ?? release['android_sha256'] ?? ''}'
        .trim()
        .toLowerCase();
    if (hash.isNotEmpty && !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const AppUpdateException('Android 安装包 SHA-256 配置不正确');
    }

    return AppUpdateInfo(
      currentVersion: package.version,
      currentBuild: int.tryParse(package.buildNumber) ?? 0,
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      minimumSupportedBuild: minimumSupportedBuild,
      destinationType: destinationType,
      destinationUri: destinationUri,
      releaseNotes: _plainTextFromHtml(release['description']),
      publishedAt:
          _asDateTime(release['updated_at']) ??
          _asDateTime(release['created_at']) ??
          publishedAt,
      title: '${release['title'] ?? ''}'.trim(),
      forceUpdateRequested: _asBool(release['force']),
      sha256: hash.isEmpty ? null : hash,
    );
  }

  AppUpdateInfo _currentPackageInfo(
    PackageInfo package, {
    required String platformName,
    required Uri endpointUri,
    required DateTime publishedAt,
  }) {
    final currentBuild = int.tryParse(package.buildNumber) ?? 0;
    return AppUpdateInfo(
      currentVersion: package.version,
      currentBuild: currentBuild,
      latestVersion: package.version,
      latestBuild: currentBuild,
      minimumSupportedBuild: 0,
      destinationType: platformName == 'ios'
          ? AppUpdateDestinationType.appStore
          : AppUpdateDestinationType.androidStore,
      destinationUri: endpointUri,
      releaseNotes: '',
      publishedAt: publishedAt,
    );
  }

  Future<void> openDestination(AppUpdateInfo info) async {
    if (info.destinationType == AppUpdateDestinationType.androidApk) {
      throw const AppUpdateException('请先安全下载并校验安装包');
    }
    if (!await launchUrl(
      info.destinationUri,
      mode: LaunchMode.externalApplication,
    )) {
      throw const AppUpdateException('无法打开更新页面');
    }
  }

  Future<void> openDownload(AppUpdateInfo info) => openDestination(info);

  bool validatePersisted(AppUpdateInfo info) {
    final endpointUri = _endpointUri;
    if (endpointUri == null) return false;
    try {
      _requireHttps(endpointUri, '版本接口地址必须使用 HTTPS');
      _validateDestination(
        info.destinationType,
        info.destinationUri,
        endpointUri: endpointUri,
      );
      if (info.destinationType == AppUpdateDestinationType.androidApk &&
          info.sha256 != null &&
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(info.sha256!)) {
        return false;
      }
      return true;
    } on AppUpdateException {
      return false;
    }
  }

  void _validateDestination(
    AppUpdateDestinationType type,
    Uri uri, {
    required Uri endpointUri,
  }) {
    _requireHttps(uri, '更新地址必须使用 HTTPS');
    final platformIsIos = _targetPlatform == TargetPlatform.iOS;
    if (platformIsIos &&
        (type != AppUpdateDestinationType.appStore ||
            uri.host.toLowerCase() != 'apps.apple.com' ||
            !_appStoreProductPath.hasMatch(uri.path))) {
      throw const AppUpdateException('iOS 正式版只能通过 App Store 更新');
    }
    if (!platformIsIos && type == AppUpdateDestinationType.appStore) {
      throw const AppUpdateException('Android 更新目标类型不正确');
    }
    // `android_store` is an external landing page selected by the trusted
    // backend version API. It is opened by the system browser/app market and
    // may legitimately live on another HTTPS host. Keep the host allowlist for
    // direct APK downloads, where a cross-origin change affects the binary we
    // install on the device.
    if (!platformIsIos && type == AppUpdateDestinationType.androidStore) {
      return;
    }
    final configuredHosts =
        _allowedDestinationHosts ?? _configuredAllowedHosts(endpointUri.host);
    if (!configuredHosts.contains(uri.host.toLowerCase())) {
      throw const AppUpdateException('更新地址不在允许的安全域名内');
    }
  }

  static Uri? _configuredVersionEndpointUri() {
    const configuredEndpoint = String.fromEnvironment('SAYDIAN_UPDATE_API_URL');
    if (configuredEndpoint.trim().isNotEmpty) {
      return Uri.tryParse(configuredEndpoint.trim());
    }
    const configuredBase = String.fromEnvironment(
      'SAYDIAN_API_BASE_URL',
      defaultValue: GlobalEnvironment.origin,
    );
    return Uri.tryParse(configuredBase.trim())?.resolve('/api/v1/site/version');
  }

  static Set<String> _configuredAllowedHosts(String manifestHost) {
    const raw = String.fromEnvironment('SAYDIAN_UPDATE_ALLOWED_HOSTS');
    return <String>{
      manifestHost.toLowerCase(),
      'apps.apple.com',
      ...raw
          .split(',')
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty),
    };
  }
}

class AndroidApkUpdateInstaller {
  AndroidApkUpdateInstaller({
    http.Client? client,
    MethodChannel? channel,
    Future<Directory> Function()? temporaryDirectory,
    bool? isAndroid,
    this._allowedDownloadUri,
    this._requireSha256 = false,
  }) : _client = client ?? http.Client(),
       _channel = channel ?? const MethodChannel('cc.saidian/app_update'),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _isAndroid = isAndroid ?? Platform.isAndroid;

  AndroidApkUpdateInstaller.global({
    http.Client? client,
    MethodChannel? channel,
    Future<Directory> Function()? temporaryDirectory,
    bool? isAndroid,
  }) : this(
         client: client,
         channel: channel,
         temporaryDirectory: temporaryDirectory,
         isAndroid: isAndroid,
         allowedDownloadUri: _isAllowedGlobalApkUri,
         requireSha256: true,
       );

  final http.Client _client;
  final MethodChannel _channel;
  final Future<Directory> Function() _temporaryDirectory;
  final bool _isAndroid;
  final bool Function(Uri)? _allowedDownloadUri;
  final bool _requireSha256;

  Future<void> downloadAndInstall(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    if (!_isAndroid ||
        info.destinationType != AppUpdateDestinationType.androidApk) {
      throw const AppUpdateException('当前更新不能使用 Android 安装器');
    }
    if (!_isSameHttpsOrigin(info.destinationUri, info.destinationUri) ||
        !(_allowedDownloadUri?.call(info.destinationUri) ?? true) ||
        (_requireSha256 &&
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(info.sha256 ?? ''))) {
      throw const AppUpdateException(
        'This update is not available for this app.',
      );
    }
    final directory = Directory(
      path.join((await _temporaryDirectory()).path, 'saidian_updates'),
    );
    await directory.create(recursive: true);
    final target = File(
      path.join(directory.path, 'Say-Ring-${info.latestBuild}.apk'),
    );
    if (await target.exists()) await target.delete();

    http.StreamedResponse response;
    try {
      response = await _getWithSafeRedirects(
        _client,
        info.destinationUri,
        timeout: const Duration(seconds: 20),
        allowedUri: _allowedDownloadUri,
        auditKind: 'update_apk',
      );
    } on AppUpdateException {
      rethrow;
    } catch (_) {
      throw const AppUpdateException('安装包下载失败，请稍后重试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AppUpdateException('安装包下载失败，请稍后重试');
    }
    final finalDownloadUri = _responseUrl(response) ?? info.destinationUri;
    if (!_isSameHttpsOrigin(info.destinationUri, finalDownloadUri)) {
      throw const AppUpdateException('安装包重定向到了不可信地址');
    }

    final sink = target.openWrite();
    final digestSink = _DigestSink();
    final byteSink = sha256.startChunkedConversion(digestSink);
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 45),
      )) {
        sink.add(chunk);
        byteSink.add(chunk);
        received += chunk.length;
        final total = response.contentLength ?? 0;
        if (total > 0) onProgress?.call((received / total).clamp(0, 1));
      }
      await sink.flush();
      await sink.close();
      byteSink.close();
    } catch (_) {
      await sink.close();
      if (await target.exists()) await target.delete();
      throw const AppUpdateException('安装包下载中断，已删除不完整文件');
    }
    if (received == 0 || digestSink.value == null) {
      if (await target.exists()) await target.delete();
      throw const AppUpdateException('安装包内容为空');
    }
    final actual = digestSink.value!.toString().toLowerCase();
    final expectedHash = info.sha256;
    if (expectedHash != null && actual != expectedHash) {
      if (await target.exists()) await target.delete();
      throw const AppUpdateException('安装包校验失败，已删除损坏文件');
    }
    onProgress?.call(1);
    try {
      await _channel.invokeMethod<void>('installApk', {
        'filePath': target.path,
      });
    } on PlatformException catch (error) {
      if (error.code == 'UNKNOWN_SOURCES_DISABLED') {
        throw const AppUpdateException('请先允许 Say Ring 安装未知来源应用');
      }
      throw AppUpdateException(error.message ?? '无法打开系统安装器');
    }
  }

  Future<void> openUnknownSourcesSettings() async {
    try {
      await _channel.invokeMethod<void>('openUnknownSourcesSettings');
    } on PlatformException catch (error) {
      throw AppUpdateException(error.message ?? '无法打开安装授权设置');
    }
  }
}

abstract interface class AppUpdateCheckStore {
  Future<DateTime?> readLastSuccessfulCheck();
  Future<void> writeLastSuccessfulCheck(DateTime value);
  Future<AppUpdateInfo?> readRequiredUpdate();
  Future<void> writeRequiredUpdate(AppUpdateInfo? value);
}

class SecureAppUpdateCheckStore implements AppUpdateCheckStore {
  SecureAppUpdateCheckStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'saydian.update.last-success.v1';
  static const _requiredUpdateKey = 'saydian.update.required.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<DateTime?> readLastSuccessfulCheck() async =>
      DateTime.tryParse(await _storage.read(key: _key) ?? '')?.toUtc();

  @override
  Future<void> writeLastSuccessfulCheck(DateTime value) =>
      _storage.write(key: _key, value: value.toUtc().toIso8601String());

  @override
  Future<AppUpdateInfo?> readRequiredUpdate() async {
    final raw = await _storage.read(key: _requiredUpdateKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AppUpdateInfo.fromPersistenceMap(
        decoded.map((key, value) => MapEntry('$key', value)),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeRequiredUpdate(AppUpdateInfo? value) async {
    if (value == null) {
      await _storage.delete(key: _requiredUpdateKey);
      return;
    }
    await _storage.write(
      key: _requiredUpdateKey,
      value: jsonEncode(value.toPersistenceMap()),
    );
  }
}

class AppUpdateCoordinator {
  AppUpdateCoordinator(
    this._service, {
    AppUpdateCheckStore? store,
    DateTime Function()? now,
  }) : _store = store ?? SecureAppUpdateCheckStore(),
       _now = now ?? DateTime.now;

  final AppUpdateService _service;
  final AppUpdateCheckStore _store;
  final DateTime Function() _now;
  bool _checking = false;

  Future<AppUpdateInfo?> restoreRequiredUpdate() async {
    final persisted = await _store.readRequiredUpdate();
    if (persisted == null) return null;
    if (!_service.validatePersisted(persisted)) {
      await _store.writeRequiredUpdate(null);
      return null;
    }
    // A valid cached mandatory gate must fail closed when package metadata is
    // temporarily unavailable during cold start. Otherwise a plugin/storage
    // startup error could turn a previously known forced update into access to
    // the app. A later successful read still clears the gate after upgrading.
    AppUpdateInfo current;
    try {
      current = persisted.withCurrentPackage(
        await _service.loadCurrentPackage(),
      );
    } catch (_) {
      return persisted.forceUpdate ? persisted : null;
    }
    if (current.forceUpdate) return current;
    await _store.writeRequiredUpdate(null);
    return null;
  }

  Future<AppUpdateInfo?> checkIfDue() async {
    if (_checking) return null;
    final required = await restoreRequiredUpdate();
    if (required != null) {
      if (!_service.isConfigured) return required;
      return _refreshKnownRequiredUpdate();
    }
    if (!_service.isConfigured) return null;
    final now = _now().toUtc();
    final last = await _store.readLastSuccessfulCheck();
    if (last != null && now.difference(last) < const Duration(days: 1)) {
      return null;
    }
    _checking = true;
    try {
      final info = await _service.check();
      try {
        await _store.writeRequiredUpdate(info.forceUpdate ? info : null);
      } catch (_) {
        if (info.forceUpdate) throw AppUpdatePersistenceException(info);
        throw const AppUpdateException('更新状态暂时无法保存');
      }
      await _store.writeLastSuccessfulCheck(now);
      return info.hasUpdate ? info : null;
    } finally {
      _checking = false;
    }
  }

  /// Manual checks bypass the daily throttle but still update the same
  /// persisted mandatory gate used during cold start and app resume.
  Future<AppUpdateInfo> checkNow() async {
    if (_checking) throw const AppUpdateException('正在检查更新，请稍候');
    if (!_service.isConfigured) {
      throw const AppUpdateException('在线更新服务暂未配置');
    }
    _checking = true;
    try {
      final info = await _service.check();
      try {
        await _store.writeRequiredUpdate(info.forceUpdate ? info : null);
      } catch (_) {
        if (info.forceUpdate) throw AppUpdatePersistenceException(info);
        throw const AppUpdateException('更新状态暂时无法保存');
      }
      await _store.writeLastSuccessfulCheck(_now().toUtc());
      return info;
    } finally {
      _checking = false;
    }
  }

  Future<AppUpdateInfo?> _refreshKnownRequiredUpdate() async {
    _checking = true;
    try {
      // A cached mandatory gate fails closed while offline, but a successful
      // production manifest request must be able to correct or replace it.
      // This intentionally bypasses the daily throttle until the gate clears.
      final info = await _service.check();
      try {
        await _store.writeRequiredUpdate(info.forceUpdate ? info : null);
      } catch (_) {
        if (info.forceUpdate) throw AppUpdatePersistenceException(info);
        throw const AppUpdateException('更新状态暂时无法保存');
      }
      await _store.writeLastSuccessfulCheck(_now().toUtc());
      return info.hasUpdate ? info : null;
    } finally {
      _checking = false;
    }
  }
}

Map<String, Object?> _selectRelease(
  Map<String, Object?> root,
  String platform,
) {
  final releases = root['releases'];
  if (releases is List) {
    for (final raw in releases.whereType<Map>()) {
      final candidate = raw.map((key, value) => MapEntry('$key', value));
      if ('${candidate['platform'] ?? ''}'.trim().toLowerCase() == platform) {
        return candidate;
      }
    }
    throw const AppUpdateException('更新清单没有当前平台的正式版本');
  }
  final platformData = root[platform];
  if (platformData is Map) {
    final candidate = platformData.map((key, value) => MapEntry('$key', value));
    return {
      'schema_version': root['schema_version'],
      'channel': root['channel'],
      'platform': platform,
      ...candidate,
    };
  }
  return root;
}

Uri? _resolveBackendDestination(Uri endpointUri, Object? raw) {
  final value = '${raw ?? ''}'.trim();
  if (value.isEmpty) return null;
  final parsed = Uri.tryParse(value);
  if (parsed == null) return null;
  if (parsed.hasScheme) return parsed;
  final origin = endpointUri.replace(path: '/', query: null, fragment: null);
  return origin.resolveUri(parsed);
}

void _requireHttps(Uri uri, String message) {
  if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
    throw AppUpdateException(message);
  }
}

bool _isSameHttpsOrigin(Uri expected, Uri actual) =>
    expected.scheme.toLowerCase() == 'https' &&
    expected.host.isNotEmpty &&
    expected.port == 443 &&
    expected.userInfo.isEmpty &&
    !expected.hasFragment &&
    actual.scheme.toLowerCase() == 'https' &&
    actual.host.toLowerCase() == expected.host.toLowerCase() &&
    actual.port == 443 &&
    actual.userInfo.isEmpty &&
    !actual.hasFragment;

Future<http.StreamedResponse> _getWithSafeRedirects(
  http.Client client,
  Uri initialUri, {
  required Duration timeout,
  Map<String, String> headers = const {},
  bool Function(Uri)? allowedUri,
  String auditKind = 'update_manifest',
}) async {
  var uri = initialUri;
  final visited = <Uri>{};
  const maxRedirects = 3;
  for (var hop = 0; hop <= maxRedirects; hop++) {
    if (!_isSameHttpsOrigin(initialUri, uri) ||
        !(allowedUri?.call(uri) ?? true) ||
        !visited.add(uri)) {
      throw const AppUpdateException('更新地址不在允许的安全范围内');
    }
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll(headers);
    NetworkAudit.record(
      uri,
      request.method,
      auditKind,
      outcome: 'request_started',
    );
    final response = await client.send(request).timeout(timeout);
    NetworkAudit.record(
      uri,
      request.method,
      auditKind,
      status: response.statusCode,
      requestId: response.headers['x-request-id'],
    );
    // No client is allowed to follow a hop behind this validator's back.
    if ((_responseUrl(response) ?? uri) != uri) {
      await response.stream.listen(null).cancel();
      throw const AppUpdateException('更新地址不在允许的安全范围内');
    }
    if (!const {301, 302, 303, 307, 308}.contains(response.statusCode)) {
      return response;
    }
    final location = response.headers['location'];
    await response.stream.listen(null).cancel();
    if (hop == maxRedirects || location == null || location.trim().isEmpty) {
      throw const AppUpdateException('更新下载跳转失败，请稍后重试');
    }
    final next = Uri.tryParse(location);
    if (next == null) {
      throw const AppUpdateException('更新地址不在允许的安全范围内');
    }
    uri = uri.resolveUri(next);
  }
  throw const AppUpdateException('更新下载跳转失败，请稍后重试');
}

Uri? _responseUrl(http.BaseResponse response) => switch (response) {
  http.BaseResponseWithUrl(:final url) => url,
  _ => response.request?.url,
};

final RegExp _appStoreProductPath = RegExp(
  r'^/(?:[a-z]{2}/)?app/(?:[^/]+/)?id[0-9]+/?$',
  caseSensitive: false,
);

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}'.trim()) ?? 0;

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {
    '1',
    'true',
    'yes',
    'on',
  }.contains('${value ?? ''}'.trim().toLowerCase());
}

DateTime? _asDateTime(Object? value) {
  if (value is num) {
    final raw = value.toInt();
    if (raw <= 0) return null;
    final milliseconds = raw > 99999999999 ? raw : raw * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty) return null;
  final numeric = int.tryParse(raw);
  if (numeric != null) return _asDateTime(numeric);
  return DateTime.tryParse(raw)?.toUtc();
}

String _plainTextFromHtml(Object? raw) {
  var value = '${raw ?? ''}';
  value = value
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</\s*(?:p|div|li|h[1-6])\s*>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return value.trim();
}

int _compareVersions(String left, String right) {
  final a = left.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  final b = right.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  final length = a.length > b.length ? a.length : b.length;
  for (var index = 0; index < length; index++) {
    final av = index < a.length ? a[index] : 0;
    final bv = index < b.length ? b[index] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
