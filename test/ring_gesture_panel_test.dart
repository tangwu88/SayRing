import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/user_message.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/widgets/ring_gesture_panel.dart';

void main() {
  for (final tapControl in [true, false]) {
    for (final viewport in const [(320.0, 2.0), (390.0, 1.0)]) {
      testWidgets(
        'iPhone setup is readable and read only; tap=$tapControl at $viewport',
        (tester) async {
          final originalPlatform = debugDefaultTargetPlatformOverride;
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          try {
            await tester.binding.setSurfaceSize(Size(viewport.$1, 844));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            var writes = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: buildSaydianTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(viewport.$2)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: RingGesturePanel(
                      availableModes: const {0, 1},
                      confirmedMode: 1,
                      ready: true,
                      busy: false,
                      requiresReconnect: false,
                      readbackConfirmed: tapControl,
                      tapControl: tapControl,
                      onRefresh: () => writes++,
                      onSelect: (_) => writes++,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final setup = find.byKey(const ValueKey('gesture-ios-setup'));
            await tester.ensureVisible(setup);
            expect(find.text('设置 → 无障碍 → 触控 → 辅助触控'), findsOneWidget);
            expect(
              find.textContaining('辅助触控 · 需开启', findRichText: true),
              findsOneWidget,
            );
            expect(
              find.textContaining('执行触控手势 · 需开启', findRichText: true),
              findsOneWidget,
            );
            expect(
              find.textContaining('跟踪灵敏度 · 调至最高', findRichText: true),
              findsOneWidget,
            );
            final action = find.text('双击戒指');
            expect(find.text('晃动手指'), findsOneWidget);
            await tester.ensureVisible(action);
            expect(action.hitTestable(), findsOneWidget);
            expect(find.textContaining('双击即可'), findsNothing);
            expect(find.byType(Switch), findsNothing);
            expect(find.byType(Checkbox), findsNothing);
            expect(writes, 0);
            expect(tester.takeException(), isNull);
          } finally {
            debugDefaultTargetPlatformOverride = originalPlatform;
          }
        },
      );
    }
  }

  testWidgets('iPhone setup cannot imply an unavailable or unconfirmed mode', (
    tester,
  ) async {
    final originalPlatform = debugDefaultTargetPlatformOverride;
    try {
      for (final state in [
        (TargetPlatform.android, true, true, false, false, true, 1, {0, 1}),
        (TargetPlatform.iOS, true, false, false, false, false, 1, {0, 1}),
        (TargetPlatform.iOS, true, true, true, false, true, 1, {0, 1}),
        (TargetPlatform.iOS, true, true, false, true, true, 1, {0, 1}),
        (TargetPlatform.iOS, true, true, false, false, true, 2, {0, 1, 2}),
        (TargetPlatform.iOS, true, true, false, false, true, 1, {0}),
      ]) {
        debugDefaultTargetPlatformOverride = state.$1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RingGesturePanel(
                  availableModes: state.$8,
                  confirmedMode: state.$7,
                  ready: state.$3,
                  busy: state.$4,
                  requiresReconnect: state.$5,
                  readbackConfirmed: state.$6,
                  tapControl: state.$2,
                  onRefresh: () {},
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('gesture-ios-setup')), findsNothing);
        expect(find.text('三步开始'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    } finally {
      debugDefaultTargetPlatformOverride = originalPlatform;
    }
  });

  testWidgets(
    'merged guide never suggests a confirmed scene while control is uncertain',
    (tester) async {
      var closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RingGesturePanel(
                availableModes: const {0, 1},
                confirmedMode: 1,
                ready: true,
                busy: false,
                requiresReconnect: false,
                readbackConfirmed: true,
                uncertainControl: true,
                onStop: () => closes++,
                onRefresh: () {},
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('控制状态待确认'), findsOneWidget);
      expect(find.byKey(const ValueKey('gesture-next-step')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('gesture-stop-control')));
      expect(closes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'close remains reachable with unknown scenes and cannot imply confirmed disabled state',
    (tester) async {
      var closes = 0;
      Future<void> pump(bool busy) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RingGesturePanel(
                availableModes: const {},
                confirmedMode: 0,
                ready: false,
                busy: busy,
                requiresReconnect: true,
                readbackConfirmed: false,
                uncertainControl: true,
                onStop: () => closes++,
                onRefresh: () {},
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await pump(false);
      await tester.pumpAndSettle();
      expect(find.text('控制状态待确认'), findsOneWidget);
      expect(find.textContaining('之前开启的控制可能仍在生效'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gesture-stop-control')));
      expect(closes, 1);
      await pump(true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('gesture-stop-control')));
      expect(closes, 1);
    },
  );
  testWidgets(
    'unconfigured sensitivity requires explicit choice before any scene write',
    (tester) async {
      int? strength;
      final writes = <(int, int?)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => RingGesturePanel(
                  availableModes: const {0, 1},
                  confirmedMode: 0,
                  ready: true,
                  busy: false,
                  requiresReconnect: false,
                  readbackConfirmed: true,
                  needsStrength: true,
                  selectedStrength: strength,
                  onStrengthChanged: (value) =>
                      setState(() => strength = value),
                  onRefresh: () {},
                  onSelect: (mode) => writes.add((mode, strength)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scene = find.byKey(const ValueKey('gesture-mode-1'));
      await tester.ensureVisible(scene);
      await tester.tap(scene);
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(strength, isNull);
      final selector = find.byKey(const ValueKey('gesture-strength'));
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('5').last);
      await tester.pumpAndSettle();
      expect(strength, 5);
      expect(writes, isEmpty);
      await tester.ensureVisible(scene);
      await tester.tap(scene);
      await tester.pumpAndSettle();
      expect(writes, [(1, 5)]);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'presentation hides supplier names without altering device identity',
    () {
      for (final name in [
        'QRing',
        'qring-R12',
        'LUCKRING-HR05',
        'LuckRing R7 Ultra',
      ]) {
        final device = DeviceInfo(id: 'qring:raw-id', name: name, model: name);
        expect(
          device.displayName,
          isNot(matches(RegExp('qring|luckring', caseSensitive: false))),
        );
        expect(
          device.displayModel,
          isNot(matches(RegExp('qring|luckring', caseSensitive: false))),
        );
        expect(device.toJson()['name'], name);
        expect(device.id, 'qring:raw-id');
      }
      expect(
        userFacingMessage('请打开 QRing 或 LuckRing', fallback: '请检查戒指连接'),
        '请检查戒指连接',
      );
    },
  );

  for (final spec in [(320.0, 2.0), (390.0, 1.0)]) {
    testWidgets(
      'gesture scene cards preserve support and write guards at $spec',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(spec.$1, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final selected = <int>[];
        var reconnects = 0;
        Future<void> pump({bool busy = false, bool reconnect = false}) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildSaydianTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(spec.$2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: RingGesturePanel(
                    availableModes: const {0, 2, 3},
                    confirmedMode: 2,
                    ready: true,
                    busy: busy,
                    requiresReconnect: reconnect,
                    readbackConfirmed: true,
                    onRefresh: () {},
                    onReconnect: () => reconnects++,
                    onSelect: selected.add,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pump();
        expect(find.text('三步开始'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('gesture-phone-compatibility')),
          findsOneWidget,
        );
        expect(find.textContaining('部分手机型号可能不支持'), findsOneWidget);
        expect(find.byKey(const ValueKey('gesture-next-step')), findsOneWidget);
        expect(find.textContaining('打开音乐播放器，再按戒指说明操作'), findsOneWidget);
        expect(find.byKey(const ValueKey('gesture-mode-1')), findsNothing);
        final reading = find.byKey(const ValueKey('gesture-mode-3'));
        await tester.ensureVisible(reading);
        await tester.tap(reading);
        await tester.pumpAndSettle();
        expect(selected, [3]);
        // A tap requests the guarded write, but does not claim it succeeded.
        expect(find.textContaining('打开音乐播放器，再按戒指说明操作'), findsOneWidget);
        expect(find.textContaining('打开支持翻页的阅读 App，再按戒指说明操作'), findsNothing);
        await pump(busy: true);
        expect(find.byKey(const ValueKey('gesture-next-step')), findsNothing);
        await tester.ensureVisible(reading);
        await tester.tap(reading);
        expect(selected, [3]);
        await pump(reconnect: true);
        expect(find.byKey(const ValueKey('gesture-next-step')), findsNothing);
        await tester.ensureVisible(reading);
        await tester.tap(reading);
        expect(selected, [3]);
        final reconnect = find.byKey(const ValueKey('gesture-refresh'));
        await tester.ensureVisible(reconnect);
        await tester.pumpAndSettle();
        expect(find.text('恢复控制'), findsOneWidget);
        await tester.tap(reconnect);
        expect(reconnects, 1);
        expect(selected, [3]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
