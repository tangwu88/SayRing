import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/services/app_update_service.dart';

const _origin = 'https://app.saydian.cn';
const _path = '/global/down/files/Saydian-global.apk';
final _bytes = <int>[0, 1, 2, 3, 255];

AppUpdateInfo _info({String url = '$_origin$_path', String? hash}) =>
    AppUpdateInfo(
      currentVersion: '0.1.0',
      currentBuild: 1,
      latestVersion: '0.2.0',
      latestBuild: 2,
      minimumSupportedBuild: 0,
      destinationType: AppUpdateDestinationType.androidApk,
      destinationUri: Uri.parse(url),
      releaseNotes: '',
      publishedAt: DateTime.utc(2026, 9, 9),
      sha256: hash ?? sha256.convert(_bytes).toString(),
    );

class _RequestClient extends http.BaseClient {
  _RequestClient(this.respond);

  final http.StreamedResponse Function(http.BaseRequest request) respond;
  final requests = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    if (request.followRedirects) {
      throw StateError('Automatic redirects must never be enabled.');
    }
    return respond(request);
  }
}

http.StreamedResponse _redirect(
  http.BaseRequest request,
  String? location, {
  int status = 302,
}) => http.StreamedResponse(
  const Stream<List<int>>.empty(),
  status,
  request: request,
  headers: {'location': ?location},
);

http.StreamedResponse _success(http.BaseRequest request) =>
    http.StreamedResponse(
      Stream.value(_bytes),
      200,
      contentLength: _bytes.length,
      request: request,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final installed = <MethodCall>[];
  const channel = MethodChannel('saydian/global-update-redirect-test');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('saydian-update-guard-');
    installed.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          installed.add(call);
          return null;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  AndroidApkUpdateInstaller installer(http.Client client) =>
      AndroidApkUpdateInstaller.global(
        client: client,
        isAndroid: true,
        temporaryDirectory: () async => directory,
        channel: channel,
      );

  final unsafeTargets = <String, String>{
    'legacy host': 'https://app.saidian.cc$_path',
    'other host': 'https://untrusted.invalid$_path',
    'HTTP downgrade': 'http://app.saydian.cn$_path',
    'non-443 port': 'https://app.saydian.cn:8443$_path',
    'userinfo': 'https://user:password@app.saydian.cn$_path',
    'domestic download path': '$_origin/down/files/Saydian.apk',
    'query': '$_origin$_path?target=legacy',
    'fragment': '$_origin$_path#legacy',
    'encoded path escape': '$_origin/global/down/files/%2Foutside.apk',
    'path traversal': '$_origin/global/down/files/../../../down/a.apk',
  };

  for (final target in unsafeTargets.entries) {
    test(
      'global initial ${target.key} is rejected before any request',
      () async {
        final client = _RequestClient(_success);
        await expectLater(
          installer(client).downloadAndInstall(_info(url: target.value)),
          throwsA(isA<AppUpdateException>()),
        );
        expect(client.requests, isEmpty);
        expect(installed, isEmpty);
      },
    );
    for (final status in [302, 307]) {
      test('$status ${target.key} never receives a second request', () async {
        final client = _RequestClient(
          (request) => _redirect(request, target.value, status: status),
        );
        await expectLater(
          installer(client).downloadAndInstall(_info()),
          throwsA(isA<AppUpdateException>()),
        );
        expect(client.requests, [Uri.parse('$_origin$_path')]);
        expect(installed, isEmpty);
      });
    }
  }

  test(
    'same-origin redirects stay in the global directory and install',
    () async {
      final client = _RequestClient(
        (request) => switch (request.url.path) {
          _path => _redirect(request, 'Saydian-step-1.apk', status: 301),
          '/global/down/files/Saydian-step-1.apk' => _redirect(
            request,
            '/global/down/files/Saydian-step-2.apk',
            status: 303,
          ),
          '/global/down/files/Saydian-step-2.apk' => _redirect(
            request,
            '$_origin/global/down/files/Saydian-final.apk',
            status: 308,
          ),
          _ => _success(request),
        },
      );
      await installer(client).downloadAndInstall(_info());
      expect(client.requests, hasLength(4));
      expect(installed.single.method, 'installApk');
      final filePath =
          (installed.single.arguments as Map)['filePath'] as String;
      expect(await File(filePath).readAsBytes(), _bytes);
    },
  );

  test('redirect loops stop before issuing a repeated request', () async {
    final client = _RequestClient((request) => _redirect(request, _path));
    await expectLater(
      installer(client).downloadAndInstall(_info()),
      throwsA(isA<AppUpdateException>()),
    );
    expect(client.requests, hasLength(1));
    expect(installed, isEmpty);
  });

  test('more than three redirects never issues the fifth request', () async {
    var count = 0;
    final client = _RequestClient(
      (request) => _redirect(request, '/global/down/files/next-${++count}.apk'),
    );
    await expectLater(
      installer(client).downloadAndInstall(_info()),
      throwsA(isA<AppUpdateException>()),
    );
    expect(client.requests, hasLength(4));
    expect(installed, isEmpty);
  });

  for (final location in [null, '', 'http://[invalid']) {
    test('missing or invalid Location is rejected: $location', () async {
      final client = _RequestClient((request) => _redirect(request, location));
      await expectLater(
        installer(client).downloadAndInstall(_info()),
        throwsA(isA<AppUpdateException>()),
      );
      expect(client.requests, hasLength(1));
      expect(installed, isEmpty);
    });
  }

  test(
    'global installer rejects absent hash before requesting package',
    () async {
      final client = _RequestClient(_success);
      await expectLater(
        installer(client).downloadAndInstall(_info(hash: '')),
        throwsA(isA<AppUpdateException>()),
      );
      expect(client.requests, isEmpty);
      expect(installed, isEmpty);
    },
  );

  test('corrupt redirected package never reaches the installer', () async {
    final client = _RequestClient(
      (request) => request.url.path == _path
          ? _redirect(request, 'other.apk')
          : _success(request),
    );
    await expectLater(
      installer(client).downloadAndInstall(_info(hash: '0' * 64)),
      throwsA(isA<AppUpdateException>()),
    );
    expect(client.requests, hasLength(2));
    expect(installed, isEmpty);
    expect(
      await directory.list(recursive: true).where((f) => f is File).toList(),
      isEmpty,
    );
  });

  test(
    'generic manifest rejects old-host redirect before second request',
    () async {
      final client = _RequestClient(
        (request) => _redirect(request, 'https://app.saidian.cc/version'),
      );
      final service = AppUpdateService(
        client: client,
        endpointUri: Uri.parse(
          '$_origin/global/api/saydian-app/v2/support/app-update',
        ),
        targetPlatform: TargetPlatform.android,
        packageInfoLoader: () async => PackageInfo(
          appName: 'Saydian',
          packageName: 'cn.saydian.app.global',
          version: '0.1.0',
          buildNumber: '1',
        ),
      );
      await expectLater(service.check(), throwsA(isA<AppUpdateException>()));
      expect(client.requests, hasLength(1));
    },
  );
}
