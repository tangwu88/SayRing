import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/ui/widgets/ring_gesture_guide.dart';

void main() {
  for (final viewport in const [(320.0, 2.0), (390.0, 1.0)]) {
    testWidgets('gesture guide is readable at $viewport', (tester) async {
      tester.view.physicalSize = Size(viewport.$1, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(viewport.$2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: RingGestureGuide(),
            ),
          ),
        ),
      );
      expect(find.text('使用前'), findsNothing);
      await tester.tap(find.text('使用说明'));
      await tester.pumpAndSettle();
      expect(find.text('使用前'), findsOneWidget);
      expect(find.text('操作方法'), findsOneWidget);
      final lastStep = find.textContaining('仍无反应时关闭模式再重选');
      await tester.ensureVisible(lastStep);
      await tester.pumpAndSettle();
      expect(lastStep.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      // This is instructional content, not switches or a permission prompt.
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });
  }

  test('mode hints separate system gestures from camera and reminders', () {
    expect(RingGestureGuide.modeHint(0), contains('关闭'));
    expect(RingGestureGuide.modeHint(4), contains('摇一摇拍照'));
    expect(RingGestureGuide.modeHint(5), contains('不等于开启来电提醒'));
    for (var mode = 0; mode <= 5; mode++) {
      expect(RingGestureGuide.modeHint(mode), isNotEmpty);
    }
    expect(RingGestureGuide.modeHint(6), isEmpty);
  });
}
