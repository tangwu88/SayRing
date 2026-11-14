import 'package:flutter/material.dart';
import '../domain/sync_diagnostics.dart';
import '../services/app_controller.dart';

class SyncDiagnosticsPage extends StatefulWidget {
  const SyncDiagnosticsPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<SyncDiagnosticsPage> createState() => _SyncDiagnosticsPageState();
}

class _SyncDiagnosticsPageState extends State<SyncDiagnosticsPage> {
  String? _message;
  @override
  void initState() {
    super.initState();
    widget.controller.prepareSyncDiagnostics();
  }

  static const _stageNames = {
    SyncDiagnosticStage.connect: '设备连接',
    SyncDiagnosticStage.initialization: '设备准备',
    SyncDiagnosticStage.capabilities: '功能信息',
    SyncDiagnosticStage.read: '读取记录',
    SyncDiagnosticStage.persist: '保存记录',
    SyncDiagnosticStage.upload: '上传记录',
    SyncDiagnosticStage.recover: '恢复检查',
  };
  static const _stateNames = {
    SyncDiagnosticState.pending: '进行中',
    SyncDiagnosticState.ok: '已完成',
    SyncDiagnosticState.partial: '尚未全部完成',
    SyncDiagnosticState.failed: '暂未完成',
    SyncDiagnosticState.blocked: '等待处理',
    SyncDiagnosticState.empty: '本次暂无记录',
  };
  Future<void> _recover() async {
    final message = await widget.controller.recoverSyncFromDiagnostics();
    if (mounted) setState(() => _message = message);
  }

  Future<void> _upload() async {
    final message = await widget.controller.syncDiagnostics.send();
    if (mounted) setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller,
          diagnostics = controller.syncDiagnostics;
      final latest = <SyncDiagnosticStage, SyncDiagnosticEvent>{
        for (final event in diagnostics.events) event.stage: event,
      };
      final busy = diagnostics.busy || controller.syncDiagnosticRecoveryBusy;
      return Scaffold(
        appBar: AppBar(title: const Text('同步诊断与恢复')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '设备已连接但数据没有更新时，可在这里检查并尝试恢复。',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text('恢复不会解绑、重置设备或清空记录。设备准备尚未确认时，会保留现有保护。'),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  for (final stage in SyncDiagnosticStage.values)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          Text(_stageNames[stage]!),
                          Text(
                            latest[stage] == null
                                ? '尚未检查'
                                : _stateNames[latest[stage]!.state]!,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('sync-diagnostic-recover'),
              onPressed: busy ? null : _recover,
              icon: const Icon(Icons.sync),
              label: Text(
                controller.syncDiagnosticRecoveryBusy ? '正在检查' : '检查并恢复同步',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('sync-diagnostic-upload'),
              onPressed: busy ? null : _upload,
              icon: const Icon(Icons.support_agent),
              label: Text(diagnostics.busy ? '正在提交' : '上传诊断供客服核查'),
            ),
            const SizedBox(height: 16),
            const Text(
              '诊断仅包含版本、设备型号、过程状态、错误类别和记录数量，不包含健康数值、原始蓝牙数据或账号凭证。登录并同意隐私政策后，失败摘要会限频自动上报。',
            ),
            if (_message ?? diagnostics.status case final String message)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(message, key: const Key('sync-diagnostic-message')),
              ),
            if (diagnostics.lastReportId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SelectableText('诊断编号：${diagnostics.lastReportId}'),
              ),
          ],
        ),
      );
    },
  );
}
