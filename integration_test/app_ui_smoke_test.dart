import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('physical iPhone core pages render and navigate safely', (
    tester,
  ) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    await controller.initialize();
    if (!controller.isAuthenticated) controller.enterPreview();

    await tester.pumpWidget(SaydianApp(controller: controller));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    if (controller.isPreviewMode) {
      await _testReviewDemoPages(tester);
      return;
    }

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.destinations, hasLength(3));
    expect(find.text('健康数据'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-functions')), findsOneWidget);
    expect(find.byKey(const Key('home-sleep-overview-entry')), findsOneWidget);
    expect(find.text('Say Ring 商城'), findsNothing);

    if (controller.hideAiContent) {
      expect(find.byKey(const Key('dashboard-ai-assistant')), findsNothing);
    } else {
      expect(find.byKey(const Key('dashboard-ai-assistant')), findsOneWidget);
    }

    final heartRate = find.byKey(const ValueKey('health-metric-heartRate'));
    if (controller.shouldShowHealthMetric(HealthMetric.heartRate)) {
      await tester.scrollUntilVisible(
        heartRate,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(heartRate);
      await tester.pumpAndSettle();
      expect(find.text('心率分析'), findsOneWidget);
      if (!controller.canMeasureHealthMetric(HealthMetric.heartRate)) {
        expect(find.text('连接支持该指标的戒指后测量'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('health-measure-heart_rate')),
          findsNothing,
        );
      }
      await tester.tap(find.text('周'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();
      await _popRoute(tester);
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(
      find.byKey(const Key('home-sleep-overview-entry')),
    );
    await tester.tap(find.byKey(const Key('home-sleep-overview-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
    await _popRoute(tester);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('全部数据'));
    await tester.tap(find.text('全部数据'));
    await tester.pumpAndSettle();
    expect(find.text('全部健康数据'), findsOneWidget);
    await _popRoute(tester);
    await tester.pumpAndSettle();

    controller.selectTab(1);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-page')), findsOneWidget);
    expect(
      find.byKey(const Key('device-empty-card')).evaluate().isNotEmpty ||
          find.byKey(const Key('device-overview-card')).evaluate().isNotEmpty,
      isTrue,
      reason: '设备页应展示空设备状态或现有绑定设备',
    );

    controller.selectTab(2);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-page')), findsOneWidget);
    await tester.ensureVisible(find.text('关于我们'));
    await tester.tap(find.text('关于我们'));
    await tester.pumpAndSettle();
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
  });
}

Future<void> _popRoute(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}

Future<void> _testReviewDemoPages(WidgetTester tester) async {
  expect(find.byKey(const Key('review-demo-page')), findsOneWidget);
  expect(find.byKey(const Key('review-demo-disclaimer')), findsOneWidget);
  expect(find.byKey(const Key('review-demo-health')), findsOneWidget);

  await tester.tap(find.byKey(const Key('review-demo-sleep')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('sleep-timeline-card')), findsOneWidget);
  expect(find.text('夜间睡眠'), findsOneWidget);
  expect(find.textContaining('全部为示例数据'), findsOneWidget);
  await _popRoute(tester);
  await tester.pumpAndSettle();

  for (final metric in const [
    ('heart', '72 bpm'),
    ('oxygen', '98%'),
    ('steps', '8,250 步'),
  ]) {
    await tester.tap(find.byKey(Key('review-demo-metric-${metric.$1}')));
    await tester.pumpAndSettle();
    expect(find.text(metric.$2), findsOneWidget);
    expect(find.textContaining('演示数值'), findsOneWidget);
    await _popRoute(tester);
    await tester.pumpAndSettle();
  }

  await tester.tap(find.text('设备').last);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('review-demo-device')), findsOneWidget);
  expect(find.textContaining('不申请蓝牙权限'), findsOneWidget);
  await tester.tap(find.byKey(const Key('review-demo-device-guide')));
  await tester.pumpAndSettle();
  expect(find.textContaining('不代表已完成任何真实连接'), findsOneWidget);
  await _popRoute(tester);
  await tester.pumpAndSettle();

  await tester.tap(find.text('我的').last);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('review-demo-profile')), findsOneWidget);
  expect(find.text('演示用户'), findsOneWidget);
  await tester.tap(find.byKey(const Key('review-demo-profile-guide')));
  await tester.pumpAndSettle();
  expect(find.textContaining('演示模式没有可注销的账号'), findsOneWidget);
  await _popRoute(tester);
  await tester.pumpAndSettle();
}
