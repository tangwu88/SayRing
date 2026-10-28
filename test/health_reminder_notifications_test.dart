import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/health_reminder_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = MethodChannelHealthReminderNotifications();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(
    () => messenger.setMockMethodCallHandler(
      MethodChannelHealthReminderNotifications.channel,
      null,
    ),
  );

  test('reading permission never implicitly requests authorization', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(
      MethodChannelHealthReminderNotifications.channel,
      (call) async {
        methods.add(call.method);
        return call.method == 'permission' ? 'denied' : 'granted';
      },
    );
    expect(await service.permission(), ReminderNotificationPermission.denied);
    expect(methods, ['permission']);
    expect(
      await service.permission(request: true),
      ReminderNotificationPermission.granted,
    );
    expect(methods, ['permission', 'requestPermission']);
  });

  test(
    'local notification request carries only owner and event identifiers',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(
        MethodChannelHealthReminderNotifications.channel,
        (call) async {
          calls.add(call);
          return call.method == 'show' ? true : null;
        },
      );
      final owner = List.filled(64, 'a').join();
      await service.setOwner(owner);
      expect(
        await service.show(owner: owner, eventId: 'reminder-fixture'),
        isTrue,
      );
      expect(calls.last.arguments, {
        'owner': owner,
        'eventId': 'reminder-fixture',
      });
      await service.setOwner(null);
      expect(calls.last.arguments, {'owner': null});
    },
  );

  test(
    'unsupported native permission and malformed opens remain unavailable',
    () async {
      messenger.setMockMethodCallHandler(
        MethodChannelHealthReminderNotifications.channel,
        (call) async {
          return call.method == 'consumeOpen'
              ? {'owner': 3, 'eventId': null}
              : 'future-status';
        },
      );
      expect(
        await service.permission(),
        ReminderNotificationPermission.unavailable,
      );
      expect(await service.consumeOpen(), isNull);
      messenger.setMockMethodCallHandler(
        MethodChannelHealthReminderNotifications.channel,
        (call) async {
          throw PlatformException(code: 'UNAVAILABLE');
        },
      );
      expect(
        await service.permission(),
        ReminderNotificationPermission.unavailable,
      );
      expect(await service.consumeOpen(), isNull);
    },
  );
}
