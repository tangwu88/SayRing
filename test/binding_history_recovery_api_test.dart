import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

Session owner([String id = 'owner']) => Session(
  accessToken: 'test-access',
  refreshToken: 'test-refresh',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  displayName: 'Synthetic',
  accountKey: 'global:member:$id',
);
const target = 'qring:SYNTHETIC_R8';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final confirmed in [true, false]) {
    test(
      'read-only proof accepts explicit $confirmed for the exact owner and target',
      () async {
        final vault = MemorySessionVault()..session = owner();
        final api = GlobalSaydianApiClient(
          vault,
          baseUri: Uri.parse('https://app.saydian.cn'),
          client: MockClient((r) async {
            expect(r.method, 'GET');
            expect(
              r.url.path,
              '/global/api/saydian-app/v2/devices/binding-history-status',
            );
            expect(r.url.queryParameters, {
              'product': 'say-ring',
              'deviceId': target,
            });
            expect(r.headers['authorization'], 'Bearer test-access');
            return http.Response(
              jsonEncode({
                'code': 200,
                'data': {
                  'product': 'say-ring',
                  'deviceId': target,
                  'priorBindingConfirmed': confirmed,
                },
              }),
              200,
            );
          }),
        );
        expect(
          await api.hasPriorBindingBeforeDevice(
            expectedSession: owner(),
            deviceId: target,
          ),
          confirmed,
        );
      },
    );
  }
  for (final body in <Map<String, Object?>>[
    {
      'product': 'say-ring',
      'deviceId': 'another-target',
      'priorBindingConfirmed': true,
    },
    {
      'product': 'saydian-global',
      'deviceId': target,
      'priorBindingConfirmed': true,
    },
    {
      'product': 'say-ring',
      'deviceId': target,
      'priorBindingConfirmed': 'true',
    },
    {'product': 'say-ring', 'deviceId': target},
  ]) {
    test('mismatched or ambiguous proof stays unconfirmed: $body', () async {
      final vault = MemorySessionVault()..session = owner();
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient(
          (r) async =>
              http.Response(jsonEncode({'code': 200, 'data': body}), 200),
        ),
      );
      await expectLater(
        api.hasPriorBindingBeforeDevice(
          expectedSession: owner(),
          deviceId: target,
        ),
        throwsA(isA<ApiException>()),
      );
    });
  }
  test(
    'a switched account is rejected without sending a history request',
    () async {
      var calls = 0;
      final vault = MemorySessionVault()..session = owner('other');
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((r) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.hasPriorBindingBeforeDevice(
          expectedSession: owner(),
          deviceId: target,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 0);
    },
  );
  test(
    'an unavailable endpoint never falls back to replaying a binding write',
    () async {
      final methods = <String>[];
      final vault = MemorySessionVault()..session = owner();
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((r) async {
          methods.add(r.method);
          return http.Response('{"code":404,"message":"Not found"}', 404);
        }),
      );
      await expectLater(
        api.hasPriorBindingBeforeDevice(
          expectedSession: owner(),
          deviceId: target,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(methods, ['GET']);
    },
  );

  group('durable first-binding decision protocol', () {
    const operation = '11111111-2222-4333-8444-555555555555';
    const otherOperation = '99999999-2222-4333-8444-555555555555';
    const decisionPath =
        '/global/api/saydian-app/v2/devices/first-binding-decision';
    const statusPath =
        '/global/api/saydian-app/v2/devices/binding-initialization-status';
    http.Response ok(Object? data) =>
        http.Response(jsonEncode({'code': 200, 'data': data}), 200);
    Map<String, Object?> status(String value) => {
      'product': 'say-ring',
      'deviceId': target,
      'operationId': operation,
      'decision': value,
    };
    Map<String, Object?> decision(bool clear) => {
      'product': 'say-ring',
      'deviceId': target,
      'operationId': operation,
      'shouldClear': clear,
    };
    Future<bool> post(
      GlobalSaydianApiClient api, {
      String operationId = operation,
    }) => api.reportFirstRingBindingDecision(
      expectedSession: owner(),
      deviceId: target,
      operationId: operationId,
      vendor: 'QRing',
      model: 'R8',
      displayName: 'SYNTHETIC_R8',
      capabilities: ['metric:steps'],
    );
    Future<RingBindingDecisionStatus> get(
      GlobalSaydianApiClient api, {
      String operationId = operation,
    }) => api.readRingBindingDecision(
      expectedSession: owner(),
      deviceId: target,
      operationId: operationId,
    );

    for (final entry in {
      'preserve': RingBindingDecisionStatus.preserve,
      'clear-issued': RingBindingDecisionStatus.clearIssued,
      'not-found': RingBindingDecisionStatus.notFound,
    }.entries) {
      test(
        'GET reads ${entry.key} without dispatching a binding write',
        () async {
          final requests = <http.Request>[];
          final api = GlobalSaydianApiClient(
            MemorySessionVault()..session = owner(),
            client: MockClient((request) async {
              requests.add(request);
              return ok(status(entry.key));
            }),
          );
          expect(await get(api), entry.value);
          expect(requests, hasLength(1));
          expect(requests.single.method, 'GET');
          expect(requests.single.url.path, statusPath);
          expect(requests.single.url.queryParameters, {
            'product': 'say-ring',
            'deviceId': target,
            'operationId': operation,
          });
          expect(
            requests.single.headers['authorization'],
            'Bearer test-access',
          );
        },
      );
    }

    for (final clear in [false, true]) {
      test(
        'POST accepts exact typed $clear decision only on the dedicated endpoint',
        () async {
          final requests = <http.Request>[];
          final api = GlobalSaydianApiClient(
            MemorySessionVault()..session = owner(),
            client: MockClient((request) async {
              requests.add(request);
              return ok({'firstBindingInitialization': decision(clear)});
            }),
          );
          expect(await post(api), clear);
          expect(requests, hasLength(1));
          final request = requests.single;
          expect(request.method, 'POST');
          expect(request.url.path, decisionPath);
          expect(request.headers['authorization'], 'Bearer test-access');
          expect(jsonDecode(request.body), {
            'deviceId': target,
            'vendor': 'QRing',
            'model': 'R8',
            'displayName': 'SYNTHETIC_R8',
            'capabilities': ['metric:steps'],
            'product': 'say-ring',
            'initializeFirstBinding': true,
            'initializationOperationId': operation,
          });
        },
      );
    }

    final invalidStatuses = <String, Object?>{
      'wrong product': {...status('preserve'), 'product': 'other-app'},
      'wrong target': {...status('preserve'), 'deviceId': 'qring:other'},
      'wrong operation': {...status('preserve'), 'operationId': otherOperation},
      'missing operation': {...status('preserve')}..remove('operationId'),
      'unknown decision': status('not-confirmed'),
      'boolean decision': {...status('preserve'), 'decision': true},
      'legacy first-binding shape': {
        'firstBindingInitialization': decision(false),
      },
    };
    for (final entry in invalidStatuses.entries) {
      test('GET rejects ${entry.key} without producing preserve', () async {
        var calls = 0;
        final api = GlobalSaydianApiClient(
          MemorySessionVault()..session = owner(),
          client: MockClient((request) async {
            calls++;
            expect(request.method, 'GET');
            return ok(entry.value);
          }),
        );
        await expectLater(get(api), throwsA(isA<ApiException>()));
        expect(calls, 1);
      });
    }

    final invalidDecisions = <String, Object?>{
      'wrong product': {...decision(false), 'product': 'other-app'},
      'wrong target': {...decision(false), 'deviceId': 'qring:other'},
      'wrong operation': {...decision(false), 'operationId': otherOperation},
      'missing operation': {...decision(false)}..remove('operationId'),
      'text true': {...decision(true), 'shouldClear': 'true'},
      'numeric false': {...decision(false), 'shouldClear': 0},
      'missing shouldClear': {...decision(false)}..remove('shouldClear'),
      'null': null,
    };
    for (final entry in invalidDecisions.entries) {
      test('POST rejects ${entry.key} rather than assuming no clear', () async {
        final api = GlobalSaydianApiClient(
          MemorySessionVault()..session = owner(),
          client: MockClient(
            (request) async => ok({'firstBindingInitialization': entry.value}),
          ),
        );
        await expectLater(post(api), throwsA(isA<ApiException>()));
      });
    }

    for (final method in ['GET', 'POST']) {
      for (final responseCode in [404, 409, 503]) {
        test(
          '$method $responseCode never falls back to the legacy bind route',
          () async {
            final requests = <http.Request>[];
            final api = GlobalSaydianApiClient(
              MemorySessionVault()..session = owner(),
              client: MockClient((request) async {
                requests.add(request);
                return http.Response(
                  jsonEncode({
                    'code': responseCode,
                    'message': 'Synthetic failure',
                  }),
                  responseCode,
                );
              }),
            );
            await expectLater(
              method == 'GET' ? get(api) : post(api),
              throwsA(isA<ApiException>()),
            );
            expect(requests, hasLength(1));
            expect(requests.single.method, method);
            expect(
              requests.single.url.path,
              method == 'GET' ? statusPath : decisionPath,
            );
          },
        );
      }

      test('$method refuses an old owner before network dispatch', () async {
        var calls = 0;
        final api = GlobalSaydianApiClient(
          MemorySessionVault()..session = owner('other-owner'),
          client: MockClient((request) async {
            calls++;
            return ok({});
          }),
        );
        await expectLater(
          method == 'GET' ? get(api) : post(api),
          throwsA(isA<ApiException>()),
        );
        expect(calls, 0);
      });

      test('$method validates operation before network dispatch', () async {
        var calls = 0;
        final api = GlobalSaydianApiClient(
          MemorySessionVault()..session = owner(),
          client: MockClient((request) async {
            calls++;
            return ok({});
          }),
        );
        await expectLater(
          method == 'GET'
              ? get(api, operationId: 'invalid')
              : post(api, operationId: 'invalid'),
          throwsA(isA<ApiException>()),
        );
        expect(calls, 0);
      });
    }

    test(
      'authorization refresh reuses the exact POST operation and original target',
      () async {
        final vault = MemorySessionVault()..session = owner();
        final bodies = <String>[];
        final requests = <String>[];
        final api = GlobalSaydianApiClient(
          vault,
          client: MockClient((request) async {
            requests.add(request.url.path);
            if (request.url.path.endsWith('/auth/refresh')) {
              return ok({
                'accessToken': 'fresh-test-access',
                'refreshToken': 'fresh-test-refresh',
                'expiresAt': DateTime.utc(2099).toIso8601String(),
                'member': {'id': 'owner', 'nickname': 'Synthetic'},
              });
            }
            expect(request.url.path, decisionPath);
            bodies.add(request.body);
            if (bodies.length == 1) {
              return http.Response('{"code":401,"message":"Expired"}', 401);
            }
            expect(
              request.headers['authorization'],
              'Bearer fresh-test-access',
            );
            return ok({'firstBindingInitialization': decision(false)});
          }),
        );
        expect(await post(api), false);
        expect(bodies, hasLength(2));
        expect(bodies[1], bodies[0]);
        expect(requests, [
          decisionPath,
          '/global/api/saydian-app/v2/auth/refresh',
          decisionPath,
        ]);
        expect(vault.session?.memberId, 'owner');
      },
    );
  });
}
