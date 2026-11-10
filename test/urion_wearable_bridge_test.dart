import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/urion_wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stalled native connection is closed before the next attempt', () async {
    const methods = MethodChannel('test/urion-stalled-methods');
    const events = EventChannel('test/urion-stalled-events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final stalledConnect = Completer<Map<Object?, Object?>>();
    var disconnects = 0;
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'connect') return stalledConnect.future;
      if (call.method == 'disconnect') {
        disconnects++;
        return null;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('test/urion-stalled-events'),
      (_) async => null,
    );
    final bridge = UrionWearableBridge(
      methods: methods,
      eventChannel: events,
      connectTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(() async {
      await bridge.dispose();
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockMethodCallHandler(
        const MethodChannel('test/urion-stalled-events'),
        null,
      );
    });

    await expectLater(
      bridge.connect(
        'candidate',
        profile: const WearableUserProfile(
          gender: 1,
          heightCm: 170,
          weightKg: 65,
          birthYear: 1990,
          age: 36,
          targetSteps: 6000,
        ),
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'CONNECT_TIMEOUT',
        ),
      ),
    );
    expect(disconnects, 1);
  });
}
