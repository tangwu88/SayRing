import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/cycle_tracking.dart';
import 'package:saydian_app/ui/cycle_day_widgets.dart';
import 'package:saydian_app/ui/cycle_diary_sheet.dart';
import 'cycle_diary_fixture.dart';

/// 与正式账号、戒指和持久化存储隔离的移动端界面验收，手机与桌面使用同一条路径。
Future<void> exerciseCycleDiary(
  WidgetTester t,
  double scale, {
  GlobalKey? boundary,
  Future<void> Function(String name)? capture,
}) async {
  final c = Controller();
  addTearDown(c.dispose);
  final today = c.cycles.today,
      past = shiftCycleDate(today, -2),
      future = shiftCycleDate(today, 1);
  await t.runAsync(() async {
    await c.cycles.load();
    await c.cycles.saveSettings(
      const CycleSettings(
        enabled: true,
        adultConfirmed: true,
        purposeAccepted: true,
        recordOnly: true,
      ),
    );
    await c.cycles.save(
      CycleEntry(
        id: 'sample-period',
        kind: 'period',
        data: {
          'start': shiftCycleDate(past, -1),
          'end': shiftCycleDate(today, -1),
        },
      ),
    );
    c.cycles.nights = [
      for (final offset in [-4, -2])
        CycleNightFeature(
          date: shiftCycleDate(today, offset),
          sourceKey: 'synthetic-skin',
          metric: 'skin_temperature',
          value: offset == -4 ? 32 : 33,
          samples: 18,
          coverageMinutes: 240,
          maxGapMinutes: 20,
          recordIds: const [],
        ),
    ];
  });
  await t.pumpWidget(RepaintBoundary(key: boundary, child: host(c, scale)));
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await t.pumpAndSettle();
  Future<void> shot(String name) async {
    if (capture != null) await capture(name);
    expect(t.takeException(), isNull, reason: name);
  }

  Future<void> tap(Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  final feels = find.byKey(const Key('cycle-feelings'));
  if (scale == 1) expect(feels.hitTestable(), findsOneWidget);
  await shot('overview');
  final weekToday = find.byKey(ValueKey('week-$today'));
  await t.drag(weekToday, const Offset(-210, 0));
  await t.pumpAndSettle();
  expect(
    find.byKey(ValueKey('week-${shiftCycleDate(today, 7)}')),
    findsOneWidget,
  );
  await tap(find.text('今天'));
  expect(t.widget<CycleDateCell>(weekToday).selected, isTrue);

  Future<void> monthPick(String date, {bool photo = false}) async {
    await tap(find.byTooltip('打开月历'));
    if (photo) await shot('month');
    final current = t
        .widget<CycleMonthSheet>(find.byType(CycleMonthSheet))
        .selected;
    final from = parseCycleDate(current), to = parseCycleDate(date);
    final diff = (to.year - from.year) * 12 + to.month - from.month;
    for (var i = 0; i < diff.abs(); i++) {
      await tap(find.byTooltip(diff < 0 ? '上个月' : '下个月'));
    }
    await tap(find.byKey(ValueKey('month-$date')));
  }

  await monthPick(past, photo: true);
  expect(find.byType(CycleDiarySheet), findsNothing);
  expect(find.text('经期第 2 天'), findsOneWidget);
  expect(find.byKey(const Key('cycle-view-period')), findsOneWidget);
  await tap(feels);
  expect(find.text('${cycleShort(past)} · 记感受'), findsOneWidget);
  final save = find.byKey(const Key('diary-save'));
  expect(save.hitTestable(), findsOneWidget);
  await tap(find.byKey(const Key('diary-flow-light')));
  await shot('diary');
  final scroll = find
      .descendant(
        of: find.byType(CycleDiarySheet),
        matching: find.byType(Scrollable),
      )
      .first;
  Future<void> sheetItem(Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(f, 170, scrollable: scroll);
    }
    await tap(f);
  }

  await sheetItem(find.text('更多感受'));
  await sheetItem(find.text('头痛'));
  await sheetItem(find.text('腹胀'));
  await shot('more-feelings');
  expect(save.hitTestable(), findsOneWidget);
  await tap(save);
  final daily = c.cycles.entries.singleWhere((e) => e.kind == 'daily');
  expect(daily.start, past);
  expect(daily.data['symptoms'], ['headache', 'bloating']);
  expect(daily.data.containsKey('fatigue'), false);
  expect(find.text('经量少 · 头痛 · 腹胀'), findsOneWidget);
  await tap(feels);
  await tap(find.byKey(const Key('diary-flow-heavy')));
  await tap(find.byTooltip('取消'));
  expect(
    c.cycles.entries.singleWhere((e) => e.kind == 'daily').data['flow'],
    'light',
  );
  await tap(feels);
  await tap(save);
  expect(c.cycles.entries.where((e) => e.kind == 'daily'), hasLength(1));

  final trend = find.text('夜间皮温');
  if (trend.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      trend,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final summary = find.textContaining('相对个人均值');
  await t.ensureVisible(summary);
  await t.pumpAndSettle();
  await shot('trend');
  expect(summary, findsOneWidget);
  await tap(find.byTooltip('逐晚查看'));
  await tap(find.text('${cycleShort(shiftCycleDate(today, -4))} · -0.50 ℃'));
  expect(find.text('-0.50 ℃'), findsOneWidget);
  expect(find.text('睡眠心率'), findsNothing);
  await monthPick(future);
  expect(find.byType(CycleDiarySheet), findsNothing);
  expect(feels, findsNothing);
  expect(find.byKey(const Key('cycle-record-start')), findsNothing);
  expect(find.byKey(const Key('cycle-record-end')), findsNothing);
  await tap(find.byTooltip('打开月历'));
  await tap(find.text('回到今天'));
  expect(t.widget<CycleDateCell>(weekToday).selected, isTrue);
  expect(feels, findsOneWidget);
  expect(t.takeException(), isNull);
}
