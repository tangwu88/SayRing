import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/widgets/ring_gesture_panel.dart';

const _gesture = DeviceFeature.gestureControl;
const _message = '手势状态未确认，请重新连接';
const _verified = <String, Object?>{
  'rawMode': 1,
  'confirmedMode': 2,
  'availableModes': [0, 2],
  'readbackVerified': true,
};

class _Api extends Fake implements SaydianApi {}

class _Wearable extends Fake implements WearableBridge {
  String? errorCode;
  Completer<void>? gate;
  int reads = 0;

  Future<void> _finish() async {
    await gate?.future;
    if (errorCode != null) {
      throw PlatformException(code: errorCode!, message: _message);
    }
  }

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    reads++;
    await _finish();
    return _verified;
  }

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) => _finish();
}

AppController _controller(_Wearable bridge, {String id = 'qring:owned'}) =>
    AppController(MemorySessionVault(), _Api(), MemoryHealthStore(), bridge)
      ..connectedDevice = DeviceInfo(id: id, name: 'fixture')
      ..deviceCapabilityState = DeviceCapabilityState.ready
      ..capabilities = const DeviceCapabilities(
        metrics: {},
        features: {_gesture, DeviceFeature.camera},
        integratedFeatures: {_gesture, DeviceFeature.camera},
      )
      ..deviceFeatureData = {_gesture: _verified};

void _expectUnconfirmed(Map<String, Object?>? value) {
  expect(value, {
    'requiresReconnect': true,
    'readbackVerified': false,
    'errorMessage': _message,
  });
}

void main() {
  for (final code in ['QRING_CONTROL_UNCONFIRMED', 'QRING_CONTROL_RECONNECT']) {
    test('QRing read $code survives global error consumption', () async {
      final bridge = _Wearable()..errorCode = code;
      final app = _controller(bridge);
      addTearDown(app.dispose);
      final result = await app.readDeviceFeature(_gesture);
      // AppShell consumes the shared snackbar error on its next frame.
      app.clearError();
      expect(app.errorMessage, isNull);
      _expectUnconfirmed(result);
      _expectUnconfirmed(app.deviceFeatureData[_gesture]);
      expect(app.deviceFeatureBusy, isEmpty);
      bridge.errorCode = null;
      expect(await app.readDeviceFeature(_gesture), _verified);
      expect(app.deviceFeatureData[_gesture], _verified);
    });

    test('QRing write $code invalidates the old confirmed snapshot', () async {
      final app = _controller(_Wearable()..errorCode = code);
      addTearDown(app.dispose);
      expect(
        await app.writeDeviceFeature(_gesture, {'mode': 0, 'expectedMode': 1}),
        isFalse,
      );
      app.clearError();
      _expectUnconfirmed(app.deviceFeatureData[_gesture]);
      expect(app.deviceFeatureBusy, isEmpty);
    });

    testWidgets('QRing page fences actual $code after snackbar clear', (
      tester,
    ) async {
      final bridge = _Wearable()..errorCode = code;
      final app = _controller(bridge);
      addTearDown(app.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceFeaturePage(controller: app, feature: _gesture),
        ),
      );
      await tester.pumpAndSettle();
      app.clearError();
      await tester.pumpAndSettle();
      final panel = tester.widget<RingGesturePanel>(
        find.byType(RingGesturePanel),
      );
      expect(panel.requiresReconnect, isTrue);
      expect(panel.ready, isFalse);
      expect(panel.confirmedMode, isNull);
      expect(panel.availableModes, isEmpty);
      expect(panel.error, _message);
      expect(find.text('重新连接'), findsOneWidget);
      expect(find.text('刷新状态'), findsNothing);
      expect(find.byKey(const ValueKey('gesture-mode-2')), findsNothing);
      expect(bridge.reads, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final operation in ['read', 'write']) {
    test('late QRing $operation failure cannot poison a replacement', () async {
      final bridge = _Wearable()
        ..errorCode = 'QRING_CONTROL_UNCONFIRMED'
        ..gate = Completer<void>();
      final app = _controller(bridge);
      addTearDown(app.dispose);
      final pending = operation == 'read'
          ? app.readDeviceFeature(_gesture)
          : app.writeDeviceFeature(_gesture, {'mode': 0, 'expectedMode': 1});
      app.connectedDevice = const DeviceInfo(id: 'qring:new', name: 'new');
      app.deviceFeatureData = {_gesture: _verified};
      bridge.gate!.complete();
      await pending;
      expect(app.deviceFeatureData[_gesture], _verified);
      expect(app.errorMessage, isNull);
    });
  }

  for (final variant in ['busy', 'other-source', 'other-feature']) {
    test('QRing failure projection stays scoped: $variant', () async {
      final bridge = _Wearable()
        ..errorCode = variant == 'busy'
            ? 'DEVICE_BUSY'
            : 'QRING_CONTROL_UNCONFIRMED';
      final app = _controller(
        bridge,
        id: variant == 'other-source' ? 'coolwear:owned' : 'qring:owned',
      );
      addTearDown(app.dispose);
      expect(
        await app.readDeviceFeature(
          variant == 'other-feature' ? DeviceFeature.camera : _gesture,
        ),
        isEmpty,
      );
      expect(app.deviceFeatureData[_gesture], _verified);
    });
  }
}
