import '../domain/models.dart';
import '../domain/health_reminder.dart';

/// Local, user-selected export. Unknown symptom state is not 'no symptoms'.
String buildHealthReminderCsv(HealthWarningAlert event) {
  final reminder = event.reminder;
  final rows = <List<String>>[
    ['项目', '内容'],
    ['记录类型', reminder?.kind.label ?? '历史提醒（旧规则）'],
    [
      '记录时间',
      (reminder?.recordedAt ?? event.triggeredAt).toUtc().toIso8601String(),
    ],
    ['测量时间', reminder?.measuredAt?.toUtc().toIso8601String() ?? '未记录'],
    ['来源', reminder?.deviceName ?? event.origin.label],
    if (reminder?.reading != null)
      [
        switch (reminder!.kind) {
          HealthReminderKind.lowBloodOxygen => '血氧（%）',
          HealthReminderKind.lowHrv => 'HRV（ms）',
          HealthReminderKind.highSkinTemperature => '皮肤温度（℃）',
          _ => '心率（bpm）',
        },
        '${reminder.reading}',
      ],
    if (reminder?.threshold != null) ['设定阈值', '${reminder!.threshold}'],
    if (reminder?.baselineValue != null)
      ['个人参考值', '${reminder!.baselineValue}'],
    ['说明', event.message],
    ['规则版本', reminder?.ruleVersion ?? '未提供'],
    [
      '症状反馈',
      reminder == null || reminder.symptoms.isEmpty
          ? '未记录'
          : reminder.symptoms.map((item) => item.label).join('、'),
    ],
    ['知晓时间', reminder?.acknowledgedAt?.toUtc().toIso8601String() ?? '未记录'],
    ['拨号发起时间', reminder?.dialRequestedAt?.toUtc().toIso8601String() ?? '未记录'],
    [
      '手机通知请求时间',
      reminder?.notificationRequestedAt?.toUtc().toIso8601String() ?? '未记录',
    ],
    ['通知说明', '已请求不代表系统实际展示或用户已经收到'],
    ['拨号说明', '打开拨号界面不代表已接通或救援已受理'],
    ['用途说明', '本记录不用于诊断或排除心肌梗死等疾病；没有提醒不代表没有风险'],
  ];
  String cell(String value) {
    // CSV formula injection is possible even in a quoted spreadsheet cell.
    final safe = RegExp(r'^[\s]*[=+@\-\t\r]').hasMatch(value)
        ? "'$value"
        : value;
    return '"${safe.replaceAll('"', '""')}"';
  }

  return '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}\r\n';
}
