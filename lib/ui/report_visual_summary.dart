import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Read-only, report-bound summaries. Never derive chart values from AI prose.
class ReportVisualSummary extends StatelessWidget {
  const ReportVisualSummary({
    required this.visuals,
    this.score,
    this.explanation,
    super.key,
  });
  final Map<String, Object?> visuals;
  final num? score;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final sleep = _object(visuals['sleep']);
    final metrics = _rows(visuals['metrics']);
    final value =
        score != null &&
            score!.isFinite &&
            score! >= 0 &&
            score! <= 100 &&
            score! == score!.roundToDouble()
        ? score!.toInt()
        : null;
    if (sleep.isEmpty && metrics.isEmpty && score == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sleep.isNotEmpty || score != null) ...[
          _surface(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (score != null || explanation != null) ...[
                  Wrap(
                    spacing: 18,
                    runSpacing: 14,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Semantics(
                        label: value == null
                            ? '证据不足，未评分'
                            : 'AI 睡眠参考评分 $value / 100',
                        child: SizedBox.square(
                          dimension: 160,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.square(
                                dimension: 148,
                                child: CircularProgressIndicator(
                                  value: (value ?? 0) / 100,
                                  strokeWidth: 8,
                                  color: const Color(0xff7166c8),
                                  backgroundColor: const Color(0xffe7e5f4),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text.rich(
                                  TextSpan(
                                    text: value?.toString() ?? '—',
                                    children: [
                                      TextSpan(
                                        text: value == null ? ' 未评分' : ' / 100',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 睡眠参考评分',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'AI 参考 · 非设备评分 · 非临床评估',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (explanation?.trim().isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        explanation!,
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                ],
                if (sleep.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _facts(context, [
                    (
                      '睡眠时长',
                      _duration(_number(sleep['totalSeconds'])),
                      Icons.bedtime_outlined,
                    ),
                    (
                      '醒来次数',
                      _number(sleep['wakeCount']) == null
                          ? '未记录'
                          : '${_format(_number(sleep['wakeCount']))} 次',
                      Icons.wb_twilight_outlined,
                    ),
                    (
                      '睡眠记录',
                      _number(sleep['sessionCount']) == null
                          ? '未记录'
                          : '${_format(_number(sleep['sessionCount']))} 段',
                      Icons.layers_outlined,
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (sleep.isNotEmpty) ...[
          _sleepStages(context, sleep),
          const SizedBox(height: 12),
        ],
        if (metrics.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '数据一览',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          for (final metric in metrics)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _metric(context, metric),
            ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '图中为每日样本均值，缺失日期不补零。步数、距离和热量的样本均值不代表全天累计。',
              style: TextStyle(fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _facts(BuildContext context, List<(String, String, IconData)> facts) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth >= 470 &&
                  MediaQuery.textScalerOf(context).scale(1) < 1.5
              ? 3
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (label, value, icon) in facts)
                SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 16),
                            const SizedBox(width: 6),
                            Text(label),
                          ],
                        ),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );

  Widget _sleepStages(BuildContext context, Map<String, Object?> sleep) {
    final total = _number(sleep['totalSeconds']);
    final stages = _rows(sleep['stages']);
    final other = _number(sleep['unclassifiedSeconds']);
    final entries = [
      ...stages,
      if (other != null) <String, Object?>{'label': '未分类', 'seconds': other},
    ];
    const colors = [
      Color(0xff655abd),
      Color(0xffa29bdf),
      Color(0xff49b4b2),
      Color(0xffdce1eb),
    ];
    final segments = <Widget>[];
    if (total != null && total > 0) {
      for (var i = 0; i < entries.length; i++) {
        final seconds = _number(entries[i]['seconds']);
        if (seconds != null && seconds > 0 && seconds <= total) {
          segments.add(
            Expanded(
              flex: math.max(1, (seconds * 100).round()),
              child: ColoredBox(
                color: colors[i % colors.length],
                child: const SizedBox(height: 24),
              ),
            ),
          );
        }
      }
    }
    return _surface(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '睡眠阶段',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 16),
          if (segments.isNotEmpty)
            Semantics(
              label: '睡眠阶段时长占比，具体数值见下方图例',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(children: segments),
              ),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 10,
                runSpacing: 5,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${entries[i]['label'] ?? ''}'),
                    ],
                  ),
                  Text(
                    _duration(_number(entries[i]['seconds'])),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            '缺失阶段显示“未记录”，未分类时长单独保留。',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, Map<String, Object?> metric) {
    final points = _rows(metric['points'])
        .where(
          (p) =>
              DateTime.tryParse('${p['date']}') != null &&
              _number(p['value']) != null,
        )
        .toList();
    final unit = '${metric['unit'] ?? ''}';
    return _surface(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${metric['label'] ?? '健康指标'}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                _format(_number(metric['average'])),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$unit · 样本均值',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 16),
            Semantics(
              label:
                  '${metric['label']}每日样本均值趋势，共${points.length}个有记录日期；下方可查看数值',
              child: SizedBox(
                height: 90,
                child: CustomPaint(
                  painter: _ReportTrendPainter(
                    points,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  '${points.first['date']}',
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  points.length == 1 ? '仅 1 天记录' : '${points.last['date']}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '最近 ${_format(_number(metric['latest']))} $unit · ${_format(_number(metric['sampleCount']))} 个样本',
            style: const TextStyle(fontSize: 12),
          ),
          if (points.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('查看每日数值', style: TextStyle(fontSize: 12)),
              children: [
                for (final point in points)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      children: [
                        Text('${point['date']}'),
                        Text('${_format(_number(point['value']))} $unit'),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _surface(BuildContext context, Widget child) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .45),
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class ReportAdviceList extends StatelessWidget {
  const ReportAdviceList({required this.items, super.key});
  final List<String> items;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: '建议 ${i + 1}',
                  child: Text(
                    '${i + 1}'.padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(items[i], style: const TextStyle(height: 1.65)),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _ReportTrendPainter extends CustomPainter {
  const _ReportTrendPainter(this.points, this.color);
  final List<Map<String, Object?>> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final times = points
        .map((p) => DateTime.parse('${p['date']}').millisecondsSinceEpoch)
        .toList();
    final values = points.map((p) => _number(p['value'])!).toList();
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final from = times.reduce(math.min), end = times.reduce(math.max);
    final path = Path();
    final dots = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = end == from
          ? size.width / 2
          : 8 + (times[i] - from) / (end - from) * (size.width - 16);
      final y = high == low
          ? size.height / 2
          : 8 + (1 - (values[i] - low) / (high - low)) * (size.height - 20);
      final dot = Offset(x, y);
      dots.add(dot);
      if (i == 0 ||
          times[i] - times[i - 1] > const Duration(days: 1).inMilliseconds) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawLine(
      Offset(8, size.height - 8),
      Offset(size.width - 8, size.height - 8),
      Paint()
        ..color = color.withValues(alpha: .1)
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (final point in dots) {
      canvas.drawCircle(point, 3.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ReportTrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

Map<String, Object?> _object(Object? value) =>
    value is Map ? value.map((k, v) => MapEntry('$k', v)) : const {};
List<Map<String, Object?>> _rows(Object? value) =>
    value is List ? value.whereType<Map>().map(_object).toList() : const [];
double? _number(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value.toDouble() : null;
String _format(num? value) => value == null
    ? '—'
    : value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
String _duration(num? seconds) {
  if (seconds == null) return '未记录';
  final minutes = (seconds / 60).round();
  return '${minutes ~/ 60}小时${minutes % 60}分';
}
