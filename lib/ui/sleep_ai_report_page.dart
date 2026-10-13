import 'dart:async';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;

import '../domain/health_report_models.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';
import '../services/sleep_health_projection.dart';
import 'app_theme.dart';
import 'health_ui_owner.dart';
import 'wellness_release.dart';

class SleepAiReportCard extends StatefulWidget {
  const SleepAiReportCard({
    required this.controller,
    required this.record,
    super.key,
  });
  final AppController controller;
  final HealthRecord record;
  @override
  State<SleepAiReportCard> createState() => _SleepAiReportCardState();
}

class _SleepAiReportCardState extends State<SleepAiReportCard>
    with WidgetsBindingObserver {
  HealthReportSummary? _report;
  bool _failed = false;
  bool _foreground = true;
  bool _showingReport = false;
  bool _pausedPolling = false;
  late (bool, String?, String?) _owner;
  Timer? _poll;
  int _request = 0;
  int _polls = 0;
  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _owner = healthUiOwnerKey(widget.controller);
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  void _reset() {
    _request++;
    _poll?.cancel();
    _polls = 0;
    _pausedPolling = false;
    _report = null;
    _failed = false;
    _owner = healthUiOwnerKey(widget.controller);
  }

  void _onControllerChanged() {
    if (_owner == healthUiOwnerKey(widget.controller) &&
        widget.controller.sleepAiEnabled) {
      return;
    }
    setState(_reset);
    if (widget.controller.sleepAiEnabled) unawaited(_load());
  }

  @override
  void didUpdateWidget(SleepAiReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.controller != widget.controller ||
        !identical(oldWidget.record, widget.record)) {
      _reset();
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _request++;
    _poll?.cancel();
    if (_foreground) {
      _polls = 0;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _request++;
    _poll?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted ||
        !_foreground ||
        _showingReport ||
        !widget.controller.sleepAiEnabled) {
      return;
    }
    _poll?.cancel();
    final request = ++_request;
    final record = widget.record;
    final owner = healthUiOwnerKey(widget.controller);
    bool current() =>
        mounted &&
        _foreground &&
        !_showingReport &&
        request == _request &&
        identical(record, widget.record) &&
        owner == healthUiOwnerKey(widget.controller) &&
        widget.controller.sleepAiEnabled;
    try {
      final report = await widget.controller.loadSleepReport(record);
      if (!current()) return;
      setState(() {
        _report = report;
        _failed = false;
        _pausedPolling = _isPending(report) && _polls >= 90;
      });
      if (_isPending(report) && _polls++ < 90) {
        _poll = Timer(const Duration(seconds: 5), () => unawaited(_load()));
      }
    } catch (_) {
      if (current()) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.controller.isWellnessOnly
      ? const SizedBox.shrink()
      : ListTile(
          key: const Key('sleep-ai-report-entry'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.auto_awesome_outlined,
            color: SaydianColors.techBlue,
          ),
          title: const Text(
            'AI 睡眠评分与分析报告',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            _failed
                ? '报告读取失败，点击重试；未生成评分'
                : _report?.sleepScore != null
                ? '${_report!.sleepScore} / 100 · 查看评分依据和建议'
                : _report == null
                ? '根据本次睡眠生成参考评分及详细建议'
                : _report!.status == HealthReportStatus.ready
                ? '查看睡眠分析与数据局限'
                : _pausedPolling
                ? '${_report!.progressLabel} · 点击刷新状态'
                : _report!.progressLabel,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            _showingReport = true;
            _request++;
            _poll?.cancel();
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'sleep-ai-report'),
                builder: (_) => SleepAiReportPage(
                  controller: widget.controller,
                  record: widget.record,
                ),
              ),
            );
            _showingReport = false;
            _polls = 0;
            if (mounted) await _load();
          },
        );
}

class SleepAiReportPage extends StatefulWidget {
  const SleepAiReportPage({
    required this.controller,
    required this.record,
    super.key,
  });
  final AppController controller;
  final HealthRecord record;
  @override
  State<SleepAiReportPage> createState() => _SleepAiReportPageState();
}

class _SleepAiReportPageState extends State<SleepAiReportPage>
    with WidgetsBindingObserver {
  late (bool, String?, String?) _owner;
  HealthReportSummary? _report;
  Map<String, Object?>? _content;
  bool _loading = true;
  bool _working = false;
  String? _error;
  Timer? _poll;
  int _request = 0;
  int _polls = 0;
  bool _closed = false;
  bool _foreground = true;
  bool _pausedPolling = false;
  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _owner = healthUiOwnerKey(widget.controller);
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  bool get _current =>
      mounted &&
      !_closed &&
      _owner == healthUiOwnerKey(widget.controller) &&
      widget.controller.sleepAiEnabled;
  void _onControllerChanged() {
    if (_current || _closed) return;
    _retire();
  }

  void _retire() {
    _closed = true;
    _request++;
    _poll?.cancel();
    setState(() {
      _report = null;
      _content = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isActive == true) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void didUpdateWidget(SleepAiReportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
    }
    if (!_closed &&
        (oldWidget.controller != widget.controller ||
            !identical(oldWidget.record, widget.record))) {
      _retire();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      _request++;
      _poll?.cancel();
    } else if (_current && !_working) {
      _polls = 0;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _closed = true;
    _request++;
    _poll?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current || !_foreground) return;
    final request = ++_request;
    _poll?.cancel();
    try {
      final report = await widget.controller.loadSleepReport(widget.record);
      if (!_current || !_foreground || request != _request) return;
      Map<String, Object?>? content;
      if (report?.status == HealthReportStatus.ready) {
        final payload = await widget.controller.loadFullSleepReport(report!.id);
        content = _map(payload['content']);
      }
      if (!_current || !_foreground || request != _request) return;
      setState(() {
        _report = report;
        _content = content;
        _error = null;
        _loading = false;
        _pausedPolling = _isPending(report) && _polls >= 90;
      });
      if (_isPending(report) && _polls++ < 90) {
        _poll = Timer(const Duration(seconds: 5), () => unawaited(_load()));
      }
    } catch (error) {
      if (!_current || !_foreground || request != _request) return;
      setState(() {
        _error = _errorMessage(error);
        _loading = false;
      });
    }
  }

  Future<bool> _confirmUpload(Map<String, Object?> availability) async {
    final consent = _map(availability['analysisConsent']);
    final metadata = _map(consent['document']);
    final version = '${consent['availableVersion'] ?? ''}';
    if (version.isEmpty ||
        metadata['version'] != version ||
        '${metadata['path'] ?? ''}'.isEmpty) {
      throw const FormatException('Say Ring 睡眠 AI 分析说明暂不可用');
    }
    final document = await widget.controller.globalLegalDocument(
      '${metadata['path']}',
    );
    if (!mounted || !_current) return false;
    if (document['version'] != version ||
        (metadata['locale'] != null &&
            document['locale'] != metadata['locale'])) {
      throw const FormatException('分析说明已更新，请重新打开页面');
    }
    final parsed = html.parse(
      '${document['contentHtml'] ?? ''}'.replaceAll(
        RegExp(r'</p>|<br\s*/?>', caseSensitive: false),
        '\n\n',
      ),
    );
    for (final element in parsed.querySelectorAll(
      'script,style,noscript,template',
    )) {
      element.remove();
    }
    final text = parsed.documentElement?.text.trim() ?? '';
    if (text.isEmpty) throw const FormatException('分析说明内容为空，不能上传');
    var accepted = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('生成 AI 睡眠报告'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '仅上传选中日期的睡眠时长、已返回的阶段汇总、夜睡/小睡起止和设备评分（如有）。服务端调用已配置的第三方 AI 分析，不向 AI 提供姓名、联系方式、设备地址或原始分段。',
                ),
                const SizedBox(height: 12),
                SelectableText(text),
                const SizedBox(height: 12),
                CheckboxListTile(
                  key: const Key('sleep-ai-upload-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: accepted,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('我已阅读并同意上传本次睡眠汇总用于 AI 分析'),
                  onChanged: (value) =>
                      setDialogState(() => accepted = value == true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('sleep-ai-confirm-upload'),
              onPressed: accepted
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('上传并分析'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !_current) return false;
    if (consent['granted'] != true || consent['version'] != version) {
      await widget.controller.grantSleepAnalysisConsent(version);
    }
    return _current;
  }

  Future<void> _generate() async {
    if (_working || !_current) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final availability = await widget.controller
          .loadSleepReportAvailability();
      if (!_current) return;
      if (availability['available'] != true) {
        throw FormatException('${availability['reason'] ?? 'AI 分析服务暂不可用'}');
      }
      if (!await _confirmUpload(availability)) return;
      final report = _report?.status == HealthReportStatus.failed
          ? await widget.controller.retrySleepReport(_report!.id)
          : await widget.controller.createSleepReport(widget.record);
      if (!_current) return;
      setState(() {
        _report = report;
        _content = null;
      });
      _polls = 0;
      await _load();
    } catch (error) {
      if (_current) {
        setState(() => _error = _errorMessage(error));
      }
    } finally {
      if (_current) setState(() => _working = false);
    }
  }

  String _errorMessage(Object error) => error is FormatException
      ? error.message
      : widget.controller.healthReportErrorMessage(error);

  Future<void> _withdraw() async {
    if (_working || !_current) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('撤回睡眠 AI 分析授权'),
        content: const Text(
          '仅撤回 Say Ring 睡眠 AI 分析授权，停止新的睡眠分析；不改变 Health App 的授权，也不会在此操作中删除已生成的账号报告。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认撤回'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_current) return;
    setState(() => _working = true);
    try {
      await widget.controller.withdrawSleepAnalysisConsent();
      if (mounted && _current) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已撤回睡眠 AI 分析授权')));
      }
    } catch (error) {
      if (_current) setState(() => _error = _errorMessage(error));
    } finally {
      if (_current) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isWellnessOnly) {
      return const WellnessReleaseUnavailablePage();
    }
    if (_closed) return const Scaffold(body: SizedBox.shrink());
    final content = _content ?? const <String, Object?>{};
    final score = _map(content['sleepScore']);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 睡眠分析报告'),
        actions: [
          IconButton(
            key: const Key('sleep-ai-refresh'),
            onPressed: _working
                ? null
                : () {
                    _polls = 0;
                    unawaited(_load());
                  },
            tooltip: '刷新报告',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${sleepRecordSdkDate(widget.record)} · 本次睡眠',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                if (_content != null) ...[
                  _section('AI 睡眠参考评分', [
                    _report?.sleepScore == null
                        ? '证据不足，未评分'
                        : '${_report!.sleepScore} / 100',
                    '${score['explanation'] ?? ''}',
                    'AI 生成，非设备评分、非临床评估。仅基于本次记录。',
                  ]),
                  _section('睡眠分析', [
                    '${content['overview'] ?? ''}',
                    for (final row
                        in content['trends'] is List
                            ? content['trends'] as List
                            : const [])
                      '${_map(row)['text'] ?? ''}',
                  ]),
                  _section('睡眠改善建议', _strings(content['suggestions'])),
                  _section('数据与分析局限', _strings(content['limitations'])),
                  _section('使用说明', [
                    '${content['safetyNotice'] ?? '仅供日常健康管理参考，不用于诊断或治疗。'}',
                  ]),
                ] else ...[
                  _section('AI 评分与建议', [
                    _report == null
                        ? '尚未生成本次睡眠报告。确认后上传睡眠汇总，报告同时保存在账号云端和后台健康报告中。'
                        : _report!.status == HealthReportStatus.failed
                        ? (_report!.progressMessage ??
                              'AI 生成失败，未提供评分。可重试；不会用固定分数替代。')
                        : (_report!.progressMessage ??
                              '${_report!.progressLabel}。'),
                    if (_isPending(_report))
                      _pausedPolling ? '自动刷新已暂停，点击右上角重试' : '完成后自动刷新',
                    '原始睡眠分段时间轴仍仅保存在本机。AI 报告不能作为诊断、治疗或医疗评分。',
                  ]),
                  if (_report == null ||
                      _report!.status == HealthReportStatus.failed)
                    FilledButton.icon(
                      key: const Key('sleep-ai-generate'),
                      onPressed: _working ? null : _generate,
                      icon: _working
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _report?.status == HealthReportStatus.failed
                            ? '重试睡眠分析'
                            : '生成 AI 睡眠评分与报告',
                      ),
                    ),
                ],
                TextButton(
                  key: const Key('sleep-ai-withdraw-consent'),
                  onPressed: _working ? null : _withdraw,
                  child: const Text('撤回睡眠 AI 分析授权'),
                ),
              ],
            ),
    );
  }

  Widget _section(String title, List<String> lines) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          for (final line in lines.where((value) => value.trim().isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(line, style: const TextStyle(height: 1.6)),
            ),
        ],
      ),
    ),
  );
}

Map<String, Object?> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : const {};
List<String> _strings(Object? value) => value is List
    ? value
          .map((value) => '$value')
          .where((value) => value.trim().isNotEmpty)
          .toList()
    : const [];

bool _isPending(HealthReportSummary? report) =>
    report?.status == HealthReportStatus.queued ||
    report?.status == HealthReportStatus.generating;
