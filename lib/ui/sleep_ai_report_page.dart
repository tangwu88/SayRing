import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;

import '../domain/health_report_models.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';
import '../services/sleep_health_projection.dart';
import '../services/user_message.dart';
import 'app_theme.dart';
import 'report_visual_summary.dart';
import 'health_ui_owner.dart';
import 'wellness_release.dart';
import 'widgets/usage_info_button.dart';

// Retries only read existing reports. Creating/retrying analysis still requires
// the separate explicit upload confirmation below.
const _maxReportPolls = 90;
const _maxReadFailures = 3;

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
  int _readFailures = 0;
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
    _readFailures = 0;
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
      _readFailures = 0;
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
        _readFailures = 0;
        _schedulePoll(pending: _isPending(report));
      });
    } catch (_) {
      if (current()) {
        setState(() {
          _failed = true;
          _readFailures++;
          _schedulePoll(pending: true);
        });
      }
    }
  }

  void _schedulePoll({required bool pending}) {
    _pausedPolling =
        pending &&
        (_polls >= _maxReportPolls || _readFailures >= _maxReadFailures);
    if (pending && !_pausedPolling) {
      _polls++;
      _poll = Timer(const Duration(seconds: 5), () => unawaited(_load()));
    }
  }

  @override
  Widget build(BuildContext context) => !widget.controller.sleepAiEnabled
      ? const SizedBox.shrink()
      : ListTile(
          key: const Key('sleep-ai-report-entry'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.auto_awesome_outlined,
            color: SaydianColors.techBlue,
          ),
          title: Text(
            uiCopy(context, "睡眠报告"),
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            _failed
                ? _pausedPolling
                      ? uiCopy(context, "报告未加载，点此重试")
                      : uiCopy(context, "正在重新加载报告")
                : _report?.sleepScore != null
                ? uiCopy(
                    context,
                    "{p0} / 100 · 查看评分依据和建议",
                    parameters: [_report!.sleepScore],
                  )
                : _report == null
                ? uiCopy(context, "查看本次睡眠与建议")
                : _report!.status == HealthReportStatus.ready
                ? uiCopy(context, "查看报告")
                : _pausedPolling
                ? uiCopy(
                    context,
                    "{p0} · 点此刷新",
                    parameters: [_report!.progressLabel],
                  )
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
            _readFailures = 0;
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
  Map<String, Object?> _visuals = const {};
  bool _loading = true;
  bool _working = false;
  String? _error;
  Timer? _poll;
  int _request = 0;
  int _polls = 0;
  int _readFailures = 0;
  bool _readFailed = false;
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
      _visuals = const {};
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
      _readFailures = 0;
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
      Map<String, Object?> visuals = const {};
      if (report?.status == HealthReportStatus.ready) {
        final payload = await widget.controller.loadFullSleepReport(report!.id);
        content = _map(payload['content']);
        visuals = _map(payload['visuals']);
      }
      if (!_current || !_foreground || request != _request) return;
      setState(() {
        _report = report;
        _content = content;
        _visuals = visuals;
        _error = null;
        _readFailed = false;
        _readFailures = 0;
        _loading = false;
        _schedulePoll(pending: _isPending(report));
      });
    } catch (error) {
      if (!_current || !_foreground || request != _request) return;
      setState(() {
        _error = _errorMessage(error);
        _readFailed = true;
        _readFailures++;
        _loading = false;
        _schedulePoll(pending: true);
      });
    }
  }

  void _schedulePoll({required bool pending}) {
    _pausedPolling =
        pending &&
        (_polls >= _maxReportPolls || _readFailures >= _maxReadFailures);
    if (pending && !_pausedPolling) {
      _polls++;
      _poll = Timer(const Duration(seconds: 5), () => unawaited(_load()));
    }
  }

  Future<bool> _confirmUpload(Map<String, Object?> availability) async {
    final consent = _map(availability['analysisConsent']);
    final metadata = _map(consent['document']);
    final version = '${consent['availableVersion'] ?? ''}';
    if (version.isEmpty ||
        metadata['version'] != version ||
        '${metadata['path'] ?? ''}'.isEmpty) {
      throw FormatException(uiCopy(context, "Say Ring 睡眠 AI 分析说明暂不可用"));
    }
    final document = await widget.controller.globalLegalDocument(
      '${metadata['path']}',
    );
    if (!mounted || !_current) return false;
    if (document['version'] != version ||
        (metadata['locale'] != null &&
            document['locale'] != metadata['locale'])) {
      throw FormatException(uiCopy(context, "分析说明已更新，请重新打开页面"));
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
    if (text.isEmpty) throw FormatException(uiCopy(context, "分析说明内容为空，不能上传"));
    var accepted = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(uiCopy(context, "生成睡眠报告？")),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  uiCopy(
                    context,
                    "第三方 AI 将分析当天的睡眠时长、阶段汇总、夜睡和小睡的起止时间及已有评分。不提供姓名、联系方式、设备地址或分段明细。",
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(text),
                const SizedBox(height: 12),
                CheckboxListTile(
                  key: const Key('sleep-ai-upload-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: accepted,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(uiCopy(context, "我已阅读并同意上传本次睡眠汇总用于 AI 分析")),
                  onChanged: (value) =>
                      setDialogState(() => accepted = value == true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(uiCopy(context, "取消")),
            ),
            FilledButton(
              key: const Key('sleep-ai-confirm-upload'),
              onPressed: accepted
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text(uiCopy(context, "上传并分析")),
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
        throw FormatException(
          '${availability['reason'] ?? uiCopy(null, "AI 分析服务暂不可用")}',
        );
      }
      if (!await _confirmUpload(availability)) return;
      final report = _report?.status == HealthReportStatus.failed
          ? await widget.controller.retrySleepReport(_report!.id)
          : await widget.controller.createSleepReport(widget.record);
      if (!_current) return;
      setState(() {
        _report = report;
        _content = null;
        _visuals = const {};
      });
      _polls = 0;
      _readFailures = 0;
      await _load();
    } catch (error) {
      if (_current) {
        setState(() => _error = _errorMessage(error));
      }
    } finally {
      if (_current) setState(() => _working = false);
    }
  }

  String _errorMessage(Object error) {
    final message = error is FormatException
        ? error.message
        : widget.controller.healthReportErrorMessage(error);
    if (message.trim().isEmpty ||
        RegExp(
          r'\b(null|undefined|exception|missing)\b',
          caseSensitive: false,
        ).hasMatch(message) ||
        message.contains('未返回') ||
        message.contains('数据缺失')) {
      return uiCopy(context, "睡眠分析暂时无法生成，请更新睡眠记录后重试");
    }
    if (message.contains('说明尚未发布')) return uiCopy(context, "分析说明暂不可用，请稍后重试");
    return userFacingMessage(
      message,
      fallback: uiCopy(context, "报告暂不可用，请稍后重试"),
    );
  }

  Future<void> _withdraw() async {
    if (_working || !_current) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(uiCopy(context, "撤回睡眠 AI 分析授权")),
        content: Text(uiCopy(context, "撤回后停止新的睡眠分析。已有报告和「健康」App 授权不变。")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(uiCopy(context, "取消")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(uiCopy(context, "确认撤回")),
          ),
        ],
      ),
    );
    if (confirmed != true || !_current) return;
    setState(() => _working = true);
    try {
      await widget.controller.withdrawSleepAnalysisConsent();
      if (mounted && _current) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uiCopy(context, "已撤回睡眠 AI 分析授权"))),
        );
      }
    } catch (error) {
      if (_current) setState(() => _error = _errorMessage(error));
    } finally {
      if (_current) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.sleepAiEnabled) {
      return const WellnessReleaseUnavailablePage();
    }
    if (_closed) return const Scaffold(body: SizedBox.shrink());
    final content = _content ?? const <String, Object?>{};
    final score = _map(content['sleepScore']);
    return Scaffold(
      appBar: AppBar(
        title: Text(uiCopy(context, "睡眠报告")),
        actions: [
          IconButton(
            key: const Key('sleep-ai-refresh'),
            onPressed: _working
                ? null
                : () {
                    _polls = 0;
                    _readFailures = 0;
                    unawaited(_load());
                  },
            tooltip: uiCopy(context, "刷新报告"),
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
                  uiCopy(
                    context,
                    "{p0} · 本次睡眠",
                    parameters: [sleepRecordSdkDate(widget.record)],
                  ),
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
                  ReportVisualSummary(
                    visuals: _visuals,
                    score: _report?.sleepScore,
                    explanation: '${score['explanation'] ?? ''}',
                  ),
                  if (_visuals.isEmpty && _report?.sleepScore == null)
                    _section(uiCopy(context, "睡眠参考评分"), [
                      uiCopy(context, "证据不足，未评分"),
                      '${score['explanation'] ?? ''}',
                    ]),
                  _section(uiCopy(context, "睡眠分析"), [
                    '${content['overview'] ?? ''}',
                    for (final row
                        in content['trends'] is List
                            ? content['trends'] as List
                            : const [])
                      '${_map(row)['text'] ?? ''}',
                  ]),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      uiCopy(context, "睡眠改善建议"),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  ReportAdviceList(items: _strings(content['suggestions'])),
                  _section(
                    uiCopy(context, "如何看这份报告"),
                    _strings(content['limitations']),
                  ),
                ] else ...[
                  _section(uiCopy(context, "评分与建议"), [
                    _readFailed
                        ? uiCopy(context, "暂时无法加载报告")
                        : _report == null
                        ? uiCopy(context, "报告将保存在你的账号中。")
                        : _report!.status == HealthReportStatus.failed
                        ? uiCopy(context, "报告未生成，请重试")
                        : _report!.progressLabel,
                    if (_readFailed || _isPending(_report))
                      _pausedPolling
                          ? uiCopy(context, "点右上角刷新")
                          : _readFailed
                          ? uiCopy(context, "正在重试")
                          : uiCopy(context, "完成后自动刷新"),
                  ]),
                  if (!_readFailed &&
                      (_report == null ||
                          _report!.status == HealthReportStatus.failed))
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
                            ? uiCopy(context, "重试睡眠分析")
                            : uiCopy(context, "生成睡眠报告"),
                      ),
                    ),
                ],
                UsageInfoButton(
                  title: uiCopy(context, "报告说明"),
                  message: uiCopy(
                    context,
                    "报告由 AI 根据睡眠汇总生成。\n{p0}",
                    parameters: [
                      content['safetyNotice'] ??
                          uiCopy(context, "供日常参考，不用于诊断或治疗。"),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('sleep-ai-withdraw-consent'),
                  onPressed: _working ? null : _withdraw,
                  child: Text(uiCopy(context, "撤回睡眠 AI 分析授权")),
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
