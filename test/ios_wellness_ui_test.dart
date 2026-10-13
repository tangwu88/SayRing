import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/health_trend_page.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/sleep_ai_report_page.dart';
import 'package:saydian_app/ui/wellness_release.dart';

// Synthetic fixtures verify release visibility, never hardware accuracy.
HealthRecord _record(HealthMetric metric) => HealthRecord(
  id: 'synthetic-${metric.wireName}',
  metric: metric,
  values: metric == HealthMetric.sleep
      ? const {
          'value': 7,
          'deepHours': 2,
          'lightHours': 5,
          'score': 91,
          'efficiency': 95,
        }
      : const {'value': 88, 'diseaseRisk': 80, 'chdRisk': 80},
  unit: metric == HealthMetric.sleep ? 'h' : '',
  measuredAt: DateTime.utc(2026, 10, 1),
  timezone: '+08:00',
  deviceId: 'synthetic-ring',
  firmwareVersion: 'test',
  quality: 'test_only',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);

class _Api extends Fake implements SaydianApi {}

class _Wearable extends Fake implements WearableBridge {}

AppController _controller({bool wellness = true}) => AppController(
  MemorySessionVault(),
  _Api(),
  MemoryHealthStore(),
  _Wearable(),
  wellnessOnly: wellness,
);

Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home and all-data hide old physiology while keeping activity', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final ecg = _record(HealthMetric.ecg);
    final steps = _record(HealthMetric.steps);
    controller.healthRecords = [ecg, steps];
    await _pump(tester, Scaffold(body: DashboardPage(controller: controller)));
    expect(find.byKey(const ValueKey('health-metric-steps')), findsOneWidget);
    expect(find.byKey(const ValueKey('health-metric-ecg')), findsNothing);
    expect(find.text('健康百科'), findsNothing);
    await _pump(tester, AllHealthDataPage(controller: controller));
    expect(find.text('心电图'), findsNothing);
    expect(find.textContaining('校准'), findsNothing);
    expect(controller.healthRecords, [ecg, steps]);
  });

  testWidgets(
    'old physiological detail routes remain stored but are unavailable',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      final record = _record(HealthMetric.ecg);
      controller.healthRecords = [record];
      await _pump(
        tester,
        HealthRecordDetailPage(controller: controller, record: record),
      );
      expect(find.byType(WellnessReleaseUnavailablePage), findsOneWidget);
      expect(find.text('风险分析'), findsNothing);
      expect(controller.healthRecords.single, same(record));
    },
  );

  testWidgets('direct blocked trend cannot expose old data', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      HealthTrendPage(
        controller: controller,
        metric: HealthMetric.bloodPressure,
      ),
    );
    expect(find.byType(WellnessReleaseUnavailablePage), findsOneWidget);
    expect(find.byKey(const Key('health-trend-blood_pressure')), findsNothing);
  });

  testWidgets(
    'sleep history preserves duration and hides existing device scores',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      final record = _record(HealthMetric.sleep);
      await _pump(
        tester,
        HealthRecordDetailPage(
          controller: controller,
          record: record,
          readOnly: true,
        ),
      );
      expect(find.text('7小时0分'), findsOneWidget);
      expect(find.text('设备睡眠评分'), findsNothing);
      expect(find.text('睡眠效率'), findsNothing);
      expect(record.values['score'], 91);
    },
  );

  testWidgets('Android-compatible sleep structure still shows device scores', (
    tester,
  ) async {
    final controller = _controller(wellness: false);
    addTearDown(controller.dispose);
    await _pump(
      tester,
      Scaffold(
        body: SleepStructureCard(
          record: _record(HealthMetric.sleep),
          controller: controller,
        ),
      ),
    );
    expect(find.text('设备睡眠评分'), findsOneWidget);
    expect(find.text('91 分'), findsOneWidget);
  });

  testWidgets('sport history hides physiology and retains activity', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    const record = SportRecord(
      id: 'synthetic-workout',
      mode: SportMode.walking,
      startedAt: null,
      durationSeconds: 600,
      distanceKm: 1,
      calories: 40,
      steps: 1000,
      heartRate: 88,
      heartRateSamples: [SportHeartRateSample(elapsedSeconds: 10, bpm: 88)],
    );
    await _pump(
      tester,
      SportRecordDetailPage(controller: controller, record: record),
    );
    expect(find.text('1000 步'), findsOneWidget);
    expect(find.textContaining('bpm'), findsNothing);
    expect(find.text('心率记录'), findsNothing);
    expect(record.heartRate, 88);
  });

  testWidgets(
    'direct monitoring, alert, AI, calibration and content routes are closed',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      final pages = <Widget>[
        DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.healthMonitoring,
        ),
        PermissionManagementPage(controller: controller, healthOnly: true),
        HealthWarningPage(controller: controller),
        SleepAiReportPage(
          controller: controller,
          record: _record(HealthMetric.sleep),
        ),
        HealthCalibrationPage(
          controller: controller,
          metric: HealthMetric.bloodGlucose,
        ),
        ArticleCategoryPage(controller: controller),
        GlobalArticleLibraryPage(controller: controller),
      ];
      for (final page in pages) {
        await _pump(tester, page);
        expect(
          find.byType(WellnessReleaseUnavailablePage),
          findsOneWidget,
          reason: '${page.runtimeType}',
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
