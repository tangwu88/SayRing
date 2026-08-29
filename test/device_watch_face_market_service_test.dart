import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/services/device_watch_face_market_service.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/watch_face_market_page.dart';

void main() {
  test('watch-face async load gate rejects replaced requests and devices', () {
    final gate = WatchFaceLoadRequestGate();
    final first = gate.begin();
    expect(
      gate.accepts(
        token: first,
        requestedDeviceId: 'veepoo:watch-a',
        currentDeviceId: 'veepoo:watch-a',
      ),
      isTrue,
    );
    final second = gate.begin();
    expect(
      gate.accepts(
        token: first,
        requestedDeviceId: 'veepoo:watch-a',
        currentDeviceId: 'veepoo:watch-a',
      ),
      isFalse,
    );
    expect(
      gate.accepts(
        token: second,
        requestedDeviceId: 'veepoo:watch-a',
        currentDeviceId: 'veepoo:watch-b',
      ),
      isFalse,
    );
    gate.invalidate();
    expect(
      gate.accepts(
        token: second,
        requestedDeviceId: 'veepoo:watch-a',
        currentDeviceId: 'veepoo:watch-a',
      ),
      isFalse,
    );
  });

  final profile = DeviceWatchFaceMarketProfile.fromMap({
    'onlineMarketSupported': true,
    'profileVersion': 1,
    'profileFingerprintAlgorithm': 'sha256',
    'provider': 'Vep',
    'deviceId': 'device-1',
    'deviceLabel': 'SD-Watch-W9S',
    'dialShape': 58,
    'screenWidth': 410,
    'screenHeight': 502,
    'binProtocol': 2,
    'maxLength': 614733,
    'deviceNumber': 6702,
    'deviceTestVersion': 'device-firmware',
    'slotCount': 1,
    'profileFingerprint':
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  });

  test(
    'requires a complete runtime profile without W9S production defaults',
    () {
      expect(profile.dialShape, 58);
      expect(profile.screenWidth, 410);
      expect(profile.screenHeight, 502);
      expect(profile.binProtocol, 2);
      expect(profile.maxFileLength, 614733);
      expect(profile.deviceNumber, 6702);
      expect(profile.firmwareVersion, 'device-firmware');
      expect(profile.matchesDevice('veepoo:device-1'), isTrue);
      expect(profile.matchesDevice('yucheng:device-1'), isFalse);
      expect(profile.matchesDevice('device-2'), isFalse);
      expect(
        () => DeviceWatchFaceMarketProfile.fromMap({
          'onlineMarketSupported': true,
          'dialShape': 58,
        }),
        throwsA(isA<DeviceWatchFaceMarketException>()),
      );
      expect(
        () => DeviceWatchFaceMarketProfile.fromMap({
          'onlineMarketSupported': true,
          'profileVersion': 1,
          'profileFingerprintAlgorithm': 'sha256',
          'provider': 'Vep',
          'deviceId': 'device-1',
          'deviceLabel': 'SD-Watch-W9S',
          'dialShape': 58,
          'width': 410,
          'screenWidth': 390,
          'height': 502,
          'screenHeight': 502,
          'binProtocol': 2,
          'maxFileLength': 614733,
          'maxLength': 614733,
          'deviceNumber': 6702,
          'firmware': 'device-firmware',
          'deviceTestVersion': 'device-firmware',
          'slotCount': 1,
          'profileFingerprint':
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        }),
        throwsA(isA<DeviceWatchFaceMarketException>()),
      );
    },
  );

  test(
    'loads the W9S market profile and parses available watch faces',
    () async {
      late Uri requested;
      final service = DeviceWatchFaceMarketService(
        appVersionLoader: () async => '0.1.19',
        client: MockClient((request) async {
          requested = request.url;
          return http.Response('''
          {
            "pageIndex": 1,
            "pageCount": 14,
            "counts": 160,
            "results": [
              {
                "name": "296JL041",
                "fileLenght": 189520,
                "fileUrl": "https://www.vphband.com/themebin/watch041",
                "previewUrl": "https://www.vphband.com/themebin/watch041.png",
                "crc": 47136,
                "binProtocol": 2,
                "dialShape": 58,
                "available": true
              },
              {
                "name": "disabled",
                "fileLenght": 100,
                "fileUrl": "https://www.vphband.com/themebin/disabled",
                "previewUrl": "https://www.vphband.com/themebin/disabled.png",
                "available": false
              }
            ]
          }
        ''', 200);
        }),
      );

      final result = await service.loadPage(profile: profile);

      expect(requested.host, 'www.vphband.com');
      expect(requested.queryParameters['dialShape'], '58');
      expect(requested.queryParameters['binProtocol'], '2');
      expect(requested.queryParameters['deviceNumber'], '6702');
      expect(requested.queryParameters['deviceVersion'], 'device-firmware');
      expect(result.pageCount, 14);
      expect(result.total, 160);
      expect(result.items, hasLength(1));
      expect(result.items.single.name, '296JL041');
      expect(result.items.single.fileLength, 189520);
      expect(result.items.single.crc, 47136);
      expect(result.items.single.binProtocol, 2);
      expect(result.items.single.dialShape, 58);
    },
  );

  test('reports malformed market responses as a user facing error', () async {
    final service = DeviceWatchFaceMarketService(
      appVersionLoader: () async => '0.1.19',
      client: MockClient((_) async => http.Response('not-json', 200)),
    );

    await expectLater(
      service.loadPage(profile: profile),
      throwsA(
        isA<DeviceWatchFaceMarketException>().having(
          (error) => error.message,
          'message',
          contains('无法识别'),
        ),
      ),
    );
  });

  test(
    'iOS native catalogue preserves the SDK id and blocks Android HTTP',
    () async {
      final native = NativeWatchFaceCatalogItem(
        id: 'session-bound-id',
        name: 'SDK 表盘',
        fileUrl: Uri.parse('https://vendor.example/watch.bin'),
        previewUrl: Uri.parse('https://vendor.example/watch.png'),
        crc: 42,
        binProtocol: 2,
        dialShape: 58,
      );
      final mapped = DeviceWatchFaceMarketItem.fromNative(native);
      expect(mapped.nativeCatalogId, native.id);
      expect(mapped.fileLength, 0);
      expect(mapped.crc, 42);

      final directory = await Directory.systemTemp.createTemp(
        'ios-dial-guard-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final service = DeviceWatchFaceMarketService(
        directCatalogueAllowed: false,
        supportDirectory: () async => directory,
      );
      await expectLater(
        service.loadPage(profile: profile),
        throwsA(
          isA<DeviceWatchFaceMarketException>().having(
            (error) => error.message,
            'message',
            contains('手表 SDK'),
          ),
        ),
      );
    },
  );

  test('matches an installed watch path to the official preview resource', () {
    final service = DeviceWatchFaceMarketService();
    final item = DeviceWatchFaceMarketItem.fromMap({
      'name': 'watch146',
      'fileLenght': 1000,
      'fileUrl': 'https://www.vphband.com/themebin/watch146.bin',
      'previewUrl': 'https://www.vphband.com/themebin/watch146.png',
      'binProtocol': 2,
      'dialShape': 58,
    });

    expect(service.matchInstalledPath('/WATCH146', [item]), same(item));
  });

  test(
    'missing local previews fall through to the official catalogue',
    () async {
      final service = DeviceWatchFaceMarketService();
      expect(
        service.hasUsablePreviewReference({
          'previewPath': '/definitely/missing/watch-face.png',
        }),
        isFalse,
      );
      expect(
        service.hasUsablePreviewReference({
          'previewUrl': 'https://www.vphband.com/themebin/watch146.png',
        }),
        isTrue,
      );
      expect(
        DeviceWatchFaceMarketService.findUsablePreviewReference({
          'previewPath': '/definitely/missing/watch-face.png',
          'previewUrl': 'https://www.vphband.com/themebin/watch146.png',
        }),
        'https://www.vphband.com/themebin/watch146.png',
      );
      final directory = await Directory.systemTemp.createTemp('dial-preview-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/preview.png');
      await file.writeAsBytes([1, 2, 3]);
      expect(
        service.hasUsablePreviewReference({'previewPath': file.path}),
        isTrue,
      );
    },
  );
}
