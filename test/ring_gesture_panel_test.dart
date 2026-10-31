import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/user_message.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/widgets/ring_gesture_panel.dart';

void main() {
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
        expect(find.byKey(const ValueKey('gesture-mode-1')), findsNothing);
        final reading = find.byKey(const ValueKey('gesture-mode-3'));
        await tester.ensureVisible(reading);
        await tester.tap(reading);
        await tester.pumpAndSettle();
        expect(selected, [3]);
        await pump(busy: true);
        await tester.ensureVisible(reading);
        await tester.tap(reading);
        expect(selected, [3]);
        await pump(reconnect: true);
        await tester.ensureVisible(reading);
        await tester.tap(reading);
        expect(selected, [3]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
