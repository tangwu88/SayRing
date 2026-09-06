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
      final yuc = _NativeMarketBridge(name: 'W8', id: 'fixture-yuc');
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

  test('routes every device name containing W8 to Yucheng', () {
    expect(YuchengDeviceClassifier.matches('W8'), isTrue);
    expect(YuchengDeviceClassifier.matches('w8s'), isTrue);
    expect(YuchengDeviceClassifier.matches('W8S 983F'), isTrue);
    expect(YuchengDeviceClassifier.matches('W8 983F'), isTrue);
    expect(YuchengDeviceClassifier.matches(' W8  Pro '), isTrue);
    expect(YuchengDeviceClassifier.matches('W8-Ultra'), isTrue);
    expect(YuchengDeviceClassifier.matches('w8 ultra-r'), isTrue);
    expect(YuchengDeviceClassifier.matches('W8 Plus 549D'), isTrue);
    expect(YuchengDeviceClassifier.matches('W80'), isTrue);
    expect(YuchengDeviceClassifier.matches('W8 Pro Max'), isTrue);
    expect(YuchengDeviceClassifier.matches('SAYDIAN-W8-BLE'), isTrue);
    expect(YuchengDeviceClassifier.matches('W9S'), isFalse);
    expect(YuchengDeviceClassifier.matches('w9 s 1234'), isFalse);
    expect(YuchengDeviceClassifier.matches('W9'), isFalse);
    expect(YuchengDeviceClassifier.matches('VP-100'), isFalse);
  });

  test('scopes IDs without losing the vendor identifier', () {
    final routed = RoutedDevice.fromScan(
      transport: WearableTransport.yucheng,
      nativeIdentifier: 'A1-B2',
      name: 'W8 Ultra',
    );

    expect(routed.display.id, 'yucheng:A1-B2');
    expect(routed.nativeIdentifier, 'A1-B2');
    expect(routed.transport, WearableTransport.yucheng);
  });

  test('prefers Yucheng for a W8 seen by both SDKs', () async {
    final veepoo = _FakeWearableBridge(
      scanned: const [
        DeviceInfo(id: 'AA:01', name: 'W8 Ultra'),
        DeviceInfo(id: 'AA:02', name: 'VP-100'),
      ],
    );
    final yucheng = _FakeWearableBridge(
      scanned: const [DeviceInfo(id: 'IOS-UUID-01', name: 'W8 Ultra')],
    );
    final bridge = RoutedWearableBridge(veepoo: veepoo, yucheng: yucheng);

    final devices = await bridge.scanDevices();

    expect(devices.map((item) => item.id), contains('yucheng:IOS-UUID-01'));
    expect(devices.map((item) => item.id), isNot(contains('veepoo:AA:01')));
    expect(devices.map((item) => item.id), contains('veepoo:AA:02'));
  });

  test('locks every later operation to the transport that connected', () async {
    final veepoo = _FakeWearableBridge(scanned: const []);
    final yucheng = _FakeWearableBridge(
      scanned: const [DeviceInfo(id: 'YC-1', name: 'W8S')],
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

  test('hides a W8 only returned by Veepoo', () async {
    final bridge = RoutedWearableBridge(
      veepoo: _FakeWearableBridge(
        scanned: const [DeviceInfo(id: 'W8-1', name: 'W8')],
      ),
      yucheng: _FakeWearableBridge(scanned: const []),
    );

    expect(await bridge.scanDevices(), isEmpty);
  });

  test('keeps W9 and W9S devices on the Veepoo transport', () async {
    final bridge = RoutedWearableBridge(
      veepoo: _FakeWearableBridge(
        scanned: const [
          DeviceInfo(id: 'W9-1', name: 'W9 1001'),
          DeviceInfo(id: 'W9S-1', name: 'SD-watch-W9S'),
        ],
      ),
      yucheng: _FakeWearableBridge(scanned: const []),
    );

    final devices = await bridge.scanDevices();

    expect(devices, hasLength(2));
    expect(devices.map((device) => device.id), contains('veepoo:W9-1'));
    expect(devices.map((device) => device.id), contains('veepoo:W9S-1'));
  });

  test('scopes pulled W9S details and live metadata events', () async {
    final veepoo = _FakeWearableBridge(
      scanned: const [DeviceInfo(id: 'W9S-1', name: 'SD-watch-W9S')],
      connectedDetails: const DeviceInfo(
        id: 'W9S-1',
        name: 'SD-watch-W9S',
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
    await bridge.connect('veepoo:W9S-1', profile: _profile);
    final details = await bridge.getConnectedDeviceDetails();
    veepoo.emit(
      const WearableEvent(
        type: 'deviceDetails',
        payload: {
          'id': 'W9S-1',
          'name': 'SD-watch-W9S',
          'firmwareVersion': '00.20.01',
        },
      ),
    );
    veepoo.emit(
      const WearableEvent(
        type: 'syncProgress',
        payload: {'deviceId': 'W9S-1', 'progress': 0.5},
      ),
    );
    await pumpEventQueue();

    expect(details?.id, 'veepoo:W9S-1');
    expect(details?.firmwareVersion, '00.20.01');
    expect(received[0].payload['id'], 'veepoo:W9S-1');
    expect(received[1].payload['deviceId'], 'veepoo:W9S-1');
    await subscription.cancel();
    await bridge.dispose();
  });

  test('drops live Veepoo W8 events and forwards the Yucheng event', () async {
    final veepoo = _FakeWearableBridge(scanned: const []);
    final yucheng = _FakeWearableBridge(scanned: const []);
    final bridge = RoutedWearableBridge(veepoo: veepoo, yucheng: yucheng);
    final received = <WearableEvent>[];
    final subscription = bridge.events.listen(received.add);

    veepoo.emitScan(
      const DeviceInfo(id: '07:43:00:00:4D:E9', name: 'w8s 4DE9'),
    );
    yucheng.emitScan(
      const DeviceInfo(id: '07:43:00:00:4D:E9', name: 'w8s 4DE9'),
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
        const DeviceInfo(id: '38:23:A4:5E:CA:69', name: 'SD-watch-W9S'),
      );
      await pumpEventQueue();
      await bridge.connect('veepoo:38:23:A4:5E:CA:69', profile: _profile);

      expect(veepoo.connectCalls, ['38:23:A4:5E:CA:69']);
      await subscription.cancel();
      await bridge.dispose();
    },
  );

  test(
    'discovers suffixed W8S through Yucheng and hides the Veepoo duplicate',
    () async {
      final bridge = RoutedWearableBridge(
        veepoo: _FakeWearableBridge(
          scanned: const [DeviceInfo(id: 'VP-W8S', name: 'w8s 4DE9')],
        ),
        yucheng: _FakeWearableBridge(
          scanned: const [DeviceInfo(id: 'YC-W8S', name: 'w8s 4DE9')],
        ),
      );

      final devices = await bridge.scanDevices();

      expect(devices, hasLength(1));
      expect(devices.single.id, 'yucheng:YC-W8S');
      expect(devices.single.name, 'w8s 4DE9');
    },
  );

  test(
    'routes W8 Plus through Yucheng and hides the Veepoo duplicate',
    () async {
      final bridge = RoutedWearableBridge(
        veepoo: _FakeWearableBridge(
          scanned: const [DeviceInfo(id: 'VP-W8-PLUS', name: 'W8 Plus 549D')],
        ),
        yucheng: _FakeWearableBridge(
          scanned: const [DeviceInfo(id: 'YC-W8-PLUS', name: 'W8 Plus 549D')],
        ),
      );

      final devices = await bridge.scanDevices();

      expect(devices, hasLength(1));
      expect(devices.single.id, 'yucheng:YC-W8-PLUS');
      expect(devices.single.sdkSource, WearableSdkSource.yucheng);
    },
  );

  test('restores a W9S and locks later operations to Veepoo', () async {
    final veepoo = _FakeWearableBridge(
      scanned: const [],
      connectedDetails: const DeviceInfo(
        id: '38:23:A4:5E:CA:69',
        name: 'SD-watch-W9S',
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
  });

  test('restores only the last selected SDK transport', () async {
    final preference = _MemoryTransportPreference()
      ..value = WearableTransport.yucheng;
    final veepoo = _FakeWearableBridge(
      scanned: const [],
      connectedDetails: const DeviceInfo(id: 'VP-1', name: 'ET488'),
    );
    final yucheng = _FakeWearableBridge(
      scanned: const [],
      connectedDetails: const DeviceInfo(id: 'YC-1', name: 'W8 Plus 549D'),
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

class _NativeMarketBridge extends _FakeWearableBridge
    implements WearableNativeWatchFaceBridge {
  _NativeMarketBridge({String name = 'W9S', String id = 'fixture-watch'})
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
