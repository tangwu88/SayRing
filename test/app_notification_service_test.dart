import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  test(
    'empty AppKey disables SDK setup, registration and permissions',
    () async {
      final jpush = _FakeJPush();
      final service = JPushAppNotificationService(jpush: jpush, appKey: '');
      addTearDown(service.dispose);

      await service.initialize();
      await service.activateAfterPrivacyConsent();
      await service.requestPermission();

      expect(service.isConfigured, isFalse);
      expect(service.isActivated, isFalse);
      expect(await service.registrationId(), isNull);
      expect(await service.isPermissionEnabled(), isFalse);
      expect(jpush.handlerInstallCount, 0);
      expect(jpush.setupCount, 0);
      expect(jpush.registrationIdReadCount, 0);
      expect(jpush.launchNotificationReadCount, 0);
      expect(jpush.authValues, isEmpty);
    },
  );

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
    expect(jpush.lastSetupDebug, isFalse);
    expect(jpush.authValues, [true]);
  });

  test('vendored Android JPush setup never logs its arguments', () {
    final source = File(
      'third_party/jpush_flutter/android/src/main/java/'
      'com/jiguang/jpush/JPushPlugin.java',
    ).readAsStringSync();
    final setupStart = source.indexOf('public void setup(');
    final setupEnd = source.indexOf('\n    public void ', setupStart + 1);

    expect(setupStart, greaterThanOrEqualTo(0));
    expect(setupEnd, greaterThan(setupStart));
    final setupBlock = source.substring(setupStart, setupEnd);
    expect(
      RegExp(r'Log\.[^(]+\([^;]*call\.arguments').hasMatch(setupBlock),
      isFalse,
    );
  });

  test('native notification logs only debug callback readiness', () {
    final source = File(
      'third_party/jpush_flutter/android/src/main/java/'
      'com/jiguang/jpush/JPushHelper.java',
    ).readAsStringSync();
    final helperStart = source.indexOf(
      'private void logNotificationCallback(String type)',
    );
    final helperEnd = source.indexOf('\n    public void ', helperStart);
    expect(helperStart, greaterThanOrEqualTo(0));
    expect(helperEnd, greaterThan(helperStart));
    final helper = source.substring(helperStart, helperEnd);
    final logCalls = RegExp(
      r'Log\.[a-z]+\([^;]*;',
      dotAll: true,
    ).allMatches(source).map((match) => match.group(0)!).toList();

    expect(logCalls, hasLength(1));
    expect(helper, contains('ApplicationInfo.FLAG_DEBUGGABLE) != 0'));
    expect(helper, contains(logCalls.single));
    expect(
      logCalls.single.replaceAll(RegExp(r'\s+'), ' '),
      'Log.i("SaydianPush", "callback=" + type + " dart_ready=" + dartIsReady '
      '+ " channel_ready=" + (channel != null));',
    );
    expect(
      RegExp(
        r'logNotificationCallback\(([^)]*)\);',
      ).allMatches(source).map((match) => match.group(1)),
      ['"open"', '"receive"'],
    );
    expect(source, isNot(contains('printStackTrace(')));
    expect(source, isNot(contains('System.out.')));
    expect(source, isNot(contains('System.err.')));
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
    'registration id reuses one native request while it is pending',
    () async {
      final registration = Completer<String>();
      final jpush = _FakeJPush(registrationId: registration.future);
      final service = JPushAppNotificationService(
        jpush: jpush,
        appKey: 'test-app-key',
        registrationTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);
      await service.activateAfterPrivacyConsent();

      expect(await service.registrationId(), isNull);
      expect(await service.registrationId(), isNull);
      expect(jpush.registrationIdReadCount, 1);

      registration.complete('registration-test');
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('connected callback requests a fresh device registration', () async {
    final jpush = _FakeJPush();
    final service = JPushAppNotificationService(
      jpush: jpush,
      appKey: 'test-app-key',
    );
    addTearDown(service.dispose);
    await service.activateAfterPrivacyConsent();
    final ready = service.registrationReadyEvents.first;

    await jpush.emitConnected(true);

    await ready.timeout(const Duration(seconds: 1));
  });

  test('connected callback accepts native numeric result payload', () async {
    final jpush = _FakeJPush();
    final service = JPushAppNotificationService(
      jpush: jpush,
      appKey: 'test-app-key',
    );
    addTearDown(service.dispose);
    await service.activateAfterPrivacyConsent();
    var readyCount = 0;
    final subscription = service.registrationReadyEvents.listen(
      (_) => readyCount++,
    );
    addTearDown(subscription.cancel);

    await jpush.emitConnected(0);
    await Future<void>.delayed(Duration.zero);
    expect(readyCount, 0);

    await jpush.emitConnected(1);
    await Future<void>.delayed(Duration.zero);
    expect(readyCount, 1);
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
  bool? lastSetupDebug;
  int launchNotificationReadCount = 0;
  int registrationIdReadCount = 0;
  bool notificationEnabled = false;
  EventHandler? _authorizationHandler;
  EventHandler? _receiveNotificationHandler;
  EventHandler? _receiveMessageHandler;
  EventHandler? _connectedHandler;

  Future<void> emitAuthorization(bool enabled) async {
    notificationEnabled = enabled;
    await _authorizationHandler?.call(<String, dynamic>{'isEnabled': enabled});
  }

  Future<void> emitNotification(Map<String, Object?> payload) async =>
      _receiveNotificationHandler?.call(Map<String, dynamic>.from(payload));

  Future<void> emitMessage(Map<String, Object?> payload) async =>
      _receiveMessageHandler?.call(Map<String, dynamic>.from(payload));

  Future<void> emitConnected(Object connected) async =>
      _connectedHandler?.call(<String, dynamic>{'result': connected});

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
    _connectedHandler = onConnected;
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
    lastSetupDebug = debug;
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
  Future<String> getRegistrationID() {
    registrationIdReadCount++;
    return _registrationId;
  }

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
