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
  final String? sha256;

  bool get forceUpdate => currentBuild < minimumSupportedBuild;

  bool get hasUpdate =>
      forceUpdate ||
      latestBuild > currentBuild ||
      (latestBuild == currentBuild &&
          _compareVersions(latestVersion, currentVersion) > 0);

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
        minimumSupportedBuild <= 0 ||
        minimumSupportedBuild > latestBuild) {
      return null;
    }
    final hash = '${value['sha256'] ?? ''}'.trim().toLowerCase();
    if (destinationType == AppUpdateDestinationType.androidApk &&
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
      sha256: hash.isEmpty ? null : hash,
    );
  }
}

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Uri? manifestUri,
    TargetPlatform? targetPlatform,
    Future<PackageInfo> Function()? packageInfoLoader,
    Set<String>? allowedDestinationHosts,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _manifestUri = manifestUri ?? _configuredManifestUri(),
       _targetPlatform = targetPlatform ?? defaultTargetPlatform,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _allowedDestinationHosts = allowedDestinationHosts == null
           ? null
           : Set.unmodifiable(allowedDestinationHosts),
       _requestTimeout = Duration(microseconds: requestTimeout.inMicroseconds);

  final http.Client _client;
  final Uri? _manifestUri;
  final TargetPlatform _targetPlatform;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final Set<String>? _allowedDestinationHosts;
  final Duration _requestTimeout;

  bool get isConfigured => _manifestUri != null;

  Future<PackageInfo> loadCurrentPackage() => _packageInfoLoader();

  Future<AppUpdateInfo> check() async {
    final manifestUri = _manifestUri;
    if (manifestUri == null) {
      throw const AppUpdateException('在线更新服务暂未配置');
    }
    _requireHttps(manifestUri, '更新清单地址必须使用 HTTPS');

    late http.Response response;
    late Uri finalManifestUri;
    try {
      final request = http.Request('GET', manifestUri);
      final streamed = await _client.send(request).timeout(_requestTimeout);
      finalManifestUri = _responseUrl(streamed) ?? manifestUri;
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
    if (!_isSameHttpsOrigin(manifestUri, finalManifestUri)) {
      throw const AppUpdateException('更新清单重定向到了不可信地址');
    }

    final Map<String, Object?> root;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      root = decoded.map((key, value) => MapEntry('$key', value));
    } catch (_) {
      throw const AppUpdateException('版本信息格式不正确');
    }

    final platformName = switch (_targetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => throw const AppUpdateException('当前平台不支持在线更新'),
    };
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
      manifestUri: manifestUri,
    );

    final hash = '${release['sha256'] ?? destination['sha256'] ?? ''}'
        .trim()
        .toLowerCase();
    if (destinationType == AppUpdateDestinationType.androidApk &&
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const AppUpdateException('Android 安装包缺少有效 SHA-256');
    }

    final package = await _packageInfoLoader();
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
    final manifestUri = _manifestUri;
    if (manifestUri == null) return false;
    try {
      _requireHttps(manifestUri, '更新清单地址必须使用 HTTPS');
      _validateDestination(
        info.destinationType,
        info.destinationUri,
        manifestUri: manifestUri,
      );
      if (info.destinationType == AppUpdateDestinationType.androidApk &&
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(info.sha256 ?? '')) {
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
    required Uri manifestUri,
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
    final configuredHosts =
        _allowedDestinationHosts ?? _configuredAllowedHosts(manifestUri.host);
    if (!configuredHosts.contains(uri.host.toLowerCase())) {
      throw const AppUpdateException('更新地址不在允许的安全域名内');
    }
  }

  static Uri? _configuredManifestUri() {
    const value = String.fromEnvironment('SAYDIAN_UPDATE_MANIFEST_URL');
    final configured = value.trim();
    return configured.isEmpty ? null : Uri.tryParse(configured);
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
  }) : _client = client ?? http.Client(),
       _channel = channel ?? const MethodChannel('cc.saidian/app_update'),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _isAndroid = isAndroid ?? Platform.isAndroid;

  final http.Client _client;
  final MethodChannel _channel;
  final Future<Directory> Function() _temporaryDirectory;
  final bool _isAndroid;

  Future<void> downloadAndInstall(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    if (!_isAndroid ||
        info.destinationType != AppUpdateDestinationType.androidApk ||
        info.sha256 == null) {
      throw const AppUpdateException('当前更新不能使用 Android 安装器');
    }
    final directory = Directory(
      path.join((await _temporaryDirectory()).path, 'saidian_updates'),
    );
    await directory.create(recursive: true);
    final target = File(
      path.join(directory.path, 'Saydian-${info.latestBuild}.apk'),
    );
    if (await target.exists()) await target.delete();

    http.StreamedResponse response;
    try {
      response = await _client
          .send(http.Request('GET', info.destinationUri))
          .timeout(const Duration(seconds: 20));
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
    if (actual != info.sha256) {
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
        throw const AppUpdateException('请先允许赛电安装未知来源应用');
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

void _requireHttps(Uri uri, String message) {
  if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
    throw AppUpdateException(message);
  }
}

bool _isSameHttpsOrigin(Uri expected, Uri actual) =>
    actual.scheme.toLowerCase() == 'https' &&
    actual.host.toLowerCase() == expected.host.toLowerCase() &&
    actual.port == expected.port;

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
