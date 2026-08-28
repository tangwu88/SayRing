import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/services/device_watch_face_market_service.dart';

void main() {
  test(
    'keeps the vendor catalogue protocol with a runtime display profile',
    () {
      final profile = DeviceWatchFaceMarketProfile.fromMap({
        'dialShape': 126,
        'screenWidth': 410,
        'screenHeight': 502,
        'binProtocol': 99,
        'maxLength': 1,
        'deviceNumber': 1,
        'deviceTestVersion': 'device-firmware',
      });

      expect(profile.dialShape, 58);
      expect(profile.screenWidth, 410);
      expect(profile.screenHeight, 502);
      expect(profile.binProtocol, 99);
      expect(profile.maxLength, 1);
      expect(profile.deviceNumber, 1);
      expect(profile.deviceTestVersion, 'device-firmware');
    },
  );

  test(
    'loads the W9S market profile and parses available watch faces',
    () async {
      late Uri requested;
      final service = DeviceWatchFaceMarketService(
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

      final result = await service.loadPage();

      expect(requested.host, 'www.vphband.com');
      expect(requested.queryParameters['dialShape'], '58');
      expect(requested.queryParameters['binProtocol'], '2');
      expect(requested.queryParameters['deviceNumber'], '6702');
      expect(requested.queryParameters['deviceVersion'], '11.95.01.00');
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
      client: MockClient((_) async => http.Response('not-json', 200)),
    );

    await expectLater(
      service.loadPage(),
      throwsA(
        isA<DeviceWatchFaceMarketException>().having(
          (error) => error.message,
          'message',
          contains('无法识别'),
        ),
      ),
    );
  });
}
