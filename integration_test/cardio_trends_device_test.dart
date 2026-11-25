import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/ring_experience.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';

class _OfflineApi extends Fake implements SaydianApi, GlobalAccountApi {}

class _NoWearable extends Fake implements WearableBridge {}

/// Run on a disposable QA installation. All readings and storage in this
/// fixture are synthetic and in memory. The production route and widgets render them.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'opens paired cardiovascular insights from the bottom of All health data',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = MemoryHealthStore();
      final controller = AppController(
        MemorySessionVault(),
        _OfflineApi(),
        store,
        _NoWearable(),
      );
      controller
        ..connectedDevice = const DeviceInfo(
          id: 'qring:qa-device',
          name: 'QA',
          model: 'Test ring',
        )
        ..deviceCapabilityState = DeviceCapabilityState.ready
        ..capabilities = const DeviceCapabilities(
          metrics: {
            HealthMetric.heartRate,
            HealthMetric.bloodOxygen,
            HealthMetric.bodyTemperature,
            HealthMetric.hrv,
            HealthMetric.stress,
            HealthMetric.sleep,
          },
        );
      addTearDown(controller.dispose);
      final now = DateTime.now(),
          yesterday = DateTime(now.year, now.month, now.day - 1, 12);
      await controller.savePressureReference(
        PressureSample(
          at: yesterday,
          systolic: 123,
          diastolic: 79,
          source: 'reference',
        ),
      );
      await store.upsert([
        HealthRecord(
          id: 'cardio-emulator-fixture',
          metric: HealthMetric.heartRate,
          values: const {'value': 64},
          unit: 'bpm',
          measuredAt: yesterday,
          timezone: '+00:00',
          deviceId: 'qring:qa-device',
          sourceModel: 'QA',
          firmwareVersion: '',
          quality: 'valid',
          source: MeasurementSource.wearable,
          rawVersion: 2,
        ),
      ]);
      controller.healthRecords = await store.recent();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DashboardPage(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('心血管趋势'), findsNothing);
      final catalog = find.text('全部数据');
      await tester.scrollUntilVisible(catalog.hitTestable(), 180);
      await tester.tap(catalog);
      await tester.pumpAndSettle();
      final entry = find.byKey(const Key('all-health-cardiovascular-trends'));
      await tester.scrollUntilVisible(entry.hitTestable(), 180);
      expect(
        tester.getTopLeft(find.text('睡眠')).dy,
        lessThan(tester.getTopLeft(entry).dy),
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('pressure-period-7')))
            .selected,
        isTrue,
      );
      expect(find.text('AI 辅助趋势解读'), findsOneWidget);
      expect(find.textContaining('123/79 mmHg，心率为64 bpm'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pressure-period-30')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('pressure-period-30')),
            )
            .selected,
        isTrue,
      );
      final evidence = find.byKey(const Key('cardio-evidence'));
      await tester.scrollUntilVisible(evidence.hitTestable(), 160);
      await tester.tap(evidence);
      await tester.pumpAndSettle();
      expect(find.text('血压来源 · 上臂血压计'), findsOneWidget);
      expect(find.text('心率 · QA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
