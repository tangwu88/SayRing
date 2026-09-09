import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/domain/global_care.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/global_environment.dart';
import 'package:saydian_app/services/secure_vault.dart';

http.Response ok(Object? data) => http.Response(
  jsonEncode({'code': 200, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, Object?> sessionData([String id = 'uuid-member-α']) => {
  'accessToken': 'global-test-access',
  'refreshToken': 'global-test-refresh',
  'expiresAt': '2099-01-01T00:00:00Z',
  'member': {'id': id, 'nickname': 'Test'},
};
Session session([String id = 'member-a']) => Session(
  accessToken: 'global-test-access',
  refreshToken: 'global-test-refresh',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  displayName: 'Test',
  accountKey: 'global:member:$id',
);
Map<String, Object?> capabilities({bool email = true, bool sms = true}) => {
  'realm': 'global',
  'registration': {'email': email, 'sms': sms},
  'smsCountries': ['US', 'GB'],
  'supportedLocales': GlobalEnvironment.locales,
  'consentVersion': 'reviewed-test-v1',
  'legal': {
    'userAgreement': {
      'path':
          '/api/saydian-app/v2/content/legal/user_agreement?version=reviewed-test-v1&locale=en',
    },
    'privacyPolicy': {
      'path':
          '/api/saydian-app/v2/content/legal/privacy_policy?version=reviewed-test-v1&locale=en',
    },
  },
};

void main() {
  test('legacy auth entry points never submit a global request', () async {
    var requests = 0;
    final api = GlobalSaydianApiClient(
      MemorySessionVault(),
      client: MockClient((request) async {
        requests++;
        return ok({});
      }),
    );
    for (final invoke in <Future<Object?> Function()>[
      () => api.sendSmsCode(mobile: '+12025550123', usage: 'register'),
      () => api.registerWithSms(
        mobile: '+12025550123',
        code: '123456',
        password: 'Synthetic123',
        nickname: 'Synthetic',
      ),
      () => api.resetPassword(
        mobile: '+12025550123',
        code: '123456',
        password: 'Synthetic123',
      ),
    ]) {
      await expectLater(
        invoke(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'purpose-bound challenge required',
            'VERIFICATION_REQUIRED',
          ),
        ),
      );
    }
    expect(requests, 0);
  });
  group('identity', () {
    test('email normalization never merges provider-specific aliases', () {
      expect(
        GlobalAccountIdentity.email(' A.B+care@Example.com ').identifier,
        'a.b+care@example.com',
      );
      expect(
        GlobalAccountIdentity.email('AB@example.com').identifier,
        isNot('a.b+care@example.com'),
      );
    });
    test('country selection and E164 work beyond China', () {
      expect(
        GlobalAccountIdentity.phone('(202) 555-0123', country: 'US').identifier,
        '+12025550123',
      );
      expect(
        GlobalAccountIdentity.phone('020 7946 0018', country: 'GB').identifier,
        '+442079460018',
      );
      expect(GlobalAccountIdentity.phone('+49 1512 3456789').country, 'DE');
    });
    test('reject ambiguous numbers, prose and extensions', () {
      for (final value in [
        '2025550123',
        'call +12025550123',
        '+12025550123 ext 123',
        '*123#',
        '+123',
      ]) {
        expect(() => GlobalAccountIdentity.phone(value), throwsFormatException);
      }
    });
    test('capabilities fail closed for countries and domestic realm', () {
      final caps = GlobalAuthCapabilities.fromJson(capabilities());
      expect(caps.permits(GlobalAccountIdentity.phone('+12025550123')), isTrue);
      expect(
        caps.permits(GlobalAccountIdentity.phone('+4915123456789')),
        isFalse,
      );
      expect(
        GlobalAuthCapabilities.fromJson(
          capabilities(email: false),
        ).permits(GlobalAccountIdentity.email('a@example.com')),
        isFalse,
      );
      expect(
        () => GlobalAuthCapabilities.fromJson({
          ...capabilities(),
          'realm': 'domestic',
        }),
        throwsFormatException,
      );
    });
  });
  group('environment', () {
    test('all first-party paths and media are global with query preserved', () {
      final origin = Uri.parse(GlobalEnvironment.origin);
      expect(
        GlobalEnvironment.resolve(
          origin,
          '/api/saydian-app/v2/auth/capabilities?locale=de',
        ).toString(),
        'https://app.saydian.cn/global/api/saydian-app/v2/auth/capabilities?locale=de',
      );
      expect(
        GlobalEnvironment.resolve(origin, '/global/api/test').path,
        '/global/api/test',
      );
      expect(
        GlobalEnvironment.media('/files/avatar.jpg'),
        'https://app.saydian.cn/global/files/avatar.jpg',
      );
      expect(GlobalEnvironment.media('https://app.saidian.cc/avatar.jpg'), '');
      expect(
        GlobalEnvironment.media('https://app.saydian.cn/down/domestic.apk'),
        '',
      );
      expect(
        GlobalEnvironment.media('https://third-party.example/watchface.png'),
        isNotEmpty,
      );
      expect(
        () => GlobalEnvironment.resolve(origin, '//app.saidian.cc/api'),
        throwsArgumentError,
      );
      expect(
        () => GlobalEnvironment.resolve(origin, '/global/../api'),
        throwsArgumentError,
      );
    });
    test('day boundaries use local calendar, not Beijing offset', () {
      final range = globalLocalDayRange(DateTime(2026, 3, 8, 12));
      expect(range.from, DateTime(2026, 3, 8).toUtc());
      expect(range.to, DateTime(2026, 3, 9).toUtc());
    });
  });
  group('global auth', () {
    test(
      'login preserves opaque identifiers and does not use legacy credentials',
      () async {
        final vault = MemorySessionVault();
        final api = GlobalSaydianApiClient(
          vault,
          locale: () => 'de',
          client: MockClient((request) async {
            expect(
              request.url.toString(),
              '${GlobalEnvironment.origin}${GlobalEnvironment.apiPrefix}/auth/login',
            );
            expect(request.followRedirects, isFalse);
            expect(request.headers['token'], isNull);
            expect(request.headers['Accept-Language'], 'de');
            expect(jsonDecode(request.body), {
              'channel': 'email',
              'identifier': 'a+care@example.com',
              'password': 'password-test',
            });
            return ok(sessionData());
          }),
        );
        final result = await api.login('A+care@EXAMPLE.COM', 'password-test');
        expect(result.memberId, 'uuid-member-α');
        expect(result.accountKey, 'global:member:uuid-member-α');
        expect((await vault.readSession())?.accountKey, result.accountKey);
      },
    );
    test('malformed or domestic sessions never persist', () async {
      for (final data in [
        {
          'access_token': 'domestic-token',
          'member': {'id': 9},
        },
        {
          ...sessionData(),
          'member': {'id': 9},
        },
        {...sessionData(), 'expiresAt': 'bad'},
      ]) {
        final vault = MemorySessionVault();
        final api = GlobalSaydianApiClient(
          vault,
          client: MockClient((_) async => ok(data)),
        );
        await expectLater(
          api.login('a@example.com', 'password'),
          throwsA(isA<ApiException>()),
        );
        expect(await vault.readSession(), isNull);
      }
    });
    test('redirect never follows into domestic origin', () async {
      var calls = 0;
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((request) async {
          calls++;
          expect(request.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://app.saidian.cc/api/v1/login'},
          );
        }),
      );
      await expectLater(
        api.login('a@example.com', 'password'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
    });
    test(
      'provider disabled makes no send request and never fabricates challenge',
      () async {
        final requests = <Uri>[];
        final api = GlobalSaydianApiClient(
          MemorySessionVault(),
          client: MockClient((request) async {
            requests.add(request.url);
            return ok(capabilities(email: false));
          }),
        );
        await expectLater(
          api.requestVerification(
            identity: GlobalAccountIdentity.email('a@example.com'),
            purpose: 'register',
            locale: 'en',
          ),
          throwsA(isA<FeatureNotConfiguredException>()),
        );
        expect(requests.single.path, endsWith('/auth/capabilities'));
      },
    );
    test(
      'challenge is purpose-bound and completes only with reviewed consent version',
      () async {
        final paths = <String>[];
        final api = GlobalSaydianApiClient(
          MemorySessionVault(),
          client: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.endsWith('/capabilities')) {
              return ok(capabilities());
            }
            final body = jsonDecode(request.body) as Map;
            if (request.url.path.endsWith('/verification-code')) {
              expect(body['purpose'], 'register');
              expect(body['identifier'], 'a@example.com');
              return ok({
                'challengeId': 'challenge-uuid',
                'expiresIn': 300,
                'retryAfter': 60,
                'maskedIdentifier': 'a***@example.com',
              });
            }
            expect(body['consentVersion'], 'reviewed-test-v1');
            expect(body['challengeId'], 'challenge-uuid');
            expect(body.containsKey('identifier'), isFalse);
            return ok(sessionData());
          }),
        );
        final challenge = await api.requestVerification(
          identity: GlobalAccountIdentity.email('a@example.com'),
          purpose: 'register',
          locale: 'en',
        );
        expect(challenge.retryAfter, 60);
        await api.completeVerification(
          challengeId: challenge.id,
          code: '123456',
          password: 'test-password',
          resetPassword: false,
          locale: 'en',
          consentVersion: 'reviewed-test-v1',
        );
        expect(paths.last, endsWith('/auth/register-with-code'));
      },
    );
    test(
      'reset uses global purpose and refresh cannot restore a signed-out account',
      () async {
        final vault = MemorySessionVault()..session = session();
        final gate = Completer<http.Response>();
        var requests = 0;
        final api = GlobalSaydianApiClient(
          vault,
          client: MockClient((request) async {
            requests++;
            expect(request.url.path, endsWith('/auth/refresh'));
            return gate.future;
          }),
        );
        final first = api.refreshSession(vault.session!);
        final second = api.refreshSession(vault.session!);
        final firstCheck = expectLater(first, throwsA(isA<ApiException>()));
        final secondCheck = expectLater(second, throwsA(isA<ApiException>()));
        await vault.clearSession();
        gate.complete(ok(sessionData('member-a')));
        await Future.wait([firstCheck, secondCheck]);
        expect(requests, 1);
        expect(vault.session, isNull);
      },
    );
    test(
      'logout clears local credentials even when server is unavailable',
      () async {
        final vault = MemorySessionVault()..session = session();
        final api = GlobalSaydianApiClient(
          vault,
          client: MockClient((_) async => http.Response('', 503)),
        );
        await expectLater(api.logout(), throwsA(isA<ApiException>()));
        expect(vault.session, isNull);
      },
    );
  });
  test(
    'global care keeps UUIDs and asks only for a calendar day in UTC',
    () async {
      final vault = MemorySessionVault()..session = session();
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          expect(
            request.url.path,
            '${GlobalEnvironment.apiPrefix}/care/relationships/care-uuid/health',
          );
          expect(request.url.queryParameters['metric'], 'heart_rate');
          expect(
            request.url.queryParameters['from'],
            DateTime(2026, 3, 8).toUtc().toIso8601String(),
          );
          expect(request.headers['token'], isNull);
          expect(request.headers['Authorization'], startsWith('Bearer '));
          return ok([
            {
              'id': 'record-uuid',
              'values': {'value': 71},
            },
          ]);
        }),
      );
      final records = await api.globalCareRecords(
        'care-uuid',
        'heart_rate',
        DateTime(2026, 3, 8),
      );
      expect(records.single['id'], 'record-uuid');
    },
  );
}
