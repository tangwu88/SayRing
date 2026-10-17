import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/ui/widgets/ring_screen_scroll_control.dart';

void main() {
  testWidgets('sent setting is adjustable but never presented as confirmed', (
    tester,
  ) async {
    final calls = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RingScreenScrollControl(
              supported: true,
              ready: true,
              busy: false,
              requiresReconnect: false,
              confirmedMode: null,
              sentMode: 1,
              onChanged: calls.add,
              onPractice: () {},
            ),
          ),
        ),
      ),
    );
    final toggle = find.byKey(const ValueKey('gesture-scroll-toggle'));
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(find.textContaining('戒指状态未确认'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await tester.tap(toggle);
    expect(calls, [false]);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('gesture-scroll-practice')),
          )
          .onPressed,
      isNotNull,
    );
  });
  for (final mode in <int?>[null, 0, 1, 2]) {
    testWidgets('practice opens only for confirmed scroll mode $mode', (
      tester,
    ) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RingScreenScrollControl(
                supported: true,
                ready: true,
                busy: false,
                requiresReconnect: false,
                confirmedMode: mode,
                onChanged: (_) {},
                onPractice: () => opens++,
              ),
            ),
          ),
        ),
      );
      final button = find.byKey(const ValueKey('gesture-scroll-practice'));
      final control = tester.widget<OutlinedButton>(button);
      expect(control.onPressed != null, mode == 1);
      if (mode == 1) {
        await tester.tap(button);
      }
      expect(opens, mode == 1 ? 1 : 0);
    });
  }
  testWidgets(
    'practice observes a manually scrolled list, never claims success',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RingScreenScrollPracticePage()),
      );
      final list = find.byKey(const ValueKey('gesture-scroll-practice-list'));
      final state = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      expect(state.position.pixels, 0);
      await tester.drag(list, const Offset(0, -320));
      await tester.pumpAndSettle();
      expect(state.position.pixels, greaterThan(0));
      expect(find.text('滑屏成功'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final mode in <int?>[null, -1, 0, 1, 2]) {
    testWidgets(
      'scroll switch uses confirmed mode $mode without optimistic state',
      (tester) async {
        final calls = <bool>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RingScreenScrollControl(
                  supported: true,
                  ready: true,
                  busy: false,
                  requiresReconnect: false,
                  confirmedMode: mode,
                  onChanged: calls.add,
                ),
              ),
            ),
          ),
        );
        expect(calls, isEmpty);
        final toggle = find.byKey(const ValueKey('gesture-scroll-toggle'));
        expect(
          tester.widget<SwitchListTile>(toggle).value,
          mode != null && mode > 0,
        );
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(calls, [mode == null || mode <= 0]);
        expect(
          tester.widget<SwitchListTile>(toggle).value,
          mode != null && mode > 0,
        );
      },
    );
  }
  for (final gate in ['unsupported', 'unread', 'busy', 'reconnect']) {
    testWidgets('scroll cannot write when $gate', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RingScreenScrollControl(
                supported: gate != 'unsupported',
                ready: gate != 'unread',
                busy: gate == 'busy',
                requiresReconnect: gate == 'reconnect',
                confirmedMode: 1,
                onChanged: calls.add,
              ),
            ),
          ),
        ),
      );
      final toggle = find.byKey(const ValueKey('gesture-scroll-toggle'));
      expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
      if (gate != 'busy') {
        expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      }
      expect(calls, isEmpty);
    });
  }
  testWidgets(
    'scroll instructions remain readable on narrow large-text screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RingScreenScrollControl(
                supported: true,
                ready: true,
                busy: false,
                requiresReconnect: false,
                confirmedMode: null,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.textContaining('如出现系统配对请求'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
