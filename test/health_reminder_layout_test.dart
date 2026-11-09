import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/reading_reminder.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/health_reminder_notifications.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/health_reminder_center.dart';
import 'package:saydian_app/ui/reading_reminder_widgets.dart';

class _Api extends Fake implements SaydianApi {}

class _Bridge extends Fake implements WearableBridge {}

// 全部为本机合成数据，不连接服务端或戒指。验证排版不能暗中保存设置。
class LayoutController extends AppController {
  LayoutController()
    : super(MemorySessionVault(), _Api(), MemoryHealthStore(), _Bridge()) {
    connectedDevice = const DeviceInfo(
      id: 'synthetic-layout-ring',
      name: 'Synthetic',
      firmwareVersion: 'test',
    );
    capabilities = DeviceCapabilities(
      metrics: metrics,
      manualMetrics: metrics,
      features: const {},
      supportsHistorySync: false,
    );
    healthReminderNotificationPermission =
        ReminderNotificationPermission.granted;
    readingReminderSettings = const ReadingReminderSettings(
      highEnabled: true,
      phoneSoundEnabled: false,
      ringVibrationEnabled: false,
    );
  }

  Set<HealthMetric> metrics = {
    HealthMetric.heartRate,
    HealthMetric.bloodOxygen,
    HealthMetric.hrv,
    HealthMetric.bodyTemperature,
  };
  bool vibrating = true;
  bool dailyAvailable = false;
  int saves = 0;
  int reads = 0;
  int permissionRequests = 0;

  @override
  bool get canSaveHealthReminder => true;
  @override
  bool get healthReminderRingVibrationAvailable => vibrating;
  @override
  bool canMeasureHealthMetric(HealthMetric metric) => metrics.contains(metric);
  @override
  Future<void> refreshHealthReminderPermissions({bool request = false}) async {
    if (request) permissionRequests++;
  }

  @override
  FeatureAvailability availabilityFor(DeviceFeature feature) =>
      FeatureAvailability(
        dailyAvailable && feature == DeviceFeature.healthReminders
            ? FeatureAvailabilityStatus.ready
            : FeatureAvailabilityStatus.unsupportedDevice,
      );
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    reads++;
    return const {};
  }

  @override
  Future<bool> saveReadingReminderSettings(
    ReadingReminderSettings value, {
    required String expectedOwner,
  }) async {
    if (expectedOwner != homeHealthCardOwner || !value.valid) return false;
    saves++;
    readingReminderSettings = value;
    notifyListeners();
    return true;
  }
}

Widget layoutHost(
  LayoutController controller, {
  double scale = 1,
  Locale locale = const Locale('zh'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: buildSaydianTheme().copyWith(platform: TargetPlatform.iOS),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  // 使用有返回入口的真实导航宽度，避免根页面掩盖iOS标题栏挤占。
  initialRoute: '/reminders',
  routes: {
    '/reminders': (_) => HealthReminderCenterPage(controller: controller),
  },
  home: const Scaffold(),
);

void main() {
  testWidgets(
    'reference explanation retains guidance without outbound reference links',
    (tester) async {
      final controller = LayoutController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReadingReminderSettingsPanel(
                controller: controller,
                onHelp: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final explanation = find.text('参考值说明');
      await tester.scrollUntilVisible(
        explanation,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(explanation);
      await tester.tap(explanation);
      await tester.pumpAndSettle();
      for (final title in ['心率参考', '血氧使用说明', '测量局限', 'HRV说明（Oura）']) {
        expect(find.text(title), findsNothing);
      }
      expect(find.textContaining('120/40 bpm'), findsOneWidget);
      expect(controller.saves, 0);
      expect(controller.permissionRequests, 0);
    },
  );
  for (final locale in [const Locale('zh'), const Locale('en')]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'grouped page fits $locale at $scale without saving settings',
        (tester) async {
          tester.view.physicalSize = const Size(375, 812);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = LayoutController();
          addTearDown(controller.dispose);
          final before = controller.readingReminderSettings.toJson();
          await tester.pumpWidget(
            layoutHost(controller, locale: locale, scale: scale),
          );
          await tester.pumpAndSettle();
          final list = find.byKey(const Key('health-reminder-center'));
          final metrics = find.byKey(
            const Key('reading-reminder-measurement-group'),
          );
          expect(metrics, findsOneWidget);
          expect(tester.takeException(), isNull);
          // 滚动覆盖完整页面；布局变化不能使底部操作或顶部求助失联。
          final notification = find.byKey(
            const Key('health-reminder-notification-permission'),
          );
          await tester.scrollUntilVisible(
            notification,
            240,
            scrollable: find
                .descendant(of: list, matching: find.byType(Scrollable))
                .first,
          );
          await tester.pumpAndSettle();
          expect(notification, findsOneWidget);
          expect(
            find.ancestor(
              of: notification,
              matching: find.byKey(
                const Key('reading-reminder-delivery-group'),
              ),
            ),
            findsOneWidget,
          );
          final symptoms = find.byKey(
            const Key('health-reminder-record-symptoms'),
          );
          await tester.scrollUntilVisible(
            symptoms,
            200,
            scrollable: find
                .descendant(of: list, matching: find.byType(Scrollable))
                .first,
          );
          await tester.pumpAndSettle();
          expect(symptoms.hitTestable(), findsOneWidget);
          final preview = find.byKey(const Key('reading-reminder-preview'));
          await tester.ensureVisible(preview);
          await tester.pumpAndSettle();
          expect(preview.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(controller.saves, 0);
          expect(controller.permissionRequests, 0);
          expect(controller.reads, 0);
          expect(controller.readingReminderSettings.toJson(), before);
          final help = find.byKey(const Key('health-reminder-urgent-help'));
          expect(help.hitTestable(), findsOneWidget);
          await tester.tap(help);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('emergency-help-page')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('only returned daily settings appear in their own group', (
    tester,
  ) async {
    final controller = LayoutController()..dailyAvailable = true;
    addTearDown(controller.dispose);
    controller.deviceFeatureData = {
      DeviceFeature.healthReminders: {
        'items': [
          {'id': 'sedentary', 'enabled': true},
          {'id': 'water', 'enabled': false, 'stateKnown': false},
        ],
      },
    };
    await tester.pumpWidget(layoutHost(controller));
    await tester.pumpAndSettle();
    final sedentary = find.byKey(const Key('health-reminder-sedentary'));
    await tester.scrollUntilVisible(sedentary, 200);
    expect(find.text('日常提醒'), findsOneWidget);
    expect(sedentary, findsOneWidget);
    expect(
      find.byKey(const Key('health-reminder-other-ring-settings')),
      findsNothing,
    );
    expect(controller.saves, 0);
    expect(controller.reads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable metrics and daily settings leave no empty section', (
    tester,
  ) async {
    final controller = LayoutController()
      ..metrics = {}
      ..vibrating = false;
    addTearDown(controller.dispose);
    await tester.pumpWidget(layoutHost(controller));
    await tester.pumpAndSettle();
    expect(find.text('指标提醒'), findsNothing);
    expect(find.text('日常提醒'), findsNothing);
    expect(
      find.byKey(const Key('health-reminder-ring-settings')),
      findsNothing,
    );
    expect(find.byKey(const Key('reading-reminder-phone-sound')), findsNothing);
    expect(
      find.byKey(const Key('reading-reminder-ring-vibration')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('health-reminder-notification-permission')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reading-reminder-preview')), findsOneWidget);
    expect(controller.saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('symptom and preview actions keep their existing routes', (
    tester,
  ) async {
    final controller = LayoutController()..metrics = {};
    addTearDown(controller.dispose);
    await tester.pumpWidget(layoutHost(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-reminder-record-symptoms')));
    await tester.pumpAndSettle();
    expect(find.text('记录当前不适'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reading-reminder-preview')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('reading-reminder-preview-label')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('reading-reminder-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-reminder-center')), findsOneWidget);
    expect(controller.saves, 0);
    expect(controller.healthReminderEvents, isEmpty);
  });
}
