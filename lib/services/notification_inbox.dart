import 'dart:async';

import 'notification_models.dart';

abstract interface class NotificationInboxStorage {
  Future<List<Map<String, Object?>>> readAll({String ownerId = 'default'});

  Future<void> replaceAll(
    List<Map<String, Object?>> rows, {
    String ownerId = 'default',
  });
}

abstract interface class NotificationInboxRepository {
  Future<List<NotificationEvent>> list();

  Future<NotificationEvent> upsert(NotificationEvent event);

  Future<NotificationEvent?> markRead({
    required String eventId,
    required DateTime readAt,
  });

  Future<int> unreadCount();

  Future<void> clear();
}

final class StoredNotificationInboxRepository
    implements NotificationInboxRepository {
  StoredNotificationInboxRepository(this._storage, {this.ownerId = 'default'})
    : assert(ownerId != '');

  final NotificationInboxStorage _storage;
  final String ownerId;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<List<NotificationEvent>> list() =>
      _runExclusive(() async => _loadDeduplicated());

  @override
  Future<NotificationEvent> upsert(NotificationEvent event) =>
      _runExclusive(() async {
        final events = await _loadDeduplicated();
        final index = events.indexWhere(
          (candidate) => candidate.eventId == event.eventId,
        );
        final merged = index < 0 ? event : _merge(events[index], event);
        if (index < 0) {
          events.add(merged);
        } else {
          events[index] = merged;
        }
        await _save(events);
        return merged;
      });

  @override
  Future<NotificationEvent?> markRead({
    required String eventId,
    required DateTime readAt,
  }) => _runExclusive(() async {
    final events = await _loadDeduplicated();
    final index = events.indexWhere(
      (candidate) => candidate.eventId == eventId,
    );
    if (index < 0) return null;
    final existing = events[index];
    final updated = existing.readAt == null
        ? existing.withReadAt(readAt)
        : existing;
    events[index] = updated;
    await _save(events);
    return updated;
  });

  @override
  Future<int> unreadCount() => _runExclusive(() async {
    final events = await _loadDeduplicated();
    return events.where((event) => !event.isRead).length;
  });

  @override
  Future<void> clear() =>
      _runExclusive(() => _storage.replaceAll(const [], ownerId: ownerId));

  Future<List<NotificationEvent>> _loadDeduplicated() async {
    final byId = <String, NotificationEvent>{};
    for (final row in await _storage.readAll(ownerId: ownerId)) {
      final parsed = NotificationEvent.tryParse(row);
      if (parsed == null) continue;
      final existing = byId[parsed.eventId];
      byId[parsed.eventId] = existing == null
          ? parsed
          : _merge(existing, parsed);
    }
    return byId.values.toList(growable: true)..sort(_newestFirst);
  }

  Future<void> _save(List<NotificationEvent> events) async {
    events.sort(_newestFirst);
    await _storage.replaceAll(
      events.map((event) => event.toPersistenceMap()).toList(growable: false),
      ownerId: ownerId,
    );
  }

  NotificationEvent _merge(
    NotificationEvent existing,
    NotificationEvent incoming,
  ) {
    var result = existing;
    if (result.remoteEventId == null && incoming.remoteEventId != null) {
      result = result.withRemoteEventId(incoming.remoteEventId!);
    }
    final incomingReadAt = incoming.readAt;
    if (result.readAt == null && incomingReadAt != null) {
      result = result.withReadAt(incomingReadAt);
    }
    return result;
  }

  int _newestFirst(NotificationEvent left, NotificationEvent right) {
    final byTime = right.createdAt.compareTo(left.createdAt);
    return byTime != 0 ? byTime : left.eventId.compareTo(right.eventId);
  }

  Future<T> _runExclusive<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}

final class MemoryNotificationInboxStorage implements NotificationInboxStorage {
  MemoryNotificationInboxStorage([
    Iterable<Map<String, Object?>> initialRows = const [],
  ]) : _rowsByOwner = <String, List<Map<String, Object?>>>{
         'default': initialRows.map(_copyRow).toList(growable: true),
       };

  final Map<String, List<Map<String, Object?>>> _rowsByOwner;

  @override
  Future<List<Map<String, Object?>>> readAll({
    String ownerId = 'default',
  }) async =>
      (_rowsByOwner[ownerId] ?? const []).map(_copyRow).toList(growable: false);

  @override
  Future<void> replaceAll(
    List<Map<String, Object?>> rows, {
    String ownerId = 'default',
  }) async {
    _rowsByOwner[ownerId] = rows.map(_copyRow).toList(growable: true);
  }

  static Map<String, Object?> _copyRow(Map<String, Object?> row) =>
      Map<String, Object?>.unmodifiable(row);
}

final class NotificationInboxService {
  NotificationInboxService(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final NotificationInboxRepository _repository;
  final DateTime Function() _clock;

  Future<NotificationEvent?> ingest(Map<Object?, Object?> payload) async {
    final event = NotificationEvent.tryParse(payload);
    return event == null ? null : _repository.upsert(event);
  }

  Future<NotificationEvent?> markRead(String eventId) =>
      _repository.markRead(eventId: eventId, readAt: _clock().toUtc());

  Future<void> clear() => _repository.clear();
}
