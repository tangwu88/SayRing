import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('test/qring/connection-snapshot');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  test(
    'only iOS exposes the native command-free connection snapshot',
    () async {
      expect(
        QRingWearableBridge(),
        isNot(isA<WearableConnectionSnapshotBridge>()),
      );
      final pendingRead = Completer<Object?>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        if (call.method == 'readDeviceFeature') return pendingRead.future;
        if (call.method == 'getDeviceSnapshot') {
          return {'id': 'snapshot-target', 'name': 'R8'};
        }
        fail('Snapshot must not trigger optional details: ${call.method}');
      });
      final bridge = QRingIosWearableBridge(methods: methods);
      final old = bridge.readDeviceFeature(DeviceFeature.gestureControl);
      await Future<void>.delayed(Duration.zero);
      final snapshot = await bridge.getConnectedDeviceSnapshot();
      expect(snapshot?.id, 'snapshot-target');
      expect(snapshot?.battery, isNull);
      expect(snapshot?.firmwareVersion, isNull);
      expect(calls, ['readDeviceFeature', 'getDeviceSnapshot']);
      expect(pendingRead.isCompleted, isFalse);
      pendingRead.complete({'confirmedMode': 0});
      await old;
    },
  );

  test('missing native handshake snapshot stays unknown', () async {
    messenger.setMockMethodCallHandler(methods, (_) async => null);
    expect(
      await QRingIosWearableBridge(
        methods: methods,
      ).getConnectedDeviceSnapshot(),
      isNull,
    );
  });

  test('a retired connection cannot return its late snapshot', () async {
    final pendingSnapshot = Completer<Object?>();
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'getDeviceSnapshot') return pendingSnapshot.future;
      return null;
    });
    final bridge = QRingIosWearableBridge(methods: methods);
    final assertion = expectLater(
      bridge.getConnectedDeviceSnapshot(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'QRING_SESSION_CHANGED',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await bridge.disconnect();
    pendingSnapshot.complete({'id': 'retired-target', 'name': 'R8'});
    await assertion;
  });
}
