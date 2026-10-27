import 'package:flutter/services.dart';

enum ReminderNotificationPermission {
  granted,
  denied,
  notDetermined,
  unavailable,
}

final class HealthReminderNotificationOpen {
  const HealthReminderNotificationOpen(this.owner, this.eventId);
  final String owner;
  final String eventId;
}

abstract interface class HealthReminderNotifications {
  Future<void> setOwner(String? owner);
  Future<ReminderNotificationPermission> permission({bool request = false});
  Future<bool> show({required String owner, required String eventId});
  Future<void> cancel(String eventId);
  Future<HealthReminderNotificationOpen?> consumeOpen();
}

final class MethodChannelHealthReminderNotifications
    implements HealthReminderNotifications {
  const MethodChannelHealthReminderNotifications();
  static const channel = MethodChannel('cn.saydian.ring/health_reminders');

  @override
  Future<void> setOwner(String? owner) async {
    try {
      await channel.invokeMethod<void>('setOwner', {'owner': owner});
    } on MissingPluginException {
      // No native channel on unsupported hosts; never claim notifications work.
    }
  }

  @override
  Future<ReminderNotificationPermission> permission({
    bool request = false,
  }) async {
    try {
      final result = await channel.invokeMethod<String>(
        request ? 'requestPermission' : 'permission',
      );
      return ReminderNotificationPermission.values.firstWhere(
        (value) => value.name == result,
        orElse: () => ReminderNotificationPermission.unavailable,
      );
    } on PlatformException {
      return ReminderNotificationPermission.unavailable;
    } on MissingPluginException {
      return ReminderNotificationPermission.unavailable;
    }
  }

  @override
  Future<bool> show({required String owner, required String eventId}) async =>
      await channel.invokeMethod<bool>('show', {
        'owner': owner,
        'eventId': eventId,
      }) ??
      false;

  @override
  Future<void> cancel(String eventId) async {
    try {
      await channel.invokeMethod<void>('cancel', {'eventId': eventId});
    } on MissingPluginException {
      // No event could have been scheduled on this host.
    }
  }

  @override
  Future<HealthReminderNotificationOpen?> consumeOpen() async {
    try {
      final value = await channel.invokeMapMethod<String, Object?>(
        'consumeOpen',
      );
      final owner = value?['owner'];
      final event = value?['eventId'];
      if (owner is! String || event is! String) return null;
      return HealthReminderNotificationOpen(owner, event);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

final class DisabledHealthReminderNotifications
    implements HealthReminderNotifications {
  const DisabledHealthReminderNotifications();
  @override
  Future<void> setOwner(String? owner) async {}
  @override
  Future<ReminderNotificationPermission> permission({
    bool request = false,
  }) async => ReminderNotificationPermission.unavailable;
  @override
  Future<bool> show({required String owner, required String eventId}) async =>
      false;
  @override
  Future<void> cancel(String eventId) async {}
  @override
  Future<HealthReminderNotificationOpen?> consumeOpen() async => null;
}
