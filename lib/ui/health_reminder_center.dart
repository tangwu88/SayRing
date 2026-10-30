import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/health_reminder.dart';
import '../domain/models.dart';
import '../domain/feature_models.dart';
import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';
import '../services/health_reminder_notifications.dart';
import 'app_theme.dart';
import 'reading_reminder_widgets.dart';
import 'prototype_pages.dart' show DeviceFeaturePage, RingReminderView;

String _copy(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
String _time(DateTime? value) => value == null
    ? '—'
    : DateFormat('yyyy-MM-dd HH:mm:ss').format(value.toLocal());

Future<bool> openHealthReminderDialler(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// A static urgent-help route. It needs no account, ring, API or location grant.
class EmergencyHelpPage extends StatefulWidget {
  const EmergencyHelpPage({
    super.key,
    this.onDiallerOpened,
    this.dialler = openHealthReminderDialler,
  });
  final Future<void> Function()? onDiallerOpened;
  final Future<bool> Function(Uri) dialler;

  @override
  State<EmergencyHelpPage> createState() => _EmergencyHelpPageState();
}

class _EmergencyHelpPageState extends State<EmergencyHelpPage> {
  String? _region;
  bool _opening = false;

  Future<void> _dial() async {
    if (_opening || _region == null) return;
    final number = _region == 'CN' ? '120' : '911';
    setState(() => _opening = true);
    try {
      final opened = await widget.dialler(Uri(scheme: 'tel', path: number));
      if (opened) {
        await widget.onDiallerOpened?.call();
      } else if (mounted) {
        _message(
          _copy(
            context,
            '无法打开拨号界面，请使用手机拨打 $number。',
            'Unable to open the dialler. Call $number using your phone.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _message(
          _copy(
            context,
            '无法打开拨号界面，请使用手机拨打 $number。',
            'Unable to open the dialler. Call $number using your phone.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_copy(context, '急症求助', 'Urgent help'))),
    body: ListView(
      key: const Key('emergency-help-page'),
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(
          Icons.emergency_outlined,
          size: 48,
          color: SaydianColors.danger,
        ),
        const SizedBox(height: 16),
        Text(
          _copy(
            context,
            '有严重不适时，请立即寻求急救帮助',
            'Seek emergency help for serious symptoms',
          ),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('emergency-region'),
          initialValue: _region,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _copy(context, '确认您所在地区', 'Confirm your location'),
          ),
          items: [
            DropdownMenuItem(
              value: 'CN',
              child: Text(_copy(context, '中国大陆 · 120', 'Mainland China · 120')),
            ),
            DropdownMenuItem(
              value: 'US',
              child: Text(_copy(context, '美国 · 911', 'United States · 911')),
            ),
          ],
          onChanged: _opening
              ? null
              : (value) => setState(() => _region = value),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('emergency-dial'),
          style: FilledButton.styleFrom(
            backgroundColor: SaydianColors.danger,
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: _region == null || _opening ? null : _dial,
          icon: const Icon(Icons.phone_in_talk_outlined),
          label: Text(
            _copy(
              context,
              '打开急救拨号${_region == null ? '' : ' · ${_region == 'CN' ? '120' : '911'}'}',
              'Open emergency dialler${_region == null ? '' : ' · ${_region == 'CN' ? '120' : '911'}'}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _copy(
            context,
            '如出现胸部不适、明显气短、晕厥等警示症状，请及时联系当地急救服务。不要等待戒指再次测量，也不要因读数正常而延迟求助。',
            'For warning symptoms such as chest discomfort, severe shortness of breath or fainting, contact local emergency services promptly. Do not wait for another ring reading or delay because a reading looks normal.',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _copy(
            context,
            '其他地区请使用当地急救号码。打开拨号界面不代表已经接通或救援已受理。',
            'Elsewhere, use the local emergency number. Opening the dialler does not confirm a connected call or accepted rescue request.',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _copy(
            context,
            '戒指不能诊断或排除心肌梗死。本页不提供药物或剂量建议。',
            'The ring cannot diagnose or rule out a heart attack. This page does not provide medication or dosage advice.',
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(_copy(context, '信息来源', 'Sources')),
          children: [
            _SourceLink(
              label: _copy(
                context,
                '国家卫健委 · 急救电话说明',
                'National Health Commission · Emergency calls',
              ),
              url:
                  'https://www.nhc.gov.cn/xcs/c100122/202405/f251e896a50a49ff8c632b4b3da93126/files/1734001844015_12363.pdf',
            ),
            const _SourceLink(
              label: 'American Heart Association',
              url:
                  'https://www.heart.org/en/health-topics/heart-attack/warning-signs-of-a-heart-attack',
            ),
            const _SourceLink(
              label: '911.gov',
              url: 'https://www.911.gov/calling-911/',
            ),
          ],
        ),
      ],
    ),
  );
}

class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.label, required this.url});
  final String label;
  final String url;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () async {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {
        /* Help and dialler remain usable offline. */
      }
    },
    child: Text(label),
  );
}

class UrgentHelpCard extends StatelessWidget {
  const UrgentHelpCard({
    super.key,
    this.onDiallerOpened,
    this.compact = false,
    this.terse = false,
  });
  final Future<void> Function()? onDiallerOpened;
  final bool compact;
  final bool terse;
  @override
  Widget build(BuildContext context) => compact
      ? Card(
          color: const Color(0xFFFFF1EE),
          child: ListTile(
            key: const Key('health-reminder-urgent-help'),
            leading: const Icon(
              Icons.emergency_outlined,
              color: SaydianColors.danger,
            ),
            title: Text(
              _copy(context, '急症求助', 'Urgent help'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: terse
                ? null
                : Text(
                    _copy(
                      context,
                      '严重不适时，不要等待复测。',
                      'Serious symptoms? Do not wait for another reading.',
                    ),
                  ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    EmergencyHelpPage(onDiallerOpened: onDiallerOpened),
              ),
            ),
          ),
        )
      : Card(
          color: const Color(0xFFFFF1EE),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.emergency_outlined,
                  color: SaydianColors.danger,
                  size: 30,
                ),
                const SizedBox(height: 10),
                Text(
                  _copy(context, '严重不适，优先求助', 'Serious symptoms come first'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('health-reminder-urgent-help'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          EmergencyHelpPage(onDiallerOpened: onDiallerOpened),
                    ),
                  ),
                  icon: const Icon(Icons.phone_in_talk_outlined),
                  label: Text(_copy(context, '急症求助', 'Urgent help')),
                ),
                const SizedBox(height: 8),
                Text(
                  _copy(
                    context,
                    '胸部不适、明显气短或晕厥时，不要等待戒指复测。',
                    'For chest discomfort, severe breathlessness or fainting, do not wait for another ring reading.',
                  ),
                ),
              ],
            ),
          ),
        );
}

class HealthReminderShortcut extends StatelessWidget {
  const HealthReminderShortcut({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: const Key('health-reminder-entry'),
      leading: const Icon(
        Icons.monitor_heart_outlined,
        color: SaydianColors.danger,
        size: 30,
      ),
      title: Text(
        context.l10n.healthAlerts,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        _copy(context, '异常记录与急症求助', 'Event records and urgent help'),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HealthReminderCenterPage(controller: controller),
        ),
      ),
    ),
  );
}

class HealthReminderCenterPage extends StatefulWidget {
  const HealthReminderCenterPage({
    required this.controller,
    this.targetReminderId,
    super.key,
  });
  final AppController controller;
  final String? targetReminderId;
  @override
  State<HealthReminderCenterPage> createState() =>
      _HealthReminderCenterPageState();
}

class _HealthReminderCenterPageState extends State<HealthReminderCenterPage> {
  String? _ringReadContext;
  bool _ringReadScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    unawaited(widget.controller.refreshHealthReminderPermissions());
    _scheduleRingReminderRead();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.controller.canOpenHealthReminderEvent(
            widget.targetReminderId,
          )) {
        _openEvent(widget.targetReminderId!);
      }
    });
  }

  void _refresh() {
    if (!mounted) return;
    if (!widget.controller
        .availabilityFor(DeviceFeature.healthReminders)
        .isReady) {
      _ringReadContext = null;
    }
    setState(() {});
    _scheduleRingReminderRead();
  }

  void _scheduleRingReminderRead() {
    if (_ringReadScheduled) return;
    _ringReadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ringReadScheduled = false;
      if (!mounted) return;
      final controller = widget.controller;
      if (!controller.availabilityFor(DeviceFeature.healthReminders).isReady) {
        _ringReadContext = null;
        return;
      }
      final contextKey =
          '${controller.homeHealthCardOwner}\u0000${controller.connectedDevice!.id}';
      if (_ringReadContext == contextKey) return;
      _ringReadContext = contextKey;
      final cached =
          controller.deviceFeatureData[DeviceFeature.healthReminders];
      if (cached?['items'] is List) return;
      // One guarded read per connection/account context; no writes or retry loop.
      unawaited(controller.readDeviceFeature(DeviceFeature.healthReminders));
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _openEvent(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          HealthReminderDetailPage(controller: widget.controller, eventId: id),
    ),
  );

  Widget _ringReminderSettings() {
    final controller = widget.controller;
    final available =
        controller.connectedDevice != null &&
        controller.availabilityFor(DeviceFeature.healthReminders).isReady;
    if (!available) return const SizedBox.shrink();
    final raw =
        controller.deviceFeatureData[DeviceFeature.healthReminders]?['items'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map((item) => item.map((key, value) => MapEntry('$key', value)))
              .where(canDisplayRingReminder)
              .toList(growable: false)
        : const <Map<String, Object?>>[];
    final sedentary = items.any((item) => item['id'] == 'sedentary');
    final other = items.any((item) => item['id'] != 'sedentary');
    if (!sedentary && !other) return const SizedBox.shrink();
    void open(RingReminderView view) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'health-reminder-ring-${view.name}'),
        builder: (_) => DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.healthReminders,
          reminderView: view,
        ),
      ),
    );
    return Card(
      key: const Key('health-reminder-ring-settings'),
      child: Column(
        children: [
          if (sedentary)
            ListTile(
              key: const Key('health-reminder-sedentary'),
              leading: const Icon(Icons.airline_seat_recline_normal_rounded),
              title: Text(_copy(context, '久坐提醒', 'Sedentary reminder')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(RingReminderView.sedentary),
            ),
          if (sedentary && other) const Divider(height: 1, indent: 56),
          if (other)
            ListTile(
              key: const Key('health-reminder-other-ring-settings'),
              leading: const Icon(Icons.event_available_outlined),
              title: Text(_copy(context, '其他日常提醒', 'Other daily reminders')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(RingReminderView.other),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final events = controller.healthReminderEvents;
    final permission = controller.healthReminderNotificationPermission;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.healthAlerts)),
      body: ListView(
        key: const Key('health-reminder-center'),
        padding: const EdgeInsets.all(16),
        children: [
          const UrgentHelpCard(compact: true, terse: true),
          const SizedBox(height: 12),
          ReadingReminderSettingsPanel(
            controller: controller,
            onHelp: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EmergencyHelpPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ringReminderSettings(),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns =
                  constraints.maxWidth >= 340 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 20;
              final width = twoColumns
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: OutlinedButton.icon(
                      key: const Key('health-reminder-notification-permission'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: () async {
                        if (permission ==
                            ReminderNotificationPermission.denied) {
                          await openAppSettings();
                        } else {
                          await controller.refreshHealthReminderPermissions(
                            request: true,
                          );
                        }
                      },
                      icon: Icon(
                        permission == ReminderNotificationPermission.granted
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        size: 18,
                      ),
                      label: Text(
                        permission == ReminderNotificationPermission.granted
                            ? _copy(context, '通知已允许', 'Notifications on')
                            : _copy(context, '手机通知', 'Phone notifications'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: OutlinedButton.icon(
                      key: const Key('health-reminder-record-symptoms'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HealthReminderSymptomsPage(
                            controller: controller,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: Text(_copy(context, '记录不适', 'Record symptoms')),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            _copy(context, '本机记录', 'Local records'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(_copy(context, '暂无提醒记录', 'No reminder records yet')),
            ),
          for (final event in events)
            Card(
              child: ListTile(
                key: ValueKey('health-reminder-event-${event.id}'),
                leading: Icon(switch (event.reminder!.kind) {
                  HealthReminderKind.symptoms => Icons.edit_note,
                  HealthReminderKind.lowBloodOxygen =>
                    Icons.water_drop_outlined,
                  HealthReminderKind.lowHrv =>
                    Icons.battery_charging_full_rounded,
                  HealthReminderKind.highSkinTemperature =>
                    Icons.thermostat_rounded,
                  _ => Icons.monitor_heart_outlined,
                }, color: SaydianColors.danger),
                title: Text(event.title),
                subtitle: Text(
                  '${_time(event.reminder!.recordedAt)}\n${event.message}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openEvent(event.id),
              ),
            ),
          if (controller.healthWarningAlerts.any(
            (event) => event.reminder == null,
          ))
            ExpansionTile(
              title: Text(
                _copy(
                  context,
                  '历史提醒（旧规则）',
                  'Historical reminders (previous rules)',
                ),
              ),
              children: [
                for (final event in controller.healthWarningAlerts.where(
                  (event) => event.reminder == null,
                ))
                  ListTile(
                    title: Text(event.title.replaceAll('健康预警', '健康提醒')),
                    subtitle: Text(
                      '${_time(event.triggeredAt)}\n${event.message}\n${_copy(context, '历史记录不代表当前异常。', 'A historical record is not a current event.')}',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class HealthReminderSymptomsPage extends StatefulWidget {
  const HealthReminderSymptomsPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<HealthReminderSymptomsPage> createState() =>
      _HealthReminderSymptomsPageState();
}

class _HealthReminderSymptomsPageState
    extends State<HealthReminderSymptomsPage> {
  final _symptoms = <HealthReminderSymptom>{};
  bool _saving = false;
  late final String _owner;

  @override
  void initState() {
    super.initState();
    _owner = widget.controller.homeHealthCardOwner;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(_copy(context, '记录当前不适', 'Record symptoms'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const UrgentHelpCard(),
          const SizedBox(height: 16),
          Text(
            _copy(
              context,
              '先求助，再记录。保存不是求助的前置条件。',
              'Get help first. Saving a record is not required to seek help.',
            ),
          ),
          const SizedBox(height: 12),
          for (final symptom in HealthReminderSymptom.values)
            CheckboxListTile(
              key: ValueKey('health-reminder-symptom-${symptom.wireName}'),
              value: _symptoms.contains(symptom),
              title: Text(
                _copy(context, symptom.label, switch (symptom) {
                  HealthReminderSymptom.chestDiscomfort => 'Chest discomfort',
                  HealthReminderSymptom.breathlessness =>
                    'Severe breathlessness',
                  HealthReminderSymptom.faintness =>
                    'Fainting or near-fainting',
                }),
              ),
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        _symptoms.add(symptom);
                      } else {
                        _symptoms.remove(symptom);
                      }
                    }),
            ),
          if (!widget.controller.canSaveHealthReminder)
            Text(
              _copy(
                context,
                '登录后可保存本机记录；急症求助无需登录。',
                'Sign in to save records. Urgent help never requires sign-in.',
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('health-reminder-save-symptoms'),
            onPressed:
                _saving ||
                    _symptoms.isEmpty ||
                    !widget.controller.canSaveHealthReminder ||
                    _owner != widget.controller.homeHealthCardOwner
                ? null
                : () async {
                    setState(() => _saving = true);
                    final event = await widget.controller
                        .recordHealthReminderSymptoms(_symptoms);
                    if (!context.mounted) return;
                    setState(() => _saving = false);
                    if (event != null &&
                        _owner == widget.controller.homeHealthCardOwner) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => HealthReminderDetailPage(
                            controller: widget.controller,
                            eventId: event.id,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _copy(
                              context,
                              '记录未保存，请稍后重试。求助入口仍可使用。',
                              'The record was not saved. Urgent help is still available.',
                            ),
                          ),
                        ),
                      );
                    }
                  },
            child: Text(_copy(context, '保存到本机', 'Save locally')),
          ),
        ],
      ),
    ),
  );
}

class HealthReminderDetailPage extends StatefulWidget {
  const HealthReminderDetailPage({
    required this.controller,
    required this.eventId,
    super.key,
  });
  final AppController controller;
  final String eventId;
  @override
  State<HealthReminderDetailPage> createState() =>
      _HealthReminderDetailPageState();
}

class _HealthReminderDetailPageState extends State<HealthReminderDetailPage> {
  late final String _owner;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _owner = widget.controller.homeHealthCardOwner;
  }

  Future<void> _share() async {
    final csv = widget.controller.healthReminderCsv(
      widget.eventId,
      expectedOwner: _owner,
    );
    if (csv == null || _busy) return;
    setState(() => _busy = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv')],
          fileNameOverrides: ['SayRing-health-reminder.csv'],
          subject: _copy(
            context,
            'Say Ring 健康提醒记录',
            'Say Ring health reminder record',
          ),
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copy(
                context,
                '导出未完成，请稍后重试。',
                'Export was not completed. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final event = _owner == widget.controller.homeHealthCardOwner
          ? widget.controller.healthReminderEvents
                .where((item) => item.id == widget.eventId)
                .firstOrNull
          : null;
      return Scaffold(
        appBar: AppBar(title: Text(_copy(context, '提醒详情', 'Reminder details'))),
        body: event == null
            ? Center(
                child: Text(_copy(context, '记录暂不可用', 'Record unavailable')),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  UrgentHelpCard(
                    onDiallerOpened: () async {
                      await widget.controller.updateHealthReminderAction(
                        widget.eventId,
                        expectedOwner: _owner,
                        dialRequested: true,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (event.reminder!.baselineValue != null &&
                              event.reminder!.reading != null) ...[
                            Text(
                              '${event.reminder!.reading!.toStringAsFixed(event.metric == HealthMetric.bodyTemperature ? 1 : 0)} ${event.metric.defaultUnit}',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _copy(
                                context,
                                '个人参考 ${event.reminder!.baselineValue!.toStringAsFixed(event.metric == HealthMetric.bodyTemperature ? 1 : 0)} ${event.metric.defaultUnit}',
                                'Personal reference ${event.reminder!.baselineValue!.toStringAsFixed(event.metric == HealthMetric.bodyTemperature ? 1 : 0)} ${event.metric.defaultUnit}',
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            event.message,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _copy(
                              context,
                              '来源：${event.reminder!.deviceName ?? event.origin.label}',
                              'Source: ${event.reminder!.deviceName ?? event.origin.label}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TimelineRow(
                    icon: Icons.monitor_heart_outlined,
                    label: _copy(context, '测量时间', 'Measured'),
                    value: _time(event.reminder!.measuredAt),
                  ),
                  _TimelineRow(
                    icon: Icons.note_add_outlined,
                    label: _copy(context, '记录时间', 'Recorded'),
                    value: _time(event.reminder!.recordedAt),
                  ),
                  _TimelineRow(
                    icon: Icons.visibility_outlined,
                    label: _copy(context, '已知晓', 'Acknowledged'),
                    value: _time(event.reminder!.acknowledgedAt),
                  ),
                  _TimelineRow(
                    icon: Icons.phone_outlined,
                    label: _copy(context, '拨号已发起', 'Dialler opened'),
                    value: _time(event.reminder!.dialRequestedAt),
                  ),
                  if (event.reminder!.notificationRequestedAt != null)
                    _TimelineRow(
                      icon: Icons.notifications_outlined,
                      label: _copy(
                        context,
                        '手机通知已请求',
                        'Notification requested',
                      ),
                      value: _time(event.reminder!.notificationRequestedAt),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _copy(
                      context,
                      '知晓不代表异常已经消失，发起拨号不代表已经接通或获救。',
                      'Acknowledgement does not mean recovery. Opening the dialler does not confirm a call or rescue.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('health-reminder-acknowledge'),
                    onPressed: event.reminder!.acknowledgedAt != null
                        ? null
                        : () async {
                            await widget.controller.updateHealthReminderAction(
                              event.id,
                              expectedOwner: _owner,
                              acknowledged: true,
                            );
                          },
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(_copy(context, '我已知晓', 'Acknowledge')),
                  ),
                  OutlinedButton.icon(
                    key: const Key('health-reminder-export'),
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.ios_share),
                    label: Text(
                      _copy(context, '导出本条记录 CSV', 'Export this record as CSV'),
                    ),
                  ),
                  TextButton(
                    key: const Key('health-reminder-delete'),
                    onPressed: _busy
                        ? null
                        : () async {
                            final approved = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                  _copy(
                                    context,
                                    '删除本机记录',
                                    'Delete local record',
                                  ),
                                ),
                                content: Text(
                                  _copy(
                                    context,
                                    '这会删除本条记录及其处理状态，已导出的文件需您自行管理。',
                                    'This removes this record and its action history. Files you exported are managed separately.',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(_copy(context, '取消', 'Cancel')),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(_copy(context, '删除', 'Delete')),
                                  ),
                                ],
                              ),
                            );
                            if (approved != true) return;
                            final deleted = await widget.controller
                                .deleteHealthReminder(
                                  event.id,
                                  expectedOwner: _owner,
                                );
                            if (context.mounted && deleted) {
                              Navigator.pop(context);
                            }
                          },
                    child: Text(
                      _copy(context, '删除本机记录', 'Delete local record'),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    leading: Icon(icon, color: SaydianColors.techBlue),
    title: Text(label),
    subtitle: Text(value),
  );
}
