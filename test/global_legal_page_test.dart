import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/global_environment.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/global_auth_page.dart';
import 'package:saydian_app/ui/global_legal_page.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart';

class _NoWatch extends Fake implements WearableBridge {}

const _version = 'reviewed-test-v1';
const _prefix = GlobalEnvironment.apiPrefix;

Map<String, Object?> _capabilities() => {
  'realm': 'global',
  'product': 'say-ring',
  'registration': {'email': false, 'sms': false},
  'consentVersion': _version,
  'legal': {
    for (final entry in {
      'userAgreement': 'say_ring_user_agreement',
      'privacyPolicy': 'say_ring_privacy_policy',
    }.entries)
      entry.key: {
        'path':
            '$_prefix/content/legal/${entry.value}'
            '?version=$_version&locale=en',
      },
  },
};

Map<String, Object?> _document(String type) => {
  'documentType': type,
  'version': _version,
  'locale': 'en',
  'reviewed': true,
  'title': type == 'say_ring_privacy_policy'
      ? 'Published privacy'
      : 'Published terms',
  'contentHtml': '<p>Published test document.</p><p>Second paragraph.</p>',
};

http.Response _ok(Object data) => http.Response(
  jsonEncode({'code': 200, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

AppController _controller(http.Client client) {
  final vault = MemorySessionVault();
  return AppController(
    vault,
    GlobalSaydianApiClient(vault, client: client, locale: () => 'en'),
    MemoryHealthStore(),
    _NoWatch(),
  );
}

Widget _host(Widget home, {double scale = 1}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void main() {
  testWidgets('account privacy uses capability legal path, not article 3', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final controller = _controller(
      MockClient((request) async {
        requests.add(request);
        if (request.url.path == '$_prefix/auth/capabilities') {
          return _ok(_capabilities());
        }
        if (request.url.path ==
            '$_prefix/content/legal/say_ring_privacy_policy') {
          return _ok(_document('say_ring_privacy_policy'));
        }
        return http.Response('', 404);
      }),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(AccountSettingsPage(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.privacy_tip_outlined));
    await tester.pumpAndSettle();

    expect(find.textContaining('Published test document.'), findsOneWidget);
    expect(requests.map((r) => r.url.path), [
      '$_prefix/auth/capabilities',
      '$_prefix/content/legal/say_ring_privacy_policy',
    ]);
    expect(requests.last.url.queryParameters, {
      'version': _version,
      'locale': 'en',
    });
    expect(
      requests.every((r) => r.url.origin == GlobalEnvironment.origin),
      isTrue,
    );
    expect(requests.every((r) => !r.followRedirects), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final entry in ['about', 'auth']) {
    for (final type in GlobalLegalDocumentType.values) {
      testWidgets(
        '$entry opens published ${type.name} with its consent version',
        (tester) async {
          final requests = <http.Request>[];
          final controller = _controller(
            MockClient((request) async {
              requests.add(request);
              if (request.url.path == '$_prefix/auth/capabilities') {
                return _ok(_capabilities());
              }
              return _ok(_document(type.documentType));
            }),
          );
          addTearDown(controller.dispose);
          final home = entry == 'auth'
              ? GlobalAuthPage(controller: controller)
              : AboutSaydianPage(
                  controller: controller,
                  packageInfoLoader: () async => PackageInfo(
                    appName: 'Saydian',
                    packageName: GlobalEnvironment.packageId,
                    version: '0.1.21',
                    buildNumber: '1003',
                  ),
                );
          await tester.pumpWidget(_host(home));
          await tester.pumpAndSettle();
          final title = type == GlobalLegalDocumentType.userAgreement
              ? 'Terms of Service'
              : 'Privacy Policy';
          await tester.ensureVisible(find.text(title));
          await tester.tap(find.text(title));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('global-legal-body')), findsOneWidget);
          expect(find.text('$_version · English'), findsOneWidget);
          expect(
            requests.last.url.path,
            '$_prefix/content/legal/${type.documentType}',
          );
          expect(requests.last.url.queryParameters, {
            'version': _version,
            'locale': 'en',
          });
          expect(
            requests.map((r) => r.url.path),
            everyElement(
              anyOf(
                '$_prefix/auth/capabilities',
                '$_prefix/content/legal/${type.documentType}',
              ),
            ),
          );
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('global-legal-page')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final failure in [
    'missing consent',
    'missing path',
    'wrong reference version',
    'blank content',
    'missing content',
    'missing document version',
    'wrong document version',
    'wrong type',
    'wrong locale',
    'not reviewed',
    'server unavailable',
    'capabilities unavailable',
  ]) {
    testWidgets('$failure shows no substitute agreement and can retry', (
      tester,
    ) async {
      var fixed = false;
      final requests = <String>[];
      final controller = _controller(
        MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path == '$_prefix/auth/capabilities') {
            if (!fixed && failure == 'capabilities unavailable') {
              return http.Response('', 404);
            }
            final data = _capabilities();
            if (!fixed) {
              if (failure == 'missing consent') data.remove('consentVersion');
              if (failure == 'missing path') {
                data['legal'] = <String, Object?>{};
              }
              if (failure == 'wrong reference version') {
                data['consentVersion'] = 'different-reviewed-version';
              }
            }
            return _ok(data);
          }
          if (!fixed && failure == 'server unavailable') {
            return http.Response('', 503);
          }
          final data = _document('say_ring_privacy_policy');
          if (!fixed) {
            switch (failure) {
              case 'blank content':
                data['contentHtml'] = '<p> </p><script>not legal text</script>';
              case 'missing content':
                data.remove('contentHtml');
              case 'missing document version':
                data.remove('version');
              case 'wrong document version':
                data['version'] = 'different-reviewed-version';
              case 'wrong type':
                data['documentType'] = 'say_ring_user_agreement';
              case 'wrong locale':
                data['locale'] = 'de';
              case 'not reviewed':
                data['reviewed'] = false;
            }
          }
          return _ok(data);
        }),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          GlobalLegalPage(
            controller: controller,
            document: GlobalLegalDocumentType.privacyPolicy,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-legal-body')), findsNothing);
      expect(find.byKey(const Key('global-legal-retry')), findsOneWidget);
      expect(find.textContaining('Published test document.'), findsNothing);
      if ([
        'missing consent',
        'missing path',
        'wrong reference version',
      ].contains(failure)) {
        expect(requests, ['$_prefix/auth/capabilities']);
      }
      fixed = true;
      await tester.tap(find.byKey(const Key('global-legal-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-legal-body')), findsOneWidget);
      expect(find.byKey(const Key('global-legal-retry')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('404 capabilities never enables consent or registration', (
    tester,
  ) async {
    final requests = <String>[];
    final controller = _controller(
      MockClient((request) async {
        requests.add(request.url.path);
        return http.Response('', 404);
      }),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(GlobalAuthPage(controller: controller)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('auth-toggle-mode')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('auth-toggle-mode')));
    await tester.pumpAndSettle();
    final consent = tester.widget<CheckboxListTile>(
      find.byKey(const Key('auth-consent')),
    );
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('auth-submit')),
    );
    expect(consent.onChanged, isNull);
    expect(consent.value, isFalse);
    expect(submit.onPressed, isNull);
    expect(requests, ['$_prefix/auth/capabilities']);
  });

  testWidgets('compact legal page supports large text and long paragraphs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(
      MockClient(
        (request) async => _ok(
          request.url.path.endsWith('/auth/capabilities')
              ? _capabilities()
              : {
                  ..._document('say_ring_privacy_policy'),
                  'contentHtml': '<p>${'Readable legal paragraph. ' * 60}</p>',
                },
        ),
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        GlobalLegalPage(
          controller: controller,
          document: GlobalLegalDocumentType.privacyPolicy,
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('global-legal-body')), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final prefix in [GlobalEnvironment.canonicalApiPrefix, _prefix]) {
    test('legal $prefix reference maps only to international origin', () async {
      final requests = <http.Request>[];
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((request) async {
          requests.add(request);
          return _ok(_document('say_ring_privacy_policy'));
        }),
      );
      await api.getGlobalLegalDocument(
        '$prefix/content/legal/say_ring_privacy_policy?version=$_version&locale=en',
      );
      expect(
        requests.single.url.toString(),
        '${GlobalEnvironment.origin}$_prefix/content/legal/say_ring_privacy_policy?version=$_version&locale=en',
      );
      expect(requests.single.followRedirects, isFalse);
    });
  }

  for (final path in [
    '$_prefix/content/legal/user_agreement?version=v&locale=en',
    '$_prefix/content/legal/privacy_policy?version=v&locale=en',
    'https://app.saidian.cc/api/saydian-app/v2/content/legal/say_ring_privacy_policy?version=v&locale=en',
    'https://app.saydian.cn$_prefix/content/legal/say_ring_privacy_policy?version=v&locale=en',
    '//app.saydian.cn$_prefix/content/legal/say_ring_privacy_policy?version=v&locale=en',
    '/api/v1/articles/3',
    '$_prefix/content/articles/3?version=v&locale=en',
    '$_prefix/content/legal/../../members/me?version=v&locale=en',
    '$_prefix/content/legal/%252e%252e/members?version=v&locale=en',
    '$_prefix/content/legal/say_ring_privacy_policy?locale=en',
    '$_prefix/content/legal/say_ring_privacy_policy?version=&locale=en',
    '$_prefix/content/legal/say_ring_privacy_policy?version=v&version=other&locale=en',
    '$_prefix/content/legal/say_ring_privacy_policy?version=v&locale=unknown',
    '$_prefix/content/legal/say_ring_privacy_policy?version=v&locale=en&redirect=old',
    '$_prefix/content/legal/say_ring_privacy_policy?version=v&locale=en#fragment',
  ]) {
    test('unsafe legal reference rejected before any send: $path', () async {
      var requests = 0;
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((request) async {
          requests++;
          return _ok(_document('say_ring_privacy_policy'));
        }),
      );
      await expectLater(
        api.getGlobalLegalDocument(path),
        throwsA(isA<ApiException>()),
      );
      expect(requests, 0);
    });
  }
}
