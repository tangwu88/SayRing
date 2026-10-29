import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/ui/widgets/device_wait_status.dart';

Widget _page(
  Widget child, {
  double scale = 1,
  bool reducedMotion = false,
  bool ticker = true,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reducedMotion,
    ),
    child: TickerMode(
      enabled: ticker,
      child: Scaffold(
        body: ListView(padding: const EdgeInsets.all(32), children: [child]),
      ),
    ),
  ),
);

void main() {
  testWidgets('unknown progress animates without a made-up percentage', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const DeviceWaitStatus(connected: true)));
    final turns = tester
        .widget<RotationTransition>(find.byKey(const Key('device-wait-orbit')))
        .turns;
    final before = turns.value;
    await tester.pump(const Duration(milliseconds: 600));
    expect(turns.value, isNot(before));
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('可先浏览其他页面'), findsOneWidget);
    expect(find.textContaining('完成'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('real progress and record reception coexist without completion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(
        const DeviceWaitStatus(
          connected: true,
          progress: 0.4,
          receivedRecords: 23,
        ),
      ),
    );
    expect(find.text('已接收 23 条记录'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('device-confirmed-sync-progress')),
          )
          .value,
      0.4,
    );
    expect(find.textContaining('完成'), findsNothing);
  });

  testWidgets('disconnected operation never claims data or connected state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(
        const DeviceWaitStatus(
          connected: false,
          receivedRecords: 23,
          progress: 0.4,
        ),
      ),
    );
    expect(find.text('正在重新连接'), findsOneWidget);
    expect(find.textContaining('已接收'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('已连接'), findsNothing);
  });

  testWidgets('reduced motion and hidden ticker stop, then resume animation', (
    tester,
  ) async {
    Animation<double> turns() => tester
        .widget<RotationTransition>(find.byKey(const Key('device-wait-orbit')))
        .turns;
    for (final flags in [(true, true), (false, false)]) {
      await tester.pumpWidget(
        _page(
          const DeviceWaitStatus(connected: true),
          reducedMotion: flags.$1,
          ticker: flags.$2,
        ),
      );
      final value = turns().value;
      await tester.pump(const Duration(milliseconds: 600));
      expect(turns().value, value);
      expect(tester.hasRunningAnimations, isFalse);
    }
    await tester.pumpWidget(_page(const DeviceWaitStatus(connected: true)));
    final before = turns().value;
    await tester.pump(const Duration(milliseconds: 600));
    expect(turns().value, isNot(before));
  });

  for (final connected in [true, false]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('332dp scale $scale connected=$connected fits', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(332, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _page(
            DeviceWaitStatus(
              connected: connected,
              progress: 0.99,
              receivedRecords: 123456,
            ),
            scale: scale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
