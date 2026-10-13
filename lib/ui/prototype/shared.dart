part of '../prototype_pages.dart';

class FeatureStateCard extends StatelessWidget {
  const FeatureStateCard({
    required this.message,
    required this.icon,
    this.detail,
    this.color = SaydianColors.blue,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? detail;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SaydianColors.muted, height: 1.5),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CityInputDialog extends StatefulWidget {
  const _CityInputDialog();

  @override
  State<_CityInputDialog> createState() => _CityInputDialogState();
}

class _CityInputDialogState extends State<_CityInputDialog> {
  final _city = TextEditingController();

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _city.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.selectCity),
    content: TextField(
      controller: _city,
      autofocus: true,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: context.l10n.cityNameLabel,
        hintText: context.l10n.cityNameExample,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(context.l10n.confirm)),
    ],
  );
}

class _ContactEditorDialog extends StatefulWidget {
  const _ContactEditorDialog();

  @override
  State<_ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<_ContactEditorDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    Navigator.pop(context, <String, Object?>{
      'operation': 'add',
      'name': name,
      'phone': phone,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.addContact),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 12,
          decoration: InputDecoration(labelText: context.l10n.contactName),
        ),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: context.l10n.contactPhone),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
    ],
  );
}

IconData _deviceFeatureIcon(DeviceFeature feature) => switch (feature) {
  DeviceFeature.watchFaces => Icons.watch_later_outlined,
  DeviceFeature.photoWatchFace => Icons.photo_outlined,
  DeviceFeature.findWatch => Icons.notifications_active_outlined,
  DeviceFeature.camera => Icons.camera_alt_outlined,
  DeviceFeature.gestureControl => Icons.gesture_rounded,
  DeviceFeature.callReminder => Icons.phone_in_talk_outlined,
  DeviceFeature.phoneCalls => Icons.call_outlined,
  DeviceFeature.contacts => Icons.contacts_outlined,
  DeviceFeature.notifications => Icons.notifications_none_rounded,
  DeviceFeature.alarms => Icons.alarm_rounded,
  DeviceFeature.weather => Icons.cloud_outlined,
  DeviceFeature.worldClock => Icons.public_rounded,
  DeviceFeature.healthReminders => Icons.event_available_outlined,
  DeviceFeature.healthMonitoring => Icons.monitor_heart_outlined,
  DeviceFeature.healthAssessment => Icons.assignment_turned_in_outlined,
  DeviceFeature.screenDisplay => Icons.brightness_6_outlined,
};

String _deviceFeatureDescription(DeviceFeature feature) => switch (feature) {
  DeviceFeature.watchFaces => '选择并管理戒指显示样式',
  DeviceFeature.photoWatchFace => '用自己的照片制作显示样式',
  DeviceFeature.findWatch => '让附近的戒指响铃或振动',
  DeviceFeature.camera => '打开相机后摇动戒指控制手机拍照',
  DeviceFeature.gestureControl => '设置戒指支持的手势模式',
  DeviceFeature.callReminder => '设置戒指来电提醒',
  DeviceFeature.phoneCalls => '管理戒指通话相关设置',
  DeviceFeature.contacts => '管理戒指中的常用联系人',
  DeviceFeature.notifications => '选择需要由戒指振动提醒的消息',
  DeviceFeature.alarms => '管理戒指闹钟和重复日期',
  DeviceFeature.weather => '把所在城市天气同步到戒指',
  DeviceFeature.worldClock => '同步其他城市的时间信息',
  DeviceFeature.healthReminders => '设置久坐、饮水和日常提醒',
  DeviceFeature.healthMonitoring => '设置心率和血氧自动健康检测',
  DeviceFeature.healthAssessment => '查看戒指支持的辅助评估',
  DeviceFeature.screenDisplay => '调节亮度和亮屏方式',
};
