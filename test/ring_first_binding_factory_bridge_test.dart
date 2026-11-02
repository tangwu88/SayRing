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
      final sessionChanged = throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'QRING_SESSION_CHANGED',
        ),
      );
      final readRejected = expectLater(pendingRead, sessionChanged);
      await Future<void>.delayed(Duration.zero);
      final reset = bridge.clearRingHistory(
        deviceId: 'ring-a',
        ownerKey: 'owner-a',
        allowFactoryReset: true,
      );
      final rejected = expectLater(reset, sessionChanged);
      await bridge.configureRecoveryTarget(nativeIdentifier: null);
      expect(calls, ['readDeviceFeature', 'configureRecoveryTarget']);
      read.complete({});
      // The old owner's late read is rejected too, rather than exposed to the
      // current session. This does not release or replay the queued reset.
      await readRejected;
      await rejected;
      expect(calls, ['readDeviceFeature', 'configureRecoveryTarget']);
    },
  );
}
