import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/health_record_units.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/health_analysis.dart';
import 'package:saydian_app/ui/health_trend_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'read existing calorie provenance without rewriting history',
    (tester) async {
      final app = AppController.production();
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      final owner = app.session?.accountKey;
      final target = app.rememberedDevice?.id;
      final groups = <String, int>{};
      for (final metric in [
        HealthMetric.calories,
        HealthMetric.steps,
        HealthMetric.sleep,
      ]) {
        final records = await app.loadHealthRecords(
          metric: metric,
          start: DateTime.utc(2000),
          end: DateTime.utc(DateTime.now().year + 1),
        );
        for (final record in records) {
          // Only bounded protocol metadata and counts; no IDs, health values,
          // timestamps, names, account identifiers, credentials or payloads.
          final vendor =
              const {
                'coolwear',
                'qring',
                'veepoo',
                'yucheng',
                'moyoung',
              }.contains(record.sourceVendor)
              ? record.sourceVendor
              : 'other';
          final unit =
              const {'kcal', 'unknown', '', 'steps', 'h'}.contains(record.unit)
              ? record.unit
              : 'other';
          final key =
              '${metric.name}/$vendor/${record.source.name}/v${record.rawVersion}/$unit'
              '/vendorEmpty=${record.sourceVendor.isEmpty}'
              '/qringDevice=${record.deviceId.startsWith('qring:')}'
              '/qringId=${record.id.startsWith('qring:')}'
              '/activityV3Id=${record.id.contains('|calories|v3|')}'
              '/ringApp=${record.sourceApp == 'say-ring'}'
              '/ringCategory=${record.sourceDeviceCategory == 'ring'}'
              '/pending=${hasUnconfirmedCalorieUnit(record)}';
          groups.update(key, (count) => count + 1, ifAbsent: () => 1);
        }
      }
      final result = {
        'groups': groups,
        'hasSession': owner != null,
        'hasRememberedTarget': target != null,
        'connectedToRememberedTarget':
            target != null && app.connectedDevice?.id == target,
        'ownerUnchanged': app.session?.accountKey == owner,
        'targetUnchanged': app.rememberedDevice?.id == target,
      };
      binding.reportData = {
        ...?binding.reportData,
        'calorieProvenance': result,
      };
      expect(result['ownerUnchanged'], isTrue);
      expect(result['targetUnchanged'], isTrue);

      final calories = await app.loadHealthRecords(
        metric: HealthMetric.calories,
        start: DateTime.utc(2000),
        end: DateTime.utc(DateTime.now().year + 1),
      );
      final legacy = calories
          .where(
            (record) =>
                record.rawVersion == 3 &&
                RegExp(r'^qring:[^|]+\|calories\|v3\|').hasMatch(record.id),
          )
          .toList();
      expect(legacy, isNotEmpty, reason: 'Actual saved samples required');
      expect(legacy.every(hasUnconfirmedCalorieUnit), isTrue);
      final before = [for (final record in calories) record.toJson()];
      for (final period in HealthTrendPeriod.values) {
        final data = const HealthAnalysisService().analyze(
          metric: HealthMetric.calories,
          records: legacy,
          previousRecords: legacy,
          period: period,
          anchor: HealthAnalysisService.displayTime(legacy.first),
        );
        expect(data.points, isEmpty);
        expect(data.summary.average, isNull);
        expect(data.summary.previousAverage, isNull);
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => HealthTrendPage(
            controller: app,
            metric: HealthMetric.calories,
            initialDate: HealthAnalysisService.displayTime(legacy.first),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byKey(const Key('calorie-unit-unconfirmed')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('1140-real-legacy-calorie-trend-private');
      navigator.pop();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final after = await app.loadHealthRecords(
        metric: HealthMetric.calories,
        start: DateTime.utc(2000),
        end: DateTime.utc(DateTime.now().year + 1),
      );
      expect([for (final record in after) record.toJson()], before);
      binding.reportData = {
        ...?binding.reportData,
        'realLegacyCalorieGuard': true,
        'savedCaloriePayloadsUnchanged': true,
      };

      app.selectTab(0);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final latestSleep = await app.loadLatestSleepDay();
      final sleep = find.byKey(const Key('home-sleep-overview-entry'));
      await tester.ensureVisible(sleep);
      await tester.tap(sleep);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
      expect(find.text('最近一次睡眠'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sleep-previous-day')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('按日期查看'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sleep-latest-day')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('最近一次睡眠'), findsOneWidget);
      expect(tester.takeException(), isNull);
      binding.reportData = {
        ...?binding.reportData,
        'sleepDateNavigation': true,
        'hasCurrentTargetSleepSample': latestSleep != null,
      };
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
