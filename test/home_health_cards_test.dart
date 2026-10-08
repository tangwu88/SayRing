import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saydian_app/domain/home_health_cards.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/home_health_cards_page.dart';
import 'package:saydian_app/ui/pages.dart';

Session _session(String id) => Session(
  accessToken: 'synthetic',
  refreshToken: 'synthetic',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  accountKey: id,
  displayName: 'Test',
);

AppController _controller(MemorySessionVault vault) => AppController(
  vault,
  SaydianApiClient(
    vault,
    client: MockClient(
      (_) async => http.Response(jsonEncode({'code': 200, 'data': []}), 200),
    ),
  ),
  MemoryHealthStore(),
  MethodChannelWearableBridge(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('zh_Hans'));

  test('defaults and corrupt schema preserve existing card order', () {
    expect(HomeHealthCardLayout().visible, HomeHealthCardLayout.defaultOrder);
    for (final raw in [
      null,
      [],
      {'schemaVersion': 99},
      'bad',
    ]) {
      expect(
        HomeHealthCardLayout.fromJson(raw).visible,
        HomeHealthCardLayout.defaultOrder,
      );
    }
    final layout = HomeHealthCardLayout.fromJson({
      'schemaVersion': 1,
      'order': [
        'blood_oxygen',
        'unknown',
        'blood_oxygen',
        'steps',
        'heart_rate',
      ],
      'hidden': ['stress', 'unknown', 'steps'],
    });
    expect(layout.order.take(2), [
      HealthMetric.bloodOxygen,
      HealthMetric.heartRate,
    ]);
    expect(
      layout.order.toSet().length,
      HomeHealthCardLayout.defaultOrder.length,
    );
    expect(layout.hidden, {HealthMetric.stress});
    expect(HomeHealthCardLayout.fromJson(layout.toJson()).order, layout.order);
  });

  test(
    'reordering subset retains hidden and unavailable metric preferences',
    () {
      final layout = HomeHealthCardLayout().setVisible(
        HealthMetric.stress,
        false,
      );
      final reordered = layout.reorderVisible([
        HealthMetric.bloodOxygen,
        HealthMetric.heartRate,
      ]);
      expect(
        reordered.visible.indexOf(HealthMetric.bloodOxygen),
        lessThan(reordered.visible.indexOf(HealthMetric.heartRate)),
      );
      expect(reordered.hidden, {HealthMetric.stress});
      expect(reordered.order.length, layout.order.length);
      expect(
        layout.reorderVisible([HealthMetric.heartRate, HealthMetric.heartRate]),
        same(layout),
      );
      expect(layout.reorderVisible([HealthMetric.stress]), same(layout));
      expect(layout.setVisible(HealthMetric.stress, true).hidden, isEmpty);
    },
  );

  test('secure persistence is isolated by account and environment', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final first = SecureSessionVault.global(
      storageNamespace: List.filled(64, 'a').join(),
    );
    final otherEnvironment = SecureSessionVault.global(
      storageNamespace: List.filled(64, 'b').join(),
    );
    final layout = HomeHealthCardLayout().setVisible(
      HealthMetric.heartRate,
      false,
    );
    await first.writeHomeHealthCards('synthetic-owner-a', layout);
    expect(
      (await first.readHomeHealthCards('synthetic-owner-a')).hidden,
      layout.hidden,
    );
    expect(
      (await first.readHomeHealthCards('synthetic-owner-b')).hidden,
      isEmpty,
    );
    expect(
      (await otherEnvironment.readHomeHealthCards('synthetic-owner-a')).hidden,
      isEmpty,
    );
    final storage = const FlutterSecureStorage();
    final keys = (await storage.readAll()).keys.toList();
    expect(keys.single.contains('synthetic-owner-a'), isFalse);
    await storage.write(key: keys.single, value: '{bad');
    expect(
      (await first.readHomeHealthCards('synthetic-owner-a')).visible,
      HomeHealthCardLayout.defaultOrder,
    );
  });

  test(
    'save and restart retain layout while account and guest remain separate',
    () async {
      final vault = MemorySessionVault();
      final controller = _controller(vault)..session = _session('a');
      addTearDown(controller.dispose);
      await controller.loadHomeHealthCards();
      final owner = controller.homeHealthCardOwner;
      final draft = HomeHealthCardLayout(
        order: [HealthMetric.bloodOxygen, HealthMetric.heartRate],
      ).setVisible(HealthMetric.heartRate, false);
      expect(
        await controller.saveHomeHealthCards(draft, expectedOwner: owner),
        isTrue,
      );
      final restarted = _controller(vault)..session = _session('a');
      addTearDown(restarted.dispose);
      await restarted.loadHomeHealthCards();
      expect(
        restarted.homeHealthCardLayout.order.first,
        HealthMetric.bloodOxygen,
      );
      expect(restarted.homeHealthCardLayout.hidden, {HealthMetric.heartRate});
      restarted.session = _session('b');
      await restarted.loadHomeHealthCards();
      expect(restarted.homeHealthCardLayout.hidden, isEmpty);
      expect(
        await restarted.saveHomeHealthCards(draft, expectedOwner: owner),
        isFalse,
      );
      restarted.session = null;
      await restarted.loadHomeHealthCards();
      expect(restarted.homeHealthCardLayout.hidden, isEmpty);
    },
  );

  test(
    'failed save retains current layout and late reads cannot overwrite another account',
    () async {
      final failing = _FailingVault();
      final controller = _controller(failing);
      addTearDown(controller.dispose);
      expect(
        await controller.saveHomeHealthCards(
          HomeHealthCardLayout(hidden: HomeHealthCardLayout.defaultOrder),
          expectedOwner: controller.homeHealthCardOwner,
        ),
        isFalse,
      );
      expect(controller.homeHealthCardLayout.hidden, isEmpty);
      final delayed = _DelayedVault();
      final other = _controller(delayed)..session = _session('a');
      addTearDown(other.dispose);
      final pending = other.loadHomeHealthCards();
      other.session = _session('b');
      final second = other.loadHomeHealthCards();
      delayed.reads[1].complete(
        HomeHealthCardLayout(hidden: [HealthMetric.bloodOxygen]),
      );
      await second;
      delayed.reads[0].complete(
        HomeHealthCardLayout(hidden: [HealthMetric.heartRate]),
      );
      await pending;
      expect(other.homeHealthCardLayout.hidden, {HealthMetric.bloodOxygen});
    },
  );

  test('in-flight save cannot change a switched account', () async {
    final vault = _DelayedWriteVault();
    final controller = _controller(vault)..session = _session('a');
    addTearDown(controller.dispose);
    final owner = controller.homeHealthCardOwner;
    final draft = HomeHealthCardLayout(hidden: [HealthMetric.heartRate]);
    final save = controller.saveHomeHealthCards(draft, expectedOwner: owner);
    controller.session = _session('b');
    await controller.loadHomeHealthCards();
    vault.pending.complete();
    expect(await save, isFalse);
    expect(controller.homeHealthCardLayout.hidden, isEmpty);
    expect((await vault.readHomeHealthCards(owner)).hidden, draft.hidden);
  });

  testWidgets('failed save leaves editor open and reports unsaved settings', (
    tester,
  ) async {
    final controller = _controller(_FailingVault());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HomeHealthCardsPage(controller: controller),
      ),
    );
    await tester.tap(find.byKey(const Key('save-home-health-cards')));
    await tester.pumpAndSettle();
    expect(find.text('设置未保存，请返回后重试'), findsOneWidget);
    expect(find.text('编辑卡片'), findsOneWidget);
    expect(controller.homeHealthCardLayout.hidden, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editor cancels draft and saves hidden cards; unavailable metrics stay absent',
    (tester) async {
      final vault = MemorySessionVault();
      final controller = _controller(vault);
      addTearDown(controller.dispose);
      controller.healthRecords = [
        for (final metric in [HealthMetric.heartRate, HealthMetric.bloodOxygen])
          HealthRecord(
            id: metric.wireName,
            metric: metric,
            measuredAt: DateTime.utc(2026, 10, 8),
            values: {'value': 80},
            unit: metric.defaultUnit,
            timezone: 'UTC',
            deviceId: 'synthetic',
            firmwareVersion: '',
            quality: 'valid',
            source: MeasurementSource.wearable,
            rawVersion: 1,
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HomeHealthCardsPage(controller: controller),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('edit-home-card-stress')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('hide-home-card-heart_rate')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('show-home-card-heart_rate')),
        findsOneWidget,
      );
      expect(controller.homeHealthCardLayout.hidden, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(controller.homeHealthCardLayout.hidden, isEmpty);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final reorder = tester.widget<ReorderableListView>(
        find.byKey(const Key('home-health-cards-reorder')),
      );
      reorder.onReorderItem!(0, 1);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hide-home-card-heart_rate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-home-health-cards')));
      await tester.pumpAndSettle();
      expect(controller.homeHealthCardLayout.hidden, {HealthMetric.heartRate});
      expect(controller.homeHealthCardMetrics, [HealthMetric.bloodOxygen]);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('show-home-card-heart_rate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-home-health-cards')));
      await tester.pumpAndSettle();
      expect(controller.homeHealthCardMetrics, [
        HealthMetric.bloodOxygen,
        HealthMetric.heartRate,
      ]);
      expect(controller.healthRecords.length, 2);
    },
  );

  testWidgets(
    'homepage all-hidden empty state and editor render on narrow enlarged screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _controller(MemorySessionVault());
      addTearDown(controller.dispose);
      controller.healthRecords = [
        HealthRecord(
          id: 'synthetic',
          metric: HealthMetric.heartRate,
          measuredAt: DateTime.utc(2026, 10, 8),
          values: {'value': 72},
          unit: 'bpm',
          timezone: 'UTC',
          deviceId: 'synthetic',
          firmwareVersion: '',
          quality: 'valid',
          source: MeasurementSource.wearable,
          rawVersion: 1,
        ),
      ];
      controller.homeHealthCardLayout = HomeHealthCardLayout(
        hidden: HomeHealthCardLayout.defaultOrder,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(body: DashboardPage(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('edit-home-health-cards')),
      );
      await tester.pumpAndSettle();
      expect(find.text('首页暂无卡片，点击编辑添加'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-health-card-heart_rate')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('edit-home-health-cards')));
      await tester.pumpAndSettle();
      expect(find.text('编辑卡片'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('show-home-card-heart_rate')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _FailingVault extends MemorySessionVault {
  @override
  Future<void> writeHomeHealthCards(
    String owner,
    HomeHealthCardLayout layout,
  ) async => throw StateError('synthetic failure');
}

class _DelayedVault extends MemorySessionVault {
  final reads = <Completer<HomeHealthCardLayout>>[];
  @override
  Future<HomeHealthCardLayout> readHomeHealthCards(String owner) {
    final pending = Completer<HomeHealthCardLayout>();
    reads.add(pending);
    return pending.future;
  }
}

class _DelayedWriteVault extends MemorySessionVault {
  final pending = Completer<void>();
  @override
  Future<void> writeHomeHealthCards(
    String owner,
    HomeHealthCardLayout layout,
  ) async {
    await pending.future;
    await super.writeHomeHealthCards(owner, layout);
  }
}
