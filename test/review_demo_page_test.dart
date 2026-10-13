import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/ui/review_demo_page.dart';

void main() {
  testWidgets('public review demo is labeled and explores health and sleep', (
    tester,
  ) async {
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(home: ReviewDemoPage(onExit: () => exited = true)),
    );
    expect(find.byKey(const Key('review-demo-disclaimer')), findsOneWidget);
    expect(find.textContaining('虚构示例'), findsOneWidget);
    expect(find.byKey(const Key('review-demo-health')), findsOneWidget);

    await tester.tap(find.byKey(const Key('review-demo-sleep')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sleep-timeline-card')), findsOneWidget);
    expect(find.textContaining('全部为示例数据'), findsOneWidget);
    expect(find.text('夜间睡眠'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('review-demo-metric-heart')));
    await tester.pumpAndSettle();
    expect(find.text('72 bpm'), findsOneWidget);
    expect(find.textContaining('演示数值'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('review-demo-exit')));
    expect(exited, isTrue);
  });

  testWidgets(
    'device and profile describe limitations without claiming a connection',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: ReviewDemoPage(onExit: () {})));
      await tester.tap(find.text('设备').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('演示模式不申请蓝牙权限'), findsOneWidget);
      await tester.tap(find.byKey(const Key('review-demo-device-guide')));
      await tester.pumpAndSettle();
      expect(find.textContaining('不代表已完成任何真实连接'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      expect(find.text('演示用户'), findsOneWidget);
      await tester.tap(find.byKey(const Key('review-demo-profile-guide')));
      await tester.pumpAndSettle();
      expect(find.textContaining('演示模式没有可注销的账号'), findsOneWidget);
    },
  );

  test(
    'sample sleep segments are synthetic, coherent and not a real device',
    () {
      final timeline = reviewDemoSleepTimeline;
      expect(timeline.deviceId, 'demo-only-no-device');
      expect(timeline.sessions.length, 2);
      expect(timeline.sessions.first.asleepMinutes, 470);
      expect(timeline.sessions.first.awakeMinutes, 15);
      expect(timeline.sessions.last.asleepMinutes, 30);
      expect(timeline.rawSummary, isEmpty);
    },
  );
}
