import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/first-ring-factory');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'factory-only adapter requires explicit authorization, no native write by default',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (c) async {
        calls.add(c);
        return 'factoryResetRequested';
      });
      final bridge = QRingWearableBridge(methods: channel);
      await expectLater(
        bridge.clearRingHistory(deviceId: 'ring-a', ownerKey: 'owner-a'),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, isEmpty);
      expect(
        await bridge.clearRingHistory(
          deviceId: 'ring-a',
          ownerKey: 'owner-a',
          allowFactoryReset: true,
        ),
        RingDataClearResult.factoryResetRequested,
      );
      expect(calls, hasLength(1));
      expect(calls.single.arguments, {
        'id': 'ring-a',
        'ownerKey': 'owner-a',
        'allowFactoryReset': true,
      });
    },
  );
  test(
    'an ambiguous factory result is not retried or called acknowledged',
    () async {
      var writes = 0;
      messenger.setMockMethodCallHandler(channel, (c) async {
        writes++;
        return null;
      });
      await expectLater(
        QRingWearableBridge(methods: channel).clearRingHistory(
          deviceId: 'ring-a',
          ownerKey: 'owner-a',
          allowFactoryReset: true,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(writes, 1);
    },
  );
  test(
    'owner change preempts a queued factory reset before it is sent',
    () async {
      final read = Completer<Map<Object?, Object?>>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (c) async {
        calls.add(c.method);
        if (c.method == 'readDeviceFeature') return read.future;
        return null;
      });
      final bridge = QRingWearableBridge(methods: channel);
      final pendingRead = bridge.readDeviceFeature(
        DeviceFeature.gestureControl,
      );
      await Future<void>.delayed(Duration.zero);
      final reset = bridge.clearRingHistory(
        deviceId: 'ring-a',
        ownerKey: 'owner-a',
        allowFactoryReset: true,
      );
      final rejected = expectLater(reset, throwsA(isA<PlatformException>()));
      await bridge.configureRecoveryTarget(nativeIdentifier: null);
      read.complete({});
      await pendingRead;
      await rejected;
      expect(calls, isNot(contains('clearRingHistory')));
    },
  );
}
