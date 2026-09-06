import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';

MemorySessionVault _vault() => MemorySessionVault()
  ..session = Session(
    accessToken: 'synthetic-token',
    refreshToken: '',
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    memberId: '1',
    displayName: '合成账号',
  );

http.Response _success(Object data) => http.Response(
  jsonEncode({'code': 200, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  for (final staleRows in [false, true]) {
    for (final httpStatus in [200, 403]) {
      for (final businessCode in <Object>[403, '403']) {
        test(
          'care ${businessCode.runtimeType} 403 overrides ${staleRows ? 'stale' : 'empty'} aggregate rows with HTTP $httpStatus',
          () async {
            final api = SaydianApiClient(
              _vault(),
              baseUri: Uri.parse('https://example.invalid'),
              client: MockClient((request) async {
                if (request.url.path == '/api/v1/member/care/preview') {
                  return _success({
                    'daily': [
                      {'title': '心率', 'latest': 88},
                    ],
                  });
                }
                if (request.url.path == '/api/v1/member/daily-date/preview') {
                  final type = request.url.queryParameters['type'];
                  if (type == null) {
                    return _success(
                      staleRows
                          ? [
                              {'time': '08:00', 'pulseReat': 88},
                            ]
                          : [],
                    );
                  }
                  if (type == 'pulseReat') {
                    return http.Response(
                      jsonEncode({
                        'code': businessCode,
                        'message': 'permission denied',
                      }),
                      httpStatus,
                    );
                  }
                  if (type == 'BloodGlucose') {
                    return _success([
                      {'time': '08:00', 'bloodGlucose': 5.8},
                    ]);
                  }
                }
                return _success([]);
              }),
            );
            final preview = await api.getCareMemberPreview(
              id: 59,
              memberId: 87,
              day: '2026-08-27',
            );
            final daily = (preview['daily'] as List).cast<Map>();
            final heart = daily.singleWhere((item) => item['title'] == '心率');
            expect(heart['state'], 'unauthorized');
            expect(heart['records'], isEmpty);
            expect(heart['tips'], '对方未授权此项目');
            for (final key in ['latest', 'min', 'max', 'avg']) {
              expect(heart.containsKey(key), isFalse);
            }
            expect(
              daily.singleWhere((item) => item['title'] == '血糖')['state'],
              'ready',
            );
          },
        );
      }
    }
  }

  for (final failure in ['401', 'string401', 'timeout', 'offline']) {
    test(
      'care $failure remains a failure even when shared raw rows exist',
      () async {
        var detailRequests = 0;
        final api = SaydianApiClient(
          _vault(),
          baseUri: Uri.parse('https://example.invalid'),
          client: MockClient((request) async {
            if (request.url.path == '/api/v1/member/care/preview') {
              return _success({});
            }
            if (!request.url.queryParameters.containsKey('type')) {
              return _success([
                {'time': '08:00', 'pulseReat': 88},
              ]);
            }
            detailRequests++;
            if (failure == 'timeout') {
              throw TimeoutException('synthetic timeout');
            }
            if (failure == 'offline') {
              throw http.ClientException('synthetic offline');
            }
            if (failure == 'string401') {
              return http.Response(
                '{"code":"401","message":"session expired"}',
                200,
              );
            }
            return http.Response(
              '{"code":401,"message":"session expired"}',
              401,
            );
          }),
        );
        await expectLater(
          api.getCareMemberPreview(id: 59, memberId: 87, day: '2026-08-27'),
          throwsA(
            isA<ApiException>().having(
              (error) =>
                  failure.endsWith('401') ? error.statusCode : error.code,
              'failure',
              failure.endsWith('401')
                  ? 401
                  : failure == 'timeout'
                  ? 'NETWORK_TIMEOUT'
                  : 'NETWORK_UNAVAILABLE',
            ),
          ),
        );
        expect(detailRequests, 1);
      },
    );
  }

  test(
    'response code accepts exact 200 strings, rejects malformed and unknown codes',
    () async {
      for (final code in <Object?>[
        '200',
        200,
        '403bad',
        '403.0',
        ' 403',
        '403 ',
        '',
        'success',
        null,
        true,
        {},
        [],
        200.5,
        '70001',
        70001,
      ]) {
        final api = SaydianApiClient(
          _vault(),
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'code': code,
                'data': {'title': 'synthetic'},
              }),
              200,
            ),
          ),
        );
        if (code == '200' || code == 200) {
          expect((await api.getShopHome())['title'], 'synthetic');
        } else {
          await expectLater(
            api.getShopHome(),
            throwsA(isA<ApiException>()),
            reason: 'code=$code',
          );
        }
      }
    },
  );

  test(
    'HTTP error status stays authoritative over body success or another denial',
    () async {
      for (final pair in [
        (403, '401'),
        (401, '403'),
        (404, '403'),
        (503, '200'),
      ]) {
        final api = SaydianApiClient(
          _vault(),
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'code': pair.$2, 'message': 'synthetic denial'}),
              pair.$1,
            ),
          ),
        );
        await expectLater(
          api.getShopHome(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'HTTP status',
              pair.$1,
            ),
          ),
        );
      }
    },
  );

  test(
    'string 401 refreshes once, while HTTP 403 never refreshes from conflicting body 401',
    () async {
      for (final status in [200, 403]) {
        final vault = _vault();
        final original = vault.session!;
        vault.session = Session(
          accessToken: original.accessToken,
          refreshToken: 'synthetic-refresh',
          expiresAt: original.expiresAt,
          memberId: original.memberId,
          displayName: original.displayName,
        );
        var refreshes = 0, reads = 0;
        final api = SaydianApiClient(
          vault,
          client: MockClient((request) async {
            if (request.url.path.contains('refresh')) {
              refreshes++;
              return http.Response(
                '{"code":401,"message":"synthetic expired"}',
                401,
              );
            }
            reads++;
            return http.Response(
              '{"code":"401","message":"synthetic denied"}',
              status,
            );
          }),
        );
        await expectLater(
          api.getAddresses(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'status',
              status == 200 ? 401 : 403,
            ),
          ),
        );
        expect(refreshes, status == 200 ? 1 : 0);
        expect(reads, 1);
      }
    },
  );

  testWidgets(
    'unauthorized care summary and detail never render stale health readings',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = AppController(
        _vault(),
        _CareApi(),
        MemoryHealthStore(),
        _Wearable(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: CareMemberPage(
            controller: controller,
            member: const {'nickname': '合成家人', 'to_member_id': 87},
            careId: 59,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('对方未授权此项目'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.textContaining('88'), findsNothing);
      await tester.tap(find.text('心率'));
      await tester.pumpAndSettle();
      expect(find.text('对方未授权此项目'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.textContaining('88'), findsNothing);
      expect(find.textContaining('暂无记录'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _CareApi implements SaydianApi {
  @override
  Future<Map<String, Object?>> getCareMemberPreview({
    required int id,
    required String day,
    int? memberId,
  }) async => {
    'daily': [
      {
        'title': '心率',
        'state': 'unauthorized',
        'unit': '次/分',
        'latest': 88,
        'avg': 88,
        'tips': '当日暂无记录',
        'records': [
          {'time': '08:00', 'pulseReat': 88},
        ],
      },
    ],
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wearable implements WearableBridge {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
