import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/health_trend_page.dart';
import 'package:saydian_app/ui/pages.dart';

const _device = DeviceInfo(id: 'qring:synthetic-ui-r12', name: 'R12');

Session _session(String owner) => Session(
  accessToken: 'synthetic-only',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: owner,
  accountKey: 'global:$owner',
  displayName: 'Test',
);

HealthRecord _record(String id, HealthMetric metric, num value, DateTime at) =>
    HealthRecord(
      id: id,
      metric: metric,
      values: {'value': value},
      unit: metric.defaultUnit,
      measuredAt: at,
      timezone: _timezone(at),
      deviceId: _device.id,
      firmwareVersion: 'synthetic',
      quality: 'synthetic-test-only',
      source: MeasurementSource.wearable,
      sourceVendor: 'qring',
      rawVersion: 3,
    );

String _timezone(DateTime at) {
  final offset = at.timeZoneOffset;
  final minutes = offset.inMinutes.abs();
  return '${offset.isNegative ? '-' : '+'}'
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
}

class _Api extends Fake implements SaydianApi {}

class _Bridge extends Fake implements WearableBridge {}

typedef _Read =
    Future<List<HealthRecord>> Function(
      HealthMetric metric,
      DateTime start,
      DateTime end,
    );

class _Controller extends AppController {
  _Controller(MemoryHealthStore store)
    : super(
        MemorySessionVault(),
        _Api(),
        store,
        _Bridge(),
        generalAiEnabled: false,
      ) {
    session = _session('owner-a');
    connectedDevice = _device;
    capabilities = const DeviceCapabilities(
      metrics: {
        HealthMetric.steps,
        HealthMetric.distance,
        HealthMetric.calories,
      },
    );
  }

  _Read? readOverride;

  @override
  Future<List<HealthRecord>> loadHealthRecords({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) =>
      readOverride?.call(metric, start, end) ??
      super.loadHealthRecords(metric: metric, start: start, end: end);

  void announceChange() => notifyListeners();
}

Finder get _activity => find.byKey(const Key('dashboard-today-health'));

Finder _activityText(String text) =>
    find.descendant(of: _activity, matching: find.text(text));

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Future<void> _mount(
  WidgetTester tester,
  _Controller controller, {
  double width = 390,
  double textScale = 1,
  bool shell = false,
  Widget? page,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSaydianTheme(),
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home:
          page ??
          (shell
              ? ListenableBuilder(
                  listenable: controller,
                  builder: (_, _) => AppShell(controller: controller),
                )
              : Scaffold(body: DashboardPage(controller: controller))),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => initializeDateFormatting('zh_Hans'));

  testWidgets('home sums the full saved day beyond the recent record cache', (
    tester,
  ) async {
    final store = MemoryHealthStore();
    final controller = _Controller(store);
    final day = _today();
    final records = [
      for (var i = 0; i < 256; i++)
        _record(
          'today-$i',
          HealthMetric.steps,
          1,
          day.add(Duration(minutes: i + 1)),
        ),
    ];
    await store.upsert(records);
    // The ordinary dashboard cache cannot supply the complete daily total.
    controller.healthRecords = await store.recent(limit: 200);
    expect(controller.healthRecords, hasLength(200));
    await _mount(tester, controller);
    await tester.pumpAndSettle();
    expect(_activityText('256'), findsOneWidget);
    expect(_activityText('200'), findsNothing);
    expect(_activityText('--'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home activity excludes previous and following calendar days', (
    tester,
  ) async {
    final store = MemoryHealthStore();
    final controller = _Controller(store);
    final day = _today();
    await store.upsert([
      _record(
        'yesterday',
        HealthMetric.steps,
        7000,
        day.subtract(const Duration(minutes: 1)),
      ),
      _record('today', HealthMetric.steps, 125, day),
      _record(
        'tomorrow',
        HealthMetric.steps,
        9000,
        day.add(const Duration(days: 1)),
      ),
    ]);
    controller.healthRecords = await store.recent();
    await _mount(tester, controller);
    await tester.pumpAndSettle();
    expect(_activityText('125'), findsOneWidget);
    expect(_activityText('16125'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing activity remains unknown rather than zero', (
    tester,
  ) async {
    final controller = _Controller(MemoryHealthStore());
    await _mount(tester, controller);
    await tester.pumpAndSettle();
    expect(_activityText('暂无今日活动数据'), findsOneWidget);
    expect(_activityText('--'), findsNWidgets(3));
    expect(_activityText('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed activity read can retry without hiding the entry', (
    tester,
  ) async {
    final controller = _Controller(MemoryHealthStore());
    var fail = true;
    controller.readOverride = (metric, start, end) async {
      if (metric != HealthMetric.steps) return [];
      if (fail) throw StateError('synthetic storage read failure');
      return [_record('recovered', metric, 678, start)];
    };
    await _mount(tester, controller);
    await tester.pumpAndSettle();
    final retry = find.text('今日活动读取失败，点击重试');
    expect(retry, findsOneWidget);
    expect(_activity, findsOneWidget);
    fail = false;
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(retry, findsNothing);
    expect(_activityText('678'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an old owner response cannot overwrite the new owner activity', (
    tester,
  ) async {
    final controller = _Controller(MemoryHealthStore());
    final pendingOld = Completer<List<HealthRecord>>();
    controller.readOverride = (metric, start, end) async {
      if (metric != HealthMetric.steps) return [];
      if (controller.session!.memberId == 'owner-a') {
        return pendingOld.future;
      }
      return [_record('new-owner', metric, 321, start)];
    };
    await _mount(tester, controller);
    controller.session = _session('owner-b');
    controller.announceChange();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(_activityText('321'), findsOneWidget);
    pendingOld.complete([
      _record('late-old-owner', HealthMetric.steps, 9876, _today()),
    ]);
    await tester.pumpAndSettle();
    expect(_activityText('321'), findsOneWidget);
    expect(_activityText('9876'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sync notifications coalesce while a day read is pending and show its first result',
    (tester) async {
      final controller = _Controller(MemoryHealthStore());
      final first = Completer<List<HealthRecord>>();
      final second = Completer<List<HealthRecord>>();
      var stepReads = 0;
      controller.readOverride = (metric, start, end) {
        if (metric != HealthMetric.steps) return Future.value([]);
        stepReads++;
        return stepReads == 1 ? first.future : second.future;
      };
      await _mount(tester, controller);
      expect(stepReads, 1);

      // A slow database read must not be multiplied by ongoing sync progress.
      // Each tick lasts beyond the usual refresh window, while the same owner
      // and exact device remain active.
      for (var i = 0; i < 4; i++) {
        controller.announceChange();
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(stepReads, 1);

      first.complete([
        _record('first-readable', HealthMetric.steps, 222, _today()),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(stepReads, 2);
      // A single trailing read is still pending, but the saved first result
      // must already be visible rather than waiting for all sync to finish.
      expect(_activityText('222'), findsOneWidget);
      expect(second.isCompleted, isFalse);

      second.complete([
        _record('trailing-readable', HealthMetric.steps, 333, _today()),
      ]);
      await tester.pumpAndSettle();
      expect(_activityText('333'), findsOneWidget);
      expect(stepReads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('320px large text keeps goals, activity trends and tabs usable', (
    tester,
  ) async {
    final store = MemoryHealthStore();
    final controller = _Controller(store);
    await store.upsert([
      _record('large-text-steps', HealthMetric.steps, 6280, _today()),
    ]);
    await _mount(tester, controller, width: 320, textScale: 2, shell: true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final goals = find.descendant(of: _activity, matching: find.text('目标'));
    await tester.ensureVisible(goals);
    await tester.tap(goals);
    await tester.pumpAndSettle();
    expect(find.byType(GoalSettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final ring = find.byKey(const Key('home-activity-rings'));
    await tester.ensureVisible(ring);
    await tester.tap(ring);
    await tester.pumpAndSettle();
    expect(find.byType(HealthTrendPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final deviceTab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('设备'),
    );
    await tester.tap(deviceTab);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-page')), findsOneWidget);
    final profileTab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('我的'),
    );
    await tester.tap(profileTab);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final count in [0, 1]) {
    testWidgets('a $count-point health history never invents a trend line', (
      tester,
    ) async {
      final controller = _Controller(MemoryHealthStore());
      await _mount(
        tester,
        controller,
        page: Scaffold(
          body: HealthMetricMiniChart(
            controller: controller,
            metric: HealthMetric.heartRate,
            color: Colors.blue,
            records: [
              if (count == 1)
                _record('single', HealthMetric.heartRate, 68, _today()),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsNothing);
      expect(find.text(count == 0 ? '暂无数据' : '仅 1 条记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
