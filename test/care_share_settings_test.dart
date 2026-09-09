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
import 'package:saydian_app/ui/prototype_pages.dart';

Session _account(String id, {bool refreshable = false}) => Session(
  accessToken: 'synthetic-$id',
  refreshToken: refreshable ? 'synthetic-refresh' : '',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  memberId: id,
  displayName: '合成账号',
);

http.Response _ok(Object data) =>
    http.Response(jsonEncode({'code': 200, 'data': data}), 200);

Matcher _apiError(String code) =>
    throwsA(isA<ApiException>().having((error) => error.code, 'code', code));

class _Wearable extends Fake implements WearableBridge {}

class _Harness {
  _Harness(
    Future<http.Response> Function(http.Request) handler, {
    bool refreshable = false,
  }) {
    vault.session = _account('1', refreshable: refreshable);
    api = SaydianApiClient(
      vault,
      baseUri: Uri.parse('https://example.invalid'),
      client: MockClient(handler),
    );
    controller = AppController(vault, api, MemoryHealthStore(), _Wearable())
      ..session = vault.session;
    addTearDown(controller.dispose);
  }

  final vault = MemorySessionVault();
  late final SaydianApiClient api;
  late final AppController controller;
}

Future<void> _openPage(WidgetTester tester, _Harness harness) async {
  await tester.binding.setSurfaceSize(const Size(800, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: CareShareSettingsPage(
        controller: harness.controller,
        member: const {'nickname': '合成关爱成员'},
        memberId: 87,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'unchanged readback never confirms save; reread restores real settings',
    (tester) async {
      var reads = 0, writes = 0;
      final harness = _Harness((request) async {
        if (request.method == 'GET') {
          expect(request.url.path, '/api/v1/member/care-setting/preview');
          expect(request.url.queryParameters, {
            'type': '0',
            'to_member_id': '87',
          });
          reads++;
          return _ok({'setting': '["HRV","heartReat","legacyPermission"]'});
        }
        expect(request.url.path, '/api/v1/member/care-setting');
        expect(jsonDecode(request.body), {
          'type': 0,
          'to_member_id': 87,
          'setting': ['heartReat', 'legacyPermission'],
        });
        writes++;
        return _ok({}); // The synthetic server deliberately ignores this write.
      });
      await _openPage(tester, harness);
      final hrv = find.widgetWithText(SwitchListTile, 'HRV');
      expect(tester.widget<SwitchListTile>(hrv).value, isTrue);
      expect(find.text('仅共享已开启的项目，更改后请保存'), findsOneWidget);
      await tester.tap(hrv);
      await tester.pump();
      await tester.tap(find.text('保存共享设置'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(reads, 2);
      expect(find.text('共享设置已保存'), findsNothing);
      expect(find.text('保存未确认，请重新读取后重试'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(hrv).value, isFalse);
      expect(tester.widget<SwitchListTile>(hrv).onChanged, isNull);
      await tester.ensureVisible(find.text('重新读取共享设置'));
      await tester.tap(find.text('重新读取共享设置'));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(writes, 1);
      expect(tester.widget<SwitchListTile>(hrv).value, isTrue);
      expect(tester.widget<SwitchListTile>(hrv).onChanged, isNotNull);
      expect(find.text('保存未确认，请重新读取后重试'), findsNothing);
    },
  );

  test('controller rejects POST success with unmatched readback', () async {
    var reads = 0;
    final harness = _Harness((request) async {
      if (request.method == 'POST') return _ok({});
      reads++;
      return _ok({
        'setting': ['HRV'],
      });
    });
    expect(
      await harness.controller.saveCareShareSettings(
        memberId: 87,
        settings: {},
      ),
      isFalse,
    );
    expect(reads, 1);
    expect(harness.controller.errorMessage, '保存未确认，请重新读取后重试');
    expect(harness.controller.isBusy, isFalse);
  });

  test(
    'readback uses set equality and preserves all unknown permission keys',
    () async {
      final requests = <String>[];
      final harness = _Harness((request) async {
        requests.add(request.method);
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'type': 0,
            'to_member_id': 87,
            'setting': ['HRV', 'legacyPermission'],
          });
          return _ok({});
        }
        expect(request.url.queryParameters, {
          'type': '0',
          'to_member_id': '87',
        });
        return _ok({'setting': '["legacyPermission","HRV","HRV"]'});
      });
      expect(
        await harness.controller.saveCareShareSettings(
          memberId: 87,
          settings: {'legacyPermission', 'HRV'},
        ),
        isTrue,
      );
      expect(requests, ['POST', 'GET']);
    },
  );

  for (final value in <Object?>[
    null,
    '',
    'bad JSON',
    '{}',
    {},
    0,
    ['HRV', 3],
    [''],
    [' '],
  ]) {
    test(
      'invalid initial permission setting $value is not treated as no grants',
      () async {
        final harness = _Harness((_) async => _ok({'setting': value}));
        await expectLater(
          harness.api.getCareShareSettings(type: 0, memberId: 87),
          _apiError('INVALID_CARE_SETTINGS'),
        );
      },
    );
  }

  for (final value in <Object>['[]', <String>[]]) {
    test(
      'explicit empty permission list $value is valid and verifiable',
      () async {
        final harness = _Harness(
          (request) async =>
              request.method == 'POST' ? _ok({}) : _ok({'setting': value}),
        );
        expect(
          await harness.controller.saveCareShareSettings(
            memberId: 87,
            settings: {},
          ),
          isTrue,
        );
      },
    );
  }

  for (final failure in [
    '404',
    '500',
    'offline',
    'timeout',
    'malformed',
    'missing',
  ]) {
    test('POST accepted but $failure readback remains unconfirmed', () async {
      final requests = <String>[];
      final harness = _Harness((request) async {
        requests.add(request.method);
        if (request.method == 'POST') return _ok({});
        if (failure == 'offline') {
          throw http.ClientException('synthetic offline');
        }
        if (failure == 'timeout') throw TimeoutException('synthetic timeout');
        if (failure == 'malformed') return _ok({'setting': 'not a list'});
        if (failure == 'missing') return _ok({});
        return http.Response('{"code":$failure}', int.parse(failure));
      });
      await expectLater(
        harness.api.saveCareShareSettings(
          type: 0,
          memberId: 87,
          settings: {'HRV'},
        ),
        _apiError('CARE_SETTINGS_UNCONFIRMED'),
      );
      expect(requests, ['POST', 'GET']);
    });
  }

  for (final status in [401, 403, 500]) {
    test('failed POST $status never proceeds to verification GET', () async {
      var calls = 0;
      final harness = _Harness((request) async {
        calls++;
        expect(request.method, 'POST');
        return http.Response(jsonEncode({'code': status}), status);
      });
      await expectLater(
        harness.api.saveCareShareSettings(type: 0, memberId: 87, settings: {}),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
    });
  }

  for (final phase in ['POST', 'GET']) {
    test(
      'same-owner token refresh during $phase still confirms readback',
      () async {
        var refreshes = 0, attempts = 0;
        final harness = _Harness((request) async {
          if (request.url.path.endsWith('/site/refresh')) {
            refreshes++;
            return _ok({
              'access_token': 'synthetic-fresh',
              'refresh_token': 'synthetic-refresh-next',
              'expiration_time': 3600,
              'member': {'id': 1},
            });
          }
          if (request.method == phase && attempts++ == 0) {
            return http.Response('{"code":"401"}', 200);
          }
          if (request.method == 'GET') {
            expect(request.headers['token'], 'synthetic-fresh');
            return _ok({
              'setting': ['HRV'],
            });
          }
          return _ok({});
        }, refreshable: true);
        expect(
          await harness.controller.saveCareShareSettings(
            memberId: 87,
            settings: {'HRV'},
          ),
          isTrue,
        );
        expect(refreshes, 1);
        expect(harness.vault.session!.memberId, '1');
      },
    );
  }

  test('save snapshots the submitted set before any pending request', () async {
    final started = Completer<void>(), pending = Completer<http.Response>();
    final harness = _Harness((request) async {
      if (request.method == 'POST') {
        expect((jsonDecode(request.body) as Map)['setting'], ['HRV']);
        started.complete();
        return pending.future;
      }
      return _ok({
        'setting': ['HRV'],
      });
    });
    final settings = {'HRV'};
    final saved = harness.controller.saveCareShareSettings(
      memberId: 87,
      settings: settings,
    );
    await started.future;
    settings.clear();
    pending.complete(_ok({}));
    expect(await saved, isTrue);
  });

  for (final phase in ['read', 'POST', 'readback']) {
    for (final completion in ['success', '500', '401', 'offline']) {
      test(
        'late $phase $completion cannot cross account or refresh the new account',
        () async {
          final started = Completer<void>(),
              pending = Completer<http.Response>();
          final requests = <String>[];
          final harness = _Harness((request) async {
            requests.add(request.method);
            expect(request.headers['token'], 'synthetic-1');
            if (phase == 'readback' && request.method == 'POST') return _ok({});
            started.complete();
            return pending.future;
          }, refreshable: true);
          final Future<Object?> operation = phase == 'read'
              ? harness.controller.loadCareShareSettings(memberId: 87)
              : harness.api.saveCareShareSettings(
                  type: 0,
                  memberId: 87,
                  settings: {'HRV'},
                );
          await started.future;
          final callsBeforeSwitch = requests.length;
          harness.vault.session = _account('2');
          final rejected = expectLater(
            operation,
            _apiError('STALE_CARE_SESSION'),
          );
          if (completion == 'offline') {
            pending.completeError(http.ClientException('synthetic offline'));
          } else if (completion == 'success') {
            pending.complete(
              _ok({
                'setting': ['HRV'],
              }),
            );
          } else {
            pending.complete(http.Response('{"code":"$completion"}', 200));
          }
          await rejected;
          expect(requests.length, callsBeforeSwitch);
          expect(harness.vault.session!.memberId, '2');
        },
      );
    }
  }

  for (final completion in ['success', '500', 'offline']) {
    test(
      'controller old POST $completion never updates new-session busy, error or listeners',
      () async {
        final started = Completer<void>(), pending = Completer<http.Response>();
        final harness = _Harness((request) async {
          if (request.url.path.endsWith('/site/logout')) return _ok({});
          expect(request.method, 'POST');
          started.complete();
          return pending.future;
        });
        final save = harness.controller.saveCareShareSettings(
          memberId: 87,
          settings: {},
        );
        await started.future;
        await harness.controller.logout();
        harness.vault.session = _account('2');
        harness.controller.session = harness.vault.session;
        harness.controller.errorMessage = '新账号提示';
        harness.controller.isBusy = true;
        var notifications = 0;
        harness.controller.addListener(() => notifications++);
        if (completion == 'offline') {
          pending.completeError(http.ClientException('synthetic offline'));
        } else {
          pending.complete(
            completion == 'success'
                ? _ok({})
                : http.Response('{"code":500}', 500),
          );
        }
        expect(await save, isFalse);
        expect(notifications, 0);
        expect(harness.controller.errorMessage, '新账号提示');
        expect(harness.controller.isBusy, isTrue);
      },
    );
  }

  testWidgets(
    'saving locks individual, group, reload and repeat-save controls until verified',
    (tester) async {
      final pending = Completer<http.Response>();
      var reads = 0, writes = 0;
      final harness = _Harness((request) async {
        if (request.method == 'GET') {
          reads++;
          return _ok({'setting': <String>[]});
        }
        writes++;
        return pending.future;
      });
      await _openPage(tester, harness);
      await tester.tap(find.text('保存共享设置'));
      await tester.pump();
      expect(writes, 1);
      expect(
        tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)),
        everyElement(
          isA<SwitchListTile>().having(
            (value) => value.onChanged,
            'disabled',
            isNull,
          ),
        ),
      );
      expect(
        tester.widgetList<TextButton>(find.byType(TextButton)),
        everyElement(
          isA<TextButton>().having(
            (value) => value.onPressed,
            'disabled',
            isNull,
          ),
        ),
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        await harness.controller.saveCareShareSettings(
          memberId: 87,
          settings: {'HRV'},
        ),
        isFalse,
      );
      expect(writes, 1);
      pending.complete(_ok({}));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('共享设置已保存'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'HRV'))
            .onChanged,
        isNotNull,
      );
    },
  );

  testWidgets(
    'invalid initial settings disables edits and supports a real reread',
    (tester) async {
      var reads = 0;
      final harness = _Harness((request) async {
        expect(request.method, 'GET');
        return _ok({'setting': ++reads == 1 ? '{}' : '["HRV"]'});
      });
      await _openPage(tester, harness);
      final hrv = find.widgetWithText(SwitchListTile, 'HRV');
      expect(find.text('共享设置读取失败，请重新读取'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(hrv).onChanged, isNull);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('重新读取共享设置'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(tester.widget<SwitchListTile>(hrv).value, isTrue);
      expect(tester.widget<SwitchListTile>(hrv).onChanged, isNotNull);
    },
  );

  testWidgets(
    'logout removes old settings and ignores pending save UI completion',
    (tester) async {
      final pending = Completer<http.Response>();
      var reads = 0;
      final harness = _Harness((request) async {
        if (request.url.path.endsWith('/site/logout')) return _ok({});
        if (request.method == 'GET') {
          reads++;
          return _ok({
            'setting': ['HRV'],
          });
        }
        return pending.future;
      });
      await _openPage(tester, harness);
      await tester.tap(find.text('保存共享设置'));
      await tester.pump();
      await harness.controller.logout();
      harness.vault.session = _account('2');
      harness.controller.session = harness.vault.session;
      await tester.pump();
      expect(find.text('账号已变化，请返回后重新查看'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      pending.complete(_ok({}));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(find.text('共享设置已保存'), findsNothing);
      expect(find.text('保存未确认，请重新读取后重试'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
