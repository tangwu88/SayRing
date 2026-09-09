import '../l10n/global_locale_controller.dart';
import '../l10n/ui_labels.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../services/app_controller.dart';
import '../services/health_analysis.dart';
import 'app_theme.dart';
import 'prototype_pages.dart';

class HealthMetricMiniChart extends StatelessWidget {
  const HealthMetricMiniChart({
    required this.controller,
    required this.metric,
    required this.color,
    this.showEmptyLabel = true,
    super.key,
  });

  final AppController controller;
  final HealthMetric metric;
  final Color color;
  final bool showEmptyLabel;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return SizedBox(
      height: 38,
      child: FutureBuilder<List<HealthRecord>>(
        future: controller.loadHealthRecords(
          metric: metric,
          start: start,
          end: start.add(const Duration(days: 1)),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasError) {
            return Text(
              context.l10n.trendUnavailable,
              style: TextStyle(color: SaydianColors.muted),
            );
          }
          final records = snapshot.data ?? const <HealthRecord>[];
          if (records.isEmpty && !showEmptyLabel) {
            return const SizedBox.shrink();
          }
          if (records.length < 2) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                records.isEmpty ? '暂无数据' : '仅 1 条记录',
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 13,
                ),
              ),
            );
          }
          final data = const HealthAnalysisService().analyze(
            metric: metric,
            records: records,
            previousRecords: const [],
            period: HealthTrendPeriod.day,
            anchor: now,
          );
          if (data.points.length < 2) return const SizedBox.shrink();
          return Semantics(
            label: '${metric.label}今日趋势，共${data.points.length}个数据点',
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 24,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.points
                        .map(
                          (point) => FlSpot(
                            point.at.hour + point.at.minute / 60,
                            point.value,
                          ),
                        )
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.22,
                    color: color,
                    barWidth: 2.2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class HealthTrendPage extends StatefulWidget {
  const HealthTrendPage({
    required this.controller,
    required this.metric,
    this.onMeasure,
    super.key,
  });

  final AppController controller;
  final HealthMetric metric;
  final Future<void> Function()? onMeasure;

  @override
  State<HealthTrendPage> createState() => _HealthTrendPageState();
}

class _HealthTrendPageState extends State<HealthTrendPage> {
  static const _analysis = HealthAnalysisService();

  HealthTrendPeriod _period = HealthTrendPeriod.day;
  DateTime _anchor = DateTime.now();
  String? _selectedValueKey;
  bool _loading = true;
  Object? _error;
  bool _measuring = false;
  List<HealthRecord> _records = const [];
  List<HealthRecord> _previousRecords = const [];

  HealthTrendData get _data => _analysis.analyze(
    metric: widget.metric,
    records: _records,
    previousRecords: _previousRecords,
    period: _period,
    anchor: _anchor,
    selectedValueKey: _selectedValueKey,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final range = HealthTrendRange.forPeriod(_period, _anchor);
    try {
      final values = await Future.wait([
        widget.controller.loadHealthRecords(
          metric: widget.metric,
          start: range.start,
          end: range.end,
        ),
        widget.controller.loadHealthRecords(
          metric: widget.metric,
          start: range.previousStart,
          end: range.previousEnd,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _records = values[0];
        _previousRecords = values[1];
        final keys = HealthAnalysisService.availableValueKeys(
          widget.metric,
          _records,
        );
        if (_selectedValueKey != null && !keys.contains(_selectedValueKey)) {
          _selectedValueKey = null;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted || !showLoading) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _shift(int direction) {
    setState(() {
      _anchor = switch (_period) {
        HealthTrendPeriod.day => _anchor.add(Duration(days: direction)),
        HealthTrendPeriod.week => _anchor.add(Duration(days: 7 * direction)),
        HealthTrendPeriod.month => DateTime(
          _anchor.year,
          _anchor.month + direction,
          math.min(_anchor.day, 28),
        ),
      };
    });
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '选择查看日期',
    );
    if (picked == null || !mounted) return;
    setState(() => _anchor = picked);
    _load();
  }

  Future<void> _measure() async {
    final onMeasure = widget.onMeasure;
    if (onMeasure == null || _measuring) return;
    setState(() => _measuring = true);
    try {
      await onMeasure();
      if (!mounted) return;
      final range = HealthTrendRange.forPeriod(_period, _anchor);
      final cached =
          widget.controller.healthRecords
              .where(
                (record) =>
                    record.metric == widget.metric &&
                    !record.measuredAt.isBefore(range.start) &&
                    record.measuredAt.isBefore(range.end),
              )
              .toList()
            ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      final merged = <String, HealthRecord>{
        for (final record in _records) record.id: record,
        for (final record in cached) record.id: record,
      }.values.toList()..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      setState(() {
        if (merged.isNotEmpty) _records = merged;
        _measuring = false;
        _loading = false;
        _error = null;
      });
      // The controller already exposes a valid result in memory. Refresh the
      // encrypted store silently so a busy SQLCipher queue cannot leave the
      // visible measurement button spinning after the result dialog closes.
      unawaited(_load(showLoading: false));
    } finally {
      if (mounted && _measuring) setState(() => _measuring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = HealthTrendRange.forPeriod(_period, _anchor);
    final rangeLabel = switch (_period) {
      HealthTrendPeriod.day => DateFormat('yyyy年M月d日').format(range.start),
      HealthTrendPeriod.week =>
        '${DateFormat('M月d日').format(range.start)} - ${DateFormat('M月d日').format(range.end.subtract(const Duration(days: 1)))}',
      HealthTrendPeriod.month => DateFormat('yyyy年M月').format(range.start),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.metricAnalysis(context.l10n.metricName(widget.metric)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: Key('health-trend-${widget.metric.wireName}'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            SegmentedButton<HealthTrendPeriod>(
              segments: [
                for (final period in HealthTrendPeriod.values)
                  ButtonSegment(value: period, label: Text(period.label)),
              ],
              selected: {_period},
              onSelectionChanged: (selection) {
                setState(() => _period = selection.single);
                _load();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: '上一${_period.label}',
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(rangeLabel),
                  ),
                ),
                IconButton(
                  tooltip: '下一${_period.label}',
                  onPressed: range.end.isAfter(DateTime.now())
                      ? null
                      : () => _shift(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.onMeasure != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: Key('health-measure-${widget.metric.wireName}'),
                  onPressed: _measuring ? null : _measure,
                  icon: _measuring
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.monitor_heart_outlined),
                  label: Text(_measuring ? '测量中' : '手动测量'),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_loading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              _MessageCard(
                icon: Icons.error_outline_rounded,
                title: '数据读取失败',
                detail: '请稍后重试，本机记录不会被删除。',
                action: _load,
              )
            else
              ..._content(_data),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(HealthTrendData data) {
    final keys = HealthAnalysisService.availableValueKeys(
      widget.metric,
      _records,
    );
    return [
      if ((widget.metric == HealthMetric.bodyComposition ||
              widget.metric == HealthMetric.bloodComposition) &&
          keys.isNotEmpty) ...[
        _MetricFieldSelector(
          keys: keys,
          selected: data.valueKey,
          onSelected: (value) => setState(() => _selectedValueKey = value),
        ),
        const SizedBox(height: 12),
      ],
      if (data.records.isEmpty)
        const _MessageCard(icon: Icons.show_chart_rounded, title: '该时间段暂无数据')
      else ...[
        _SummaryCard(
          metric: widget.metric,
          summary: data.summary,
          unit: _unit(widget.metric, data.records.first, data.valueKey),
          valueKey: data.valueKey,
        ),
        const SizedBox(height: 12),
        if (widget.metric != HealthMetric.ecg)
          _TrendChartCard(metric: widget.metric, data: data),
        if (widget.metric != HealthMetric.ecg) const SizedBox(height: 16),
        Row(
          children: [
            Text(
              context.l10n.recentData,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '${data.records.length} 条',
              style: const TextStyle(color: SaydianColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final record in data.records.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _RecordTile(
              controller: widget.controller,
              record: record,
              valueKey: data.valueKey,
            ),
          ),
        if (data.records.length > 6)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: Key('health-all-records-${widget.metric.wireName}'),
              onPressed: () => _showAllRecords(data),
              icon: const Icon(Icons.list_alt_rounded),
              label: Text('查看全部 ${data.records.length} 条数据'),
            ),
          ),
      ],
      const SizedBox(height: 8),
      FeatureStateCard(
        message: context.l10n.trendReferenceOnly,
        detail: context.l10n.trendVariationSafety,
        icon: Icons.health_and_safety_outlined,
        color: SaydianColors.green,
      ),
    ];
  }

  Future<void> _showAllRecords(HealthTrendData data) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: .86,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.metricAllData(
                            context.l10n.metricName(widget.metric),
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${data.records.length} 条',
                        style: const TextStyle(color: SaydianColors.muted),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: data.records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) => _RecordTile(
                      controller: widget.controller,
                      record: data.records[index],
                      valueKey: data.valueKey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MetricFieldSelector extends StatelessWidget {
  const _MetricFieldSelector({
    required this.keys,
    required this.selected,
    required this.onSelected,
  });

  final List<String> keys;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final key in keys)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_fieldLabel(key)),
                selected: selected == key,
                onSelected: (_) => onSelected(key),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.metric,
    required this.summary,
    required this.unit,
    required this.valueKey,
  });

  final HealthMetric metric;
  final HealthMetricSummary summary;
  final String unit;
  final String valueKey;

  @override
  Widget build(BuildContext context) {
    final values = <(String, String)>[
      ('平均值', _format(summary.average, unit)),
      ('最大值', _format(summary.maximum, unit)),
      ('最小值', _format(summary.minimum, unit)),
      ('记录数', '${summary.recordCount} 条'),
    ];
    if (metric == HealthMetric.bloodPressure &&
        summary.secondaryAverage != null) {
      values[0] = (
        '平均血压',
        '${_number(summary.average)}/${_number(summary.secondaryAverage)} $unit',
      );
    }
    final change = summary.changeFromPrevious;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fieldLabel(valueKey),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                for (final value in values)
                  SizedBox(
                    width: 126,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value.$1,
                          style: const TextStyle(
                            color: SaydianColors.muted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          value.$2,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (change != null) ...[
              const SizedBox(height: 13),
              Text(
                '较上一周期 ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} $unit',
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({required this.metric, required this.data});

  final HealthMetric metric;
  final HealthTrendData data;

  @override
  Widget build(BuildContext context) {
    if (data.points.isEmpty) {
      return const _MessageCard(
        icon: Icons.show_chart_rounded,
        title: '暂无可绘制数据',
        detail: '记录中没有该指标的有效数值。',
      );
    }
    final isBar =
        metric == HealthMetric.steps ||
        metric == HealthMetric.distance ||
        metric == HealthMetric.calories ||
        metric == HealthMetric.sleep;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 16, 12),
        child: Semantics(
          label:
              '${metric.label}趋势图，${data.points.length}个数据点，平均${_number(data.summary.average)}',
          child: SizedBox(
            height: 250,
            child: isBar
                ? _barChart(context, data)
                : _lineChart(context: context, metric: metric, data: data),
          ),
        ),
      ),
    );
  }
}

Widget _lineChart({
  required BuildContext context,
  required HealthMetric metric,
  required HealthTrendData data,
}) {
  final primary = data.points
      .asMap()
      .entries
      .map((entry) => FlSpot(entry.key.toDouble(), entry.value.value))
      .toList();
  final secondary = data.points
      .asMap()
      .entries
      .where((entry) => entry.value.secondaryValue != null)
      .map((entry) => FlSpot(entry.key.toDouble(), entry.value.secondaryValue!))
      .toList();
  final allValues = [
    ...primary.map((spot) => spot.y),
    ...secondary.map((spot) => spot.y),
  ];
  final min = allValues.reduce(math.min);
  final max = allValues.reduce(math.max);
  final padding = math.max((max - min) * 0.18, max == 0 ? 1.0 : max * 0.04);
  final minY = math.max(0, min - padding).toDouble();
  final maxY = (max + padding).toDouble();
  return LineChart(
    LineChartData(
      minY: minY,
      maxY: maxY,
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: SaydianColors.line, strokeWidth: 1),
      ),
      titlesData: _titles(context, data, minY: minY, maxY: maxY),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map(
                (spot) => LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
              .toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: primary,
          color: _metricColor(metric),
          isCurved: primary.length > 2,
          barWidth: 3,
          dotData: FlDotData(show: primary.length < 16),
          belowBarData: BarAreaData(
            show: true,
            color: _metricColor(metric).withValues(alpha: 0.09),
          ),
        ),
        if (secondary.isNotEmpty)
          LineChartBarData(
            spots: secondary,
            color: SaydianColors.blue,
            isCurved: secondary.length > 2,
            barWidth: 3,
            dotData: FlDotData(show: secondary.length < 16),
          ),
      ],
    ),
  );
}

Widget _barChart(BuildContext context, HealthTrendData data) {
  final maximum = data.points.map((point) => point.value).reduce(math.max);
  final maxY = math.max(maximum * 1.15, 1).toDouble();
  return BarChart(
    BarChartData(
      minY: 0,
      maxY: maxY,
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: SaydianColors.line, strokeWidth: 1),
      ),
      titlesData: _titles(context, data, minY: 0, maxY: maxY),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
            rod.toY.toStringAsFixed(1),
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      barGroups: data.points
          .asMap()
          .entries
          .map(
            (entry) => BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value,
                  color: SaydianColors.blue,
                  width: data.points.length > 14 ? 8 : 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    ),
  );
}

FlTitlesData _titles(
  BuildContext context,
  HealthTrendData data, {
  required double minY,
  required double maxY,
}) {
  final interval = _niceAxisInterval(maxY - minY);
  final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
  final longest = math.max(_axisLabel(minY).length, _axisLabel(maxY).length);
  final reservedSize = (longest * 7.4 * textScale + 12).clamp(42.0, 72.0);
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: reservedSize,
        interval: interval,
        getTitlesWidget: (value, meta) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            _axisLabel(value),
            maxLines: 1,
            style: const TextStyle(fontSize: 12, color: SaydianColors.muted),
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        interval: math.max(1, (data.points.length / 4).ceilToDouble()),
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (index < 0 || index >= data.points.length) {
            return const SizedBox.shrink();
          }
          final point = data.points[index];
          final text = data.range.end.difference(data.range.start).inDays <= 1
              ? DateFormat('HH:mm').format(point.at)
              : DateFormat('M/d').format(point.at);
          return Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(text, style: const TextStyle(fontSize: 13)),
          );
        },
      ),
    ),
  );
}

double _niceAxisInterval(double span) {
  if (!span.isFinite || span <= 0) return 1;
  final raw = span / 4;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final normalized = raw / magnitude;
  final step = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  return step * magnitude;
}

String _axisLabel(double value) {
  if (value.abs() >= 1000) return value.toStringAsFixed(0);
  if (value.abs() >= 10) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.controller,
    required this.record,
    required this.valueKey,
  });

  final AppController controller;
  final HealthRecord record;
  final String valueKey;

  @override
  Widget build(BuildContext context) {
    final value = record.metric == HealthMetric.bloodPressure
        ? record.displayValue
        : _number(record.values[valueKey] ?? record.values['value']);
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'health-record-detail'),
            builder: (_) =>
                HealthRecordDetailPage(controller: controller, record: record),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: _metricColor(record.metric).withValues(alpha: 0.12),
          foregroundColor: _metricColor(record.metric),
          child: const Icon(Icons.monitor_heart_outlined),
        ),
        title: Text(
          '$value ${_unit(record.metric, record, valueKey)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          DateFormat(
            'yyyy-MM-dd HH:mm:ss',
          ).format(HealthAnalysisService.displayTime(record)),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Future<void> Function()? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 36, color: SaydianColors.muted),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SaydianColors.muted, height: 1.5),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: action,
                child: Text(context.l10n.readAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _metricColor(HealthMetric metric) => switch (metric) {
  HealthMetric.bloodPressure => SaydianColors.orange,
  HealthMetric.bloodGlucose => SaydianColors.green,
  HealthMetric.bloodOxygen => SaydianColors.blue,
  HealthMetric.bodyTemperature => SaydianColors.cyan,
  HealthMetric.heartRate || HealthMetric.bloodComposition => SaydianColors.pink,
  HealthMetric.hrv || HealthMetric.sleep => const Color(0xFF8C7CF0),
  HealthMetric.ecg => const Color(0xFF6E8DF5),
  _ => SaydianColors.green,
};

String _fieldLabel(String key) => switch (key) {
  'value' => '趋势概况',
  'systolic' => '收缩压',
  'diastolic' => '舒张压',
  'pulse' => '脉搏',
  'meanHeartRate' || 'averageHeartRate' => '平均心率',
  'averageTimeInterval' || 'qt' => 'QT间期',
  'averageHRV' || 'hrv' => 'HRV',
  'BMI' || 'bmi' => 'BMI',
  'bodyFatRate' || 'bodyFatPercentage' => '体脂率',
  'fatMass' => '脂肪量',
  'fatFreeMass' => '去脂体重',
  'muscleRate' => '肌肉率',
  'muscleMass' => '肌肉量',
  'subcutaneousFat' => '皮下脂肪率',
  'bodyWaterRate' || 'bodyMoisture' => '体水分率',
  'waterMass' => '水分量',
  'skeletalMuscleRate' => '骨骼肌率',
  'boneMass' => '骨量',
  'proteinRate' => '蛋白质率',
  'proteinMass' => '蛋白质量',
  'basalMetabolicRate' || 'basalMetabolism' => '基础代谢',
  'uricAcid' => '尿酸',
  'totalCholesterol' => '总胆固醇',
  'triglycerides' => '甘油三酯',
  'highDensityLipoprotein' => '高密度脂蛋白',
  'lowDensityLipoprotein' => '低密度脂蛋白',
  _ => key,
};

String _unit(HealthMetric metric, HealthRecord record, String key) {
  if (metric == HealthMetric.bodyComposition) {
    if (const {
      'bodyFatRate',
      'bodyFatPercentage',
      'muscleRate',
      'subcutaneousFat',
      'bodyWaterRate',
      'bodyMoisture',
      'skeletalMuscleRate',
      'proteinRate',
    }.contains(key)) {
      return '%';
    }
    if (const {
      'fatMass',
      'fatFreeMass',
      'muscleMass',
      'waterMass',
      'boneMass',
      'proteinMass',
    }.contains(key)) {
      return 'kg';
    }
    if (key == 'basalMetabolicRate' || key == 'basalMetabolism') {
      return 'kcal/日';
    }
    return '';
  }
  if (metric == HealthMetric.bloodComposition) {
    return key == 'uricAcid' ? 'μmol/L' : 'mmol/L';
  }
  return record.unit.isEmpty ? metric.defaultUnit : record.unit;
}

String _format(double? value, String unit) =>
    value == null ? '--' : '${_number(value)} $unit'.trim();

String _number(num? value) {
  if (value == null || !value.isFinite) return '--';
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}
