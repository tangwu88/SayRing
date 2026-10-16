import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('test/qring/gesture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));
  test(
    'gesture snapshot preserves actual modes and rejects invalid/stale inputs locally',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return call.method == 'readDeviceFeature'
            ? {
                'rawMode': 2,
                'confirmedMode': 1,
                'availableModes': [0, 1, 4],
                'readbackVerified': true,
                'strength': 7,
                'touch': false,
              }
            : null;
      });
      final bridge = QRingWearableBridge(methods: methods);
      final snapshot = await bridge.readDeviceFeature(
        DeviceFeature.gestureControl,
      );
      expect(snapshot['confirmedMode'], 1);
      expect(snapshot['availableModes'], [0, 1, 4]);
      expect(snapshot['strength'], 7);
      for (var mode = 0; mode <= 5; mode++) {
        await bridge.writeDeviceFeature(DeviceFeature.gestureControl, {
          'mode': mode,
          'expectedMode': 2,
        });
        expect(calls.last.arguments, {
          'feature': 'gesture_control',
          'values': {'mode': mode, 'expectedMode': 2},
        });
      }
      final count = calls.length;
      for (final invalid in [
        {'mode': -1, 'expectedMode': 2},
        {'mode': 6, 'expectedMode': 2},
        {'mode': true, 'expectedMode': 2},
        {'mode': 1},
        {'mode': 1, 'expectedMode': false},
        {'mode': 1, 'expectedMode': 10},
      ]) {
        await expectLater(
          bridge.writeDeviceFeature(DeviceFeature.gestureControl, invalid),
          throwsA(isA<PlatformException>()),
        );
      }
      expect(calls, hasLength(count));
    },
  );
}
