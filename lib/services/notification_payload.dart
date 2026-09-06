/// Converts both deployed notification contracts to the existing inbox format.
/// Only routing identifiers survive; notification text is fetched after login.
Map<String, Object?>? normalizeNotificationBusinessPayload(
  Map<String, Object?> source, {
  required DateTime receivedAt,
}) {
  try {
    Object? alias(String first, String second) {
      final a = source[first];
      final b = source[second];
      if (a != null && b != null && '$a' != '$b') {
        throw const FormatException('Conflicting notification fields');
      }
      return a ?? b;
    }

    String? identifier(Object? value) {
      if (value == null) return null;
      final text = switch (value) {
        String value => value.trim(),
        int value => '$value',
        _ => '',
      };
      if (!RegExp(r'^[A-Za-z0-9._:-]{1,160}$').hasMatch(text)) {
        throw const FormatException('Invalid notification identifier');
      }
      return text;
    }

    final version = alias('schema_version', 'schemaVersion') ?? 1;
    if ('$version' != '1') return null;
    final rawType = alias('event_type', 'type');
    var type = rawType is String ? rawType.trim().toLowerCase() : '';
    if (type == 'care_invitation_created') type = 'care_invitation';
    if (type == 'health_alert') type = 'health_warning';
    var entityId = identifier(alias('entity_id', 'entityId'));
    final routeValue = alias('route', 'deepLink');
    if (routeValue != null) {
      if (routeValue is! String) return null;
      final route = routeValue.trim();
      final match = RegExp(
        r'^/(care/invitations|health/alerts|health/warnings)(?:/([A-Za-z0-9._:-]{1,160}))?$',
      ).firstMatch(route);
      final routeType = switch (route) {
        'care-invitations' || 'care_invitation_review' => 'care_invitation',
        'health-alerts' || 'health_warning_history' => 'health_warning',
        'notification_inbox' || '/notifications' || '/messages' => 'system',
        _ when match != null =>
          match.group(1) == 'care/invitations'
              ? 'care_invitation'
              : 'health_warning',
        _ => '',
      };
      if (routeType.isEmpty || (type.isNotEmpty && type != routeType)) {
        return null;
      }
      type = routeType;
      final routeEntity = match?.group(2);
      if (entityId != null && routeEntity != null && entityId != routeEntity) {
        return null;
      }
      entityId ??= routeEntity;
    }
    if (!const ['care_invitation', 'health_warning', 'system'].contains(type)) {
      return null;
    }
    final eventId = identifier(alias('event_id', 'eventId'));
    return {
      'schema_version': 1,
      'event_id': ?eventId,
      'event_type': type,
      'entity_id': ?entityId,
      'created_at':
          alias('created_at', 'createdAt') ??
          receivedAt.toUtc().toIso8601String(),
    };
  } on FormatException {
    return null;
  }
}
