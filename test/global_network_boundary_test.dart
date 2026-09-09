import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/services/global_environment.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/network_audit.dart';
import 'package:saydian_app/services/safe_resource_client.dart';

void main() {
  const root = 'https://app.saydian.cn';
  const file = '$root/global/api/saydian-app/v2/files/test/content';

  test('explicit client origin cannot bypass the production boundary', () {
    var sent = 0;
    final inner = MockClient((_) async {
      sent++;
      return http.Response('', 200);
    });
    for (final url in [
      'https://app.saidian.cc',
      'https://app.saydian.cn:444',
      'http://127.0.0.1:8082',
      'https://other.example',
    ]) {
      expect(
        () => GlobalSaydianApiClient(
          MemorySessionVault(),
          client: inner,
          baseUri: Uri.parse(url),
        ),
        throwsArgumentError,
      );
    }
    expect(sent, 0);
    inner.close();
  });

  test('global canonical API maps to isolated gateway only', () {
    final deployed = GlobalEnvironment.deployedPath(
      '/api/saydian-app/v2/auth/login',
    );
    expect(deployed, '/global/api/saydian-app/v2/auth/login');
    expect(GlobalEnvironment.resolve(Uri.parse(root), deployed).origin, root);
    expect(
      GlobalEnvironment.storageNamespace,
      matches(RegExp(r'^[a-f0-9]{64}$')),
    );
  });

  for (final url in [
    'https://app.saidian.cc/file',
    'https://sd.cc/file',
    'https://files.sd.cc/file',
    'https://cdn.example.com/file',
    '$root/api/saydian-app/v2/files/test/content',
    'http://app.saydian.cn/global/media/a.png',
    'https://app.saydian.cn:444/global/media/a.png',
    'https://user:secret@app.saydian.cn/global/media/a.png',
    '$file#private',
    '$root/global/api/saydian-app/v2/%252e%252e/a',
  ]) {
    test('untrusted resource is blocked before transport: $url', () async {
      var sent = 0;
      final client = SafeResourceClient(
        purpose: ResourcePurpose.image,
        inner: MockClient((_) async {
          sent++;
          return http.Response('', 200);
        }),
      );
      expect(GlobalEnvironment.media(url), isEmpty);
      await expectLater(
        client.get(Uri.parse(url)),
        throwsA(isA<http.ClientException>()),
      );
      expect(sent, 0);
      client.close();
    });
  }

  for (final code in [301, 302, 303, 307, 308]) {
    test('image $code never follows old-domain redirect', () async {
      var sent = 0;
      final client = SafeResourceClient(
        purpose: ResourcePurpose.image,
        inner: MockClient((request) async {
          sent++;
          expect(request.followRedirects, isFalse);
          return http.Response(
            '',
            code,
            headers: {'location': 'https://app.saidian.cc/stolen'},
          );
        }),
      );
      await expectLater(
        client.get(Uri.parse(file)),
        throwsA(isA<http.ClientException>()),
      );
      expect(sent, 1);
      client.close();
    });
  }

  test(
    'approved global media and official watch previews use safe transport',
    () async {
      final client = SafeResourceClient(
        purpose: ResourcePurpose.image,
        inner: MockClient((request) async {
          expect(request.followRedirects, isFalse);
          return http.Response('image', 200);
        }),
      );
      expect((await client.get(Uri.parse(file))).statusCode, 200);
      expect(
        (await client.get(
          Uri.parse('https://www.vphband.com/themebin/1.png'),
        )).statusCode,
        200,
      );
      expect(
        GlobalEnvironment.media('https://www.vphband.com/themebin/1.png'),
        isEmpty,
        reason: 'business media cannot claim a vendor exception',
      );
      client.close();
    },
  );

  test(
    'vendor lists do not grant access to first-party auth or arbitrary hosts',
    () {
      final weather = SafeResourceClient(purpose: ResourcePurpose.weather);
      final watch = SafeResourceClient(purpose: ResourcePurpose.watchFace);
      expect(
        weather.allows(
          Uri.parse('https://ny2tuqge5v.re.qweatherapi.com/v7/weather/7d'),
        ),
        isTrue,
      );
      expect(weather.allows(Uri.parse(file)), isFalse);
      expect(
        watch.allows(
          Uri.parse('https://www.vphband.com:9001/api/system/getthemespage'),
        ),
        isTrue,
      );
      expect(
        watch.allows(Uri.parse('https://vphband.com.attacker.example/file')),
        isFalse,
      );
      expect(watch.allows(Uri.parse(file)), isFalse);
      weather.close();
      watch.close();
    },
  );

  test('audit omits secrets, identifiers and bodies', () {
    NetworkAudit.record(
      Uri.parse('$file?token=never-log-this&email=private'),
      'GET',
      'api',
      status: 200,
      requestId: 'malicious-token-value',
    );
    final event = jsonEncode(NetworkAudit.recent.last);
    expect(event, isNot(contains('never-log-this')));
    expect(event, isNot(contains('/files/test')));
    expect(event, isNot(contains('malicious-token-value')));
    expect(event, contains('app.saydian.cn'));
  });

  test(
    'failed resource transport still records only a redacted attempt',
    () async {
      final client = SafeResourceClient(
        purpose: ResourcePurpose.image,
        inner: MockClient(
          (_) async => throw Exception('private transport detail'),
        ),
      );
      await expectLater(
        client.get(Uri.parse('$file?token=private-query')),
        throwsA(isA<Exception>()),
      );
      final event = NetworkAudit.recent.last;
      expect(event['outcome'], 'sending');
      expect(event['host'], 'app.saydian.cn');
      expect(jsonEncode(event), isNot(contains('private')));
      client.close();
    },
  );

  test(
    'formal origin rejects nonstandard ports and local product overrides',
    () {
      for (final url in [
        'https://app.saydian.cn:444',
        'http://127.0.0.1:8082',
      ]) {
        expect(
          () => GlobalEnvironment.validateOrigin(
            url,
            allowLocalDebug: true,
            isProduct: true,
          ),
          throwsArgumentError,
        );
      }
    },
  );
}
