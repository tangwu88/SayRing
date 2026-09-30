import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cc.saidian.ring/qring/commands');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps explicitly requested system-bonded QRing devices', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'listBondedDevices') {
            return <Object?>[
              <Object?, Object?>{
                'id': 'AA:BB:CC:DD:EE:FF',
                'name': 'R22_C493',
                'model': 'R22_C493',
                'hardwareAddress': 'AA:BB:CC:DD:EE:FF',
              },
            ];
          }
          return null;
        });

    final devices = await QRingWearableBridge().listBondedDevicesForSelection();

    expect(calls.map((call) => call.method), ['listBondedDevices']);
    expect(devices.single.name, 'R22_C493');
    expect(devices.single.macAddress, 'AA:BB:CC:DD:EE:FF');
    expect(devices.single.rssi, isNull);
  });

  test('prepares only the explicitly supplied remembered identifier', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          if (call.method == 'prepareRememberedDevice') {
            return <Object?, Object?>{
              'id': call.arguments['id'],
              'name': '上次连接的 QRing 戒指',
              'model': 'QRing',
            };
          }
          return null;
        });

    final device = await QRingWearableBridge()
        .prepareRememberedDeviceForSelection(
          'AA:BB:CC:DD:EE:FF',
          knownName: 'R22_C493',
        );

    expect(captured?.method, 'prepareRememberedDevice');
    expect(captured?.arguments, {
      'id': 'AA:BB:CC:DD:EE:FF',
      'name': 'R22_C493',
    });
    expect(device?.id, 'AA:BB:CC:DD:EE:FF');
  });
}
