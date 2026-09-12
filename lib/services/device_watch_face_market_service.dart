import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'wearable_bridge.dart';
import 'safe_resource_client.dart';

class DeviceWatchFaceMarketException implements Exception {
  const DeviceWatchFaceMarketException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceWatchFaceMarketItem {
  const DeviceWatchFaceMarketItem({
    required this.name,
    required this.fileUrl,
    required this.previewUrl,
    required this.fileLength,
    required this.available,
    required this.crc,
    required this.binProtocol,
    required this.dialShape,
    this.nativeCatalogId,
  });

  final String name;
  final Uri fileUrl;
  final Uri previewUrl;
  final int fileLength;
  final bool available;
  final int? crc;
  final int? binProtocol;
  final int? dialShape;
  final String? nativeCatalogId;

  factory DeviceWatchFaceMarketItem.fromNative(
    NativeWatchFaceCatalogItem item,
  ) => DeviceWatchFaceMarketItem(
    name: item.name,
    fileUrl: item.fileUrl,
    previewUrl: item.previewUrl,
    fileLength: 0,
    available: true,
    crc: item.crc,
    binProtocol: item.binProtocol,
    dialShape: item.dialShape,
    nativeCatalogId: item.id,
  );

  factory DeviceWatchFaceMarketItem.fromMap(Map<Object?, Object?> map) {
    final fileUrl = Uri.tryParse('${map['fileUrl'] ?? ''}');
    final previewUrl = Uri.tryParse('${map['previewUrl'] ?? ''}');
    if (fileUrl == null ||
        previewUrl == null ||
        fileUrl.scheme != 'https' ||
        previewUrl.scheme != 'https') {
      throw const DeviceWatchFaceMarketException('显示样式数据地址无效');
    }
    return DeviceWatchFaceMarketItem(
      name: '${map['name'] ?? '在线显示样式'}'.trim(),
      fileUrl: fileUrl,
      previewUrl: previewUrl,
      fileLength: _optionalInt(map['fileLenght'] ?? map['fileLength']) ?? 0,
      available: map['available'] != false,
      crc: _optionalInt(map['crc']),
      binProtocol: _optionalInt(map['binProtocol']),
      dialShape: _optionalInt(map['dialShape']),
    );
  }

  static int? _optionalInt(Object? value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed >= 0 ? parsed : null;
  }
}

class DeviceWatchFaceMarketPageData {
  const DeviceWatchFaceMarketPageData({
    required this.pageIndex,
    required this.pageCount,
    required this.total,
    required this.items,
    this.isCached = false,
  });

  final int pageIndex;
  final int pageCount;
  final int total;
  final List<DeviceWatchFaceMarketItem> items;
  final bool isCached;
}

class DeviceWatchFaceMarketProfile {
  const DeviceWatchFaceMarketProfile({
    required this.provider,
    required this.deviceId,
    required this.deviceLabel,
    required this.dialShape,
    required this.binProtocol,
    required this.maxFileLength,
    required this.deviceNumber,
    required this.firmwareVersion,
    required this.screenWidth,
    required this.screenHeight,
    required this.slotCount,
    required this.profileFingerprint,
  });

  factory DeviceWatchFaceMarketProfile.fromMap(Map<String, Object?> value) {
    String text(String key, [String? alias]) =>
        '${value[key] ?? (alias == null ? null : value[alias]) ?? ''}'.trim();
    int number(String key, [String? alias]) =>
        (value[key] as num?)?.toInt() ??
        (alias == null ? null : (value[alias] as num?)?.toInt()) ??
        int.tryParse(text(key, alias)) ??
        0;
    bool aliasesAgree(String key, String alias) {
      if (!value.containsKey(key) || !value.containsKey(alias)) return true;
      final primary = '${value[key] ?? ''}'.trim();
      final secondary = '${value[alias] ?? ''}'.trim();
      return primary == secondary;
    }

    final provider = text('provider');
    final deviceId = text('deviceId');
    final deviceLabel = text('deviceLabel');
    final firmware = text('firmware', 'deviceTestVersion');
    final fingerprint = text('profileFingerprint').toLowerCase();
    final screenWidth = number('width', 'screenWidth');
    final screenHeight = number('height', 'screenHeight');
    final dialShape = number('dialShape');
    final binProtocol = number('binProtocol');
    final maxFileLength = number('maxFileLength', 'maxLength');
    final deviceNumber = number('deviceNumber');
    final slotCount = number('slotCount');
    final valid =
        value['onlineMarketSupported'] == true &&
        number('profileVersion') == 1 &&
        text('profileFingerprintAlgorithm').toLowerCase() == 'sha256' &&
        provider.toLowerCase() == 'vep' &&
        deviceId.isNotEmpty &&
        deviceLabel.isNotEmpty &&
        firmware.isNotEmpty &&
        RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint) &&
        screenWidth > 0 &&
        screenHeight > 0 &&
        dialShape > 0 &&
        binProtocol > 0 &&
        maxFileLength > 100 &&
        deviceNumber > 0 &&
        slotCount > 0 &&
        aliasesAgree('firmware', 'deviceTestVersion') &&
        aliasesAgree('width', 'screenWidth') &&
        aliasesAgree('height', 'screenHeight') &&
        aliasesAgree('maxFileLength', 'maxLength');
    if (!valid) {
      throw const DeviceWatchFaceMarketException('当前戒指的显示规格不完整');
    }
    return DeviceWatchFaceMarketProfile(
      provider: provider,
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      dialShape: dialShape,
      binProtocol: binProtocol,
      maxFileLength: maxFileLength,
      deviceNumber: deviceNumber,
      firmwareVersion: firmware,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      slotCount: slotCount,
      profileFingerprint: fingerprint,
    );
  }

  /// Test fixture only. Production callers must use a freshly read profile.
  static const testW9s = DeviceWatchFaceMarketProfile(
    provider: 'Vep',
    deviceId: 'test-w9s',
    deviceLabel: 'SD-Watch-W9S',
    dialShape: 58,
    binProtocol: 2,
    maxFileLength: 614733,
    deviceNumber: 6702,
    firmwareVersion: '11.95.01.00',
    screenWidth: 410,
    screenHeight: 502,
    slotCount: 1,
    profileFingerprint:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  );

  final String provider;
  final String deviceId;
  final String deviceLabel;
  final int dialShape;
  final int binProtocol;
  final int maxFileLength;
  final int deviceNumber;
  final String firmwareVersion;
  final int screenWidth;
  final int screenHeight;
  final int slotCount;
  final String profileFingerprint;

  bool matchesDevice(String? currentDeviceId) =>
      currentDeviceId != null &&
      _nativeVeepooDeviceId(currentDeviceId) == deviceId.toLowerCase();

  static String? _nativeVeepooDeviceId(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('yucheng:')) return null;
    return normalized.startsWith('veepoo:')
        ? normalized.substring('veepoo:'.length)
        : normalized;
  }
}

/// Loads the Veepoo/JL online watch-face catalogue.
///
/// Veepoo's catalogue endpoint expects the binary compatibility profile used
/// by its network-dial manager. Every compatibility field comes from the
/// authenticated device session; the W9S profile is only a test/fallback value
/// and must not be used to open the market for an unidentified device.
class DeviceWatchFaceMarketService {
  DeviceWatchFaceMarketService({
    http.Client? client,
    Future<Directory> Function()? supportDirectory,
    Future<String> Function()? appVersionLoader,
    bool? directCatalogueAllowed,
  }) : _client = SafeResourceClient(
         inner: client,
         purpose: ResourcePurpose.watchFace,
       ),
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _appVersionLoader =
           appVersionLoader ??
           (() async => (await PackageInfo.fromPlatform()).version),
       _directCatalogueAllowed = directCatalogueAllowed ?? !Platform.isIOS;

  final http.Client _client;
  final Future<Directory> Function() _supportDirectory;
  final Future<String> Function() _appVersionLoader;
  final bool _directCatalogueAllowed;

  static const _endpoint =
      'https://www.vphband.com:9001/api/system/getthemespage';
  static const _pageSize = 12;

  Future<DeviceWatchFaceMarketPageData> loadPage({
    int page = 1,
    required DeviceWatchFaceMarketProfile profile,
  }) async {
    final normalizedPage = page < 1 ? 1 : page;
    try {
      final response = await _requestCatalogue(
        page: normalizedPage,
        pageSize: _pageSize,
        profile: profile,
      );
      final parsed = _parseResponse(response.body, normalizedPage);
      await _writeCache(profile, 'page-$normalizedPage.json', response.body);
      return parsed;
    } on DeviceWatchFaceMarketException {
      final cached = await _readCachedPage(
        profile,
        'page-$normalizedPage.json',
        normalizedPage,
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<DeviceWatchFaceMarketItem>> loadIndex({
    required DeviceWatchFaceMarketProfile profile,
  }) async {
    try {
      final response = await _requestCatalogue(
        page: 1,
        pageSize: 200,
        profile: profile,
      );
      final parsed = _parseResponse(response.body, 1);
      await _writeCache(profile, 'index.json', response.body);
      return parsed.items.take(200).toList(growable: false);
    } on DeviceWatchFaceMarketException {
      final cached = await _readCachedPage(profile, 'index.json', 1);
      if (cached != null) return cached.items.take(200).toList(growable: false);
      rethrow;
    }
  }

  DeviceWatchFaceMarketItem? matchInstalledPath(
    String installedPath,
    Iterable<DeviceWatchFaceMarketItem> catalogue,
  ) {
    final installed = _normalizedResourceName(installedPath);
    if (installed.isEmpty) return null;
    for (final item in catalogue) {
      if (_normalizedResourceName(item.fileUrl.path) == installed) return item;
    }
    return null;
  }

  bool hasUsablePreviewReference(Map<String, Object?> face) {
    return _findUsablePreviewReference(face, const [
          'thumbnail',
          'thumbnailUrl',
          'previewPath',
          'previewUrl',
        ]) !=
        null;
  }

  static String? findUsablePreviewReference(Map<String, Object?> face) {
    return _findUsablePreviewReference(face, const [
      'thumbnail',
      'thumbnailUrl',
      'previewPath',
      'preview',
      'previewUrl',
      'image',
      'imageUrl',
      'background',
      'filePath',
    ]);
  }

  static String? _findUsablePreviewReference(
    Map<String, Object?> face,
    Iterable<String> keys,
  ) {
    for (final key in keys) {
      final value = '${face[key] ?? ''}'.trim();
      if (value.isEmpty) continue;
      final uri = Uri.tryParse(value);
      if (uri != null && uri.isScheme('https') && uri.host.isNotEmpty) {
        return value;
      }
      final file = File(value.replaceFirst('file://', ''));
      try {
        if (file.existsSync() && file.lengthSync() > 0) return value;
      } on FileSystemException {
        // Fall through so an official catalogue preview can be matched.
      }
    }
    return null;
  }

  Future<File?> previewFile(
    DeviceWatchFaceMarketItem item, {
    required DeviceWatchFaceMarketProfile profile,
  }) async {
    final directory = await _profileCacheDirectory(profile);
    final previews = Directory(path.join(directory.path, 'previews'));
    await previews.create(recursive: true);
    final extension = path.extension(item.previewUrl.path).toLowerCase();
    final safeExtension =
        const {'.png', '.jpg', '.jpeg', '.webp'}.contains(extension)
        ? extension
        : '.img';
    final key = sha256.convert(utf8.encode(item.previewUrl.toString()));
    final file = File(path.join(previews.path, '$key$safeExtension'));
    if (await file.exists() && await file.length() > 0) return file;
    try {
      final response = await _client
          .get(item.previewUrl)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        return null;
      }
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _requestCatalogue({
    required int page,
    required int pageSize,
    required DeviceWatchFaceMarketProfile profile,
  }) async {
    if (!_directCatalogueAllowed) {
      throw const DeviceWatchFaceMarketException('当前手机无法完成此操作，请在戒指上操作');
    }
    final appVersion = (await _appVersionLoader()).trim();
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'dialShape': '${profile.dialShape}',
        'binProtocol': '${profile.binProtocol}',
        'maxLength': '${profile.maxFileLength}',
        'deviceNumber': '${profile.deviceNumber}',
        'deviceVersion': profile.firmwareVersion,
        'appType': 'android',
        'appVersion': appVersion.isEmpty ? 'unknown' : appVersion,
        'pageIndex': '$page',
        'pageSize': '$pageSize',
      },
    );
    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const DeviceWatchFaceMarketException('网络不可用，请检查网络后重试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DeviceWatchFaceMarketException('显示样式商城暂时无法访问，请稍后重试');
    }
    return response;
  }

  DeviceWatchFaceMarketPageData _parseResponse(String body, int page) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const DeviceWatchFaceMarketException('显示样式商城返回了无法识别的数据');
    }
    if (decoded is! Map) {
      throw const DeviceWatchFaceMarketException('显示样式商城返回了无法识别的数据');
    }
    final rawItems = decoded['results'];
    final items = <DeviceWatchFaceMarketItem>[];
    if (rawItems is List) {
      for (final raw in rawItems.whereType<Map>()) {
        try {
          final item = DeviceWatchFaceMarketItem.fromMap(
            raw.map((key, value) => MapEntry(key, value)),
          );
          if (item.available) items.add(item);
        } on DeviceWatchFaceMarketException {
          // Ignore an individual malformed item without hiding the catalogue.
        }
      }
    }
    return DeviceWatchFaceMarketPageData(
      pageIndex: (decoded['pageIndex'] as num?)?.toInt() ?? page,
      pageCount: (decoded['pageCount'] as num?)?.toInt() ?? 1,
      total: (decoded['counts'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }

  Future<DeviceWatchFaceMarketPageData?> _readCachedPage(
    DeviceWatchFaceMarketProfile profile,
    String fileName,
    int page,
  ) async {
    try {
      final file = File(
        path.join((await _profileCacheDirectory(profile)).path, fileName),
      );
      if (!await file.exists()) return null;
      final parsed = _parseResponse(await file.readAsString(), page);
      return DeviceWatchFaceMarketPageData(
        pageIndex: parsed.pageIndex,
        pageCount: parsed.pageCount,
        total: parsed.total,
        items: parsed.items,
        isCached: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    DeviceWatchFaceMarketProfile profile,
    String fileName,
    String body,
  ) async {
    try {
      final directory = await _profileCacheDirectory(profile);
      await directory.create(recursive: true);
      final target = File(path.join(directory.path, fileName));
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsString(body, flush: true);
      await temporary.rename(target.path);
    } catch (_) {
      // Cache failures never turn a valid online catalogue into an error.
    }
  }

  Future<Directory> _profileCacheDirectory(
    DeviceWatchFaceMarketProfile profile,
  ) async {
    final root = await _supportDirectory();
    return Directory(
      path.join(root.path, 'watch_face_catalog', profile.profileFingerprint),
    );
  }

  Future<String> download(
    DeviceWatchFaceMarketItem item, {
    required DeviceWatchFaceMarketProfile profile,
    void Function(double progress)? onProgress,
  }) async {
    if (!_directCatalogueAllowed) {
      throw const DeviceWatchFaceMarketException('当前手机无法完成此操作，请在戒指上操作');
    }
    if ((item.dialShape != null && item.dialShape != profile.dialShape) ||
        (item.binProtocol != null && item.binProtocol != profile.binProtocol) ||
        item.fileLength <= 100 ||
        item.fileLength > profile.maxFileLength) {
      throw const DeviceWatchFaceMarketException('此显示样式与当前戒指规格不匹配');
    }
    http.StreamedResponse response;
    try {
      final request = http.Request('GET', item.fileUrl);
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const DeviceWatchFaceMarketException('显示样式下载失败，请检查网络后重试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DeviceWatchFaceMarketException('显示样式下载失败，请稍后重试');
    }
    final directory = Directory(
      path.join((await getTemporaryDirectory()).path, 'saidian_watch_faces'),
    );
    await directory.create(recursive: true);
    // JL identifies dial resources by the filename embedded in the catalogue.
    // Renaming every download to a UI title plus `.bin` makes the transferred
    // resource impossible to find/switch on W9S.  Preserve the server filename
    // while still removing path/control characters.
    final sourceName = item.fileUrl.pathSegments.isEmpty
        ? 'WATCH_DOWNLOAD'
        : Uri.decodeComponent(item.fileUrl.pathSegments.last);
    final safeName = sourceName.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final file = File(
      path.join(directory.path, safeName.isEmpty ? 'WATCH_DOWNLOAD' : safeName),
    );
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        sink.add(chunk);
        received += chunk.length;
        final expected = item.fileLength > 0
            ? item.fileLength
            : response.contentLength ?? 0;
        if (expected > 0) onProgress?.call((received / expected).clamp(0, 1));
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      throw const DeviceWatchFaceMarketException('显示样式下载中断，请重试');
    }
    await sink.close();
    if (received <= 0 || (item.fileLength > 0 && received != item.fileLength)) {
      if (await file.exists()) await file.delete();
      throw const DeviceWatchFaceMarketException('显示样式文件不完整，请重新下载');
    }
    onProgress?.call(1);
    return file.path;
  }
}

String _normalizedResourceName(String value) {
  final decoded = Uri.decodeComponent(value).replaceAll('\\', '/');
  final base = path.basename(decoded).toLowerCase();
  final extension = path.extension(base);
  return extension.isEmpty
      ? base
      : base.substring(0, base.length - extension.length);
}
