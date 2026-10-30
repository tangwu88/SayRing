import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_reminder.dart';
import 'package:saydian_app/domain/reading_reminder.dart';
import 'package:saydian_app/services/health_reminder_sound.dart';
import 'package:saydian_app/ui/reading_reminder_widgets.dart';

class _Sound implements HealthReminderSound {
  final plays = <String>[];
  final stops = <String>[];
  Completer<bool>? pending;
  @override
  Future<bool> play(String token) async {
    plays.add(token);
    return pending?.future ?? true;
  }

  @override
  Future<void> stop(String token) async => stops.add(token);
}

Widget _page(_Sound sound, {bool enabled = true, bool reduced = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: ReadingReminderAlertView(
          kind: HealthReminderKind.highHeartRate,
          reading: 125,
          preview: true,
          sound: sound,
          soundEnabled: enabled,
          onDismiss: () {},
          onHelp: () {},
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'old settings retain thresholds and vibration with the new sound preference',
    () {
      final old = const ReadingReminderSettings(
        highEnabled: true,
        high: 150,
        ringVibrationEnabled: false,
      ).toJson()..remove('phoneSoundEnabled');
      final settings = ReadingReminderSettings.parse(jsonEncode(old))!;
      expect(settings.high, 150);
      expect(settings.highEnabled, isTrue);
      expect(settings.ringVibrationEnabled, isFalse);
      expect(settings.phoneSoundEnabled, isTrue);
      expect(
        settings.copyWith(phoneSoundEnabled: false).comparisonFingerprint,
        settings.comparisonFingerprint,
      );
      expect(
        settings.copyWith(phoneSoundEnabled: false).fingerprint,
        isNot(settings.fingerprint),
      );
      expect(
        ReadingReminderSettings.parse(
          jsonEncode({...old, 'phoneSoundEnabled': 'true'}),
        ),
        isNull,
      );
      final muted = ReadingReminderSettings.parse(
        jsonEncode(settings.copyWith(phoneSoundEnabled: false).toJson()),
      )!;
      expect(muted.phoneSoundEnabled, isFalse);
    },
  );

  test(
    'sound channel sends only a bounded token and survives missing native support',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(
        MethodChannelHealthReminderSound.channel,
        (call) async {
          calls.add(call);
          return call.method == 'play';
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          MethodChannelHealthReminderSound.channel,
          null,
        ),
      );
      const sound = MethodChannelHealthReminderSound();
      expect(await sound.play('reading-123-1'), isTrue);
      await sound.stop('reading-123-1');
      expect(calls.map((c) => c.method), ['play', 'stop']);
      expect(
        calls.every((c) => (c.arguments as Map).keys.single == 'token'),
        isTrue,
      );
      messenger.setMockMethodCallHandler(
        MethodChannelHealthReminderSound.channel,
        (_) => throw PlatformException(code: 'UNAVAILABLE'),
      );
      expect(await sound.play('reading-123-2'), isFalse);
      await sound.stop('reading-123-2');
    },
  );

  testWidgets(
    'preview plays once across animation/rebuilds and silence never replays',
    (tester) async {
      final sound = _Sound();
      await tester.pumpWidget(_page(sound));
      await tester.pump(const Duration(milliseconds: 150));
      expect(sound.plays, hasLength(1));
      final scale = tester
          .widget<Transform>(
            find.byKey(const Key('reading-reminder-heartbeat')),
          )
          .transform
          .storage[0];
      await tester.pump(const Duration(milliseconds: 240));
      expect(
        tester
            .widget<Transform>(
              find.byKey(const Key('reading-reminder-heartbeat')),
            )
            .transform
            .storage[0],
        isNot(scale),
      );
      expect(find.byKey(const Key('reading-reminder-wave-0')), findsOneWidget);
      await tester.pumpWidget(_page(sound));
      await tester.pump(const Duration(milliseconds: 300));
      expect(sound.plays, hasLength(1));
      await tester.ensureVisible(
        find.byKey(const Key('reading-reminder-silence')),
      );
      await tester.tap(find.byKey(const Key('reading-reminder-silence')));
      await tester.pump();
      expect(sound.stops, contains(sound.plays.single));
      await tester.pump(const Duration(seconds: 2));
      expect(sound.plays, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disabled sound stays silent while reduced motion remains static',
    (tester) async {
      final sound = _Sound();
      await tester.pumpWidget(_page(sound, enabled: false, reduced: true));
      await tester.pump(const Duration(seconds: 1));
      expect(sound.plays, isEmpty);
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byKey(const Key('reading-reminder-wave-0')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'background and disposal stop playback without replay on resume',
    (tester) async {
      final sound = _Sound();
      await tester.pumpWidget(_page(sound));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(sound.stops, contains(sound.plays.single));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));
      expect(sound.plays, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabling sound during preparation stops a late acceptance', (
    tester,
  ) async {
    final sound = _Sound()..pending = Completer<bool>();
    await tester.pumpWidget(_page(sound));
    await tester.pump();
    final token = sound.plays.single;
    await tester.pumpWidget(_page(sound, enabled: false));
    sound.pending!.complete(true);
    await tester.pump();
    expect(sound.stops, contains(token));
    expect(sound.plays, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late native preparation cannot restart a disposed preview', (
    tester,
  ) async {
    final sound = _Sound()..pending = Completer<bool>();
    await tester.pumpWidget(_page(sound));
    await tester.pump();
    final token = sound.plays.single;
    await tester.pumpWidget(const SizedBox());
    sound.pending!.complete(true);
    await tester.pump();
    expect(sound.stops, contains(token));
    expect(sound.plays, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
