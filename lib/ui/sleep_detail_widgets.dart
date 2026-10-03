import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../domain/sleep_timeline.dart';
import '../services/app_controller.dart';
import '../services/health_analysis.dart';
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
  SleepStage.unknown => '未知',
  SleepStage.notWorn => '未佩戴',
};

Color _stageColor(SleepStage stage) => switch (stage) {
  SleepStage.awake => const Color(0xFFE6A657),
  SleepStage.light => const Color(0xFF78A6E9),
  SleepStage.deep => const Color(0xFF4959B9),
  SleepStage.rem => const Color(0xFF9C7FD8),
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
      DateTime.tryParse(record.sleepTimeline?.sdkDate ?? '') ??
      DateUtils.dateOnly(HealthAnalysisService.displayTime(record));

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                          ? '本机睡眠缓存读取失败，请稍后重试'
                          : '睡眠数据读取失败，请重新连接戒指并同步'
                    : '睡眠缓存刷新失败，仍显示本机已保存的数据',
                icon: Icons.error_outline_rounded,
              ),
            if (record == null)
              _SleepNotice(
                message: failed
                    ? '没有可显示的本机睡眠记录'
                    : syncUnavailable
                    ? '该日期暂无本机睡眠记录，当前戒指的睡眠同步暂未开放'
                    : status == 'noData'
                    ? '戒指本次未返回该日睡眠数据'
                    : '该日期暂无睡眠记录，佩戴戒指睡眠后请同步数据',
                icon: Icons.bedtime_outlined,
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '总睡眠',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        duration,
                        style: const TextStyle(
                          color: SaydianColors.techIndigo,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (timeline?.hasSegments == true) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '含实际返回的小睡；清醒、未知及未佩戴时间不计入睡眠。',
                          style: TextStyle(color: SaydianColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (timeline?.hasSegments == true)
                SleepTimelineCard(timeline: timeline!)
              else
                _SleepNotice(
                  message: syncUnavailable
                      ? '此记录只有睡眠汇总，无法反推具体时间段。当前戒指的睡眠同步暂未开放。'
                      : '此记录只有睡眠汇总，无法反推具体时间段。连接戒指并同步后可补充设备仍保留的明细。',
                  icon: Icons.schedule_outlined,
                ),
              SleepStructureCard(record: record, controller: widget.controller),
            ],
          ],
          const SizedBox(height: 12),
          const _SleepNotice(
            message:
                '时间明细仅保存在本机。阶段和设备评分来自戒指，未返回项目保持未知。AI 报告需另行确认上传汇总，AI 评分与设备评分分开。数据仅供日常健康参考。',
            icon: Icons.lock_outline_rounded,
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            isDemo
                ? '演示时间轴 · 全部为示例数据（UTC${timeline.timezone}）'
                : '时间按记录时区 UTC${timeline.timezone} 显示',
            style: const TextStyle(color: SaydianColors.muted, fontSize: 12),
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
                  isDemo ? '本机生成的示例数据，不代表真实测量。' : '时间依据设备实际返回，按记录时区显示。',
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('开始 ${_time(start)}'),
            Text('结束 ${_time(end)}'),
            Text(
              '有效睡眠 ${asleep > 0 ? sleepMinutesLabel(asleep) : '--'}',
              style: const TextStyle(
                color: SaydianColors.techIndigo,
                fontWeight: FontWeight.w800,
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
                    height: 156,
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        DateFormat('HH:mm').format(timeline.displayTime(start)),
                        key: const Key('sleep-axis-start'),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        DateFormat('HH:mm').format(timeline.displayTime(end)),
                        key: const Key('sleep-axis-end'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '点击色块查看时间；空白表示该时段未返回数据。',
              style: TextStyle(color: SaydianColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            for (final stage in SleepStage.values)
              if (stageMinutes.containsKey(stage))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 10,
                        child: ColoredBox(color: _stageColor(stage)),
                      ),
                      Text(_stageLabel(stage)),
                      Text(
                        sleepMinutesLabel(stageMinutes[stage]!),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (asleep > 0 &&
                          (stage == SleepStage.deep ||
                              stage == SleepStage.light ||
                              stage == SleepStage.rem))
                        Text(
                          '${(stageMinutes[stage]! / asleep * 100).toStringAsFixed(1)}%',
                        ),
                    ],
                  ),
                ),
            const Text(
              '占比按有效睡眠计算，清醒、未知、未佩戴不计入。',
              style: TextStyle(color: SaydianColors.muted, fontSize: 12),
            ),
            ExpansionTile(
              title: const Text('展开时间明细'),
              tilePadding: EdgeInsets.zero,
              children: [
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
    final rowHeight = size.height / SleepStage.values.length;
    final background = Paint()..color = const Color(0xFFF2F5FA);
    for (var row = 0; row < SleepStage.values.length; row++) {
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
      final y = segment.stage.index * rowHeight + 3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, math.max(1, width), rowHeight - 6),
          const Radius.circular(3),
        ),
        Paint()..color = _stageColor(segment.stage),
      );
    }
  }

  @override
  bool shouldRepaint(_SleepStagePainter oldDelegate) =>
      oldDelegate.session != session;
}
