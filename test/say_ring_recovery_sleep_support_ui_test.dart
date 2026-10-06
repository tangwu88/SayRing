import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/say_ring_support.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/health_trend_page.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/sleep_detail_widgets.dart';

// These fabricated packets validate rendering only, not physical ring accuracy.
SleepTimeline _timeline() => SleepTimeline(
  deviceId: 'qring:00000000-0000-0000-0000-000000000001',
  sdkDate: '2026-10-01',
  timezone: '+08:00',
  readAt: DateTime.utc(2026, 10, 1, 6),
  sessions: [
    SleepSession(
      kind: SleepSessionKind.night,
      segments: [
        _segment(DateTime.utc(2026, 9, 30, 15), 10, SleepStage.awake),
        _segment(DateTime.utc(2026, 9, 30, 15, 10), 60, SleepStage.light),
        _segment(DateTime.utc(2026, 9, 30, 16, 10), 60, SleepStage.deep),
        // The following hour is intentionally absent: no invented stage.
        _segment(DateTime.utc(2026, 9, 30, 18, 10), 60, SleepStage.rem),
        _segment(DateTime.utc(2026, 9, 30, 19, 10), 10, SleepStage.unknown),
        _segment(DateTime.utc(2026, 9, 30, 19, 20), 10, SleepStage.notWorn),
        _segment(DateTime.utc(2026, 9, 30, 19, 30), 210, SleepStage.light),
      ],
    ),
    SleepSession(
      kind: SleepSessionKind.nap,
      segments: [_segment(DateTime.utc(2026, 10, 1, 4), 20, SleepStage.light)],
    ),
  ],
);

SleepStageSegment _segment(DateTime start, int minutes, SleepStage stage) =>
    SleepStageSegment(
      startAt: start,
      endAt: start.add(Duration(minutes: minutes)),
      stage: stage,
      rawStage: stage.index,
    );

HealthRecord _record({
  SleepTimeline? timeline,
  DateTime? at,
  double hours = 7.5,
}) => HealthRecord(
  id: 'sleep-ui-${at?.toIso8601String() ?? 'latest'}',
  metric: HealthMetric.sleep,
  values:
      timeline?.summaryValues ??
      {'value': hours, 'deepHours': 2, 'remHours': 1},
  unit: 'h',
  measuredAt: at ?? DateTime.utc(2026, 10, 1),
  timezone: '+08:00',
  deviceId: 'qring:00000000-0000-0000-0000-000000000001',
  firmwareVersion: 'test-only',
  quality: 'test_only',
  source: MeasurementSource.wearable,
  rawVersion: 1,
  sleepTimeline: timeline,
);

Session _session(String account, {String? memberId}) => Session(
  accessToken: 'test-only',
  refreshToken: 'test-only',
  expiresAt: DateTime.utc(2099),
  memberId: memberId ?? account,
  displayName: 'Test',
  accountKey: account,
);

class _UiController extends Fake implements AppController {
  @override
  bool get isWellnessOnly => false;
  @override
  bool isMetricAvailableInRelease(HealthMetric metric) => true;
  final listeners = <VoidCallback>[];
  List<HealthRecord> stored = [];
  Session? currentSession;
  bool globalEdition = true;
  DeviceInfo? boundRing = const DeviceInfo(
    id: 'qring:00000000-0000-0000-0000-000000000001',
    name: 'R21',
  );
  DeviceInfo? activeRing;
  final sleepRanges = <({DateTime start, DateTime end})>[];
  Completer<List<HealthRecord>>? pendingLoad;
  Future<Map<String, Object?>> support = Future.value({'configured': false});
  int latestReads = 0;
  int reconnects = 0;
  @override
  bool isDeviceReconnecting = false;
  int unbinds = 0;
  bool syncSucceeds = true;
  DeviceCapabilities? deviceCapabilities;

  @override
  DeviceCapabilities? get capabilities => deviceCapabilities;

  @override
  String syncStatus = '暂无新增数据';

  @override
  String? errorMessage;

  @override
  Map<String, String> sleepReadStatuses = {};

  @override
  Session? get session => currentSession;

  @override
  bool get isGlobalEdition => globalEdition;
  @override
  bool get sleepAiEnabled => false;

  @override
  void addListener(VoidCallback listener) => listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);

  void changed() {
    for (final listener in List<VoidCallback>.of(listeners)) {
      listener();
    }
  }

  @override
  Future<HealthRecord?> loadLatestSleepDay() async {
    latestReads++;
    if (stored.isEmpty) return null;
    return (List<HealthRecord>.of(
      stored,
    )..sort((a, b) => b.measuredAt.compareTo(a.measuredAt))).first;
  }

  @override
  Future<List<HealthRecord>> loadSleepDays({
    required DateTime start,
    required DateTime end,
  }) async {
    sleepRanges.add((start: start, end: end));
    final pending = pendingLoad;
    if (pending != null) return pending.future;
    return stored.where((record) {
      final day = DateTime.parse(
        record.sleepTimeline?.sdkDate ??
            record.measuredAt.toIso8601String().substring(0, 10),
      );
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList();
  }

  @override
  Future<Map<String, Object?>> loadGlobalSupportConfig() => support;

  @override
  DeviceInfo? get connectedDevice => activeRing;

  @override
  DeviceConnectionState get deviceState => DeviceConnectionState.ready;

  @override
  DeviceCapabilityState get deviceCapabilityState =>
      DeviceCapabilityState.ready;

  @override
  DeviceInfo? get rememberedDevice => boundRing;

  @override
  bool get isWearableRecovering => true;

  @override
  String? get wearableRecoveryMessage => '等待戒指靠近';

  @override
  Set<DeviceFeature> get visibleDeviceFeatures => const {};

  @override
  bool get isDeviceSyncing => false;

  @override
  double get deviceSyncProgress => 0;

  @override
  Future<void> reconnectDevice() async => reconnects++;

  @override
  Future<bool> syncDeviceData() async => syncSucceeds;

  @override
  Future<void> unbindDevice() async => unbinds++;
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  double scale = 1,
  double width = 390,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSaydianTheme(),
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() => initializeDateFormatting('zh_Hans'));

  testWidgets(
    'bound disconnected device retains recovery card and unbind confirmation',
    (tester) async {
      final controller = _UiController();
      await _pump(
        tester,
        Scaffold(body: DevicePage(controller: controller)),
        scale: 2,
        width: 320,
      );
      expect(find.byKey(const Key('device-overview-card')), findsOneWidget);
      expect(find.byKey(const Key('device-empty-card')), findsNothing);
      expect(find.text('等待戒指靠近'), findsOneWidget);
      expect(find.text('断开连接'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('device-reconnect')));
      await tester.tap(find.byKey(const Key('device-reconnect')));
      expect(controller.reconnects, 1);
      await tester.ensureVisible(find.byKey(const Key('device-unbind')));
      await tester.tap(find.byKey(const Key('device-unbind')));
      await tester.pumpAndSettle();
      expect(controller.unbinds, 0);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.unbinds, 0);
      await tester.tap(find.byKey(const Key('device-unbind')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('device-confirm-unbind')));
      await tester.pumpAndSettle();
      expect(controller.unbinds, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('successful connection hides reconnect until it disconnects', (
    tester,
  ) async {
    final controller = _UiController();
    controller.activeRing = controller.boundRing;
    await _pump(
      tester,
      Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (_, _) => DevicePage(controller: controller),
        ),
      ),
    );
    expect(find.byKey(const Key('device-overview-card')), findsOneWidget);
    expect(find.byKey(const Key('device-reconnect')), findsNothing);
    expect(find.byKey(const Key('device-unbind')), findsOneWidget);

    controller.activeRing = null;
    controller.changed();
    await tester.pump();
    expect(find.byKey(const Key('device-reconnect')), findsOneWidget);
    controller.isDeviceReconnecting = true;
    controller.changed();
    await tester.pump();
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('device-reconnect')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('正在重连'), findsOneWidget);
    controller.isDeviceReconnecting = false;
    controller.changed();
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('device-reconnect')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('an empty successful sync says up to date, not failed', (
    tester,
  ) async {
    final controller = _UiController();
    controller.activeRing = controller.boundRing;
    await _pump(tester, Scaffold(body: DevicePage(controller: controller)));
    await tester.ensureVisible(find.text('同步数据'));
    await tester.tap(find.text('同步数据'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('已是最新，暂无新数据'), findsOneWidget);
    expect(find.textContaining('数据同步失败'), findsNothing);
  });

  testWidgets(
    'enterprise service stays available while backend config loads and fails',
    (tester) async {
      final config = Completer<Map<String, Object?>>();
      final controller = _UiController()..support = config.future;
      await _pump(
        tester,
        CustomerServicePage(isGlobalEdition: true, controller: controller),
      );
      expect(
        find.byKey(const Key('say-ring-open-wechat-service')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      config.completeError(StateError('test-only outage'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('say-ring-open-wechat-service')),
        findsOneWidget,
      );
      expect(find.text('电话及公众号信息加载失败，仍可使用上方微信客服'), findsOneWidget);
      expect(find.text('4006386738'), findsNothing);
    },
  );

  testWidgets(
    'enterprise service tries external then system browser and both failures can copy the exact link',
    (tester) async {
      final launches = <MethodCall>[];
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          launches.add(call);
          return false;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      await _pump(
        tester,
        const CustomerServicePage(isGlobalEdition: true),
        scale: 2,
        width: 320,
      );
      await tester.tap(find.byKey(const Key('say-ring-open-wechat-service')));
      await tester.pumpAndSettle();
      expect(launches.length, 2);
      expect(launches.every((call) => call.method == 'launch'), isTrue);
      final arguments = launches.first.arguments as Map;
      expect(arguments['url'], SayRingSupport.customerServiceUri.toString());
      expect(arguments['useWebView'], isFalse);
      expect(arguments['useSafariVC'], isFalse);
      final fallback = launches.last.arguments as Map;
      expect(fallback['url'], SayRingSupport.customerServiceUri.toString());
      expect(fallback['useWebView'], isTrue);
      expect(fallback['useSafariVC'], isTrue);
      expect(find.text('无法打开微信客服，请复制链接后在微信或浏览器中打开'), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, '复制链接'));
      await tester.pumpAndSettle();
      expect(copied, 'https://work.weixin.qq.com/kfid/kfcae32196355fde04c');
      expect(find.text('无法打开微信客服，请复制链接后在微信或浏览器中打开'), findsNothing);
      expect(find.text('客服链接已复制，可在微信或浏览器中打开'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'enterprise service does not open a second browser after external success',
    (tester) async {
      final launches = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          launches.add(call);
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      await _pump(tester, const CustomerServicePage(isGlobalEdition: true));
      await tester.tap(find.byKey(const Key('say-ring-open-wechat-service')));
      await tester.pumpAndSettle();
      expect(launches, hasLength(1));
      expect((launches.single.arguments as Map)['useSafariVC'], isFalse);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  for (final throws in [false, true]) {
    testWidgets(
      'enterprise service system browser handles external ${throws ? 'exception' : 'failure'}',
      (tester) async {
        final launches = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            launches.add(call);
            if (launches.length == 1) {
              if (throws) {
                throw PlatformException(code: 'test_only_unavailable');
              }
              return false;
            }
            return true;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            null,
          ),
        );
        await _pump(tester, const CustomerServicePage(isGlobalEdition: true));
        await tester.tap(find.byKey(const Key('say-ring-open-wechat-service')));
        await tester.pumpAndSettle();
        expect(launches, hasLength(2));
        expect((launches.last.arguments as Map)['useSafariVC'], isTrue);
        expect(
          (launches.last.arguments as Map)['url'],
          SayRingSupport.customerServiceUri.toString(),
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'leaving service page during external launch prevents browser fallback',
    (tester) async {
      final external = Completer<bool>();
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          calls++;
          return external.future;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      await _pump(tester, const CustomerServicePage(isGlobalEdition: true));
      await tester.tap(find.byKey(const Key('say-ring-open-wechat-service')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      external.complete(false);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'configured phone and public account remain usable at 320px with large text',
    (tester) async {
      final controller = _UiController()
        ..support = Future.value({
          'configured': true,
          'phone': '4001234567',
          'officialAccount': '赛电国际客服',
          'serviceHours': '工作日 09:00-18:00',
        });
      await _pump(
        tester,
        CustomerServicePage(isGlobalEdition: true, controller: controller),
        scale: 2,
        width: 320,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('say-ring-open-wechat-service')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('4001234567'), 250);
      expect(find.text('联系电话'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('添加客服'), 250);
      expect(find.text('赛电国际客服'), findsOneWidget);
      expect(find.text('4006386738'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unmapped sleep has an explicit empty state and retains saved summary',
    (tester) async {
      final controller = _UiController()
        ..deviceCapabilities = const DeviceCapabilities(
          metrics: {HealthMetric.heartRate},
          supportsHistorySync: false,
        );
      await _pump(
        tester,
        SleepOverviewPage(controller: controller),
        width: 320,
        scale: 2,
      );
      await tester.pumpAndSettle();
      expect(find.text('该日期暂无本机睡眠记录，当前戒指的睡眠同步暂未开放'), findsOneWidget);
      expect(find.textContaining('睡眠后请同步'), findsNothing);
      controller.stored = [_record()];
      controller.changed();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('7小时30分'), findsNWidgets(2));
      await tester.scrollUntilVisible(find.textContaining('此记录只有睡眠汇总'), 250);
      expect(find.text('此记录只有睡眠汇总，无法反推具体时间段。当前戒指的睡眠同步暂未开放。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unmapped sleep cache failures remain failures without unusable sync advice',
    (tester) async {
      final controller = _UiController()
        ..deviceCapabilities = const DeviceCapabilities(
          metrics: {},
          supportsHistorySync: false,
        )
        ..sleepReadStatuses = {'2026-10-01': 'failed'};
      await _pump(
        tester,
        Scaffold(
          body: SleepDayDetails(
            controller: controller,
            initialDate: DateTime(2026, 10, 1),
            onOpenTrend: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('本机睡眠缓存读取失败，请稍后重试'), findsOneWidget);
      expect(find.text('没有可显示的本机睡眠记录'), findsOneWidget);
      expect(find.textContaining('重新连接戒指并同步'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sleep detail displays SDK day, cross-midnight times and independent nap',
    (tester) async {
      final controller = _UiController()
        ..stored = [_record(timeline: _timeline())];
      await _pump(tester, SleepOverviewPage(controller: controller));
      await tester.pumpAndSettle();
      expect(controller.latestReads, 1);
      expect(find.text('2026年10月1日'), findsOneWidget);
      expect(find.text('6小时50分'), findsOneWidget);
      expect(find.text('夜间睡眠'), findsOneWidget);
      expect(find.text('开始 9月30日 23:00'), findsOneWidget);
      expect(find.text('结束 10月1日 07:00'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('小睡 1'), 250);
      expect(find.text('小睡 1'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('未知（戒指未返回）'), 250);
      expect(find.text('未知（戒指未返回）'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('时间明细仅保存在本机'), 250);
      expect(find.textContaining('时间明细仅保存在本机'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'sleep timeline start and end labels align with chart edges at scale $scale',
      (tester) async {
        await _pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: SleepTimelineCard(timeline: _timeline()),
            ),
          ),
          scale: scale,
          width: 320,
        );
        await tester.pumpAndSettle();
        final chart = tester.getRect(
          find.byKey(const Key('sleep-stage-chart')).first,
        );
        final start = tester.getRect(
          find.byKey(const Key('sleep-axis-start')).first,
        );
        final end = tester.getRect(
          find.byKey(const Key('sleep-axis-end')).first,
        );
        expect((start.left - chart.left).abs(), lessThan(2));
        expect((end.right - chart.right).abs(), lessThan(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'real interval tap shows exact preserved-offset times at narrow width and scale $scale',
      (tester) async {
        await _pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: SleepTimelineCard(timeline: _timeline()),
            ),
          ),
          scale: scale,
          width: 320,
        );
        await tester.pumpAndSettle();
        final chart = find.byKey(const Key('sleep-stage-chart')).first;
        await tester.ensureVisible(chart);
        final rect = tester.getRect(chart);
        await tester.tapAt(
          Offset(rect.left + rect.width * 5 / 480, rect.top + 10),
        );
        await tester.pumpAndSettle();
        expect(find.text('开始：9月30日 23:00'), findsOneWidget);
        expect(find.text('结束：9月30日 23:10'), findsOneWidget);
        expect(find.text('持续：10分钟'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'old summary cannot invent a timeline, date changes show genuine no-data',
    (tester) async {
      final controller = _UiController()
        ..stored = [_record()]
        ..sleepReadStatuses = {'2026-09-30': 'noData'};
      await _pump(
        tester,
        SleepOverviewPage(controller: controller),
        scale: 2,
        width: 320,
      );
      await tester.pumpAndSettle();
      expect(find.text('7小时30分'), findsOneWidget);
      expect(find.byKey(const Key('sleep-stage-chart')), findsNothing);
      await tester.scrollUntilVisible(find.textContaining('此记录只有睡眠汇总'), 200);
      expect(find.textContaining('无法反推具体时间段'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('sleep-previous-day')));
      await tester.tap(find.byKey(const Key('sleep-previous-day')));
      await tester.pumpAndSettle();
      expect(find.text('2026年9月30日'), findsOneWidget);
      expect(find.text('戒指本次未返回该日睡眠数据'), findsOneWidget);
      expect(find.text('0小时0分'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed refresh retains cache and never reports it as a fresh read',
    (tester) async {
      final controller = _UiController()
        ..stored = [_record(timeline: _timeline())]
        ..sleepReadStatuses = {'2026-10-01': 'failed'};
      await _pump(tester, SleepOverviewPage(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('睡眠缓存刷新失败，仍显示本机已保存的数据'), findsOneWidget);
      expect(find.text('6小时50分'), findsOneWidget);
    },
  );

  testWidgets(
    'unknown and not-worn intervals remain visible without inventing zero sleep',
    (tester) async {
      final timeline = SleepTimeline(
        deviceId: 'qring:00000000-0000-0000-0000-000000000001',
        sdkDate: '2026-10-01',
        timezone: '+08:00',
        readAt: DateTime.utc(2026, 10, 1, 6),
        sessions: [
          SleepSession(
            kind: SleepSessionKind.night,
            segments: [
              _segment(DateTime.utc(2026, 9, 30, 15), 10, SleepStage.unknown),
              _segment(
                DateTime.utc(2026, 9, 30, 15, 10),
                10,
                SleepStage.notWorn,
              ),
            ],
          ),
        ],
      );
      final controller = _UiController()
        ..stored = [_record(timeline: timeline)];
      await _pump(tester, SleepOverviewPage(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('有效睡眠 --'), findsOneWidget);
      expect(find.text('0分钟'), findsNothing);
      expect(find.text('0秒'), findsNothing);
      expect(find.byKey(const Key('sleep-stage-chart')), findsOneWidget);
      expect(find.text('未知'), findsOneWidget);
      expect(find.text('未佩戴'), findsOneWidget);
    },
  );

  testWidgets(
    'account switch discards a delayed sleep payload from the old account',
    (tester) async {
      final pending = Completer<List<HealthRecord>>();
      final controller = _UiController()
        ..currentSession = _session('account-a')
        ..stored = [_record(timeline: _timeline())]
        ..pendingLoad = pending;
      await _pump(tester, SleepOverviewPage(controller: controller));
      controller
        ..currentSession = _session('account-b')
        ..stored = []
        ..pendingLoad = null;
      controller.changed();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      pending.complete([_record(timeline: _timeline())]);
      await tester.pumpAndSettle();
      expect(find.text('6小时50分'), findsNothing);
      expect(find.byKey(const Key('sleep-stage-chart')), findsNothing);
    },
  );

  testWidgets(
    'blank member account switch immediately clears sleep and selects new latest day',
    (tester) async {
      final controller = _UiController()
        ..currentSession = _session('account-a', memberId: '')
        ..stored = [_record(timeline: _timeline())];
      await _pump(tester, SleepOverviewPage(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('6小时50分'), findsOneWidget);
      final pending = Completer<List<HealthRecord>>();
      controller.pendingLoad = pending;
      controller.changed();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      controller
        ..currentSession = _session('account-b', memberId: '')
        ..stored = [_record(at: DateTime.utc(2026, 9, 15), hours: 3)]
        ..pendingLoad = null;
      controller.changed();
      await tester.pump();
      // The old account must disappear before the refresh debounce expires.
      expect(find.text('6小时50分'), findsNothing);
      expect(find.byKey(const Key('sleep-stage-chart')), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('2026年9月15日'), findsOneWidget);
      expect(find.text('3小时0分'), findsNWidgets(2));
      pending.complete([_record(timeline: _timeline())]);
      await tester.pumpAndSettle();
      expect(find.text('2026年9月15日'), findsOneWidget);
      expect(find.text('6小时50分'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blank member account switch clears trend and ignores old in-flight query',
    (tester) async {
      final controller = _UiController()
        ..currentSession = _session('account-a', memberId: '')
        ..stored = [_record(hours: 7.5)];
      await _pump(
        tester,
        HealthTrendPage(
          controller: controller,
          metric: HealthMetric.sleep,
          initialDate: DateTime(2026, 10, 1),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('sleep-structure-card'));
      expect(
        find.descendant(of: card, matching: find.text('7小时30分')),
        findsOneWidget,
      );
      final pending = Completer<List<HealthRecord>>();
      controller.pendingLoad = pending;
      controller.changed();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      controller
        ..currentSession = _session('account-b', memberId: '')
        ..stored = []
        ..pendingLoad = null;
      controller.changed();
      await tester.pump();
      expect(find.text('7小时30分'), findsNothing);
      await tester.pumpAndSettle();
      pending.complete([_record(hours: 7.5)]);
      await tester.pumpAndSettle();
      expect(find.text('7小时30分'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sleep month reads full September rather than a shifted 31-day period',
    (tester) async {
      final controller = _UiController();
      await _pump(
        tester,
        HealthTrendPage(
          controller: controller,
          metric: HealthMetric.sleep,
          initialDate: DateTime(2026, 10, 1),
        ),
      );
      await tester.pumpAndSettle();
      controller.sleepRanges.clear();
      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();
      expect(controller.sleepRanges, [
        (start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 31)),
        (start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)),
      ]);
    },
  );

  for (final trend in [false, true]) {
    testWidgets(
      '${trend ? 'sleep trend' : 'sleep detail'} ring switch immediately clears cache and discards old exact-target query',
      (tester) async {
        final controller = _UiController()
          ..currentSession = _session('same-account')
          ..stored = [_record(hours: 7.5)];
        await _pump(
          tester,
          trend
              ? HealthTrendPage(
                  controller: controller,
                  metric: HealthMetric.sleep,
                  initialDate: DateTime(2026, 10, 1),
                )
              : SleepOverviewPage(controller: controller),
        );
        await tester.pumpAndSettle();
        const oldValue = '7小时30分';
        expect(find.text(oldValue), findsNWidgets(trend ? 1 : 2));
        final pending = Completer<List<HealthRecord>>();
        controller.pendingLoad = pending;
        controller.changed();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        controller
          ..boundRing = const DeviceInfo(
            id: 'qring:00000000-0000-0000-0000-000000000002',
            name: 'R21',
          )
          ..stored = []
          ..pendingLoad = null;
        controller.changed();
        await tester.pump();
        expect(find.text(oldValue), findsNothing);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        pending.complete([_record(hours: 7.5)]);
        await tester.pumpAndSettle();
        expect(find.text(oldValue), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'sleep week structure card chooses the newest day rather than the oldest',
    (tester) async {
      final controller = _UiController()
        ..stored = [
          _record(hours: 7.5),
          _record(at: DateTime.utc(2026, 9, 29), hours: 3),
        ];
      await _pump(
        tester,
        HealthTrendPage(
          controller: controller,
          metric: HealthMetric.sleep,
          initialDate: DateTime(2026, 10, 1),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('周'));
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('sleep-structure-card'));
      expect(
        find.descendant(of: card, matching: find.text('7小时30分')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('3小时0分')),
        findsNothing,
      );
    },
  );
}
