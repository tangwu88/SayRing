import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/pages.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS read-only walkthrough of reachable product pages', (
    tester,
  ) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    await controller.initialize();
    final hasAppShell = controller.isAuthenticated || controller.isLocalMode;
    if (!hasAppShell) controller.enterPreview();
    final visited = <String>[];

    await tester.pumpWidget(SaydianApp(controller: controller));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    if (controller.isPreviewMode) {
      expect(find.byKey(const Key('review-demo-page')), findsOneWidget);
      await tester.tap(find.byKey(const Key('review-demo-sleep')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sleep-timeline-card')), findsOneWidget);
      expect(find.text('夜间睡眠'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      for (final key in const ['heart', 'oxygen', 'steps']) {
        await tester.tap(find.byKey(Key('review-demo-metric-$key')));
        await tester.pumpAndSettle();
        expect(find.textContaining('演示数值'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('设备').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review-demo-device')), findsOneWidget);
      await tester.tap(find.byKey(const Key('review-demo-device-guide')));
      await tester.pumpAndSettle();
      expect(find.textContaining('不代表已完成任何真实连接'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review-demo-profile')), findsOneWidget);
      expect(find.text('演示用户'), findsOneWidget);

      await tester.tap(find.byKey(const Key('review-demo-exit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-code-login-page')), findsOneWidget);
      expect(find.byKey(const Key('code-login-contact')), findsOneWidget);
      expect(find.byKey(const Key('code-login-submit')), findsOneWidget);
      expect(find.byKey(const Key('local-ring-use-entry')), findsOneWidget);
      expect(find.byKey(const Key('review-demo-entry')), findsNothing);
      expect(find.text('Say Ring 商城'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('local-ring-use-entry')));
      await tester.tap(find.byKey(const Key('local-ring-use-entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('code-login-error')), findsOneWidget);
      expect(find.byKey(const Key('global-code-login-page')), findsOneWidget);

      final emailChip = find.text('邮箱').last;
      await tester.ensureVisible(emailChip);
      await tester.tap(emailChip);
      await tester.pumpAndSettle();
      final emailField = tester.widget<TextField>(
        find.byKey(const Key('code-login-contact')),
      );
      expect(emailField.keyboardType, TextInputType.emailAddress);
      if (find.byKey(const Key('email-login-mode')).evaluate().isNotEmpty) {
        expect(find.byKey(const Key('email-login-password')), findsOneWidget);
        await tester.tap(find.byKey(const Key('email-login-mode')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('code-login-code')), findsOneWidget);
        await tester.tap(find.byKey(const Key('email-login-mode')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('email-login-password')), findsOneWidget);
      }
      visited.addAll(const ['只读睡眠/指标/设备/我的', '登录首页与单一本机入口']);
      expect(tester.takeException(), isNull);
      // Labels only; never print account, profile, or health values into the log.
      // ignore: avoid_print
      print('iOS read-only walkthrough pages: ${visited.join('、')}');
      return;
    }

    Future<void> open(String name, Finder tapTarget, Finder pageMarker) async {
      if (tapTarget.evaluate().isEmpty) return;
      await tester.ensureVisible(tapTarget.last);
      await tester.tap(tapTarget.last);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(pageMarker, findsOneWidget, reason: '$name 页面未打开');
      expect(tester.takeException(), isNull, reason: '$name 页面发生异常');
      visited.add(name);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    expect(find.byKey(const Key('dashboard-functions')), findsOneWidget);
    expect(find.text('Say Ring 商城'), findsNothing);
    visited.add('健康首页');

    for (final metric in HealthPage.coreMetrics) {
      if (!controller.shouldShowHealthMetric(metric)) continue;
      final card = find.byKey(ValueKey('health-metric-${metric.name}'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(
        find.textContaining(metric.label),
        findsWidgets,
        reason: '${metric.label}详情没有显示标题/指标',
      );
      expect(tester.takeException(), isNull, reason: '${metric.label}详情发生异常');
      visited.add('${metric.label}详情');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    await open(
      '睡眠概览',
      find.byKey(const Key('home-sleep-overview-entry')),
      find.byKey(const Key('sleep-overview-page')),
    );
    await open('全部健康数据', find.text('全部数据'), find.text('全部健康数据'));
    await open('远程关爱', find.text('远程关爱'), find.text('守护家人健康'));
    await open(
      '健康百科',
      find.text('健康百科'),
      find.byKey(const Key('article-category-page')),
    );
    await open(
      '运动总览',
      find.text('运动'),
      find.byKey(const Key('sport-overview-page')),
    );

    controller.selectTab(1);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('device-page')), findsOneWidget);
    expect(
      find.byKey(const Key('device-empty-card')).evaluate().isNotEmpty ||
          find.byKey(const Key('device-overview-card')).evaluate().isNotEmpty,
      isTrue,
      reason: '设备页既没有空状态，也没有已绑定设备状态',
    );
    visited.add('设备');

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('消息'), findsOneWidget);
    expect(tester.takeException(), isNull);
    visited.add('消息通知');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    controller.selectTab(2);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('my-page')), findsOneWidget);
    visited.add('我的');

    if (!controller.isLocalMode) {
      await tester.tap(find.byKey(const Key('profile-header-card')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byKey(const Key('profile-nickname')), findsOneWidget);
      expect(find.byKey(const Key('profile-save')), findsOneWidget);
      expect(tester.takeException(), isNull);
      visited.add('个人资料（只读）');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    final myPageScroll = find
        .descendant(
          of: find.byKey(const Key('my-page')),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> openMyEntry(String label, Finder marker) async {
      final entry = find.text(label);
      if (entry.evaluate().isEmpty) return;
      await tester.scrollUntilVisible(
        entry.last,
        280,
        scrollable: myPageScroll,
      );
      await tester.tap(entry.last);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(marker, findsOneWidget, reason: '$label 页面未打开');
      expect(tester.takeException(), isNull, reason: '$label 页面发生异常');
      visited.add(label);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    if (controller.isLocalMode) {
      await openMyEntry('账号设置', find.byKey(const Key('local-mode-sign-in')));
    }
    await openMyEntry('单位设置', find.text('单位设置'));
    if (!controller.isLocalMode) {
      await openMyEntry('健康档案', find.text('健康档案'));
      await openMyEntry('账号设置', find.text('个人资料'));
    }
    await openMyEntry('权限管理', find.text('权限管理'));
    await openMyEntry('帮助反馈', find.text('帮助反馈'));
    await openMyEntry('联系客服', find.text('联系客服'));
    await openMyEntry('关于 Say Ring', find.text('关于 Say Ring'));

    expect(tester.takeException(), isNull);
    // Labels only; never print account, profile, or health values into the log.
    // ignore: avoid_print
    print('iOS read-only walkthrough pages: ${visited.join('、')}');
  });
}
