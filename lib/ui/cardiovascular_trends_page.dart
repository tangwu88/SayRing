import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/ring_experience.dart';
import '../services/app_controller.dart';
import '../services/cardiovascular_trend_summary.dart';
import '../services/cardiovascular_model.dart';
import 'cardiovascular_insights.dart';
import 'cardiovascular_model_panel.dart';
import 'ring_share_page.dart';

class CardiovascularTrendsPage extends StatefulWidget {
  const CardiovascularTrendsPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<CardiovascularTrendsPage> createState() =>
      _CardiovascularTrendsPageState();
}

class _CardiovascularTrendsPageState extends State<CardiovascularTrendsPage> {
  late final owner = widget.controller.ringExperienceOwner;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(ringText(context, '心血管趋势', 'Cardiovascular trends')),
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (owner != c.ringExperienceOwner ||
              !c.canOpenCardiovascularTrends) {
            return const SizedBox.shrink();
          }
          final device = (c.connectedDevice ?? c.rememberedDevice)?.id;
          return _TrendBody(
            key: ValueKey((
              owner,
              device,
              c.isMetricAvailableInRelease(HealthMetric.bloodPressure),
              c.isMetricAvailableInRelease(HealthMetric.heartRate),
              c.isMetricAvailableInRelease(HealthMetric.sleep),
              c.isMetricAvailableInRelease(HealthMetric.steps),
            )),
            controller: c,
          );
        },
      ),
    );
  }
}

class _TrendBody extends StatefulWidget {
  const _TrendBody({required this.controller, super.key});
  final AppController controller;
  @override
  State<_TrendBody> createState() => _TrendBodyState();
}

typedef _Report = ({
  CardiovascularSummary summary,
  CardioInsightCopy? copy,
  Set<HealthMetric> failed,
});

class _TrendBodyState extends State<_TrendBody> {
  int days = 7;
  DateTime end = ringDate(DateTime.now());
  DateTime get start => ringAddDays(end, 1 - days);
  String? chosenSource;
  late Future<_Report> result = load();

  // Scoped to the current page, member and device. No model output is persisted locally.
  final modelResults = <String, Future<CardiovascularModelReply>>{};

  Future<CardiovascularModelReply> analyze(
    String key,
    CardiovascularModelInput input,
    String locale,
  ) {
    final existing = modelResults[key];
    if (existing != null) return existing;
    if (modelResults.length >= 8) modelResults.remove(modelResults.keys.first);
    late final Future<CardiovascularModelReply> future;
    future = widget.controller
        .analyzeCardiovascularTrends(input, locale)
        .catchError((Object error, StackTrace stack) {
          if (identical(modelResults[key], future)) modelResults.remove(key);
          Error.throwWithStackTrace(error, stack);
        });
    return modelResults[key] = future;
  }

  Future<_Report> load() async {
    final c = widget.controller,
        from = start,
        to = end,
        previous = ringAddDays(from, -days);
    final device = (c.connectedDevice ?? c.rememberedDevice)?.id;
    final failed = <HealthMetric>{};
    Future<List<T>> read<T>(
      HealthMetric metric,
      Future<List<T>> Function() query,
    ) async {
      try {
        return await query();
      } catch (_) {
        failed.add(metric);
        return <T>[];
      }
    }

    final (bp, records, copy) = await (
      read(
        HealthMetric.bloodPressure,
        () => c.loadPressureTrend(previous, ringAddDays(to, 1)),
      ),
      Future.wait([
        for (final m in CardiovascularSummary.contextMetrics)
          if (c.isMetricAvailableInRelease(m))
            read(m, () => c.loadCardioContext(m, previous, to)),
      ]),
      CardioInsightCopy.load(),
    ).wait;
    return (
      summary: CardiovascularSummary(
        start: from,
        end: to,
        previousStart: previous,
        readings: bp,
        contextRecords: records.expand((r) => r),
        preferredDeviceId: device,
        now: DateTime.now(),
      ),
      copy: copy,
      failed: failed,
    );
  }

  Future<void> refresh() async {
    setState(() {
      result = load();
    });
    await result;
  }

  Future<void> addReference() async {
    final owner = widget.controller.ringExperienceOwner;
    final row = await showDialog<PressureSample>(
      context: context,
      builder: (_) => _ReferenceEntry(end),
    );
    if (!mounted ||
        row == null ||
        owner != widget.controller.ringExperienceOwner) {
      return;
    }
    try {
      await widget.controller.savePressureReference(row);
      if (mounted) {
        setState(() {
          if (row.at.isBefore(start) || !row.at.isBefore(ringAddDays(end, 1))) {
            end = ringDate(row.at);
          }
          chosenSource = 'reference';
          result = load();
        });
      }
    } catch (error) {
      if (mounted) showRingError(context, error);
    }
  }

  Future<void> pickDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: end,
      firstDate: DateTime(today.year - 10),
      lastDate: today,
      helpText: ringText(context, '选择结束日期', 'Choose the end date'),
    );
    if (date != null && mounted) {
      setState(() {
        end = date;
        result = load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: refresh,
      child: FutureBuilder(
        future: result,
        builder: (c, s) {
          final data = s.connectionState == ConnectionState.done
              ? s.data
              : null;
          final report = data?.summary;
          final sources = report?.sources ?? const <String>[];
          final source = sources.contains(chosenSource)
              ? chosenSource
              : sources.firstOrNull;
          final rows = report?.pressure[source] ?? const <PressureSample>[];
          final daily = pressureDays(rows);
          final current = daily.where((r) => !r.date.isBefore(start)).toList();
          final contextSeries =
              report?.contextFor(source) ?? const <CardioContextSeries>[];
          String sourceName(String id) {
            if (id == 'reference') {
              return ringText(c, '上臂血压计', 'Upper-arm monitor');
            }
            final number =
                sources.where((s) => s != 'reference').toList().indexOf(id) + 1;
            final label = report!.pressure[id]!.last.label;
            if (label.isEmpty) {
              return ringText(c, '穿戴设备 $number', 'Wearable $number');
            }
            final shared =
                sources
                    .where(
                      (s) =>
                          s != 'reference' &&
                          report.pressure[s]!.last.label == label,
                    )
                    .length >
                1;
            return shared ? '$label · $number' : label;
          }

          final pressureFailed =
              data?.failed.contains(HealthMetric.bloodPressure) == true;
          final insights = report == null || data?.copy == null
              ? const <String>[]
              : cardioInsights(
                  c,
                  data!.copy!,
                  report,
                  daily,
                  contextSeries,
                  pressureReadFailed: pressureFailed,
                );
          final language = Localizations.localeOf(c).languageCode == 'zh'
              ? 'zh-Hans'
              : 'en';
          final input = report == null || pressureFailed
              ? null
              : CardiovascularModelInput.from(report, source);
          final modelKey = input == null
              ? ''
              : jsonEncode([
                  source,
                  start.toIso8601String(),
                  end.toIso8601String(),
                  language,
                  widget.controller.canAnalyzeCardiovascularTrends,
                  input.encodedEvidence,
                ]);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final n in [7, 30])
                    ChoiceChip(
                      key: ValueKey('pressure-period-$n'),
                      label: Text(ringText(c, '近 $n 天', '$n days')),
                      selected: days == n,
                      onSelected: (_) {
                        if (days != n) {
                          setState(() {
                            days = n;
                            result = load();
                          });
                        }
                      },
                    ),
                  TextButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      start.year == end.year && end.year == DateTime.now().year
                          ? '${l.formatShortMonthDay(start)} – ${l.formatShortMonthDay(end)}'
                          : '${l.formatShortDate(start)} – ${l.formatShortDate(end)}',
                    ),
                  ),
                ],
              ),
              if (s.connectionState != ConnectionState.done)
                const Center(child: CircularProgressIndicator())
              else if (s.hasError)
                TextButton(
                  onPressed: refresh,
                  child: Text(
                    ringText(c, '读取失败，点此重试', 'Could not load. Tap to retry.'),
                  ),
                )
              else if (report != null) ...[
                if (sources.length > 1)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final id in sources)
                        ChoiceChip(
                          label: Text(sourceName(id)),
                          selected: id == source,
                          onSelected: (_) => setState(() => chosenSource = id),
                        ),
                    ],
                  ),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ringText(c, '最近一次血压', 'Latest blood pressure'),
                        style: Theme.of(c).textTheme.titleMedium,
                      ),
                      if (rows.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 28,
                          runSpacing: 8,
                          children: [
                            _Reading(
                              label: ringText(c, '收缩压（高压）', 'Systolic'),
                              value: rows.last.systolic,
                              color: _upper,
                            ),
                            _Reading(
                              label: ringText(c, '舒张压（低压）', 'Diastolic'),
                              value: rows.last.diastolic,
                              color: _lower,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${sourceName(source!)} · ${l.formatShortDate(rows.last.at)} ${ringClockText(rows.last.at)}',
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          pressureFailed
                              ? ringText(
                                  c,
                                  '暂时读不到血压记录',
                                  'Blood pressure readings could not be loaded',
                                )
                              : ringText(
                                  c,
                                  '这段时间还没有血压记录',
                                  'No blood pressure readings in this period',
                                ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('record-pressure-reference'),
                        onPressed: addReference,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(ringText(c, '记上臂血压', 'Add a cuff reading')),
                      ),
                    ],
                  ),
                ),
                if (input != null)
                  CardiovascularModelPanel(
                    key: ValueKey(modelKey),
                    analyze: widget.controller.canAnalyzeCardiovascularTrends
                        ? () => analyze(modelKey, input, language)
                        : null,
                  ),
                if (data!.copy == null &&
                    (daily.isNotEmpty || contextSeries.isNotEmpty))
                  TextButton(
                    onPressed: refresh,
                    child: Text(
                      ringText(
                        c,
                        '数据摘要暂时无法加载，重试',
                        'Reading summary could not load. Retry',
                      ),
                    ),
                  ),
                if (insights.isNotEmpty)
                  _Panel(
                    tint: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ringText(c, '数据摘要', 'Reading summary'),
                          style: Theme.of(c).textTheme.titleMedium,
                        ),
                        for (final note in insights.take(2))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(note),
                          ),
                        if (insights.length > 2)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              ringText(c, '更多同期观察', 'More observations'),
                            ),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              for (final note in insights.skip(2))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(note),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                if (daily.isNotEmpty || contextSeries.isNotEmpty)
                  _Evidence(
                    key: ValueKey((source, start, end)),
                    report: report,
                    days: daily,
                    series: contextSeries,
                    pressureName: source == null ? '' : sourceName(source),
                    rows: rows,
                    controller: widget.controller,
                  ),
                if (current.isNotEmpty)
                  _PressureChart(current: current, start: start, end: end),
                if (contextSeries.isNotEmpty)
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ringText(c, '同期健康数据', 'Health data this period'),
                          style: Theme.of(c).textTheme.titleMedium,
                        ),
                        for (final item in contextSeries) ...[
                          const Divider(height: 20),
                          _ContextRow(item: item, start: start, end: end),
                        ],
                      ],
                    ),
                  ),
                if (data.failed.isNotEmpty)
                  TextButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      ringText(
                        c,
                        '部分记录读取失败，重试',
                        'Some records could not load. Retry',
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

const _upper = Color(0xff245c49), _lower = Color(0xff4764a7);

class _Reading extends StatelessWidget {
  const _Reading({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final num value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text.rich(
        TextSpan(
          text: cardioNumber(value.toDouble()),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
          children: [
            TextSpan(
              text: ' mmHg',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.tint = false});
  final Widget child;
  final bool tint;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 12),
    color: tint
        ? Color.alphaBlend(
            Theme.of(context).colorScheme.primary.withValues(alpha: .055),
            Theme.of(context).colorScheme.surface,
          )
        : null,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.item,
    required this.start,
    required this.end,
  });
  final CardioContextSeries item;
  final DateTime start, end;
  @override
  Widget build(BuildContext c) {
    final values = item.period(start, end).values;
    final count = values.length;
    final value = cardioValue(c, item.metric, cardioMean(values));
    final days = ringText(
      c,
      '$count 天有记录',
      count == 1 ? '1 recorded day' : '$count recorded days',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              ringText(
                c,
                '日均${cardioMetric(c, item.metric)}',
                'Average ${cardioMetric(c, item.metric).toLowerCase()}',
              ),
            ),
            Text(value, style: Theme.of(c).textTheme.titleMedium),
          ],
        ),
        Text(
          [if (item.model.isNotEmpty) item.model, days].join(' · '),
          style: Theme.of(c).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PressureChart extends StatelessWidget {
  const _PressureChart({
    required this.current,
    required this.start,
    required this.end,
  });
  final List<PressureDay> current;
  final DateTime start, end;

  int offset(DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

  List<FlSpot> points(double Function(PressureDay) value) {
    final spots = <FlSpot>[];
    var prior = -1;
    for (final row in current) {
      final day = offset(row.date);
      if (prior >= 0 && day > prior + 1) spots.add(FlSpot.nullSpot);
      spots.add(FlSpot(day.toDouble(), value(row)));
      prior = day;
    }
    return spots;
  }

  @override
  Widget build(BuildContext c) {
    final colors = Theme.of(c).colorScheme;
    final low =
        ((current.map((r) => r.diastolic).reduce((a, b) => a < b ? a : b) - 2) /
                10)
            .floor() *
        10.0;
    final high =
        ((current.map((r) => r.systolic).reduce((a, b) => a > b ? a : b) + 2) /
                10)
            .ceil() *
        10.0;
    final interval = (((high - low) / 3) / 10).ceil() * 10.0;
    final l = MaterialLocalizations.of(c);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ringText(c, '每日平均血压', 'Daily average blood pressure'),
            style: Theme.of(c).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 12,
            runSpacing: 3,
            children: [
              Text(
                ringText(c, '● 收缩压', '● Systolic'),
                style: const TextStyle(color: _upper),
              ),
              Text(
                ringText(c, '● 舒张压', '● Diastolic'),
                style: const TextStyle(color: _lower),
              ),
              const Text('mmHg'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: Semantics(
              label: ringText(
                c,
                '每日血压曲线，数值见查看依据',
                'Daily blood pressure chart. Values are listed under View evidence.',
              ),
              child: LineChart(
                duration: Duration.zero,
                LineChartData(
                  minX: 0,
                  maxX: offset(end).toDouble(),
                  minY: low,
                  maxY: high,
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize:
                            8 + MediaQuery.textScalerOf(c).scale(12) * 2.4,
                        interval: interval,
                        getTitlesWidget: (value, _) => Text(
                          value.round().toString(),
                          style: Theme.of(c).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: colors.outlineVariant, strokeWidth: 1),
                  ),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    for (final upper in [true, false])
                      LineChartBarData(
                        spots: points((r) => upper ? r.systolic : r.diastolic),
                        color: upper ? _upper : _lower,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: true),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              Text(l.formatShortDate(start)),
              Text(l.formatShortDate(end)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Evidence extends StatelessWidget {
  const _Evidence({
    required this.report,
    required this.days,
    required this.series,
    required this.pressureName,
    required this.rows,
    required this.controller,
    super.key,
  });
  final CardiovascularSummary report;
  final List<PressureDay> days;
  final List<CardioContextSeries> series;
  final String pressureName;
  final List<PressureSample> rows;
  final AppController controller;

  @override
  Widget build(BuildContext c) {
    final owner = controller.ringExperienceOwner;
    final target =
        (controller.connectedDevice ?? controller.rememberedDevice)?.id;
    final l = MaterialLocalizations.of(c);
    final byDate = {for (final d in days) d.date: d};
    final dates = {
      ...byDate.keys,
      for (final item in series) ...item.values.keys,
    }.toList()..sort((a, b) => b.compareTo(a));
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        key: const Key('cardio-evidence'),
        title: Text(ringText(c, '查看依据', 'View evidence')),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Text(
            ringText(
              c,
              '同一天有两项记录才放在一起比较。两期各有至少 3 个记录日时，才比较两期变化。',
              'Readings are paired by day. Period comparisons need at least three recorded days in each period.',
            ),
          ),
          if (pressureName.isNotEmpty)
            Text(
              ringText(
                c,
                '血压来源 · $pressureName',
                'Blood pressure source · $pressureName',
              ),
            ),
          for (final item in series)
            Text(
              '${cardioMetric(c, item.metric)} · ${item.model.isNotEmpty ? item.model : ringText(c, "穿戴设备", "Wearable device")}',
            ),
          for (final current in [true, false]) ...[
            const Divider(),
            Text(
              '${current ? ringText(c, "本期", "This period") : ringText(c, "上期", "Previous period")} · '
              '${l.formatShortDate(current ? report.start : report.previousStart)} – '
              '${l.formatShortDate(current ? report.end : ringAddDays(report.start, -1))}',
              style: Theme.of(c).textTheme.titleSmall,
            ),
            if (!dates.any((d) => d.isBefore(report.start) != current))
              Text(ringText(c, '暂无记录', 'No records')),
            for (final date in dates.where(
              (d) => d.isBefore(report.start) != current,
            ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.formatCompactDate(date),
                      style: Theme.of(c).textTheme.labelMedium,
                    ),
                    Text(
                      [
                        if (byDate[date] case final day?)
                          '${cardioNumber(day.systolic)}/${cardioNumber(day.diastolic)} mmHg · ${ringText(c, "${day.count} 次", day.count == 1 ? "1 reading" : "${day.count} readings")}',
                        for (final item in series)
                          if (item.values[date] case final value?)
                            '${cardioMetric(c, item.metric)} ${cardioValue(c, item.metric, value)}',
                      ].join('  ·  '),
                    ),
                  ],
                ),
              ),
          ],
          if (rows.isNotEmpty)
            TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: c,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (sheet) => ListenableBuilder(
                  listenable: controller,
                  builder: (_, _) {
                    if (owner != controller.ringExperienceOwner ||
                        target !=
                            (controller.connectedDevice ??
                                    controller.rememberedDevice)
                                ?.id ||
                        (rows.first.source != 'reference' &&
                            !controller.isMetricAvailableInRelease(
                              HealthMetric.bloodPressure,
                            ))) {
                      return const SizedBox.shrink();
                    }
                    return FractionallySizedBox(
                      heightFactor: .75,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              pressureName,
                              style: Theme.of(sheet).textTheme.titleMedium,
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (_, i) {
                                final row = rows[rows.length - 1 - i];
                                return ListTile(
                                  title: Text(
                                    '${row.systolic}/${row.diastolic} mmHg',
                                  ),
                                  subtitle: Text(
                                    '${l.formatCompactDate(row.at)} · ${ringClockText(row.at)}',
                                  ),
                                  trailing:
                                      controller.ringSharingEnabled &&
                                          controller.isAuthenticated
                                      ? RingShareButton(
                                          controller: controller,
                                          compact: true,
                                          snapshot:
                                              RingSnapshot('health', row.at, {
                                                'systolic': row.systolic,
                                                'diastolic': row.diastolic,
                                                'measuredTime': ringClockText(
                                                  row.at,
                                                ),
                                              }),
                                        )
                                      : null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              child: Text(ringText(c, '逐条查看血压记录', 'View individual readings')),
            ),
        ],
      ),
    );
  }
}

class _ReferenceEntry extends StatefulWidget {
  const _ReferenceEntry(this.day);
  final DateTime day;
  @override
  State<_ReferenceEntry> createState() => _ReferenceEntryState();
}

class _ReferenceEntryState extends State<_ReferenceEntry> {
  final upper = TextEditingController();
  final lower = TextEditingController();
  late DateTime date = () {
    final now = DateTime.now(), day = widget.day;
    return DateTime(day.year, day.month, day.day, now.hour, now.minute);
  }();
  bool invalid = false;

  @override
  void dispose() {
    upper.dispose();
    lower.dispose();
    super.dispose();
  }

  Future<void> selectTime() async {
    final next = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(DateTime.now().year - 10),
      lastDate: DateTime.now(),
    );
    if (next == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
    );
    if (mounted && time != null) {
      setState(() {
        date = DateTime(
          next.year,
          next.month,
          next.day,
          time.hour,
          time.minute,
        );
        invalid = false;
      });
    }
  }

  void save() {
    final systolic = int.tryParse(upper.text.trim());
    final diastolic = int.tryParse(lower.text.trim());
    if (!PressureSample.validPair(systolic, diastolic) ||
        date.isAfter(DateTime.now())) {
      setState(() => invalid = true);
      return;
    }
    Navigator.pop(
      context,
      PressureSample(
        at: date,
        systolic: systolic!,
        diastolic: diastolic!,
        source: 'reference',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(ringText(context, '录入血压参考值', 'Add a reference reading')),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: upper,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: ringText(context, '收缩压 (mmHg)', 'Systolic (mmHg)'),
          ),
        ),
        TextField(
          controller: lower,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: ringText(context, '舒张压 (mmHg)', 'Diastolic (mmHg)'),
          ),
        ),
        TextButton.icon(
          onPressed: selectTime,
          icon: const Icon(Icons.schedule),
          label: Text(
            '${MaterialLocalizations.of(context).formatCompactDate(date)} ${ringClockText(date)}',
          ),
        ),
        if (invalid)
          Text(
            ringText(
              context,
              '请检查收缩压、舒张压和测量时间。',
              'Check the two readings and the measurement time.',
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        onPressed: save,
        child: Text(ringText(context, '保存到本机', 'Save on this phone')),
      ),
    ],
  );
}
