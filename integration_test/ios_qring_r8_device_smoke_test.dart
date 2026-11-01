import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/widgets/ring_camera_panel.dart';

/// Reads the existing XR/R8 binding and settings. Never scans, binds, resets,
/// takes a photo or changes a ring setting. Run with the preserving iOS driver.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('existing R8 connection and device functions', (tester) async {
    final app = AppController.production();
    addTearDown(app.dispose);
    runApp(SaydianApp(controller: app));
    await app.initialize().timeout(const Duration(seconds: 60));
    expect(app.isAuthenticated && !app.isLocalMode && !app.isPreviewMode, true);
    final owner = app.session!.accountKey;
    final remembered = app.rememberedDevice;
    expect(remembered, isNotNull);
    expect(remembered!.name.toUpperCase().contains('R8'), true);

    Future<void> waitFor(bool Function() ready, int seconds) async {
      for (var i = 0; i < seconds * 4 && !ready(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump().timeout(const Duration(seconds: 15));
      }
      expect(ready(), true);
    }

    await waitFor(
      () =>
          app.connectedDevice?.id == remembered.id &&
          app.deviceCapabilityState == DeviceCapabilityState.ready &&
          !app.isDeviceSyncing,
      120,
    );
    expect(app.connectedDevice!.name.toUpperCase().contains('R8'), true);
    expect(app.connectedDevice!.sdkSource.name, 'qring');
    expect(app.connectedDevice!.battery?.updatedAt, isNotNull);

    final proof = <String, Object?>{
      'exactRememberedR8Connected': true,
      'batteryRead': true,
      'findOffered': app.availabilityFor(DeviceFeature.findWatch).isReady,
      'gestureOffered': app
          .availabilityFor(DeviceFeature.gestureControl)
          .isReady,
      'cameraOffered': app.availabilityFor(DeviceFeature.camera).isReady,
      'monitoringOffered': app
          .availabilityFor(DeviceFeature.healthMonitoring)
          .isReady,
    };
    expect(proof['gestureOffered'], true);
    expect(proof['cameraOffered'], true);
    final gesture = await app.readDeviceFeature(DeviceFeature.gestureControl);
    proof['gestureRead'] = gesture.isNotEmpty;
    expect(gesture, isNotEmpty);
    expect(app.session?.accountKey, owner);
    expect(app.rememberedDevice?.id, remembered.id);

    app.selectTab(1);
    await tester.pump(const Duration(seconds: 1));
    final cameraTile = find.byKey(const Key('device-feature-camera'));
    await tester.scrollUntilVisible(
      cameraTile,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(cameraTile), alignment: .5);
    await tester.tap(cameraTile.hitTestable());
    await waitFor(() => find.byType(CameraPreview).evaluate().isNotEmpty, 45);
    final camera = tester
        .widget<CameraPreview>(find.byType(CameraPreview))
        .controller;
    expect(camera.value.isInitialized, true);
    proof['realPreviewInitialized'] = true;
    await waitFor(
      () =>
          find.byType(RingCameraPanel).evaluate().isNotEmpty &&
          tester
              .widget<RingCameraPanel>(find.byType(RingCameraPanel))
              .remoteReady,
      30,
    );
    proof['remoteSessionConfirmed'] = true;
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 2));
    expect(app.session?.accountKey, owner);
    expect(app.rememberedDevice?.id, remembered.id);
    expect(app.connectedDevice?.id, remembered.id);
    proof['ownerAndBindingPreserved'] = true;
    binding.reportData = proof;
    final path =
        '${(await getApplicationDocumentsDirectory()).path}/r8-device-smoke-qa.json';
    await File(path).writeAsString(jsonEncode(proof), flush: true);
  });
}
