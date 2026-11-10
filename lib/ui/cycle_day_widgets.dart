import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/cycle_tracking.dart';

const cycleRose = Color(0xffa74668);
const cyclePlum = Color(0xff68578d);
const _ink = Color(0xff332b40);
final _week = [
  uiCopy(null, "一"),
  uiCopy(null, "二"),
  uiCopy(null, "三"),
  uiCopy(null, "四"),
  uiCopy(null, "五"),
  uiCopy(null, "六"),
  uiCopy(null, "日"),
];
String cycleShort(String day) {
  final d = parseCycleDate(day);
  return uiCopy(null, "{p0}月{p1}日", parameters: [d.month, d.day]);
}

class CycleDateCell extends StatelessWidget {
  const CycleDateCell({
    required this.day,
    required this.selected,
    required this.onTap,
    this.weekday,
    super.key,
  });
  final CycleDayView day;
  final bool selected;
  final VoidCallback onTap;
  final String? weekday;
  @override
  Widget build(BuildContext context) {
    final actual = day.period != null,
        estimated = day.inReference,
        today = day.date == day.today;
    final ink = actual
        ? Colors.white
        : estimated
        ? cyclePlum
        : _ink;
    return Semantics(
      button: true,
      onTap: onTap,
      selected: selected,
      label:
          '${day.date}${today ? '，今天' : ''}${actual
              ? uiCopy(context, "，实际经期")
              : estimated
              ? '，经期参考范围'
              : ''}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (weekday != null)
                Text(
                  today ? uiCopy(context, "今") : weekday!,
                  style: TextStyle(
                    fontSize: 12,
                    color: today ? cyclePlum : Colors.black54,
                  ),
                ),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 1,
                    vertical: 2,
                  ),
                  padding: const EdgeInsets.all(2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: actual
                        ? cycleRose
                        : estimated
                        ? const Color(0xfff0eaf7)
                        : selected
                        ? const Color(0xffe8e3f1)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    border: selected ? Border.all(color: _ink, width: 2) : null,
                  ),
                  child: CustomPaint(
                    foregroundPainter: estimated ? const _DashedEdge() : null,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${parseCycleDate(day.date).day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: selected || actual
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedEdge extends CustomPainter {
  const _DashedEdge();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = cyclePlum
      ..strokeWidth = 1.2;
    final edge = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & s).deflate(1),
          const Radius.circular(8),
        ),
      );
    for (final m in edge.computeMetrics()) {
      for (double at = 0; at < m.length; at += 6) {
        c.drawPath(m.extractPath(at, math.min(at + 3.3, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedEdge old) => false;
}

class CycleDateLegend extends StatelessWidget {
  const CycleDateLegend({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 4,
    children: [
      for (final pair in [
        (true, uiCopy(context, "实际经期")),
        (false, uiCopy(context, "经期参考")),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 10,
              decoration: BoxDecoration(
                color: pair.$1 ? cycleRose : const Color(0xfff0eaf7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: pair.$1 ? null : const CustomPaint(painter: _DashedEdge()),
            ),
            const SizedBox(width: 5),
            Text(
              pair.$2,
              style: const TextStyle(fontSize: 12, color: Color(0xff554e5e)),
            ),
          ],
        ),
    ],
  );
}

class CycleWeek extends StatefulWidget {
  const CycleWeek({
    required this.selected,
    required this.today,
    required this.view,
    required this.select,
    super.key,
  });
  final String selected, today;
  final CycleDayView Function(String) view;
  final ValueChanged<String> select;
  @override
  State<CycleWeek> createState() => _CycleWeekState();
}

class _CycleWeekState extends State<CycleWeek> {
  double drag = 0;
  @override
  Widget build(BuildContext context) {
    final start = cycleWeekStart(widget.selected);
    final scale = MediaQuery.textScalerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: uiCopy(context, "上一周"),
              onPressed: () =>
                  widget.select(shiftCycleDate(widget.selected, -7)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                cycleShort(widget.selected),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.selected != widget.today)
              TextButton(
                onPressed: () => widget.select(widget.today),
                child: Text(uiCopy(context, "今天")),
              ),
            IconButton(
              tooltip: uiCopy(context, "下一周"),
              onPressed: () =>
                  widget.select(shiftCycleDate(widget.selected, 7)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => drag = 0,
          onHorizontalDragUpdate: (d) => drag += d.delta.dx,
          onHorizontalDragEnd: (d) {
            final dx = drag.abs() > 24 ? drag : (d.primaryVelocity ?? 0) / 8;
            if (dx.abs() > 24) {
              widget.select(shiftCycleDate(widget.selected, dx < 0 ? 7 : -7));
            }
          },
          child: SizedBox(
            height: math.max(64, scale.scale(34) + 28),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: CycleDateCell(
                      key: ValueKey('week-${shiftCycleDate(start, i)}'),
                      day: widget.view(shiftCycleDate(start, i)),
                      weekday: _week[i],
                      selected: shiftCycleDate(start, i) == widget.selected,
                      onTap: () => widget.select(shiftCycleDate(start, i)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Align(alignment: Alignment.centerRight, child: CycleDateLegend()),
      ],
    );
  }
}

class CycleMonthSheet extends StatefulWidget {
  const CycleMonthSheet({
    required this.selected,
    required this.today,
    required this.view,
    super.key,
  });
  final String selected, today;
  final CycleDayView Function(String) view;
  @override
  State<CycleMonthSheet> createState() => _CycleMonthSheetState();
}

class _CycleMonthSheetState extends State<CycleMonthSheet> {
  late DateTime month = parseCycleDate(widget.selected);
  void move(int delta) =>
      setState(() => month = DateTime.utc(month.year, month.month + delta));
  @override
  Widget build(BuildContext context) {
    final first = DateTime.utc(month.year, month.month),
        days = DateTime.utc(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: uiCopy(context, "上个月"),
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => move(-1),
                ),
                Expanded(
                  child: Text(
                    uiCopy(
                      context,
                      "{p0}年{p1}月",
                      parameters: [month.year, month.month],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: uiCopy(context, "下个月"),
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => move(1),
                ),
              ],
            ),
            Row(
              children: [
                for (final d in _week) Expanded(child: Center(child: Text(d))),
              ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ((days + offset + 6) ~/ 7) * 7,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: math.max(
                  46,
                  MediaQuery.textScalerOf(context).scale(20) + 15,
                ),
              ),
              itemBuilder: (ctx, i) {
                final n = i - offset + 1;
                if (n < 1 || n > days) return const SizedBox.shrink();
                final date = cycleDate(
                  DateTime.utc(month.year, month.month, n),
                );
                return CycleDateCell(
                  key: ValueKey('month-$date'),
                  day: widget.view(date),
                  selected: date == widget.selected,
                  onTap: () => Navigator.pop(context, date),
                );
              },
            ),
            const CycleDateLegend(),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, widget.today),
              icon: const Icon(Icons.today_outlined),
              label: Text(uiCopy(context, "回到今天")),
            ),
          ],
        ),
      ),
    );
  }
}
