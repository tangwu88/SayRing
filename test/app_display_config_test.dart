import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saydian_app/domain/health_report_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/ai_content_gate.dart';
import 'package:saydian_app/ui/health_reports_page.dart';
import 'package:saydian_app/ui/pages.dart';

void main() {
  setUpAll(() => initializeDateFormatting('zh_Hans'));
  test('display request is public, product-bound and isolated', () async {
    for (final hidden in [true, false]) {
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'app.saydian.cn');
          expect(
            request.url.path,
            '/global/api/saydian-app/v2/support/app-display',
          );
          expect(request.url.queryParameters, {'product': 'say-ring'});
          expect(request.headers.containsKey('Authorization'), isFalse);
          return _ok({'product': 'say-ring', 'hideAi': hidden});
        }),
      );
      expect(await api.getSayRingHideAi(), hidden);
    }
  });

  test(
    'display response rejects wrong product and non-boolean flags',
    () async {
      for (final data in [
        {'product': 'watch', 'hideAi': false},
        {'product': 'say-ring', 'hideAi': 'false'},
        {'product': 'say-ring'},
      ]) {
        final api = GlobalSaydianApiClient(
          MemorySessionVault(),
          client: MockClient((_) async => _ok(data)),
        );
        await expectLater(api.getSayRingHideAi(), throwsA(isA<ApiException>()));
      }
    },
  );

  test(
    'first load stays hidden; accepted setting survives failed refresh and restart',
    () async {
      final vault = MemorySessionVault();
      final api = _DisplayApi()..fail = true;
      final controller = _controller(api, vault: vault);
      addTearDown(controller.dispose);
      expect(controller.hideAiContent, isTrue);
      await controller.refreshAppDisplayConfig();
      expect(controller.hideAiContent, isTrue);
      api
        ..fail = false
        ..hidden = false;
      await controller.refreshAppDisplayConfig();
      expect(controller.hideAiContent, isFalse);
      expect(vault.sayRingHideAi, isFalse);
      api.fail = true;
      await controller.refreshAppDisplayConfig();
      expect(controller.hideAiContent, isFalse);
      final restarted = _controller(api, vault: vault);
      addTearDown(restarted.dispose);
      await restarted.refreshAppDisplayConfig();
      expect(restarted.hideAiContent, isFalse);
      api
        ..fail = false
        ..hidden = true;
      await restarted.refreshAppDisplayConfig();
      expect(restarted.hideAiContent, isTrue);
      expect(vault.sayRingHideAi, isTrue);
    },
  );

  test(
    'resume refreshes display setting without requiring a session',
    () async {
      final api = _DisplayApi()..hidden = false;
      final controller = _controller(api);
      addTearDown(controller.dispose);
      await controller.refreshAppDisplayConfig();
      api.hidden = true;
      await controller.handleAppResumed();
      await controller.refreshAppDisplayConfig();
      expect(controller.hideAiContent, isTrue);
    },
  );

  test(
    'hidden AI blocks chat, reports, consent and new purchases before API calls',
    () async {
      final api = _DisplayApi();
      final controller = _controller(api);
      addTearDown(controller.dispose);
      await controller.refreshAiMessages(app: 1);
      expect(await controller.sendAiMessage(app: 1, message: 'test'), isFalse);
      for (final action in <Future<Object?> Function()>[
        controller.loadHealthReportDashboard,
        controller.createHealthReport,
        () => controller.retryHealthReport('report'),
        () => controller.loadFullHealthReport('report'),
        () => controller.exportHealthReport('report'),
        () => controller.setHealthAnalysisConsent(true, version: 'test'),
        () => controller.startHealthPurchase(
          offer: HealthReportOffer.fromMap({'id': 'test'}),
          report: HealthReportSummary.fromMap({
            'id': 'test',
            'status': 'awaiting_payment',
          }),
        ),
        controller.restoreAppleHealthPurchases,
      ]) {
        await expectLater(
          action(),
          throwsA(isA<FeatureNotConfiguredException>()),
        );
      }
      expect(api.aiRequests, 0);
    },
  );

  test(
    'late chat reply does not reappear after hiding and re-enabling',
    () async {
      final api = _DisplayApi()..hidden = false;
      final controller = _controller(api);
      addTearDown(controller.dispose);
      await controller.refreshAppDisplayConfig();
      controller.session = Session(
        accessToken: 'test',
        refreshToken: 'test',
        expiresAt: DateTime.utc(2099),
        memberId: 'test',
        displayName: 'Test',
        accountKey: 'test',
      );
      api.reply = Completer<Map<String, Object?>>();
      final send = controller.sendAiMessage(app: 1, message: 'hello');
      api.hidden = true;
      await controller.refreshAppDisplayConfig();
      expect(controller.aiMessages, isEmpty);
      api.hidden = false;
      await controller.refreshAppDisplayConfig();
      api.reply!.complete({'message': 'late reply'});
      expect(await send, isFalse);
      expect(controller.aiMessages, isEmpty);
      expect(controller.isBusy, isFalse);
    },
  );

  testWidgets('home hides AI while health, sport and encyclopedia remain', (
    tester,
  ) async {
    final api = _DisplayApi()..hidden = false;
    final controller = _controller(api);
    addTearDown(controller.dispose);
    await controller.refreshAppDisplayConfig();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: Scaffold(body: DashboardPage(controller: controller)),
      ),
    );
    expect(find.byKey(const Key('dashboard-ai-assistant')), findsOneWidget);
    api.hidden = true;
    await controller.refreshAppDisplayConfig();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-ai-assistant')), findsNothing);
    expect(find.text('运动'), findsOneWidget);
    expect(find.text('健康百科'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-functions')), findsOneWidget);
  });

  testWidgets(
    'profile excludes chat and AI health archive but keeps normal services',
    (tester) async {
      final api = _DisplayApi()..hidden = true;
      final controller = _controller(api);
      addTearDown(controller.dispose);
      await controller.refreshAppDisplayConfig();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: Scaffold(body: SettingsPage(controller: controller)),
        ),
      );
      await tester.drag(
        find.byKey(const Key('my-page')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('my-ai-question')), findsNothing);
      expect(find.text('健康档案'), findsNothing);
      expect(find.text('联系客服'), findsOneWidget);
      expect(find.text('单位设置'), findsOneWidget);
      api.hidden = false;
      await controller.refreshAppDisplayConfig();
      await tester.pumpAndSettle();
      expect(find.text('健康档案'), findsOneWidget);
      expect(find.byKey(const Key('my-ai-question')), findsOneWidget);
    },
  );

  testWidgets('already open chat and its dialog close when hiding is enabled', (
    tester,
  ) async {
    final api = _DisplayApi()..hidden = false;
    final controller = _controller(api);
    addTearDown(controller.dispose);
    await controller.refreshAppDisplayConfig();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('home')),
      ),
    );
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => AiChatPage(controller: controller, app: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI 健康管家'), findsOneWidget);
    unawaited(
      showDialog<void>(
        context: tester.element(find.byType(AiChatPage)),
        builder: (_) => const AlertDialog(title: Text('dialog')),
      ),
    );
    await tester.pumpAndSettle();
    api.hidden = true;
    await controller.refreshAppDisplayConfig();
    await tester.pumpAndSettle();
    expect(find.byType(AiChatPage), findsNothing);
    expect(find.text('dialog'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets(
    'nested AI routes close without removing the preceding normal page',
    (tester) async {
      final api = _DisplayApi()..hidden = false;
      final controller = _controller(api);
      addTearDown(controller.dispose);
      await controller.refreshAppDisplayConfig();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('home')),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('normal page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['first AI page', 'second AI page']) {
        unawaited(
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => AiContentGate(
                controller: controller,
                builder: (_) => Scaffold(body: Text(label)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      api.hidden = true;
      await controller.refreshAppDisplayConfig();
      await tester.pumpAndSettle();
      expect(find.byType(AiContentGate), findsNothing);
      expect(find.text('normal page'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
    },
  );

  testWidgets('direct AI and report routes stay empty while hidden', (
    tester,
  ) async {
    final api = _DisplayApi();
    final controller = _controller(api);
    addTearDown(controller.dispose);
    for (final page in <Widget>[
      AiPage(controller: controller),
      AiChatPage(controller: controller, app: 2),
      HealthProfilePage(controller: controller),
      HealthReportDetailPage(
        controller: controller,
        report: HealthReportSummary.fromMap({'id': 'test'}),
      ),
    ]) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
      expect(find.text('此功能暂未开放'), findsOneWidget);
      expect(find.byKey(const Key('health-report-pay')), findsNothing);
      expect(find.byKey(const Key('health-report-share')), findsNothing);
    }
    expect(api.aiRequests, 0);
  });
}

http.Response _ok(Map<String, Object?> data) =>
    http.Response(jsonEncode({'code': 200, 'data': data}), 200);

AppController _controller(_DisplayApi api, {MemorySessionVault? vault}) =>
    AppController(
      vault ?? MemorySessionVault(),
      api,
      MemoryHealthStore(),
      _Wearable(),
    );

class _DisplayApi implements SaydianApi, SayRingAppDisplayApi {
  bool hidden = true;
  bool fail = false;
  int aiRequests = 0;
  Completer<Map<String, Object?>>? reply;

  @override
  Future<bool> getSayRingHideAi() async {
    if (fail) throw const ApiException('test offline');
    return hidden;
  }

  @override
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  }) async {
    aiRequests++;
    return [];
  }

  @override
  Future<Map<String, Object?>> sendAiMessage({
    required int app,
    required String message,
    String? sessionId,
  }) {
    aiRequests++;
    return reply!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wearable implements WearableBridge {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
