import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('test/qring/session-queue');
  const events = EventChannel('test/qring/session-queue/events');
  const profile = WearableUserProfile(
    gender: 1,
    heightCm: 175,
    weightKg: 70,
    birthYear: 1996,
    age: 30,
    targetSteps: 10000,
  );
  const deviceId = '11111111-2222-4333-8444-555555555555';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final changedSession = throwsA(
    isA<PlatformException>().having(
      (error) => error.code,
      'code',
      'QRING_SESSION_CHANGED',
    ),
  );

  Future<void> flush() => Future<void>.delayed(Duration.zero);
  Future<void> emit(String type) async {
    final delivered = Completer<void>();
    messenger.handlePlatformMessage(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'type': type,
        'payload': {'deviceId': deviceId},
      }),
      (_) => delivered.complete(),
    );
    await delivered.future;
    await flush();
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(MethodChannel(events.name), null);
  });

  test(
    'confirmed teardown frees new reads without the retired reply',
    () async {
      final oldReply = Completer<Object?>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        if (call.method == 'readDeviceFeature') return oldReply.future;
        if (call.method == 'getDeviceDetails') {
          return {'id': deviceId, 'name': 'R8'};
        }
        return null;
      });
      final bridge = QRingWearableBridge(methods: methods);
      final old = expectLater(
        bridge.readDeviceFeature(DeviceFeature.gestureControl),
        changedSession,
      );
      await flush();
      await bridge.disconnect();
      await bridge.connect(deviceId, profile: profile);
      expect((await bridge.getConnectedDeviceDetails())?.id, deviceId);
      await old;
      expect(oldReply.isCompleted, isFalse);
      expect(calls, [
        'readDeviceFeature',
        'disconnect',
        'connect',
        'getDeviceDetails',
      ]);
      // Late completion is consumed, without reinstating the old session.
      oldReply.complete({'confirmedMode': 4});
      await flush();
      expect((await bridge.getConnectedDeviceDetails())?.id, deviceId);
    },
  );

  test(
    'queued stale write is never dispatched after confirmed teardown',
    () async {
      final oldReply = Completer<Object?>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        if (call.method == 'readAutoMeasureSettings') return oldReply.future;
        return null;
      });
      final bridge = QRingWearableBridge(methods: methods);
      final old = expectLater(bridge.readAutoMeasureSettings(), changedSession);
      final queuedWrite = expectLater(
        bridge.writeDeviceFeature(DeviceFeature.gestureControl, {
          'mode': 1,
          'expectedMode': 0,
        }),
        changedSession,
      );
      await flush();
      await bridge.disconnect();
      await bridge.getConnectedDeviceDetails();
      await Future.wait([old, queuedWrite]);
      expect(calls, [
        'readAutoMeasureSettings',
        'disconnect',
        'getDeviceDetails',
      ]);
      oldReply.complete({});
    },
  );

  test(
    'an ambiguous write holds the queue until teardown is confirmed',
    () async {
      final writeReply = Completer<Object?>();
      final teardown = Completer<Object?>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        if (call.method == 'writeDeviceFeature') return writeReply.future;
        if (call.method == 'disconnect') return teardown.future;
        return null;
      });
      final bridge = QRingWearableBridge(methods: methods);
      final old = expectLater(
        bridge.writeDeviceFeature(DeviceFeature.gestureControl, {
          'mode': 1,
          'expectedMode': 0,
        }),
        changedSession,
      );
      await flush();
      final disconnect = bridge.disconnect();
      final next = bridge.getConnectedDeviceDetails();
      await flush();
      expect(calls, ['writeDeviceFeature', 'disconnect']);
      teardown.complete();
      await disconnect;
      await next;
      await old;
      expect(calls.last, 'getDeviceDetails');
      expect(writeReply.isCompleted, isFalse);
      writeReply.completeError(PlatformException(code: 'LATE_NATIVE_REPLY'));
      await flush();
    },
  );

  test('failed teardown does not release pending physical commands', () async {
    final oldReply = Completer<Object?>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      if (call.method == 'writeDeviceFeature') return oldReply.future;
      if (call.method == 'disconnect') {
        throw PlatformException(code: 'RECOVERY_PENDING');
      }
      return null;
    });
    final bridge = QRingWearableBridge(methods: methods);
    final old = expectLater(
      bridge.writeDeviceFeature(DeviceFeature.gestureControl, {
        'mode': 1,
        'expectedMode': 0,
      }),
      changedSession,
    );
    await flush();
    await expectLater(bridge.disconnect(), throwsA(isA<PlatformException>()));
    final next = bridge.getConnectedDeviceDetails();
    await flush();
    expect(calls, ['writeDeviceFeature', 'disconnect']);
    oldReply.complete();
    await old;
    await next;
    expect(calls.last, 'getDeviceDetails');
  });

  test('arming recovery alone cannot release an active command', () async {
    final oldReply = Completer<Object?>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      if (call.method == 'readDeviceFeature') return oldReply.future;
      return null;
    });
    final bridge = QRingWearableBridge(methods: methods);
    final old = expectLater(
      bridge.readDeviceFeature(DeviceFeature.gestureControl),
      changedSession,
    );
    await flush();
    await bridge.configureRecoveryTarget(
      nativeIdentifier: deviceId,
      knownName: 'R8',
      contextKey: 'owner-test',
      profile: profile,
    );
    final next = bridge.getConnectedDeviceDetails();
    await flush();
    expect(calls, ['readDeviceFeature', 'configureRecoveryTarget']);
    oldReply.complete({'confirmedMode': 1});
    await old;
    await next;
  });

  test(
    'failed connect does not release old queue but successful handshake does',
    () async {
      final oldReply = Completer<Object?>();
      final calls = <String>[];
      var connects = 0;
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        if (call.method == 'readDeviceFeature') return oldReply.future;
        if (call.method == 'connect' && ++connects == 1) {
          throw PlatformException(code: 'CONNECT_BUSY');
        }
        return null;
      });
      final bridge = QRingWearableBridge(methods: methods);
      final old = expectLater(
        bridge.readDeviceFeature(DeviceFeature.gestureControl),
        changedSession,
      );
      await flush();
      await expectLater(
        bridge.connect(deviceId, profile: profile),
        throwsA(isA<PlatformException>()),
      );
      final staleQueuedRead = expectLater(
        bridge.getConnectedDeviceDetails(),
        changedSession,
      );
      await flush();
      expect(calls, ['readDeviceFeature', 'connect']);
      await bridge.connect(deviceId, profile: profile);
      await Future.wait([old, staleQueuedRead]);
      await bridge.getConnectedDeviceDetails();
      expect(calls, [
        'readDeviceFeature',
        'connect',
        'connect',
        'getDeviceDetails',
      ]);
      oldReply.complete({});
    },
  );

  test(
    'natural recovery waits for ready and handles duplicate events once',
    () async {
      final oldReply = Completer<Object?>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(
        MethodChannel(events.name),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        if (call.method == 'readDeviceFeature') return oldReply.future;
        return null;
      });
      final bridge = QRingWearableBridge(methods: methods, events: events);
      final first = bridge.events.listen((_) {});
      final second = bridge.events.listen((_) {});
      addTearDown(first.cancel);
      addTearDown(second.cancel);
      final old = expectLater(
        bridge.readDeviceFeature(DeviceFeature.gestureControl),
        changedSession,
      );
      await flush();
      await emit('disconnected');
      final next = bridge.getConnectedDeviceDetails();
      await emit('disconnected');
      expect(calls, ['readDeviceFeature']);
      await emit('reconnected');
      await old;
      await next;
      expect(calls, ['readDeviceFeature', 'getDeviceDetails']);
      oldReply.complete({});
      await emit('reconnected');
      await bridge.getConnectedDeviceDetails();
      expect(calls.last, 'getDeviceDetails');
    },
  );

  test('same-session operations remain strictly serial', () async {
    final readReply = Completer<Object?>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      if (call.method == 'readDeviceFeature') return readReply.future;
      return null;
    });
    final bridge = QRingWearableBridge(methods: methods);
    final read = bridge.readDeviceFeature(DeviceFeature.gestureControl);
    final write = bridge.writeDeviceFeature(DeviceFeature.gestureControl, {
      'mode': 1,
      'expectedMode': 0,
    });
    await flush();
    expect(calls, ['readDeviceFeature']);
    readReply.complete({'confirmedMode': 0});
    expect((await read)['confirmedMode'], 0);
    await write;
    expect(calls, ['readDeviceFeature', 'writeDeviceFeature']);
  });
}
