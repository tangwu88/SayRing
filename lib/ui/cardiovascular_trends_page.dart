import 'dart:convert';

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/ring_experience.dart';
import '../services/app_controller.dart';
import '../services/cardiovascular_trend_summary.dart';
import '../services/cardiovascular_model.dart';
import 'app_theme.dart';
import 'cardiovascular_charts.dart';
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
    final title = ringText(context, '心血管趋势', 'Cardiovascular trends');
    final style =
        AppBarTheme.of(context).titleTextStyle ??
        Theme.of(context).textTheme.titleLarge!;
    final leading = Navigator.canPop(context) ? kToolbarHeight : 0.0;
    final measure =
        TextPainter(
          text: TextSpan(text: title, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: (MediaQuery.sizeOf(context).width - leading - 32).clamp(
            1,
            double.infinity,
          ),
        );
    final headerHeight = (measure.height + 12).clamp(
      kToolbarHeight,
      double.infinity,
    );
    final titleLines = measure.computeLineMetrics().length;
    measure.dispose();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: headerHeight,
        title: Text(
          title,
          maxLines: titleLines,
          textScaler: MediaQuery.textScalerOf(context),
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
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

RingSnapshot _pressureSnapshot(PressureSample reading) =>
    RingSnapshot('health', reading.at, {
      'systolic': reading.systolic,
      'diastolic': reading.diastolic,
      'measuredTime': ringClockText(reading.at),
    });

class _TrendBodyState extends State<_TrendBody> {
  int days = 7;
  DateTime end = ringDate(DateTime.now());
  DateTime get start => ringAddDays(end, 1 - days);
  String? chosenSource;
  DateTime? selectedDay;
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
      selectedDay = null;
      result = load();
    });
    await result;
  }

  Future<void> addReference() => changeReference(null);

  Future<void> changeReference(
    PressureSample? original, {
    bool remove = false,
  }) async {
    final owner = widget.controller.ringExperienceOwner;
    PressureSample? row;
    if (remove) {
      if (original == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(
            ringText(dialog, '删除这条上臂血压？', 'Delete this cuff reading?'),
          ),
          content: Text(
            '${original.systolic}/${original.diastolic} mmHg · '
            '${MaterialLocalizations.of(dialog).formatCompactDate(original.at)} ${ringClockText(original.at)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(ringText(dialog, '删除', 'Delete')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      row = await showDialog<PressureSample>(
        context: context,
        builder: (_) => _ReferenceEntry(selectedDay ?? end, existing: original),
      );
      if (row == null) return;
    }
    if (!mounted || owner != widget.controller.ringExperienceOwner) return;
    try {
      if (original != null) {
        await widget.controller.replacePressureReference(original, row);
      } else if (row != null) {
        await widget.controller.savePressureReference(row);
      }
      if (mounted && owner == widget.controller.ringExperienceOwner) {
        setState(() {
          final savedDay = row == null ? null : ringDate(row.at);
          final showSavedDay =
              savedDay != null &&
              (selectedDay != null || original != null || savedDay != end);
          if (row != null &&
              (row.at.isBefore(start) ||
                  !row.at.isBefore(ringAddDays(end, 1)))) {
            end = ringDate(row.at);
          }
          chosenSource = 'reference';
          selectedDay = showSavedDay ? savedDay : null;
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
        selectedDay = null;
        result = load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          final current = {
            for (final r in daily)
              if (!r.date.isBefore(start)) r.date: r,
          };
          final dates = List.generate(days, (i) => ringAddDays(start, i));
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
          final selected = source != null ? selectedDay : null;
          final shareReading = selected == null
              ? rows.lastOrNull
              : rows.where((row) => ringDate(row.at) == selected).lastOrNull;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              24 + MediaQuery.paddingOf(c).bottom,
            ),
            children: [
              _PeriodBar(
                days: days,
                start: start,
                end: end,
                pickDate: pickDate,
                onChange: (n) {
                  if (days == n) return;
                  setState(() {
                    days = n;
                    selectedDay = null;
                    result = load();
                  });
                },
              ),
              if (s.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (s.hasError)
                TextButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    ringText(c, '读取失败，点此重试', 'Could not load. Tap to retry.'),
                  ),
                )
              else if (report != null) ...[
                if (source != null && current.isNotEmpty)
                  CardioPressureOverview(
                    latest: rows.last,
                    source: _PressureSource(
                      source: source,
                      sources: sources,
                      name: sourceName,
                      onChanged: (id) => setState(() {
                        chosenSource = id;
                        selectedDay = null;
                      }),
                    ),
                    dates: dates,
                    daily: current,
                    selected: selected,
                    onSelect: (date) => setState(() => selectedDay = date),
                    onAdd: addReference,
                    shareAction:
                        shareReading == null ||
                            !widget.controller.ringSharingEnabled ||
                            !widget.controller.isAuthenticated
                        ? null
                        : _PressureShareButton(
                            controller: widget.controller,
                            reading: shareReading,
                          ),
                  )
                else
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 22,
                      ),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: SaydianColors.techBlueSoft,
                            child: Icon(
                              Icons.monitor_heart_outlined,
                              color: SaydianColors.techBlue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            pressureFailed
                                ? ringText(
                                    c,
                                    '暂时读不到血压记录',
                                    'Couldn’t load blood pressure',
                                  )
                                : ringText(
                                    c,
                                    '这段时间还没有血压记录',
                                    'No pressure readings this period',
                                  ),
                            textAlign: TextAlign.center,
                            style: Theme.of(c).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const Key('record-pressure-reference'),
                            onPressed: addReference,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              ringText(c, '记上臂血压', 'Add cuff reading'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (input != null)
                  CardiovascularModelPanel(
                    key: ValueKey(modelKey),
                    needsMoreDays: !input.hasTrend,
                    analyze:
                        input.hasTrend &&
                            widget.controller.canAnalyzeCardiovascularTrends
                        ? () => analyze(modelKey, input, language)
                        : null,
                  ),
                if (contextSeries.isNotEmpty)
                  CardioContextCard(
                    series: contextSeries,
                    dates: dates,
                    selected: selected,
                  ),
                if (daily.isNotEmpty || contextSeries.isNotEmpty)
                  _Evidence(
                    key: ValueKey((source, start, end)),
                    report: report,
                    days: daily,
                    series: contextSeries,
                    insights: insights,
                    pressureName: source == null ? '' : sourceName(source),
                    rows: rows,
                    controller: widget.controller,
                    changeReference: changeReference,
                  ),
                if (data!.failed.isNotEmpty ||
                    (data.copy == null &&
                        (daily.isNotEmpty || contextSeries.isNotEmpty)))
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

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.days,
    required this.start,
    required this.end,
    required this.pickDate,
    required this.onChange,
  });
  final int days;
  final DateTime start, end;
  final VoidCallback pickDate;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext c) {
    final l = MaterialLocalizations.of(c);
    final showYear = start.year != end.year || end.year != DateTime.now().year;
    String format(DateTime d) =>
        showYear ? l.formatShortDate(d) : l.formatShortMonthDay(d);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: SaydianColors.techBlueSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Wrap(
              children: [
                for (final n in [7, 30])
                  Semantics(
                    key: ValueKey('pressure-period-$n'),
                    selected: days == n,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: days == n
                            ? SaydianColors.techBlue
                            : Colors.transparent,
                        foregroundColor: days == n
                            ? Colors.white
                            : SaydianColors.techBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(48, 40),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      onPressed: () => onChange(n),
                      child: Text(ringText(c, '$n 天', '$n days')),
                    ),
                  ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          key: const Key('cardio-date-range'),
          onPressed: pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text('${format(start)} – ${format(end)}'),
        ),
      ],
    );
  }
}

class _PressureSource extends StatelessWidget {
  const _PressureSource({
    required this.source,
    required this.sources,
    required this.name,
    required this.onChanged,
  });
  final String source;
  final List<String> sources;
  final String Function(String) name;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext c) {
    final multiple = sources.length > 1;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          source == 'reference' ? Icons.edit_note : Icons.watch_outlined,
          size: 16,
          color: SaydianColors.techBlue,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            name(source),
            style: Theme.of(
              c,
            ).textTheme.labelMedium?.copyWith(color: SaydianColors.techBlue),
          ),
        ),
        if (multiple)
          const Icon(
            Icons.expand_more,
            size: 18,
            color: SaydianColors.techBlue,
          ),
      ],
    );
    if (!multiple) return label;
    return PopupMenuButton<String>(
      key: const Key('cardio-source-menu'),
      tooltip: ringText(c, '切换血压来源', 'Change blood pressure source'),
      initialValue: source,
      onSelected: (id) {
        if (id != source) onChanged(id);
      },
      itemBuilder: (_) => [
        for (final id in sources)
          CheckedPopupMenuItem(
            value: id,
            checked: id == source,
            child: Text(name(id)),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: label,
      ),
    );
  }
}

class _PressureShareButton extends StatelessWidget {
  const _PressureShareButton({required this.controller, required this.reading});
  final AppController controller;
  final PressureSample reading;

  @override
  Widget build(BuildContext context) => RingShareButton(
    controller: controller,
    compact: true,
    snapshot: _pressureSnapshot(reading),
    canRead: () =>
        reading.source == 'reference' ||
        controller.isMetricAvailableInRelease(HealthMetric.bloodPressure),
    loadDate: (date) async {
      final readings = await controller.loadPressureTrend(
        date,
        ringAddDays(date, 1),
      );
      return [
        for (final value in readings)
          if (value.source == reading.source && ringDate(value.at) == date)
            _pressureSnapshot(value),
      ];
    },
  );
}

class _Evidence extends StatelessWidget {
  const _Evidence({
    required this.report,
    required this.days,
    required this.series,
    required this.insights,
    required this.pressureName,
    required this.rows,
    required this.controller,
    required this.changeReference,
    super.key,
  });
  final CardiovascularSummary report;
  final List<PressureDay> days;
  final List<CardioContextSeries> series;
  final List<String> insights;
  final String pressureName;
  final List<PressureSample> rows;
  final AppController controller;
  final Future<void> Function(PressureSample?, {bool remove}) changeReference;

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
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(ringText(c, '查看依据', 'View evidence')),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (rows.isNotEmpty)
            TextButton(
              onPressed: () async {
                final action =
                    await showModalBottomSheet<
                      ({PressureSample row, bool remove})
                    >(
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
                                    style: Theme.of(
                                      sheet,
                                    ).textTheme.titleMedium,
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
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _PressureShareButton(
                                              controller: controller,
                                              reading: row,
                                            ),
                                            if (row.source == 'reference')
                                              PopupMenuButton<bool>(
                                                tooltip: ringText(
                                                  sheet,
                                                  '管理参考值',
                                                  'Manage reference reading',
                                                ),
                                                onSelected: (remove) =>
                                                    Navigator.pop(sheet, (
                                                      row: row,
                                                      remove: remove,
                                                    )),
                                                itemBuilder: (_) => [
                                                  PopupMenuItem(
                                                    value: false,
                                                    child: Text(
                                                      ringText(
                                                        sheet,
                                                        '修改',
                                                        'Edit',
                                                      ),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: true,
                                                    child: Text(
                                                      ringText(
                                                        sheet,
                                                        '删除',
                                                        'Delete',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                if (action != null &&
                    c.mounted &&
                    owner == controller.ringExperienceOwner) {
                  await changeReference(action.row, remove: action.remove);
                }
              },
              child: Text(ringText(c, '逐条查看血压记录', 'View individual readings')),
            ),
          Text(
            ringText(
              c,
              '按同日记录配对。两期各满 3 个记录日可比较均值。',
              'Readings are paired by day. Comparing averages takes three recorded days in each period.',
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
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final note in insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(note),
              ),
          ],
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
        ],
      ),
    );
  }
}

class _ReferenceEntry extends StatefulWidget {
  const _ReferenceEntry(this.day, {this.existing});
  final DateTime day;
  final PressureSample? existing;
  @override
  State<_ReferenceEntry> createState() => _ReferenceEntryState();
}

class _ReferenceEntryState extends State<_ReferenceEntry> {
  late final upper = TextEditingController(
    text: widget.existing == null
        ? ''
        : cardioNumber(widget.existing!.systolic.toDouble()),
  );
  late final lower = TextEditingController(
    text: widget.existing == null
        ? ''
        : cardioNumber(widget.existing!.diastolic.toDouble()),
  );
  late DateTime date = () {
    if (widget.existing case final sample?) return sample.at.toLocal();
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
    final systolic = num.tryParse(upper.text.trim());
    final diastolic = num.tryParse(lower.text.trim());
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
    title: Text(
      widget.existing == null
          ? ringText(context, '录入血压参考值', 'Add a reference reading')
          : ringText(context, '修改血压参考值', 'Edit reference reading'),
    ),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: upper,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: ringText(context, '收缩压 (mmHg)', 'Systolic (mmHg)'),
          ),
        ),
        TextField(
          controller: lower,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
