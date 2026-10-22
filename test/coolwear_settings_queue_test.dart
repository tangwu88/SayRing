import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

class _Api extends Fake implements SaydianApi {}

class _Queue extends Fake implements WearableBridge {
  int calls = 0;
  int busyReads = 2;
  String busyCode = 'DEVICE_BUSY';
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    calls++;
    if (calls <= busyReads) throw PlatformException(code: busyCode);
    return {'incomingCall': true, 'systemNotificationAuthorized': false};
  }
}

void main() {
  void testIosWidgets(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  AppController controller(_Queue queue, {String id = 'coolwear:owned'}) =>
      AppController(MemorySessionVault(), _Api(), MemoryHealthStore(), queue)
        ..connectedDevice = DeviceInfo(id: id, name: 'R7 Ultra')
        ..capabilities = const DeviceCapabilities(
          metrics: {},
          features: {DeviceFeature.callReminder},
          integratedFeatures: {DeviceFeature.callReminder},
        );

  testIosWidgets(
    'busy read waits then returns actual snapshot without changing settings',
    (tester) async {
      final queue = _Queue();
      final app = controller(queue);
      addTearDown(app.dispose);
      final result = app.readDeviceFeature(DeviceFeature.callReminder);
      await tester.pump();
      expect(app.deviceFeatureBusy, contains(DeviceFeature.callReminder));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect((await result)['incomingCall'], true);
      expect(queue.calls, 3);
      expect(app.deviceFeatureBusy, isEmpty);
      expect(app.errorMessage, isNull);
    },
  );

  testIosWidgets('monitoring CONNECT_BUSY also waits for the real snapshot', (
    tester,
  ) async {
    final queue = _Queue()
      ..busyCode = 'CONNECT_BUSY'
      ..busyReads = 1;
    final app = controller(queue);
    addTearDown(app.dispose);
    final result = app.readDeviceFeature(DeviceFeature.callReminder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect((await result)['incomingCall'], true);
    expect(queue.calls, 2);
  });

  testIosWidgets(
    'replacement target cancels waiting read before another vendor call',
    (tester) async {
      final queue = _Queue();
      final app = controller(queue);
      addTearDown(app.dispose);
      final result = app.readDeviceFeature(DeviceFeature.callReminder);
      await tester.pump();
      app.connectedDevice = const DeviceInfo(
        id: 'coolwear:other',
        name: 'HR05',
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(await result, isEmpty);
      expect(queue.calls, 1);
      expect(app.deviceFeatureData, isEmpty);
    },
  );

  testIosWidgets('permanently busy reads have a bounded retry budget', (
    tester,
  ) async {
    final queue = _Queue()..busyReads = 100;
    final app = controller(queue);
    addTearDown(app.dispose);
    final result = app.readDeviceFeature(DeviceFeature.callReminder);
    await tester.pump();
    for (var i = 0; i < 41; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(await result, isEmpty);
    expect(queue.calls, 41);
    expect(app.deviceFeatureBusy, isEmpty);
    expect(app.errorMessage, isNotNull);
  });

  testIosWidgets('unrelated transports retain their existing busy behavior', (
    tester,
  ) async {
    final queue = _Queue();
    final app = controller(queue, id: 'qring:owned');
    addTearDown(app.dispose);
    final result = app.readDeviceFeature(DeviceFeature.callReminder);
    await tester.pump();
    expect(await result, isEmpty);
    expect(queue.calls, 1);
  });
}
