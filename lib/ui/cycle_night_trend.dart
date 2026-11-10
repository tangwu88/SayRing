import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/cycle_tracking.dart';
import 'cycle_day_widgets.dart';

/// 图上每个点对应一个日历日。按所选日期向前看，不用之后的夜间样本构造过去的基线。
class CycleTrendSeries {
  CycleTrendSeries(this.metric, this.points, this.first, this.last);
  final String metric, first, last;
  final List<({String date, double delta})> points;
  String get unit => metric == 'skin_temperature'
      ? '℃'
      : metric == 'sleep_heart_rate'
      ? 'bpm'
      : 'ms';
  static CycleTrendSeries? build(
    Iterable<CycleNightFeature> nights,
    String metric,
    String until,
  ) {
    final available =
        nights
            .where(
              (n) =>
                  n.metric == metric &&
                  n.date.compareTo(until) <= 0 &&
                  n.value.isFinite,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (available.isEmpty) return null;
    final source = available.last.sourceKey, from = shiftCycleDate(until, -59);
    final dates = <String, double>{
      for (final n in available)
        if (n.sourceKey == source && n.date.compareTo(from) >= 0)
          n.date: n.value,
    };
    if (dates.isEmpty) return null;
    final mean = dates.values.reduce((a, b) => a + b) / dates.length;
    return CycleTrendSeries(
      metric,
      [for (final e in dates.entries) (date: e.key, delta: e.value - mean)],
      dates.keys.first,
      until,
    );
  }
}

String _name(String s) => switch (s) {
  'skin_temperature' => uiCopy(null, "夜间皮温"),
  'sleep_heart_rate' => uiCopy(null, "睡眠心率"),
  'hrv_sdnn' => 'HRV · SDNN',
  'hrv_rmssd' => 'HRV · RMSSD',
  _ => '',
};

class CycleNightTrend extends StatefulWidget {
  const CycleNightTrend({required this.nights, required this.until, super.key});
  final List<CycleNightFeature> nights;
  final String until;
  @override
  State<CycleNightTrend> createState() => _CycleNightTrendState();
}

class _CycleNightTrendState extends State<CycleNightTrend> {
  String selected = 'skin_temperature';
  String? picked;
  String valueLabel(CycleTrendSeries s, double delta) =>
      '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(s.metric == 'skin_temperature' ? 2 : 1)} ${s.unit}';
  @override
  void didUpdateWidget(CycleNightTrend old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) picked = null;
  }

  @override
  Widget build(BuildContext context) {
    final series = {
      for (final m in [
        'skin_temperature',
        'sleep_heart_rate',
        'hrv_sdnn',
        'hrv_rmssd',
      ])
        if (CycleTrendSeries.build(widget.nights, m, widget.until)
            case final CycleTrendSeries v)
          m: v,
    };
    if (series.isEmpty) return const SizedBox.shrink();
    final s = series[selected] ?? series.values.first;
    final point =
        s.points.where((p) => p.date == picked).firstOrNull ?? s.points.last;
    final value = valueLabel(s, point.delta);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _name(s.metric),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (s.points.length > 1)
                  PopupMenuButton<String>(
                    tooltip: uiCopy(context, "逐晚查看"),
                    icon: const Icon(Icons.list_alt_outlined),
                    initialValue: point.date,
                    onSelected: (v) => setState(() => picked = v),
                    itemBuilder: (_) => [
                      for (final p in s.points.reversed)
                        PopupMenuItem(
                          value: p.date,
                          child: Text(
                            '${cycleShort(p.date)} · ${valueLabel(s, p.delta)}',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            if (series.length > 1)
              Wrap(
                spacing: 6,
                children: [
                  for (final m in series.keys)
                    ChoiceChip(
                      label: Text(_name(m)),
                      selected: s.metric == m,
                      onSelected: (_) => setState(() {
                        selected = m;
                        picked = null;
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: cyclePlum,
              ),
            ),
            Text(
              uiCopy(
                context,
                "{p0} · 相对个人均值 · {p1}晚",
                parameters: [cycleShort(point.date), s.points.length],
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  '${_name(s.metric)}，${s.points.map((p) => '${cycleShort(p.date)} ${p.delta.toStringAsFixed(2)} ${s.unit}').join('，')}',
              child: SizedBox(
                height: 78,
                width: double.infinity,
                child: CustomPaint(painter: _NightPainter(s, point.date)),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(cycleShort(s.first))),
                if (s.first != s.last)
                  Expanded(
                    child: Text(cycleShort(s.last), textAlign: TextAlign.end),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NightPainter extends CustomPainter {
  _NightPainter(this.s, this.selectedDate);
  final String selectedDate;
  final CycleTrendSeries s;
  @override
  void paint(Canvas c, Size size) {
    final max = s.points.fold<double>(
          0.1,
          (v, p) => math.max(v, p.delta.abs()),
        ),
        span = cycleDays(s.first, s.last);
    final mid = size.height / 2,
        line = Paint()
          ..color = cyclePlum
          ..strokeWidth = 2;
    c.drawLine(
      Offset(4, mid),
      Offset(size.width - 4, mid),
      Paint()..color = const Color(0xffdad5e3),
    );
    Offset? prior;
    String? prevDate;
    for (final p in s.points) {
      final x = span == 0
          ? size.width / 2
          : 5 + (size.width - 10) * cycleDays(s.first, p.date) / span;
      final point = Offset(x, mid - p.delta / max * (mid - 5));
      if (prior != null && cycleDays(prevDate!, p.date) == 1) {
        c.drawLine(prior, point, line);
      }
      c.drawCircle(point, p.date == selectedDate ? 4.5 : 3.2, line);
      prior = point;
      prevDate = p.date;
    }
  }

  @override
  bool shouldRepaint(_NightPainter old) =>
      old.s != s || old.selectedDate != selectedDate;
}
