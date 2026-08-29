import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/app.dart';

void main() {
  testWidgets('background tap dismisses the active system keyboard focus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DismissKeyboardOnBackgroundTap(
          child: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const Key('keyboard-test-field'),
                  focusNode: focusNode,
                ),
                const Expanded(
                  child: ColoredBox(
                    key: Key('keyboard-test-background'),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('keyboard-test-field')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    final background = find.byKey(const Key('keyboard-test-background'));
    await tester.tapAt(tester.getTopLeft(background) + const Offset(20, 20));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('button tap keeps its action and dismisses the keyboard', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var presses = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DismissKeyboardOnBackgroundTap(
          child: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const Key('button-test-field'),
                  focusNode: focusNode,
                ),
                FilledButton(
                  key: const Key('button-test-action'),
                  onPressed: () => presses += 1,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('button-test-field')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('button-test-action')));
    await tester.pump();
    expect(presses, 1);
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('tapping another input transfers focus without dismissing it', (
    tester,
  ) async {
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DismissKeyboardOnBackgroundTap(
          child: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const Key('first-transfer-field'),
                  focusNode: firstFocus,
                ),
                TextField(
                  key: const Key('second-transfer-field'),
                  focusNode: secondFocus,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('first-transfer-field')));
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('second-transfer-field')));
    await tester.pump();
    expect(firstFocus.hasFocus, isFalse);
    expect(secondFocus.hasFocus, isTrue);
  });

  testWidgets('tapping the focused input keeps its focus', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DismissKeyboardOnBackgroundTap(
          child: Scaffold(
            body: TextField(
              key: const Key('same-field-test'),
              focusNode: focusNode,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('same-field-test')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('same-field-test')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('scrolling content does not dismiss the keyboard', (
    tester,
  ) async {
    final focusNode = FocusNode();
    final scrollController = ScrollController();
    addTearDown(focusNode.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DismissKeyboardOnBackgroundTap(
          child: Scaffold(
            body: ListView(
              key: const Key('keyboard-test-list'),
              controller: scrollController,
              children: [
                TextField(
                  key: const Key('scroll-test-field'),
                  focusNode: focusNode,
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('scroll-test-field')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.drag(
      find.byKey(const Key('keyboard-test-list')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(scrollController.offset, greaterThan(0));
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('wrapper adds no full-screen semantic tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: DismissKeyboardOnBackgroundTap(
          child: Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    final node = tester.getSemantics(
      find.byKey(const Key('global-keyboard-dismiss')),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });
}
