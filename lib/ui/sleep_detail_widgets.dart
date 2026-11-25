import '../domain/ring_experience.dart';
import 'ring_share_page.dart';
import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import '../domain/sleep_timeline.dart';
import '../domain/sleep_report_view.dart';
import '../services/app_controller.dart';
import '../services/sleep_health_projection.dart';
import 'app_theme.dart';
import 'sleep_report_charts.dart';
import 'sleep_ai_report_page.dart';
import 'health_ui_owner.dart';

bool sleepSyncUnavailable(AppController controller) {
  final capabilities = controller.capabilities;
  // 总历史通道可用不代表这枚戒指已确认睡眠回包。旧协议若未列举指标，
  // 仍采用原有提示；明确缺少睡眠时，只引导用户按日期查看。
  return controller.connectedDevice == null ||
      controller.deviceCapabilityState != DeviceCapabilityState.ready ||
      capabilities == null ||
      capabilities.supportsHistorySync == false ||
      capabilities.historyMetrics?.contains(HealthMetric.sleep) == false;
}

String sleepMinutesLabel(double minutes) {
  final seconds = (minutes * 60).round();
  if (seconds < 60) return uiCopy(null, "{p0}秒", parameters: [seconds]);
  final wholeMinutes = seconds ~/ 60;
  final label = wholeMinutes < 60
      ? uiCopy(null, "{p0}分钟", parameters: [wholeMinutes])
      : uiCopy(
          null,
          "{p0}小时{p1}分",
          parameters: [wholeMinutes ~/ 60, wholeMinutes % 60],
        );
  return seconds % 60 == 0
      ? label
      : uiCopy(null, "{p0}{p1}秒", parameters: [label, seconds % 60]);
}

String _stageLabel(SleepStage stage) => switch (stage) {
  SleepStage.awake => uiCopy(null, "清醒"),
  SleepStage.light => uiCopy(null, "浅睡"),
  SleepStage.deep => uiCopy(null, "深睡"),
  SleepStage.rem => uiCopy(null, "快速眼动"),
  SleepStage.unknown => uiCopy(null, "暂未分类"),
  SleepStage.notWorn => uiCopy(null, "未佩戴"),
};

Color _stageColor(SleepStage stage) => switch (stage) {
  SleepStage.awake => const Color(0xFFAF682E),
  SleepStage.light => const Color(0xFF777AD0),
  SleepStage.deep => const Color(0xFF4F3992),
  SleepStage.rem => const Color(0xFF27877F),
  SleepStage.unknown => const Color(0xFF98A4B5),
  SleepStage.notWorn => const Color(0xFF637482),
};

/// Reads sleep-only history from the full encrypted stores, not the home feed.
class SleepDayDetails extends StatefulWidget {
  const SleepDayDetails({
    required this.controller,
    required this.onOpenTrend,
    this.initialDate,
    super.key,
  });

  final AppController controller;
  final ValueChanged<DateTime> onOpenTrend;
  final DateTime? initialDate;

  @override
  State<SleepDayDetails> createState() => _SleepDayDetailsState();
}

class _SleepDayDetailsState extends State<SleepDayDetails> {
  final _scroll = ScrollController();
  late DateTime _date;
  late (bool, String?, String?) _account;
  List<HealthRecord> _records = const [];
  Map<String, List<SleepMetricSeries>> _measurements = const {};
  SleepReportPeriod _period = SleepReportPeriod.day;
  bool _loading = true, _chooseLatest = true, _failed = false;
  int _request = 0;
  Timer? _refresh;

  bool get _zh => Localizations.localeOf(context).languageCode == 'zh';
  String tr(String zh, String en) => _zh ? zh : en;
  DateFormat fmt(String zh, String en) => DateFormat(tr(zh, en));
  MaterialLocalizations get _locale => MaterialLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _date = sleepCalendarDay(widget.initialDate ?? DateTime.now());
    _chooseLatest = widget.initialDate == null;
    _account = healthUiOwnerKey(widget.controller);
    widget.controller.addListener(_onChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _request++;
    _refresh?.cancel();
    widget.controller.removeListener(_onChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    final account = healthUiOwnerKey(widget.controller);
    if (_account != account) {
      _request++;
      _account = account;
      _chooseLatest = true;
      setState(() {
        _records = const [];
        _measurements = const {};
        _date = sleepCalendarDay(DateTime.now());
        _loading = true;
      });
    }
    _refresh?.cancel();
    _refresh = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    final request = ++_request, account = _account;
    var date = _date;
    bool current() =>
        mounted &&
        request == _request &&
        account == healthUiOwnerKey(widget.controller);
    try {
      if (_chooseLatest) {
        final latest = await widget.controller.loadLatestSleepDay();
        if (!current()) return;
        if (latest != null) date = DateTime.parse(sleepRecordSdkDate(latest));
      }
      final range = sleepPeriodRange(date, _period);
      final records = await widget.controller.loadSleepDays(
        start: range.start,
        end: range.end,
      );
      if (!current()) return;
      final selected = date;
      final sameRecords =
          _date == selected &&
          _records.length == records.length &&
          List.generate(records.length, (i) => i).every(
            (i) =>
                _records[i].id == records[i].id &&
                _records[i].sleepTimeline?.contentHash ==
                    records[i].sleepTimeline?.contentHash,
          );
      setState(() {
        _date = selected;
        _records = records;
        if (!sameRecords) _measurements = const {};
        _failed = false;
        _loading = false;
      });
      final windows = records
          .expand(sleepObservationWindows)
          .where((w) => w.kind != SleepSessionKind.nap)
          .toList();
      if (windows.isEmpty) return;
      final samples = await widget.controller.loadSleepReportReadings(records);
      if (!current()) return;
      final groups = {
        for (final r in records) r.id: sleepMetricSeries(r, samples),
      };
      setState(() => _measurements = groups);
    } catch (_) {
      if (!current()) return;
      if (!_loading && _records.isNotEmpty) {
        return; // Optional overnight metrics must not suppress sleep.
      }
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _selectDate(DateTime date, {SleepReportPeriod? period}) {
    _chooseLatest = false;
    setState(() {
      _date = sleepCalendarDay(date);
      _period = period ?? _period;
      _records = const [];
      _measurements = const {};
      _failed = false;
      _loading = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_load());
  }

  void _selectPeriod(SleepReportPeriod period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _records = const [];
      _measurements = const {};
      _loading = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_load());
  }

  void _move(int step) {
    final candidate = switch (_period) {
      SleepReportPeriod.day => sleepCalendarAdd(_date, step),
      SleepReportPeriod.week => sleepCalendarAdd(_date, step * 7),
      SleepReportPeriod.month => DateTime(_date.year, _date.month + step),
    };
    final today = sleepCalendarDay(DateTime.now());
    _selectDate(candidate.isAfter(today) ? today : candidate);
  }

  Future<void> _pickDate() async {
    final account = _account;
    final today = sleepCalendarDay(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: _date.isAfter(today) ? _date : today,
    );
    if (date != null && mounted && account == _account) _selectDate(date);
  }

  double? _duration(HealthRecord r) {
    final t = r.sleepTimeline;
    final minutes = t?.hasSegments == true
        ? t!.asleepMinutes
        : (r.values['value']?.toDouble() ?? 0) * 60;
    return minutes > 0 && minutes.isFinite && minutes <= 1440 ? minutes : null;
  }

  RingSnapshot? _shareSnapshot(
    DateTime date,
    SleepReportPeriod period,
    List<HealthRecord> records,
  ) {
    if (period != SleepReportPeriod.day) {
      final range = sleepPeriodRange(date, period);
      final minutes = records.map(_duration).nonNulls.toList();
      if (minutes.isEmpty) return null;
      final today = ringDate(DateTime.now());
      return RingSnapshot('sleep', range.start, {
        'rangeEnd': ringDateText(range.end.isAfter(today) ? today : range.end),
        'sleepAverageMinutes':
            (minutes.reduce((sum, value) => sum + value) / minutes.length)
                .round(),
        'recordDays': minutes.length,
      });
    }
    final row = records
        .where((record) => sleepRecordSdkDate(record) == ringDateText(date))
        .firstOrNull;
    final duration = row == null ? null : _duration(row);
    if (row == null || duration == null) return null;
    final segments = row.sleepTimeline?.sessions
        .expand((session) => session.segments)
        .toList();
    return RingSnapshot('sleep', date, {
      'sleepMinutes': duration.round(),
      for (final (key, stage) in [
        ('deepMinutes', SleepStage.deep),
        ('lightMinutes', SleepStage.light),
        ('remMinutes', SleepStage.rem),
        ('awakeMinutes', SleepStage.awake),
      ])
        if (segments?.any((segment) => segment.stage == stage) == true)
          key:
              (segments!
                          .where((segment) => segment.stage == stage)
                          .fold<int>(
                            0,
                            (sum, segment) =>
                                sum +
                                segment.endAt
                                    .difference(segment.startAt)
                                    .inSeconds,
                          ) /
                      60)
                  .round(),
    });
  }

  Widget _shareSleepReport() {
    final controller = widget.controller;
    final period = _period;
    return RingShareButton(
      controller: controller,
      snapshot: _shareSnapshot(_date, period, _records),
      canRead: () => controller.isMetricAvailableInRelease(HealthMetric.sleep),
      loadDate: (date) async {
        final range = sleepPeriodRange(date, period);
        final rows = await controller.loadSleepDays(
          start: range.start,
          end: range.end,
        );
        return [?_shareSnapshot(date, period, rows)];
      },
    );
  }

  num? _deviceScore(HealthRecord r) {
    if (widget.controller.isWellnessOnly ||
        r.deviceId.trim().isEmpty ||
        r.source != MeasurementSource.wearable ||
        r.origin != MeasurementOrigin.watchHistory) {
      return null;
    }
    final score = r.sleepTimeline?.summaryValues['score'] ?? r.values['score'];
    return score != null && score.isFinite && score > 0 && score <= 100
        ? score
        : null;
  }

  String _shortDate(DateTime date) => fmt('M月d日', 'MMM d').format(date);
  String _clock(DateTime date) => _locale.formatTimeOfDay(
    TimeOfDay.fromDateTime(date),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  String _clockWithDate(DateTime date, DateTime anchor) =>
      DateUtils.isSameDay(date, anchor)
      ? _clock(date)
      : '${_shortDate(date)} ${_clock(date)}';
  String _number(double value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  String _unit(SleepMetricSeries value) => switch (value.metric) {
    HealthMetric.heartRate => tr('次/分', 'bpm'),
    HealthMetric.hrv => tr('毫秒', 'ms'),
    _ => value.unit,
  };
  String _minuteClock(double raw) {
    final minutes = raw.round() % 1440;
    return _locale.formatTimeOfDay(
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  String _metricLabel(SleepMetricSeries value) => switch (value.metric) {
    HealthMetric.heartRate => tr('睡眠心率', 'Heart rate during sleep'),
    HealthMetric.hrv =>
      '${tr('睡眠 HRV', 'HRV during sleep')} · ${value.algorithm.toUpperCase()}',
    _ => tr('睡眠血氧', 'Blood oxygen during sleep'),
  };
  Color _metricColor(HealthMetric value) => switch (value) {
    HealthMetric.heartRate => const Color(0xff6953ae),
    HealthMetric.hrv => const Color(0xff3f60bc),
    _ => const Color(0xff217f79),
  };

  @override
  Widget build(BuildContext context) {
    final range = sleepPeriodRange(_date, _period);
    final status = widget
        .controller
        .sleepReadStatuses[fmt('yyyy-MM-dd', 'yyyy-MM-dd').format(_date)];
    final rows = _records.toList()
      ..sort((a, b) {
        final complete =
            (b.sleepTimeline?.hasSegments == true ? 1 : 0) -
            (a.sleepTimeline?.hasSegments == true ? 1 : 0);
        return complete != 0 ? complete : b.measuredAt.compareTo(a.measuredAt);
      });
    final record = rows.firstOrNull;
    final failed =
        _failed || (_period == SleepReportPeriod.day && status == 'failed');
    final syncUnavailable = sleepSyncUnavailable(widget.controller);
    final today = sleepCalendarDay(DateTime.now());
    final dateLabel = switch (_period) {
      SleepReportPeriod.day => fmt('yyyy年M月d日', 'MMM d, yyyy').format(_date),
      SleepReportPeriod.week =>
        '${_shortDate(range.start)} – ${_shortDate(range.end)}',
      SleepReportPeriod.month => fmt('yyyy年M月', 'MMMM yyyy').format(_date),
    };
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _periodTabs(),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                key: const Key('sleep-previous-day'),
                tooltip: tr('上一段日期', 'Previous period'),
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('sleep-select-date'),
                  onPressed: _pickDate,
                  child: Text(dateLabel, textAlign: TextAlign.center),
                ),
              ),
              IconButton(
                key: const Key('sleep-next-day'),
                tooltip: tr('下一段日期', 'Next period'),
                onPressed: range.end.isBefore(today) ? () => _move(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  _chooseLatest
                      ? uiCopy(context, "最近一次睡眠")
                      : uiCopy(context, "按日期查看"),
                  key: const Key('sleep-selection-mode'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (!_chooseLatest)
                TextButton(
                  key: const Key('sleep-latest-day'),
                  onPressed: () {
                    setState(() {
                      _chooseLatest = true;
                      _period = SleepReportPeriod.day;
                      _loading = true;
                      _records = const [];
                      _measurements = const {};
                    });
                    unawaited(_load());
                  },
                  child: Text(uiCopy(context, "最近一次")),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (failed)
              _SleepNotice(
                message: record == null
                    ? (syncUnavailable
                          ? uiCopy(context, "暂时无法查看睡眠记录，请稍后重试")
                          : uiCopy(context, "睡眠记录暂时无法更新，请连接戒指后重试"))
                    : uiCopy(context, "睡眠记录暂未更新，以下为已保存的记录"),
                icon: Icons.error_outline_rounded,
              ),
            if (record == null)
              _SleepNotice(
                message: failed
                    ? uiCopy(context, "你可以稍后下拉重试，或选择其他日期查看")
                    : _period != SleepReportPeriod.day
                    ? tr('这一段暂无睡眠记录', 'No sleep recorded for this period')
                    : syncUnavailable
                    ? uiCopy(context, "这一天暂无睡眠记录，你可以选择其他日期查看")
                    : status == 'noData'
                    ? uiCopy(context, "这一天暂无睡眠记录，佩戴戒指入睡后，可在次日更新查看")
                    : uiCopy(context, "这一天暂无睡眠记录，佩戴戒指入睡后，请连接更新"),
                icon: Icons.bedtime_outlined,
              )
            else if (_period == SleepReportPeriod.day)
              ..._daily(record, rows)
            else
              ..._range(range, rows),
          ],
          if (!_loading && _records.isNotEmpty) _shareSleepReport(),
          const SizedBox(height: 10),
          Card(
            child: ExpansionTile(
              key: const Key('sleep-reference-details'),
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(uiCopy(context, "睡眠说明")),
              subtitle: Text(uiCopy(context, "戒指估算 · 日常作息参考")),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              children: [
                Text(
                  tr(
                    '总时长含夜间睡眠和小睡，不含清醒和未分类时段。生成报告前会请你同意上传汇总。',
                    'Sleep time includes naps and excludes awake or unclassified periods. You choose whether to upload a summary for analysis.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('sleep-open-trend'),
            onPressed: () => widget.onOpenTrend(_date),
            icon: const Icon(Icons.show_chart_rounded),
            label: Text(uiCopy(context, "查看睡眠趋势与记录")),
          ),
        ],
      ),
    );
  }

  Widget _periodTabs() => Semantics(
    label: tr('报告范围', 'Report period'),
    child: Container(
      key: const Key('sleep-period-tabs'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xffede9f8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final period in SleepReportPeriod.values)
            Expanded(
              child: Semantics(
                selected: _period == period,
                button: true,
                child: TextButton(
                  key: ValueKey('sleep-period-${period.name}'),
                  style: TextButton.styleFrom(
                    backgroundColor: _period == period
                        ? const Color(0xff65539e)
                        : Colors.transparent,
                    foregroundColor: _period == period
                        ? Colors.white
                        : const Color(0xff47396f),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _selectPeriod(period),
                  child: Text(switch (period) {
                    SleepReportPeriod.day => tr('日', 'Day'),
                    SleepReportPeriod.week => tr('周', 'Week'),
                    SleepReportPeriod.month => tr('月', 'Month'),
                  }, textAlign: TextAlign.center),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  List<Widget> _daily(HealthRecord record, List<HealthRecord> rows) {
    final duration = _duration(record),
        timeline = record.sleepTimeline,
        main = mainSleepWindow(record);
    final score = _deviceScore(record);
    final efficiency =
        !widget.controller.isWellnessOnly &&
            record.source == MeasurementSource.wearable &&
            record.origin == MeasurementOrigin.watchHistory
        ? record.values['efficiency']
        : null;
    final otherWindows = sleepObservationWindows(
      record,
    ).where((w) => w.kind == SleepSessionKind.nap);
    return [
      _hero(
        uiCopy(context, "睡眠总时长"),
        duration == null ? '--' : sleepMinutesLabel(duration),
        details: [
          if (main != null) ...[
            '${tr('入睡', 'Asleep')} ${_clockWithDate(main.clock(main.start), _date)}',
            '${tr('醒来', 'Awake')} ${_clockWithDate(main.clock(main.end), _date)}',
          ],
        ],
      ),
      const SizedBox(height: 10),
      if (timeline?.hasSegments == true)
        SleepTimelineCard(timeline: timeline!)
      else ...[
        if (main == null && _recordedSleepStages(record).isEmpty)
          _SleepNotice(
            message: uiCopy(context, "仅有总时长，暂无分段"),
            icon: Icons.schedule_outlined,
          ),
        _SleepStageDistribution(record: record),
        if (otherWindows.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('小睡', 'Naps'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final nap in otherWindows)
                    Text(
                      '${_clock(nap.clock(nap.start))} – ${_clock(nap.clock(nap.end))}',
                    ),
                ],
              ),
            ),
          ),
      ],
      if (rows.length > 1)
        Card(
          child: ExpansionTile(
            title: Text(tr('其他睡眠记录', 'Other sleep records')),
            children: [
              for (final other in rows.skip(1))
                ListTile(
                  title: Text(switch (_duration(other)) {
                    final double minutes => sleepMinutesLabel(minutes),
                    null => tr('睡眠记录', 'Sleep record'),
                  }),
                  subtitle: switch (mainSleepWindow(other)) {
                    final SleepObservationWindow w => Text(
                      '${_clock(w.clock(w.start))} – ${_clock(w.clock(w.end))}',
                    ),
                    null => null,
                  },
                ),
            ],
          ),
        ),
      for (final series
          in _measurements[record.id] ?? const <SleepMetricSeries>[])
        _night(series),
      if (score != null) _score(score),
      if (efficiency != null &&
          efficiency.isFinite &&
          efficiency > 0 &&
          efficiency <= 100)
        Card(
          child: ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: Text(tr('睡眠效率', 'Sleep efficiency')),
            subtitle: Text('${_number(efficiency.toDouble())} %'),
          ),
        ),
      if (duration != null && widget.controller.sleepAiEnabled)
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: SleepAiReportCard(
              key: ValueKey(
                'daily-${record.id}-${record.sleepTimeline?.contentHash ?? record.values}',
              ),
              controller: widget.controller,
              record: record,
            ),
          ),
        ),
    ];
  }

  Widget _hero(String label, String value, {List<String> details = const []}) =>
      Card(
        key: const Key('sleep-report-overview'),
        color: const Color(0xfff0ebfa),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.bedtime_rounded, color: Color(0xff6853aa)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 34,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff28203e),
                ),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 15,
                  runSpacing: 4,
                  children: [
                    for (final detail in details)
                      Text(
                        detail,
                        style: const TextStyle(color: Color(0xff554a6a)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );

  Widget _score(num score) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            label: '${tr('设备睡眠评分', 'Device sleep score')} $score / 100',
            child: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 5,
                      backgroundColor: const Color(0xffeee9f6),
                      color: const Color(0xff6953ae),
                    ),
                  ),
                  Text('$score', textScaler: TextScaler.noScaling),
                ],
              ),
            ),
          ),
          Text(
            tr('设备睡眠评分', 'Device sleep score'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${_number(score.toDouble())} ${tr('分', 'pts')}'),
        ],
      ),
    ),
  );

  Widget _night(SleepMetricSeries series) {
    final first = series.points.first, last = series.points.last;
    final start = first.window.start, end = last.window.end;
    final samples = <List<Offset>>[];
    SleepMetricPoint? previous;
    for (final p in series.points) {
      if (previous == null || !series.connects(previous, p)) samples.add([]);
      samples.last.add(
        Offset(p.at.difference(start).inMilliseconds / 1000, p.value),
      );
      previous = p;
    }
    final extreme = series.metric == HealthMetric.hrv
        ? series.maximum
        : series.minimum;
    final extremeLabel = series.metric == HealthMetric.hrv
        ? tr('最高', 'Highest')
        : tr('最低', 'Lowest');
    final unit = _unit(series);
    return NightMeasurementsChart(
      key: ValueKey('sleep-metric-${series.signature}'),
      title: _metricLabel(series),
      stats:
          '$extremeLabel ${_number(extreme)} $unit · ${tr('平均', 'Avg')} ${_number(series.mean)} $unit',
      segments: samples,
      begin: 0,
      end: end.difference(start).inMilliseconds / 1000,
      minimum: series.minimum - 1,
      maximum: series.maximum + 1,
      axisStart: _clock(first.window.clock(start)),
      axisEnd: _clock(last.window.clock(end)),
      color: _metricColor(series.metric),
    );
  }

  List<Widget> _range(
    ({DateTime start, DateTime end}) range,
    List<HealthRecord> records,
  ) {
    final days = sleepDaysInRange(range.start, range.end).toList();
    // One consistent device for a comparison. Old records stay available by
    // selecting a date/device; never average two devices on the same axis.
    final selectedDevice =
        (widget.controller.connectedDevice ??
                widget.controller.rememberedDevice)
            ?.id ??
        records.first.deviceId;
    final byDay = <String, HealthRecord>{};
    for (final r in records.where((r) => r.deviceId == selectedDevice)) {
      byDay.putIfAbsent(sleepRecordSdkDate(r), () => r);
    }
    HealthRecord? forDay(DateTime d) =>
        byDay[DateFormat('yyyy-MM-dd').format(d)];
    final points = days.map(forDay).toList();
    final axis = days.map(_shortDate).toList();
    final hours = points.map((r) => r == null ? null : _duration(r)).toList();
    final valid = hours.whereType<double>().toList();
    final mean = valid.isEmpty
        ? null
        : valid.fold<double>(0, (a, b) => a + b) / valid.length;
    final periodKey =
        '${range.start.year}-${range.start.month}-${range.start.day}-${_period.name}';
    final windows = points
        .map((r) => r == null ? null : mainSleepWindow(r))
        .toList();
    final starts = [
      for (var i = 0; i < days.length; i++)
        if (windows[i] case final w?)
          sleepMinutesFromSdkDay(w.clock(w.start), days[i]).toDouble()
        else
          null,
    ];
    final ends = [
      for (var i = 0; i < days.length; i++)
        if (windows[i] case final w?)
          sleepMinutesFromSdkDay(w.clock(w.end), days[i]).toDouble()
        else
          null,
    ];
    final scores = points
        .map((r) => r == null ? null : _deviceScore(r)?.toDouble())
        .toList();
    final scoreSources = {
      for (var i = 0; i < points.length; i++)
        if (scores[i] != null)
          '${points[i]!.sourceVendor}|${points[i]!.sourceModel}|${points[i]!.firmwareVersion}|${points[i]!.rawVersion}|${points[i]!.sleepTimeline != null}',
    };
    final groups = <String, SleepMetricSeries>{};
    for (final row in points.whereType<HealthRecord>()) {
      for (final series
          in _measurements[row.id] ?? const <SleepMetricSeries>[]) {
        if (series.metric != HealthMetric.bloodOxygen) {
          groups[series.signature] = series;
        }
      }
    }
    final sleep = const Color(0xff6e58ae), wake = const Color(0xffaa662d);
    Color color(HealthMetric metric) => _metricColor(metric);
    String missing(int i) => '${axis[i]} · ${tr('暂无记录', 'No record')}';
    void open(int i) => _selectDate(days[i], period: SleepReportPeriod.day);
    return [
      _hero(
        tr('平均睡眠时长', 'Average sleep time'),
        mean == null ? '--' : sleepMinutesLabel(mean),
        details: [
          tr(
            '${valid.length} 天有时长记录',
            '${valid.length} days with duration records',
          ),
        ],
      ),
      if (valid.isNotEmpty)
        SleepReportChart(
          key: ValueKey('duration-$periodKey'),
          title: tr('睡眠时长', 'Sleep duration'),
          series: [(color: sleep, values: hours)],
          axis: axis,
          minimum: 0,
          yLabel: (v) => '${(v / 60).toStringAsFixed(1)} h',
          describe: (i) => hours[i] == null
              ? missing(i)
              : '${axis[i]} · ${sleepMinutesLabel(hours[i]!)}',
          onOpen: open,
        ),
      if (windows.any((w) => w != null))
        SleepReportChart(
          key: ValueKey('schedule-$periodKey'),
          title: tr('入睡与醒来', 'Sleep & wake times'),
          series: [(color: sleep, values: starts), (color: wake, values: ends)],
          axis: axis,
          yLabel: _minuteClock,
          header: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legend(sleep, tr('入睡', 'Asleep')),
              _legend(wake, tr('醒来', 'Awake')),
            ],
          ),
          describe: (i) {
            final w = windows[i];
            return w == null
                ? missing(i)
                : '${axis[i]} · ${tr('入睡', 'Asleep')} ${_clockWithDate(w.clock(w.start), days[i])} · ${tr('醒来', 'Awake')} ${_clockWithDate(w.clock(w.end), days[i])}';
          },
          onOpen: open,
        ),
      if (scoreSources.length == 1)
        SleepReportChart(
          key: ValueKey('score-$periodKey'),
          title: tr('设备睡眠评分', 'Device sleep score'),
          series: [(color: wake, values: scores)],
          axis: axis,
          minimum: 0,
          maximum: 100,
          describe: (i) => scores[i] == null
              ? missing(i)
              : '${axis[i]} · ${_number(scores[i]!)} / 100',
          onOpen: open,
        ),
      for (final entry in groups.entries) ...[
        Builder(
          builder: (context) => _metricTrend(
            entry.key,
            entry.value,
            points,
            axis,
            periodKey,
            open,
            color(entry.value.metric),
          ),
        ),
      ],
    ];
  }

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 9, color: color),
      const SizedBox(width: 5),
      Flexible(child: Text(label)),
    ],
  );

  Widget _metricTrend(
    String key,
    SleepMetricSeries reference,
    List<HealthRecord?> records,
    List<String> labels,
    String periodKey,
    ValueChanged<int> open,
    Color color,
  ) {
    final means = [
      for (final row in records)
        row == null
            ? null
            : (_measurements[row.id] ?? const <SleepMetricSeries>[])
                  .where((s) => s.signature == key)
                  .firstOrNull
                  ?.mean,
    ];
    return SleepReportChart(
      key: ValueKey('$key-$periodKey'),
      title: _metricLabel(reference),
      series: [(color: color, values: means)],
      axis: labels,
      describe: (i) =>
          '${labels[i]} · ${means[i] == null ? tr('暂无记录', 'No record') : '${tr('平均', 'Avg')} ${_number(means[i]!)} ${_unit(reference)}'}',
      onOpen: open,
    );
  }
}

List<(SleepStage, double)> _recordedSleepStages(HealthRecord record) {
  final values = record.values;
  return <(SleepStage, double)>[
    if (values['deepHours'] != null)
      (SleepStage.deep, values['deepHours']!.toDouble() * 60),
    if (values['lightHours'] != null)
      (SleepStage.light, values['lightHours']!.toDouble() * 60),
    if (values['remHours'] != null)
      (SleepStage.rem, values['remHours']!.toDouble() * 60),
    if (values['awakeMinutes'] != null)
      (SleepStage.awake, values['awakeMinutes']!.toDouble()),
  ].where((stage) => stage.$2.isFinite && stage.$2 > 0).toList();
}

class _SleepStageDistribution extends StatelessWidget {
  const _SleepStageDistribution({required this.record});
  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    final stages = _recordedSleepStages(record);
    final total = stages.fold<double>(0, (sum, stage) => sum + stage.$2);
    if (total <= 0) return const SizedBox.shrink();
    return Card(
      key: const Key('sleep-stage-distribution'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiCopy(context, "睡眠阶段分布"),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  for (final stage in stages)
                    Expanded(
                      flex: math.max(1, (stage.$2 / total * 10000).round()),
                      child: Semantics(
                        label:
                            '${_stageLabel(stage.$1)} ${sleepMinutesLabel(stage.$2)}',
                        child: SizedBox(
                          height: 28,
                          child: ColoredBox(color: _stageColor(stage.$1)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                for (final stage in stages)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _stageColor(stage.$1).withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_stageLabel(stage.$1)),
                        Text(
                          sleepMinutesLabel(stage.$2),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('${(stage.$2 / total * 100).round()}%'),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              uiCopy(context, "各睡眠阶段占比"),
              style: TextStyle(fontSize: 14, color: SaydianColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepNotice extends StatelessWidget {
  const _SleepNotice({required this.message, required this.icon});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SaydianColors.techBlue),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class SleepTimelineCard extends StatelessWidget {
  const SleepTimelineCard({
    required this.timeline,
    this.isDemo = false,
    super.key,
  });
  final SleepTimeline timeline;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    var naps = 0;
    return Column(
      key: const Key('sleep-timeline-card'),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            isDemo
                ? uiCopy(
                    context,
                    "演示时间轴 · 全部为示例数据（UTC{p0}）",
                    parameters: [timeline.timezone],
                  )
                : uiCopy(
                    context,
                    "时间按记录时区 UTC{p0} 显示",
                    parameters: [timeline.timezone],
                  ),
            style: const TextStyle(color: SaydianColors.muted, fontSize: 14),
          ),
        ),
        for (final session in timeline.sessions.where(
          (session) => session.hasSegments,
        ))
          _SleepSessionCard(
            timeline: timeline,
            session: session,
            isDemo: isDemo,
            title: switch (session.kind) {
              SleepSessionKind.night => uiCopy(context, "夜间睡眠"),
              SleepSessionKind.nap => uiCopy(
                context,
                "小睡 {p0}",
                parameters: [++naps],
              ),
              SleepSessionKind.unknown => uiCopy(context, "睡眠记录"),
            },
          ),
      ],
    );
  }
}

class _SleepSessionCard extends StatefulWidget {
  const _SleepSessionCard({
    required this.timeline,
    required this.session,
    required this.title,
    required this.isDemo,
  });
  final SleepTimeline timeline;
  final SleepSession session;
  final String title;
  final bool isDemo;

  @override
  State<_SleepSessionCard> createState() => _SleepSessionCardState();
}

class _SleepSessionCardState extends State<_SleepSessionCard> {
  SleepStageSegment? selected;
  SleepTimeline get timeline => widget.timeline;
  SleepSession get session => widget.session;
  String get title => widget.title;
  bool get isDemo => widget.isDemo;

  @override
  void didUpdateWidget(_SleepSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != session) selected = null;
  }

  void _selectFraction(double x, double width) {
    if (width <= 0) return;
    final first = session.startedAt!, last = session.endedAt!;
    final micros = last.difference(first).inMicroseconds;
    final at = first.add(
      Duration(
        microseconds: (micros * (x / width).clamp(0.0, 1.0)).floor().clamp(
          0,
          micros - 1,
        ),
      ),
    );
    final segment = session.segments
        .where((s) => !at.isBefore(s.startAt) && at.isBefore(s.endAt))
        .firstOrNull;
    if (segment != selected) setState(() => selected = segment);
  }

  String _time(DateTime instant) => DateFormat(
    uiCopy(null, "M月d日 HH:mm"),
  ).format(timeline.displayTime(instant));

  double _minutes(SleepStageSegment segment) =>
      segment.endAt.difference(segment.startAt).inSeconds / 60;

  Future<void> _showSegment(
    BuildContext context,
    SleepStageSegment segment,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _stageLabel(segment.stage),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Text(
              uiCopy(context, "开始：{p0}", parameters: [_time(segment.startAt)]),
            ),
            Text(
              uiCopy(context, "结束：{p0}", parameters: [_time(segment.endAt)]),
            ),
            Text(
              uiCopy(
                context,
                "持续：{p0}",
                parameters: [sleepMinutesLabel(_minutes(segment))],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isDemo
                  ? uiCopy(context, "示例展示，并非你的睡眠记录。")
                  : uiCopy(context, "时间按这条记录的时区显示。"),
              style: TextStyle(color: SaydianColors.muted),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final start = session.startedAt!;
    final end = session.endedAt!;
    final stageMinutes = <SleepStage, double>{};
    for (final segment in session.segments) {
      stageMinutes.update(
        segment.stage,
        (value) => value + _minutes(segment),
        ifAbsent: () => _minutes(segment),
      );
    }
    final asleep = session.asleepMinutes;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              uiCopy(
                context,
                "有效睡眠 {p0}",
                parameters: [asleep > 0 ? sleepMinutesLabel(asleep) : '--'],
              ),
              style: const TextStyle(
                color: Color(0xFF7164C5),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) => Semantics(
                label: uiCopy(
                  context,
                  "{p0}阶段时间轴，{p1}个{p2}时间段。展开时间明细可逐段查看。",
                  parameters: [
                    title,
                    session.segments.length,
                    isDemo ? uiCopy(context, "示例") : uiCopy(context, "真实"),
                  ],
                ),
                child: GestureDetector(
                  key: const Key('sleep-stage-chart'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _selectFraction(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  ),
                  onHorizontalDragStart: (details) => _selectFraction(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  ),
                  onHorizontalDragUpdate: (details) => _selectFraction(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  ),
                  child: SizedBox(
                    height: 184,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SleepStagePainter(
                        session: session,
                        selected: selected,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      DateFormat('HH:mm').format(timeline.displayTime(start)),
                      key: const Key('sleep-axis-start'),
                      style: const TextStyle(color: SaydianColors.muted),
                    ),
                  ),
                ),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      DateFormat('HH:mm').format(timeline.displayTime(end)),
                      key: const Key('sleep-axis-end'),
                      style: const TextStyle(color: SaydianColors.muted),
                    ),
                  ),
                ),
              ],
            ),
            if (selected case final segment?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  key: const Key('sleep-stage-readout'),
                  liveRegion: true,
                  child: Text(
                    '${_stageLabel(segment.stage)} · ${sleepMinutesLabel(_minutes(segment))}\n${_time(segment.startAt)} – ${_time(segment.endAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 300 &&
                        MediaQuery.textScalerOf(context).scale(16) <= 22
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final stage in SleepStage.values)
                      if (stageMinutes.containsKey(stage))
                        Container(
                          width: width,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _stageColor(stage).withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 7,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(
                                    switch (stage) {
                                      SleepStage.deep =>
                                        Icons.nights_stay_rounded,
                                      SleepStage.light => Icons.hotel_outlined,
                                      SleepStage.rem =>
                                        Icons.bubble_chart_outlined,
                                      SleepStage.awake =>
                                        Icons.visibility_outlined,
                                      _ => Icons.circle_outlined,
                                    },
                                    size: 18,
                                    color: _stageColor(stage),
                                  ),
                                  Text(_stageLabel(stage)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                sleepMinutesLabel(stageMinutes[stage]!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (asleep > 0 &&
                                  (stage == SleepStage.deep ||
                                      stage == SleepStage.light ||
                                      stage == SleepStage.rem)) ...[
                                const SizedBox(height: 5),
                                Text(
                                  '${(stageMinutes[stage]! / asleep * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: SaydianColors.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              key: PageStorageKey(
                'sleep-session-details-${session.startedAt!.toIso8601String()}',
              ),
              title: Text(uiCopy(context, "展开时间明细")),
              tilePadding: EdgeInsets.zero,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiCopy(context, "开始 {p0}", parameters: [_time(start)]),
                      ),
                      Text(
                        uiCopy(context, "结束 {p0}", parameters: [_time(end)]),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        uiCopy(
                          context,
                          "点击色块可查看对应时间；空白表示该时段暂无记录。占比按已记录的睡眠计算，清醒、暂未分类及未佩戴时段不计入。",
                        ),
                        style: TextStyle(color: SaydianColors.muted),
                      ),
                    ],
                  ),
                ),
                for (var index = 0; index < session.segments.length; index++)
                  ListTile(
                    key: Key('sleep-segment-$title-$index'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(_stageLabel(session.segments[index].stage)),
                    subtitle: Text(
                      uiCopy(
                        context,
                        "{p0} 至 {p1}\n{p2}",
                        parameters: [
                          _time(session.segments[index].startAt),
                          _time(session.segments[index].endAt),
                          sleepMinutesLabel(_minutes(session.segments[index])),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showSegment(context, session.segments[index]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepStagePainter extends CustomPainter {
  const _SleepStagePainter({required this.session, this.selected});
  final SleepSession session;
  final SleepStageSegment? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final start = session.startedAt!;
    final span = session.endedAt!.difference(start).inMicroseconds;
    if (span <= 0) return;
    final stages = SleepStage.values
        .where(
          (stage) => session.segments.any((segment) => segment.stage == stage),
        )
        .toList(growable: false);
    if (stages.isEmpty) return;
    final rowHeight = size.height / stages.length;
    final background = Paint()..color = const Color(0xFFF5F3FA);
    for (var row = 0; row < stages.length; row++) {
      canvas.drawRect(
        Rect.fromLTWH(0, row * rowHeight + 3, size.width, rowHeight - 6),
        background,
      );
    }
    SleepStageSegment? previous;
    for (final segment in session.segments) {
      final x =
          segment.startAt.difference(start).inMicroseconds / span * size.width;
      final width =
          segment.endAt.difference(segment.startAt).inMicroseconds /
          span *
          size.width;
      final y = stages.indexOf(segment.stage) * rowHeight + 3;
      if (previous != null && previous.endAt == segment.startAt) {
        final from = (stages.indexOf(previous.stage) + .5) * rowHeight;
        canvas.drawLine(
          Offset(x, from),
          Offset(x, (stages.indexOf(segment.stage) + .5) * rowHeight),
          Paint()
            ..color = _stageColor(segment.stage).withValues(alpha: .4)
            ..strokeWidth = 1.2,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            y,
            math.min(size.width - x, math.max(1, width)),
            rowHeight - 6,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = _stageColor(segment.stage),
      );
      previous = segment;
    }
    if (selected case final segment?) {
      final x =
          ((segment.startAt.difference(start).inMicroseconds +
                  segment.endAt.difference(start).inMicroseconds) /
              2) /
          span *
          size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = const Color(0xff28203e)
          ..strokeWidth = 1.3,
      );
      canvas.drawCircle(
        Offset(x, size.height - 3),
        3.5,
        Paint()..color = const Color(0xff28203e),
      );
    }
  }

  @override
  bool shouldRepaint(_SleepStagePainter oldDelegate) =>
      oldDelegate.session != session || oldDelegate.selected != selected;
}

/// Distribution of real returned segments. No synthetic stages or sleep goal.
class SleepStageMiniBar extends StatelessWidget {
  const SleepStageMiniBar({required this.record, super.key});
  final HealthRecord record;
  @override
  Widget build(BuildContext context) {
    final timeline = record.sleepTimeline;
    if (timeline == null) return const SizedBox.shrink();
    final durations = <SleepStage, int>{};
    for (final session in timeline.sessions) {
      for (final segment in session.segments) {
        final seconds = segment.endAt.difference(segment.startAt).inSeconds;
        if (seconds > 0) {
          durations.update(
            segment.stage,
            (value) => value + seconds,
            ifAbsent: () => seconds,
          );
        }
      }
    }
    if (durations.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: uiCopy(
        context,
        "睡眠阶段分布：{p0}",
        parameters: [
          durations.entries
              .map(
                (e) => uiCopy(
                  context,
                  "{p0}{p1}分钟",
                  parameters: [_stageLabel(e.key), (e.value / 60).round()],
                ),
              )
              .join(', '),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final entry in durations.entries)
                  Expanded(
                    flex: entry.value,
                    child: ColoredBox(
                      color: _stageColor(entry.key),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
