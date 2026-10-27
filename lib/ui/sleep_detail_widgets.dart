import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../domain/sleep_timeline.dart';
import '../services/app_controller.dart';
import '../services/sleep_health_projection.dart';
import 'app_theme.dart';
import 'health_trend_page.dart' show SleepStructureCard;
import 'health_ui_owner.dart';

bool sleepSyncUnavailable(AppController controller) {
  // Missing capabilities keep the existing guide, never imply no support.
  return controller.capabilities?.supportsHistorySync == false;
}

String sleepMinutesLabel(double minutes) {
  final seconds = (minutes * 60).round();
  if (seconds < 60) return '$seconds秒';
  final wholeMinutes = seconds ~/ 60;
  final label = wholeMinutes < 60
      ? '$wholeMinutes分钟'
      : '${wholeMinutes ~/ 60}小时${wholeMinutes % 60}分';
  return seconds % 60 == 0 ? label : '$label${seconds % 60}秒';
}

String _stageLabel(SleepStage stage) => switch (stage) {
  SleepStage.awake => '清醒',
  SleepStage.light => '浅睡',
  SleepStage.deep => '深睡',
  SleepStage.rem => '快速眼动',
  SleepStage.unknown => '暂未分类',
  SleepStage.notWorn => '未佩戴',
};

Color _stageColor(SleepStage stage) => switch (stage) {
  SleepStage.awake => const Color(0xFFD99A51),
  SleepStage.light => const Color(0xFFAFA7E8),
  SleepStage.deep => const Color(0xFF6454B5),
  SleepStage.rem => const Color(0xFF8B80CF),
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
  late DateTime _date;
  late (bool, String?, String?) _account;
  List<HealthRecord> _records = const [];
  bool _loading = true;
  bool _chooseLatest = true;
  bool _failed = false;
  int _request = 0;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _date = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
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
        _date = DateUtils.dateOnly(DateTime.now());
        _loading = true;
      });
    }
    _refresh?.cancel();
    _refresh = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_load());
    });
  }

  DateTime _recordDate(HealthRecord record) =>
      DateTime.parse(sleepRecordSdkDate(record));

  Future<void> _load() async {
    final request = ++_request;
    var date = _date;
    final account = _account;
    try {
      if (_chooseLatest) {
        final latest = await widget.controller.loadLatestSleepDay();
        if (!mounted || request != _request || account != _account) return;
        if (latest != null) date = _recordDate(latest);
      }
      final records = List<HealthRecord>.of(
        await widget.controller.loadSleepDays(start: date, end: date),
      );
      if (!mounted || request != _request || account != _account) return;
      records.sort((a, b) => _recordDate(b).compareTo(_recordDate(a)));
      final selected = date;
      setState(() {
        _date = selected;
        _records = records
            .where(
              (record) => DateUtils.isSameDay(_recordDate(record), selected),
            )
            .toList(growable: false);
        _failed = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request || account != _account) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _selectDate(DateTime date) {
    _chooseLatest = false;
    setState(() {
      _date = DateUtils.dateOnly(date);
      _records = const [];
      _failed = false;
      _loading = true;
    });
    unawaited(_load());
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: _date.isAfter(today) ? _date : today,
    );
    if (date != null && mounted) _selectDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final day = DateFormat('yyyy-MM-dd').format(_date);
    final status = widget.controller.sleepReadStatuses[day];
    final record = _records.isEmpty ? null : _records.first;
    final timeline = record?.sleepTimeline;
    final hours = record?.values['value'];
    final duration = timeline?.hasSegments == true
        ? timeline!.asleepMinutes > 0
              ? sleepMinutesLabel(timeline.asleepMinutes)
              : '--'
        : hours == null
        ? '--'
        : sleepMinutesLabel(hours.toDouble() * 60);
    final failed = _failed || status == 'failed';
    final syncUnavailable = sleepSyncUnavailable(widget.controller);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _chooseLatest ? '最近一次睡眠' : '按日期查看',
                  key: const Key('sleep-selection-mode'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (!_chooseLatest)
                TextButton.icon(
                  key: const Key('sleep-latest-day'),
                  onPressed: () {
                    setState(() {
                      _chooseLatest = true;
                      _loading = true;
                      _records = const [];
                    });
                    unawaited(_load());
                  },
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('最近一次'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('sleep-previous-day'),
                    tooltip: '前一天',
                    onPressed: () => _selectDate(
                      DateTime(_date.year, _date.month, _date.day - 1),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: TextButton(
                      key: const Key('sleep-select-date'),
                      onPressed: _pickDate,
                      child: Text(
                        DateFormat('yyyy年M月d日').format(_date),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('sleep-next-day'),
                    tooltip: '后一天',
                    onPressed:
                        !_date.isBefore(DateUtils.dateOnly(DateTime.now()))
                        ? null
                        : () => _selectDate(
                            DateTime(_date.year, _date.month, _date.day + 1),
                          ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (failed)
              _SleepNotice(
                message: record == null
                    ? syncUnavailable
                          ? '暂时无法查看睡眠记录，请稍后重试'
                          : '睡眠记录暂时无法更新，请连接戒指后重试'
                    : '睡眠记录暂未更新，以下为已保存的记录',
                icon: Icons.error_outline_rounded,
              ),
            if (record == null)
              _SleepNotice(
                message: failed
                    ? '你可以稍后下拉重试，或选择其他日期查看'
                    : syncUnavailable
                    ? '这一天暂无睡眠记录，你可以选择其他日期查看'
                    : status == 'noData'
                    ? '这一天暂无睡眠记录，佩戴戒指入睡后，可在次日更新查看'
                    : '这一天暂无睡眠记录，佩戴戒指入睡后，请连接更新',
                icon: Icons.bedtime_outlined,
              )
            else ...[
              Card(
                color: const Color(0xFFF0EDF8),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.bedtime_rounded,
                            color: Color(0xFF7164C5),
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '睡眠总时长',
                              style: TextStyle(
                                color: SaydianColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        duration,
                        style: const TextStyle(
                          color: SaydianColors.ink,
                          fontSize: 36,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (timeline?.hasSegments == true)
                SleepTimelineCard(timeline: timeline!)
              else
                _SleepNotice(
                  message: syncUnavailable
                      ? '已记录睡眠总时长，暂未展示分段详情'
                      : '已记录睡眠总时长。连接戒指后下拉更新，可查看最新的睡眠详情',
                  icon: Icons.schedule_outlined,
                ),
              const SizedBox(height: 16),
              _SleepStageDistribution(record: record),
              const SizedBox(height: 16),
              SleepStructureCard(record: record, controller: widget.controller),
            ],
          ],
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              key: const Key('sleep-reference-details'),
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('睡眠说明'),
              subtitle: const Text('戒指估算 · 日常作息参考'),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: const [
                Text(
                  '睡眠总时长包含已记录的夜间睡眠和小睡，清醒及暂未分类的时段不计入。睡眠时长与阶段由戒指估算，长时间静止或未佩戴可能影响结果，请结合实际作息查看，仅供日常参考。建议睡眠时保持佩戴，并在起床后连接更新。时间明细仅保存在手机中；使用 AI 报告前，会另行征求你上传睡眠汇总的同意。',
                  style: TextStyle(color: SaydianColors.muted, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('sleep-open-trend'),
            onPressed: () => widget.onOpenTrend(_date),
            icon: const Icon(Icons.show_chart_rounded),
            label: const Text('查看睡眠趋势与记录'),
          ),
        ],
      ),
    );
  }
}

class _SleepStageDistribution extends StatelessWidget {
  const _SleepStageDistribution({required this.record});
  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    final values = record.values;
    final stages = <(SleepStage, double)>[
      if (values['deepHours'] != null)
        (SleepStage.deep, values['deepHours']!.toDouble() * 60),
      if (values['lightHours'] != null)
        (SleepStage.light, values['lightHours']!.toDouble() * 60),
      if (values['remHours'] != null)
        (SleepStage.rem, values['remHours']!.toDouble() * 60),
      if (values['awakeMinutes'] != null)
        (SleepStage.awake, values['awakeMinutes']!.toDouble()),
    ].where((stage) => stage.$2.isFinite && stage.$2 > 0).toList();
    final total = stages.fold<double>(0, (sum, stage) => sum + stage.$2);
    if (total <= 0) return const SizedBox.shrink();
    return Card(
      key: const Key('sleep-stage-distribution'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '睡眠阶段分布',
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '● ',
                          style: TextStyle(color: _stageColor(stage.$1)),
                        ),
                        TextSpan(
                          text:
                              '${_stageLabel(stage.$1)} ${(stage.$2 / total * 100).round()}%',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '已返回阶段的时长占比',
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
                ? '演示时间轴 · 全部为示例数据（UTC${timeline.timezone}）'
                : '时间按记录时区 UTC${timeline.timezone} 显示',
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
              SleepSessionKind.night => '夜间睡眠',
              SleepSessionKind.nap => '小睡 ${++naps}',
              SleepSessionKind.unknown => '睡眠记录',
            },
          ),
      ],
    );
  }
}

class _SleepSessionCard extends StatelessWidget {
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

  String _time(DateTime instant) =>
      DateFormat('M月d日 HH:mm').format(timeline.displayTime(instant));

  double _minutes(SleepStageSegment segment) =>
      segment.endAt.difference(segment.startAt).inSeconds / 60;

  Future<void> _showSegment(BuildContext context, SleepStageSegment segment) =>
      showModalBottomSheet<void>(
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text('开始：${_time(segment.startAt)}'),
                Text('结束：${_time(segment.endAt)}'),
                Text('持续：${sleepMinutesLabel(_minutes(segment))}'),
                const SizedBox(height: 12),
                Text(
                  isDemo ? '示例展示，并非你的睡眠记录。' : '时间按这条记录的时区显示。',
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
              '有效睡眠 ${asleep > 0 ? sleepMinutesLabel(asleep) : '--'}',
              style: const TextStyle(
                color: Color(0xFF7164C5),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) => Semantics(
                label:
                    '$title阶段时间轴，${session.segments.length}个${isDemo ? '示例' : '真实'}时间段。展开时间明细可逐段查看。',
                child: GestureDetector(
                  key: const Key('sleep-stage-chart'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final width = constraints.maxWidth;
                    final fraction = (details.localPosition.dx / width).clamp(
                      0.0,
                      1.0,
                    );
                    final at = start.add(
                      Duration(
                        microseconds:
                            (end.difference(start).inMicroseconds * fraction)
                                .round(),
                      ),
                    );
                    for (final segment in session.segments) {
                      if (!at.isBefore(segment.startAt) &&
                          at.isBefore(segment.endAt)) {
                        unawaited(_showSegment(context, segment));
                        return;
                      }
                    }
                  },
                  child: SizedBox(
                    height: 184,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SleepStagePainter(session: session),
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
            const SizedBox(height: 18),
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
                            color: _stageColor(stage).withValues(alpha: 0.07),
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
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _stageColor(stage),
                                      shape: BoxShape.circle,
                                    ),
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
              title: const Text('展开时间明细'),
              tilePadding: EdgeInsets.zero,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('开始 ${_time(start)}'),
                      Text('结束 ${_time(end)}'),
                      const SizedBox(height: 12),
                      const Text(
                        '点击色块可查看对应时间；空白表示该时段暂无记录。占比按已记录的睡眠计算，清醒、暂未分类及未佩戴时段不计入。',
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
                      '${_time(session.segments[index].startAt)} 至 ${_time(session.segments[index].endAt)}\n${sleepMinutesLabel(_minutes(session.segments[index]))}',
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
  const _SleepStagePainter({required this.session});
  final SleepSession session;

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
    for (final segment in session.segments) {
      final x =
          segment.startAt.difference(start).inMicroseconds / span * size.width;
      final width =
          segment.endAt.difference(segment.startAt).inMicroseconds /
          span *
          size.width;
      final y = stages.indexOf(segment.stage) * rowHeight + 3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, math.max(1, width), rowHeight - 6),
          const Radius.circular(5),
        ),
        Paint()..color = _stageColor(segment.stage),
      );
    }
  }

  @override
  bool shouldRepaint(_SleepStagePainter oldDelegate) =>
      oldDelegate.session != session;
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
      label:
          '睡眠阶段分布：${durations.entries.map((e) => '${_stageLabel(e.key)}${(e.value / 60).round()}分钟').join('，')}',
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
