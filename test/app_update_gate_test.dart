import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_update_service.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/notification_route_service.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/app_update_gate_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'pending notification route is not consumed before required gate restores',
    (tester) async {
      final controller = _authenticatedController()
        ..pendingNotificationRoute = const NotificationRouteIntent(
          target: NotificationRouteTarget.notificationInbox,
          eventId: 'cold-start-event',
        );
      final requiredRead = Completer<AppUpdateInfo?>();
      final store = _UpdateGateStore(requiredRead.future);

      await tester.pumpWidget(
        SaydianApp(
          controller: controller,
          updateService: _iosUpdateService(
            MockClient((request) async => http.Response('', 503)),
          ),
          updateCheckStore: store,
        ),
      );
      await tester.pump();

      expect(find.text('正在为你准备…'), findsOneWidget);
      expect(controller.pendingNotificationRoute, isNotNull);

      requiredRead.complete(_requiredInfo());
      await tester.pumpAndSettle();

      expect(find.text('需要更新后继续使用'), findsOneWidget);
      expect(controller.pendingNotificationRoute, isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('online mandatory update collapses every pushed route', (
    tester,
  ) async {
    final controller = _authenticatedController();
    final requiredRead = Completer<AppUpdateInfo?>()..complete(null);
    final store = _UpdateGateStore(requiredRead.future);
    final response = Completer<http.Response>();
    var networkRequested = false;
    final service = _iosUpdateService(
      MockClient((request) {
        networkRequested = true;
        return response.future;
      }),
    );

    await tester.pumpWidget(
      SaydianApp(
        controller: controller,
        updateService: service,
        updateCheckStore: store,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byType(AppShell), findsOneWidget);
    expect(networkRequested, isTrue);

    final appContext = tester.element(find.byType(AppShell));
    unawaited(
      Navigator.of(appContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            key: Key('route-open-during-update-check'),
            body: Text('已打开的业务页'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('route-open-during-update-check')),
      findsOneWidget,
    );

    response.complete(
      http.Response(
        _mandatoryManifest(),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
        request: http.Request(
          'GET',
          Uri.parse('https://app.saidian.cc/app-update.json'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('需要更新后继续使用'), findsOneWidget);
    expect(
      find.byKey(const Key('route-open-during-update-check')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('corrected online manifest releases a persisted mandatory gate', (
    tester,
  ) async {
    final controller = _authenticatedController();
    final store = _UpdateGateStore(
      Future<AppUpdateInfo?>.value(_requiredInfo()),
    );
    final service = _iosUpdateService(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'schema_version': 1,
            'channel': 'production',
            'platform': 'ios',
            'latest_version': '0.2.0',
            'latest_build': 25,
            'minimum_supported_build': 18,
            'release_notes': '已取消必要更新限制',
            'published_at': '2026-08-29T00:00:00Z',
            'destination': {
              'type': 'app_store',
              'url': 'https://apps.apple.com/cn/app/saydian/id1234567890',
            },
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      SaydianApp(
        controller: controller,
        updateService: service,
        updateCheckStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('需要更新后继续使用'), findsNothing);
    expect(find.text('发现新版本 V0.2.0'), findsOneWidget);
    expect(store.writtenRequired, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('manual check enters the same root mandatory gate', (
    tester,
  ) async {
    final controller = _authenticatedController();
    final gate = AppUpdateGateController();
    final store = _UpdateGateStore(Future<AppUpdateInfo?>.value(null))
      ..lastSuccessfulCheck = DateTime.now().toUtc();
    final service = _iosUpdateService(
      MockClient(
        (_) async => http.Response(
          _mandatoryManifest(),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      SaydianApp(
        controller: controller,
        updateService: service,
        updateCheckStore: store,
        updateGateController: gate,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);

    final context = tester.element(find.byType(AppShell));
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            key: Key('route-open-before-manual-check'),
            body: Text('业务页'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await gate.checkNow();
    await tester.pumpAndSettle();

    expect(find.text('需要更新后继续使用'), findsOneWidget);
    expect(
      find.byKey(const Key('route-open-before-manual-check')),
      findsNothing,
    );
    expect(store.writtenRequired?.forceUpdate, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('manual mandatory update stays blocking when storage fails', (
    tester,
  ) async {
    final controller = _authenticatedController();
    final gate = AppUpdateGateController();
    final store = _UpdateGateStore(Future<AppUpdateInfo?>.value(null))
      ..lastSuccessfulCheck = DateTime.now().toUtc()
      ..failRequiredWrite = true;
    final service = _iosUpdateService(_ManifestClient(_mandatoryManifest()));

    await tester.pumpWidget(
      SaydianApp(
        controller: controller,
        updateService: service,
        updateCheckStore: store,
        updateGateController: gate,
      ),
    );
    await tester.pumpAndSettle();
    expect(gate.isAttached, isTrue);
    await gate.checkNow();
    await tester.pumpAndSettle();

    expect(
      find.text('需要更新后继续使用'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | '),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

AppController _authenticatedController() =>
    AppController(
        MemorySessionVault(),
        _TestApi(),
        MemoryHealthStore(),
        _TestWearable(),
      )
      ..isBooting = false
      ..session = Session(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        memberId: 'member-1',
        displayName: '测试用户',
      );

AppUpdateService _iosUpdateService(http.Client client) => AppUpdateService(
  client: client,
  manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
  targetPlatform: TargetPlatform.iOS,
  packageInfoLoader: () async => PackageInfo(
    appName: '赛电健康',
    packageName: 'cc.saidian.app',
    version: '0.1.19',
    buildNumber: '19',
  ),
);

AppUpdateInfo _requiredInfo() => AppUpdateInfo(
  currentVersion: '0.1.19',
  currentBuild: 19,
  latestVersion: '0.2.0',
  latestBuild: 25,
  minimumSupportedBuild: 20,
  destinationType: AppUpdateDestinationType.appStore,
  destinationUri: Uri.parse(
    'https://apps.apple.com/cn/app/saydian/id1234567890',
  ),
  releaseNotes: '必要安全更新',
  publishedAt: DateTime.utc(2026, 8, 29),
);

String _mandatoryManifest() => jsonEncode({
  'schema_version': 1,
  'channel': 'production',
  'platform': 'ios',
  'latest_version': '0.2.0',
  'latest_build': 25,
  'minimum_supported_build': 20,
  'release_notes': '必要安全更新',
  'published_at': '2026-08-29T00:00:00Z',
  'destination': {
    'type': 'app_store',
    'url': 'https://apps.apple.com/cn/app/saydian/id1234567890',
  },
});

class _UpdateGateStore implements AppUpdateCheckStore {
  _UpdateGateStore(this.requiredRead);

  final Future<AppUpdateInfo?> requiredRead;
  DateTime? lastSuccessfulCheck;
  AppUpdateInfo? writtenRequired;
  bool failRequiredWrite = false;

  @override
  Future<AppUpdateInfo?> readRequiredUpdate() => requiredRead;

  @override
  Future<void> writeRequiredUpdate(AppUpdateInfo? value) async {
    if (failRequiredWrite) throw StateError('secure storage unavailable');
    writtenRequired = value;
  }

  @override
  Future<DateTime?> readLastSuccessfulCheck() async => lastSuccessfulCheck;

  @override
  Future<void> writeLastSuccessfulCheck(DateTime value) async {
    lastSuccessfulCheck = value;
  }
}

class _ManifestClient extends http.BaseClient {
  _ManifestClient(this.body);

  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        request: request,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
}

class _TestApi extends Fake implements SaydianApi {}

class _TestWearable extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}
