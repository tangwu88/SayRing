import 'notification_models.dart';

enum NotificationRouteTarget {
  careInvitationReview,
  healthWarningHistory,
  cycleTracking,
  supportConversation,
  notificationInbox,
  ringCareInteraction,
  ringShares,
}

final class NotificationRouteIntent {
  const NotificationRouteIntent({
    required this.target,
    required this.eventId,
    this.entityId,
  });

  final NotificationRouteTarget target;
  final String eventId;
  final String? entityId;
}

String? supportConversationFromLink(Object? link) => link is String
    ? RegExp(
        r'^/support/conversations/([a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12})$',
      ).firstMatch(link)?.group(1)
    : null;

String? supportConversationForEvent(NotificationEvent event) {
  if (event.type != NotificationEventType.system ||
      !RegExp(r'^support-reply:[a-fA-F0-9-]{36}$').hasMatch(event.eventId)) {
    return null;
  }
  return supportConversationFromLink(
    '/support/conversations/${event.entityId ?? ''}',
  );
}

String? ringCareRelationshipFromLink(Object? link) => link is String
    ? RegExp(
        r'^/care/interactions/([a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12})$',
      ).firstMatch(link)?.group(1)
    : null;

bool isRingCareNotice(String eventId) =>
    RegExp(r'^ring-(care|joined):[a-fA-F0-9-]{36}$').hasMatch(eventId);

bool isRingShareNotice(String eventId) =>
    RegExp(r'^ring-share:[a-fA-F0-9-]{36}$').hasMatch(eventId);

final class NotificationRouteService {
  const NotificationRouteService();

  NotificationRouteIntent resolve(NotificationEvent event) =>
      NotificationRouteIntent(
        target: switch (event.type) {
          NotificationEventType.careInvitation =>
            NotificationRouteTarget.careInvitationReview,
          NotificationEventType.healthWarning =>
            NotificationRouteTarget.healthWarningHistory,
          NotificationEventType.system when isRingShareNotice(event.eventId) =>
            NotificationRouteTarget.ringShares,
          NotificationEventType.system
              when isRingCareNotice(event.eventId) &&
                  ringCareRelationshipFromLink(
                        '/care/interactions/${event.entityId ?? ''}',
                      ) !=
                      null =>
            NotificationRouteTarget.ringCareInteraction,
          NotificationEventType.system =>
            supportConversationForEvent(event) == null
                ? NotificationRouteTarget.notificationInbox
                : NotificationRouteTarget.supportConversation,
        },
        eventId: event.eventId,
        entityId: event.entityId,
      );
}
