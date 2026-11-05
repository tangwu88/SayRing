import 'dart:convert';
import '../services/user_message.dart';
import 'cycle_day_widgets.dart';
import 'cycle_diary_sheet.dart';
import 'cycle_night_trend.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/cycle_tracking.dart';
import '../services/app_controller.dart';
import '../services/cycle_tracking_service.dart';
import 'global_code_login_page.dart';
import 'package:html/parser.dart' as html;

const _cyclePurple = cyclePlum;

class CycleShortcut extends StatelessWidget {
  const CycleShortcut({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller.cycles,
    builder: (context, _) => Card(
      child: ListTile(
        key: const Key('cycle-entry'),
        leading: const Icon(Icons.spa_outlined, color: _cyclePurple, size: 30),
        title: const Text(
          '生理周期',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          controller.cycles.settings.hideSummary
              ? '私密记录，安心管理'
              : controller.cycles.settings.enabled
              ? '查看周期与戒指趋势'
              : '记录周期，提前准备',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CycleTrackingPage(controller: controller),
          ),
        ),
      ),
    ),
  );
}

class CycleTrackingPage extends StatefulWidget {
  const CycleTrackingPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<CycleTrackingPage> createState() => _CycleTrackingPageState();
}

class _CycleTrackingPageState extends State<CycleTrackingPage>
    with WidgetsBindingObserver {
  CycleTrackingService get c => widget.controller.cycles;
  late String selected;
  final _daysScroll = ScrollController();
  bool _working = false;
  late int _initialRevision;
  @override
  void initState() {
    super.initState();
    selected = c.today;
    _initialRevision = c.contextRevision;
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    widget.controller.addListener(_changed);
    _refresh();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await _run(() async {
      if (c.available) {
        await c.load();
        await widget.controller.loadCycleHealth();
        await c.readAiAvailability();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _daysScroll.dispose();
    c.removeListener(_changed);
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working || _initialRevision != c.contextRevision) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException
                  ? userFacingMessage(e.message, fallback: '暂时无法保存，请重试')
                  : '暂时无法完成，请稍后重试',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _card(Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
  Widget _title(String title, IconData icon) => Row(
    children: [
      Icon(icon, color: _cyclePurple),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final s = c.settings, p = c.prediction, day = _view(selected);
    return Scaffold(
      key: const Key('cycle-page'),
      appBar: AppBar(
        title: const Text('生理周期'),
        actions: [
          if (c.available && s.enabled)
            IconButton(
              tooltip: '打开月历',
              onPressed: _calendar,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          if (c.available)
            IconButton(
              tooltip: '更多',
              onPressed: _working ? null : _moreSettings,
              icon: const Icon(Icons.more_horiz),
            ),
        ],
      ),
      body: _initialRevision != c.contextRevision
          ? const Center(child: Text('账号已变化，请返回后重新打开'))
          : !c.available
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.spa_outlined,
                      size: 54,
                      color: _cyclePurple,
                    ),
                    const SizedBox(height: 16),
                    const Text('登录后开启私密周期记录，换机可恢复'),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GlobalCodeLoginPage(
                            controller: widget.controller,
                          ),
                        ),
                      ),
                      child: const Text('登录账号'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                controller: _daysScroll,
                padding: const EdgeInsets.all(16),
                children: [
                  if (!s.enabled)
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _title('记录周期，提前准备', Icons.spa_outlined),
                          const SizedBox(height: 10),
                          const Text('记下起止日期，了解自己的节奏。'),
                          const SizedBox(height: 14),
                          FilledButton(
                            key: const Key('cycle-enable'),
                            onPressed: _working
                                ? null
                                : () => _settings(first: true),
                            child: const Text('开始记录'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    CycleWeek(
                      selected: selected,
                      today: c.today,
                      view: _view,
                      select: _select,
                    ),
                    const SizedBox(height: 10),
                    _overview(day, p),
                    _feelings(day),
                    if (c.conflicts.isNotEmpty)
                      _card(
                        Column(
                          children: [
                            const Text('不同手机修改了同一条记录，请核对后选择。'),
                            for (final conflict in c.conflicts)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('本机：${_describe(conflict)}'),
                                  Text(
                                    '云端：${_describe(CycleEntry.fromJson(conflict.conflict!))}',
                                  ),
                                  Wrap(
                                    spacing: 10,
                                    children: [
                                      TextButton(
                                        onPressed: () => _run(
                                          () => c.resolve(conflict, true),
                                        ),
                                        child: const Text('保留本机'),
                                      ),
                                      TextButton(
                                        onPressed: () => _run(
                                          () => c.resolve(conflict, false),
                                        ),
                                        child: const Text('保留云端'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    if (c.nights.isNotEmpty)
                      CycleNightTrend(
                        nights: c.nights,
                        until: day.future ? c.today : selected,
                      ),
                    _insights(day),
                  ],
                  if (c.busy || c.status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          if (c.busy)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              c.status == '已同步'
                                  ? Icons.cloud_done_outlined
                                  : Icons.save_outlined,
                              size: 18,
                              color: _cyclePurple,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.busy ? '正在同步' : c.status,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_working && !c.busy) const LinearProgressIndicator(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '生活安排参考，不用于避孕或诊断。',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  CycleDayView _view(String date) =>
      cycleDayView(c.entries, c.prediction, date, c.today);
  void _select(String date) {
    if (mounted && _initialRevision == c.contextRevision) {
      setState(() => selected = date);
      // 月历也可从页尾打开，选完应立即看到所选日而不是留在旧的滚动位置。
      if (_daysScroll.hasClients) _daysScroll.jumpTo(0);
    }
  }

  Future<void> _calendar() async {
    final date = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          CycleMonthSheet(selected: selected, today: c.today, view: _view),
    );
    if (date != null) _select(date);
  }

  Widget _overview(CycleDayView day, CyclePrediction p) {
    final active = day.period, completed = active?.end != null;
    final actual = active != null, ref = day.inReference;
    final latestPeriod = c.entries.where((e) => e.kind == 'period').firstOrNull;
    final title = actual
        ? '经期第 ${day.periodDay} 天'
        : ref
        ? '处于经期参考范围'
        : day.future
        ? '尚未到这一天'
        : day.historical
        ? '当天未记经期'
        : p.status == 'reference'
        ? '下次经期参考'
        : p.status == 'needs_confirmation'
        ? '核对最近经期'
        : latestPeriod != null
        ? '今天未记经期'
        : '记录你的周期';
    final sub = actual
        ? '${cycleShort(active.start)}开始${completed ? ' · ${cycleShort(active.end!)}结束' : ''}'
        : (ref || (!day.historical && !day.future && p.status == 'reference'))
        ? '${cycleShort(p.from!)} — ${cycleShort(p.to!)}'
        : day.future
        ? '当天可记录。'
        : day.historical
        ? '可补记这一天。'
        : p.status == 'needs_confirmation'
        ? '上次参考范围已过，请核对实际日期。'
        : c.settings.recordOnly
        ? (latestPeriod == null
              ? '记录实际开始或结束日期。'
              : '上次开始于 ${cycleShort(latestPeriod.start)}。')
        : latestPeriod != null
        ? '记下经期开始和结束日。'
        : '先记下经期开始日。';
    final color = actual ? cycleRose : cyclePlum;
    return Container(
      key: const Key('cycle-overview'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: actual
              ? [const Color(0xfff9e8ed), const Color(0xfffcf7f6)]
              : [const Color(0xffeeebf8), const Color(0xfffaf7f4)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                actual
                    ? Icons.water_drop_outlined
                    : ref
                    ? Icons.date_range_outlined
                    : Icons.spa_outlined,
                color: color,
                size: 19,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  actual
                      ? '实际经期'
                      : ref
                      ? '日历参考'
                      : day.historical
                      ? '历史记录'
                      : day.future
                      ? '日期预览'
                      : c.settings.recordOnly
                      ? '仅记录'
                      : '周期日历',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Color(0xff332b40),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sub,
            style: const TextStyle(fontSize: 14, color: Color(0xff574e5e)),
          ),
          if (!day.future) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              key: Key(
                actual
                    ? (completed ? 'cycle-view-period' : 'cycle-record-end')
                    : 'cycle-record-start',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                minimumSize: const Size(128, 44),
              ),
              onPressed: _working
                  ? null
                  : () => actual
                        ? (completed
                              ? _viewPeriod(active)
                              : _period(existing: active, finish: true))
                        : _period(),
              icon: Icon(
                completed
                    ? Icons.article_outlined
                    : actual
                    ? Icons.check
                    : Icons.add,
                size: 18,
              ),
              label: Text(
                completed
                    ? '查看记录'
                    : actual
                    ? '记录结束'
                    : '记录开始',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feelings(CycleDayView day) {
    if (day.future) return const SizedBox.shrink();
    final labels = diarySummary(day.daily?.data ?? {});
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        key: const Key('cycle-feelings'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: const CircleAvatar(
          backgroundColor: Color(0xfff5eaf0),
          child: Icon(Icons.sentiment_satisfied_alt, color: cycleRose),
        ),
        title: Text(
          day.date == c.today ? '今日感受' : '当天感受',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        subtitle: Text(labels.isEmpty ? '记感受' : labels.join(' · ')),
        trailing: Icon(
          labels.isEmpty ? Icons.add_circle_outline : Icons.edit_outlined,
          color: cycleRose,
        ),
        onTap: _working ? null : () => _daily(day.date, existing: day.daily),
      ),
    );
  }

  Widget _insights(CycleDayView day) {
    // 回顾历史时展示当日事实，不把当前参考或后出的 AI 解读贴到那一天。
    final lines = day.historical
        ? [
            day.period != null
                ? '当天记录为经期第 ${day.periodDay} 天。'
                : '按当天已保存的记录回顾。',
            '依据实际经期和当天感受。',
          ]
        : c.explanation;
    return _card(
      ExpansionTile(
        key: ValueKey('cycle-insight-${day.date}'),
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.auto_awesome_outlined, color: cyclePlum),
        title: Text(
          lines.first,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('查看依据'),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(lines.skip(1).join('\n')),
          ),
          if (!day.historical &&
              !day.future &&
              c.availability?['available'] == true)
            TextButton.icon(
              onPressed: _working ? null : _ai,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                c.availability?['granted'] == true ? '更新解读' : '查看周期解读',
              ),
            ),
        ],
      ),
    );
  }

  String _describe(CycleEntry e) => e.deleted
      ? '已删除'
      : e.kind == 'settings'
      ? '周期设置'
      : e.kind == 'period'
      ? '${e.start} — ${e.end ?? '未结束'}'
      : '${e.start} · ${diarySummary(e.data).join(' · ')}';

  Future<void> _history() async {
    final entries = c.entries;
    final periods = entries.where((e) => e.kind == 'period').toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final lengths = [
      for (var i = 1; i < periods.length; i++)
        if (periods[i - 1].end != null)
          cycleDays(periods[i - 1].start, periods[i].start),
    ];
    final closed = periods.where((p) => p.end != null).length;
    final chosen = await showModalBottomSheet<CycleEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              _title('历史与统计', Icons.bar_chart_rounded),
              const SizedBox(height: 8),
              Text('已记 ${periods.length} 次经期 · $closed 次有结束日期'),
              if (lengths.isNotEmpty)
                Text(
                  '最近记录间隔：${lengths.reversed.take(6).toList().reversed.join('、')} 天',
                ),
              const Divider(),
              if (entries.isEmpty) const Text('还没有记录'),
              for (final e in entries)
                ListTile(
                  leading: Icon(
                    e.kind == 'period'
                        ? Icons.water_drop_outlined
                        : Icons.sentiment_satisfied_alt,
                  ),
                  title: Text(_describe(e)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(ctx, e),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || chosen == null || _initialRevision != c.contextRevision) {
      return;
    }
    _select(chosen.start);
    if (chosen.kind == 'period') {
      await _viewPeriod(chosen);
    } else {
      await _viewDaily(chosen);
    }
  }

  Future<void> _viewDaily(CycleEntry e) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(_describe(e))),
            ListTile(
              title: const Text('修改感受'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              title: const Text('删除这条记录'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || _initialRevision != c.contextRevision) return;
    if (action == 'edit') await _daily(e.start, existing: e);
    if (action == 'delete') await _delete(e);
  }

  Future<void> _viewPeriod(CycleEntry e) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('经期记录'), subtitle: Text(_describe(e))),
            ListTile(
              title: const Text('修改日期'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              title: const Text('删除这段经期'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || _initialRevision != c.contextRevision) return;
    if (action == 'edit') await _period(existing: e);
    if (action == 'delete') await _delete(e);
  }

  Future<DateTime?> _date(String initial) => showDatePicker(
    context: context,
    initialDate: DateTime(
      parseCycleDate(initial).year,
      parseCycleDate(initial).month,
      parseCycleDate(initial).day,
    ),
    firstDate: DateTime(1900),
    lastDate: parseCycleDate(c.today),
  );
  Future<void> _period({CycleEntry? existing, bool finish = false}) async {
    if (selected.compareTo(c.today) > 0) return;
    var start = existing?.start ?? selected;
    String? end = finish ? selected : existing?.end;
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            finish
                ? '记录结束'
                : existing == null
                ? '记录开始'
                : '修改经期',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('开始日期'),
                  subtitle: Text(start),
                  onTap: finish
                      ? null
                      : () async {
                          final d = await _date(start);
                          if (d != null && ctx.mounted) {
                            update(() => start = cycleDate(d));
                          }
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('结束日期'),
                  subtitle: Text(end ?? '未填写'),
                  onTap: () async {
                    final d = await _date(end ?? start);
                    if (d != null && ctx.mounted) {
                      update(() => end = cycleDate(d));
                    }
                  },
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  validateCycleEntry(
                    CycleEntry(
                      id: existing?.id ?? 'draft-period',
                      kind: 'period',
                      data: {'start': start, 'end': ?end},
                    ),
                    c.entries,
                    c.today,
                  );
                } on FormatException catch (e) {
                  update(
                    () => error = userFacingMessage(
                      e.message,
                      fallback: '记录未保存，请重试',
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      await _run(
        () => c.save(
          CycleEntry(
            id:
                existing?.id ??
                'period-${DateTime.now().microsecondsSinceEpoch}',
            kind: 'period',
            data: {'start': start, 'end': ?end},
          ),
        ),
      );
    }
  }

  Future<void> _daily(String date, {CycleEntry? existing}) async {
    if (date.compareTo(c.today) > 0) return;
    final data = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          CycleDiarySheet(date: date, initial: existing?.data ?? const {}),
    );
    if (!mounted || data == null || _initialRevision != c.contextRevision) {
      return;
    }
    if (existing == null && diarySummary(data).isEmpty) return;
    await _run(
      () => c.save(
        CycleEntry(
          id: existing?.id ?? 'daily-$date',
          kind: 'daily',
          data: data,
        ),
      ),
    );
  }

  Future<void> _delete(CycleEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text(_describe(e)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(
        () => c.save(
          CycleEntry(id: e.id, kind: e.kind, data: e.data, deleted: true),
        ),
      );
    }
  }

  Future<void> _settings({bool first = false, bool reminders = false}) async {
    final data = Map<String, Object?>.from(c.settings.toJson());
    if (first) data['enabled'] = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            first
                ? '开启生理周期'
                : reminders
                ? '提醒设置'
                : '记录模式',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!reminders)
                    const Text(
                      '经期与感受加密保存在本机，自动同步到当前账号的赛电云端，换机可恢复。你可关闭、导出或删除记录。AI 分析需单独同意。',
                    ),
                  for (final f
                      in {
                        'enabled': '启用生理周期',
                        'adultConfirmed': '确认已年满18岁',
                        'purposeAccepted': '理解并同意上述数据用途',
                        'recordOnly': '仅记录（孕哺、用药或不确定时适用）',
                        'historyComplete': '已核对历史，中间没有漏记',
                        'hideSummary': '隐藏“我的”入口上的周期摘要',
                        'remind': '经期准备提醒',
                        'recordRemind': '每日记录提醒',
                      }.entries.where(
                        (item) =>
                            first ||
                            (reminders ==
                                ['remind', 'recordRemind'].contains(item.key)),
                      ))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(f.value),
                      value: data[f.key] == true,
                      onChanged: (v) => update(() => data[f.key] = v),
                    ),
                  if (first || reminders)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('提醒时间'),
                      trailing: Text(
                        '${(data['hour'] as int).toString().padLeft(2, '0')}:${(data['minute'] as int).toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay(
                            hour: data['hour'] as int,
                            minute: data['minute'] as int,
                          ),
                        );
                        if (t != null) {
                          update(() {
                            data['hour'] = t.hour;
                            data['minute'] = t.minute;
                          });
                        }
                      },
                    ),
                  if (first || reminders)
                    DropdownButtonFormField<int>(
                      initialValue: data['leadDays'] as int,
                      decoration: const InputDecoration(
                        labelText: '参考范围开始前几天提醒',
                      ),
                      items: [
                        for (var i = 0; i <= 7; i++)
                          DropdownMenuItem(value: i, child: Text('$i天')),
                      ],
                      onChanged: (v) => data['leadDays'] = v,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _run(() async {
        await c.saveSettings(CycleSettings.fromJson(data));
        if (!first && !reminders) return;
        if (data['remind'] == true || data['recordRemind'] == true) {
          await c.enableNotifications(true);
        } else {
          await c.enableNotifications(false);
        }
      });
    }
  }

  Future<void> _moreSettings() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          shrinkWrap: true,
          children: [
            _title('记录模式', Icons.spa_outlined),
            ListTile(
              title: Text(c.settings.recordOnly ? '仅记录' : '经期记录与日历参考'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _settings(first: !c.settings.enabled);
              },
            ),
            const Divider(),
            _title('历史与统计', Icons.bar_chart_rounded),
            ListTile(
              title: const Text('周期记录与统计'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _history();
              },
            ),
            const Divider(),
            _title('提醒与隐私', Icons.notifications_none),
            if (c.settings.enabled)
              ListTile(
                title: const Text('提醒时间与日程'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  _settings(reminders: true);
                },
              ),
            SwitchListTile(
              title: const Text('这台手机的周期通知'),
              subtitle: Text(c.notificationAccepted ? '已安排提醒' : '需允许系统通知'),
              value: c.notificationOptIn,
              onChanged: (v) {
                Navigator.pop(ctx);
                _run(() => c.enableNotifications(v));
              },
            ),
            if (c.availability?['granted'] == true)
              ListTile(
                title: const Text('撤回AI分析授权'),
                onTap: () {
                  Navigator.pop(ctx);
                  _run(() => c.consentAi(false, ''));
                },
              ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('导出周期记录'),
              onTap: () async {
                Navigator.pop(ctx);
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: parseCycleDate(c.today),
                );
                if (range == null || _initialRevision != c.contextRevision) {
                  return;
                }
                final rows = c.entries.where(
                  (e) =>
                      e.start.compareTo(cycleDate(range.start)) >= 0 &&
                      e.start.compareTo(cycleDate(range.end)) <= 0,
                );
                await SharePlus.instance.share(
                  ShareParams(
                    files: [
                      XFile.fromData(
                        utf8.encode(cycleCsv(rows)),
                        mimeType: 'text/csv',
                      ),
                    ],
                    fileNameOverrides: ['Say-Ring-cycle.csv'],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除全部周期数据'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('删除全部周期数据？'),
                    content: const Text('删除经期、感受、周期报告及云端副本，取消周期提醒。其他健康记录不受影响。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('确认删除'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await _run(c.erase);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ai() async {
    if (c.availability?['granted'] != true) {
      final doc = c.availability?['document'];
      if (doc is! Map) return;
      final expectedOwner = c.owner;
      String noticeText;
      try {
        final actual = await widget.controller.globalLegalDocument(
          doc['path'] as String,
        );
        if (c.owner != expectedOwner ||
            actual['version'] != c.availability?['version']) {
          return;
        }
        final parsed = html.parse('${actual['contentHtml'] ?? ''}');
        for (final node in parsed.querySelectorAll(
          'script,style,noscript,template',
        )) {
          node.remove();
        }
        noticeText = parsed.documentElement?.text.trim() ?? '';
        if (noticeText.isEmpty) return;
      } catch (_) {
        return;
      }
      if (!mounted) return;
      final agreed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('周期AI分析'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '仅向说明中列明的服务商发送必要的匿名化周期摘要，用于选择简短建议；不发送身份、设备编号或原始健康数据。可随时撤回。',
                ),
                Text(noticeText),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('暂不开启'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('同意并分析'),
            ),
          ],
        ),
      );
      if (agreed != true) return;
      await _run(() => c.consentAi(true, c.availability!['version'] as String));
    }
    await _run(c.explain);
  }
}
