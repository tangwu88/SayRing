import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/services/wearable_routing.dart';

final _environmentA = 'a' * 64;
final _environmentB = 'b' * 64;
const _watchA = DeviceInfo(id: 'native-id-a', name: 'V Same model');
const _watchB = DeviceInfo(id: 'native-id-b', name: 'V Same model');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'without current-environment binding neither native SDK is restored',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'wearable.last.transport': 'veepoo',
      });
      final veepoo = _FakeBridge();
      final yucheng = _FakeBridge();
      final bridge = _bridge(veepoo, yucheng, _environmentA);
      addTearDown(bridge.dispose);
      expect(await bridge.restoreConnection(profile: _profile), isNull);
      expect(veepoo.scanCount, 0);
      expect(yucheng.scanCount, 0);
      expect(veepoo.restoreCount + yucheng.restoreCount, 0);
      expect(veepoo.connectedIdentifiers, isEmpty);
      expect(yucheng.connectedIdentifiers, isEmpty);
    },
  );

  test(
    'A-B-A only reconnects each environments exact target, never native saved target',
    () async {
      final veepoo = _FakeBridge(scanned: [_watchA, _watchB]);
      final yucheng = _FakeBridge();
      await SecureWearableTransportPreferenceStore(
        storageNamespace: _environmentA,
      ).writeBinding(
        const SavedWearableBinding(WearableTransport.veepoo, 'native-id-a'),
      );
      await SecureWearableTransportPreferenceStore(
        storageNamespace: _environmentB,
      ).writeBinding(
        const SavedWearableBinding(WearableTransport.veepoo, 'native-id-b'),
      );
      for (final namespace in [_environmentA, _environmentB, _environmentA]) {
        final bridge = _bridge(veepoo, yucheng, namespace);
        final result = await bridge.restoreConnection(profile: _profile);
        expect(
          result?.id,
          namespace == _environmentA
              ? 'veepoo:native-id-a'
              : 'veepoo:native-id-b',
        );
        await bridge.dispose();
      }
      expect(veepoo.connectedIdentifiers, [
        'native-id-a',
        'native-id-b',
        'native-id-a',
      ]);
      expect(veepoo.restoreCount, 0);
      expect(yucheng.scanCount, 0);
      expect(yucheng.restoreCount, 0);
      expect(veepoo.stopCount, 3);
    },
  );

  test('same model name cannot replace a missing bound identifier', () async {
    await SecureWearableTransportPreferenceStore(
      storageNamespace: _environmentA,
    ).writeBinding(
      const SavedWearableBinding(WearableTransport.veepoo, 'native-id-a'),
    );
    final veepoo = _FakeBridge(scanned: [_watchB]);
    final bridge = _bridge(veepoo, _FakeBridge(), _environmentA);
    addTearDown(bridge.dispose);
    expect(await bridge.restoreConnection(profile: _profile), isNull);
    expect(veepoo.connectedIdentifiers, isEmpty);
    expect(veepoo.restoreCount, 0);
    expect(veepoo.stopCount, 1);
  });

  test(
    'late scanning after disconnect cannot reconnect or replace a binding',
    () async {
      final preference = SecureWearableTransportPreferenceStore(
        storageNamespace: _environmentA,
      );
      await preference.writeBinding(
        const SavedWearableBinding(WearableTransport.veepoo, 'native-id-a'),
      );
      final pendingScan = Completer<List<DeviceInfo>>();
      final veepoo = _FakeBridge(pendingScan: pendingScan.future);
      final bridge = _bridge(veepoo, _FakeBridge(), _environmentA);
      addTearDown(bridge.dispose);
      final restoring = bridge.restoreConnection(profile: _profile);
      await _waitUntil(() => veepoo.scanCount == 1);
      await bridge.disconnect();
      pendingScan.complete([_watchA]);
      expect(await restoring, isNull);
      expect(veepoo.connectedIdentifiers, isEmpty);
    },
  );

  test(
    'explicit scanned connection writes a complete environment binding',
    () async {
      final veepoo = _FakeBridge(scanned: [_watchA]);
      final bridge = _bridge(veepoo, _FakeBridge(), _environmentA);
      addTearDown(bridge.dispose);
      final found = await bridge.scanDevices();
      await bridge.connect(found.single.id, profile: _profile);
      final saved = await SecureWearableTransportPreferenceStore(
        storageNamespace: _environmentA,
      ).readBinding();
      expect(saved?.transport, WearableTransport.veepoo);
      expect(saved?.nativeIdentifier, 'native-id-a');
      expect(
        await SecureWearableTransportPreferenceStore(
          storageNamespace: _environmentB,
        ).readBinding(),
        isNull,
      );
    },
  );

  test(
    'controller stopScan cancellation cannot resume a partial saved target',
    () async {
      final preference = SecureWearableTransportPreferenceStore(
        storageNamespace: _environmentA,
      );
      await preference.writeBinding(
        const SavedWearableBinding(WearableTransport.veepoo, 'native-id-a'),
      );
      final pendingScan = Completer<List<DeviceInfo>>();
      final veepoo = _FakeBridge(pendingScan: pendingScan.future);
      final bridge = _bridge(veepoo, _FakeBridge(), _environmentA);
      addTearDown(bridge.dispose);
      final restoring = bridge.restoreConnection(profile: _profile);
      await _waitUntil(() => veepoo.scanCount == 1);
      await bridge.stopScan();
      pendingScan.complete([_watchA]);
      expect(await restoring, isNull);
      expect(veepoo.connectedIdentifiers, isEmpty);
      expect((await preference.readBinding())?.nativeIdentifier, 'native-id-a');
    },
  );

  test(
    'cancelled in-flight connect is drained and its own source disconnected',
    () async {
      final pendingConnect = Completer<void>();
      final veepoo = _FakeBridge(
        scanned: [_watchA],
        pendingConnect: pendingConnect.future,
      );
      await _saveTarget();
      final bridge = _bridge(veepoo, _FakeBridge(), _environmentA);
      addTearDown(bridge.dispose);
      final received = <WearableEvent>[];
      final subscription = bridge.events.listen(received.add);
      addTearDown(subscription.cancel);
      final restoring = bridge.restoreConnection(profile: _profile);
      await _waitUntil(() => veepoo.connectedIdentifiers.isNotEmpty);
      await bridge.stopScan();
      expect(veepoo.disconnectCount, 0);
      veepoo.eventController.add(
        const WearableEvent(
          type: 'reconnected',
          payload: {'id': 'native-id-a'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);
      pendingConnect.complete();
      expect(await restoring, isNull);
      expect(veepoo.disconnectCount, 1);
      expect(await bridge.getConnectedDeviceDetails(), isNull);
    },
  );

  test(
    'missing stopScan callback cannot hang recovery or cancellation',
    () async {
      final neverStops = Completer<void>();
      final veepoo = _FakeBridge(
        scanned: [_watchA],
        pendingStop: neverStops.future,
      );
      await _saveTarget();
      final bridge = _bridge(veepoo, _FakeBridge(), _environmentA);
      addTearDown(bridge.dispose);
      expect(
        (await bridge.restoreConnection(profile: _profile))?.id,
        'veepoo:native-id-a',
      );
      await bridge.stopScan().timeout(const Duration(seconds: 1));
      expect(veepoo.connectedIdentifiers, ['native-id-a']);
    },
  );

  test('scan timeout is bounded and never becomes a late connection', () async {
    final pendingScan = Completer<List<DeviceInfo>>();
    final veepoo = _FakeBridge(pendingScan: pendingScan.future);
    await _saveTarget();
    final bridge = _bridge(
      veepoo,
      _FakeBridge(),
      _environmentA,
      operationTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(bridge.dispose);
    await expectLater(
      bridge.restoreConnection(profile: _profile),
      throwsA(isA<TimeoutException>()),
    );
    pendingScan.complete([_watchA]);
    await Future<void>.delayed(Duration.zero);
    expect(veepoo.connectedIdentifiers, isEmpty);
  });

  test(
    'connect timeout discards late success and disconnects its native session',
    () async {
      final pendingConnect = Completer<void>();
      final veepoo = _FakeBridge(
        scanned: [_watchA],
        pendingConnect: pendingConnect.future,
      );
      await _saveTarget();
      final bridge = _bridge(
        veepoo,
        _FakeBridge(),
        _environmentA,
        operationTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(bridge.dispose);
      await expectLater(
        bridge.restoreConnection(profile: _profile),
        throwsA(isA<TimeoutException>()),
      );
      expect(await bridge.getConnectedDeviceDetails(), isNull);
      pendingConnect.complete();
      await _waitUntil(() => veepoo.disconnectCount == 1);
      expect(await bridge.getConnectedDeviceDetails(), isNull);
    },
  );

  test(
    'same SDK cannot reconnect until timed-out native connect and cleanup settle',
    () async {
      final pendingConnect = Completer<void>();
      final veepoo = _FakeBridge(
        scanned: [_watchA, _watchB],
        pendingConnect: pendingConnect.future,
      );
      await _saveTarget();
      final bridge = _bridge(
        veepoo,
        _FakeBridge(),
        _environmentA,
        operationTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(bridge.dispose);
      await expectLater(
        bridge.restoreConnection(profile: _profile),
        throwsA(isA<TimeoutException>()),
      );
      await bridge.scanDevices();
      veepoo.pendingConnect = null;
      await expectLater(
        bridge.connect('veepoo:native-id-b', profile: _profile),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'RECOVERY_PENDING',
          ),
        ),
      );
      expect(veepoo.connectedIdentifiers, ['native-id-a']);
      pendingConnect.complete();
      await _waitUntil(() => veepoo.disconnectCount == 1);
      await Future<void>.delayed(Duration.zero);
      await bridge.connect('veepoo:native-id-b', profile: _profile);
      expect(veepoo.disconnectCount, 1);
      expect(veepoo.connectedIdentifiers, ['native-id-a', 'native-id-b']);
    },
  );

  test(
    'late Veepoo success is cleaned without disconnecting active Yucheng',
    () async {
      final pendingConnect = Completer<void>();
      final veepoo = _FakeBridge(
        scanned: [_watchA],
        pendingConnect: pendingConnect.future,
      );
      final yucheng = _FakeBridge(
        scanned: const [DeviceInfo(id: 'yuc-id', name: 'YC W8')],
      );
      await _saveTarget();
      final bridge = _bridge(
        veepoo,
        yucheng,
        _environmentA,
        operationTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(bridge.dispose);
      await expectLater(
        bridge.restoreConnection(profile: _profile),
        throwsA(isA<TimeoutException>()),
      );
      await bridge.scanDevices();
      await bridge.connect('yucheng:yuc-id', profile: _profile);
      pendingConnect.complete();
      await _waitUntil(() => veepoo.disconnectCount == 1);
      await Future<void>.delayed(Duration.zero);
      expect(yucheng.disconnectCount, 0);
      await bridge.startMeasurement(HealthMetric.heartRate);
      expect(yucheng.measurementCount, 1);
      expect(veepoo.measurementCount, 0);
    },
  );

  test(
    'pending native cleanup survives caller timeout and blocks only its own SDK',
    () async {
      final pendingConnect = Completer<void>();
      final pendingDisconnect = Completer<void>();
      final veepoo = _FakeBridge(
        scanned: [_watchA, _watchB],
        pendingConnect: pendingConnect.future,
        pendingDisconnect: pendingDisconnect.future,
      );
      final yucheng = _FakeBridge(
        scanned: const [DeviceInfo(id: 'yuc-id', name: 'YC W8')],
      );
      await _saveTarget();
      final bridge = _bridge(
        veepoo,
        yucheng,
        _environmentA,
        operationTimeout: const Duration(milliseconds: 40),
      );
      addTearDown(bridge.dispose);
      final restoring = bridge.restoreConnection(profile: _profile);
      final failedWait = expectLater(
        restoring,
        throwsA(isA<TimeoutException>()),
      );
      await _waitUntil(() => veepoo.connectedIdentifiers.isNotEmpty);
      await bridge.stopScan();
      pendingConnect.complete();
      await _waitUntil(() => veepoo.disconnectCount == 1);
      await failedWait;
      await bridge.scanDevices();
      await expectLater(
        bridge.connect('veepoo:native-id-b', profile: _profile),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'RECOVERY_PENDING',
          ),
        ),
      );
      await bridge.connect('yucheng:yuc-id', profile: _profile);
      expect(yucheng.disconnectCount, 0);
      pendingDisconnect.complete();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await bridge.startMeasurement(HealthMetric.heartRate);
      expect(yucheng.measurementCount, 1);
      expect(veepoo.connectedIdentifiers, ['native-id-a']);
    },
  );
}

Future<void> _saveTarget() =>
    SecureWearableTransportPreferenceStore(
      storageNamespace: _environmentA,
    ).writeBinding(
      const SavedWearableBinding(WearableTransport.veepoo, 'native-id-a'),
    );

RoutedWearableBridge _bridge(
  _FakeBridge veepoo,
  _FakeBridge yucheng,
  String namespace, {
  Duration operationTimeout = const Duration(seconds: 1),
}) => RoutedWearableBridge(
  veepoo: veepoo,
  yucheng: yucheng,
  restoreOnlyBoundDevice: true,
  recoveryOperationTimeout: operationTimeout,
  recoveryStopScanTimeout: const Duration(milliseconds: 10),
  preferenceStore: SecureWearableTransportPreferenceStore(
    storageNamespace: namespace,
  ),
);

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 50; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Timed out waiting for synthetic scan');
}

const _profile = WearableUserProfile(
  gender: 1,
  heightCm: 175,
  weightKg: 70,
  birthYear: 1996,
  age: 30,
  targetSteps: 10000,
);

class _FakeBridge extends Fake
    implements WearableBridge, WearableConnectionRecoveryBridge {
  _FakeBridge({
    this.scanned = const [],
    this.pendingScan,
    this.pendingConnect,
    this.pendingStop,
    this.pendingDisconnect,
  });
  final List<DeviceInfo> scanned;
  final Future<List<DeviceInfo>>? pendingScan;
  Future<void>? pendingConnect;
  final Future<void>? pendingStop;
  final Future<void>? pendingDisconnect;
  final connectedIdentifiers = <String>[];
  int scanCount = 0;
  int restoreCount = 0;
  int stopCount = 0;
  int disconnectCount = 0;
  int measurementCount = 0;
  final eventController = StreamController<WearableEvent>.broadcast();

  @override
  Stream<WearableEvent> get events => eventController.stream;
  @override
  Future<List<DeviceInfo>> scanDevices() async {
    scanCount++;
    return pendingScan ?? scanned;
  }

  @override
  Future<void> stopScan() async {
    stopCount++;
    await pendingStop;
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connectedIdentifiers.add(deviceId);
    await pendingConnect;
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    await pendingDisconnect;
  }

  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    measurementCount++;
  }

  @override
  Future<DeviceInfo?> restoreConnection({
    required WearableUserProfile profile,
  }) async {
    restoreCount++;
    return const DeviceInfo(
      id: 'other-environment-native-target',
      name: 'Same model',
    );
  }
}
