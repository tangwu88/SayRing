import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/module_visibility.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/module_visibility_service.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/shop_pages.dart';
import 'package:saydian_app/ui/global_shop_pages.dart';

Map<String, Object?> _config({
  bool library = false,
  bool mall = false,
  int validForSeconds = 300,
}) => {
  'product': 'say-ring',
  'platform': 'ios',
  'readOnlyHealth': {
    'schemaVersion': 1,
    'validForSeconds': 300,
    'metrics': {'heart_rate': true},
  },
  'moduleVisibility': {
    'schemaVersion': 1,
    'validForSeconds': validForSeconds,
    'modules': {'health_library': library, 'mall': mall},
  },
};

class _ModuleApi implements SayRingModuleVisibilityApi {
  Future<ModuleVisibilitySnapshot> Function() next = () async =>
      ModuleVisibilitySnapshot.fromMap(_config());
  int calls = 0;
  @override
  Future<ModuleVisibilitySnapshot> getModuleVisibility() {
    calls++;
    return next();
  }
}

class _Harness {
  _Harness({bool purchaseCeiling = false}) {
    final vault = MemorySessionVault();
    api = GlobalSaydianApiClient(
      vault,
      moduleVisibilityScopeIos: true,
      locale: () => 'zh-Hans',
      client: MockClient(_reply),
    );
    controller = AppController(
      vault,
      api,
      MemoryHealthStore(),
      MethodChannelWearableBridge(),
      wellnessOnly: true,
      commerceEnabled: purchaseCeiling,
      moduleVisibility: ModuleVisibilityLease(),
    );
  }
  late final GlobalSaydianApiClient api;
  late final AppController controller;
  bool library = false, mall = false;
  bool configFails = false;
  int validForSeconds = 300;
  int articleCalls = 0, catalogCalls = 0;
  String articleHtml = '<p>Synthetic article body</p>';
  final requests = <http.Request>[];
  Completer<http.Response>? delayedArticles;
  Future<http.Response> _reply(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    Object data;
    if (path.endsWith('support/app-display')) {
      if (configFails) throw const FormatException('Synthetic failure');
      data = _config(
        library: library,
        mall: mall,
        validForSeconds: validForSeconds,
      );
    } else if (path.endsWith('content/categories')) {
      data = {'items': <Object>[]};
    } else if (path.endsWith('content/articles')) {
      articleCalls++;
      if (delayedArticles != null) return delayedArticles!.future;
      data = {
        'items': [
          {'id': 'article-test', 'title': 'Synthetic library article'},
        ],
      };
    } else if (path.endsWith('commerce/home')) {
      catalogCalls++;
      data = {'categories': <Object>[], 'banners': <Object>[]};
    } else if (path.endsWith('content/articles/article-test')) {
      data = {
        'id': 'article-test',
        'title': 'Synthetic library article',
        'contentHtml': articleHtml,
      };
    } else if (path.endsWith('commerce/products')) {
      data = {
        'items': [
          {
            'id': 'product-test',
            'name': 'Synthetic catalog ring',
            'salePriceCents': 1000,
            'coverImage': '',
          },
        ],
        'total': 1,
      };
    } else if (path.endsWith('commerce/products/product-test')) {
      data = {
        'id': 'product-test',
        'name': 'Synthetic catalog ring',
        'descriptionHtml': '<p>Catalog fixture</p>',
        'skus': [
          {'id': 'sku-test', 'stock': 5, 'salePriceCents': 1000},
        ],
      };
    } else if (path.endsWith('commerce/capabilities')) {
      data = {
        'checkout': {
          'enabled': true,
          'countryCodes': ['CN'],
          'currency': 'CNY',
          'currencyExponent': 2,
        },
        'payments': <Object>[],
      };
    } else {
      throw StateError('Unexpected fixture route');
    }
    return http.Response(
      jsonEncode({'code': 200, 'data': data}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  bool _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.dispose();
  }
}

void main() {
  testWidgets(
    'article image enlargement closes when library access is revoked',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.library = true;
      h.articleHtml =
          '<p>Image fixture</p><img src="/global/media/synthetic-reader.png">';
      await h.controller.refreshModuleVisibility();
      await tester.pumpWidget(
        MaterialApp(
          home: ArticleDetailPage(
            controller: h.controller,
            article: const {'id': 'article-test'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看大图'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('article-image-viewer')), findsOneWidget);
      h.library = false;
      await h.controller.refreshModuleVisibility();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('article-image-viewer')), findsNothing);
      expect(
        find.byKey(const ValueKey('article-content-image-0')),
        findsNothing,
      );
      expect(find.text('Image fixture'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );

  test(
    'the original purchase ceiling still requires mall visibility',
    () async {
      final h = _Harness(purchaseCeiling: true);
      addTearDown(h.dispose);
      expect(h.controller.commerceEnabled, false);
      h.mall = true;
      await h.controller.refreshModuleVisibility();
      expect(h.controller.commerceEnabled, true);
      h.library = true;
      h.mall = false;
      await h.controller.refreshModuleVisibility();
      expect(h.controller.commerceEnabled, false);
      expect(h.controller.healthLibraryVisible, true);
    },
  );

  test('read route scope is opt-in and never changes capabilities', () async {
    for (final scoped in [false, true]) {
      final requests = <http.Request>[];
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        moduleVisibilityScopeIos: scoped,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {'items': <Object>[]},
            }),
            200,
          );
        }),
      );
      await api.getGlobalArticleCategories();
      await api.getGlobalArticles(categoryId: 'synthetic', page: 2);
      await api.getGlobalArticle('synthetic');
      await api.getShopHome();
      await api.getGlobalShopProducts(categoryId: 'synthetic', page: 3);
      await api.getGlobalShopProduct('synthetic');
      await api.getGlobalCommerceCapabilities();
      expect(requests, hasLength(7));
      for (final request in requests) {
        expect(request.url.host, 'app.saydian.cn');
        expect(request.url.path, startsWith('/global/api/saydian-app/v2/'));
        final expectedScope =
            scoped && !request.url.path.endsWith('/capabilities');
        expect(
          request.url.queryParameters['product'],
          expectedScope ? 'say-ring' : null,
        );
        expect(
          request.url.queryParameters['platform'],
          expectedScope ? 'ios' : null,
        );
      }
      expect(requests[1].url.queryParameters['categoryId'], 'synthetic');
      expect(requests[1].url.queryParameters['page'], '2');
      expect(requests[4].url.queryParameters['page'], '3');
    }
  });

  test('independent modules use an exact typed catalogue', () {
    for (final library in [true, false]) {
      for (final mall in [true, false]) {
        final value = ModuleVisibilitySnapshot.fromMap(
          _config(library: library, mall: mall),
        );
        expect(value.modules.contains(SayRingModule.healthLibrary), library);
        expect(value.modules.contains(SayRingModule.mall), mall);
      }
    }
    for (final change in <void Function(Map<String, Object?>)>[
      (m) => m.remove('moduleVisibility'),
      (m) => m['platform'] = 'android',
      (m) => m['product'] = 'saydian-health',
      (m) => (m['moduleVisibility'] as Map)['schemaVersion'] = '1',
      (m) => (m['moduleVisibility'] as Map)['validForSeconds'] = 301,
      (m) => (m['moduleVisibility'] as Map)['validForSeconds'] = 0,
      (m) =>
          ((m['moduleVisibility'] as Map)['modules'] as Map)['mall'] = 'true',
      (m) => ((m['moduleVisibility'] as Map)['modules'] as Map).remove(
        'health_library',
      ),
      (m) =>
          ((m['moduleVisibility'] as Map)['modules'] as Map)['reviewer'] = true,
    ]) {
      final data = jsonDecode(jsonEncode(_config())) as Map<String, dynamic>;
      change(data);
      expect(
        () => ModuleVisibilitySnapshot.fromMap(data),
        throwsFormatException,
      );
    }
  });

  test(
    'monotonic nonpersistent lease expires and same-grant renewal preserves readers',
    () {
      var now = Duration.zero;
      final lease = ModuleVisibilityLease(now: () => now);
      expect(lease.allows(SayRingModule.mall), false);
      lease.replace({SayRingModule.mall}, const Duration(seconds: 10));
      final generation = lease.generation;
      now += const Duration(seconds: 2);
      lease.replace({SayRingModule.mall}, const Duration(seconds: 10));
      expect(lease.generation, generation);
      now += const Duration(seconds: 10);
      expect(lease.allows(SayRingModule.mall), false);
      lease.replace({SayRingModule.mall}, const Duration(seconds: 10));
      expect(lease.generation, greaterThan(generation));
      lease.close();
      expect(lease.allows(SayRingModule.mall), false);
      expect(ModuleVisibilityLease().allows(SayRingModule.mall), false);
      expect(
        () => lease.replace({}, const Duration(seconds: 301)),
        throwsFormatException,
      );
    },
  );

  test(
    'invalid module object does not close the shared physiological parse',
    () async {
      var calls = 0;
      final data = _config()..remove('moduleVisibility');
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode({'code': 200, 'data': data}), 200);
        }),
      );
      final physiological = api.getReadOnlyHealthFeatures();
      final failed = expectLater(
        api.getModuleVisibility(),
        throwsFormatException,
      );
      expect((await physiological).metrics, {HealthMetric.heartRate});
      await failed;
      expect(calls, 1);
    },
  );

  test(
    'configuration failure closes only module lease and late disposed result cannot reopen it',
    () async {
      final api = _ModuleApi();
      final lease = ModuleVisibilityLease();
      final service = ModuleVisibilityService(lease: lease, api: api);
      api.next = () async =>
          ModuleVisibilitySnapshot.fromMap(_config(library: true));
      await service.refresh();
      expect(lease.allows(SayRingModule.healthLibrary), true);
      api.next = () async =>
          throw const FormatException('Synthetic invalid config');
      await service.refresh();
      expect(lease.allows(SayRingModule.healthLibrary), false);
      final pending = Completer<ModuleVisibilitySnapshot>();
      api.next = () => pending.future;
      final read = service.refresh();
      expect(service.refresh(), same(read));
      service.dispose();
      pending.complete(ModuleVisibilitySnapshot.fromMap(_config(mall: true)));
      await read;
      expect(lease.allows(SayRingModule.mall), false);
    },
  );

  test(
    'changing mall visibility does not discard an authorized library read',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.library = true;
      await h.controller.refreshModuleVisibility();
      h.delayedArticles = Completer<http.Response>();
      final read = h.controller.loadGlobalArticles();
      await Future<void>.delayed(Duration.zero);
      h.mall = true;
      await h.controller.refreshModuleVisibility();
      h.delayedArticles!.complete(
        http.Response(
          jsonEncode({
            'code': 200,
            'data': {'items': <Object>[]},
          }),
          200,
        ),
      );
      expect(await read, isEmpty);
    },
  );

  test(
    'closed and expired module prevent reads, including late success after revoke/reopen',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await expectLater(
        h.controller.loadGlobalArticles(),
        throwsA(isA<FeatureNotConfiguredException>()),
      );
      expect(h.articleCalls, 0);
      h.library = true;
      await h.controller.refreshModuleVisibility();
      h.delayedArticles = Completer<http.Response>();
      final read = h.controller.loadGlobalArticles();
      await Future<void>.delayed(Duration.zero);
      h.library = false;
      await h.controller.refreshModuleVisibility();
      h.library = true;
      await h.controller.refreshModuleVisibility();
      final rejected = expectLater(
        read,
        throwsA(isA<FeatureNotConfiguredException>()),
      );
      h.delayedArticles!.complete(
        http.Response(
          jsonEncode({
            'code': 200,
            'data': {
              'items': [
                {'id': 'late', 'title': 'Late public fixture'},
              ],
            },
          }),
          200,
        ),
      );
      await rejected;
    },
  );

  testWidgets(
    'device search keeps its original catalog entry without purchase permission',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.mall = true;
      await h.controller.refreshModuleVisibility();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: DeviceSearchPage(controller: h.controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.controller.commerceEnabled, false);
      expect(find.byKey(const Key('device-shop-entry')), findsOneWidget);
      h.mall = false;
      await h.controller.refreshModuleVisibility();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('device-shop-entry')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );

  testWidgets('homepage keeps the two original entries independent', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: ListenableBuilder(
          listenable: h.controller,
          builder: (context, _) =>
              Scaffold(body: DashboardPage(controller: h.controller)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final grid = find.byKey(const Key('dashboard-functions'));
    Finder entry(String label) =>
        find.descendant(of: grid, matching: find.text(label));
    expect(entry('健康百科'), findsNothing);
    expect(entry('赛电商城'), findsNothing);
    for (final (library, mall) in [
      (true, false),
      (false, true),
      (true, true),
      (false, false),
    ]) {
      h.library = library;
      h.mall = mall;
      await h.controller.refreshModuleVisibility();
      await tester.pumpAndSettle();
      expect(entry('健康百科'), library ? findsOneWidget : findsNothing);
      expect(entry('赛电商城'), mall ? findsOneWidget : findsNothing);
      expect(entry('远程关爱'), findsOneWidget);
      expect(entry('运动'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });

  testWidgets('expiry or refresh failure closes an already visible page', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    h.library = true;
    h.validForSeconds = 2;
    await h.controller.refreshModuleVisibility();
    await tester.pumpWidget(
      MaterialApp(home: ArticleCategoryPage(controller: h.controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Synthetic library article'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic library article'), findsNothing);
    expect(find.text('此功能暂未开放'), findsOneWidget);
    h.validForSeconds = 300;
    await h.controller.refreshModuleVisibility();
    await tester.pumpAndSettle();
    expect(find.text('Synthetic library article'), findsOneWidget);
    h.configFails = true;
    await h.controller.refreshModuleVisibility();
    await tester.pumpAndSettle();
    expect(find.text('Synthetic library article'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });

  testWidgets('closed original detail routes never reveal cached content', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    for (final page in <Widget>[
      ArticleDetailPage(
        controller: h.controller,
        article: const {
          'id': 'article-test',
          'title': 'Cached hidden article',
          'contentHtml': '<p>Cached hidden body</p>',
        },
      ),
      GlobalShopProductPage(
        controller: h.controller,
        productId: 'product-test',
      ),
      GlobalShopHomePage(controller: h.controller),
    ]) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
      expect(find.text('此功能暂未开放'), findsOneWidget);
      expect(find.textContaining('Cached hidden'), findsNothing);
    }
    expect(h.articleCalls, 0);
    expect(h.catalogCalls, 0);
    expect(
      h.requests.any(
        (r) =>
            r.url.path.contains('/content/') ||
            r.url.path.contains('/commerce/products'),
      ),
      false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });

  testWidgets(
    'already open original library hides and reopens through the independent setting',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: ArticleCategoryPage(controller: h.controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('此功能暂未开放'), findsOneWidget);
      expect(h.articleCalls, 0);
      h.library = true;
      await h.controller.refreshModuleVisibility();
      await tester.pumpAndSettle();
      expect(find.text('Synthetic library article'), findsOneWidget);
      h.library = false;
      await h.controller.refreshModuleVisibility();
      await tester.pumpAndSettle();
      expect(find.text('Synthetic library article'), findsNothing);
      expect(find.text('此功能暂未开放'), findsOneWidget);
      h.library = true;
      await h.controller.refreshModuleVisibility();
      await tester.pumpAndSettle();
      expect(find.text('Synthetic library article'), findsOneWidget);
      final scoped = h.requests.where((r) => r.url.path.contains('/content/'));
      expect(scoped, isNotEmpty);
      expect(
        scoped.every(
          (r) =>
              r.url.queryParameters['product'] == 'say-ring' &&
              r.url.queryParameters['platform'] == 'ios',
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );

  testWidgets(
    'existing mall can browse without lifting the closed purchase ceiling',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.mall = true;
      await h.controller.refreshModuleVisibility();
      expect(h.controller.mallVisible, true);
      expect(h.controller.commerceEnabled, false);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: ShopHomePage(controller: h.controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic catalog ring'), findsOneWidget);
      expect(find.byKey(const Key('global-shop-cart-action')), findsNothing);
      await tester.tap(find.text('Synthetic catalog ring'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('global-product-buy-now')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('global-product-add-cart')),
            )
            .onPressed,
        isNull,
      );
      expect(
        h.requests.any(
          (r) =>
              r.url.path.contains('/cart') ||
              r.url.path.contains('/orders') ||
              r.url.path.contains('/payments'),
        ),
        false,
      );
      h.mall = false;
      await h.controller.refreshModuleVisibility();
      await tester.pumpAndSettle();
      expect(find.text('Synthetic catalog ring'), findsNothing);
      expect(find.byKey(const Key('module-unavailable')), findsOneWidget);
      final reads = h.requests.where(
        (r) =>
            r.url.path.contains('/commerce/') &&
            !r.url.path.endsWith('/capabilities'),
      );
      expect(
        reads.every(
          (r) =>
              r.url.queryParameters['product'] == 'say-ring' &&
              r.url.queryParameters['platform'] == 'ios',
        ),
        true,
      );
      final capabilities = h.requests.where(
        (r) => r.url.path.endsWith('/capabilities'),
      );
      expect(
        capabilities.every(
          (r) => !r.url.queryParameters.containsKey('product'),
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );
}
