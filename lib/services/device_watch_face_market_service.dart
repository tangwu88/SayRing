import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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
  });

  final String name;
  final Uri fileUrl;
  final Uri previewUrl;
  final int fileLength;
  final bool available;
  final int? crc;
  final int? binProtocol;
  final int? dialShape;

  factory DeviceWatchFaceMarketItem.fromMap(Map<Object?, Object?> map) {
    final fileUrl = Uri.tryParse('${map['fileUrl'] ?? ''}');
    final previewUrl = Uri.tryParse('${map['previewUrl'] ?? ''}');
    if (fileUrl == null ||
        previewUrl == null ||
        fileUrl.scheme != 'https' ||
        previewUrl.scheme != 'https') {
      throw const DeviceWatchFaceMarketException('表盘数据地址无效');
    }
    return DeviceWatchFaceMarketItem(
      name: '${map['name'] ?? '在线表盘'}'.trim(),
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
  });

  final int pageIndex;
  final int pageCount;
  final int total;
  final List<DeviceWatchFaceMarketItem> items;
}

class DeviceWatchFaceMarketProfile {
  const DeviceWatchFaceMarketProfile({
    required this.dialShape,
    required this.binProtocol,
    required this.maxLength,
    required this.deviceNumber,
    required this.deviceTestVersion,
    required this.screenWidth,
    required this.screenHeight,
  });

  factory DeviceWatchFaceMarketProfile.fromMap(Map<String, Object?> value) {
    int number(String key, int fallback) =>
        (value[key] as num?)?.toInt() ??
        int.tryParse('${value[key] ?? ''}') ??
        fallback;
    const catalogue = DeviceWatchFaceMarketProfile.w9s;
    final screenWidth = number('screenWidth', catalogue.screenWidth);
    final screenHeight = number('screenHeight', catalogue.screenHeight);
    final reportedDialShape = number('dialShape', catalogue.dialShape);
    // The SDK has multiple custom-UI variants for the same physical panel
    // (for example standard/Apple/Earth/Aurora 410x502). Veepoo's online
    // catalogue groups all of them under the base display code 58.
    final catalogueDialShape = screenWidth == 410 && screenHeight == 502
        ? 58
        : reportedDialShape;
    return DeviceWatchFaceMarketProfile(
      dialShape: catalogueDialShape,
      binProtocol: number('binProtocol', catalogue.binProtocol),
      maxLength: number('maxLength', catalogue.maxLength),
      deviceNumber: number('deviceNumber', catalogue.deviceNumber),
      deviceTestVersion:
          '${value['deviceTestVersion'] ?? value['deviceVersion'] ?? ''}'
              .trim()
              .isNotEmpty
          ? '${value['deviceTestVersion'] ?? value['deviceVersion']}'.trim()
          : catalogue.deviceTestVersion,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
  }

  /// Safe fallback for the currently supplied W9S hardware. The connected
  /// device profile returned by the SDK always takes precedence.
  static const w9s = DeviceWatchFaceMarketProfile(
    dialShape: 58,
    binProtocol: 2,
    maxLength: 614733,
    deviceNumber: 6702,
    deviceTestVersion: '11.95.01.00',
    screenWidth: 410,
    screenHeight: 502,
  );

  final int dialShape;
  final int binProtocol;
  final int maxLength;
  final int deviceNumber;
  final String deviceTestVersion;
  final int screenWidth;
  final int screenHeight;
}

/// Loads the Veepoo/JL online watch-face catalogue.
///
/// Veepoo's catalogue endpoint expects the binary compatibility profile used
/// by its network-dial manager. Every compatibility field comes from the
/// authenticated device session; the W9S profile is only a test/fallback value
/// and must not be used to open the market for an unidentified device.
class DeviceWatchFaceMarketService {
  DeviceWatchFaceMarketService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint =
      'https://www.vphband.com:9001/api/system/getthemespage';
  static const _pageSize = 12;

  Future<DeviceWatchFaceMarketPageData> loadPage({
    int page = 1,
    DeviceWatchFaceMarketProfile profile = DeviceWatchFaceMarketProfile.w9s,
  }) async {
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'dialShape': '${profile.dialShape}',
        'binProtocol': '${profile.binProtocol}',
        'maxLength': '${profile.maxLength}',
        'deviceNumber': '${profile.deviceNumber}',
        'deviceVersion': profile.deviceTestVersion,
        'appType': 'android',
        'appVersion': '1.28.7',
        'pageIndex': '${page < 1 ? 1 : page}',
        'pageSize': '$_pageSize',
      },
    );
    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const DeviceWatchFaceMarketException('网络不可用，请检查网络后重试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DeviceWatchFaceMarketException('表盘商城暂时无法访问，请稍后重试');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const DeviceWatchFaceMarketException('表盘商城返回了无法识别的数据');
    }
    if (decoded is! Map) {
      throw const DeviceWatchFaceMarketException('表盘商城返回了无法识别的数据');
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

  Future<String> download(
    DeviceWatchFaceMarketItem item, {
    void Function(double progress)? onProgress,
  }) async {
    http.StreamedResponse response;
    try {
      final request = http.Request('GET', item.fileUrl);
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const DeviceWatchFaceMarketException('表盘下载失败，请检查网络后重试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DeviceWatchFaceMarketException('表盘下载失败，请稍后重试');
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
      throw const DeviceWatchFaceMarketException('表盘下载中断，请重试');
    }
    await sink.close();
    if (received <= 0 || (item.fileLength > 0 && received != item.fileLength)) {
      if (await file.exists()) await file.delete();
      throw const DeviceWatchFaceMarketException('表盘文件不完整，请重新下载');
    }
    onProgress?.call(1);
    return file.path;
  }
}
