import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/services/wearable_routing.dart';

void main() {
  test(
    'production router forwards Vep native market and download only',
    () async {
      final vep = _NativeMarketBridge();
      final yuc = _NativeMarketBridge(name: 'YC Ring', id: 'fixture-yuc');
      final bridge = RoutedWearableBridge(
        veepoo: vep,
        yucheng: yuc,
        preferenceStore: _MemoryTransportPreference(),
      );
      await bridge.scanDevices();
      await bridge.connect('veepoo:fixture-watch', profile: _profile);
      expect(await bridge.getNativeWatchFaceCatalog(), isEmpty);
      expect(
        (await bridge.downloadNativeWatchFace('fixture-dial')).catalogId,
        'fixture-dial',
      );
      expect(vep.catalogCalls, 1);
      await bridge.connect('yucheng:fixture-yuc', profile: _profile);
      await expectLater(
        bridge.getNativeWatchFaceCatalog(),
        throwsA(isA<PlatformException>()),
      );
      expect(yuc.catalogCalls, 0);
    },
  );

  test(
    'late native market result is rejected after same-SDK reconnect',
    () async {
      final vep = _NativeMarketBridge()
        ..pending = Completer<List<NativeWatchFaceCatalogItem>>();
      final bridge = RoutedWearableBridge(
        veepoo: vep,
        yucheng: _FakeWearableBridge(scanned: const []),
        preferenceStore: _MemoryTransportPreference(),
      );
      await bridge.scanDevices();
      await bridge.connect('veepoo:fixture-watch', profile: _profile);
      final result = bridge.getNativeWatchFaceCatalog();
      final rejected = expectLater(
        result,
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'DEVICE_CHANGED',
          ),
        ),
      );
      await bridge.connect('veepoo:fixture-watch', profile: _profile);
      vep.pending!.complete([]);
      await rejected;
    },
  );

  test('routes ring name prefixes without guessing unknown devices', () {
    expect(
      WearableDeviceClassifier.transportFor(' YC Ring'),
      WearableTransport.yucheng,
    );
    expect(
      WearableDeviceClassifier.transportFor('yc-01'),
      WearableTransport.yucheng,
    );
    expect(
      WearableDeviceClassifier.transportFor('V Ring'),
      WearableTransport.veepoo,
    );
    expect(
      WearableDeviceClassifier.transportFor('tk-ring'),
      WearableTransport.veepoo,
    );
    expect(
      WearableDeviceClassifier.transportFor('D Ring'),
      WearableTransport.moyoung,
    );
    expect(
      WearableDeviceClassifier.transportFor('HR01'),
      WearableTransport.coolwear,
    );
    expect(
      WearableDeviceClassifier.transportFor('hr01-1'),
      WearableTransport.coolwear,
    );
    expect(
      WearableDeviceClassifier.transportFor(' hr05 '),
      WearableTransport.coolwear,
    );
    expect(
      WearableDeviceClassifier.transportFor('Q_Ring 1024'),
      WearableTransport.qring,
    );
    expect(
      WearableDeviceClassifier.transportFor(' o_ring'),
      WearableTransport.qring,
    );
    expect(
      WearableDeviceClassifier.transportFor(' r22_c493'),
      WearableTransport.qring,
    );
    expect(
      WearableDeviceClassifier.transportFor('R22_C493 '),
      WearableTransport.qring,
    );
    for (final name in [
      'R2',
      'R21',
      ' r210 ',
      'R22_',
      'R22_C493_extra',
      'R22_Z493',
    ]) {
      expect(
        WearableDeviceClassifier.transportFor(name),
        WearableTransport.qring,
      );
    }
    expect(WearableDeviceClassifier.transportFor('R1'), isNull);
    expect(WearableDeviceClassifier.transportFor('R3'), isNull);
    expect(WearableDeviceClassifier.transportFor('Q Ring'), isNull);
    expect(WearableDeviceClassifier.transportFor('Oura Ring'), isNull);
    expect(WearableDeviceClassifier.transportFor('HR010'), isNull);
    expect(WearableDeviceClassifier.transportFor('HR050'), isNull);
    expect(WearableDeviceClassifier.transportFor('HR05-unknown'), isNull);
    expect(WearableDeviceClassifier.transportFor('W8'), isNull);
    expect(WearableDeviceClassifier.transportFor('Ring'), isNull);
    expect(WearableDeviceClassifier.transportFor(''), isNull);
    expect(
      WearableDeviceClassifier.transportForScopedId(' yucheng:A1-B2 '),
      WearableTransport.yucheng,
    );
    expect(WearableDeviceClassifier.transportForScopedId('VEP:A1-B2'), isNull);
    expect(
      WearableDeviceClassifier.transportForScopedId('coolwear:A1-B2'),
      WearableTransport.coolwear,
    );
    expect(
      WearableDeviceClassifier.transportForScopedId('qring:A1-B2'),
      WearableTransport.qring,
    );
    expect(
      WearableDeviceClassifier.transportForScopedId('ring-without-scope'),
      isNull,
    );
  });

  test('scopes IDs without losing the vendor identifier', () {
    final routed = RoutedDevice.fromScan(
      transport: WearableTransport.yucheng,
      nativeIdentifier: 'A1-B2',
      name: 'YC Ring',
    );

    expect(routed.display.id, 'yucheng:A1-B2');
    expect(routed.nativeIdentifier, 'A1-B2');
    expect(routed.transport, WearableTransport.yucheng);
  });

  test('accepts a ring only from the SDK selected by its prefix', () async {
    final veepoo = _FakeWearableBridge(
      scanned: const [
        DeviceInfo(id: 'AA:01', name: 'YC Ring'),
        DeviceInfo(id: 'AA:02', name: 'V Ring'),
      ],
    );
    final yucheng = _FakeWearableBridge(
      scanned: const [
        DeviceInfo(id: 'IOS-UUID-01', name: 'YC Ring'),
        DeviceInfo(id: 'IOS-UUID-02', name: 'V Ring'),
      ],
    );
    final bridge = RoutedWearableBridge(veepoo: veepoo, yucheng: yucheng);

    final devices = await bridge.scanDevices();

    expect(devices.map((item) => item.id), contains('yucheng:IOS-UUID-01'));
    expect(devices.map((item) => item.id), isNot(contains('veepoo:AA:01')));
    expect(devices.map((item) => item.id), contains('veepoo:AA:02'));
    expect(
      devices.map((item) => item.id),
      isNot(contains('yucheng:IOS-UUID-02')),
    );
  });

  test('locks every later operation to the transport that connected', () async {
    final veepoo = _FakeWearableBridge(scanned: const []);
    final yucheng = _FakeWearableBridge(
      scanned: const [DeviceInfo(id: 'YC-1', name: 'YC Ring')],
    );
    final bridge = RoutedWearableBridge(veepoo: veepoo, yucheng: yucheng);

    await bridge.scanDevices();
    await bridge.connect('yucheng:YC-1', profile: _profile);
    await bridge.startMeasurement(HealthMetric.heartRate);

    expect(yucheng.connectCalls, ['YC-1']);
    expect(yucheng.measurementCalls, [HealthMetric.heartRate]);
    expect(veepoo.connectCalls, isEmpty);
    expect(veepoo.measurementCalls, isEmpty);
  });

  test('hides a Yucheng-prefix ring returned only by Veepoo', () async {
    final bridge = RoutedWearableBridge(
      veepoo: _FakeWearableBridge(
        scanned: const [DeviceInfo(id: 'YC-1', name: 'YC Ring')],
      ),
      yucheng: _FakeWearableBridge(scanned: const []),
    );

    expect(await bridge.scanDevices(), isEmpty);
  });

  test('keeps V and TK prefix rings on the Veepoo transport', () async {
    final bridge = RoutedWearableBridge(
      veepoo: _FakeWearableBridge(
        scanned: const [
          DeviceInfo(id: 'V-1', name: 'V Ring 1001'),
          DeviceInfo(id: 'TK-1', name: 'TK Ring'),
        ],
      ),
      yucheng: _FakeWearableBridge(scanned: const []),
    );

    final devices = await bridge.scanDevices();

    expect(devices, hasLength(2));
    expect(devices.map((device) => device.id), contains('veepoo:V-1'));
    expect(devices.map((device) => device.id), contains('veepoo:TK-1'));
  });

  test('routes HR01 and HR05 only through the CoolWear SDK', () async {
    final coolwear = _FakeWearableBridge(
      scanned: const [
        DeviceInfo(id: 'CW-1', name: 'HR01'),
        DeviceInfo(id: 'CW-5', name: 'HR05', model: 'HR05'),
      ],
    );
    final bridge = RoutedWearableBridge(
      veepoo: _FakeWearableBridge(
        scanned: const [
          DeviceInfo(id: 'VP-1', name: 'HR01'),
          DeviceInfo(id: 'VP-5', name: 'HR05'),
        ],
      ),
      yucheng: _FakeWearableBridge(scanned: const []),
      coolwear: coolwear,
      preferenceStore: _MemoryTransportPreference(),
    );

    final devices = await bridge.scanDevices();
    expect(devices.map((device) => device.id), [
      'coolwear:CW-1',
      'coolwear:CW-5',
    ]);
    expect(
      devices.every((device) => device.sdkSource == WearableSdkSource.coolwear),
      isTrue,
    );

    await bridge.connect('coolwear:CW-5', profile: _profile);
    await bridge.startMeasurement(HealthMetric.heartRate);
    expect(coolwear.connectCalls, ['CW-5']);
    expect(coolwear.measurementCalls, [HealthMetric.heartRate]);
  });

  test('routes Q_, O_ and R2 rings only through the QRing SDK', () async {
    final qring = _FakeWearableBridge(
      scanned: const [
        DeviceInfo(id: 'QR-1', name: 'Q_Ring'),
        DeviceInfo(id: 'OR-1', name: 'O_Ring'),
        DeviceInfo(id: 'R22-1', name: 'R22_C493'),
        DeviceInfo(id: 'R21-1', name: ' r21 '),
        DeviceInfo(id: 'WRONG-SDK', name: 'HR05'),
      ],
    );
    final bridge = RoutedWearableBridge(
      veepoo: _FakeWearableBridge(
        scanned: const [
          DeviceInfo(id: 'VP-1', name: 'Q_Ring'),
          DeviceInfo(id: 'R21-1', name: 'R21'),
        ],
      ),
      yucheng: _FakeWearableBridge(scanned: const []),
      qring: qring,
      preferenceStore: _MemoryTransportPreference(),
    );

    final devices = await bridge.scanDevices();
    expect(devices.map((device) => device.id), [
      'qring:QR-1',
      'qring:OR-1',
      'qring:R22-1',
      'qring:R21-1',
    ]);

    await bridge.connect('qring:R21-1', profile: _profile);
    await bridge.startMeasurement(HealthMetric.hrv);
    expect(qring.connectCalls, ['R21-1']);
    expect(qring.measurementCalls, [HealthMetric.hrv]);
  });

  test('lists an OS-bonded R22 only after explicit selection lookup', () async {
    final preference = _MemoryBoundPreference(null);
    final qring = _BondedQRingBridge(
      const DeviceInfo(
        id: 'AA:BB:CC:DD:EE:FF',
        name: 'R22_C493',
        hardwareAddress: 'AA:BB:CC:DD:EE:FF',
      ),
    );
    final bridge = RoutedWearableBridge(
      veepoo: _FakeWearableBridge(scanned: const []),
      yucheng: _FakeWearableBridge(scanned: const []),
      qring: qring,
      preferenceStore: preference,
      restoreOnlyBoundDevice: true,
    );
    addTearDown(bridge.dispose);

    expect(await bridge.scanDevices(), isEmpty);
    expect(preference.binding, isNull);

    final bonded = await bridge.listBondedDevicesForSelection();
    expect(bonded.single.id, 'qring:AA:BB:CC:DD:EE:FF');
    expect(qring.selectionLookupCalls, 1);
    expect(preference.binding, isNull);

    await bridge.connect(bonded.single.id, profile: _profile);
    expect(qring.connectCalls, ['AA:BB:CC:DD:EE:FF']);
    expect(preference.binding?.transport, WearableTransport.qring);
    expect(preference.binding?.nativeIdentifier, 'AA:BB:CC:DD:EE:FF');
    expect(preference.binding?.deviceName, 'R22_C493');
  });

  test(
    'lists and connects the exact remembered QRing only after explicit lookup',
    () async {
      final preference = _MemoryBoundPreference(
        const SavedWearableBinding(
          WearableTransport.qring,
          'AA:BB:CC:DD:EE:FF',
        ),
      );
      final qring = _BondedQRingBridge(
        null,
        remembered: const DeviceInfo(
          id: 'AA:BB:CC:DD:EE:FF',
          name: '上次连接的 QRing 戒指',
        ),
      );
      final bridge = RoutedWearableBridge(
        veepoo: _FakeWearableBridge(scanned: const []),
        yucheng: _FakeWearableBridge(scanned: const []),
        qring: qring,
        preferenceStore: preference,
        restoreOnlyBoundDevice: true,
      );
      addTearDown(bridge.dispose);

      expect(await bridge.scanDevices(), isEmpty);
      expect(qring.rememberedLookupCalls, isEmpty);

      final remembered = await bridge.listBondedDevicesForSelection();
      expect(remembered.single.id, 'qring:AA:BB:CC:DD:EE:FF');
      expect(qring.rememberedLookupCalls, ['AA:BB:CC:DD:EE:FF']);

      await bridge.connect(remembered.single.id, profile: _profile);
      expect(qring.connectCalls, ['AA:BB:CC:DD:EE:FF']);
    },
  );

  test(
    'iOS UUID recovery requires explicit selection, not auto adoption',
    () async {
      const uuid = '11111111-2222-4333-8444-555555555555';
      final preference = _MemoryBoundPreference(
        const SavedWearableBinding(
          WearableTransport.qring,
          uuid,
          deviceName: 'R21_TEST',
        ),
      );
      final qring = _BondedQRingBridge(
        null,
        remembered: const DeviceInfo(id: uuid, name: 'R21_TEST'),
      );
      final bridge = RoutedWearableBridge(
        veepoo: _FakeWearableBridge(scanned: const []),
        yucheng: _FakeWearableBridge(scanned: const []),
        qring: qring,
        preferenceStore: preference,
        restoreOnlyBoundDevice: true,
      );
      addTearDown(bridge.dispose);
      expect(await bridge.restoreConnection(profile: _profile), isNull);
      expect(qring.rememberedLookupCalls, isEmpty);
      final devices = await bridge.listBondedDevicesForSelection();
      expect(devices.single.id, 'qring:$uuid');
      expect(qring.connectCalls, isEmpty);
      await bridge.connect(devices.single.id, profile: _profile);
      expect(qring.connectCalls, [uuid]);
      expect(preference.binding?.nativeIdentifier, uuid);
    },
  );

  test('rejects remembered selection when native returns another id', () async {
    final qring = _BondedQRingBridge(
      null,
      remembered: const DeviceInfo(
        id: '11:22:33:44:55:66',
        name: '上次连接的 QRing 戒指',
      ),
    );
    final bridge = RoutedWearableBridge(
      veepoo: _FakeWearableBridge(scanned: const []),
      yucheng: _FakeWearableBridge(scanned: const []),
      qring: qring,
      preferenceStore: _MemoryBoundPreference(
        const SavedWearableBinding(
          WearableTransport.qring,
          'AA:BB:CC:DD:EE:FF',
          deviceName: 'R22_C493',
        ),
      ),
    );
    addTearDown(bridge.dispose);

    expect(await bridge.listBondedDevicesForSelection(), isEmpty);
    expect(qring.connectCalls, isEmpty);
  });

  test(
    'filters a non-QRing name returned by bonded selection lookup',
    () async {
      final bridge = RoutedWearableBridge(
        veepoo: _FakeWearableBridge(scanned: const []),
        yucheng: _FakeWearableBridge(scanned: const []),
        qring: _BondedQRingBridge(
          const DeviceInfo(id: 'AA:BB', name: 'V Ring'),
        ),
      );
      addTearDown(bridge.dispose);

      expect(await bridge.listBondedDevicesForSelection(), isEmpty);
    },
  );

  test(
    'restores only the saved QRing bond when it stops advertising',
    () async {
      final preference = _MemoryBoundPreference(
        const SavedWearableBinding(WearableTransport.qring, 'R22-1'),
      );
      final qring = _BondedQRingBridge(
        const DeviceInfo(id: 'R22-1', name: 'R22_C493'),
      );
      final bridge = RoutedWearableBridge(
        veepoo: _FakeWearableBridge(scanned: const []),
        yucheng: _FakeWearableBridge(scanned: const []),
        qring: qring,
        preferenceStore: preference,
        restoreOnlyBoundDevice: true,
      );
      addTearDown(bridge.dispose);

      expect(
        (await bridge.restoreConnection(profile: _profile))?.id,
        'qring:R22-1',
      );
      expect(qring.lookupCalls, ['R22-1']);
      expect(qring.connectCalls, ['R22-1']);
    },
  );

  test('rejects a bonded lookup for a different identifier', () async {
    final qring = _BondedQRingBridge(
      const DeviceInfo(id: 'other-ring', name: 'R22_C493'),
    );
    final bridge = RoutedWearableBridge(
      veepoo: _FakeWearableBridge(scanned: const []),
      yucheng: _FakeWearableBridge(scanned: const []),
      qring: qring,
      preferenceStore: _MemoryBoundPreference(
        const SavedWearableBinding(WearableTransport.qring, 'R22-1'),
      ),
      restoreOnlyBoundDevice: true,
    );
    addTearDown(bridge.dispose);

    expect(await bridge.restoreConnection(profile: _profile), isNull);
    expect(qring.lookupCalls, ['R22-1']);
    expect(qring.connectCalls, isEmpty);
  });

  test('scopes pulled V ring details and live metadata events', () async {
    final veepoo = _FakeWearableBridge(
      scanned: const [DeviceInfo(id: 'V-1', name: 'V Ring')],
      connectedDetails: const DeviceInfo(
        id: 'V-1',
        name: 'V Ring',
        firmwareVersion: '00.20.01',
      ),
    );
    final bridge = RoutedWearableBridge(
      veepoo: veepoo,
      yucheng: _FakeWearableBridge(scanned: const []),
    );
    final received = <WearableEvent>[];
    final subscription = bridge.events.listen(received.add);

    await bridge.scanDevices();
    await bridge.connect('veepoo:V-1', profile: _profile);
    final details = await bridge.getConnectedDeviceDetails();
    veepoo.emit(
      const WearableEvent(
        type: 'deviceDetails',
        payload: {'id': 'V-1', 'name': 'V Ring', 'firmwareVersion': '00.20.01'},
      ),
    );
    veepoo.emit(
      const WearableEvent(
        type: 'syncProgress',
        payload: {'deviceId': 'V-1', 'progress': 0.5},
      ),
    );
    await pumpEventQueue();

    expect(details?.id, 'veepoo:V-1');
    expect(details?.firmwareVersion, '00.20.01');
    expect(received[0].payload['id'], 'veepoo:V-1');
    expect(received[1].payload['deviceId'], 'veepoo:V-1');
    await subscription.cancel();
    await bridge.dispose();
  });

  test('drops a live ring from the wrong SDK and forwards its owner', () async {
    final veepoo = _FakeWearableBridge(scanned: const []);
    final yucheng = _FakeWearableBridge(scanned: const []);
    final bridge = RoutedWearableBridge(veepoo: veepoo, yucheng: yucheng);
    final received = <WearableEvent>[];
    final subscription = bridge.events.listen(received.add);

    veepoo.emitScan(const DeviceInfo(id: '07:43:00:00:4D:E9', name: 'YC Ring'));
    yucheng.emitScan(
      const DeviceInfo(id: '07:43:00:00:4D:E9', name: 'YC Ring'),
    );
    await pumpEventQueue();

    expect(received, hasLength(1));
    expect(received.single.payload['id'], 'yucheng:07:43:00:00:4D:E9');
    await subscription.cancel();
    await bridge.dispose();
  });

  test(
    'can connect a live scan result before the scan future completes',
    () async {
      final veepoo = _FakeWearableBridge(scanned: const []);
      final bridge = RoutedWearableBridge(
        veepoo: veepoo,
        yucheng: _FakeWearableBridge(scanned: const []),
      );
      final subscription = bridge.events.listen((_) {});

      veepoo.emitScan(
        const DeviceInfo(id: '38:23:A4:5E:CA:69', name: 'V Ring'),
      );
      await pumpEventQueue();
      await bridge.connect('veepoo:38:23:A4:5E:CA:69', profile: _profile);

      expect(veepoo.connectCalls, ['38:23:A4:5E:CA:69']);
      await subscription.cancel();
      await bridge.dispose();
    },
  );

  test(
    'hides a D-prefix ring until a Moyoung ring SDK is integrated',
    () async {
      final bridge = RoutedWearableBridge(
        veepoo: _FakeWearableBridge(
          scanned: const [DeviceInfo(id: 'VP-D', name: 'D Ring')],
        ),
        yucheng: _FakeWearableBridge(
          scanned: const [DeviceInfo(id: 'YC-D', name: 'D Ring')],
        ),
      );

      final devices = await bridge.scanDevices();

      expect(devices, isEmpty);
    },
  );

  test(
    'routes a D-prefix ring only when a Moyoung bridge is supplied',
    () async {
      final bridge = RoutedWearableBridge(
        veepoo: _FakeWearableBridge(
          scanned: const [DeviceInfo(id: 'VP-D', name: 'D Ring')],
        ),
        yucheng: _FakeWearableBridge(
          scanned: const [DeviceInfo(id: 'YC-D', name: 'D Ring')],
        ),
        moyoung: _FakeWearableBridge(
          scanned: const [DeviceInfo(id: 'MOY-D', name: 'D Ring')],
        ),
      );

      final devices = await bridge.scanDevices();

      expect(devices, hasLength(1));
      expect(devices.single.id, 'moyoung:MOY-D');
      expect(devices.single.sdkSource, WearableSdkSource.moyoung);
    },
  );

  test(
    'restores a V-prefix ring and locks later operations to Veepoo',
    () async {
      final veepoo = _FakeWearableBridge(
        scanned: const [],
        connectedDetails: const DeviceInfo(
          id: '38:23:A4:5E:CA:69',
          name: 'V Ring',
        ),
      );
      final yucheng = _FakeWearableBridge(scanned: const []);
      final bridge = RoutedWearableBridge(veepoo: veepoo, yucheng: yucheng);

      final restored = await bridge.restoreConnection(profile: _profile);
      await bridge.startMeasurement(HealthMetric.heartRate);

      expect(restored?.id, 'veepoo:38:23:A4:5E:CA:69');
      expect(veepoo.restoreCalls, 1);
      expect(veepoo.measurementCalls, [HealthMetric.heartRate]);
      expect(yucheng.measurementCalls, isEmpty);
    },
  );

  test('restores only the last selected SDK transport', () async {
    final preference = _MemoryTransportPreference()
      ..value = WearableTransport.yucheng;
    final veepoo = _FakeWearableBridge(
      scanned: const [],
      connectedDetails: const DeviceInfo(id: 'VP-1', name: 'V Ring'),
    );
    final yucheng = _FakeWearableBridge(
      scanned: const [],
      connectedDetails: const DeviceInfo(id: 'YC-1', name: 'YC Ring'),
    );
    final bridge = RoutedWearableBridge(
      veepoo: veepoo,
      yucheng: yucheng,
      preferenceStore: preference,
    );

    final restored = await bridge.restoreConnection(profile: _profile);

    expect(restored?.id, 'yucheng:YC-1');
    expect(yucheng.restoreCalls, 1);
    expect(veepoo.restoreCalls, 0);
  });
}

const _profile = WearableUserProfile(
  gender: 1,
  heightCm: 175,
  weightKg: 70,
  birthYear: 1996,
  age: 30,
  targetSteps: 10000,
);

class _FakeWearableBridge extends Fake
    implements
        WearableBridge,
        WearableDeviceDetailsBridge,
        WearableConnectionRecoveryBridge {
  _FakeWearableBridge({required this.scanned, this.connectedDetails});

  final List<DeviceInfo> scanned;
  final DeviceInfo? connectedDetails;
  final _events = StreamController<WearableEvent>.broadcast();
  final List<String> connectCalls = [];
  final List<HealthMetric> measurementCalls = [];
  int restoreCalls = 0;

  @override
  Stream<WearableEvent> get events => _events.stream;

  @override
  Future<List<DeviceInfo>> scanDevices() async => scanned;

  @override
  Future<void> stopScan() async {}

  void emitScan(DeviceInfo device) {
    _events.add(WearableEvent(type: 'scanDevice', payload: device.toJson()));
  }

  void emit(WearableEvent event) => _events.add(event);

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connectCalls.add(deviceId);
  }

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async => connectedDetails;

  @override
  Future<DeviceInfo?> restoreConnection({
    required WearableUserProfile profile,
  }) async {
    restoreCalls += 1;
    return connectedDetails;
  }

  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    measurementCalls.add(metric);
  }
}

class _MemoryTransportPreference implements WearableTransportPreferenceStore {
  WearableTransport? value;

  @override
  Future<WearableTransport?> read() async => value;

  @override
  Future<void> write(WearableTransport transport) async {
    value = transport;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _MemoryBoundPreference extends _MemoryTransportPreference
    implements WearableBindingPreferenceStore {
  _MemoryBoundPreference(this.binding);

  SavedWearableBinding? binding;

  @override
  Future<SavedWearableBinding?> readBinding() async => binding;

  @override
  Future<void> writeBinding(SavedWearableBinding value) async {
    binding = value;
    await write(value.transport);
  }

  @override
  Future<void> clear() async {
    binding = null;
    await super.clear();
  }
}

class _BondedQRingBridge extends _FakeWearableBridge
    implements
        WearableBoundDeviceLookupBridge,
        WearableBondedDeviceSelectionBridge,
        WearableRememberedDeviceSelectionBridge {
  _BondedQRingBridge(this.bonded, {this.remembered}) : super(scanned: const []);

  final DeviceInfo? bonded;
  final DeviceInfo? remembered;
  final List<String> lookupCalls = [];
  final List<String> rememberedLookupCalls = [];
  int selectionLookupCalls = 0;

  @override
  Future<DeviceInfo?> lookupPreviouslyBoundDevice(
    String nativeIdentifier,
  ) async {
    lookupCalls.add(nativeIdentifier);
    return bonded;
  }

  @override
  Future<List<DeviceInfo>> listBondedDevicesForSelection() async {
    selectionLookupCalls++;
    return bonded == null ? const [] : [bonded!];
  }

  @override
  Future<DeviceInfo?> prepareRememberedDeviceForSelection(
    String nativeIdentifier, {
    String? knownName,
  }) async {
    rememberedLookupCalls.add(nativeIdentifier);
    return remembered;
  }
}

class _NativeMarketBridge extends _FakeWearableBridge
    implements WearableNativeWatchFaceBridge {
  _NativeMarketBridge({String name = 'V Ring', String id = 'fixture-watch'})
    : super(
        scanned: [DeviceInfo(id: id, name: name)],
      );

  int catalogCalls = 0;
  Completer<List<NativeWatchFaceCatalogItem>>? pending;

  @override
  Future<List<NativeWatchFaceCatalogItem>> getNativeWatchFaceCatalog() async {
    catalogCalls++;
    return pending?.future ?? Future.value([]);
  }

  @override
  Future<NativeWatchFaceDownload> downloadNativeWatchFace(
    String catalogId,
  ) async => NativeWatchFaceDownload(
    catalogId: catalogId,
    filePath: '/fixture.bin',
    fileLength: 32,
  );
}
