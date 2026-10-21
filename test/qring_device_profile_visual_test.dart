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
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';

// Synthetic packets exercise presentation and navigation only. They are not
// physical ring battery, connection or SDK acceptance evidence.
const _ringId = 'qring:00000000-0000-0000-0000-000000000001';

class _Api extends Fake implements SaydianApi {}

class _Wearable extends Fake implements WearableBridge {}

AppController _controller({DeviceBatteryInfo? battery}) =>
    AppController(
        MemorySessionVault(),
        _Api(),
        MemoryHealthStore(),
        _Wearable(),
        commerceEnabled: true,
      )
      ..memberProfile = {'nickname': '阅读布局验证', 'memberNo': '29'}
      ..connectedDevice = DeviceInfo(id: _ringId, name: 'R12', battery: battery)
      ..deviceCapabilityState = DeviceCapabilityState.ready
      ..capabilities = const DeviceCapabilities(
        metrics: {HealthMetric.steps, HealthMetric.sleep},
        features: {
          DeviceFeature.gestureControl,
          DeviceFeature.healthMonitoring,
          DeviceFeature.camera,
        },
        integratedFeatures: {
          DeviceFeature.gestureControl,
          DeviceFeature.healthMonitoring,
        },
      );

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  double width = 390,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
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
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: page),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, String pageKey, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    220,
    scrollable: find
        .descendant(
          of: find.byKey(Key(pageKey)),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('battery graphic preserves original level units', (tester) async {
    final controller = _controller(
      battery: const DeviceBatteryInfo(
        value: 3,
        scale: 4,
        isPercent: false,
        chargeState: DeviceBatteryChargeState.unknown,
      ),
    );
    addTearDown(controller.dispose);
    await _pump(tester, DevicePage(controller: controller));
    expect(find.text('3/4 格'), findsOneWidget);
    expect(find.text('75%'), findsNothing);
    final fill = tester.widget<FractionallySizedBox>(
      find.byKey(const Key('device-battery-fill')),
    );
    expect(fill.widthFactor, 0.75);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown battery remains unknown without a filled graphic', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await _pump(tester, DevicePage(controller: controller));
    final label = tester.widget<Text>(
      find.byKey(const Key('device-battery-value')),
    );
    expect(label.data, '--');
    expect(find.byKey(const Key('device-battery-fill')), findsNothing);
    expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('device controls remain reachable at $width and 200% text', (
      tester,
    ) async {
      final controller = _controller(battery: DeviceBatteryInfo.percentage(78));
      addTearDown(controller.dispose);
      await _pump(
        tester,
        DevicePage(controller: controller),
        width: width,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);

      final details = find.byKey(const Key('device-connection-details'));
      await _reveal(tester, 'device-page', details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(
        find.text(controller.connectedDevice!.identifierLabel),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      final unbind = find.byKey(const Key('device-unbind'));
      await _reveal(tester, 'device-page', unbind);
      await tester.tap(unbind);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('device-confirm-unbind')), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.connectedDevice?.id, _ringId);

      final feature = find.byKey(const Key('device-feature-gesture_control'));
      await _reveal(tester, 'device-page', feature);
      expect(tester.getSize(feature).width, greaterThan(width - 40));
      expect(tester.getSize(feature).height, greaterThanOrEqualTo(48));
      expect(find.byKey(const Key('device-feature-camera')), findsNothing);
      final monitoring = find.byKey(
        const Key('device-feature-health_monitoring'),
      );
      await _reveal(tester, 'device-page', monitoring);
      expect(tester.getSize(monitoring).width, greaterThan(width - 40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('profile navigation stays usable at $width and 200% text', (
      tester,
    ) async {
      final controller = _controller();
      try {
        await _pump(
          tester,
          SettingsPage(controller: controller),
          width: width,
          textScale: 2,
        );
        expect(find.text('阅读布局验证'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final device = find.byKey(const Key('profile-stat-device'));
        await _reveal(tester, 'my-page', device);
        await tester.tap(device);
        await tester.pump();
        expect(controller.selectedTab, 1);

        final records = find.byKey(const Key('profile-stat-health-records'));
        await _reveal(tester, 'my-page', records);
        await tester.tap(records);
        await tester.pumpAndSettle();
        expect(find.byType(AllHealthDataPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        await _reveal(
          tester,
          'my-page',
          find.byKey(const Key('profile-orders-card')),
        );
        await _reveal(
          tester,
          'my-page',
          find.byKey(const Key('profile-services-card')),
        );
        expect(find.text('帮助反馈'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        // selectTab(1) starts the real controller's device-details polling.
        // Dispose before the widget-test timer invariant, not in addTearDown.
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    });
  }
}
