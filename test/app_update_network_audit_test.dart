import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/services/app_update_service.dart';
import 'package:saydian_app/services/network_audit.dart';

const _origin = 'https://app.saydian.cn';
const _path = '/global/down/files/Say-Ring-audit-private-path.apk';
const _requestId = '00000000-0000-4000-8000-000000000001';
const _secret = 'private-value-never-log';
const _bytes = [1, 3, 5, 7];

Future<PackageInfo> _package() async => PackageInfo(
  appName: 'Say Ring',
  packageName: 'cn.saydian.ring',
  version: '0.1.0',
  buildNumber: '1',
);

GlobalAppUpdateService _global(http.Client client) => GlobalAppUpdateService(
  client: client,
  targetPlatform: TargetPlatform.android,
  packageInfoLoader: _package,
);

AppUpdateInfo _info({String url = '$_origin$_path'}) => AppUpdateInfo(
  currentVersion: '0.1.0',
  currentBuild: 1,
  latestVersion: '0.2.0',
  latestBuild: 2,
  minimumSupportedBuild: 0,
  destinationType: AppUpdateDestinationType.androidApk,
  destinationUri: Uri.parse(url),
  releaseNotes: _secret,
  publishedAt: DateTime.utc(2026, 9, 10),
  sha256: sha256.convert(_bytes).toString(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DebugPrintCallback previousDebugPrint;
  late List<String> messages;
  late Directory temporary;
  const channel = MethodChannel('saydian/global-update-audit-test');

  setUp(() async {
    messages = [];
    previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    temporary = await Directory.systemTemp.createTemp('saydian-update-audit-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });
  tearDown(() async {
    debugPrint = previousDebugPrint;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await temporary.delete(recursive: true);
  });

  List<Map<String, Object?>> events() => [
    for (final message in messages)
      if (message.startsWith('[SaydianNetwork] '))
        Map<String, Object?>.from(jsonDecode(message.substring(17)) as Map),
  ];

  void expectPrivate(List<Map<String, Object?>> audit) {
    final encoded = jsonEncode(audit);
    expect(encoded, isNot(contains(_secret)));
    expect(encoded, isNot(contains(_path)));
    expect(encoded, isNot(contains('content-body')));
    expect(encoded, isNot(contains('authorization')));
    for (final event in audit) {
      expect(event['host'], 'app.saydian.cn');
      expect(
        event.keys,
        everyElement(
          isIn([
            'host',
            'port',
            'method',
            'kind',
            'routeHash',
            'status',
            'requestId',
            'outcome',
          ]),
        ),
      );
      expect(event['routeHash'], matches(r'^[a-f0-9]{12}$'));
    }
  }

  AndroidApkUpdateInstaller installer(http.Client client) =>
      AndroidApkUpdateInstaller.global(
        client: client,
        isAndroid: true,
        temporaryDirectory: () async => temporary,
        channel: channel,
      );

  for (final status in [200, 404]) {
    test(
      'global manifest records status $status and a safe requestId before parsing',
      () async {
        final client = MockClient((request) async {
          expect(NetworkAudit.recent.last['outcome'], 'request_started');
          return http.Response(
            'content-body-$_secret',
            status,
            headers: {'x-request-id': _requestId, 'authorization': _secret},
          );
        });
        if (status == 404) {
          final info = await _global(client).check();
          expect(info.hasUpdate, isFalse);
        } else {
          await expectLater(
            _global(client).check(),
            throwsA(isA<AppUpdateException>()),
          );
        }
        final audit = events();
        expect(audit, hasLength(2));
        expect(audit.last['status'], status);
        expect(audit.last['requestId'], _requestId);
        expect(audit.last['kind'], 'update_manifest');
        expectPrivate(audit);
      },
    );
  }

  test(
    'global manifest redirect is recorded without following or logging Location',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          302,
          headers: {
            'location': 'https://app.saidian.cc/$_secret',
            'x-request-id': _requestId,
          },
        );
      });
      await expectLater(
        _global(client).check(),
        throwsA(isA<AppUpdateException>()),
      );
      expect(calls, 1);
      expect(events().last['status'], 302);
      expectPrivate(events());
    },
  );

  test('generic manifest omits query and invalid server requestId', () async {
    final service = AppUpdateService(
      client: MockClient(
        (_) async => http.Response(
          'content-body-$_secret',
          404,
          headers: {'x-request-id': _secret},
        ),
      ),
      targetPlatform: TargetPlatform.android,
      packageInfoLoader: _package,
      endpointUri: Uri.parse('$_origin/global/$_secret.json?token=$_secret'),
    );
    await expectLater(service.check(), throwsA(isA<AppUpdateException>()));
    final audit = events();
    expect(audit, hasLength(2));
    expect(audit.last['status'], 404);
    expect(audit.last.containsKey('requestId'), isFalse);
    expectPrivate(audit);
  });

  test(
    'APK records each validated hop and keeps hash and install gates',
    () async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        expect(NetworkAudit.recent.last['outcome'], 'request_started');
        expect(request.followRedirects, isFalse);
        if (requests.length == 1) {
          return http.Response(
            '',
            307,
            headers: {
              'location': '/global/down/files/Saydian-audit-final.apk',
              'x-request-id': _requestId,
            },
          );
        }
        return http.Response.bytes(
          _bytes,
          200,
          headers: {'x-request-id': _requestId},
        );
      });
      await installer(client).downloadAndInstall(_info());
      final audit = events();
      expect(requests, hasLength(2));
      expect(audit, hasLength(4));
      expect(audit.map((event) => event['kind']), everyElement('update_apk'));
      expect(
        audit
            .where((event) => event.containsKey('status'))
            .map((event) => event['status']),
        [307, 200],
      );
      expect(audit.last['requestId'], _requestId);
      expectPrivate(audit);
    },
  );

  test(
    'invalid APK preflight sends nothing and logs no pretend request',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response.bytes(_bytes, 200);
      });
      await expectLater(
        installer(
          client,
        ).downloadAndInstall(_info(url: 'https://app.saidian.cc/$_secret.apk')),
        throwsA(isA<AppUpdateException>()),
      );
      expect(calls, 0);
      expect(events(), isEmpty);
    },
  );

  test('blocked APK redirect records only the allowed first hop', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(
        '',
        302,
        headers: {
          'location': 'https://app.saidian.cc/$_secret.apk',
          'x-request-id': '$_secret-invalid',
        },
      );
    });
    await expectLater(
      installer(client).downloadAndInstall(_info()),
      throwsA(isA<AppUpdateException>()),
    );
    expect(calls, 1);
    final audit = events();
    expect(audit, hasLength(2));
    expect(audit.last['status'], 302);
    expect(audit.last.containsKey('requestId'), isFalse);
    expectPrivate(audit);
  });

  test(
    'network failure logs only the attempt, never exception contents',
    () async {
      final client = MockClient(
        (_) async => throw http.ClientException(_secret),
      );
      await expectLater(
        _global(client).check(),
        throwsA(isA<AppUpdateException>()),
      );
      final audit = events();
      expect(audit, hasLength(1));
      expect(audit.single['outcome'], 'request_started');
      expect(audit.single.containsKey('status'), isFalse);
      expectPrivate(audit);
    },
  );
}
