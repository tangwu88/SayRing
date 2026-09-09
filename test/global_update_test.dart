import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/services/app_update_service.dart';

Map<String, Object?> manifest({
  String realm = 'global',
  String package = 'cn.saydian.app.global',
  String url = '/global/down/files/Saydian-global.apk',
  String? hash,
}) => {
  'realm': realm,
  'schemaVersion': 1,
  'audience': 'internal_test',
  'publishedAt': '2026-09-09T00:00:00Z',
  'releases': [
    {
      'platform': 'android',
      'packageId': package,
      'versionName': '0.2.0',
      'buildNumber': 24,
      'status': 'available',
      'destination': {
        'kind': 'direct',
        'url': url,
        'sha256': hash ?? List.filled(64, 'a').join(),
      },
    },
  ],
};

GlobalAppUpdateService service(
  Object data, {
  String package = 'cn.saydian.app.global',
}) => GlobalAppUpdateService(
  client: MockClient((request) async {
    expect(
      request.url.toString(),
      'https://app.saydian.cn/api/saydian-app/v2/support/app-update',
    );
    expect(request.followRedirects, isFalse);
    return http.Response(jsonEncode({'code': 200, 'data': data}), 200);
  }),
  targetPlatform: TargetPlatform.android,
  packageInfoLoader: () async => PackageInfo(
    appName: 'Saydian',
    packageName: package,
    version: '0.1.0',
    buildNumber: '1',
  ),
);

void main() {
  test(
    'iOS accepts only an explicit global TestFlight or App Store destination',
    () async {
      for (final kind in ['testflight', 'app_store']) {
        final url = kind == 'testflight'
            ? 'https://testflight.apple.com/join/TestOnly123'
            : 'https://apps.apple.com/us/app/saydian/id1234567890';
        final data = {
          ...manifest(),
          'releases': [
            {
              'platform': 'ios',
              'packageId': 'cn.saydian.app.global',
              'versionName': '0.2.0',
              'buildNumber': 24,
              'status': 'available',
              'destination': {'kind': kind, 'url': url},
            },
          ],
        };
        final client = GlobalAppUpdateService(
          client: MockClient(
            (request) async =>
                http.Response(jsonEncode({'code': 200, 'data': data}), 200),
          ),
          targetPlatform: TargetPlatform.iOS,
          packageInfoLoader: () async => PackageInfo(
            appName: 'Saydian',
            packageName: 'cn.saydian.app.global',
            version: '0.1.0',
            buildNumber: '1',
          ),
        );
        final info = await client.check();
        expect(
          info.destinationType,
          kind == 'testflight'
              ? AppUpdateDestinationType.testFlight
              : AppUpdateDestinationType.appStore,
        );
        expect(info.destinationUri.toString(), url);
        expect(info.forceUpdate, isFalse);
      }
    },
  );
  test(
    'global updates accept only explicit global identity and hash',
    () async {
      final info = await service(manifest()).check();
      expect(info.hasUpdate, isTrue);
      expect(info.destinationUri.path, '/global/down/files/Saydian-global.apk');
      expect(info.sha256, hasLength(64));
      expect(info.forceUpdate, isFalse);
    },
  );
  test(
    'domestic package, domain, prefix, missing hash and fake realm are rejected',
    () async {
      for (final data in [
        manifest(realm: 'domestic'),
        manifest(package: 'cc.saidian.saydian_app'),
        manifest(url: '/down/files/Saydian.apk'),
        manifest(url: 'https://app.saidian.cc/global/down/files/Saydian.apk'),
        manifest(hash: ''),
        manifest(url: '//app.saidian.cc/global/down/files/a.apk'),
      ]) {
        await expectLater(
          service(data).check(),
          throwsA(isA<AppUpdateException>()),
        );
      }
      await expectLater(
        service(manifest(), package: 'cc.saidian.saydian_app').check(),
        throwsA(isA<AppUpdateException>()),
      );
    },
  );
  test(
    'unpublished release does not pretend up to date or installable',
    () async {
      await expectLater(
        service({
          ...manifest(),
          'releases': [
            {
              'platform': 'android',
              'packageId': 'cn.saydian.app.global',
              'status': 'coming_soon',
            },
          ],
        }).check(),
        throwsA(isA<AppUpdateException>()),
      );
    },
  );
}
