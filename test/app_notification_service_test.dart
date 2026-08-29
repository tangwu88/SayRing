import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jpush_flutter/jpush_interface.dart';
import 'package:saydian_app/services/app_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

  group('normalizeJPushPayload', () {
    const business = <String, Object?>{
      'schema_version': 1,
      'event_id': 'event-42',
      'event_type': 'care_invitation',
      'entity_id': '42',
      'created_at': '2026-08-29T08:00:00Z',
    };

    test('accepts iOS direct extras', () {
      final result = normalizeJPushPayload(<String, dynamic>{
        'title': 'system title',
        'extras': business,
      });

      expect(result, business);
    });

    test('unwraps Android cn.jpush.android.EXTRA map', () {
      final result = normalizeJPushPayload(<String, dynamic>{
        'notificationId': 99,
        'extras': <String, Object?>{'cn.jpush.android.EXTRA': business},
      });

      expect(result, business);
      expect(result, isNot(contains('notificationId')));
    });

    test('unwraps Android cn.jpush.android.EXTRA JSON string', () {
      final result = normalizeJPushPayload(<String, dynamic>{
        'extras': <String, Object?>{
          'cn.jpush.android.EXTRA': jsonEncode(business),
        },
      });

      expect(result, business);
    });
  });

  test('SDK setup is deferred until privacy activation', () async {
    final jpush = _FakeJPush();
    final service = JPushAppNotificationService(
      jpush: jpush,
      appKey: 'test-app-key',
    );
    addTearDown(service.dispose);

    await service.initialize();
    expect(jpush.handlerInstallCount, 1);
    expect(jpush.setupCount, 0);
    expect(jpush.authValues, isEmpty);

    await service.activateAfterPrivacyConsent();
    expect(service.isActivated, isTrue);
    expect(jpush.setupCount, 1);
    expect(jpush.authValues, [true]);
  });

  test('registration id has a short bounded timeout', () async {
    final jpush = _FakeJPush(registrationId: Completer<String>().future);
    final service = JPushAppNotificationService(
      jpush: jpush,
      appKey: 'test-app-key',
      registrationTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(service.dispose);
    await service.initialize();
    await service.activateAfterPrivacyConsent();

    final stopwatch = Stopwatch()..start();
    expect(await service.registrationId(), isNull);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test(
    'cold-start notification click is emitted once after activation',
    () async {
      final jpush = _FakeJPush(
        launchNotification: <String, Object?>{
          'extras': <String, Object?>{
            'schema_version': 1,
            'event_id': 'cold-start-event',
            'event_type': 'care_invitation',
            'entity_id': '42',
          },
        },
      );
      final service = JPushAppNotificationService(
        jpush: jpush,
        appKey: 'test-app-key',
      );
      addTearDown(service.dispose);
      final opened = service.openedEvents.first;

      await service.initialize();
      await service.activateAfterPrivacyConsent();
      expect((await opened)['event_id'], 'cold-start-event');

      await service.activateAfterPrivacyConsent();
      await Future<void>.delayed(Duration.zero);
      expect(jpush.launchNotificationReadCount, 1);
    },
  );

  test(
    'permission request waits for asynchronous authorization result',
    () async {
      final jpush = _FakeJPush();
      final service = JPushAppNotificationService(
        jpush: jpush,
        appKey: 'test-app-key',
        permissionResolutionTimeout: const Duration(seconds: 1),
        permissionPollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(service.dispose);
      await service.initialize();
      await service.activateAfterPrivacyConsent();

      final changed = service.permissionChanges.first;
      final request = service.requestPermission();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await jpush.emitAuthorization(true);

      await request.timeout(const Duration(seconds: 1));
      expect(await changed, isTrue);
      expect(await service.isPermissionEnabled(), isTrue);
    },
  );

  test(
    'marks data delivery for local display without duplicating notification',
    () async {
      final jpush = _FakeJPush();
      final service = JPushAppNotificationService(
        jpush: jpush,
        appKey: 'test-app-key',
      );
      addTearDown(service.dispose);
      await service.activateAfterPrivacyConsent();
      final received = service.receivedEvents.take(2).toList();
      const payload = <String, Object?>{
        'extras': <String, Object?>{
          'schema_version': 1,
          'event_id': 'event-delivery-kind',
          'event_type': 'care_invitation',
          'entity_id': '42',
        },
      };

      await jpush.emitMessage(payload);
      await jpush.emitNotification(payload);
      final events = await received;

      expect(events.first['_delivery_kind'], 'data');
      expect(events.first['_system_already_presented'], isFalse);
      expect(events.last['_delivery_kind'], 'notification');
      expect(events.last['_system_already_presented'], isTrue);
    },
  );
}

final class _FakeJPush extends JPushFlutterInterface {
  _FakeJPush({
    Future<String>? registrationId,
    Map<String, Object?>? launchNotification,
  }) : _registrationId = registrationId ?? Future<String>.value('rid'),
       _launchNotification = launchNotification ?? const <String, Object?>{};

  final Future<String> _registrationId;
  final Map<String, Object?> _launchNotification;
  final List<bool> authValues = [];
  int handlerInstallCount = 0;
  int setupCount = 0;
  int launchNotificationReadCount = 0;
  bool notificationEnabled = false;
  EventHandler? _authorizationHandler;
  EventHandler? _receiveNotificationHandler;
  EventHandler? _receiveMessageHandler;

  Future<void> emitAuthorization(bool enabled) async {
    notificationEnabled = enabled;
    await _authorizationHandler?.call(<String, dynamic>{'isEnabled': enabled});
  }

  Future<void> emitNotification(Map<String, Object?> payload) async =>
      _receiveNotificationHandler?.call(Map<String, dynamic>.from(payload));

  Future<void> emitMessage(Map<String, Object?> payload) async =>
      _receiveMessageHandler?.call(Map<String, dynamic>.from(payload));

  @override
  void addEventHandler({
    EventHandler? onReceiveNotification,
    EventHandler? onOpenNotification,
    EventHandler? onReceiveMessage,
    EventHandler? onReceiveNotificationAuthorization,
    EventHandler? onNotifyMessageUnShow,
    EventHandler? onConnected,
    EventHandler? onInAppMessageClick,
    EventHandler? onInAppMessageShow,
    EventHandler? onNotifyButtonClick,
    EventHandler? onCommandResult,
    EventHandler? onReceiveDeviceToken,
    EventHandler? onVoipMessage,
  }) {
    handlerInstallCount++;
    _authorizationHandler = onReceiveNotificationAuthorization;
    _receiveNotificationHandler = onReceiveNotification;
    _receiveMessageHandler = onReceiveMessage;
  }

  @override
  void setAuth({bool enable = true}) => authValues.add(enable);

  @override
  void setup({
    String appKey = '',
    bool production = false,
    String channel = '',
    bool debug = false,
  }) {
    setupCount++;
  }

  @override
  void setCollectControl({
    bool imsi = true,
    bool mac = true,
    bool wifi = true,
    bool bssid = true,
    bool ssid = true,
    bool imei = true,
    bool cell = true,
    bool gps = true,
  }) {}

  @override
  void setBackgroundEnable({bool enable = false}) {}

  @override
  void setUnShowAtTheForeground({bool unShow = false}) {}

  @override
  Future<String> getRegistrationID() => _registrationId;

  @override
  Future<Map<dynamic, dynamic>> getLaunchAppNotification() async {
    launchNotificationReadCount++;
    return _launchNotification;
  }

  @override
  Future<bool> isNotificationEnabled() async => notificationEnabled;

  @override
  Future<void> stopPush() async {}
}
