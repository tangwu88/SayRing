import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/app_controller.dart';
import '../../services/notification_models.dart';
import '../../l10n/global_locale_controller.dart';
import '../app_theme.dart';
import '../prototype_pages.dart';
import '../widgets/inline_notice.dart';
import '../html_text.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshNotifications());
  }

  Future<void> _openItem(Map<String, Object?> item) async {
    final eventId = '${item['event_id'] ?? ''}'.trim();
    if (eventId.isNotEmpty) {
      await widget.controller.markNotificationEventRead(eventId);
    }
    if (!mounted) return;
    final eventType = '${item['_eventType'] ?? ''}';
    if (eventType == NotificationEventType.careInvitation.name) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CareInvitationsPage(
            controller: widget.controller,
            targetInvitationId: '${item['entity_id'] ?? ''}'.trim(),
          ),
        ),
      );
      return;
    }
    final id = int.tryParse('${item['id'] ?? ''}');
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailPage(
          controller: widget.controller,
          id: id,
          initial: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.messages)),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final healthWarnings = widget.controller.healthWarningAlerts
              .asMap()
              .entries
              .map((entry) {
                final eventId = widget.controller.healthWarningEventId(
                  entry.value,
                );
                final matchingEvents = widget.controller.notificationInboxEvents
                    .where((item) => item.eventId == eventId)
                    .toList(growable: false);
                final event = matchingEvents.isEmpty
                    ? null
                    : matchingEvents.first;
                return <String, Object?>{
                  'id': -(entry.key + 1),
                  '_localHealthWarning': true,
                  '_localNotification': true,
                  '_eventType': NotificationEventType.healthWarning.name,
                  'event_id': eventId,
                  'is_read': event?.isRead ?? true,
                  'title': entry.value.title,
                  'content': entry.value.message,
                  'created_at': DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(entry.value.triggeredAt.toLocal()),
                  'kind': 'health_warning',
                };
              })
              .toList(growable: false);
          final healthEventIds = healthWarnings
              .map((item) => '${item['event_id'] ?? ''}')
              .toSet();
          final localEvents = widget.controller.notificationInboxEvents
              .where((event) => !healthEventIds.contains(event.eventId))
              .map(
                (event) => <String, Object?>{
                  'id': -((event.eventId.hashCode & 0x3fffffff) + 1000),
                  '_localNotification': true,
                  '_eventType': event.type.name,
                  'event_id': event.eventId,
                  'entity_id': event.entityId,
                  'is_read': event.isRead,
                  'title': switch (event.type) {
                    NotificationEventType.careInvitation => '关爱邀请',
                    NotificationEventType.healthWarning => '健康预警',
                    NotificationEventType.system => '系统消息',
                  },
                  'content': switch (event.type) {
                    NotificationEventType.careInvitation =>
                      '您有新的关爱请求，请点击查看最新状态。',
                    NotificationEventType.healthWarning => '有新的健康预警，请打开预警记录查看。',
                    NotificationEventType.system => '您有一条新消息。',
                  },
                  'created_at': DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(event.createdAt.toLocal()),
                  'kind': event.type == NotificationEventType.healthWarning
                      ? 'health_warning'
                      : event.type.wireName,
                },
              )
              .toList(growable: false);
          final localEventIds = <String>{
            ...healthEventIds,
            ...localEvents.map((item) => '${item['event_id'] ?? ''}'),
          };
          final remoteNotifications = widget.controller.notifications
              .where(
                (item) => !localEventIds.contains(
                  '${item['event_id'] ?? item['eventId'] ?? ''}',
                ),
              )
              .toList(growable: false);
          final values = <Map<String, Object?>>[
            ...healthWarnings,
            ...localEvents,
            ...remoteNotifications,
          ];
          final permissionCard =
              widget.controller.notificationServiceConfigured &&
                  !widget.controller.notificationPermissionEnabled
              ? Card(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: ListTile(
                    leading: const Icon(Icons.notifications_off_outlined),
                    title: Text(context.l10n.notificationsOff),
                    subtitle: Text(context.l10n.notificationInAppHint),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'request') {
                          unawaited(
                            widget.controller.requestNotificationPermission(),
                          );
                        } else {
                          unawaited(
                            widget.controller.openNotificationSettings(),
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'request', child: Text('允许通知')),
                        PopupMenuItem(value: 'settings', child: Text('系统设置')),
                      ],
                    ),
                  ),
                )
              : null;
          return Column(
            children: [
              ?permissionCard,
              Expanded(
                child: values.isEmpty
                    ? Center(
                        child: Text(
                          widget.controller.notificationStatus,
                          style: const TextStyle(color: SaydianColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: widget.controller.refreshNotifications,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: values.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = values[index];
                            final isHealthWarning =
                                item['kind'] == 'health_warning';
                            final unread = item['is_read'] == false;
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: () => unawaited(_openItem(item)),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: isHealthWarning
                                      ? SaydianColors.brandRedSoft
                                      : SaydianColors.techBlueSoft,
                                  foregroundColor: isHealthWarning
                                      ? SaydianColors.brandRed
                                      : SaydianColors.techBlue,
                                  child: Icon(
                                    isHealthWarning
                                        ? Icons.health_and_safety_rounded
                                        : Icons.notifications_none_rounded,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['title'] ?? item['name'] ?? '系统消息'}',
                                        style: TextStyle(
                                          fontWeight: unread
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (unread)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: CircleAvatar(
                                          radius: 4,
                                          backgroundColor:
                                              SaydianColors.brandRed,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  [
                                        _notificationPreview(item),
                                        notificationDisplayTime(
                                          item['created_at'] ??
                                              item['createdAt'],
                                        ),
                                      ]
                                      .where((value) => value.trim().isNotEmpty)
                                      .join('\n'),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Format real message timestamps in the phone's local timezone. Invalid or
/// missing timestamps stay absent rather than becoming the current time.
String notificationDisplayTime(Object? value) {
  final date = value is DateTime ? value : DateTime.tryParse('${value ?? ''}');
  return date == null
      ? ''
      : DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
}

class NotificationDetailPage extends StatefulWidget {
  const NotificationDetailPage({
    required this.controller,
    required this.id,
    required this.initial,
    super.key,
  });

  final AppController controller;
  final int id;
  final Map<String, Object?> initial;

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  late Map<String, Object?> _value = widget.initial;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.initial['_localNotification'] == true) return;
    final value = await widget.controller.loadNotification(widget.id);
    if (mounted && value.isNotEmpty) setState(() => _value = value);
  }

  @override
  Widget build(BuildContext context) {
    final title = '${_value['title'] ?? _value['name'] ?? '消息详情'}';
    final raw = '${_value['content'] ?? _value['description'] ?? ''}';
    final content = _resolveNotificationContent(_value, raw);
    final isHealthWarning = _value['kind'] == 'health_warning';
    final createdAt = notificationDisplayTime(
      _value['created_at'] ?? _value['createdAt'],
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.messageDetails)),
      backgroundColor: SaydianColors.canvas,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHealthWarning
                    ? const [SaydianColors.techIndigo, SaydianColors.techBlue]
                    : const [Color(0xFF233A70), SaydianColors.techBlueDark],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white.withValues(alpha: .16),
                  foregroundColor: Colors.white,
                  child: Icon(
                    isHealthWarning
                        ? Icons.health_and_safety_rounded
                        : Icons.mark_email_read_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (createdAt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          createdAt,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                content.isEmpty ? '暂无消息正文' : content,
                style: const TextStyle(fontSize: 16, height: 1.75),
              ),
            ),
          ),
          if (isHealthWarning) ...[
            const SizedBox(height: 12),
            InlineNotice(
              message: context.l10n.healthAlertSafetyHint,
              icon: Icons.info_outline_rounded,
              color: SaydianColors.orange,
            ),
          ],
        ],
      ),
    );
  }
}

String _notificationPreview(Map<String, Object?> value) {
  final raw = '${value['content'] ?? value['description'] ?? ''}';
  return _resolveNotificationContent(value, raw);
}

String _resolveNotificationContent(Map<String, Object?> value, String raw) {
  final orderNumber = _notificationOrderNumber(value);
  final fallback = orderNumber ?? '订单号暂未返回';
  return plainTextFromHtml(raw).replaceAll('#order_sn#', fallback);
}

String? _notificationOrderNumber(Object? value, [int depth = 0]) {
  if (depth > 5 || value == null) return null;
  if (value is Map) {
    for (final key in const ['order_sn', 'orderSn', 'order_no', 'orderNo']) {
      final text = '${value[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != '#order_sn#') return text;
    }
    for (final nested in value.values) {
      final result = _notificationOrderNumber(nested, depth + 1);
      if (result != null) return result;
    }
  } else if (value is Iterable) {
    for (final nested in value) {
      final result = _notificationOrderNumber(nested, depth + 1);
      if (result != null) return result;
    }
  } else if (value is String) {
    final text = value.trim();
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      try {
        return _notificationOrderNumber(jsonDecode(text), depth + 1);
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}
