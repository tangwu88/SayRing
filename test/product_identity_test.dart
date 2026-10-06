import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/global_environment.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';

void main() {
  test('unverified QRing heart warning is absent, not a failed read', () async {
    expect(await QRingWearableBridge().readHeartRateWarning(), isNull);
  });

  test('all shipping configurations use cn.saydian.ring', () {
    expect(GlobalEnvironment.packageId, 'cn.saydian.ring');
    final android = File('android/app/build.gradle.kts').readAsStringSync();
    expect(android, contains('applicationId = "cn.saydian.ring"'));
    expect(android, isNot(contains('applicationIdSuffix')));
    for (final name in ['Debug', 'Release']) {
      final config = File('ios/Flutter/$name.xcconfig').readAsStringSync();
      final id = config.lastIndexOf(
        'SAIDIAN_BUNDLE_IDENTIFIER = cn.saydian.ring',
      );
      expect(id, greaterThan(config.indexOf('#include? "Local.xcconfig"')));
    }
  });

  test('native QRing name gates include the user confirmed R2 family', () {
    final ios = File('ios/Runner/QRingWearableBridge.m').readAsStringSync();
    final android = File(
      'android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java',
    ).readAsStringSync();
    expect(ios, contains('[upper hasPrefix:@"R2"]'));
    expect(android, contains('normalized.startsWith("R2")'));
  });

  test('QRing unbind uses vendor removal and waits for native state', () {
    final android = File(
      'android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java',
    ).readAsStringSync();
    final ios = File('ios/Runner/QRingWearableBridge.m').readAsStringSync();
    final central = File('ios/Runner/QCCentralManager.m').readAsStringSync();
    final remove = central.substring(
      central.indexOf('- (void)remove'),
      central.indexOf('- (void)disconnect'),
    );

    expect(android, contains('case "disconnect": startUnbind(result);'));
    expect(android, contains('manager.unBindDevice();'));
    expect(
      android,
      contains('private MethodChannel.Result pendingDisconnect;'),
    );
    expect(ios, contains('[self.central remove];'));
    expect(ios, contains('self.pendingDisconnect = result;'));
    expect(
      remove.indexOf('cancelPeripheralConnection:peripheral'),
      lessThan(remove.indexOf('self.connectedPeripheral = nil;')),
      reason: 'Keep the peripheral reference until CoreBluetooth disconnects.',
    );
    expect(
      central,
      contains(
        'self.deviceState = [self isBindDevice] ? QCStateDisconnected : QCStateUnbind;',
      ),
    );
  });

  test('iOS QRing recovery stays explicit and environment scoped', () {
    final bridge = File('ios/Runner/QRingWearableBridge.m').readAsStringSync();
    final central = File('ios/Runner/QCCentralManager.m').readAsStringSync();
    expect(bridge, contains('_central.appManagedConnections = YES'));
    expect(central, contains('if (self.appManagedConnections) { return; }'));
    expect(bridge, contains('retrievePeripheralsWithIdentifiers:@[uuid]'));
    expect(bridge, contains('![self isQRingName:peripheral.name]'));
    expect(
      bridge,
      contains('isEqualToString:@"lookupBondedDevice"]) { result(nil); }'),
    );
    expect(bridge, contains('if (!terminal) { return; }'));
    expect(bridge, contains('[QCSDKManager shareInstance].debug = NO'));
    expect(bridge, contains('disableDefaultMeasuringValues = YES'));
    expect(bridge, isNot(contains('@"progress": @5')));
    expect(bridge, contains('"rawVersion": activity ? @3 : @1'));
  });

  test('owned QRing central logs never include nearby device identity', () {
    final central = File('ios/Runner/QCCentralManager.m').readAsStringSync();
    final logs = RegExp(r'NSLog\([^;]*;').allMatches(central);
    expect(logs, isNotEmpty);
    for (final log in logs) {
      expect(log.group(0), isNot(contains('%@')));
      expect(log.group(0), isNot(contains('UUIDString')));
      expect(log.group(0), isNot(contains('peripheral.name')));
    }
  });

  test('QRing stress compatibility is tied to the verified SDK binary', () {
    final sdk = File('ios/Runner/Vendor/QCBandSDK.framework/QCBandSDK');
    expect(
      sha256.convert(sdk.readAsBytesSync()).toString(),
      'dde3ce1f803f998aa4795cf3189f805fb3c819cebd408165fecd60497b847393',
      reason: 'Recheck stress completion shape when updating this vendor SDK.',
    );
    final bridge = File('ios/Runner/QRingWearableBridge.m').readAsStringSync();
    expect(bridge, contains('if (!success || !value)'));
    expect(bridge, contains('if (!terminal) { return; }'));
    expect(bridge, contains('disableDefaultMeasuringValues = YES'));
    expect(
      bridge,
      contains('environment[@"SAY_RING_QA_MEASUREMENT"] isEqualToString:@"1"'),
    );
  });
}
