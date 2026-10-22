import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/user_message.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/widgets/ring_gesture_panel.dart';

void main() {
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
