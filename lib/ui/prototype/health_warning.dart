part of '../prototype_pages.dart';

class HealthWarningPage extends StatefulWidget {
  const HealthWarningPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<HealthWarningPage> createState() => _HealthWarningPageState();
}

class _HealthWarningPageState extends State<HealthWarningPage> {
  late bool _heartRateEnabled;
  late bool _bloodPressureEnabled;
  late bool _temperatureEnabled;
  late final TextEditingController _heartRateUpper;
  late final TextEditingController _systolicUpper;
  late final TextEditingController _diastolicUpper;
  late final TextEditingController _temperatureUpper;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.healthWarningSettings;
    _heartRateEnabled = settings.heartRateEnabled;
    _bloodPressureEnabled = settings.bloodPressureEnabled;
    _temperatureEnabled = settings.temperatureEnabled;
    _heartRateUpper = TextEditingController(text: '${settings.heartRateUpper}');
    _systolicUpper = TextEditingController(text: '${settings.systolicUpper}');
    _diastolicUpper = TextEditingController(text: '${settings.diastolicUpper}');
    _temperatureUpper = TextEditingController(
      text: settings.temperatureUpper.toStringAsFixed(1),
    );
    widget.controller.addListener(_refresh);
    unawaited(widget.controller.refreshNotificationHistory(allPages: true));
    unawaited(widget.controller.markAllHealthWarningsRead());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _heartRateUpper.dispose();
    _systolicUpper.dispose();
    _diastolicUpper.dispose();
    _temperatureUpper.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    final heartRate = int.tryParse(_heartRateUpper.text.trim());
    final systolic = int.tryParse(_systolicUpper.text.trim());
    final diastolic = int.tryParse(_diastolicUpper.text.trim());
    final temperature = double.tryParse(_temperatureUpper.text.trim());
    if (heartRate == null ||
        systolic == null ||
        diastolic == null ||
        temperature == null) {
      _message('请填写正确的报警数值');
      return;
    }
    final success = await widget.controller.saveHealthWarningSettings(
      HealthWarningSettings(
        heartRateEnabled: _heartRateEnabled,
        heartRateUpper: heartRate,
        bloodPressureEnabled: _bloodPressureEnabled,
        systolicUpper: systolic,
        diastolicUpper: diastolic,
        temperatureEnabled: _temperatureEnabled,
        temperatureUpper: temperature,
      ),
    );
    if (!mounted) return;
    _message(
      success ? '健康预警设置已保存' : widget.controller.errorMessage ?? '保存失败，请稍后重试',
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isExplicitHealthWarning(Map<String, Object?> item) {
    final type = [
      item['type'],
      item['category'],
      item['message_type'],
      item['notice_type'],
    ].whereType<Object>().join(' ').toLowerCase();
    return type.contains('health') ||
        type.contains('warning') ||
        type.contains('健康') ||
        type.contains('预警');
  }

  String _warningStatus(Map<String, Object?> item) {
    final raw =
        [
              item['status_text'],
              item['level_text'],
              item['status_label'],
              item['level'],
            ]
            .whereType<Object>()
            .map((value) => '$value'.trim())
            .firstWhere(
              (value) => value.isNotEmpty && int.tryParse(value) == null,
              orElse: () => '',
            );
    final normalized = raw.toLowerCase();
    if (normalized.contains('high') || raw.contains('高')) return '偏高';
    if (normalized.contains('low') || raw.contains('低')) return '偏低';
    if (normalized.contains('abnormal') || raw.contains('异常')) return '异常';
    return raw.isEmpty ? '异常提醒' : raw;
  }

  @override
  Widget build(BuildContext context) {
    final warnings = widget.controller.notifications
        .where(_isExplicitHealthWarning)
        .toList();
    final loading = widget.controller.notificationStatus == '正在加载';
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.healthAlerts)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FeatureStateCard(
            message: context.l10n.setHealthUpperLimits,
            detail: context.l10n.healthUpperLimitHint,
            icon: Icons.notifications_active_outlined,
            color: SaydianColors.orange,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('warning-heart-rate-switch'),
                    value: _heartRateEnabled,
                    onChanged: (value) =>
                        setState(() => _heartRateEnabled = value),
                    title: Text(context.l10n.heartRateAlertLabel),
                    subtitle: Text(context.l10n.heartRateAlertHint),
                    secondary: const Icon(Icons.favorite_rounded),
                  ),
                  if (_heartRateEnabled)
                    _WarningThresholdField(
                      key: const Key('warning-heart-rate-threshold'),
                      label: context.l10n.heartRateUpperLimit,
                      controller: _heartRateUpper,
                      unit: 'bpm',
                    ),
                  const Divider(height: 12),
                  SwitchListTile(
                    key: const Key('warning-blood-pressure-switch'),
                    value: _bloodPressureEnabled,
                    onChanged: (value) =>
                        setState(() => _bloodPressureEnabled = value),
                    title: Text(context.l10n.bloodPressureAlertLabel),
                    subtitle: Text(context.l10n.bloodPressureAlertHint),
                    secondary: const Icon(Icons.bloodtype_outlined),
                  ),
                  if (_bloodPressureEnabled) ...[
                    _WarningThresholdField(
                      key: const Key('warning-systolic-threshold'),
                      label: context.l10n.systolicUpperLimit,
                      controller: _systolicUpper,
                      unit: 'mmHg',
                    ),
                    const SizedBox(height: 10),
                    _WarningThresholdField(
                      key: const Key('warning-diastolic-threshold'),
                      label: context.l10n.diastolicUpperLimit,
                      controller: _diastolicUpper,
                      unit: 'mmHg',
                    ),
                  ],
                  const Divider(height: 12),
                  SwitchListTile(
                    key: const Key('warning-temperature-switch'),
                    value: _temperatureEnabled,
                    onChanged: (value) =>
                        setState(() => _temperatureEnabled = value),
                    title: Text(context.l10n.temperatureAlertLabel),
                    subtitle: Text(context.l10n.temperatureAlertHint),
                    secondary: const Icon(Icons.thermostat_rounded),
                  ),
                  if (_temperatureEnabled)
                    _WarningThresholdField(
                      key: const Key('warning-temperature-threshold'),
                      label: context.l10n.temperatureUpperLimit,
                      controller: _temperatureUpper,
                      unit: '℃',
                      decimal: true,
                    ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FilledButton.icon(
                      key: const Key('warning-save'),
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(context.l10n.saveHealthAlerts),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.healthAlertHistory,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final alert in widget.controller.healthWarningAlerts)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: SaydianColors.danger,
                ),
                title: Text(alert.title),
                subtitle: Text('${alert.message}\n来源：${alert.origin.label}'),
                trailing: Text(
                  DateFormat('yyyy-MM-dd\nHH:mm').format(alert.triggeredAt),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (warnings.isEmpty &&
              widget.controller.healthWarningAlerts.isEmpty)
            FeatureStateCard(
              message:
                  widget.controller.notificationStatus == '已加载' ||
                      widget.controller.notificationStatus == '暂无消息'
                  ? '暂无健康预警'
                  : widget.controller.notificationStatus,
              icon: Icons.health_and_safety_outlined,
              color: SaydianColors.green,
            )
          else
            for (final warning in warnings)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(
                    Icons.health_and_safety_outlined,
                    color: SaydianColors.orange,
                  ),
                  title: Text(
                    '${warning['title'] ?? warning['name'] ?? '健康提醒'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: SaydianColors.orange,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _warningStatus(warning),
                              style: const TextStyle(
                                color: SaydianColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${warning['content'] ?? warning['message'] ?? warning['created_at'] ?? '健康预警'}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 14),
          FeatureStateCard(
            message: context.l10n.seekProfessionalCare,
            detail: context.l10n.watchHealthReference,
            icon: Icons.medical_information_outlined,
          ),
        ],
      ),
    );
  }
}

class _WarningThresholdField extends StatelessWidget {
  const _WarningThresholdField({
    required this.label,
    required this.controller,
    required this.unit,
    this.decimal = false,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String unit;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 112,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          SizedBox(width: 62, child: Text(unit, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
