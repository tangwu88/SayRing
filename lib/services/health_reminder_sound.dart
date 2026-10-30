import 'package:flutter/services.dart';

/// A short, foreground-only tone. Tokens keep late cleanup from stopping a
/// newer reminder. No health values or account details go to this channel.
abstract interface class HealthReminderSound {
  Future<bool> play(String token);
  Future<void> stop(String token);
}

final class MethodChannelHealthReminderSound implements HealthReminderSound {
  const MethodChannelHealthReminderSound();
  static const channel = MethodChannel('cn.saydian.ring/health_reminder_sound');

  @override
  Future<bool> play(String token) async {
    try {
      return await channel.invokeMethod<bool>('play', {'token': token}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> stop(String token) async {
    try {
      await channel.invokeMethod<void>('stop', {'token': token});
    } on PlatformException {
      // Visual acknowledgement remains available when audio is unavailable.
    } on MissingPluginException {
      // Unsupported hosts have no player to stop.
    }
  }
}
