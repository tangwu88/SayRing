import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/coolwear_wearable_bridge.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/services/wearable_routing.dart';

const _uuid = '11111111-2222-4333-8444-555555555555';
const _profile = WearableUserProfile(
  gender: 1,
  heightCm: 175,
  weightKg: 70,
  birthYear: 1996,
  age: 30,
  targetSteps: 10000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS monitoring timeout outlives the native queue and is handled',
    (tester) async {
      const channel = MethodChannel('test/coolwear/ios-monitoring-deadline');
      final response = Completer<Object?>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) => response.future);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final ios = CoolWearIosWearableBridge(methods: channel);
      Object? error;
      var finished = false;
      final pending = ios
          .setAutoMeasureSetting('heartRate', true)
          .then(
            (_) {
              finished = true;
            },
            onError: (Object value) {
              error = value;
              finished = true;
            },
          );
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      expect(finished, isFalse);
      await tester.pump(const Duration(seconds: 25));
      await pending;
      expect(
        error,
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'COOLWEAR_OPERATION_TIMEOUT',
        ),
      );
      response.complete(null);
      await tester.pump();
    },
  );

  test(
    'iOS health monitoring forwards real settings but no unverified warning',
    () async {
      const channel = MethodChannel('test/coolwear/ios-monitoring');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'readAutoMeasureSettings') {
          return {
            'heartRate': true,
            'heartRate24h': false,
            'bloodOxygen': false,
          };
        }
        if (call.method == 'readAutoMeasureIntervals') {
          return <String, Object?>{};
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final ios = CoolWearIosWearableBridge(methods: channel);
      expect(await ios.readAutoMeasureSettings(), {
        'heartRate': true,
        'heartRate24h': false,
        'bloodOxygen': false,
      });
      await ios.setAutoMeasureSetting('heartRate24h', true);
      expect(calls.last.arguments, {'type': 'heartRate24h', 'enabled': true});
      expect(await ios.readAutoMeasureIntervals(), isEmpty);
      expect(await ios.readHeartRateWarning(), isNull);
      expect(calls.map((c) => c.method), [
        'readAutoMeasureSettings',
        'setAutoMeasureSetting',
        'readAutoMeasureIntervals',
      ]);
    },
  );

  test(
    'only iOS exposes exact recovery and forwards owner context and cancellation',
    () async {
      const channel = MethodChannel('test/coolwear/ios');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(
        CoolWearWearableBridge(methods: channel),
        isNot(isA<WearableExactTargetRecoveryBridge>()),
      );
      final ios = CoolWearIosWearableBridge(methods: channel);
      await ios.configureRecoveryTarget(
        nativeIdentifier: _uuid,
        knownName: 'HR01',
        contextKey: 'env:owner',
      );
      await ios.configureRecoveryTarget(nativeIdentifier: null);
      expect(calls.map((call) => call.method), [
        'configureRecoveryTarget',
        'configureRecoveryTarget',
      ]);
      expect(calls.first.arguments, {
        'id': _uuid,
        'name': 'HR01',
        'context': 'env:owner',
      });
      expect((calls.last.arguments as Map)['id'], isNull);
    },
  );

  test(
    'CoolWear native waiting does not end recovery; foreign and retired reconnects are discarded',
    () async {
      final source = _ExactCoolWear();
      final store = _Store();
      final bridge = RoutedWearableBridge(
        veepoo: _Empty(),
        yucheng: _Empty(),
        coolwear: source,
        preferenceStore: store,
        restoreOnlyBoundDevice: true,
        requireOwnerScopedBinding: true,
      );
      final received = <WearableEvent>[];
      final subscription = bridge.events.listen(received.add);
      addTearDown(() async {
        await subscription.cancel();
        await bridge.dispose();
        await source.eventsSource.close();
      });
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      expect(await bridge.restoreConnection(profile: _profile), isNull);
      expect(source.targets.last, _uuid);
      expect(source.scanCount, 0); // Native now owns continuing discovery.
      source.eventsSource.add(
        const WearableEvent(
          type: 'recoveryState',
          payload: {'status': 'waiting', 'deviceId': _uuid},
        ),
      );
      source.eventsSource.add(
        const WearableEvent(
          type: 'reconnected',
          payload: {'id': 'foreign', 'name': 'HR01'},
        ),
      );
      source.eventsSource.add(
        const WearableEvent(
          type: 'reconnected',
          payload: {'id': _uuid, 'name': 'HR01'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        received.where((event) => event.type == 'recoveryState').length,
        1,
      );
      expect(
        received
            .where((event) => event.type == 'reconnected')
            .single
            .payload['id'],
        'coolwear:$_uuid',
      );
      await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
      expect(source.targets.last, isNull);
      expect(await bridge.restoreConnection(profile: _profile), isNull);
      source.eventsSource.add(
        const WearableEvent(
          type: 'reconnected',
          payload: {'id': _uuid, 'name': 'HR01'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(received.where((event) => event.type == 'reconnected').length, 1);
      expect(store.binding?.nativeIdentifier, _uuid);
    },
  );
}

class _Empty extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
  @override
  Future<void> disconnect() async {}
}

class _ExactCoolWear extends _Empty
    implements WearableExactTargetRecoveryBridge, WearableDeviceDetailsBridge {
  final eventsSource = StreamController<WearableEvent>.broadcast();
  final targets = <String?>[];
  int scanCount = 0;
  @override
  Stream<WearableEvent> get events => eventsSource.stream;
  @override
  Future<void> configureRecoveryTarget({
    required String? nativeIdentifier,
    String? knownName,
    String? contextKey,
    WearableUserProfile? profile,
  }) async {
    targets.add(nativeIdentifier);
  }

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async => null;
  @override
  Future<List<DeviceInfo>> scanDevices() async {
    scanCount++;
    return [];
  }
}

class _Store implements WearableBindingPreferenceStore {
  SavedWearableBinding? binding = const SavedWearableBinding(
    WearableTransport.coolwear,
    _uuid,
    deviceName: 'HR01',
    ownerKey: 'owner-a',
  );
  @override
  Future<SavedWearableBinding?> readBinding() async => binding;
  @override
  Future<void> writeBinding(SavedWearableBinding value) async {
    binding = value;
  }

  @override
  Future<WearableTransport?> read() async => binding?.transport;
  @override
  Future<void> write(WearableTransport transport) async {}
  @override
  Future<void> clear() async {
    binding = null;
  }
}
