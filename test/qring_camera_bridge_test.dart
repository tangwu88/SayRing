import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('test/qring/camera');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  test(
    'only the mapped QRing camera feature reaches native commands',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return call.method == 'readDeviceFeature'
            ? {'mode': 5, 'enabled': true, 'touch': false, 'strength': 7}
            : null;
      });
      final bridge = QRingWearableBridge(methods: methods);
      expect((await bridge.readDeviceFeature(DeviceFeature.camera))['mode'], 5);
      await bridge.writeDeviceFeature(DeviceFeature.camera, {
        'enabled': false,
        'expectedMode': 5,
      });
      expect(calls.last.arguments, {
        'feature': 'camera',
        'values': {'enabled': false, 'expectedMode': 5},
      });
      await expectLater(
        bridge.readDeviceFeature(DeviceFeature.gestureControl),
        throwsA(isA<PlatformException>()),
      );
      await bridge.triggerDeviceAction(DeviceFeature.camera);
      expect(calls.last.arguments, {'feature': 'camera', 'enabled': true});
      await bridge.triggerDeviceAction(DeviceFeature.camera, enabled: false);
      expect(calls.last.arguments, {'feature': 'camera', 'enabled': false});
      await expectLater(
        bridge.triggerDeviceAction(DeviceFeature.gestureControl),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, hasLength(4));
    },
  );

  test(
    'camera read waits for monitoring commands and native error releases queue',
    () async {
      final release = Completer<Object?>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        if (call.method == 'readAutoMeasureSettings') return release.future;
        throw PlatformException(code: 'QRING_CONTROL_UNCONFIRMED');
      });
      final bridge = QRingWearableBridge(methods: methods);
      final monitoring = bridge.readAutoMeasureSettings();
      final camera = bridge.readDeviceFeature(DeviceFeature.camera);
      final cameraExpectation = expectLater(
        camera,
        throwsA(isA<PlatformException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['readAutoMeasureSettings']);
      release.complete({'heartRate': true});
      await monitoring;
      await cameraExpectation;
      await expectLater(
        bridge.readDeviceFeature(DeviceFeature.camera),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, [
        'readAutoMeasureSettings',
        'readDeviceFeature',
        'readDeviceFeature',
      ]);
    },
  );

  test(
    'disconnect preempts monitoring and invalidates a queued camera write',
    () async {
      final release = Completer<Object?>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        return call.method == 'readAutoMeasureSettings' ? release.future : null;
      });
      final bridge = QRingWearableBridge(methods: methods);
      final monitoring = bridge.readAutoMeasureSettings();
      final camera = bridge.writeDeviceFeature(DeviceFeature.camera, {
        'enabled': true,
        'expectedMode': 0,
      });
      final expectation = expectLater(
        camera,
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'QRING_SESSION_CHANGED',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await bridge.disconnect();
      expect(calls, ['readAutoMeasureSettings', 'disconnect']);
      release.complete({});
      await monitoring;
      await expectation;
      expect(calls, ['readAutoMeasureSettings', 'disconnect']);
    },
  );
}
