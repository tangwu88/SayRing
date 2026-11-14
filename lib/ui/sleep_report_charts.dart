import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Charts only join adjacent observed points. The accessible readout and
/// previous/next controls expose the same values without requiring drag.
class SleepReportChart extends StatefulWidget {
  const SleepReportChart({
    required this.title,
    required this.series,
    required this.axis,
    required this.describe,
    this.onOpen,
    this.header,
    this.yLabel,
    this.minimum,
    this.maximum,
    super.key,
  });
  final String title;
  final List<({Color color, List<double?> values})> series;
  final List<String> axis;
  final String Function(int) describe;
  final ValueChanged<int>? onOpen;
  final Widget? header;
  final String Function(double)? yLabel;
  final double? minimum, maximum;
  @override
  State<SleepReportChart> createState() => _SleepReportChartState();
}

class _SleepReportChartState extends State<SleepReportChart> {
  int? index;
  bool get zh => Localizations.localeOf(context).languageCode == 'zh';
  @override
  void didUpdateWidget(SleepReportChart old) {
    super.didUpdateWidget(old);
    if (index != null && index! >= widget.axis.length) index = null;
  }

  void pick(double dx, double width, {bool tap = false}) {
    if (widget.axis.isEmpty || width <= 0) return;
    final i = (dx / width * (widget.axis.length - 1)).round().clamp(
      0,
      widget.axis.length - 1,
    );
    if (tap && i == index && widget.onOpen != null) {
      widget.onOpen!(i);
      return;
    }
    if (i != index) setState(() => index = i);
  }

  @override
  Widget build(BuildContext context) {
    final has = widget.series
        .expand((s) => s.values)
        .whereType<double>()
        .where((n) => n.isFinite)
        .toList();
    if (has.isEmpty || widget.axis.isEmpty) return const SizedBox.shrink();
    final naturalMin = has.reduce(math.min), naturalMax = has.reduce(math.max);
    final min =
        widget.minimum ??
        (naturalMin == naturalMax ? naturalMin - 1 : naturalMin);
    final max =
        widget.maximum ??
        (naturalMin == naturalMax ? naturalMax + 1 : naturalMax);
    String label(double value) =>
        widget.yLabel?.call(value) ??
        value.toStringAsFixed(value.abs() < 10 ? 1 : 0);
    final visible =
        index ??
        List<int>.generate(widget.axis.length, (i) => i).reversed.firstWhere(
          (i) => widget.series.any(
            (s) => i < s.values.length && s.values[i] != null,
          ),
          orElse: () => 0,
        );
    final enlarged = MediaQuery.textScalerOf(context).scale(14) > 20;
    final ticks = [label(max), label(min)];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (widget.header != null) ...[
              const SizedBox(height: 8),
              widget.header!,
            ],
            const SizedBox(height: 12),
            Semantics(
              liveRegion: index != null,
              child: Text(
                widget.describe(visible),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 10),
            if (enlarged)
              Wrap(
                spacing: 12,
                children: [for (final tick in ticks) Text(tick)],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!enlarged) ...[
                  Flexible(
                    flex: 2,
                    child: SizedBox(
                      height: 108,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final tick in ticks)
                            Text(
                              tick,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(
                    builder: (context, box) => Semantics(
                      label: widget.title,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) =>
                            pick(d.localPosition.dx, box.maxWidth, tap: true),
                        onHorizontalDragStart: (d) =>
                            pick(d.localPosition.dx, box.maxWidth),
                        onHorizontalDragUpdate: (d) =>
                            pick(d.localPosition.dx, box.maxWidth),
                        child: SizedBox(
                          height: 108,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _ChartPainter(
                              widget.series,
                              widget.axis.length,
                              min,
                              max,
                              visible,
                              Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              children: [
                Text(widget.axis.first),
                if (widget.axis.length > 1) Text(widget.axis.last),
              ],
            ),
            if (widget.axis.length > 1 || widget.onOpen != null)
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.axis.length > 1) ...[
                    IconButton(
                      tooltip: zh ? '上一个数据点' : 'Previous point',
                      onPressed: visible > 0
                          ? () => setState(() => index = visible - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: zh ? '下一个数据点' : 'Next point',
                      onPressed: visible + 1 < widget.axis.length
                          ? () => setState(() => index = visible + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                  if (widget.onOpen != null)
                    TextButton(
                      onPressed: () => widget.onOpen!(visible),
                      child: Text(zh ? '查看当天' : 'View day'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(
    this.series,
    this.points,
    this.low,
    this.high,
    this.index,
    this.grid,
  );
  final List<({Color color, List<double?> values})> series;
  final int points, index;
  final double low, high;
  final Color grid;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || high <= low) return;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = 4 + (size.height - 8) * i / 4;
      for (var x = 3.0; x < size.width - 3; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width - 3), y),
          gridPaint,
        );
      }
    }
    double x(int i) =>
        points < 2 ? size.width / 2 : 4 + (size.width - 8) * i / (points - 1);
    double y(double value) =>
        4 +
        (size.height - 8) * (1 - ((value - low) / (high - low)).clamp(0, 1));
    canvas.drawLine(
      Offset(x(index), 3),
      Offset(x(index), size.height - 3),
      gridPaint,
    );
    for (final line in series) {
      final color = Paint()
        ..color = line.color
        ..strokeWidth = 2.3;
      Offset? previous;
      for (var i = 0; i < line.values.length; i++) {
        final value = line.values[i];
        if (value == null || !value.isFinite) {
          previous = null;
          continue;
        }
        final point = Offset(x(i), y(value));
        if (previous != null) canvas.drawLine(previous, point, color);
        canvas.drawCircle(point, i == index ? 4.1 : 2.45, color);
        previous = point;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.series != series ||
      old.index != index ||
      old.low != low ||
      old.high != high ||
      old.grid != grid;
}

class NightMeasurementsChart extends StatelessWidget {
  const NightMeasurementsChart({
    required this.title,
    required this.stats,
    required this.segments,
    required this.begin,
    required this.end,
    required this.minimum,
    required this.maximum,
    required this.axisStart,
    required this.axisEnd,
    required this.color,
    super.key,
  });
  final String title, stats, axisStart, axisEnd;

  /// X is elapsed time in seconds; every item is a separate continuous run.
  final List<List<Offset>> segments;
  final double begin, end, minimum, maximum;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(stats, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 10),
          Semantics(
            label: '$title · $stats · $axisStart – $axisEnd',
            child: CustomPaint(
              painter: _NightPainter(
                segments,
                begin,
                end,
                minimum,
                maximum,
                color,
                Theme.of(context).colorScheme.outlineVariant,
              ),
              child: const SizedBox(height: 106, width: double.infinity),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 9,
            children: [Text(axisStart), Text(axisEnd)],
          ),
        ],
      ),
    ),
  );
}

class _NightPainter extends CustomPainter {
  _NightPainter(
    this.runs,
    this.first,
    this.last,
    this.low,
    this.high,
    this.color,
    this.grid,
  );
  final List<List<Offset>> runs;
  final double first, last, low, high;
  final Color color, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = grid;
    for (var i = 0; i <= 3; i++) {
      final y = 4 + (size.height - 8) * i / 3;
      for (var x = 4.0; x < size.width - 3; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width - 3), y),
          gridPaint,
        );
      }
    }
    final ink = Paint()
      ..color = color
      ..strokeWidth = 2;
    Offset map(Offset raw) => Offset(
      4 + (size.width - 8) * (raw.dx - first) / math.max(1, last - first),
      4 + (size.height - 8) * (1 - (raw.dy - low) / math.max(1, high - low)),
    );
    for (final run in runs) {
      Offset? previous;
      for (final raw in run) {
        final p = map(raw);
        if (previous != null) {
          canvas.drawLine(previous, p, ink);
        } else {
          canvas.drawCircle(p, 2.8, ink);
        }
        previous = p;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NightPainter old) =>
      old.runs != runs ||
      old.first != first ||
      old.last != last ||
      old.low != low ||
      old.high != high ||
      old.color != color ||
      old.grid != grid;
}
