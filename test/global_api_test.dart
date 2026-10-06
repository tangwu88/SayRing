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
Map<String, Object?> capabilities({
  bool email = true,
  bool sms = true,
  bool verificationRequired = true,
}) => {
  'realm': 'global',
  'product': 'say-ring',
  'registration': {
    'email': email,
    'sms': sms,
    'verificationRequired': verificationRequired,
  },
  'recovery': {'email': true, 'sms': true},
  'smsCountries': ['US', 'GB'],
  'supportedLocales': GlobalEnvironment.locales,
  'consentVersion': 'reviewed-test-v1',
  'legal': {
    'userAgreement': {
      'path':
          '/global/api/saydian-app/v2/content/legal/say_ring_user_agreement?version=reviewed-test-v1&locale=en',
    },
    'privacyPolicy': {
      'path':
          '/global/api/saydian-app/v2/content/legal/say_ring_privacy_policy?version=reviewed-test-v1&locale=en',
    },
  },
};

void main() {
  test(
    'legal capabilities request Say Ring and reject another product or its documents',
    () async {
      for (final mismatch in [false, true]) {
        final api = GlobalSaydianApiClient(
          MemorySessionVault(),
          client: MockClient((request) async {
            expect(request.url.queryParameters['product'], 'say-ring');
            final data = capabilities();
            if (mismatch) {
              data['legal'] = {
                'userAgreement': {
                  'path':
                      '/api/saydian-app/v2/content/legal/user_agreement?version=reviewed-test-v1&locale=en',
                },
              };
            } else {
              data['product'] = 'saydian-global';
            }
            return ok(data);
          }),
        );
        await expectLater(
          api.getAuthCapabilities(),
          throwsA(isA<ApiException>()),
        );
      }
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((request) async {
          expect(request.url.queryParameters['product'], 'say-ring');
          return ok(capabilities());
        }),
      );
      expect(
        (await api.getAuthCapabilities()).legal['privacyPolicy'],
        contains('/say_ring_privacy_policy?'),
      );
    },
  );
  test(
    'native WeChat requires phone binding before returning a session',
    () async {
      const ticket =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final requests = <http.Request>[];
      final vault = MemorySessionVault();
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          requests.add(request);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path.endsWith('/auth/wechat-login')) {
            expect(body, {
              'product': 'say-ring',
              'code': 'one-time-code',
              'state': 'fresh-state',
              'platform': 'android',
              'consentAccepted': true,
              'consentVersion': 'reviewed-test-v1',
              'locale': 'zh-Hans',
            });
            return ok({
              'requiresPhoneBinding': true,
              'bindTicket': ticket,
              'expiresIn': 300,
              'wechatProfileProof': 'signed-profile-proof',
            });
          }
          if (request.url.path.endsWith('/auth/wechat-phone-code')) {
            expect(body['bindTicket'], ticket);
            expect(body['identifier'], '+8613800138000');
            expect(body, isNot(contains('openid')));
            return ok({
              'challengeId': 'wechat-phone-challenge',
              'expiresIn': 300,
              'retryAfter': 60,
              'maskedIdentifier': '+86********000',
            });
          }
          expect(request.url.path, endsWith('/auth/wechat-bind-phone'));
          expect(body['bindTicket'], ticket);
          expect(body['challengeId'], 'wechat-phone-challenge');
          expect(body['code'], '123456');
          expect(body['wechatProfileProof'], 'signed-profile-proof');
          return ok(sessionData('wechat-member'));
        }),
      );
      final result = await api.loginGlobalWithWechat(
        code: 'one-time-code',
        state: 'fresh-state',
        platform: 'android',
        consentVersion: 'reviewed-test-v1',
        locale: 'zh-Hans',
      );
      expect(result.session, isNull);
      final binding = result.binding!;
      expect(vault.session, isNull);
      final challenge = await api.requestGlobalWechatPhoneCode(
        binding: binding,
        identity: GlobalAccountIdentity.phone('13800138000', country: 'CN'),
        consentVersion: 'reviewed-test-v1',
        locale: 'zh-Hans',
      );
      final session = await api.bindGlobalWechatPhone(
        binding: binding,
        challenge: challenge,
        code: '123456',
        consentVersion: 'reviewed-test-v1',
        locale: 'zh-Hans',
      );
      expect(session.memberId, 'wechat-member');
      expect(vault.session, isNull);
      expect(
        requests.map((request) => request.url.path),
        everyElement(startsWith(GlobalEnvironment.apiPrefix)),
      );
    },
  );

  test('shared H5 code login creates the same global member session', () async {
    final vault = MemorySessionVault();
    final paths = <String>[];
    final api = GlobalSaydianApiClient(
      vault,
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.url.origin, GlobalEnvironment.origin);
        expect(request.followRedirects, isFalse);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['channel'], 'sms');
        expect(body['identifier'], '+8613800138000');
        if (request.url.path == GlobalEnvironment.sharedCodeRequestPath) {
          expect(body['locale'], 'en');
          return http.Response(
            jsonEncode({
              'challengeId': 'synthetic-challenge',
              'expiresIn': 300,
              'retryAfter': 60,
              'maskedIdentifier': '+86********000',
            }),
            200,
          );
        }
        expect(request.url.path, GlobalEnvironment.sharedCodeLoginPath);
        expect(body['challengeId'], 'synthetic-challenge');
        expect(body['code'], '123456');
        expect(body['consentVersion'], 'reviewed-test-v1');
        expect(body['product'], 'say-ring');
        expect(body['ageConfirmed'], isFalse);
        return http.Response(
          jsonEncode({
            'token': 'synthetic-access',
            'refreshToken': 'synthetic-refresh',
            'expiresAt': '2099-01-01T00:00:00Z',
            'user': {'id': 'shared-member-id', 'nickname': 'Shared user'},
          }),
          200,
        );
      }),
    );
    final identity = GlobalAccountIdentity.phone('13800138000', country: 'CN');
    final challenge = await api.requestLoginCode(
      identity: identity,
      locale: 'en',
    );
    final session = await api.loginWithCode(
      identity: identity,
      challengeId: challenge.id,
      code: '123456',
      consentVersion: 'reviewed-test-v1',
      locale: 'en',
    );
    expect(paths, [
      GlobalEnvironment.sharedCodeRequestPath,
      GlobalEnvironment.sharedCodeLoginPath,
    ]);
    expect(session.memberId, 'shared-member-id');
    expect(session.accountKey, 'global:member:shared-member-id');
    expect(vault.session?.memberId, 'shared-member-id');
  });

  test(
    'temporary H5 phone-test session is never adopted by the ring App',
    () async {
      final vault = MemorySessionVault();
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'token': 'synthetic-access',
              'refreshToken': 'synthetic-refresh',
              'expiresAt': '2099-01-01T00:00:00Z',
              'user': {'id': 'test-only-member', 'phoneTestMode': true},
            }),
            200,
          ),
        ),
      );
      await expectLater(
        api.loginWithCode(
          identity: GlobalAccountIdentity.phone('13800138000', country: 'CN'),
          challengeId: 'synthetic-challenge',
          code: '123456',
          consentVersion: 'reviewed-test-v1',
          locale: 'en',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(vault.session, isNull);
    },
  );

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
    test(
      'login capabilities are separate from registration and fail closed',
      () {
        final caps = GlobalAuthCapabilities.fromJson({
          ...capabilities(email: true, sms: true),
          'login': {'email': false, 'sms': true},
          'smsCountries': ['CN'],
        });
        expect(
          caps.permitsLogin(
            GlobalAccountIdentity.phone('13800138000', country: 'CN'),
          ),
          isTrue,
        );
        expect(
          caps.permitsLogin(GlobalAccountIdentity.email('qa@example.com')),
          isFalse,
        );
        expect(
          GlobalAuthCapabilities.fromJson(capabilities()).permitsLogin(
            GlobalAccountIdentity.phone('13800138000', country: 'CN'),
          ),
          isFalse,
        );
      },
    );
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
      final temporary = GlobalAuthCapabilities.fromJson(
        capabilities(verificationRequired: false),
      );
      expect(
        temporary.permits(GlobalAccountIdentity.phone('+4915123456789')),
        isTrue,
      );
      expect(
        temporary.permits(
          GlobalAccountIdentity.phone('+4915123456789'),
          recovery: true,
        ),
        isFalse,
      );
    });
  });
  group('environment', () {
    test('only two exact global H5 code-auth paths may be shared', () {
      final origin = Uri.parse(GlobalEnvironment.origin);
      for (final path in [
        GlobalEnvironment.sharedCodeRequestPath,
        GlobalEnvironment.sharedCodeLoginPath,
      ]) {
        final uri = GlobalEnvironment.resolveSharedCodeAuth(origin, path);
        expect(GlobalEnvironment.allowsSharedCodeAuth(uri, origin), isTrue);
        expect(
          GlobalEnvironment.allowsSharedCodeAuth(uri, origin, method: 'GET'),
          isFalse,
        );
      }
      for (final path in [
        '/api/saidian-mall/v1/auth/code/login',
        '/global/api/saidian-mall/v1/auth/code/login/other',
        '/global/api/saidian-mall/v1/auth/password/login',
      ]) {
        expect(
          () => GlobalEnvironment.resolveSharedCodeAuth(origin, path),
          throwsArgumentError,
        );
      }
    });
    test('all first-party paths stay inside App V2 with query preserved', () {
      final origin = Uri.parse(GlobalEnvironment.origin);
      expect(
        GlobalEnvironment.resolve(
          origin,
          '/global/api/saydian-app/v2/auth/capabilities?locale=de',
        ).toString(),
        'https://app.saydian.cn/global/api/saydian-app/v2/auth/capabilities?locale=de',
      );
      expect(
        GlobalEnvironment.media('/global/api/saydian-app/v2/files/avatar.jpg'),
        'https://app.saydian.cn/global/api/saydian-app/v2/files/avatar.jpg',
      );
      expect(GlobalEnvironment.media('/files/avatar.jpg'), '');
      expect(GlobalEnvironment.media('https://app.saidian.cc/avatar.jpg'), '');
      expect(
        GlobalEnvironment.media('https://app.saydian.cn/down/domestic.apk'),
        '',
      );
      expect(
        GlobalEnvironment.media('https://third-party.example/watchface.png'),
        isEmpty,
      );
      expect(
        () => GlobalEnvironment.resolve(origin, '//app.saidian.cc/api'),
        throwsArgumentError,
      );
      expect(
        () => GlobalEnvironment.resolve(origin, '/global/../api'),
        throwsArgumentError,
      );
      expect(
        () => GlobalEnvironment.resolve(origin, '/global/api/test'),
        throwsArgumentError,
      );
    });
    test('day boundaries use local calendar, not Beijing offset', () {
      final range = globalLocalDayRange(DateTime(2026, 3, 8, 12));
      expect(range.from, DateTime(2026, 3, 8).toUtc());
      expect(range.to, DateTime(2026, 3, 9).toUtc());
    });
    test('local HTTP API is accepted only by an explicit non-product flag', () {
      expect(
        GlobalEnvironment.validateOrigin(
          'http://10.0.2.2:8082',
          allowLocalDebug: true,
          isProduct: false,
        ).origin,
        'http://10.0.2.2:8082',
      );
      for (final input in [
        'http://10.0.2.2:8082/path',
        'http://192.168.1.3:8082',
        'http://10.0.2.2',
      ]) {
        expect(
          () => GlobalEnvironment.validateOrigin(
            input,
            allowLocalDebug: true,
            isProduct: false,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => GlobalEnvironment.validateOrigin(
          'http://10.0.2.2:8082',
          allowLocalDebug: true,
          isProduct: true,
        ),
        throwsArgumentError,
      );
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
              'username': 'a+care@example.com',
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
    test('capability contract is loaded from the global API', () async {
      final requests = <Uri>[];
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        locale: () => 'de',
        client: MockClient((request) async {
          requests.add(request.url);
          return ok(capabilities(verificationRequired: false));
        }),
      );
      final available = await api.getAuthCapabilities();
      expect(available.email, isTrue);
      expect(available.sms, isTrue);
      expect(available.verificationRequired, isFalse);
      expect(requests.single.path, endsWith('/auth/capabilities'));
      expect(requests.single.queryParameters['locale'], 'de');
    });
    test('verification routes keep purpose, code and consent bound', () async {
      final requests = <http.Request>[];
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/verification-code')) {
            return ok({
              'challengeId': 'challenge-1',
              'expiresIn': 300,
              'retryAfter': 60,
              'maskedIdentifier': 'a***@example.com',
            });
          }
          return ok(sessionData());
        }),
      );
      final challenge = await api.requestVerification(
        identity: GlobalAccountIdentity.email('a@example.com'),
        purpose: 'register',
        locale: 'en',
      );
      expect(challenge.id, 'challenge-1');
      expect(jsonDecode(requests.first.body), {
        'product': 'say-ring',
        'channel': 'email',
        'identifier': 'a@example.com',
        'purpose': 'register',
        'locale': 'en',
      });
      await api.completeVerification(
        challengeId: challenge.id,
        code: '123456',
        password: 'test-password',
        resetPassword: false,
        locale: 'en',
        consentVersion: 'reviewed-test-v1',
      );
      expect(requests.last.url.path, endsWith('/auth/register-with-code'));
      expect(jsonDecode(requests.last.body), {
        'product': 'say-ring',
        'challengeId': 'challenge-1',
        'code': '123456',
        'password': 'test-password',
        'locale': 'en',
        'consentVersion': 'reviewed-test-v1',
      });
    });
    test(
      'temporary registration sends no code and stores the global session',
      () async {
        final vault = MemorySessionVault();
        late http.Request request;
        final api = GlobalSaydianApiClient(
          vault,
          client: MockClient((value) async {
            request = value;
            return ok(sessionData());
          }),
        );
        final result = await api.registerWithoutVerification(
          identity: GlobalAccountIdentity.phone(
            '(202) 555-0123',
            country: 'US',
          ),
          password: 'test-password',
          locale: 'en',
          consentVersion: 'reviewed-test-v1',
        );
        expect(request.url.path, endsWith('/auth/register'));
        expect(jsonDecode(request.body), {
          'product': 'say-ring',
          'channel': 'sms',
          'identifier': '+12025550123',
          'password': 'test-password',
          'locale': 'en',
          'consentVersion': 'reviewed-test-v1',
        });
        expect(result.memberId, 'uuid-member-α');
        expect((await vault.readSession())?.memberId, result.memberId);
      },
    );
    test('phone login uses the reviewed mobile field', () async {
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((request) async {
          expect(jsonDecode(request.body), {
            'mobile': '+12025550123',
            'password': 'password-test',
          });
          return ok(sessionData());
        }),
      );
      await api.login('+1 202 555 0123', 'password-test');
    });
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
  group('global V2 compatibility', () {
    test(
      'notification list and read use V2 without legacy ID guessing',
      () async {
        final vault = MemorySessionVault()..session = session();
        final requests = <http.Request>[];
        final api = GlobalSaydianApiClient(
          vault,
          client: MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/read')) return ok({'read': true});
            return ok({
              'items': [
                {
                  'id': 'notice-uuid',
                  'eventId': 'care-event-1',
                  'type': 'care_invitation',
                  'title': 'Care request',
                  'body': 'Review the request.',
                  'deepLink': '/care/invitations/relation-1',
                  'createdAt': '2026-09-09T01:00:00Z',
                  'readAt': null,
                },
              ],
            });
          }),
        );
        final rows = await api.getNotifications(page: 2);
        expect(requests.single.url.path, endsWith('/notifications'));
        expect(requests.single.url.queryParameters, {
          'page': '2',
          'pageSize': '30',
        });
        expect(rows.single['event_id'], 'care-event-1');
        expect(rows.single['entity_id'], 'relation-1');
        expect(rows.single['content'], 'Review the request.');
        expect(rows.single['is_read'], isFalse);
        expect(rows.single['_localNotification'], isTrue);
        expect(rows.single['id'], isNegative);
        expect(
          await api.markNotificationEventRead(eventId: 'care-event-1'),
          isTrue,
        );
        expect(requests.last.url.path, endsWith('/care-event-1/read'));
        expect(requests.last.method, 'POST');
        expect(requests.last.headers['Authorization'], startsWith('Bearer '));
      },
    );

    test('shop home uses V2 and unmigrated legacy calls fail closed', () async {
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((request) async {
          expect(request.url.path, endsWith('/commerce/home'));
          return ok({'banners': [], 'categories': [], 'featured': []});
        }),
      );
      expect((await api.getShopHome())['featured'], isEmpty);
      await expectLater(
        api.getShopProduct(12),
        throwsA(isA<FeatureNotConfiguredException>()),
      );
    });
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

  test(
    'Say Ring support and map use only isolated first-party paths',
    () async {
      final vault = MemorySessionVault()..session = session();
      final requests = <http.Request>[];
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/support/config')) {
            return ok({'configured': true, 'phone': '4000000000'});
          }
          if (request.url.path.endsWith('/support/sport-map-config')) {
            return ok({'provider': 'amap', 'configured': true});
          }
          if (request.url.path.endsWith('/support/sport-route-map')) {
            expect(request.method, 'POST');
            expect(request.headers['Authorization'], startsWith('Bearer '));
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect((body['points'] as List), hasLength(2));
            return http.Response.bytes(
              [137, 80, 78, 71],
              201,
              headers: {'content-type': 'image/png'},
            );
          }
          fail('Unexpected route: ${request.url}');
        }),
      );
      expect((await api.getGlobalSupportConfig())['phone'], '4000000000');
      expect((await api.getGlobalSportMapConfig())['provider'], 'amap');
      final image = await api.loadGlobalSportRouteMap([
        SportRoutePoint(
          latitude: 31,
          longitude: 121,
          recordedAt: DateTime.utc(2026),
        ),
        SportRoutePoint(
          latitude: 31.001,
          longitude: 121.001,
          recordedAt: DateTime.utc(2026),
        ),
      ]);
      expect(image, [137, 80, 78, 71]);
      expect(
        requests.every(
          (request) => request.url.path.startsWith(
            '${GlobalEnvironment.apiPrefix}/support/',
          ),
        ),
        isTrue,
      );
    },
  );
}
