import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

Session _account(String owner, {bool refreshable = false}) => Session(
  accessToken: 'synthetic-$owner',
  refreshToken: refreshable ? 'synthetic-refresh' : '',
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  memberId: owner,
  displayName: '合成账号',
);

http.Response _ok(Object data) =>
    http.Response(jsonEncode({'code': 200, 'data': data}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final phase in ['overview', 'first metric', 'last metric']) {
    for (final completion in ['success', 'server error', 'offline', '401']) {
      test(
        'care $phase late $completion is rejected after owner changes',
        () async {
          final vault = MemorySessionVault()
            ..session = _account('1', refreshable: completion == '401');
          final started = Completer<void>();
          final pending = Completer<http.Response>();
          final owners = <String>[];
          final api = SaydianApiClient(
            vault,
            baseUri: Uri.parse('https://example.invalid'),
            client: MockClient((request) async {
              owners.add(request.headers['token'] ?? 'unexpected-refresh');
              final shouldWait = switch (phase) {
                'overview' => request.url.path.endsWith('/care/preview'),
                'first metric' =>
                  request.url.queryParameters['type'] == 'pulseReat',
                _ => request.url.path.endsWith('/bloodcomposition/preview'),
              };
              if (shouldWait) {
                started.complete();
                return pending.future;
              }
              return _ok([]);
            }),
          );
          final reading = api.getCareMemberPreview(
            id: 59,
            memberId: 87,
            day: '2026-08-27',
          );
          await started.future;
          final requestsBeforeSwitch = owners.length;
          vault.session = _account('2');
          final rejected = expectLater(
            reading,
            throwsA(
              isA<ApiException>().having(
                (error) => error.code,
                'stale care owner',
                'STALE_CARE_SESSION',
              ),
            ),
          );
          if (completion == 'offline') {
            pending.completeError(http.ClientException('synthetic offline'));
          } else if (completion == 'server error') {
            pending.complete(http.Response('{"code":500}', 500));
          } else if (completion == '401') {
            pending.complete(http.Response('{"code":"401"}', 200));
          } else {
            pending.complete(
              _ok([
                {'time': '08:00', 'pulseReat': 71},
              ]),
            );
          }
          await rejected;
          expect(owners, everyElement('synthetic-1'));
          expect(owners.length, requestsBeforeSwitch);
          expect(vault.session!.memberId, '2');
        },
      );
    }
  }

  test('care late success is rejected after logout', () async {
    final vault = MemorySessionVault()..session = _account('1');
    final started = Completer<void>(), pending = Completer<http.Response>();
    var requests = 0;
    final api = SaydianApiClient(
      vault,
      baseUri: Uri.parse('https://example.invalid'),
      client: MockClient((request) async {
        requests++;
        if (request.url.path.endsWith('/care/preview')) return _ok({});
        started.complete();
        return pending.future;
      }),
    );
    final reading = api.getCareMemberPreview(
      id: 59,
      memberId: 87,
      day: '2026-08-27',
    );
    await started.future;
    await vault.clearSession();
    final rejected = expectLater(
      reading,
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'stale care owner',
          'STALE_CARE_SESSION',
        ),
      ),
    );
    pending.complete(
      _ok([
        {'time': '08:00', 'pulseReat': 71},
      ]),
    );
    await rejected;
    expect(requests, 2);
  });

  test(
    'care accepts normal same-owner token refresh during metric read',
    () async {
      final vault = MemorySessionVault()
        ..session = _account('1', refreshable: true);
      var refreshes = 0, heartReads = 0;
      final api = SaydianApiClient(
        vault,
        baseUri: Uri.parse('https://example.invalid'),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/site/refresh')) {
            refreshes++;
            return _ok({
              'access_token': 'synthetic-fresh',
              'refresh_token': 'synthetic-refresh-next',
              'expiration_time': 3600,
              'member': {'id': 1},
            });
          }
          if (request.url.path.endsWith('/care/preview')) return _ok({});
          if (request.url.queryParameters['type'] == 'pulseReat') {
            heartReads++;
            if (heartReads == 1) return http.Response('{"code":"401"}', 200);
            expect(request.headers['token'], 'synthetic-fresh');
            return _ok([
              {'time': '08:00', 'pulseReat': 71},
            ]);
          }
          return _ok([]);
        }),
      );
      final preview = await api.getCareMemberPreview(
        id: 59,
        memberId: 87,
        day: '2026-08-27',
      );
      expect(refreshes, 1);
      expect(heartReads, 2);
      expect((preview['daily'] as List).cast<Map>().first['latest'], 71);
      expect(vault.session!.memberId, '1');
    },
  );

  for (final completion in ['success', 'error', 'stale error']) {
    test(
      'care controller ignores old $completion after logout and a new session',
      () async {
        final api = _DeferredCareApi();
        final controller = AppController(
          MemorySessionVault(),
          api,
          MemoryHealthStore(),
          _Wearable(),
        );
        addTearDown(controller.dispose);
        controller.session = _account('1');
        final reading = controller.loadCareMemberPreview(59, memberId: 87);
        await controller.logout();
        controller.session = _account('2');
        controller.errorMessage = '新账号提示';
        var changes = 0;
        controller.addListener(() => changes++);
        if (completion == 'success') {
          api.pending.complete({
            'daily': [
              {'title': '心率', 'latest': 71},
            ],
          });
        } else {
          api.pending.completeError(
            ApiException(
              '旧账号错误',
              code: completion == 'stale error'
                  ? 'STALE_CARE_SESSION'
                  : 'NETWORK_UNAVAILABLE',
            ),
          );
        }
        expect(await reading, isEmpty);
        expect(controller.errorMessage, '新账号提示');
        expect(changes, 0);
      },
    );
  }
}

class _DeferredCareApi extends Fake implements SaydianApi {
  final pending = Completer<Map<String, Object?>>();
  @override
  Future<Map<String, Object?>> getCareMemberPreview({
    required int id,
    required String day,
    int? memberId,
  }) => pending.future;
  @override
  Future<void> logout() async {}
}

class _Wearable extends Fake implements WearableBridge {}
