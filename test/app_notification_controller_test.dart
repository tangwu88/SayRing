import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_notification_service.dart';
import 'package:saydian_app/services/app_update_service.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/notification_route_service.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/prototype_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persisted upgrade account adopts legacy health data once', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'persisted-access',
        refreshToken: 'persisted-refresh',
        expiresAt: _futureExpiry,
        memberId: '100',
        displayName: 'Persisted',
      );
    final store = MemoryHealthStore();
    await store.initialize();
    await store.switchOwner('legacy-unscoped');
    await store.upsert([_accountHealthRecord]);
    final controller = AppController(
      vault,
      _NotificationApi(),
      store,
      _NotificationWearable(),
      notificationService: _FakeNotificationService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(vault.legacyHealthMigrationHandled, isTrue);
    expect(controller.healthRecords.single.id, _accountHealthRecord.id);
    await store.switchOwner('legacy-unscoped');
    expect(await store.recent(), isEmpty);
  });

  test('logged-out migration is never inherited by a later account', () async {
    final vault = MemorySessionVault();
    final store = MemoryHealthStore();
    await store.initialize();
    await store.switchOwner('legacy-unscoped');
    await store.upsert([_accountHealthRecord]);
    final loggedOutController = AppController(
      vault,
      _NotificationApi(),
      store,
      _NotificationWearable(),
      notificationService: _FakeNotificationService(),
    );
    addTearDown(loggedOutController.dispose);
    await loggedOutController.initialize();
    expect(vault.legacyHealthMigrationHandled, isTrue);

    vault.session = Session(
      accessToken: 'later-access',
      refreshToken: 'later-refresh',
      expiresAt: _futureExpiry,
      memberId: '200',
      displayName: 'Later',
    );
    final laterController = AppController(
      vault,
      _NotificationApi(),
      store,
      _NotificationWearable(),
      notificationService: _FakeNotificationService(),
    );
    addTearDown(laterController.dispose);

    await laterController.initialize();

    expect(laterController.healthRecords, isEmpty);
    await store.switchOwner('legacy-unscoped');
    expect((await store.recent()).single.id, _accountHealthRecord.id);
  });

  test(
    'notification inbox persists for A across logout and stays hidden from B',
    () async {
      final api = _NotificationApi();
      final notifications = _FakeNotificationService();
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(
        await controller.login(
          '13000000000',
          'test-only-password',
          privacyConsentGranted: true,
        ),
        isTrue,
      );

      final payload = <String, Object?>{
        'schema_version': 1,
        'event_id': 'server-event-19',
        'event_type': 'care_invitation',
        'entity_id': '19',
        'created_at': '2026-08-29T08:00:00Z',
      };
      notifications.receive(payload);
      notifications.receive(payload);
      await _drainEvents();

      expect(controller.notificationInboxEvents, hasLength(1));
      expect(controller.notificationUnreadCount, 1);

      notifications.open(payload);
      await _drainEvents();
      final route = controller.consumePendingNotificationRoute();

      expect(route?.target, NotificationRouteTarget.careInvitationReview);
      expect(route?.entityId, '19');
      expect(controller.notificationInboxEvents.single.isRead, isTrue);
      expect(controller.notificationUnreadCount, 0);
      expect(api.markedEventIds, contains('server-event-19'));

      await controller.requestNotificationPermission();
      expect(notifications.permissionRequested, isTrue);
      await controller.logout();
      expect(controller.notificationInboxEvents, isEmpty);
      expect(notifications.badges.last, 0);
      expect(api.unregisterCount, 1);

      expect(
        await controller.login(
          '13000000000',
          'test-only-password',
          privacyConsentGranted: true,
        ),
        isTrue,
      );
      expect(controller.notificationInboxEvents, hasLength(1));
      expect(controller.notificationInboxEvents.single.isRead, isTrue);
      notifications.receive(payload);
      await _drainEvents();
      expect(controller.notificationInboxEvents, hasLength(1));

      await controller.logout();
      expect(
        await controller.login(
          '13100000000',
          'test-only-password',
          privacyConsentGranted: true,
        ),
        isTrue,
      );
      expect(controller.notificationInboxEvents, isEmpty);
    },
  );

  test(
    'received push is ignored before login but opened route is queued',
    () async {
      final notifications = _FakeNotificationService();
      final controller = AppController(
        MemorySessionVault(),
        _NotificationApi(),
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final payload = <String, Object?>{
        'schema_version': 1,
        'event_id': 'server-event-20',
        'event_type': 'care_invitation',
        'entity_id': '20',
        'created_at': '2026-08-29T08:00:00Z',
      };

      notifications.receive(payload);
      await _drainEvents();
      expect(controller.notificationInboxEvents, isEmpty);
      notifications.open(payload);
      await _drainEvents();
      expect(controller.pendingNotificationRoute?.entityId, '20');
      expect(controller.consumePendingNotificationRoute(), isNull);
    },
  );

  test(
    'care unread survives a remote zero until explicitly read or processed',
    () async {
      final api = _NotificationApi()
        ..careInvitations = [
          const <String, Object?>{'id': 19, 'examine_status': 0},
        ]
        ..unreadCount = 1;
      final notifications = _FakeNotificationService();
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(
        await controller.login(
          '13000000000',
          'test-only-password',
          privacyConsentGranted: true,
        ),
        isTrue,
      );

      notifications.receive(<String, Object?>{
        'schema_version': 1,
        'event_id': 'care-event-19',
        'event_type': 'care_invitation',
        'entity_id': '19',
        'created_at': '2026-08-29T08:00:00Z',
      });
      await _drainEvents();
      expect(controller.notificationUnreadCount, 1);

      api.careInvitations = const [];
      await controller.refreshCareInvitations();
      expect(controller.notificationInboxEvents.single.isRead, isTrue);
      api.unreadCount = 0;
      await controller.refreshNotifications();
      expect(controller.notificationUnreadCount, 0);

      api.careInvitations = [
        const <String, Object?>{'id': 20, 'examine_status': 0},
      ];
      api.unreadCount = 1;
      notifications.receive(<String, Object?>{
        'schema_version': 1,
        'event_id': 'care-event-20',
        'event_type': 'care_invitation',
        'entity_id': '20',
        'created_at': '2026-08-29T08:01:00Z',
      });
      await _drainEvents();
      expect(controller.notificationUnreadCount, 1);

      api.unreadCount = 0;
      await controller.refreshNotifications();
      expect(
        controller.notificationInboxEvents
            .where((event) => event.eventId == 'care-invitation-20')
            .single
            .isRead,
        isFalse,
      );
      expect(controller.notificationUnreadCount, 1);
      expect(controller.activeCareInvitationAlert?.entityId, '20');
      await controller.markNotificationEventRead('care-invitation-20');
      expect(controller.notificationUnreadCount, 0);
      expect(controller.activeCareInvitationAlert, isNull);
    },
  );

  testWidgets('foreground poll preserves unread despite legacy zero count', (
    tester,
  ) async {
    final api = _NotificationApi();
    final notifications = _FakeNotificationService();
    final controller = AppController(
      MemorySessionVault(),
      api,
      MemoryHealthStore(),
      _NotificationWearable(),
      notificationService: notifications,
    );
    await controller.initialize();
    await controller.login('13000000000', 'test-only-password');
    api.careInvitations = const [
      {'id': 71, 'examine_status': 0},
      {'id': 72, 'examine_status': 0},
    ];
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(controller.remoteNotificationUnreadCount, 0);
    expect(controller.pendingCareInvitations, hasLength(2));
    expect(controller.notificationInboxEvents, hasLength(2));
    expect(
      controller.notificationInboxEvents.every((event) => !event.isRead),
      isTrue,
    );
    expect(controller.notificationUnreadCount, 2);
    expect(controller.activeCareInvitationAlert?.entityId, '72');
    expect(notifications.careInvitationShows, 2);

    controller.dismissCareInvitationAlert();
    notifications.receive(_carePayload('72', eventId: 'remote-72'));
    notifications.receive(_carePayload('72', eventId: 'remote-72-retry'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));

    expect(controller.notificationInboxEvents, hasLength(2));
    expect(controller.notificationUnreadCount, 2);
    expect(controller.activeCareInvitationAlert, isNull);
    expect(notifications.careInvitationShows, 2);

    await controller.markNotificationEventRead('care-invitation-71');
    expect(controller.notificationUnreadCount, 1);
    api.careInvitations = const [
      {'id': 71, 'examine_status': 0},
      {'id': 72, 'examine_status': 1},
    ];
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(controller.notificationUnreadCount, 0);
    expect(
      controller.notificationInboxEvents.every((event) => event.isRead),
      isTrue,
    );
    controller.dispose();
  });

  test(
    'care unread and foreground alert stay scoped to their account',
    () async {
      final api = _NotificationApi()
        ..careInvitations = const [
          {'id': 73, 'examine_status': 0},
        ];
      final notifications = _FakeNotificationService();
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login('13000000000', 'test-only-password');
      expect(controller.notificationUnreadCount, 1);
      expect(controller.activeCareInvitationAlert?.entityId, '73');

      api.careInvitations = const [];
      await controller.login('13100000000', 'test-only-password');
      expect(controller.activeCareInvitationAlert, isNull);
      expect(controller.notificationInboxEvents, isEmpty);
      expect(controller.notificationUnreadCount, 0);
      await controller.openCareInvitationAlert();
      expect(controller.pendingNotificationRoute, isNull);

      api.careInvitations = const [
        {'id': 73, 'examine_status': 0},
      ];
      await controller.login('13000000000', 'test-only-password');
      expect(controller.notificationUnreadCount, 1);
      expect(controller.notificationInboxEvents.single.isRead, isFalse);
      expect(controller.activeCareInvitationAlert, isNull);
      expect(notifications.careInvitationShows, 1);
      await controller.markNotificationEventRead('care-invitation-73');
      await controller.refreshNotifications();
      expect(controller.notificationUnreadCount, 0);
    },
  );

  testWidgets(
    'care banner is generic, dismissible and opens actual invitation',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = _NotificationApi();
      final notifications = _FakeNotificationService()
        ..permissionRequested = true;
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      await controller.initialize();
      await controller.login('13000000000', 'test-only-password');
      await tester.pumpWidget(
        SaydianApp(
          controller: controller,
          updateCheckStore: _NoPendingUpdateStore(),
        ),
      );
      await tester.pumpAndSettle();
      api.careInvitations = const [
        {'id': 74, 'examine_status': 0},
      ];
      await controller.refreshCareInvitations();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-care-invitation')), findsOneWidget);
      expect(find.text('收到新的关爱请求'), findsOneWidget);
      expect(notifications.careInvitationShows, 1);

      await tester.tap(find.byKey(const Key('dismiss-care-invitation')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-care-invitation')), findsNothing);
      expect(controller.notificationUnreadCount, 1);
      notifications.receive(_carePayload('74'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-care-invitation')), findsNothing);
      expect(notifications.careInvitationShows, 1);

      api.careInvitations = const [
        {'id': 74, 'examine_status': 0},
        {'id': 75, 'examine_status': 0},
      ];
      await controller.refreshCareInvitations();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-care-invitation')));
      await tester.pumpAndSettle();
      expect(find.byType(CareInvitationsPage), findsOneWidget);
      expect(
        tester
            .widget<CareInvitationsPage>(find.byType(CareInvitationsPage))
            .targetInvitationId,
        '75',
      );
      expect(find.byKey(const Key('global-care-invitation')), findsNothing);
      expect(controller.notificationUnreadCount, 1);
      expect(controller.pendingCareInvitations, hasLength(2));
      expect(notifications.careInvitationShows, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  test('background care is persisted without a foreground banner', () async {
    final api = _NotificationApi();
    final notifications = _FakeNotificationService();
    final controller = AppController(
      MemorySessionVault(),
      api,
      MemoryHealthStore(),
      _NotificationWearable(),
      notificationService: notifications,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.login('13000000000', 'test-only-password');
    controller.setAppForeground(false);
    notifications.receive(_carePayload('76'));
    await _drainEvents();
    expect(controller.activeCareInvitationAlert, isNull);
    expect(controller.notificationInboxEvents.single.isRead, isFalse);
    expect(controller.notificationUnreadCount, 1);
    controller.setAppForeground(true);
    await controller.refreshNotifications();
    expect(controller.notificationUnreadCount, 1);
    expect(controller.activeCareInvitationAlert, isNull);
  });

  testWidgets(
    'notification click still opens an already read processed invitation',
    (tester) async {
      final api = _NotificationApi()
        ..careInvitations = const [
          {'id': 68, 'examine_status': 1},
        ];
      final notifications = _FakeNotificationService()
        ..permissionRequested = true;
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      await controller.initialize();
      await controller.login('13000000000', 'test-only-password');
      await tester.pumpWidget(
        SaydianApp(
          controller: controller,
          updateCheckStore: _NoPendingUpdateStore(),
        ),
      );
      await tester.pumpAndSettle();
      final payload = _carePayload('68', eventId: 'qa-processed-care');
      notifications.receive(payload);
      await tester.pumpAndSettle();
      expect(controller.notificationInboxEvents.single.isRead, isTrue);
      expect(find.byType(CareInvitationsPage), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      notifications.open(payload);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(CareInvitationsPage), findsOneWidget);
      expect(find.text('该关爱邀请已处理'), findsOneWidget);
      expect(find.text('同意并授权'), findsNothing);
      expect(controller.pendingCareInvitations, isEmpty);
      expect(controller.notificationInboxEvents, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  test(
    'relogin reconciles an explicitly processed persisted invitation',
    () async {
      final api = _NotificationApi()
        ..careInvitations = const [
          {'id': 78, 'examine_status': 0},
        ];
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: _FakeNotificationService(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login('13000000000', 'test-only-password');
      expect(controller.notificationUnreadCount, 1);
      await controller.logout();
      api.careInvitations = const [
        {'id': 78, 'examine_status': 1},
      ];
      await controller.login('13000000000', 'test-only-password');
      expect(controller.notificationUnreadCount, 0);
      expect(controller.notificationInboxEvents.single.isRead, isTrue);
      expect(controller.activeCareInvitationAlert, isNull);
    },
  );

  test(
    'push stays inactive when login did not carry privacy consent',
    () async {
      final api = _NotificationApi();
      final notifications = _FakeNotificationService();
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      expect(
        await controller.login('13000000000', 'test-only-password'),
        isTrue,
      );
      await _drainEvents();

      expect(notifications.activated, isFalse);
      expect(api.registerCount, 0);
    },
  );

  test(
    'care processing marks the persisted server event id best effort',
    () async {
      final api = _NotificationApi();
      final notifications = _FakeNotificationService();
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );

      notifications.receive(<String, Object?>{
        'schema_version': 1,
        'event_id': 'server-care-event-31',
        'event_type': 'care_invitation',
        'entity_id': '31',
        'created_at': '2026-08-29T08:00:00Z',
      });
      await _drainEvents();
      await controller.respondCareInvitation(id: 31, accepted: true);
      await _drainEvents();

      expect(api.markedEventIds, contains('server-care-event-31'));
    },
  );

  test(
    'marking all health warnings also marks stable server event ids',
    () async {
      final api = _NotificationApi();
      final notifications = _FakeNotificationService();
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );

      notifications.receive(<String, Object?>{
        'schema_version': 1,
        'event_id': 'server-health-event-1',
        'event_type': 'health_warning',
        'entity_id': 'warning-1',
        'created_at': '2026-08-29T08:00:00Z',
      });
      await _drainEvents();
      await controller.markAllHealthWarningsRead();
      await _drainEvents();

      expect(controller.notificationInboxEvents.single.isRead, isTrue);
      expect(api.markedEventIds, contains('server-health-event-1'));
    },
  );

  test('login does not await a missing registration id callback', () async {
    final notifications = _FakeNotificationService(
      registrationIdResult: Completer<String?>().future,
    );
    final controller = AppController(
      MemorySessionVault(),
      _NotificationApi(),
      MemoryHealthStore(),
      _NotificationWearable(),
      notificationService: notifications,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final result = await controller
        .login('13000000000', 'test-only-password', privacyConsentGranted: true)
        .timeout(const Duration(seconds: 1));

    expect(result, isTrue);
    expect(notifications.activated, isTrue);
  });

  test(
    'connected callback retries a registration id that was not ready',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _mockPackageInfo();
      final api = _NotificationApi();
      final notifications = _FakeNotificationService(
        registrationIdResults: <Future<String?>>[
          Future<String?>.value(null),
          Future<String?>.value('registration-test'),
        ],
      );
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
        pushRegistrationRetryDelays: const [Duration(seconds: 1)],
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      await _drainEvents();
      expect(
        controller.pushDeviceRegistrationState,
        PushDeviceRegistrationState.retryScheduled,
      );

      notifications.emitRegistrationReady();
      await _drainEvents();

      expect(api.registerCount, 1);
      expect(
        controller.pushDeviceRegistrationState,
        PushDeviceRegistrationState.registered,
      );
      expect(controller.pushDeviceRegistrationIssueCode, isNull);
    },
  );

  test('server registration rejection retries with bounded backoff', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _mockPackageInfo();
    final api = _NotificationApi()..registerFailuresRemaining = 1;
    final controller = AppController(
      MemorySessionVault(),
      api,
      MemoryHealthStore(),
      _NotificationWearable(),
      notificationService: _FakeNotificationService(),
      pushRegistrationRetryDelays: const [Duration(milliseconds: 5)],
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.login(
      '13000000000',
      'test-only-password',
      privacyConsentGranted: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(api.registerCount, 2);
    expect(
      controller.pushDeviceRegistrationState,
      PushDeviceRegistrationState.registered,
    );
    expect(controller.pushDeviceRegistrationRetryAttempt, 0);
    expect(controller.pushDeviceRegistrationIssueCode, isNull);
  });

  test(
    'registration retry budget is finite and exposes final failure',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _mockPackageInfo();
      final api = _NotificationApi()..registerFailuresRemaining = 99;
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: _FakeNotificationService(),
        pushRegistrationRetryDelays: const [
          Duration(milliseconds: 1),
          Duration(milliseconds: 1),
        ],
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final settled = Completer<void>();
      void observeFailure() {
        if (controller.pushDeviceRegistrationState ==
                PushDeviceRegistrationState.failed &&
            !settled.isCompleted) {
          settled.complete();
        }
      }

      controller.addListener(observeFailure);
      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      try {
        await settled.future.timeout(const Duration(seconds: 5));
      } finally {
        controller.removeListener(observeFailure);
      }

      expect(api.registerCount, 3);
      expect(
        controller.pushDeviceRegistrationState,
        PushDeviceRegistrationState.failed,
      );
      expect(controller.pushDeviceRegistrationRetryAttempt, 2);
      expect(controller.pushDeviceRegistrationIssueCode, 'server_rejected');

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(api.registerCount, 3);
    },
  );

  test(
    'failed logout unbind is retried without persisting account data',
    () async {
      final vault = MemorySessionVault();
      final firstApi = _NotificationApi()..unregisterSucceeds = false;
      final first = AppController(
        vault,
        firstApi,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: _FakeNotificationService(),
      );
      await first.initialize();
      await first.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      await _drainEvents();
      await first.logout();

      expect(vault.pendingPushUnregisterInstallationId, 'installation-test');
      expect(
        first.pushDeviceRegistrationState,
        PushDeviceRegistrationState.unregisterRetryPending,
      );
      expect(first.pushDeviceRegistrationIssueCode, 'server_rejected');
      first.dispose();

      final secondApi = _NotificationApi();
      final second = AppController(
        vault,
        secondApi,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: _FakeNotificationService(),
      );
      addTearDown(second.dispose);
      await second.initialize();
      await second.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      await _drainEvents();

      expect(vault.pendingPushUnregisterInstallationId, isNull);
      expect(
        secondApi.unregisteredInstallationIds,
        contains('installation-test'),
      );
      expect(secondApi.registerCount, 1);
    },
  );

  test(
    'pending prior-account unbind blocks new-account registration',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final vault = MemorySessionVault()
        ..pendingPushUnregisterInstallationId = 'installation-test';
      final api = _NotificationApi()..unregisterSucceeds = false;
      final controller = AppController(
        vault,
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: _FakeNotificationService(),
        pushRegistrationRetryDelays: const [Duration(seconds: 1)],
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.login(
        '13100000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      await _drainEvents();

      expect(api.unregisterCount, 1);
      expect(api.registerCount, 0);
      expect(vault.pendingPushUnregisterInstallationId, 'installation-test');
      expect(
        controller.pushDeviceRegistrationState,
        PushDeviceRegistrationState.retryScheduled,
      );
      expect(
        controller.pushDeviceRegistrationIssueCode,
        'prior_unbind_pending',
      );
    },
  );

  test(
    'unsupported unregister endpoint keeps installation-only retry marker',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final vault = MemorySessionVault();
      final controller = AppController(
        vault,
        _NoNotificationApi(),
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: _FakeNotificationService(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );

      await controller.logout();

      expect(vault.pendingPushUnregisterInstallationId, 'installation-test');
      expect(
        controller.pushDeviceRegistrationState,
        PushDeviceRegistrationState.unregisterRetryPending,
      );
      expect(controller.pushDeviceRegistrationIssueCode, 'api_not_supported');
    },
  );

  test('old account invitation refresh cannot write after logout', () async {
    final api = _NotificationApi();
    final controller = AppController(
      MemorySessionVault(),
      api,
      MemoryHealthStore(),
      _NotificationWearable(),
      notificationService: _FakeNotificationService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.login(
      '13000000000',
      'test-only-password',
      privacyConsentGranted: true,
    );

    final delayed = Completer<List<Map<String, Object?>>>();
    api.careInvitationsFuture = delayed.future;
    final refresh = controller.refreshCareInvitations();
    await controller.logout();
    delayed.complete([
      const <String, Object?>{'id': 88, 'examine_status': 0},
    ]);
    await refresh;

    expect(controller.careInvitations, isEmpty);
    expect(controller.notificationInboxEvents, isEmpty);
  });

  test(
    'health state and upload metadata stay isolated across A and B',
    () async {
      final api = _NotificationApi();
      final store = MemoryHealthStore();
      final controller = AppController(
        MemorySessionVault(),
        api,
        store,
        _NotificationWearable(),
        notificationService: _FakeNotificationService(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      await store.upsert([_accountHealthRecord]);
      await store.writeCursor('cursor-a');
      await store.saveSportRecord(_accountSportRecord);
      await store.saveHealthWarningAlert(_accountWarning);

      await controller.logout();
      expect(controller.healthRecords, isEmpty);
      expect(controller.sportRecords, isEmpty);
      expect(controller.healthWarningAlerts, isEmpty);

      await controller.login(
        '13100000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      expect(controller.healthRecords, isEmpty);
      expect(controller.sportRecords, isEmpty);
      expect(controller.healthWarningAlerts, isEmpty);
      expect(await store.pending(), isEmpty);
      expect(await store.readCursor(), isNull);

      await controller.logout();
      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      expect(controller.healthRecords.single.id, _accountHealthRecord.id);
      expect(controller.sportRecords.single.id, _accountSportRecord.id);
      expect(controller.healthWarningAlerts.single.id, _accountWarning.id);
      expect((await store.pending()).single.id, _accountHealthRecord.id);
      expect(await store.readCursor(), 'cursor-a');
    },
  );

  test(
    'old A responses cannot overwrite B state after account switch',
    () async {
      final api = _NotificationApi();
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: _FakeNotificationService(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );

      final care = Completer<List<Map<String, Object?>>>();
      final profile = Completer<Map<String, Object?>>();
      final history = Completer<List<Map<String, Object?>>>();
      api.careMembersFuture = care.future;
      api.memberProfileFuture = profile.future;
      api.notificationsFuture = history.future;
      final oldCare = controller.refreshCare();
      final oldProfile = controller.refreshMemberProfile();
      final oldHistory = controller.refreshNotificationHistory();
      await Future<void>.delayed(Duration.zero);

      await controller.logout();
      api.careMembersFuture = null;
      api.memberProfileFuture = null;
      api.notificationsFuture = null;
      await controller.login(
        '13100000000',
        'test-only-password',
        privacyConsentGranted: true,
      );

      care.complete([
        const <String, Object?>{'id': 'from-a'},
      ]);
      profile.complete(const <String, Object?>{'nickname': 'A'});
      history.complete([
        const <String, Object?>{'id': 99, 'title': 'A message'},
      ]);
      await Future.wait([oldCare, oldProfile, oldHistory]);

      expect(controller.careMembers, isEmpty);
      expect(controller.memberProfile, isEmpty);
      expect(controller.notifications, isEmpty);
    },
  );

  test('care calendar day uses China boundary and preserves explicit day', () {
    expect(
      formatCareCalendarDay(null, now: DateTime.utc(2026, 8, 28, 16, 30)),
      '2026-08-29',
    );
    expect(
      formatCareCalendarDay(DateTime.utc(2026, 8, 29, 0, 30)),
      '2026-08-29',
    );
  });

  test('persisted session does not imply privacy consent', () async {
    final vault = MemorySessionVault()
      ..session = _NotificationApi._session
      ..privacyConsentGranted = false;
    final notifications = _FakeNotificationService();
    final controller = AppController(
      vault,
      _NotificationApi(),
      MemoryHealthStore(),
      _NotificationWearable(),
      notificationService: notifications,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await _drainEvents();

    expect(notifications.activated, isFalse);
    expect(notifications.permissionRequested, isFalse);
  });

  for (final previouslyAgreed in [false, true]) {
    test(
      'failed login preserves prior privacy agreement: $previouslyAgreed',
      () async {
        final vault = MemorySessionVault();
        final api = _ConsentApi();
        final notifications = _FakeNotificationService();
        final controller = AppController(
          vault,
          api,
          MemoryHealthStore(),
          _NotificationWearable(),
          notificationService: notifications,
        );
        addTearDown(controller.dispose);
        await controller.initialize();
        expect(
          await controller.login(
            'qa@example.com',
            'test-only-password',
            privacyConsentGranted: previouslyAgreed,
          ),
          isTrue,
        );
        api.rejectLogin = true;
        expect(
          await controller.login(
            'other@example.com',
            'test-only-password',
            privacyConsentGranted: !previouslyAgreed,
          ),
          isFalse,
        );
        expect(vault.privacyConsentGranted, previouslyAgreed);
        expect(controller.session, _NotificationApi._session);
        expect(notifications.activated, previouslyAgreed);
        expect(
          await controller.shouldExplainNotificationPermission(),
          previouslyAgreed,
        );
      },
    );
  }

  test(
    'reset session requires agreement and a current consent version',
    () async {
      final vault = MemorySessionVault();
      final api = _ConsentApi();
      final notifications = _FakeNotificationService();
      final controller = AppController(
        vault,
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      const challenge = VerificationChallenge(
        id: 'synthetic-challenge',
        expiresIn: 300,
        retryAfter: 0,
        maskedIdentifier: 'q***@example.com',
      );
      for (final scenario in [
        (agreed: false, version: 'reviewed-test-v1'),
        (agreed: true, version: null),
        (agreed: true, version: ''),
        (agreed: true, version: '   '),
      ]) {
        expect(
          await controller.completeGlobalVerification(
            challenge: challenge,
            code: '123456',
            password: 'test-only-password',
            resetPassword: true,
            locale: 'en',
            privacyConsentGranted: scenario.agreed,
            consentVersion: scenario.version,
          ),
          isFalse,
        );
      }
      expect(api.verificationCalls, 0);
      expect(controller.session, isNull);
      expect(vault.privacyConsentGranted, isFalse);
      expect(notifications.activated, isFalse);

      expect(
        await controller.completeGlobalVerification(
          challenge: challenge,
          code: '123456',
          password: 'test-only-password',
          resetPassword: true,
          locale: 'en',
          privacyConsentGranted: true,
          consentVersion: 'reviewed-test-v1',
        ),
        isTrue,
      );
      expect(api.verificationCalls, 1);
      expect(vault.privacyConsentGranted, isTrue);
      expect(notifications.activated, isTrue);
    },
  );

  test(
    'denying OS notifications does not revoke explicit app agreement',
    () async {
      final vault = MemorySessionVault();
      final notifications = _DeniedNotificationService();
      final controller = AppController(
        vault,
        _NotificationApi(),
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login(
        'qa@example.com',
        'test-only-password',
        privacyConsentGranted: true,
      );
      await controller.requestNotificationPermission();
      expect(notifications.permissionRequested, isTrue);
      expect(controller.notificationPermissionEnabled, isFalse);
      expect(vault.privacyConsentGranted, isTrue);
      expect(notifications.activated, isTrue);
    },
  );

  test(
    'notification permission cannot grant privacy consent and logout revokes explicit agreement',
    () async {
      final vault = MemorySessionVault();
      final notifications = _FakeNotificationService();
      final controller = AppController(
        vault,
        _NotificationApi(),
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login('13000000000', 'test-only-password');
      expect(vault.privacyConsentGranted, isFalse);

      await controller.requestNotificationPermission();
      expect(vault.privacyConsentGranted, isFalse);
      expect(notifications.activated, isFalse);
      expect(notifications.permissionRequested, isFalse);
      expect(await controller.shouldExplainNotificationPermission(), isFalse);

      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      await controller.requestNotificationPermission();
      expect(vault.privacyConsentGranted, isTrue);
      expect(notifications.activated, isTrue);
      expect(notifications.permissionRequested, isTrue);

      await controller.logout();
      expect(vault.privacyConsentGranted, isFalse);
    },
  );

  test(
    'data push shows one local alert while notification delivery does not',
    () async {
      final notifications = _FakeNotificationService();
      final controller = AppController(
        MemorySessionVault(),
        _NotificationApi(),
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      final payload = <String, Object?>{
        'schema_version': 1,
        'event_id': 'delivery-kind-1',
        'event_type': 'care_invitation',
        'entity_id': '77',
        'created_at': '2026-08-29T08:00:00Z',
      };

      notifications.receive(<String, Object?>{
        ...payload,
        '_delivery_kind': 'data',
        '_system_already_presented': false,
      });
      await _drainEvents();
      expect(notifications.careInvitationShows, 1);

      notifications.receive(<String, Object?>{
        ...payload,
        '_delivery_kind': 'notification',
        '_system_already_presented': true,
      });
      await _drainEvents();
      expect(notifications.careInvitationShows, 1);
    },
  );

  test(
    'old account registration stops after delayed installation id',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _mockPackageInfo();
      final installation = Completer<String>();
      final api = _NotificationApi();
      final notifications = _FakeNotificationService(
        installationIdResult: installation.future,
      );
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NotificationWearable(),
        notificationService: notifications,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.login(
        '13000000000',
        'test-only-password',
        privacyConsentGranted: true,
      );
      await _drainEvents();
      await controller.login(
        '13100000000',
        'test-only-password',
        privacyConsentGranted: true,
      );

      installation.complete('installation-test');
      await _drainEvents();
      expect(api.registerCount, 1);
    },
  );

  test('old registration response cannot clear a new pending marker', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _mockPackageInfo();
    final vault = MemorySessionVault();
    final api = _NotificationApi()
      ..registerResult = Completer<bool>()
      ..unregisterSucceeds = false;
    final controller = AppController(
      vault,
      api,
      MemoryHealthStore(),
      _NotificationWearable(),
      notificationService: _FakeNotificationService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.login(
      '13000000000',
      'test-only-password',
      privacyConsentGranted: true,
    );
    await api.registerStarted.future;

    await controller.logout();
    expect(vault.pendingPushUnregisterInstallationId, 'installation-test');
    api.registerResult!.complete(true);
    await _drainEvents();

    expect(vault.pendingPushUnregisterInstallationId, 'installation-test');
  });
}

final _accountHealthRecord = HealthRecord(
  id: 'account-a-heart',
  metric: HealthMetric.heartRate,
  values: const {'value': 72},
  unit: 'bpm',
  measuredAt: DateTime.utc(2026, 8, 29, 8),
  timezone: '+08:00',
  deviceId: 'watch',
  firmwareVersion: '1.0',
  quality: 'good',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);

final _futureExpiry = DateTime.utc(2030);

final _accountSportRecord = SportRecord(
  id: 'account-a-sport',
  mode: SportMode.running,
  startedAt: DateTime.utc(2026, 8, 29, 8),
  durationSeconds: 600,
  distanceKm: 1.5,
  calories: 100,
);

final _accountWarning = HealthWarningAlert(
  id: 'account-a-warning',
  metric: HealthMetric.heartRate,
  title: '心率提醒',
  message: 'A warning',
  triggeredAt: DateTime.utc(2026, 8, 29, 8),
);

Future<void> _drainEvents() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void _mockPackageInfo() {
  PackageInfo.setMockInitialValues(
    appName: '赛电健康',
    packageName: 'cc.saidian.app',
    version: '0.1.0',
    buildNumber: '1',
    buildSignature: '',
  );
}

Map<String, Object?> _carePayload(String id, {String? eventId}) => {
  'schema_version': 1,
  'event_id': eventId ?? 'remote-$id',
  'event_type': 'care_invitation',
  'entity_id': id,
  'created_at': '2026-08-29T08:00:00Z',
  '_delivery_kind': 'data',
  '_system_already_presented': false,
};

class _NoPendingUpdateStore implements AppUpdateCheckStore {
  @override
  Future<AppUpdateInfo?> readRequiredUpdate() async => null;
  @override
  Future<void> writeRequiredUpdate(AppUpdateInfo? value) async {}
  @override
  Future<DateTime?> readLastSuccessfulCheck() async => DateTime.now();
  @override
  Future<void> writeLastSuccessfulCheck(DateTime value) async {}
}

class _FakeNotificationService implements AppNotificationService {
  _FakeNotificationService({
    Future<String?>? registrationIdResult,
    List<Future<String?>>? registrationIdResults,
    Future<String>? installationIdResult,
  }) : _registrationIdResults =
           registrationIdResults ??
           <Future<String?>>[
             registrationIdResult ?? Future<String?>.value('registration-test'),
           ],
       _installationIdResult =
           installationIdResult ?? Future<String>.value('installation-test');

  final Future<String> _installationIdResult;

  final List<Future<String?>> _registrationIdResults;
  int registrationIdReadCount = 0;
  final _received = StreamController<Map<String, Object?>>.broadcast();
  final _opened = StreamController<Map<String, Object?>>.broadcast();
  final _permissions = StreamController<bool>.broadcast();
  final _registrationReady = StreamController<void>.broadcast();
  final List<int> badges = [];
  bool permissionRequested = false;
  bool activated = false;
  int healthWarningShows = 0;
  int careInvitationShows = 0;

  void receive(Map<String, Object?> payload) => _received.add(payload);
  void open(Map<String, Object?> payload) => _opened.add(payload);
  void emitRegistrationReady() => _registrationReady.add(null);

  @override
  bool get isConfigured => true;
  @override
  bool get isActivated => activated;
  @override
  Stream<Map<String, Object?>> get receivedEvents => _received.stream;
  @override
  Stream<Map<String, Object?>> get openedEvents => _opened.stream;
  @override
  Stream<bool> get permissionChanges => _permissions.stream;
  @override
  Stream<void> get registrationReadyEvents => _registrationReady.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> activateAfterPrivacyConsent() async => activated = true;
  @override
  Future<void> deactivate() async => activated = false;
  @override
  Future<String?> registrationId() {
    final index = registrationIdReadCount < _registrationIdResults.length
        ? registrationIdReadCount
        : _registrationIdResults.length - 1;
    registrationIdReadCount++;
    return _registrationIdResults[index];
  }

  @override
  Future<String> installationId() => _installationIdResult;
  @override
  Future<bool> isPermissionEnabled() async => permissionRequested;
  @override
  Future<bool> shouldExplainPermission() async => !permissionRequested;
  @override
  Future<void> markPermissionExplanationShown() async {}
  @override
  Future<void> requestPermission() async {
    permissionRequested = true;
    _permissions.add(true);
  }

  @override
  Future<void> openSettings() async {}
  @override
  Future<void> setBadge(int value) async => badges.add(value);
  @override
  Future<void> showHealthWarning({
    required String eventId,
    required String entityId,
    required DateTime createdAt,
    required int unreadCount,
  }) async => healthWarningShows++;
  @override
  Future<void> showCareInvitation({
    required String eventId,
    required String entityId,
    required DateTime createdAt,
    required int unreadCount,
  }) async => careInvitationShows++;
  @override
  Future<void> dispose() async {
    await _received.close();
    await _opened.close();
    await _permissions.close();
    await _registrationReady.close();
  }
}

class _NotificationApi extends Fake
    implements SaydianApi, SaydianCareApi, SaydianNotificationApi {
  int unregisterCount = 0;
  int registerCount = 0;
  int registerFailuresRemaining = 0;
  bool unregisterSucceeds = true;
  final List<String> unregisteredInstallationIds = [];
  final List<String> markedEventIds = [];
  int? unreadCount = 0;
  List<Map<String, Object?>> careInvitations = const [];
  Future<List<Map<String, Object?>>>? careInvitationsFuture;
  Future<List<Map<String, Object?>>>? careMembersFuture;
  Future<Map<String, Object?>>? memberProfileFuture;
  Future<List<Map<String, Object?>>>? notificationsFuture;
  Completer<bool>? registerResult;
  final Completer<void> registerStarted = Completer<void>();

  static final _session = Session(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAt: DateTime.utc(2030),
    memberId: '100',
    displayName: 'QA',
  );

  @override
  Future<Session> login(String username, String password) async =>
      username == '13100000000'
      ? Session(
          accessToken: 'access-b',
          refreshToken: 'refresh-b',
          expiresAt: DateTime.utc(2030),
          memberId: '200',
          displayName: 'QB',
        )
      : _session;
  @override
  Future<List<Map<String, Object?>>> getCareMembers() async =>
      careMembersFuture ?? Future.value(const []);
  @override
  Future<List<Map<String, Object?>>> getCareInvitations() async =>
      careInvitationsFuture ?? Future.value(careInvitations);
  @override
  Future<Map<String, Object?>> getMemberProfile() async =>
      memberProfileFuture ?? Future.value(const {});
  @override
  Future<Map<String, Object?>> getActivityGoals() async => const {};
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];
  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      notificationsFuture ?? Future.value(const []);
  @override
  Future<int?> getNotificationUnreadCount() async => unreadCount;
  @override
  Future<bool> registerPushDevice({
    required String installationId,
    required String registrationId,
    required String platform,
    String? appVersion,
    int? buildNumber,
  }) async {
    registerCount++;
    if (!registerStarted.isCompleted) registerStarted.complete();
    if (registerFailuresRemaining > 0) {
      registerFailuresRemaining--;
      return false;
    }
    return registerResult?.future ?? true;
  }

  @override
  Future<bool> unregisterPushDevice({required String installationId}) async {
    unregisterCount++;
    unregisteredInstallationIds.add(installationId);
    return unregisterSucceeds;
  }

  @override
  Future<bool> markNotificationRead({required int id}) async => true;
  @override
  Future<bool> markNotificationEventRead({required String eventId}) async {
    markedEventIds.add(eventId);
    unreadCount = 0;
    return true;
  }

  @override
  Future<void> respondCareInvitation({
    required int id,
    required bool accepted,
  }) async {}
  @override
  Future<Set<String>> getCareShareSettings({
    required int type,
    required int memberId,
  }) async => const {};
  @override
  Future<void> saveCareShareSettings({
    required int type,
    required int memberId,
    required Set<String> settings,
  }) async {}
  @override
  Future<void> logout() async {}
}

class _ConsentApi extends _NotificationApi implements GlobalAccountApi {
  bool rejectLogin = false;
  int verificationCalls = 0;

  @override
  Future<Session> login(String username, String password) {
    if (rejectLogin) {
      throw const ApiException(
        'Synthetic rejected credentials',
        statusCode: 401,
      );
    }
    return super.login(username, password);
  }

  @override
  Future<Session> completeVerification({
    required String challengeId,
    required String code,
    required String password,
    required bool resetPassword,
    required String locale,
    bool ageConfirmed = false,
    String? nickname,
    String? consentVersion,
  }) async {
    verificationCalls++;
    return _NotificationApi._session;
  }
}

class _DeniedNotificationService extends _FakeNotificationService {
  @override
  Future<bool> isPermissionEnabled() async => false;
}

class _NoNotificationApi extends Fake implements SaydianApi {
  @override
  Future<Session> login(String mobile, String password) async => Session(
    accessToken: 'test-access',
    refreshToken: 'test-refresh',
    expiresAt: _futureExpiry,
    memberId: mobile,
    displayName: mobile,
  );

  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];

  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => const [];

  @override
  Future<Map<String, Object?>> getMemberProfile() async => const {};

  @override
  Future<Map<String, Object?>> getActivityGoals() async => const {};

  @override
  Future<void> logout() async {}
}

class _NotificationWearable extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}
