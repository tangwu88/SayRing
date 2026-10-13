import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart';

// Existing owner/binding only. Run exclusively through the preserving driver,
// then restore the separately verified normal Profile binary. No OTA, scan,
// unbind, login replacement or synthetic device readings.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iPhone firmware location and real camera session', (
    tester,
  ) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    await controller.initialize();
    final owner = controller.session?.accountKey;
    final local = controller.isLocalMode;
    expect(
      controller.isAuthenticated || local,
      isTrue,
      reason: 'Existing session required; no substitute demo account',
    );
    await tester.pumpWidget(SaydianApp(controller: controller));
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (controller.connectedDevice != null &&
          controller.deviceCapabilityState == DeviceCapabilityState.ready) {
        break;
      }
    }
    expect(
      controller.connectedDevice != null &&
          controller.deviceCapabilityState == DeviceCapabilityState.ready,
      isTrue,
      reason:
          'Existing ring did not complete handshake; device acceptance pending',
    );
    controller.selectTab(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('device-functions-firmware')), findsNothing);
    final about = find.text('关于设备');
    await tester.ensureVisible(about);
    await tester.tap(about);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final firmware = find.byKey(const Key('device-firmware-upgrade'));
    await tester.ensureVisible(firmware);
    await tester.tap(firmware);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DeviceFirmwarePage), findsOneWidget);
    expect(find.text('在线固件升级暂未开放'), findsOneWidget);
    expect(find.text('已是最新版本'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 600));

    final offered = controller.availabilityFor(DeviceFeature.camera).isReady;
    var preview = false;
    var remoteAcknowledged = false;
    var manualPhotoSaved = false;
    var galleryPermissionDenied = false;
    var ringShutterReceived = false;
    if (offered) {
      // Wait for ordinary SDK sync; do not interrupt or clear device history.
      for (var i = 0; i < 360 && controller.isDeviceSyncing; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(controller.isDeviceSyncing, isFalse);
      expect(
        controller.availabilityFor(DeviceFeature.camera).isReady,
        isTrue,
        reason: 'Connection changed during sync; camera acceptance pending',
      );
      await tester.pump();
      final entry = find.byKey(const Key('device-feature-camera'));
      await tester.scrollUntilVisible(
        entry,
        -180,
        scrollable: find
            .descendant(
              of: find.byType(DevicePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(entry);
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(CameraPreview).evaluate().isNotEmpty &&
            find.text('摇动戴戒指的手，或点击快门').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.byType(DeviceFeaturePage), findsOneWidget);
      preview = find.byType(CameraPreview).evaluate().isNotEmpty;
      remoteAcknowledged = find.text('摇动戴戒指的手，或点击快门').evaluate().isNotEmpty;
      if (preview && remoteAcknowledged) {
        final sequence = controller.cameraShutterSequence;
        await tester.pump(const Duration(seconds: 3));
        ringShutterReceived = controller.cameraShutterSequence > sequence;
        final shutter = find.byKey(const ValueKey('camera-shutter-button'));
        await tester.ensureVisible(shutter);
        await tester.tap(shutter);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          manualPhotoSaved = find
              .byWidgetPredicate(
                (widget) => widget is Image && widget.image is FileImage,
              )
              .evaluate()
              .isNotEmpty;
          galleryPermissionDenied = find
              .byKey(const ValueKey('camera-photo-settings-button'))
              .evaluate()
              .isNotEmpty;
          if (manualPhotoSaved || galleryPermissionDenied) break;
        }
        expect(
          manualPhotoSaved || galleryPermissionDenied,
          isTrue,
          reason:
              'Real save or explicit recoverable permission failure required',
        );
      }
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 2));
    }
    expect(controller.session?.accountKey, owner);
    expect(controller.isLocalMode, local);
    binding.reportData = {
      'firmwareOnlyInAbout': true,
      'sdk': controller.connectedDevice?.sdkSource.name ?? 'disconnected',
      'cameraOffered': offered,
      'cameraPreview': preview,
      'cameraRemoteACK': remoteAcknowledged,
      'manualPhotoSaved': manualPhotoSaved,
      'galleryPermissionDenied': galleryPermissionDenied,
      'realRingShutterReceived': ringShutterReceived,
      'ownerPreserved': true,
      // False is pending, never a simulated device success.
    };
  });
}
