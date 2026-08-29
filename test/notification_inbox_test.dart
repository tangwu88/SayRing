import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/notification_inbox.dart';
import 'package:saydian_app/services/notification_models.dart';
import 'package:saydian_app/services/notification_route_service.dart';

void main() {
  test('payload parser persists only the stable whitelist', () {
    final event = NotificationEvent.tryParse(<Object?, Object?>{
      'schema_version': '1',
      'event_id': 'event-1',
      'event_type': 'care_invitation',
      'entity_id': 'invitation-1',
      'remote_event_id': 'server-event-1',
      'created_at': '2026-08-29T08:00:00.987Z',
      'read_at': 1787990500,
      'route': '/must-not-be-used',
      'mobile': 'must-not-persist',
      'token': 'must-not-persist',
      'measurement': 'must-not-persist',
    });

    expect(event, isNotNull);
    expect(event!.createdAt.isUtc, isTrue);
    expect(event.createdAt.millisecond, 0);
    expect(event.toPersistenceMap().keys, {
      'schema_version',
      'event_id',
      'event_type',
      'source',
      'target_route',
      'entity_id',
      'remote_event_id',
      'created_at',
      'read_at',
    });
    expect(event.toPersistenceMap().toString(), isNot(contains('must-not')));
  });

  test('payload parser rejects unknown schemas, types, and unsafe ids', () {
    const base = <Object?, Object?>{
      'schema_version': 1,
      'event_id': 'event-1',
      'event_type': 'system',
      'created_at': 1787990400,
    };

    expect(NotificationEvent.tryParse({...base, 'schema_version': 2}), isNull);
    expect(
      NotificationEvent.tryParse({...base, 'event_type': 'open_url'}),
      isNull,
    );
    expect(
      NotificationEvent.tryParse({...base, 'event_id': '../unsafe'}),
      isNull,
    );
    expect(
      NotificationEvent.tryParse({
        ...base,
        'created_at': '2026-08-29T08:00:00',
      }),
      isNull,
    );
    expect(
      NotificationEvent.tryParse({...base, 'event_type': 'care_invitation'}),
      isNull,
    );
  });

  test('legacy event id derivation is deterministic and opaque', () {
    const payload = <Object?, Object?>{
      'schema_version': 1,
      'event_type': 'health_warning',
      'entity_id': 'warning-reference',
      'created_at': 1787990400,
    };

    final first = NotificationEvent.tryParse(payload)!;
    final second = NotificationEvent.tryParse(payload)!;

    expect(first.eventId, second.eventId);
    expect(first.eventId, startsWith('legacy-'));
    expect(first.eventId, isNot(contains('warning-reference')));
  });

  test(
    'local inbox deduplicates and preserves readAt across reloads',
    () async {
      final storage = MemoryNotificationInboxStorage();
      final repository = StoredNotificationInboxRepository(storage);
      final inbox = NotificationInboxService(
        repository,
        clock: () => DateTime.utc(2026, 8, 29, 10, 30, 0, 987),
      );
      const payload = <Object?, Object?>{
        'schema_version': 1,
        'event_id': 'event-1',
        'event_type': 'care_invitation',
        'entity_id': 'invitation-1',
        'created_at': 1787990400,
        'ignored': 'must-not-persist',
      };

      await Future.wait([inbox.ingest(payload), inbox.ingest(payload)]);
      expect(await repository.unreadCount(), 1);
      expect(await repository.list(), hasLength(1));

      final read = await inbox.markRead('event-1');
      expect(read, isNotNull);
      expect(read!.readAt!.isUtc, isTrue);
      expect(read.readAt!.millisecond, 0);

      await inbox.ingest(payload);
      expect(await repository.unreadCount(), 0);
      final reloaded = StoredNotificationInboxRepository(storage);
      final restored = (await reloaded.list()).single;
      expect(restored.eventId, 'event-1');
      expect(restored.isRead, isTrue);
      expect((await storage.readAll()).single.keys, {
        'schema_version',
        'event_id',
        'event_type',
        'source',
        'target_route',
        'entity_id',
        'created_at',
        'read_at',
      });
    },
  );

  test('same event id is isolated between account owners', () async {
    final storage = MemoryNotificationInboxStorage();
    final first = StoredNotificationInboxRepository(
      storage,
      ownerId: 'owner-a',
    );
    final second = StoredNotificationInboxRepository(
      storage,
      ownerId: 'owner-b',
    );
    final event = NotificationEvent.tryParse(const <String, Object?>{
      'schema_version': 1,
      'event_id': 'shared-event-id',
      'event_type': 'system',
      'created_at': 1787990400,
    })!;

    await first.upsert(event);
    expect(await first.list(), hasLength(1));
    expect(await second.list(), isEmpty);

    await second.upsert(event);
    await first.clear();
    expect(await first.list(), isEmpty);
    expect(await second.list(), hasLength(1));
  });

  test('route service maps only known event types to controlled targets', () {
    const router = NotificationRouteService();
    final careEvent = NotificationEvent.tryParse(const {
      'event_id': 'event-care',
      'event_type': 'care_invitation',
      'entity_id': 'invitation-1',
      'created_at': 1787990400,
      'route': '/arbitrary-page',
    })!;
    final warningEvent = NotificationEvent.tryParse(const {
      'event_id': 'event-warning',
      'event_type': 'health_warning',
      'entity_id': 'warning-1',
      'created_at': 1787990401,
    })!;
    final systemEvent = NotificationEvent.tryParse(const {
      'event_id': 'event-system',
      'event_type': 'system',
      'created_at': 1787990402,
    })!;

    expect(
      router.resolve(careEvent).target,
      NotificationRouteTarget.careInvitationReview,
    );
    expect(
      router.resolve(warningEvent).target,
      NotificationRouteTarget.healthWarningHistory,
    );
    expect(
      router.resolve(systemEvent).target,
      NotificationRouteTarget.notificationInbox,
    );
  });
}
