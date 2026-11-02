import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';
import 'package:saydian_app/services/wearable_bootstrap.dart';
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
  _directRecoveryTests();
  _cachedSelectionTests();

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
    'previous exact target is offered manually and a failed handshake keeps the current binding',
    () async {
      const previousId = '22222222-3333-4444-8555-666666666666';
      final store =
          _Store(
              const SavedWearableBinding(
                WearableTransport.qring,
                _id,
                deviceName: 'R21',
                ownerKey: 'owner-a',
              ),
            )
            ..recent.add(
              const SavedWearableBinding(
                WearableTransport.qring,
                previousId,
                deviceName: 'SD_RING_R8',
                ownerKey: 'owner-a',
              ),
            );
      final qring = _QRing()..failConnection = true;
      final bridge = _bridge(store, qring);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      final choices = await bridge.listBondedDevicesForSelection();
      final r8 = choices.singleWhere((device) => device.name == 'SD_RING_R8');
      expect(await bridge.canAutomaticallyRecoverRememberedDevice(), isTrue);
      await expectLater(
        bridge.connect(r8.id, profile: _profile),
        throwsStateError,
      );
      expect(store.binding?.nativeIdentifier, _id);
      expect(qring.connects, [previousId]);
      await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
      expect(await bridge.listBondedDevicesForSelection(), isEmpty);
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

void _directRecoveryTests() {
  const saved = SavedWearableBinding(
    WearableTransport.qring,
    _id,
    deviceName: 'R21',
    ownerKey: 'owner-a',
  );
  test(
    'manual direct recovery arms only the verified exact QRing and does not claim ready',
    () async {
      final store = _Store(saved);
      final qring = _QRing();
      final bridge = _bridge(store, qring);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      qring.targets.clear();
      final result = await bridge.restoreRememberedDeviceDirectly(
        expectedDeviceId: 'qring:$_id',
        profile: _profile,
      );
      expect(result.started, isTrue);
      expect(result.device, isNull);
      expect(qring.targets, [_id]);
      expect(qring.scanCount, 0);
      expect(qring.connects, isEmpty);
      expect(store.binding, same(saved));
      expect(store.writeCount, 0);
      // An app-resume restore while the native handshake is pending must reuse
      // the already armed request, not cancel its probe with another configure.
      expect(await bridge.restoreConnection(profile: _profile), isNull);
      expect(qring.targets, [_id]);
      expect(qring.scanCount, 0);
      await bridge.disconnect();
      expect(
        (await bridge.restoreRememberedDeviceDirectly(
          expectedDeviceId: 'qring:$_id',
          profile: _profile,
        )).started,
        isTrue,
      );
      expect(qring.targets.where((target) => target == _id).length, 2);
    },
  );

  for (final entry in <String, SavedWearableBinding?>{
    'legacy': const SavedWearableBinding(
      WearableTransport.qring,
      _id,
      deviceName: 'R21',
    ),
    'foreign owner': const SavedWearableBinding(
      WearableTransport.qring,
      _id,
      deviceName: 'R21',
      ownerKey: 'owner-b',
    ),
    'another target': const SavedWearableBinding(
      WearableTransport.qring,
      '22222222-2222-4333-8444-555555555555',
      deviceName: 'R21',
      ownerKey: 'owner-a',
    ),
    'other SDK': const SavedWearableBinding(
      WearableTransport.coolwear,
      _id,
      deviceName: 'R7 Pro',
      ownerKey: 'owner-a',
    ),
    'unaccepted name': const SavedWearableBinding(
      WearableTransport.qring,
      _id,
      deviceName: 'HR05',
      ownerKey: 'owner-a',
    ),
    'missing name': const SavedWearableBinding(
      WearableTransport.qring,
      _id,
      ownerKey: 'owner-a',
    ),
    'missing binding': null,
  }.entries) {
    test(
      'manual direct recovery rejects ${entry.key} without radio activity',
      () async {
        final store = _Store(entry.value);
        final qring = _QRing();
        final bridge = _bridge(store, qring);
        addTearDown(bridge.dispose);
        await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
        qring.targets.clear();
        final result = await bridge.restoreRememberedDeviceDirectly(
          expectedDeviceId: 'qring:$_id',
          profile: _profile,
        );
        expect(result.started, isFalse);
        expect(result.device, isNull);
        expect(qring.targets, isEmpty);
        expect(qring.scanCount, 0);
        expect(qring.connects, isEmpty);
        expect(store.binding, same(entry.value));
      },
    );
  }

  test(
    'owner changes during direct lookup cannot arm the previous target',
    () async {
      final store = _Store(saved);
      final qring = _QRing();
      final bridge = _bridge(store, qring);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      qring.targets.clear();
      store.delayedRead = Completer<SavedWearableBinding?>();
      final starting = bridge.restoreRememberedDeviceDirectly(
        expectedDeviceId: 'qring:$_id',
        profile: _profile,
      );
      await Future<void>.delayed(Duration.zero);
      await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
      store.delayedRead!.complete(saved);
      expect((await starting).started, isFalse);
      expect(qring.targets.whereType<String>(), isEmpty);
      expect(qring.connects, isEmpty);
    },
  );

  test(
    'direct recovery returns only details verified by the native connection',
    () async {
      final qring = _QRing()..connected = true;
      final bridge = _bridge(_Store(saved), qring);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      final result = await bridge.restoreRememberedDeviceDirectly(
        expectedDeviceId: 'qring:$_id',
        profile: _profile,
      );
      expect(result.started, isTrue);
      expect(result.device?.id, 'qring:$_id');
      expect(qring.connects, isEmpty);
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

class _Store
    implements
        WearableBindingPreferenceStore,
        WearableRecentBindingPreferenceStore {
  _Store(this.binding);
  SavedWearableBinding? binding;
  final recent = <SavedWearableBinding>[];
  final writeStarted = Completer<void>();
  Completer<void>? delayedWrite;
  Completer<SavedWearableBinding?>? delayedRead;
  int writeCount = 0;
  @override
  Future<SavedWearableBinding?> readBinding() async =>
      delayedRead == null ? binding : await delayedRead!.future;
  @override
  Future<List<SavedWearableBinding>> readRecentBindings(
    String ownerKey,
  ) async => recent.where((binding) => binding.ownerKey == ownerKey).toList();
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
  Completer<void>? nextTargetConfiguration;
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
    final delay = nextTargetConfiguration;
    nextTargetConfiguration = null;
    if (delay != null) await delay.future;
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
    bool cacheOnly = false,
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

void _cachedSelectionTests() {
  const binding = SavedWearableBinding(
    WearableTransport.qring,
    _id,
    deviceName: 'R21',
    ownerKey: 'owner-a',
  );
  const cached = DeviceInfo(id: _id, name: 'R21');
  const other = DeviceInfo(id: 'other', name: 'R22');

  test(
    'returning to the original account retires a delayed owner change',
    () async {
      final native = _SelectionQRing()..cached = cached;
      final bridge = _bridge(_Store(binding), native);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      final delay = Completer<void>();
      native.nextTargetConfiguration = delay;
      final abandoned = bridge.setRecoveryContext(
        ownerKey: 'owner-b',
        profile: _profile,
      );
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      delay.complete();
      await abandoned;
      expect((await bridge.readRememberedDevice())?.id, 'qring:$_id');
      expect(native.connects, isEmpty);
    },
  );

  test(
    'a stopped scan cannot clear the next list of recoverable rings',
    () async {
      final native = _SelectionQRing()..cached = cached;
      final bridge = _bridge(_Store(binding), native);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      final slowStop = Completer<void>();
      native.nextTargetConfiguration = slowStop;
      final previous = bridge.scanDevices();
      await bridge.stopScan();
      final selected = (await bridge.listBondedDevicesForSelection()).single;
      slowStop.complete();
      expect(await previous, isEmpty);
      await bridge.connect(selected.id, profile: _profile);
      expect(native.connects, [_id]);
    },
  );

  test(
    'exact cached choice avoids unrelated OS lookup and never auto-connects',
    () async {
      final native = _SelectionQRing()..cached = cached;
      final store = _Store(binding);
      final bridge = _bridge(store, native);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      final choices = await bridge.listBondedDevicesForSelection();
      expect(choices.map((device) => device.id), ['qring:$_id']);
      expect(native.calls, ['cache:$_id:true']);
      expect(native.connects, isEmpty);
      expect(native.scanCount, 0);
      expect(store.writeCount, 0);
    },
  );

  group('iOS manual selection with an existing account candidate', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);
    late _Store store;
    late _SelectionQRing native;
    late RoutedWearableBridge bridge;
    setUp(() async {
      store = _Store(binding);
      native = _SelectionQRing()
        ..cached = cached
        ..osReply = Completer<List<DeviceInfo>>();
      bridge =
          createProductionWearableBridge(
                coolwear: _Empty(),
                qring: native,
                preferenceStore: store,
              )
              as RoutedWearableBridge;
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
    });
    tearDown(() => bridge.dispose());

    test('adds system-connected R8 after cached R21 without binding', () async {
      const r8 = DeviceInfo(id: 'r8-id', name: 'SD_RING_R8');
      final choices = bridge.listBondedDevicesForSelection();
      await native.osStarted.future;
      native.osReply!.complete([r8, cached, r8]);
      expect((await choices).map((d) => d.id), ['qring:$_id', 'qring:r8-id']);
      expect(native.calls, ['cache:$_id:true', 'os']);
      expect(native.connects, isEmpty);
      expect(native.scanCount, 0);
      expect(store.writeCount, 0);
    });
    test('preserves cached R21 when the extra lookup fails', () async {
      final choices = bridge.listBondedDevicesForSelection();
      await native.osStarted.future;
      native.osReply!.completeError(StateError('system read unavailable'));
      expect((await choices).single.id, 'qring:$_id');
      expect(native.connects, isEmpty);
    });
    test(
      'discards both sources when the owner changes during lookup',
      () async {
        final choices = bridge.listBondedDevicesForSelection();
        await native.osStarted.future;
        await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
        native.osReply!.complete([other]);
        expect(await choices, isEmpty);
        expect(native.connects, isEmpty);
        expect(store.writeCount, 0);
      },
    );
  });

  for (final fails in [false, true]) {
    test(
      'cache ${fails ? 'failure' : 'miss'} falls back to OS selection',
      () async {
        final native = _SelectionQRing()..cacheFails = fails;
        final bridge = _bridge(_Store(binding), native);
        addTearDown(bridge.dispose);
        await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
        final choices = await bridge.listBondedDevicesForSelection();
        expect(choices.map((device) => device.id), ['qring:other']);
        expect(native.calls, ['cache:$_id:true', 'os']);
        expect(native.connects, isEmpty);
      },
    );
  }

  for (final pending in [false, true]) {
    test(
      'a prepared manual target belongs to its account, pending=$pending',
      () async {
        final native = _SelectionQRing()..cached = cached;
        final bridge = _bridge(_Store(binding), native);
        addTearDown(bridge.dispose);
        await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
        if (pending) native.cachedReply = Completer<DeviceInfo?>();
        final first = bridge.prepareRememberedDevice();
        await native.cacheStarted.future;
        if (!pending) expect((await first)?.id, 'qring:$_id');
        await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
        if (pending) {
          native.cachedReply!.complete(cached);
          expect(await first, isNull);
        }
        await expectLater(
          bridge.connect('qring:$_id', profile: _profile),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'UNKNOWN_SCANNED_DEVICE',
            ),
          ),
        );
        expect(native.connects, isEmpty);
      },
    );
  }

  test('late cached result cannot cross an account switch', () async {
    final reply = Completer<DeviceInfo?>();
    final native = _SelectionQRing()..cachedReply = reply;
    final bridge = _bridge(_Store(binding), native);
    addTearDown(bridge.dispose);
    await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
    final pending = bridge.listBondedDevicesForSelection();
    await native.cacheStarted.future;
    await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
    reply.complete(cached);
    expect(await pending, isEmpty);
    await expectLater(
      bridge.connect('qring:$_id', profile: _profile),
      throwsA(isA<Exception>()),
    );
    expect(native.connects, isEmpty);
    expect(native.calls, ['cache:$_id:true']);
  });

  test(
    'stopped lookup rejects cached reply and a subsequent lookup succeeds',
    () async {
      final reply = Completer<DeviceInfo?>();
      final native = _SelectionQRing()..cachedReply = reply;
      final bridge = _bridge(_Store(binding), native);
      addTearDown(bridge.dispose);
      await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
      final pending = bridge.listBondedDevicesForSelection();
      await native.cacheStarted.future;
      await bridge.stopScan();
      reply.complete(cached);
      expect(await pending, isEmpty);
      native.cachedReply = null;
      native.cached = cached;
      expect(
        (await bridge.listBondedDevicesForSelection()).single.id,
        'qring:$_id',
      );
      expect(native.connects, isEmpty);
    },
  );

  test('late OS candidate cannot enter the next account selection', () async {
    final reply = Completer<List<DeviceInfo>>();
    final native = _SelectionQRing()..osReply = reply;
    final bridge = _bridge(_Store(null), native);
    addTearDown(bridge.dispose);
    await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
    final pending = bridge.listBondedDevicesForSelection();
    await native.osStarted.future;
    await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
    reply.complete([other]);
    expect(await pending, isEmpty);
    await expectLater(
      bridge.connect('qring:other', profile: _profile),
      throwsA(isA<Exception>()),
    );
    expect(native.connects, isEmpty);
  });
}

class _SelectionQRing extends _QRing
    implements WearableBondedDeviceSelectionBridge {
  final calls = <String>[];
  final cacheStarted = Completer<void>();
  final osStarted = Completer<void>();
  DeviceInfo? cached;
  bool cacheFails = false;
  Completer<DeviceInfo?>? cachedReply;
  Completer<List<DeviceInfo>>? osReply;

  @override
  Future<DeviceInfo?> prepareRememberedDeviceForSelection(
    String nativeIdentifier, {
    String? knownName,
    bool cacheOnly = false,
  }) async {
    calls.add('cache:$nativeIdentifier:$cacheOnly');
    if (!cacheStarted.isCompleted) cacheStarted.complete();
    if (cacheFails) throw StateError('synthetic cache unavailable');
    return cachedReply == null ? cached : await cachedReply!.future;
  }

  @override
  Future<List<DeviceInfo>> listBondedDevicesForSelection() async {
    calls.add('os');
    if (!osStarted.isCompleted) osStarted.complete();
    return osReply == null
        ? [const DeviceInfo(id: 'other', name: 'R22')]
        : await osReply!.future;
  }
}
