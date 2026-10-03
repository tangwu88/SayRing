import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_report_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/sleep_ai_report_page.dart';

// Synthetic content only; these tests never contact a third-party provider.
final record = HealthRecord(
  id: 'synthetic',
  metric: HealthMetric.sleep,
  values: const {'value': 7},
  unit: 'h',
  measuredAt: DateTime.utc(2026, 8, 4),
  timezone: '+08:00',
  deviceId: 'qring:synthetic',
  firmwareVersion: '',
  quality: 'fixture',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);
Session _session(String id) => Session(
  accessToken: 'synthetic',
  refreshToken: 'synthetic',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  displayName: 'Test',
  accountKey: id,
);
HealthReportSummary _report(String status, {int? score}) =>
    HealthReportSummary.fromMap({
      'id': 'synthetic',
      'reportType': 'sleep',
      'status': status,
      'aiGenerated': status == 'ready',
      'sleepScore': score,
    });

class _Controller extends Fake implements AppController {
  final listeners = <VoidCallback>[];
  Session? owner = _session('synthetic-a');
  bool enabled = true;
  HealthReportSummary? report;
  Completer<HealthReportSummary?>? pending;
  bool fail = false;
  bool staleDocument = false;
  String? unavailableReason;
  int uploads = 0, grants = 0, withdrawals = 0, retries = 0;
  @override
  Session? get session => owner;
  @override
  bool get isGlobalEdition => true;
  @override
  bool get sleepAiEnabled => enabled && owner != null;
  @override
  DeviceInfo? get connectedDevice => null;
  @override
  DeviceInfo? get rememberedDevice =>
      const DeviceInfo(id: 'qring:synthetic', name: 'Fixture');
  @override
  void addListener(VoidCallback value) => listeners.add(value);
  @override
  void removeListener(VoidCallback value) => listeners.remove(value);
  void changed() {
    for (final listener in List<VoidCallback>.of(listeners)) {
      listener();
    }
  }

  @override
  Future<HealthReportSummary?> loadSleepReport(HealthRecord record) async {
    if (fail) throw StateError('fixture read failure');
    return pending?.future ?? report;
  }

  @override
  Future<Map<String, Object?>> loadFullSleepReport(String id) async => {
    'content': {
      'overview': '本次合成睡眠分析',
      'trends': [
        {'metric': 'sleep', 'text': '本次合成阶段分析'},
      ],
      'suggestions': ['合成建议'],
      'limitations': ['仅单日测试数据'],
      'sleepScore': {'explanation': '合成评分依据'},
    },
  };
  @override
  Future<Map<String, Object?>> loadSleepReportAvailability() async => {
    'available': unavailableReason == null,
    'reason': unavailableReason,
    'analysisConsent': {
      'granted': false,
      'availableVersion': 'fixture-v1',
      'document': {
        'version': 'fixture-v1',
        'path': 'synthetic-analysis',
        'locale': 'zh-Hans',
      },
    },
  };
  @override
  Future<Map<String, Object?>> globalLegalDocument(String path) async => {
    'version': staleDocument ? 'old' : 'fixture-v1',
    'locale': 'zh-Hans',
    'contentHtml': '<p>合成授权说明。第三方处理睡眠汇总。</p>',
  };
  @override
  Future<void> grantSleepAnalysisConsent(String version) async {
    expect(version, 'fixture-v1');
    grants++;
  }

  @override
  Future<void> withdrawSleepAnalysisConsent() async {
    withdrawals++;
  }

  @override
  Future<HealthReportSummary> createSleepReport(HealthRecord record) async {
    uploads++;
    return report = _report('ready', score: 78);
  }

  @override
  Future<HealthReportSummary> retrySleepReport(String id) async {
    retries++;
    return report = _report('ready');
  }

  @override
  String healthReportErrorMessage(Object error) => '报告读取失败（合成测试）';
}

Future<void> _pump(
  WidgetTester tester,
  _Controller controller, {
  double width = 430,
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSaydianTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: SleepAiReportPage(controller: controller, record: record),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('precise unavailable reason blocks both consent and upload', (
    tester,
  ) async {
    final c = _Controller()
      ..unavailableReason = 'Say Ring 睡眠 AI 分析说明尚未发布，请稍后重试';
    await _pump(tester, c);
    await tester.tap(find.byKey(const Key('sleep-ai-generate')));
    await tester.pumpAndSettle();
    expect(find.text(c.unavailableReason!), findsOneWidget);
    expect(c.grants, 0);
    expect(c.uploads, 0);
    expect(find.byKey(const Key('sleep-ai-upload-consent')), findsNothing);
  });
  testWidgets(
    'reading never automatically uploads; cancel and unchecked consent block upload',
    (tester) async {
      final c = _Controller();
      await _pump(tester, c);
      expect(c.uploads, 0);
      await tester.tap(find.byKey(const Key('sleep-ai-generate')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('sleep-ai-confirm-upload')),
            )
            .onPressed,
        isNull,
      );
      expect(c.grants, 0);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(c.uploads, 0);
    },
  );

  testWidgets(
    'explicit reviewed consent generates an AI report, not a device score',
    (tester) async {
      final c = _Controller();
      await _pump(tester, c);
      await tester.tap(find.byKey(const Key('sleep-ai-generate')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('sleep-ai-upload-consent')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sleep-ai-confirm-upload')));
      await tester.pumpAndSettle();
      expect(c.grants, 1);
      expect(c.uploads, 1);
      expect(find.text('78 / 100'), findsOneWidget);
      expect(find.text('本次合成睡眠分析'), findsOneWidget);
      expect(find.textContaining('非设备评分'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'outdated analysis notice blocks upload and reports exact cause',
    (tester) async {
      final c = _Controller()..staleDocument = true;
      await _pump(tester, c);
      await tester.tap(find.byKey(const Key('sleep-ai-generate')));
      await tester.pumpAndSettle();
      expect(find.text('分析说明已更新，请重新打开页面'), findsOneWidget);
      expect(c.grants, 0);
      expect(c.uploads, 0);
    },
  );

  testWidgets('no cached score on read failure and retry remains explicit', (
    tester,
  ) async {
    final c = _Controller()..fail = true;
    await _pump(tester, c);
    expect(find.text('报告读取失败（合成测试）'), findsOneWidget);
    expect(find.textContaining('/ 100'), findsNothing);
    expect(c.uploads, 0);
  });

  testWidgets(
    'unknown AI score remains unknown with detailed report at narrow large text',
    (tester) async {
      final c = _Controller()..report = _report('ready');
      await _pump(tester, c, width: 320, scale: 2);
      expect(find.text('证据不足，未评分'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('合成建议'), 200);
      expect(find.text('合成建议'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final disable in [false, true]) {
    testWidgets(
      'late report discarded after ${disable ? 'feature disable' : 'account switch'}',
      (tester) async {
        final pending = Completer<HealthReportSummary?>();
        final c = _Controller()..pending = pending;
        await tester.pumpWidget(
          MaterialApp(
            home: SleepAiReportPage(controller: c, record: record),
          ),
        );
        await tester.pump();
        if (disable) {
          c.enabled = false;
        } else {
          c.owner = _session('synthetic-b');
        }
        c.changed();
        await tester.pump();
        pending.complete(_report('ready', score: 78));
        await tester.pumpAndSettle();
        expect(find.text('78 / 100'), findsNothing);
        expect(find.text('本次合成睡眠分析'), findsNothing);
        expect(c.uploads, 0);
      },
    );
  }

  testWidgets(
    'withdrawal is explicit and works while other AI pages stay hidden',
    (tester) async {
      final c = _Controller();
      await _pump(tester, c);
      await tester.tap(find.byKey(const Key('sleep-ai-withdraw-consent')));
      await tester.pumpAndSettle();
      expect(c.withdrawals, 0);
      await tester.tap(find.text('确认撤回'));
      await tester.pumpAndSettle();
      expect(c.withdrawals, 1);
      expect(find.text('已撤回睡眠 AI 分析授权'), findsOneWidget);
    },
  );
}
