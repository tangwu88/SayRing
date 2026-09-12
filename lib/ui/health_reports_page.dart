import '../l10n/global_locale_controller.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/health_report_models.dart';
import '../services/app_controller.dart';
import '../services/app_payment_bridge.dart';
import 'app_theme.dart';

class HealthProfilePage extends StatefulWidget {
  const HealthProfilePage({required this.controller, super.key});

  final AppController controller;

  @override
  State<HealthProfilePage> createState() => _HealthProfilePageState();
}

class _HealthProfilePageState extends State<HealthProfilePage>
    with WidgetsBindingObserver {
  HealthReportDashboard? _dashboard;
  HealthPaymentIntent? _pendingPayment;
  bool _loading = true;
  bool _working = false;
  bool _consentRequestRunning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAfterResume());
    }
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final dashboard = await widget.controller.loadHealthReportDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.controller.healthReportErrorMessage(error);
      });
    }
  }

  Future<void> _refreshAfterResume() async {
    final payment = _pendingPayment;
    if (payment != null) {
      if (payment.channel == 'wechat_app') {
        await widget.controller.takeWechatPaymentResult();
      }
      await _refreshPayment(quiet: true);
      return;
    }
    final hasPendingReport =
        _dashboard?.reports.any(
          (report) =>
              report.status == HealthReportStatus.queued ||
              report.status == HealthReportStatus.generating,
        ) ??
        false;
    if (hasPendingReport) await _load(quiet: true);
  }

  Future<bool> _requestAnalysisConsent() async {
    if (_consentRequestRunning) return false;
    _consentRequestRunning = true;
    try {
      return await _showAnalysisConsent();
    } finally {
      _consentRequestRunning = false;
    }
  }

  bool get _reviewedAnalysisAvailable {
    if (!widget.controller.isGlobalEdition) return true;
    final profile = _dashboard?.profile;
    final version = profile?.analysisConsentAvailableVersion;
    final document = profile?.analysisConsentDocument;
    return version != null &&
        version.isNotEmpty &&
        document != null &&
        document['version'] == version &&
        '${document['path'] ?? ''}'.trim().isNotEmpty;
  }

  bool get _hasCurrentAnalysisConsent {
    final profile = _dashboard?.profile;
    return profile?.analysisConsentGranted == true &&
        (!widget.controller.isGlobalEdition ||
            (_reviewedAnalysisAvailable &&
                profile?.analysisConsentVersion ==
                    profile?.analysisConsentAvailableVersion));
  }

  Future<bool> _ensureGlobalAnalysisConsent() async {
    if (!widget.controller.isGlobalEdition) return true;
    if (!_reviewedAnalysisAvailable) {
      _showMessage(context.l10n.analysisConsentUnavailable);
      return false;
    }
    return _hasCurrentAnalysisConsent || await _requestAnalysisConsent();
  }

  Future<bool> _showAnalysisConsent() async {
    final global = widget.controller.isGlobalEdition;
    final profile = _dashboard?.profile;
    final reviewedVersion = profile?.analysisConsentAvailableVersion;
    String? reviewedText;
    String? reviewedTitle;
    if (global) {
      if (!_reviewedAnalysisAvailable) {
        _showMessage(context.l10n.analysisConsentUnavailable);
        return false;
      }
      setState(() => _working = true);
      try {
        final metadata = profile!.analysisConsentDocument!;
        final document = await widget.controller.globalLegalDocument(
          '${metadata['path']}',
        );
        if (document['version'] != reviewedVersion) {
          throw const FormatException('Reviewed analysis document changed');
        }
        if (metadata['locale'] != null &&
            document['locale'] != metadata['locale']) {
          throw const FormatException(
            'Reviewed analysis document locale changed',
          );
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
        reviewedText = parsed.documentElement?.text.trim();
        if (reviewedText == null || reviewedText.isEmpty) {
          throw const FormatException('Empty reviewed analysis document');
        }
        reviewedTitle = '${document['title'] ?? ''}'.trim();
      } catch (error, stack) {
        debugPrint(
          'Health analysis document could not be loaded: $error\n$stack',
        );
        if (mounted) _showMessage(context.l10n.analysisConsentUnavailable);
        return false;
      } finally {
        if (mounted) setState(() => _working = false);
      }
      if (!mounted) return false;
    }
    var accepted = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            reviewedTitle?.isNotEmpty == true
                ? reviewedTitle!
                : context.l10n.analysisConsent,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (global)
                  SelectableText(reviewedText!)
                else ...[
                  const Text(
                    '为了生成详细报告，我们会分析你近30天的有效健康数据。分析结果仅用于日常健康管理参考，不用于诊断或治疗。',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '系统只向分析服务提供去除姓名、手机号和设备地址后的汇总信息。你可以随时在本页撤回授权。',
                    style: TextStyle(fontSize: 13, color: SaydianColors.muted),
                  ),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const Key('health-analysis-consent-checkbox'),
                  value: accepted,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(context.l10n.analysisReadAgree),
                  onChanged: (value) =>
                      setDialogState(() => accepted = value == true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.notGrantNow),
            ),
            FilledButton(
              key: const Key('health-analysis-consent-confirm'),
              onPressed: accepted
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text(context.l10n.agreeContinue),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return false;
    try {
      await widget.controller.setHealthAnalysisConsent(
        true,
        version: global ? reviewedVersion : null,
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.analysisConsentSaved)),
      );
      await _load(quiet: true);
      return true;
    } catch (error) {
      if (!mounted) return false;
      _showMessage(widget.controller.healthReportErrorMessage(error));
      return false;
    }
  }

  Future<void> _withdrawAnalysisConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.withdrawAnalysisConsent),
        content: Text(context.l10n.withdrawAnalysisExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.confirmWithdraw),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await widget.controller.setHealthAnalysisConsent(false);
      if (!mounted) return;
      _showMessage(context.l10n.analysisConsentWithdrawn);
      await _load(quiet: true);
    });
  }

  Future<void> _generateReport() async {
    final dashboard = _dashboard;
    if (dashboard == null || !dashboard.eligibility.eligible) return;
    if (!await _ensureGlobalAnalysisConsent()) return;
    if (!widget.controller.isGlobalEdition &&
        dashboard.eligibility.consentRequired &&
        !await _requestAnalysisConsent()) {
      return;
    }
    HealthReportSummary? created;
    await _run(() async {
      final report = await widget.controller.createHealthReport();
      created = report;
      if (!mounted) return;
      if (report.needsPayment) return;
      _showMessage(
        report.status == HealthReportStatus.ready ? '报告已准备好' : '报告正在生成，完成后会通知你',
      );
      await _load(quiet: true);
    });
    final report = created;
    if (mounted && report != null && report.needsPayment) {
      await _purchase(report);
    }
  }

  Future<void> _retryReport(HealthReportSummary report) async {
    if (!await _ensureGlobalAnalysisConsent()) return;
    await _run(() async {
      final retried = await widget.controller.retryHealthReport(report.id);
      if (!mounted) return;
      _showMessage(
        retried.status == HealthReportStatus.queued
            ? '已重新开始生成，完成后会通知你'
            : retried.status.label,
      );
      await _load(quiet: true);
    });
  }

  Future<void> _purchase(HealthReportSummary report) async {
    if (!await _ensureGlobalAnalysisConsent()) return;
    final dashboard = _dashboard;
    if (dashboard == null || !dashboard.eligibility.eligible) {
      _showMessage('当前数据还不足，暂不能购买报告');
      return;
    }
    final choice = await _selectPurchase(dashboard.offers);
    if (!mounted || choice == null) return;
    await _run(() async {
      final result = await widget.controller.startHealthPurchase(
        offer: choice.offer,
        report: report,
        androidProvider: choice.provider,
      );
      if (!mounted) return;
      _showMessage(result.message);
      switch (result.state) {
        case HealthPurchaseFlowState.succeeded:
          _pendingPayment = null;
          await widget.controller.createHealthReport();
          await _load(quiet: true);
        case HealthPurchaseFlowState.awaitingConfirmation:
        case HealthPurchaseFlowState.pendingApproval:
          setState(() => _pendingPayment = result.intent);
        case HealthPurchaseFlowState.cancelled:
          break;
      }
    });
  }

  Future<_PurchaseChoice?> _selectPurchase(
    List<HealthReportOffer> offers,
  ) async {
    if (offers.isEmpty) {
      _showMessage('购买方案暂时不可用，请稍后刷新');
      return null;
    }
    var selected = offers.first;
    var provider = AppPaymentProvider.wechat;
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    return showModalBottomSheet<_PurchaseChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.selectReportPlan,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.reportPaidContentHint,
                  style: TextStyle(color: SaydianColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                for (final offer in offers) ...[
                  _OfferCard(
                    offer: offer,
                    selected: selected.id == offer.id,
                    onTap: () => setSheetState(() => selected = offer),
                  ),
                  const SizedBox(height: 10),
                ],
                if (!isIos) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.paymentMethod,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        selected: provider == AppPaymentProvider.wechat,
                        label: Text(context.l10n.wechatPayLabel),
                        avatar: const Icon(Icons.chat_rounded, size: 18),
                        onSelected: (_) => setSheetState(
                          () => provider = AppPaymentProvider.wechat,
                        ),
                      ),
                      ChoiceChip(
                        selected: provider == AppPaymentProvider.alipay,
                        label: Text(context.l10n.alipayLabel),
                        avatar: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 18,
                        ),
                        onSelected: (_) => setSheetState(
                          () => provider = AppPaymentProvider.alipay,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('health-report-pay'),
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    _PurchaseChoice(selected, isIos ? null : provider),
                  ),
                  child: Text('确认支付 ${_price(selected)}'),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.reportPurchaseTerms,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: SaydianColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshPayment({bool quiet = false}) async {
    final pending = _pendingPayment;
    if (pending == null) return;
    try {
      final refreshed = await widget.controller.refreshHealthPayment(
        pending.id,
      );
      if (!mounted) return;
      setState(() => _pendingPayment = refreshed);
      if (refreshed.status == HealthPaymentStatus.succeeded) {
        _pendingPayment = null;
        await widget.controller.createHealthReport();
        if (!mounted) return;
        _showMessage('支付已确认，报告正在生成');
        await _load(quiet: true);
      } else if (!quiet) {
        _showMessage(_paymentStatusMessage(refreshed.status));
      }
    } catch (error) {
      if (!mounted || quiet) return;
      _showMessage(widget.controller.healthReportErrorMessage(error));
    }
  }

  Future<void> _restoreApplePurchases() async {
    await _run(() async {
      final restored = await widget.controller.restoreAppleHealthPurchases();
      if (!mounted) return;
      if (restored > 0) {
        try {
          await widget.controller.createHealthReport();
        } catch (_) {
          // Restored single-report purchases may already have queued the report.
        }
      }
      if (!mounted) return;
      _showMessage(restored > 0 ? '已恢复 $restored 笔购买' : '没有找到可恢复的购买');
      await _load(quiet: true);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _showMessage(widget.controller.healthReportErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.healthProfile),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _working ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_loading && _dashboard == null)
            const Center(child: CircularProgressIndicator())
          else if (_error != null && _dashboard == null)
            _HealthReportError(message: _error!, onRetry: _load)
          else if (_dashboard case final dashboard?)
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                key: const Key('health-profile-content'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _ProfileOverview(profile: dashboard.profile),
                  const SizedBox(height: 12),
                  _EntitlementCard(entitlements: dashboard.entitlements),
                  const SizedBox(height: 12),
                  _EligibilityCard(
                    eligibility: dashboard.eligibility,
                    working: _working,
                    analysisAvailable: _reviewedAnalysisAvailable,
                    onGenerate: _generateReport,
                  ),
                  if (_pendingPayment case final payment?) ...[
                    const SizedBox(height: 12),
                    _PendingPaymentCard(
                      payment: payment,
                      working: _working,
                      onRefresh: _refreshPayment,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _AnalysisConsentCard(
                    granted: dashboard.profile.analysisConsentGranted,
                    working: _working,
                    analysisAvailable: _reviewedAnalysisAvailable,
                    onGrant: _requestAnalysisConsent,
                    onWithdraw: _withdrawAnalysisConsent,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.reportHistory,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (defaultTargetPlatform == TargetPlatform.iOS)
                        TextButton(
                          key: const Key('health-report-restore'),
                          onPressed: _working ? null : _restoreApplePurchases,
                          child: Text(context.l10n.restorePurchases),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (dashboard.reports.isEmpty)
                    const _EmptyReports()
                  else
                    for (final report in dashboard.reports) ...[
                      _ReportCard(
                        report: report,
                        canPurchase:
                            dashboard.eligibility.eligible &&
                            _reviewedAnalysisAvailable,
                        working: _working,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HealthReportDetailPage(
                              controller: widget.controller,
                              report: report,
                            ),
                          ),
                        ),
                        onPurchase: () => _purchase(report),
                        onRetry: () => _retryReport(report),
                        onRefresh: _load,
                      ),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 4),
                  const _SafetyNotice(),
                ],
              ),
            ),
          if ((_loading && _dashboard != null) || _working)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }
}

class HealthReportDetailPage extends StatefulWidget {
  const HealthReportDetailPage({
    required this.controller,
    required this.report,
    super.key,
  });

  final AppController controller;
  final HealthReportSummary report;

  @override
  State<HealthReportDetailPage> createState() => _HealthReportDetailPageState();
}

class _HealthReportDetailPageState extends State<HealthReportDetailPage> {
  Map<String, Object?>? _payload;
  bool _loading = true;
  bool _sharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await widget.controller.loadFullHealthReport(
        widget.report.id,
      );
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.controller.healthReportErrorMessage(error);
      });
    }
  }

  Future<void> _sharePdf() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await widget.controller.exportHealthReport(
        widget.report.id,
      );
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      final result = await SharePlus.instance.share(
        ShareParams(
          subject: 'Say Ring Health Report',
          text: 'My Say Ring wellness reference report',
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: ['Say-Ring-Health-Report-$date.pdf'],
        ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        _showMessage('当前设备暂时无法分享文件');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(widget.controller.healthReportErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final content = _map(_payload?['content']);
    final trends = _maps(content['trends']);
    final suggestions = _strings(content['suggestions']);
    final limitations = _strings(content['limitations']);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.detailedHealthReport),
        actions: [
          IconButton(
            key: const Key('health-report-share'),
            tooltip: '导出或分享',
            onPressed: _loading || _sharing ? null : _sharePdf,
            icon: _sharing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _HealthReportError(message: _error!, onRetry: _load)
          : ListView(
              key: const Key('health-report-detail'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _AiLabel(
                  text: '${content['aiLabel'] ?? widget.report.aiLabel}',
                ),
                const SizedBox(height: 12),
                _DetailSection(
                  title: '报告概览',
                  icon: Icons.summarize_outlined,
                  child: Text(
                    '${content['overview'] ?? '暂未获取报告概览'}',
                    style: const TextStyle(height: 1.65),
                  ),
                ),
                if (trends.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: '趋势整理',
                    icon: Icons.show_chart_rounded,
                    child: Column(
                      children: [
                        for (var index = 0; index < trends.length; index++) ...[
                          _TrendRow(trend: trends[index]),
                          if (index != trends.length - 1)
                            const Divider(height: 24),
                        ],
                      ],
                    ),
                  ),
                ],
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: '日常健康建议',
                    icon: Icons.lightbulb_outline_rounded,
                    child: _BulletList(items: suggestions),
                  ),
                ],
                if (limitations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: '数据局限',
                    icon: Icons.info_outline_rounded,
                    child: _BulletList(items: limitations),
                  ),
                ],
                const SizedBox(height: 12),
                _SafetyNotice(
                  message:
                      '${content['safetyNotice'] ?? '本报告不用于诊断或治疗；如有明显不适，请及时就医。'}',
                ),
              ],
            ),
    );
  }
}

class _ProfileOverview extends StatelessWidget {
  const _ProfileOverview({required this.profile});

  final HealthProfileSummary profile;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety_outlined),
              SizedBox(width: 8),
              Text(
                '近30天健康档案',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ProfileNumber(
                  value: '${profile.distinctDays}',
                  label: '有效天数',
                ),
              ),
              Expanded(
                child: _ProfileNumber(
                  value: '${profile.validRecordCount}',
                  label: '有效记录',
                ),
              ),
              Expanded(
                child: _ProfileNumber(
                  value: '${profile.metricCount}',
                  label: '数据类型',
                ),
              ),
              Expanded(
                child: _ProfileNumber(
                  value: '${profile.activeWarningCount}',
                  label: '预警记录',
                  warning: profile.activeWarningCount > 0,
                ),
              ),
            ],
          ),
          if (profile.metrics.isNotEmpty) ...[
            const Divider(height: 26),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in profile.metrics.take(8))
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 17),
                    label: Text(
                      '${_metricLabel(metric.metric)} ${metric.recordCount}条',
                    ),
                  ),
              ],
            ),
          ],
          const Divider(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.watch_outlined,
                size: 20,
                color: SaydianColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profile.devices.isEmpty
                      ? '暂未绑定戒指，已保存的有效记录仍会保留'
                      : '已绑定 ${profile.devices.length} 台设备：${profile.devices.map((device) => device.displayName.isEmpty ? device.model : device.displayName).where((name) => name.isNotEmpty).join('、')}',
                  style: const TextStyle(
                    color: SaydianColors.muted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ProfileNumber extends StatelessWidget {
  const _ProfileNumber({
    required this.value,
    required this.label,
    this.warning = false,
  });

  final String value;
  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: warning ? SaydianColors.danger : SaydianColors.ink,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: SaydianColors.muted),
      ),
    ],
  );
}

class _EntitlementCard extends StatelessWidget {
  const _EntitlementCard({required this.entitlements});

  final HealthReportEntitlements entitlements;

  @override
  Widget build(BuildContext context) => Card(
    color: SaydianColors.brandGoldSoft,
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.white,
        child: Icon(Icons.workspace_premium_outlined),
      ),
      title: Text('可用详细报告 ${entitlements.availableReportCredits} 次'),
      subtitle: Text(
        entitlements.hasActiveMembership
            ? '健康会员有效至 ${_date(entitlements.membershipExpiresAt)}，会员剩余 ${entitlements.membershipRemainingCredits} 次'
            : '可单次购买，或选择30天健康会员（含4份报告）',
      ),
    ),
  );
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard({
    required this.eligibility,
    required this.working,
    required this.analysisAvailable,
    required this.onGenerate,
  });

  final HealthReportEligibility eligibility;
  final bool working;
  final bool analysisAvailable;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            eligibility.eligible ? '数据已满足报告条件' : '再积累一些数据即可生成',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '当前有 ${eligibility.distinctDays} 天、${eligibility.validRecordCount} 条有效记录；报告至少需要 ${eligibility.minimumDistinctDays} 个不同日期的数据。',
            style: const TextStyle(color: SaydianColors.muted),
          ),
          if (!eligibility.eligible) ...[
            const SizedBox(height: 10),
            for (final item in eligibility.missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            const SizedBox(height: 2),
            Text(
              context.l10n.reportInsufficientDataHint,
              style: TextStyle(fontSize: 13, color: SaydianColors.muted),
            ),
          ] else ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('health-report-generate'),
              onPressed: working || !analysisAvailable ? null : onGenerate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(
                eligibility.availableCredits > 0
                    ? '使用1次权益生成报告'
                    : eligibility.consentRequired
                    ? '阅读说明并生成报告'
                    : '生成详细报告',
              ),
            ),
          ],
          if (!analysisAvailable) ...[
            const SizedBox(height: 10),
            Text(context.l10n.analysisConsentUnavailable),
          ],
        ],
      ),
    ),
  );
}

class _AnalysisConsentCard extends StatelessWidget {
  const _AnalysisConsentCard({
    required this.granted,
    required this.working,
    required this.analysisAvailable,
    required this.onGrant,
    required this.onWithdraw,
  });

  final bool granted;
  final bool working;
  final bool analysisAvailable;
  final Future<bool> Function() onGrant;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        granted ? Icons.verified_user_outlined : Icons.policy_outlined,
      ),
      title: Text(context.l10n.analysisConsent),
      subtitle: Text(
        granted
            ? context.l10n.consentGrantedHint
            : !analysisAvailable
            ? context.l10n.analysisConsentUnavailable
            : context.l10n.consentNeededHint,
      ),
      trailing: TextButton(
        key: Key(
          granted
              ? 'health-analysis-consent-withdraw'
              : 'health-analysis-consent-grant',
        ),
        onPressed: working || (!granted && !analysisAvailable)
            ? null
            : granted
            ? onWithdraw
            : () => unawaited(onGrant()),
        child: Text(granted ? context.l10n.withdraw : context.l10n.view),
      ),
    ),
  );
}

class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({
    required this.payment,
    required this.working,
    required this.onRefresh,
  });

  final HealthPaymentIntent payment;
  final bool working;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Card(
    color: SaydianColors.techBlueSoft,
    child: ListTile(
      leading: const Icon(Icons.hourglass_top_rounded),
      title: Text(context.l10n.waitingPaymentConfirmation),
      subtitle: Text(context.l10n.paymentReturnRefreshHint),
      trailing: TextButton(
        key: const Key('health-payment-refresh'),
        onPressed: working ? null : onRefresh,
        child: Text(context.l10n.refresh),
      ),
    ),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.canPurchase,
    required this.working,
    required this.onOpen,
    required this.onPurchase,
    required this.onRetry,
    required this.onRefresh,
  });

  final HealthReportSummary report;
  final bool canPurchase;
  final bool working;
  final VoidCallback onOpen;
  final VoidCallback onPurchase;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final action = switch (report.status) {
      HealthReportStatus.ready => ('查看报告', onOpen),
      HealthReportStatus.awaitingPayment when canPurchase => (
        '选择方案',
        onPurchase,
      ),
      HealthReportStatus.failed => ('重新生成', onRetry),
      HealthReportStatus.queued ||
      HealthReportStatus.generating => ('刷新状态', onRefresh),
      _ => null,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.previewTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusChip(status: report.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_date(report.periodFrom)} 至 ${_date(report.periodTo)} · ${report.distinctDays}天 · ${report.validRecordCount}条有效记录',
              style: const TextStyle(fontSize: 13, color: SaydianColors.muted),
            ),
            const SizedBox(height: 9),
            Text(report.previewSummary),
            if (report.status == HealthReportStatus.awaitingPayment &&
                !canPurchase) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.reportPurchaseDataMissing,
                style: TextStyle(fontSize: 13, color: SaydianColors.muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: working ? null : action.$2,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(action.$1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final HealthReportStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      HealthReportStatus.ready => SaydianColors.success,
      HealthReportStatus.failed ||
      HealthReportStatus.revoked => SaydianColors.danger,
      HealthReportStatus.awaitingPayment => SaydianColors.warning,
      _ => SaydianColors.info,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final HealthReportOffer offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? SaydianColors.brandRedSoft : Colors.white,
    shape: RoundedRectangleBorder(
      side: BorderSide(
        color: selected ? SaydianColors.brandRed : SaydianColors.line,
        width: selected ? 2 : 1,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? SaydianColors.brandRed : SaydianColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    offer.description,
                    style: const TextStyle(
                      color: SaydianColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _price(offer),
              style: const TextStyle(
                color: SaydianColors.brandRed,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: SaydianColors.brandRed),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});

  final Map<String, Object?> trend;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _metricLabel('${trend['metric'] ?? ''}'),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text('${trend['text'] ?? '未获取'}', style: const TextStyle(height: 1.55)),
    ],
  );
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Icon(Icons.circle, size: 6),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(item, style: const TextStyle(height: 1.55))),
            ],
          ),
        ),
    ],
  );
}

class _AiLabel extends StatelessWidget {
  const _AiLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: SaydianColors.techBlueSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 17),
          const SizedBox(width: 6),
          Text(
            text.trim().isEmpty ? 'AI生成的健康管理参考' : text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({
    this.message = '健康数据和AI分析仅供日常健康管理参考，不用于诊断或治疗；如有明显不适，请及时就医。',
  });

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFFD7A0)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.health_and_safety_outlined,
          color: SaydianColors.warning,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 42,
            color: SaydianColors.muted,
          ),
          SizedBox(height: 10),
          Text('暂无详细报告', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text(
            '满足数据条件后，可以在上方生成第一份报告。',
            textAlign: TextAlign.center,
            style: TextStyle(color: SaydianColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _HealthReportError extends StatelessWidget {
  const _HealthReportError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    ),
  );
}

class _PurchaseChoice {
  const _PurchaseChoice(this.offer, this.provider);

  final HealthReportOffer offer;
  final AppPaymentProvider? provider;
}

String _price(HealthReportOffer offer) =>
    '¥${(offer.priceCents / 100).toStringAsFixed(2)}';

String _date(DateTime? value) =>
    value == null ? '未获取' : DateFormat('yyyy年M月d日').format(value.toLocal());

String _paymentStatusMessage(HealthPaymentStatus status) => switch (status) {
  HealthPaymentStatus.succeeded => '支付已确认',
  HealthPaymentStatus.failed || HealthPaymentStatus.closed => '支付未完成，可重新选择方案',
  HealthPaymentStatus.refunding ||
  HealthPaymentStatus.partialRefunded ||
  HealthPaymentStatus.refunded => '该笔支付正在退款或已退款',
  _ => '支付结果仍在确认，请稍后刷新',
};

String _metricLabel(String metric) => switch (metric.trim().toLowerCase()) {
  'sleep' => '睡眠',
  'steps' => '步数',
  'distance' => '距离',
  'calories' => '热量',
  'heart_rate' || 'heartrate' => '心率',
  'blood_oxygen' || 'bloodoxygen' => '血氧',
  'blood_pressure' || 'bloodpressure' => '血压',
  'blood_glucose' || 'bloodglucose' => '血糖',
  'body_temperature' || 'bodytemperature' => '体温',
  'hrv' => 'HRV',
  'ecg' => 'ECG',
  'body_composition' => '身体成分',
  'blood_composition' => '血液成分',
  _ => metric.trim().isEmpty ? '健康数据' : metric,
};

Map<String, Object?> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : <String, Object?>{};

List<Map<String, Object?>> _maps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry('$key', value)))
          .toList(growable: false)
    : const [];

List<String> _strings(Object? value) => value is List
    ? value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];
