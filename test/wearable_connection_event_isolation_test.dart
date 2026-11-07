import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/services/wearable_routing.dart';

const _profile = WearableUserProfile(
  gender: 1,
  heightCm: 175,
  weightKg: 70,
  birthYear: 1996,
  age: 30,
  targetSteps: 10000,
);

void main() {
  for (final response in ['empty', 'details', 'error']) {
    test(
      'late $response details cannot retire the replacement connection',
      () async {
        final native = _DetailsNative('R7 Ultra');
        final bridge = _router(native, WearableTransport.coolwear);
        addTearDown(bridge.dispose);
        await bridge.scanDevices();
        await bridge.connect('coolwear:previous-ring', profile: _profile);
        final old = Completer<DeviceInfo?>();
        native.deferred = old;
        final pending = bridge.getConnectedDeviceDetails();
        native.deferred = null;
        await bridge.connect('coolwear:current-ring', profile: _profile);
        final result = expectLater(pending, completion(isNull));
        if (response == 'error') {
          old.completeError(StateError('retired metadata query'));
        } else {
          old.complete(
            response == 'empty'
                ? null
                : const DeviceInfo(id: 'previous-ring', name: 'R7 Ultra'),
          );
        }
        await result;
        await bridge.startMeasurement(HealthMetric.heartRate);
        expect(native.measurements, 1);
        expect(native.disconnects, 0);
      },
    );
  }
  for (final name in ['R7 Ultra', 'R8', 'YC Ring', 'V Ring', 'D Ring']) {
    final transport = WearableDeviceClassifier.transportFor(name)!;
    for (final type in ['reconnected', 'deviceDetails', 'healthRecord']) {
      test(
        '$name rejects old target $type but keeps current scoped events',
        () async {
          final native = _Native(name);
          final bridge = _router(native, transport);
          addTearDown(bridge.dispose);
          final events = <WearableEvent>[];
          final subscription = bridge.events.listen(events.add);
          addTearDown(subscription.cancel);
          await bridge.scanDevices();
          await bridge.connect(
            '${transport.name}:current-ring',
            profile: _profile,
          );
          final key = type == 'healthRecord' ? 'deviceId' : 'id';
          native.eventsController.add(
            WearableEvent(
              type: type,
              payload: {key: '${transport.name}:previous-ring'},
            ),
          );
          native.eventsController.add(
            WearableEvent(
              type: type,
              payload: {key: '${transport.name}:current-ring'},
            ),
          );
          await pumpEventQueue();
          expect(events, hasLength(1));
          expect(events.single.payload[key], '${transport.name}:current-ring');
        },
      );
    }
    test(
      '$name retains native session handling for identifier-free disconnect',
      () async {
        final native = _Native(name);
        final bridge = _router(native, transport);
        addTearDown(bridge.dispose);
        final events = <WearableEvent>[];
        final subscription = bridge.events.listen(events.add);
        addTearDown(subscription.cancel);
        await bridge.scanDevices();
        await bridge.connect(
          '${transport.name}:current-ring',
          profile: _profile,
        );
        native.eventsController.add(
          const WearableEvent(type: 'disconnected', payload: {}),
        );
        await pumpEventQueue();
        expect(events.single.type, 'disconnected');
      },
    );
  }
  for (final name in [
    'R7',
    'R7y',
    'R7 Pro',
    'R7 Ultra',
    'K80',
    'HR01',
    'HR05',
    'R8',
    'R8 Pro',
    'R12',
    'R18',
    'R20',
    'R21',
    'R22',
    'R7C',
    'YC Ring',
    'V Ring',
    'D Ring',
  ]) {
    final transport = WearableDeviceClassifier.transportFor(name)!;
    for (final staleId in ['previous-ring', 'yucheng:foreign-ring']) {
      test('$name ignores foreign disconnect $staleId during sync', () async {
        final native = _Native(name);
        final bridge = _router(native, transport);
        addTearDown(bridge.dispose);
        final events = <WearableEvent>[];
        final subscription = bridge.events.listen(events.add);
        addTearDown(subscription.cancel);
        await bridge.scanDevices();
        // 同一通道先连旧目标再连新目标；不能用旧回调结束新会话。
        await bridge.connect(
          '${transport.name}:previous-ring',
          profile: _profile,
        );
        await bridge.connect(
          '${transport.name}:current-ring',
          profile: _profile,
        );
        final sync = bridge.syncHealthData();
        native.eventsController.add(
          WearableEvent(type: 'disconnected', payload: {'deviceId': staleId}),
        );
        await pumpEventQueue();
        expect(events, isEmpty);
        native.sync.complete([]);
        expect(await sync, isEmpty);
        expect(native.disconnects, 0);
      });
    }

    test('$name still invalidates sync on its real disconnect', () async {
      final native = _Native(name);
      final bridge = _router(native, transport);
      addTearDown(bridge.dispose);
      final events = <WearableEvent>[];
      final subscription = bridge.events.listen(events.add);
      addTearDown(subscription.cancel);
      await bridge.scanDevices();
      await bridge.connect('${transport.name}:current-ring', profile: _profile);
      final sync = bridge.syncHealthData();
      final failure = expectLater(sync, throwsA(isA<PlatformException>()));
      native.eventsController.add(
        const WearableEvent(
          type: 'disconnected',
          payload: {'deviceId': 'current-ring'},
        ),
      );
      await pumpEventQueue();
      native.sync.complete([]);
      await failure;
      expect(
        events.single.payload['deviceId'],
        '${transport.name}:current-ring',
      );
    });
  }
}

RoutedWearableBridge _router(_Native native, WearableTransport transport) =>
    RoutedWearableBridge(
      veepoo: transport == WearableTransport.veepoo ? native : null,
      yucheng: transport == WearableTransport.yucheng ? native : null,
      moyoung: transport == WearableTransport.moyoung ? native : null,
      coolwear: transport == WearableTransport.coolwear ? native : null,
      qring: transport == WearableTransport.qring ? native : null,
      preferenceStore: _Preference(),
    );

class _Native extends Fake implements WearableBridge {
  _Native(this.name);
  final String name;
  final eventsController = StreamController<WearableEvent>.broadcast();
  final sync = Completer<List<HealthRecord>>();
  int disconnects = 0;
  int measurements = 0;
  @override
  Stream<WearableEvent> get events => eventsController.stream;
  @override
  Future<List<DeviceInfo>> scanDevices() async => [
    DeviceInfo(id: 'previous-ring', name: name),
    DeviceInfo(id: 'current-ring', name: name),
  ];
  @override
  Future<void> stopScan() async {}
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<void> disconnect() async {
    disconnects++;
  }

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) => sync.future;
  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    measurements++;
  }
}

class _DetailsNative extends _Native implements WearableDeviceDetailsBridge {
  _DetailsNative(super.name);
  Completer<DeviceInfo?>? deferred;
  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async => deferred?.future;
}

class _Preference implements WearableTransportPreferenceStore {
  @override
  Future<WearableTransport?> read() async => null;
  @override
  Future<void> write(WearableTransport value) async {}
  @override
  Future<void> clear() async {}
}
