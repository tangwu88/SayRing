import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/ring_experience.dart';
import '../services/cardiovascular_trend_summary.dart';
import 'app_theme.dart';
import 'cardiovascular_insights.dart';
import 'ring_share_page.dart';

const _upper = SaydianColors.techBlue;
const _lower = Color(0xFF6359A5);

List<FlSpot> _dailySpots(List<double?> values) {
  final spots = <FlSpot>[];
  for (var i = 0; i < values.length; i++) {
    final value = values[i];
    if (value == null) continue;
    if (spots.isNotEmpty && i > spots.last.x + 1) spots.add(FlSpot.nullSpot);
    spots.add(FlSpot(i.toDouble(), value));
  }
  return spots;
}

class CardioPressureOverview extends StatelessWidget {
  const CardioPressureOverview({
    required this.latest,
    required this.source,
    required this.dates,
    required this.daily,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    super.key,
  });

  final PressureSample latest;
  final Widget source;
  final List<DateTime> dates;
  final Map<DateTime, PressureDay> daily;
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    final picked = daily[selected];
    final stamp = selected ?? latest.at;
    final dayLabel = stamp.year == DateTime.now().year
        ? l.formatShortMonthDay(stamp)
        : l.formatShortDate(stamp);
    final time = selected == null
        ? '$dayLabel · ${ringClockText(stamp)}'
        : dayLabel;
    final date = selected;
    final hasReading = date == null || picked != null;
    final count = daily.length;
    return Card(
      key: const Key('cardio-overview'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  date == null
                      ? ringText(context, '最近一次血压', 'Latest reading')
                      : ringText(context, '当日平均血压', 'Day’s average'),
                  style: theme.titleMedium,
                ),
                TextButton.icon(
                  key: const Key('record-pressure-reference'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(ringText(context, '记上臂血压', 'Add cuff reading')),
                ),
              ],
            ),
            Semantics(
              liveRegion: date != null,
              child: hasReading
                  ? Wrap(
                      spacing: 28,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        _PressureValue(
                          value: picked?.systolic ?? latest.systolic,
                          systolic: true,
                        ),
                        _PressureValue(
                          value: picked?.diastolic ?? latest.diastolic,
                          systolic: false,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'mmHg',
                            style: theme.labelMedium?.copyWith(
                              color: SaydianColors.muted,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      ringText(
                        context,
                        '当天没有血压记录',
                        'No pressure reading that day',
                      ),
                      style: theme.titleMedium,
                    ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                source,
                Text(
                  time,
                  style: theme.bodySmall?.copyWith(color: SaydianColors.muted),
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  ringText(context, '日均血压', 'Daily averages'),
                  style: theme.labelLarge,
                ),
                if (date == null)
                  Tooltip(
                    message: ringText(context, '逐日查看', 'Explore by day'),
                    child: TextButton.icon(
                      key: const Key('cardio-explore-days'),
                      onPressed: () => onSelect(ringDate(latest.at)),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.touch_app_outlined, size: 16),
                      label: Text(
                        ringText(
                          context,
                          '$count 天有记录',
                          count == 1
                              ? '1 recorded day'
                              : '$count recorded days',
                        ),
                      ),
                    ),
                  )
                else
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: ringText(context, '上一天', 'Previous day'),
                        onPressed: date == dates.first
                            ? null
                            : () => onSelect(ringAddDays(date, -1)),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        l.formatShortMonthDay(date),
                        style: theme.labelMedium,
                      ),
                      IconButton(
                        tooltip: ringText(context, '下一天', 'Next day'),
                        onPressed: date == dates.last
                            ? null
                            : () => onSelect(ringAddDays(date, 1)),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _PressurePlot(
              dates: dates,
              daily: daily,
              selected: date,
              onSelect: onSelect,
            ),
            if (date != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: const Key('cardio-show-latest'),
                  onPressed: () => onSelect(null),
                  icon: const Icon(Icons.undo, size: 16),
                  label: Text(ringText(context, '返回最近一次', 'Back to latest')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PressureValue extends StatelessWidget {
  const _PressureValue({required this.value, required this.systolic});
  final num value;
  final bool systolic;

  @override
  Widget build(BuildContext context) {
    final color = systolic ? _upper : _lower;
    final theme = Theme.of(context).textTheme;
    final label = systolic
        ? ringText(context, '高压', 'Systolic')
        : ringText(context, '低压', 'Diastolic');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              systolic ? Icons.circle : Icons.square_outlined,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: theme.labelMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
        Text(
          cardioNumber(value.toDouble()),
          style: theme.displayLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PressurePlot extends StatelessWidget {
  const _PressurePlot({
    required this.dates,
    required this.daily,
    required this.selected,
    required this.onSelect,
  });
  final List<DateTime> dates;
  final Map<DateTime, PressureDay> daily;
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelect;

  @override
  Widget build(BuildContext c) {
    final l = MaterialLocalizations.of(c);
    final labels = Theme.of(c).textTheme.labelSmall?.copyWith(
      color: SaydianColors.muted,
      fontWeight: FontWeight.normal,
    );
    final low =
        (daily.values.map((d) => d.diastolic).reduce(math.min) / 10).floor() *
            10.0 -
        5;
    final high =
        (daily.values.map((d) => d.systolic).reduce(math.max) / 10).ceil() *
            10.0 +
        5;
    final index = dates.indexOf(selected ?? daily.keys.last);
    final chart = LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: 0,
        maxX: dates.length - 1.0,
        minY: low,
        maxY: high,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        extraLinesData: ExtraLinesData(
          extraLinesOnTop: false,
          horizontalLines: [
            for (final y in [low, (low + high) / 2, high])
              HorizontalLine(
                y: y,
                color: SaydianColors.line,
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
          ],
          verticalLines: [
            if (selected != null)
              VerticalLine(
                x: index.toDouble(),
                color: SaydianColors.outline,
                strokeWidth: 1.4,
              ),
          ],
        ),
        lineBarsData: [
          for (final upper in [true, false])
            LineChartBarData(
              spots: _dailySpots([
                for (final d in dates)
                  upper ? daily[d]?.systolic : daily[d]?.diastolic,
              ]),
              color: upper ? _upper : _lower,
              barWidth: 2.5,
              dashArray: upper ? null : [5, 3],
              dotData: FlDotData(
                getDotPainter: (spot, _, _, _) {
                  final size = selected != null && spot.x == index ? 4.5 : 3.0;
                  return upper
                      ? FlDotCirclePainter(
                          radius: size,
                          color: _upper,
                          strokeWidth: 0,
                        )
                      : FlDotSquarePainter(
                          size: size * 2,
                          color: Theme.of(c).colorScheme.surface,
                          strokeColor: _lower,
                          strokeWidth: 1.6,
                        );
                },
              ),
            ),
        ],
      ),
    );
    String describe(int i) {
      final reading = daily[dates[i]];
      final spoken = reading == null
          ? ringText(c, '无血压记录', 'No pressure reading')
          : '${ringText(c, "高压", "Systolic")} ${cardioNumber(reading.systolic)}, '
                '${ringText(c, "低压", "Diastolic")} ${cardioNumber(reading.diastolic)} mmHg';
      return '${l.formatShortDate(dates[i])}, $spoken';
    }

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              height: 124,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final y in [high, (low + high) / 2, low])
                    Text(cardioNumber(y), style: labels),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Semantics(
                  label: ringText(
                    c,
                    '逐日查看平均血压',
                    'Explore daily average pressure',
                  ),
                  value: describe(index),
                  increasedValue: index < dates.length - 1
                      ? describe(index + 1)
                      : null,
                  decreasedValue: index > 0 ? describe(index - 1) : null,
                  onIncrease: index < dates.length - 1
                      ? () => onSelect(dates[index + 1])
                      : null,
                  onDecrease: index > 0
                      ? () => onSelect(dates[index - 1])
                      : null,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      void pick(double dx) {
                        final next = (dx / box.maxWidth * (dates.length - 1))
                            .round()
                            .clamp(0, dates.length - 1);
                        if (dates[next] != selected) onSelect(dates[next]);
                      }

                      return GestureDetector(
                        key: const Key('cardio-pressure-plot'),
                        excludeFromSemantics: true,
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (e) => pick(e.localPosition.dx),
                        onHorizontalDragStart: (e) => pick(e.localPosition.dx),
                        onHorizontalDragUpdate: (e) => pick(e.localPosition.dx),
                        child: SizedBox(
                          height: 112,
                          child: IgnorePointer(child: chart),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(l.formatShortMonthDay(dates.first), style: labels),
            ),
            Flexible(
              child: Text(
                l.formatShortMonthDay(dates.last),
                textAlign: TextAlign.end,
                style: labels,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CardioContextCard extends StatelessWidget {
  const CardioContextCard({
    required this.series,
    required this.dates,
    required this.selected,
    super.key,
  });
  final List<CardioContextSeries> series;
  final List<DateTime> dates;
  final DateTime? selected;

  @override
  Widget build(BuildContext c) {
    final theme = Theme.of(c).textTheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              selected == null
                  ? ringText(c, '同期日均', 'Period averages')
                  : '${ringText(c, "同日记录", "Same-day readings")} · ${MaterialLocalizations.of(c).formatShortMonthDay(selected!)}',
              style: theme.titleMedium,
            ),
            for (final item in series) ...[
              const Divider(height: 20),
              _ContextMetric(item: item, dates: dates, selected: selected),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContextMetric extends StatelessWidget {
  const _ContextMetric({
    required this.item,
    required this.dates,
    required this.selected,
  });
  final CardioContextSeries item;
  final List<DateTime> dates;
  final DateTime? selected;

  @override
  Widget build(BuildContext c) {
    final (icon, color) = switch (item.metric) {
      HealthMetric.heartRate => (
        Icons.favorite_outline,
        const Color(0xFFA74660),
      ),
      HealthMetric.sleep => (Icons.bedtime_outlined, _lower),
      _ => (Icons.directions_walk, SaydianColors.techCyanDark),
    };
    final values = [for (final day in dates) item.values[day]];
    final observed = values.nonNulls;
    final value = selected == null
        ? cardioMean(observed)
        : item.values[selected];
    final theme = Theme.of(c).textTheme;
    final label = cardioMetric(c, item.metric);
    final reading = value == null
        ? ringText(c, '暂无记录', 'No reading')
        : cardioValue(c, item.metric, value);
    final name = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 8),
        Flexible(child: Text(label, style: theme.bodyMedium)),
      ],
    );
    final lo = observed.reduce(math.min), hi = observed.reduce(math.max);
    final padding = hi == lo ? 1.0 : (hi - lo) * .15;
    final mini = ExcludeSemantics(
      child: SizedBox(
        width: 82,
        height: 26,
        child: LineChart(
          key: ValueKey('cardio-spark-${item.metric.name}'),
          duration: Duration.zero,
          LineChartData(
            minX: 0,
            maxX: dates.length - 1.0,
            minY: lo - padding,
            maxY: hi + padding,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            extraLinesData: ExtraLinesData(
              verticalLines: [
                if (selected != null)
                  VerticalLine(
                    x: dates.indexOf(selected!).toDouble(),
                    color: SaydianColors.outline,
                    strokeWidth: 1,
                  ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: _dailySpots(values),
                color: color,
                barWidth: 1.7,
                dotData: FlDotData(
                  getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                    radius: dates[spot.x.toInt()] == selected ? 3 : 1.6,
                    color: color,
                    strokeWidth: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final number = Text(reading, style: theme.titleSmall);
    return Semantics(
      container: true,
      child: LayoutBuilder(
        builder: (_, box) {
          if (MediaQuery.textScalerOf(c).scale(16) > 21 || box.maxWidth < 270) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                name,
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [number, mini],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: name),
              number,
              const SizedBox(width: 12),
              mini,
            ],
          );
        },
      ),
    );
  }
}
