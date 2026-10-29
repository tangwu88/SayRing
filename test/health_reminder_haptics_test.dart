import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/coolwear_wearable_bridge.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'accepted-but-unacknowledged or malformed native results never become acknowledgements',
    () {
      expect(
        RingReminderHapticResult.fromMap({
          'accepted': true,
          'acknowledged': false,
        }).acknowledged,
        isFalse,
      );
      expect(
        RingReminderHapticResult.fromMap({
          'accepted': false,
          'acknowledged': true,
        }).acknowledged,
        isFalse,
      );
      expect(
        RingReminderHapticResult.fromMap({
          'accepted': 1,
          'acknowledged': 1,
        }).accepted,
        isFalse,
      );
      expect(RingReminderHapticResult.fromMap(null).accepted, isFalse);
    },
  );
  for (final vendor in ['coolwear', 'qring']) {
    test(
      '$vendor pulse forwards an exact target and preserves native acknowledgement semantics',
      () async {
        final channel = MethodChannel('test/haptic/$vendor');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {'accepted': true, 'acknowledged': false};
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final WearableHealthReminderHapticsBridge bridge = vendor == 'coolwear'
            ? CoolWearIosWearableBridge(methods: channel)
            : QRingWearableBridge(methods: channel);
        final result = await bridge.pulseHealthReminder(
          expectedDeviceId: 'synthetic-exact-target',
        );
        expect(result.accepted, isTrue);
        expect(result.acknowledged, isFalse);
        expect(calls.single.method, 'pulseHealthReminder');
        expect(calls.single.arguments, {
          'expectedDeviceId': 'synthetic-exact-target',
        });
      },
    );
  }
}
