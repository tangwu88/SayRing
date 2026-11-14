import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sync_diagnostics.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

Session owner(String id) => Session(
  accessToken: 'synthetic-$id',
  refreshToken: 'synthetic-refresh',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  displayName: 'Synthetic',
  accountKey: 'global:$id',
);
Map<String, Object?> report() => {
  ...diagnosticDeviceSnapshot(
    platform: 'android',
    sdk: 'coolwear',
    model: 'R7Pro',
    connectionState: 'ready',
    initializationState: 'ready',
    capabilityState: 'ready',
    metrics: ['heart_rate'],
  ),
  'schemaVersion': 1,
  'product': 'say-ring',
  'reportId': '11111111-1111-4111-8111-111111111111',
  'connectionId': '22222222-2222-4222-8222-222222222222',
  'mode': 'manual',
  'appVersion': '1.0.14',
  'buildNumber': 1307,
  'stages': <Object?>[],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'uses only authenticated international Say Ring endpoints and safe JSON',
    () async {
      final session = owner('a'),
          vault = MemorySessionVault()..session = owner('a');
      final paths = <Uri>[];
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          paths.add(request.url);
          expect(request.url.host, 'app.saydian.cn');
          expect(
            request.url.path,
            startsWith('/global/api/saydian-app/v2/support/sync-diagnostics'),
          );
          expect(request.headers['authorization'], 'Bearer synthetic-a');
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'code': 200,
                'data': {
                  'schemaVersion': 1,
                  'product': 'say-ring',
                  'supported': true,
                  'automatic': true,
                },
              }),
              200,
            );
          }
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(isBoundedDiagnosticReport(body), isTrue);
          expect(body.containsKey('userId'), isFalse);
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {'accepted': true, 'reportId': body['reportId']},
            }),
            200,
          );
        }),
      );
      expect(await api.supportsSyncDiagnostics(session), isTrue);
      expect(
        (await api.submitSyncDiagnostics(session, report()))['accepted'],
        isTrue,
      );
      expect(paths.first.queryParameters, {'product': 'say-ring'});
    },
  );
  test(
    'old backend is unavailable without credential rotation or logout',
    () async {
      final vault = MemorySessionVault()..session = owner('a');
      final paths = <String>[];
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((r) async {
          paths.add(r.url.path);
          return http.Response('{"code":404,"message":"not found"}', 404);
        }),
      );
      expect(await api.supportsSyncDiagnostics(owner('a')), isFalse);
      expect(paths, hasLength(1));
      expect(vault.session?.memberId, 'a');
    },
  );
  test(
    'diagnostic 401 never triggers token refresh or clears normal session',
    () async {
      final vault = MemorySessionVault()..session = owner('a');
      final paths = <String>[];
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((r) async {
          paths.add(r.url.path);
          return http.Response('{"code":401,"message":"expired"}', 401);
        }),
      );
      await expectLater(
        api.supportsSyncDiagnostics(owner('a')),
        throwsA(isA<ApiException>()),
      );
      expect(paths, hasLength(1));
      expect(vault.session?.memberId, 'a');
    },
  );
  test(
    'changed owner and forbidden fields are rejected before HTTP dispatch',
    () async {
      final vault = MemorySessionVault()..session = owner('b');
      var requests = 0;
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((r) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.submitSyncDiagnostics(owner('a'), report()),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.submitSyncDiagnostics(owner('b'), {
          ...report(),
          'accessToken': 'private',
        }),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.submitSyncDiagnostics(owner('b'), {
          ...report(),
          'stages': [
            {
              'stage': 'read',
              'state': 'failed',
              'code': 'private raw error',
              'elapsedMs': 1,
            },
          ],
        }),
        throwsA(isA<ApiException>()),
      );
      expect(requests, 0);
    },
  );
}
