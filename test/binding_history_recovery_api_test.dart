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
}
