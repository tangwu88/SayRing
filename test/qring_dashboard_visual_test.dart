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

  testWidgets('364dp activity keeps rings left of all three live values', (
    tester,
  ) async {
    final store = MemoryHealthStore();
    final controller = _Controller(store);
    await store.upsert([
      _record('compact-steps', HealthMetric.steps, 239, _today()),
      _record('compact-distance', HealthMetric.distance, .18, _today()),
      _record('compact-calories', HealthMetric.calories, 8920, _today()),
    ]);
    await _mount(tester, controller, width: 364, shell: true);
    await tester.pumpAndSettle();
    final ring = find.byKey(const Key('home-activity-rings'));
    for (final text in ['239', '0.18', '8920']) {
      final value = _activityText(text);
      expect(value, findsOneWidget);
      expect(
        tester.getCenter(value).dx,
        greaterThan(tester.getCenter(ring).dx),
      );
    }
    expect(tester.getSize(_activity).height, lessThan(350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('slow downward drag at the first health row never reverses', (
    tester,
  ) async {
    final controller = _Controller(MemoryHealthStore());
    controller.capabilities = const DeviceCapabilities(
      metrics: {
        HealthMetric.steps,
        HealthMetric.distance,
        HealthMetric.calories,
        HealthMetric.heartRate,
        HealthMetric.bloodOxygen,
        HealthMetric.bodyTemperature,
        HealthMetric.hrv,
        HealthMetric.stress,
      },
    );
    controller.healthRecords = [
      _record('steps-slow', HealthMetric.steps, 62, _today()),
      _record('heart-slow', HealthMetric.heartRate, 76, _today()),
      _record('oxygen-slow', HealthMetric.bloodOxygen, 97, _today()),
      _record('temp-slow', HealthMetric.bodyTemperature, 36.4, _today()),
      _record('hrv-slow', HealthMetric.hrv, 86, _today()),
      _record('stress-slow', HealthMetric.stress, 27, _today()),
    ];
    await _mount(tester, controller, width: 364, shell: true);
    await tester.pumpAndSettle();
    final heart = find.byKey(const ValueKey('home-health-card-heart_rate'));
    final scrollable = find
        .descendant(
          of: find.byType(DashboardPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(heart, 150, scrollable: scrollable);
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.pixels + tester.getTopLeft(heart).dy + 200);
    await tester.pumpAndSettle();
    final finger = await tester.startGesture(const Offset(180, 160));
    await finger.moveBy(const Offset(0, 20));
    await tester.pump();
    var previous = tester.getTopLeft(heart).dy;
    for (var index = 0; index < 600; index++) {
      await finger.moveBy(const Offset(0, 1));
      await tester.pump(const Duration(milliseconds: 16));
      final next = tester.getTopLeft(heart).dy;
      expect(
        next,
        greaterThanOrEqualTo(previous - .1),
        reason: 'frame $index offset ${position.pixels}',
      );
      previous = next;
    }
    await finger.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '364dp phone shows two health columns; enlarged text remains single column',
    (tester) async {
      final controller = _Controller(MemoryHealthStore());
      controller.capabilities = const DeviceCapabilities(
        metrics: {HealthMetric.heartRate, HealthMetric.bloodOxygen},
      );
      controller.healthRecords = [
        _record('heart-layout', HealthMetric.heartRate, 74, _today()),
        _record('oxygen-layout', HealthMetric.bloodOxygen, 98, _today()),
      ];
      await _mount(tester, controller, width: 364);
      await tester.pumpAndSettle();
      final heart = find.byKey(const ValueKey('home-health-card-heart_rate'));
      final oxygen = find.byKey(
        const ValueKey('home-health-card-blood_oxygen'),
      );
      expect(heart, findsOneWidget);
      expect(oxygen, findsOneWidget);
      expect(tester.getTopLeft(heart).dy, tester.getTopLeft(oxygen).dy);
      expect(
        tester.getTopLeft(oxygen).dx,
        greaterThan(tester.getTopLeft(heart).dx),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mini charts retain one read across non-health rebuilds and reload for new records',
    (tester) async {
      final controller = _Controller(MemoryHealthStore());
      var reads = 0;
      controller.readOverride = (metric, start, end) async {
        reads++;
        return [
          _record('first', metric, 72, _today()),
          _record(
            'last',
            metric,
            74,
            _today().add(const Duration(minutes: 10)),
          ),
        ];
      };
      await _mount(
        tester,
        controller,
        page: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, _) => HealthMetricMiniChart(
              controller: controller,
              metric: HealthMetric.heartRate,
              color: Colors.blue,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, 1);
      for (var i = 0; i < 5; i++) {
        controller.announceChange();
        await tester.pumpAndSettle();
      }
      expect(reads, 1);
      controller.healthRecords = [
        ...controller.healthRecords,
        _record('new', HealthMetric.heartRate, 76, _today()),
      ];
      controller.announceChange();
      await tester.pumpAndSettle();
      expect(reads, 2);
      controller.session = _session('owner-b');
      controller.announceChange();
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unconfirmed iOS calories never fill a kcal goal; steps survive',
    (tester) async {
      final store = MemoryHealthStore();
      final controller = _Controller(store);
      final day = _today();
      await store.upsert([
        _record('step-safe', HealthMetric.steps, 1234, day),
        _record(
          'qring:synthetic|calories|v3|pending',
          HealthMetric.calories,
          98760,
          day,
        ),
      ]);
      controller.healthRecords = await store.recent();
      await _mount(tester, controller);
      await tester.pumpAndSettle();
      expect(_activityText('1234'), findsOneWidget);
      expect(_activityText('单位待确认'), findsOneWidget);
      expect(_activityText('98760'), findsNothing);
      expect(_activityText('--'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets(
    'calorie mini chart excludes pending counts without suppressing confirmed data',
    (tester) async {
      final controller = _Controller(MemoryHealthStore());
      final day = _today();
      await _mount(
        tester,
        controller,
        page: Scaffold(
          body: HealthMetricMiniChart(
            controller: controller,
            metric: HealthMetric.calories,
            color: Colors.blue,
            records: [
              _record('known-a', HealthMetric.calories, 30, day),
              _record(
                'known-b',
                HealthMetric.calories,
                45,
                day.add(const Duration(hours: 1)),
              ),
              _record(
                'qring:synthetic|calories|v3|pending',
                HealthMetric.calories,
                98760,
                day,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.single.spots.map((p) => p.y), [30, 45]);
      expect(find.text('单位待确认'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'calorie history retains pending records with an explicit unknown-unit message',
    (tester) async {
      final store = MemoryHealthStore();
      final controller = _Controller(store);
      await store.upsert([
        _record(
          'qring:synthetic|calories|v3|pending',
          HealthMetric.calories,
          98760,
          _today(),
        ),
      ]);
      await _mount(
        tester,
        controller,
        page: HealthTrendPage(
          controller: controller,
          metric: HealthMetric.calories,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calorie-unit-unconfirmed')), findsOneWidget);
      expect(find.textContaining('98760'), findsNothing);
      expect(find.byType(LineChart), findsNothing);
      expect((await store.recent()).single.values['value'], 98760);
      expect(tester.takeException(), isNull);
    },
  );

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
