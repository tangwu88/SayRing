import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/cycle_tracking.dart';
import '../services/app_controller.dart';
import '../services/cycle_tracking_service.dart';
import 'global_code_login_page.dart';
import 'package:html/parser.dart' as html;

const _cyclePurple = Color(0xff72679d), _cycleRose = Color(0xffb75878);

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
  late DateTime month;
  String? selected;
  bool _working = false;
  late int _initialRevision;
  @override
  void initState() {
    super.initState();
    month = DateTime.now();
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
            content: Text(e is FormatException ? e.message : '暂时无法完成，请稍后重试'),
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
    final s = c.settings, p = c.prediction;
    final ongoing = c.entries
        .where((e) => e.kind == 'period' && e.end == null)
        .firstOrNull;
    return Scaffold(
      key: const Key('cycle-page'),
      appBar: AppBar(
        title: const Text('生理周期'),
        actions: [
          if (c.available)
            IconButton(
              tooltip: '通知与数据',
              onPressed: _working ? null : _moreSettings,
              icon: const Icon(Icons.more_horiz),
            ),
          if (c.available)
            IconButton(
              tooltip: '周期设置',
              onPressed: _working ? null : () => _settings(),
              icon: const Icon(Icons.tune_rounded),
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
                    _overview(ongoing, p, s),
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
                    _calendar(),
                    _feelings(),
                    if (c.nights.isNotEmpty) _trend(),
                    _insights(p),
                    if (c.entries.isNotEmpty)
                      _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _title('周期记录', Icons.history),
                            for (final e in c.entries.take(60))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  e.kind == 'period'
                                      ? Icons.water_drop_outlined
                                      : Icons.sentiment_satisfied_alt,
                                  color: _cycleRose,
                                ),
                                title: Text(_describe(e)),
                                subtitle: e.kind == 'period'
                                    ? Text(
                                        e.end == null
                                            ? '尚未记录结束'
                                            : '共${cycleDays(e.start, e.end!) + 1}天',
                                      )
                                    : null,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'end') {
                                      _period(existing: e, finish: true);
                                    } else if (v == 'edit') {
                                      e.kind == 'period'
                                          ? _period(existing: e)
                                          : _daily(e.start, existing: e);
                                    } else {
                                      _delete(e);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('修改'),
                                    ),
                                    if (e.kind == 'period')
                                      const PopupMenuItem(
                                        value: 'end',
                                        child: Text('修改结束日期'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('删除'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                  if (c.status.isNotEmpty)
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
                            const Icon(
                              Icons.cloud_done_outlined,
                              size: 18,
                              color: _cyclePurple,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.status,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_working) const LinearProgressIndicator(),
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

  String _shortDate(String value) {
    final d = parseCycleDate(value);
    return '${d.month}/${d.day}';
  }

  Widget _tag(String text, IconData icon, {Color color = _cyclePurple}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(text, style: TextStyle(fontSize: 12, color: color)),
            ),
          ],
        ),
      );
  Widget _overview(CycleEntry? ongoing, CyclePrediction p, CycleSettings s) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final orbitSize = largeText ? 96.0 : 80.0;
    final days = ongoing == null ? null : cycleDays(ongoing.start, c.today) + 1;
    final title = ongoing != null
        ? '经期进行中'
        : p.status == 'reference'
        ? '下次经期参考'
        : p.status == 'needs_confirmation'
        ? '核对最近经期'
        : '了解你的节奏';
    final detail = ongoing != null
        ? '${_shortDate(ongoing.start)} 开始'
        : p.status == 'reference'
        ? '${_shortDate(p.from!)} — ${_shortDate(p.to!)}'
        : s.recordOnly
        ? '随时补记与回顾'
        : '记下第一次经期';
    return Container(
      key: const Key('cycle-overview'),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xfff0eaf5), Color(0xfff8eff1)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: days != null ? '经期第$days天' : '周期记录',
                child: SizedBox(
                  width: orbitSize,
                  height: orbitSize,
                  child: CustomPaint(
                    painter: const _CycleOrbitPainter(),
                    child: Center(
                      child: days == null
                          ? const Icon(
                              Icons.water_drop_rounded,
                              size: 29,
                              color: _cycleRose,
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$days',
                                  style: TextStyle(
                                    fontSize: largeText ? 24 : 30,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    color: _cycleRose,
                                  ),
                                ),
                                const Text(
                                  '经期天数',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _cycleRose,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: const Key('cycle-headline'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff38303f),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(fontSize: 16, color: _cyclePurple),
                    ),
                    const SizedBox(height: 8),
                    _tag(
                      s.recordOnly
                          ? '仅记录'
                          : p.status == 'reference'
                          ? '历史参考'
                          : '积累中',
                      s.recordOnly
                          ? Icons.edit_note_rounded
                          : p.status == 'reference'
                          ? Icons.calendar_month_outlined
                          : Icons.spa_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: Key(
                  ongoing == null ? 'cycle-record-start' : 'cycle-record-end',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _cyclePurple,
                  minimumSize: const Size(132, 48),
                ),
                onPressed: _working
                    ? null
                    : () => ongoing == null
                          ? _period()
                          : _period(existing: ongoing, finish: true),
                icon: Icon(
                  ongoing == null ? Icons.add_rounded : Icons.check_rounded,
                  size: 19,
                ),
                label: Text(ongoing == null ? '记录开始' : '记录结束'),
              ),
              OutlinedButton.icon(
                onPressed: _working ? null : () => _period(),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('补记'),
              ),
              IconButton.filledTonal(
                tooltip: '记录感受',
                onPressed: _working ? null : () => _daily(selected ?? c.today),
                icon: const Icon(Icons.sentiment_satisfied_alt_outlined),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feelings() {
    final date = selected ?? c.today;
    final entry = c.entries
        .where((e) => e.kind == 'daily' && e.start == date)
        .firstOrNull;
    const fields = [
      ('flow', '经量', Icons.water_drop_outlined),
      ('pain', '疼痛', Icons.bolt_outlined),
      ('mood', '心情', Icons.sentiment_satisfied_alt_outlined),
      ('fatigue', '疲劳', Icons.battery_4_bar_rounded),
    ];
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date == c.today ? '今日感受' : '当天感受',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (date != c.today)
                Text(
                  _shortDate(date),
                  style: const TextStyle(fontSize: 13, color: _cyclePurple),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final columns = MediaQuery.textScalerOf(context).scale(1) > 1.5
                  ? 2
                  : 4;
              final width = (box.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in fields)
                    SizedBox(
                      width: width,
                      child: Semantics(
                        button: true,
                        label: '记录${f.$2}',
                        child: Material(
                          color: const Color(0xfff7f5fa),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _working
                                ? null
                                : () => _daily(date, existing: entry),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 11,
                                horizontal: 4,
                              ),
                              child: Column(
                                children: [
                                  Icon(f.$3, size: 24, color: _cyclePurple),
                                  const SizedBox(height: 5),
                                  Text(
                                    f.$2,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _labels[entry?.data[f.$1]] ?? '＋',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: _cyclePurple,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _insights(CyclePrediction p) {
    final periods = c.entries.where((e) => e.kind == 'period').length;
    final nights = c.nights.map((n) => n.date).toSet().length;
    final fact = p.status == 'reference'
        ? '参考 ${_shortDate(p.from!)}—${_shortDate(p.to!)}'
        : p.status == 'needs_confirmation'
        ? '请确认最近一次经期'
        : '继续记录个人节奏';
    final action = switch (c.currentAiReport ? (c.report?['action']) : null) {
      'prepare' => '提前备好用品',
      'check_records' => '补充最近经期',
      'keep_wearing' => '保持夜间佩戴',
      _ => '记录实际起止日期',
    };
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _title('周期解读', Icons.auto_awesome_outlined)),
              if (c.currentAiReport) _tag('AI', Icons.auto_awesome),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 19,
                color: _cyclePurple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fact,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _tag('$periods次经期记录', Icons.fact_check_outlined),
              if (nights > 0) _tag('$nights晚数据', Icons.nights_stay_outlined),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 19,
                color: _cyclePurple,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(action)),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              '依据与说明',
              style: TextStyle(fontSize: 14, color: _cyclePurple),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${c.explanation.join('\n')}\n日期按已确认的历史参考。戒指增强预测仍在验证。',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          if (c.availability?['available'] == true)
            TextButton.icon(
              onPressed: _working ? null : _ai,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                c.availability?['granted'] == true ? '更新解读' : '开启AI解读',
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
      : '${e.start} · ${e.data.entries.where((x) => x.key != 'date').map((x) => _labels[x.value] ?? (x.value is List ? (x.value as List).map((v) => _labels[v] ?? v).join('、') : '已记录')).join(' · ')}';
  Widget _calendar() {
    final first = DateTime(month.year, month.month),
        count = DateTime(month.year, month.month + 1, 0).day,
        offset = first.weekday % 7,
        p = c.prediction;
    return _card(
      Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '上个月',
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${month.year}年${month.month}月',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '下个月',
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in ['日', '一', '二', '三', '四', '五', '六'])
                Expanded(child: Center(child: Text(d))),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ((count + offset + 6) ~/ 7) * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
            ),
            itemBuilder: (context, i) {
              final day = i - offset + 1;
              if (day < 1 || day > count) return const SizedBox();
              final date = cycleDate(DateTime(month.year, month.month, day));
              final actual = c.entries.any(
                (e) =>
                    e.kind == 'period' &&
                    date.compareTo(e.start) >= 0 &&
                    date.compareTo(e.end ?? c.today) <= 0,
              );
              final reference =
                  p.status == 'reference' &&
                  date.compareTo(p.from!) >= 0 &&
                  date.compareTo(p.to!) <= 0;
              return Semantics(
                label:
                    '$date${actual
                        ? '，已记录经期'
                        : reference
                        ? '，预计范围'
                        : ''}',
                child: InkWell(
                  onTap: date.compareTo(c.today) > 0
                      ? null
                      : () {
                          setState(() => selected = date);
                          _daily(date);
                        },
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: actual
                          ? _cycleRose
                          : reference
                          ? const Color(0xffeeeaf6)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: reference
                          ? Border.all(color: _cyclePurple)
                          : selected == date
                          ? Border.all(color: _cycleRose)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: actual ? Colors.white : null,
                          fontWeight: actual ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            children: [
              Text('● 经期', style: TextStyle(color: _cycleRose)),
              Text('○ 参考', style: TextStyle(color: _cyclePurple)),
              Text('点日期补记', style: TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  String _trendMetric = 'skin_temperature';
  Widget _trend() {
    final metrics = c.nights.map((n) => n.metric).toSet().toList();
    if (!metrics.contains(_trendMetric)) _trendMetric = metrics.first;
    final source = c.nights
        .lastWhere((n) => n.metric == _trendMetric)
        .sourceKey;
    final rows = c.nights
        .where((n) => n.metric == _trendMetric && n.sourceKey == source)
        .toList();
    final baseline =
        rows.map((n) => n.value).reduce((a, b) => a + b) / rows.length;
    final values = rows.take(60).map((n) => n.value - baseline).toList();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('夜间趋势', Icons.show_chart),
          Wrap(
            spacing: 8,
            children: [
              for (final m in metrics)
                ChoiceChip(
                  label: Text(
                    m == 'skin_temperature'
                        ? '皮温'
                        : m == 'sleep_heart_rate'
                        ? '睡眠期间心率'
                        : 'HRV ${m.endsWith('rmssd') ? 'RMSSD' : 'SDNN'}',
                  ),
                  selected: m == _trendMetric,
                  onSelected: (_) => setState(() => _trendMetric = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(painter: _CycleTrendPainter(values)),
          ),
          Text(
            '${rows.length}晚 · 相对个人记录均值',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const Text('同一戒指、同一算法', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Future<DateTime?> _date(String initial) => showDatePicker(
    context: context,
    initialDate: DateTime(
      parseCycleDate(initial).year,
      parseCycleDate(initial).month,
      parseCycleDate(initial).day,
    ),
    firstDate: DateTime(1900),
    lastDate: DateTime.now(),
  );
  Future<void> _period({CycleEntry? existing, bool finish = false}) async {
    var start = existing?.start ?? selected ?? c.today, end = existing?.end;
    if (finish) {
      final d = await _date(c.today);
      if (d == null) return;
      end = cycleDate(d);
    } else {
      final d = await _date(start);
      if (d == null) return;
      start = cycleDate(d);
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(finish ? '记录结束' : '记录经期'),
        content: Text('开始：$start\n结束：${end ?? '尚未记录'}'),
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
    );
    if (ok == true) {
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

  static const _labels = {
    'none': '无',
    'light': '少',
    'medium': '中',
    'heavy': '多',
    'mild': '轻',
    'moderate': '中',
    'severe': '重',
    'calm': '平稳',
    'low': '低落',
    'irritable': '烦躁',
    'strong': '明显',
    'travel': '旅行',
    'unwell': '身体不适',
    'medication': '用药',
    'late_sleep': '晚睡',
  };
  Future<void> _daily(String date, {CycleEntry? existing}) async {
    existing ??= c.entries
        .where((e) => e.kind == 'daily' && e.start == date)
        .firstOrNull;
    final data = <String, Object?>{...?existing?.data, 'date': date};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('$date 感受'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final field in {
                  'flow': ['经量', 'none', 'light', 'medium', 'heavy'],
                  'pain': ['疼痛', 'none', 'mild', 'moderate', 'severe'],
                  'mood': ['心情', 'calm', 'low', 'irritable'],
                  'fatigue': ['疲劳', 'none', 'mild', 'strong'],
                }.entries) ...[
                  Text(field.value.first),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final v in field.value.skip(1))
                        ChoiceChip(
                          label: Text(_labels[v]!),
                          selected: data[field.key] == v,
                          onSelected: (on) => update(() {
                            if (on) {
                              data[field.key] = v;
                            } else {
                              data.remove(field.key);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                const Text('可选标记'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final v in [
                      'travel',
                      'unwell',
                      'medication',
                      'late_sleep',
                    ])
                      FilterChip(
                        label: Text(_labels[v]!),
                        selected: (data['tags'] as List?)?.contains(v) ?? false,
                        onSelected: (on) => update(() {
                          final tags = List<String>.from(
                            data['tags'] as List? ?? [],
                          );
                          on ? tags.add(v) : tags.remove(v);
                          data['tags'] = tags;
                        }),
                      ),
                  ],
                ),
                const Text('未选择表示未填写，不代表没有症状。', style: TextStyle(fontSize: 13)),
              ],
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

  Future<void> _settings({bool first = false}) async {
    final data = Map<String, Object?>.from(c.settings.toJson());
    if (first) data['enabled'] = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(first ? '开启生理周期' : '周期设置'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '经期与感受将加密保存在本机，并随当前账号自动同步到赛电云端，供本人换机恢复和周期参考。可关闭功能、导出或删除。AI分析需另外确认。',
                  ),
                  for (final f in {
                    'enabled': '启用生理周期',
                    'adultConfirmed': '确认已年满18岁',
                    'purposeAccepted': '理解并同意上述数据用途',
                    'recordOnly': '仅记录（孕哺、用药或不确定时适用）',
                    'historyComplete': '已核对历史，中间没有漏记',
                    'hideSummary': '隐藏“我的”入口上的周期摘要',
                    'remind': '经期准备提醒',
                    'recordRemind': '每日记录提醒',
                  }.entries)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(f.value),
                      value: data[f.key] == true,
                      onChanged: (v) => update(() => data[f.key] = v),
                    ),
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
                  DropdownButtonFormField<int>(
                    initialValue: data['leadDays'] as int,
                    decoration: const InputDecoration(labelText: '参考范围开始前几天提醒'),
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('这台手机的周期通知'),
              subtitle: Text(
                c.notificationAccepted ? '通知计划已交给系统' : '需系统允许通知；记录功能仍可用',
              ),
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
                  lastDate: DateTime.now(),
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

class _CycleTrendPainter extends CustomPainter {
  const _CycleTrendPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.fold<double>(.1, (a, b) => math.max(a, b.abs()));
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
              ? size.width / 2
              : i * size.width / (values.length - 1),
          y = size.height / 2 - values[i] / max * size.height * .4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()..color = Colors.grey.shade300,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _cyclePurple
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CycleTrendPainter old) => old.values != values;
}

/// 装饰环仅表达记录状态；没有目标总天数，不表示完成百分比或排卵阶段。
class _CycleOrbitPainter extends CustomPainter {
  const _CycleOrbitPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2),
        r = size.shortestSide / 2 - 5;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = _cyclePurple.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -.6,
      math.pi * .85,
      false,
      Paint()
        ..color = _cycleRose.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(center.dx + r * math.cos(-.6), center.dy + r * math.sin(-.6)),
      3,
      Paint()..color = _cycleRose,
    );
  }

  @override
  bool shouldRepaint(_CycleOrbitPainter old) => false;
}
