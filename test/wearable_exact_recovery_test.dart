import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';
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
const _id = '11111111-2222-4333-8444-555555555555';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _bindingRaceTests();

  test(
    'v2 saves environment and owner and rejects a foreign environment',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final namespace = 'a' * 64;
      final store = SecureWearableTransportPreferenceStore(
        storageNamespace: namespace,
      );
      await store.writeBinding(
        const SavedWearableBinding(
          WearableTransport.qring,
          _id,
          deviceName: 'R21',
          ownerKey: 'owner-a',
        ),
      );
      expect((await store.readBinding())?.ownerKey, 'owner-a');
      final storage = FlutterSecureStorage();
      final key = 'saydian.global.env.$namespace.wearable.binding.v1';
      final saved =
          jsonDecode((await storage.read(key: key))!) as Map<String, dynamic>;
      expect(saved['schemaVersion'], 2);
      expect(saved['environment'], namespace);
      saved['environment'] = 'b' * 64;
      await storage.write(key: key, value: jsonEncode(saved));
      expect(await store.readBinding(), isNull);
    },
  );

  test('same owner arms exact QRing without scan or OS bond', () async {
    final store = _Store(
      const SavedWearableBinding(
        WearableTransport.qring,
        _id,
        deviceName: 'R21',
        ownerKey: 'owner-a',
      ),
    );
    final qring = _QRing();
    final bridge = _bridge(store, qring);
    addTearDown(bridge.dispose);
    await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
    qring.targets.clear();
    expect(await bridge.restoreConnection(profile: _profile), isNull);
    expect(qring.targets, [_id]);
    expect(qring.scanCount, 0);
    expect(qring.connects, isEmpty);
    expect((await bridge.readRememberedDevice())?.name, 'R21');
    expect(await bridge.canAutomaticallyRecoverRememberedDevice(), isTrue);
  });

  test(
    'different account cannot see or automatically recover saved ring',
    () async {
      final store = _Store(
        const SavedWearableBinding(
          WearableTransport.qring,
          _id,
          deviceName: 'R21',
          ownerKey: 'owner-a',
        ),
      );
      final qring = _QRing();
      final bridge = _bridge(store, qring);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
      qring.targets.clear();
      expect(await bridge.readRememberedDevice(), isNull);
      expect(await bridge.canAutomaticallyRecoverRememberedDevice(), isFalse);
      expect(await bridge.prepareRememberedDevice(), isNull);
      expect(await bridge.restoreConnection(profile: _profile), isNull);
      expect(qring.targets, isEmpty);
    },
  );

  test('legacy v1 only upgrades after exact manual handshake', () async {
    final store = _Store(
      const SavedWearableBinding(
        WearableTransport.qring,
        _id,
        deviceName: 'R21',
      ),
    );
    final qring = _QRing();
    final bridge = _bridge(store, qring);
    addTearDown(bridge.dispose);
    await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
    qring.targets.clear();
    expect(await bridge.restoreConnection(profile: _profile), isNull);
    expect(qring.targets, isEmpty);
    expect(await bridge.canAutomaticallyRecoverRememberedDevice(), isFalse);
    final candidate = await bridge.prepareRememberedDevice();
    await bridge.connect(candidate!.id, profile: _profile);
    expect(store.binding?.ownerKey, 'owner-a');
    expect(qring.targets, [_id]);
    expect(await bridge.canAutomaticallyRecoverRememberedDevice(), isTrue);
  });

  test(
    'internal disconnect preserves binding; unbind alone clears it',
    () async {
      final store = _Store(
        const SavedWearableBinding(
          WearableTransport.qring,
          _id,
          deviceName: 'R21',
          ownerKey: 'owner-a',
        ),
      );
      final qring = _QRing();
      final bridge = _bridge(store, qring);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      await bridge.restoreConnection(profile: _profile);
      await bridge.disconnect();
      expect(store.binding?.nativeIdentifier, _id);
      await bridge.forgetRememberedDevice();
      expect(store.binding, isNull);
    },
  );

  test(
    'failed candidate never replaces the last successful owner binding',
    () async {
      final store = _Store(
        const SavedWearableBinding(
          WearableTransport.qring,
          _id,
          deviceName: 'R21',
          ownerKey: 'owner-a',
        ),
      );
      final qring = _QRing()..failConnection = true;
      final bridge = _bridge(store, qring);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      final candidate = await bridge.prepareRememberedDevice();
      await expectLater(
        bridge.connect(candidate!.id, profile: _profile),
        throwsStateError,
      );
      expect(store.binding?.nativeIdentifier, _id);
      expect(store.binding?.ownerKey, 'owner-a');
    },
  );

  test(
    'QRing sleep history and events scope nested identity without changing record id',
    () async {
      final store = _Store(
        const SavedWearableBinding(
          WearableTransport.qring,
          _id,
          deviceName: 'R21',
          ownerKey: 'owner-a',
        ),
      );
      final qring = _QRing();
      final bridge = _bridge(store, qring);
      addTearDown(bridge.dispose);
      addTearDown(qring.source.close);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      await bridge.restoreConnection(profile: _profile);
      final timeline = SleepTimeline(
        deviceId: _id,
        sdkDate: '2026-09-30',
        timezone: '+08:00',
        readAt: DateTime.utc(2026, 10, 1),
        sessions: const [],
      );
      final record = HealthRecord(
        id: 'stable-sleep-history-id',
        metric: HealthMetric.sleep,
        values: const {'value': 1},
        unit: 'h',
        measuredAt: DateTime.utc(2026, 9, 30),
        timezone: '+08:00',
        deviceId: _id,
        firmwareVersion: '',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        rawVersion: 2,
        sleepTimeline: timeline,
      );
      qring.history = [record];
      final scoped = (await bridge.syncHealthData()).single;
      expect(scoped.id, record.id);
      expect(scoped.deviceId, 'qring:$_id');
      expect(scoped.sleepTimeline?.deviceId, 'qring:$_id');
      final next = bridge.events.first;
      qring.source.add(
        WearableEvent(
          type: 'sleepReadStatus',
          payload: {
            'deviceId': _id,
            'sdkDate': timeline.sdkDate,
            'status': 'noData',
            'sleepTimeline': timeline.toJson(),
          },
        ),
      );
      final event = await next;
      expect(event.payload['deviceId'], 'qring:$_id');
      expect((event.payload['sleepTimeline'] as Map)['deviceId'], 'qring:$_id');
    },
  );

  test(
    'a cancelled exact target cannot re-adopt a late native reconnect',
    () async {
      final store = _Store(
        const SavedWearableBinding(
          WearableTransport.qring,
          _id,
          deviceName: 'R21',
          ownerKey: 'owner-a',
        ),
      );
      final qring = _QRing();
      final bridge = _bridge(store, qring);
      addTearDown(bridge.dispose);
      addTearDown(qring.source.close);
      final received = <WearableEvent>[];
      final subscription = bridge.events.listen(received.add);
      addTearDown(subscription.cancel);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      await bridge.restoreConnection(profile: _profile);
      await bridge.setRecoveryContext(ownerKey: null, profile: _profile);
      qring.source.add(
        const WearableEvent(
          type: 'reconnected',
          payload: {'id': _id, 'name': 'R21'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(received.where((event) => event.type == 'reconnected'), isEmpty);
    },
  );
}

void _bindingRaceTests() {
  test(
    'account transition during optional details cannot persist or arm old handshake',
    () async {
      final original = const SavedWearableBinding(
        WearableTransport.qring,
        _id,
        deviceName: 'R22',
        ownerKey: 'owner-a',
      );
      final store = _Store(original);
      final qring = _QRing();
      final bridge = _bridge(store, qring);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      final candidate = await bridge.prepareRememberedDevice();
      qring.delayedDetails = Completer<DeviceInfo?>();
      qring.targets.clear();
      final connecting = bridge.connect(candidate!.id, profile: _profile);
      await qring.detailsStarted.future;
      await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
      qring.delayedDetails!.complete(const DeviceInfo(id: _id, name: 'R21'));
      await connecting;
      expect(store.writeCount, 0);
      expect(store.binding, same(original));
      expect(qring.targets.whereType<String>(), isEmpty);
      expect(await bridge.readRememberedDevice(), isNull);
    },
  );

  test(
    'a session changed inside secure write rolls back before next owner binding',
    () async {
      final original = const SavedWearableBinding(
        WearableTransport.qring,
        _id,
        deviceName: 'R22',
        ownerKey: 'owner-a',
      );
      final store = _Store(original)..delayedWrite = Completer<void>();
      final qring = _QRing();
      final bridge = _bridge(store, qring);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      final candidate = await bridge.prepareRememberedDevice();
      qring.targets.clear();
      final connecting = bridge.connect(candidate!.id, profile: _profile);
      await store.writeStarted.future;
      await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
      store.delayedWrite!.complete();
      await connecting;
      expect(store.binding, same(original));
      expect(store.writeCount, 2);
      expect(qring.targets.whereType<String>(), isEmpty);
      expect(await bridge.readRememberedDevice(), isNull);
    },
  );
}

RoutedWearableBridge _bridge(_Store store, _QRing qring) =>
    RoutedWearableBridge(
      veepoo: _Empty(),
      yucheng: _Empty(),
      qring: qring,
      preferenceStore: store,
      restoreOnlyBoundDevice: true,
      requireOwnerScopedBinding: true,
    );

class _Store implements WearableBindingPreferenceStore {
  _Store(this.binding);
  SavedWearableBinding? binding;
  final writeStarted = Completer<void>();
  Completer<void>? delayedWrite;
  int writeCount = 0;
  @override
  Future<SavedWearableBinding?> readBinding() async => binding;
  @override
  Future<void> writeBinding(SavedWearableBinding value) async {
    writeCount++;
    if (!writeStarted.isCompleted) writeStarted.complete();
    await delayedWrite?.future;
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

class _Empty extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
  @override
  Future<List<DeviceInfo>> scanDevices() async => const [];
  @override
  Future<void> stopScan() async {}
}

class _QRing extends _Empty
    implements
        WearableExactTargetRecoveryBridge,
        WearableRememberedDeviceSelectionBridge,
        WearableDeviceDetailsBridge {
  final targets = <String?>[];
  final source = StreamController<WearableEvent>.broadcast();
  List<HealthRecord> history = const [];
  final connects = <String>[];
  int scanCount = 0;
  bool connected = false;
  bool failConnection = false;
  Completer<DeviceInfo?>? delayedDetails;
  final detailsStarted = Completer<void>();
  @override
  Stream<WearableEvent> get events => source.stream;
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => history;
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
  Future<List<DeviceInfo>> scanDevices() async {
    scanCount++;
    return const [];
  }

  @override
  Future<DeviceInfo?> prepareRememberedDeviceForSelection(
    String nativeIdentifier, {
    String? knownName,
  }) async => DeviceInfo(id: nativeIdentifier, name: knownName!);
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connects.add(deviceId);
    if (failConnection) throw StateError('synthetic failed handshake');
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async {
    if (delayedDetails != null) {
      if (!detailsStarted.isCompleted) detailsStarted.complete();
      return delayedDetails!.future;
    }
    return connected ? const DeviceInfo(id: _id, name: 'R21') : null;
  }
}
