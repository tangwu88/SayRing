enum NotificationEventType {
  careInvitation,
  healthWarning,
  system;

  String get wireName => switch (this) {
    careInvitation => 'care_invitation',
    healthWarning => 'health_warning',
    system => 'system',
  };
}

enum NotificationEventSource {
  device,
  server,
  polling,
  local;

  String get wireName => name;
}

final class NotificationEvent {
  const NotificationEvent._({
    required this.eventId,
    required this.type,
    required this.createdAt,
    required this.source,
    this.entityId,
    this.remoteEventId,
    this.readAt,
  });

  static const schemaVersion = 1;

  final String eventId;
  final NotificationEventType type;
  final String? entityId;
  final String? remoteEventId;
  final DateTime createdAt;
  final NotificationEventSource source;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  static NotificationEvent? tryParse(Map<Object?, Object?> payload) {
    final version = _parseInteger(payload['schema_version'] ?? schemaVersion);
    if (version != schemaVersion) return null;

    final type = _parseEventType(payload['event_type']);
    final createdAt = _parseTimestamp(payload['created_at']);
    if (type == null || createdAt == null) return null;

    final rawEntityId = payload['entity_id'];
    final entityId = rawEntityId == null
        ? null
        : _parseSafeIdentifier(rawEntityId, maxLength: 160);
    if (rawEntityId != null && entityId == null) return null;
    if ((type == NotificationEventType.careInvitation ||
            type == NotificationEventType.healthWarning) &&
        entityId == null) {
      return null;
    }

    final rawEventId = payload['event_id'];
    var eventId = rawEventId == null
        ? null
        : _parseSafeIdentifier(rawEventId, maxLength: 160);
    if (rawEventId != null && eventId == null) return null;
    eventId ??= _deriveLegacyEventId(
      type: type,
      entityId: entityId,
      createdAt: createdAt,
    );
    if (eventId == null) return null;

    final rawReadAt = payload['read_at'];
    final readAt = rawReadAt == null ? null : _parseTimestamp(rawReadAt);
    if (rawReadAt != null && readAt == null) return null;

    final source = _parseEventSource(payload['source']);
    final rawRemoteEventId = payload['remote_event_id'];
    final remoteEventId = rawRemoteEventId == null
        ? null
        : _parseSafeIdentifier(rawRemoteEventId, maxLength: 160);
    if (rawRemoteEventId != null && remoteEventId == null) return null;

    return NotificationEvent._(
      eventId: eventId,
      type: type,
      entityId: entityId,
      remoteEventId: remoteEventId,
      createdAt: createdAt,
      source: source,
      readAt: readAt,
    );
  }

  NotificationEvent withReadAt(DateTime value) => NotificationEvent._(
    eventId: eventId,
    type: type,
    entityId: entityId,
    remoteEventId: remoteEventId,
    createdAt: createdAt,
    source: source,
    readAt: _toUtcSecond(value),
  );

  NotificationEvent withRemoteEventId(String value) => NotificationEvent._(
    eventId: eventId,
    type: type,
    entityId: entityId,
    remoteEventId: value,
    createdAt: createdAt,
    source: source,
    readAt: readAt,
  );

  String get targetRoute => switch (type) {
    NotificationEventType.careInvitation => 'care_invitation_review',
    NotificationEventType.healthWarning => 'health_warning_history',
    NotificationEventType.system => 'notification_inbox',
  };

  Map<String, Object?> toPersistenceMap() => <String, Object?>{
    'schema_version': schemaVersion,
    'event_id': eventId,
    'event_type': type.wireName,
    'source': source.wireName,
    'target_route': targetRoute,
    if (entityId != null) 'entity_id': entityId,
    if (remoteEventId != null) 'remote_event_id': remoteEventId,
    'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
    if (readAt != null) 'read_at': readAt!.millisecondsSinceEpoch ~/ 1000,
  };
}

NotificationEventSource _parseEventSource(Object? value) {
  final normalized = value is String ? value.trim().toLowerCase() : '';
  return switch (normalized) {
    'device' => NotificationEventSource.device,
    'polling' || 'poll' => NotificationEventSource.polling,
    'local' => NotificationEventSource.local,
    _ => NotificationEventSource.server,
  };
}

NotificationEventType? _parseEventType(Object? value) {
  final normalized = value is String ? value.trim().toLowerCase() : '';
  return switch (normalized) {
    'care_invitation' ||
    'care_invitation_created' => NotificationEventType.careInvitation,
    'health_warning' || 'health_alert' => NotificationEventType.healthWarning,
    'system' => NotificationEventType.system,
    _ => null,
  };
}

String? _parseSafeIdentifier(Object? value, {required int maxLength}) {
  final normalized = switch (value) {
    String text => text.trim(),
    int number => '$number',
    _ => '',
  };
  if (normalized.isEmpty || normalized.length > maxLength) return null;
  return RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(normalized) ? normalized : null;
}

int? _parseInteger(Object? value) => switch (value) {
  int number => number,
  num number when number.isFinite && number == number.toInt() => number.toInt(),
  String text => int.tryParse(text.trim()),
  _ => null,
};

DateTime? _parseTimestamp(Object? value) {
  if (value is num) {
    if (!value.isFinite || value != value.toInt()) return null;
    return _dateTimeFromEpoch(value.toInt());
  }
  if (value is! String) return null;
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  final epoch = int.tryParse(normalized);
  if (epoch != null) return _dateTimeFromEpoch(epoch);
  if (!RegExp(
    r'(?:Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(normalized)) {
    return null;
  }
  final parsed = DateTime.tryParse(normalized);
  return parsed == null ? null : _toUtcSecond(parsed);
}

DateTime? _dateTimeFromEpoch(int value) {
  final milliseconds = value.abs() >= 100000000000 ? value : value * 1000;
  try {
    return _toUtcSecond(
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
    );
  } on ArgumentError {
    return null;
  }
}

DateTime _toUtcSecond(DateTime value) {
  final utc = value.toUtc();
  return DateTime.fromMillisecondsSinceEpoch(
    (utc.millisecondsSinceEpoch ~/ 1000) * 1000,
    isUtc: true,
  );
}

String? _deriveLegacyEventId({
  required NotificationEventType type,
  required String? entityId,
  required DateTime createdAt,
}) {
  if (entityId == null) return null;
  final source = '${type.wireName}|$entityId';
  var hash = 0x811c9dc5;
  for (final codeUnit in source.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final encodedHash = hash.toRadixString(16).padLeft(8, '0');
  final epochSeconds = createdAt.millisecondsSinceEpoch ~/ 1000;
  return 'legacy-$epochSeconds-$encodedHash';
}
