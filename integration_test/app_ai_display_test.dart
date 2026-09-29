import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';

/// Controlled-configuration device UI test. No production account, secure vault,
/// backend write, Bluetooth connection, or health-store migration is used.
/// IMPORTANT: run flutter drive with --keep-app-running on a dedicated QA device.
/// The driver's default teardown uninstalls this package and its local data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('zh_Hans'));

  testWidgets('controlled display flag updates home and profile on device', (
    tester,
  ) async {
    final api = _DeviceDisplayApi();
    final controller = _controller(api);
    addTearDown(controller.dispose);
    await controller.refreshAppDisplayConfig();
    await _pumpShell(tester, controller);
    expect(find.byKey(const Key('dashboard-ai-assistant')), findsOneWidget);
    expect(find.text('运动'), findsOneWidget);

    api.hidden = true;
    await controller.refreshAppDisplayConfig();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-ai-assistant')), findsNothing);
    expect(find.text('运动'), findsOneWidget);
    expect(find.text('健康百科'), findsOneWidget);

    controller.selectTab(2);
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('my-page')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-ai-question')), findsNothing);
    expect(find.text('健康档案'), findsNothing);
    expect(find.text('联系客服'), findsOneWidget);

    api.hidden = false;
    await controller.refreshAppDisplayConfig();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-ai-question')), findsOneWidget);
    expect(find.text('健康档案'), findsOneWidget);
    expect(api.chatReads, 0);
  });

  testWidgets('controlled flag closes an already-open AI page on device', (
    tester,
  ) async {
    final api = _DeviceDisplayApi();
    final controller = _controller(api);
    addTearDown(controller.dispose);
    await controller.refreshAppDisplayConfig();
    await _pumpShell(tester, controller);
    await tester.tap(find.byKey(const Key('dashboard-ai-ask')));
    await tester.pumpAndSettle();
    expect(find.byType(AiChatPage), findsOneWidget);
    expect(api.chatReads, 1);

    api.hidden = true;
    await controller.refreshAppDisplayConfig();
    await tester.pumpAndSettle();
    expect(find.byType(AiChatPage), findsNothing);
    expect(find.byKey(const Key('dashboard-ai-assistant')), findsNothing);
    expect(find.text('运动'), findsOneWidget);
    expect(controller.aiMessages, isEmpty);
  });
}

Future<void> _pumpShell(WidgetTester tester, AppController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSaydianTheme(),
      home: ListenableBuilder(
        listenable: controller,
        builder: (_, _) => AppShell(controller: controller),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppController _controller(_DeviceDisplayApi api) =>
    AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _UnusedWearable(),
      )
      ..session = Session(
        accessToken: 'controlled-ui-fixture',
        refreshToken: 'controlled-ui-fixture',
        expiresAt: DateTime.utc(2099),
        memberId: 'controlled-ui-fixture',
        displayName: '界面测试',
        accountKey: 'controlled-ui-fixture',
      );

class _DeviceDisplayApi implements SaydianApi, SayRingAppDisplayApi {
  bool hidden = false;
  int chatReads = 0;

  @override
  Future<bool> getSayRingHideAi() async => hidden;

  @override
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  }) async {
    chatReads++;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedWearable implements WearableBridge {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
