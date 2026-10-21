import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/health_trend_page.dart';
import 'package:saydian_app/ui/sleep_detail_widgets.dart';

// Synthetic rendering fixtures. These are not device or sleep-accuracy evidence.
class _VisualController extends Fake implements AppController {
  final List<HealthRecord> stored = [];
  int healthReads = 0;

  @override
  bool isMetricAvailableInRelease(HealthMetric metric) => true;
  @override
  bool get isWellnessOnly => false;
  @override
  bool get isGlobalEdition => true;
  @override
  bool get sleepAiEnabled => false;
  @override
  bool get isDeviceSyncing => false;
  @override
  Session? get session => null;
  @override
  DeviceInfo? get connectedDevice => null;
  @override
  DeviceInfo? get rememberedDevice => null;
  @override
  DeviceCapabilities? get capabilities => null;
  @override
  Map<String, String> get sleepReadStatuses => {};
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  Future<HealthRecord?> loadLatestSleepDay() async =>
      stored.where((record) => record.metric == HealthMetric.sleep).firstOrNull;
  @override
  Future<List<HealthRecord>> loadSleepDays({
    required DateTime start,
    required DateTime end,
  }) async =>
      stored.where((record) => record.metric == HealthMetric.sleep).toList();
  @override
  Future<List<HealthRecord>> loadHealthRecords({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) async {
    healthReads++;
    return stored
        .where(
          (record) =>
              record.metric == metric &&
              !record.measuredAt.isBefore(start) &&
              record.measuredAt.isBefore(end),
        )
        .toList();
  }
}

HealthRecord _record({
  required String id,
  required DateTime at,
  HealthMetric metric = HealthMetric.heartRate,
  num value = 72,
  String timezone = '+08:00',
  SleepTimeline? timeline,
}) => HealthRecord(
  id: id,
  metric: metric,
  values: timeline?.summaryValues ?? {'value': value},
  unit: metric == HealthMetric.sleep ? 'h' : 'bpm',
  measuredAt: at,
  timezone: timezone,
  deviceId: 'qring:visual-fixture',
  firmwareVersion: 'fixture',
  quality: 'test_only',
  source: MeasurementSource.wearable,
  rawVersion: 1,
  sleepTimeline: timeline,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSaydianTheme(),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('zh_Hans'));

  testWidgets(
    'mini chart keeps only the displayed current day and requested metric',
    (tester) async {
      final controller = _VisualController();
      final now = DateTime.now();
      // Stored +08:00 midnight differs from the host timezone in the UTC gate.
      final midnight = DateTime.utc(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(hours: 8));
      final records = [
        _record(
          id: 'previous-day',
          at: midnight.subtract(const Duration(minutes: 1)),
          value: 180,
        ),
        _record(id: 'midnight', at: midnight, value: 60),
        _record(
          id: 'morning',
          at: midnight.add(const Duration(hours: 8)),
          value: 72,
        ),
        _record(
          id: 'last-minute',
          at: midnight.add(const Duration(hours: 23, minutes: 59)),
          value: 65,
        ),
        _record(
          id: 'next-day',
          at: midnight.add(const Duration(days: 1)),
          value: 190,
        ),
        _record(
          id: 'other-metric',
          at: midnight.add(const Duration(hours: 12)),
          metric: HealthMetric.bloodOxygen,
          value: 98,
        ),
      ];
      await _pump(
        tester,
        Scaffold(
          body: HealthMetricMiniChart(
            controller: controller,
            metric: HealthMetric.heartRate,
            color: Colors.blue,
            records: records,
            height: 76,
          ),
        ),
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.minX, 0);
      expect(chart.data.maxX, 24);
      expect(chart.data.lineBarsData.single.spots.map((point) => point.y), [
        60,
        72,
        65,
      ]);
      expect(chart.data.lineBarsData.single.spots.map((point) => point.x), [
        0,
        8,
        23 + 59 / 60,
      ]);
      expect(chart.data.lineBarsData.single.isCurved, isFalse);
      expect(tester.getSize(find.byType(LineChart)).height, 76);
      expect(
        controller.healthReads,
        0,
        reason: 'Explicit remote records never fall back to the local store.',
      );
      expect(
        records.length,
        6,
        reason: 'The chart never removes stored source records.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fitted mini chart uses actual sorted samples and exposes their time bounds',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final controller = _VisualController();
        final now = DateTime.now();
        final midnight = DateTime.utc(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(hours: 8));
        await _pump(
          tester,
          Scaffold(
            body: HealthMetricMiniChart(
              controller: controller,
              metric: HealthMetric.heartRate,
              color: Colors.blue,
              fitToSamples: true,
              height: 60,
              records: [
                _record(
                  id: 'last',
                  at: midnight.add(const Duration(hours: 11, minutes: 20)),
                  value: 68,
                ),
                _record(
                  id: 'old',
                  at: midnight.subtract(const Duration(minutes: 1)),
                  value: 150,
                ),
                _record(
                  id: 'first',
                  at: midnight.add(const Duration(hours: 8, minutes: 5)),
                  value: 72,
                ),
                _record(
                  id: 'middle',
                  at: midnight.add(const Duration(hours: 9)),
                  value: 80,
                ),
                _record(
                  id: 'next',
                  at: midnight.add(const Duration(days: 1)),
                  value: 180,
                ),
              ],
            ),
          ),
          scale: 2,
        );
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.data.minX, 8 + 5 / 60);
        expect(chart.data.maxX, 11 + 20 / 60);
        expect(chart.data.lineBarsData.single.spots.map((point) => point.y), [
          72,
          80,
          68,
        ]);
        expect(chart.data.lineBarsData.single.isCurved, isFalse);
        expect(tester.getSize(find.byType(LineChart)).height, 60);
        expect(find.text('08:05'), findsOneWidget);
        expect(find.text('11:20'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('心率今日趋势，08:05 至 11:20，共3个数据点')),
          findsOneWidget,
        );
        expect(controller.healthReads, 0);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final count in [0, 1]) {
    testWidgets('fitted mini chart keeps a $count-point history uncharted', (
      tester,
    ) async {
      final controller = _VisualController();
      final now = DateTime.now();
      final at = DateTime.utc(now.year, now.month, now.day, 2);
      await _pump(
        tester,
        Scaffold(
          body: HealthMetricMiniChart(
            controller: controller,
            metric: HealthMetric.heartRate,
            color: Colors.blue,
            fitToSamples: true,
            height: 60,
            records: [
              for (var index = 0; index < count; index++)
                _record(id: 'point-$index', at: at),
            ],
          ),
        ),
      );
      expect(find.byType(LineChart), findsNothing);
      expect(find.text(count == 0 ? '暂无数据' : '仅 1 条记录'), findsOneWidget);
      expect(find.byKey(const Key('health-mini-first-time')), findsNothing);
      expect(controller.healthReads, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fitted simultaneous samples never invent a time span', (
    tester,
  ) async {
    final controller = _VisualController();
    final now = DateTime.now();
    final at = DateTime.utc(now.year, now.month, now.day, 2);
    await _pump(
      tester,
      Scaffold(
        body: HealthMetricMiniChart(
          controller: controller,
          metric: HealthMetric.heartRate,
          color: Colors.blue,
          fitToSamples: true,
          height: 60,
          records: [
            _record(id: 'same-time-a', at: at, value: 68),
            _record(id: 'same-time-b', at: at, value: 72),
          ],
        ),
      ),
    );
    expect(find.byType(LineChart), findsNothing);
    expect(find.byKey(const Key('health-mini-first-time')), findsNothing);
    expect(find.byKey(const Key('health-mini-last-time')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty explicit mini chart remains empty without reading local history',
    (tester) async {
      final controller = _VisualController();
      await _pump(
        tester,
        Scaffold(
          body: HealthMetricMiniChart(
            controller: controller,
            metric: HealthMetric.heartRate,
            color: Colors.blue,
            records: const [],
            showEmptyLabel: false,
            height: 76,
          ),
        ),
      );
      expect(find.byType(LineChart), findsNothing);
      expect(controller.healthReads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sleep visual hierarchy and disclosures remain usable at 320px and double text',
    (tester) async {
      final start = DateTime.utc(2026, 9, 30, 15);
      final timeline = SleepTimeline(
        deviceId: 'qring:visual-fixture',
        sdkDate: '2026-10-01',
        timezone: '+08:00',
        readAt: DateTime.utc(2026, 10, 1, 6),
        sessions: [
          SleepSession(
            kind: SleepSessionKind.night,
            segments: [
              SleepStageSegment(
                startAt: start,
                endAt: start.add(const Duration(hours: 2)),
                stage: SleepStage.deep,
                rawStage: 2,
              ),
              SleepStageSegment(
                startAt: start.add(const Duration(hours: 2)),
                endAt: start.add(const Duration(hours: 6)),
                stage: SleepStage.light,
                rawStage: 1,
              ),
            ],
          ),
        ],
      );
      final controller = _VisualController()
        ..stored.add(
          _record(
            id: 'sleep',
            at: DateTime.utc(2026, 10, 1),
            metric: HealthMetric.sleep,
            timeline: timeline,
          ),
        );
      await _pump(
        tester,
        Scaffold(
          body: SleepDayDetails(controller: controller, onOpenTrend: (_) {}),
        ),
        scale: 2,
      );
      expect(find.text('最近一次睡眠'), findsOneWidget);
      expect(find.text('6小时0分'), findsWidgets);
      final chart = find.byKey(const Key('sleep-stage-chart')).first;
      await tester.scrollUntilVisible(chart, 200);
      expect(tester.getSize(chart).height, 184);
      expect(tester.takeException(), isNull);
      final disclosure = find.byKey(const Key('sleep-reference-details'));
      await tester.scrollUntilVisible(disclosure, 250, maxScrolls: 60);
      await tester.pumpAndSettle();
      expect(find.textContaining('时间明细仅保存在本机'), findsNothing);
      final title = find.descendant(
        of: disclosure,
        matching: find.text('睡眠说明'),
      );
      await Scrollable.ensureVisible(tester.element(title), alignment: 0.5);
      await tester.pumpAndSettle();
      expect(title.hitTestable(), findsOneWidget);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.textContaining('时间明细仅保存在本机'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('sleep-open-trend')),
        180,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('trend summary, chart and records fit 320px with double text', (
    tester,
  ) async {
    final now = DateTime.now();
    final controller = _VisualController();
    controller.stored.addAll([
      for (var hour = 1; hour <= 8; hour++)
        _record(
          id: 'heart-$hour',
          at: DateTime(now.year, now.month, now.day, hour),
          timezone: '',
          value: 64 + hour,
        ),
    ]);
    await _pump(
      tester,
      HealthTrendPage(controller: controller, metric: HealthMetric.heartRate),
      scale: 2,
    );
    final chart = find.byType(LineChart);
    await tester.scrollUntilVisible(chart, 220, maxScrolls: 30);
    expect(tester.getSize(chart).height, 280);
    expect(tester.takeException(), isNull);
    final allRecords = find.byKey(
      Key('health-all-records-${HealthMetric.heartRate.wireName}'),
    );
    await tester.scrollUntilVisible(allRecords, 250, maxScrolls: 30);
    expect(allRecords, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
