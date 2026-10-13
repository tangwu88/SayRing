import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/coolwear_wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final ios in [false, true]) {
    test('gesture mode contract forwards six modes on ios=$ios', () async {
      final channel = MethodChannel('test/gesture/$ios');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'readDeviceFeature' ? {'confirmedMode': 2} : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final bridge = ios
          ? CoolWearIosWearableBridge(methods: channel)
          : CoolWearWearableBridge(methods: channel);
      expect(await bridge.readDeviceFeature(DeviceFeature.gestureControl), {
        'confirmedMode': 2,
      });
      for (var mode = 0; mode <= 5; mode++) {
        await bridge.writeDeviceFeature(DeviceFeature.gestureControl, {
          'mode': mode,
        });
        expect(calls.last.arguments, {
          'feature': 'gesture_control',
          'values': {'mode': mode},
        });
      }
      for (final invalid in [null, -1, 6, 4.0, '4', true]) {
        await expectLater(
          bridge.writeDeviceFeature(DeviceFeature.gestureControl, {
            'mode': invalid,
          }),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'INVALID_GESTURE_MODE',
            ),
          ),
        );
      }
      expect(calls, hasLength(7));
    });
  }

  test(
    'native failure cannot be transformed into a successful mode update',
    () async {
      const channel = MethodChannel('test/gesture/error');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (_) => throw PlatformException(code: 'GESTURE_CONFIRMATION_TIMEOUT'),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await expectLater(
        CoolWearWearableBridge(
          methods: channel,
        ).writeDeviceFeature(DeviceFeature.gestureControl, {'mode': 1}),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
