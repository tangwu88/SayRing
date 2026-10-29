import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/widgets/ring_camera_panel.dart';

class _Lifecycle extends WidgetsBindingObserver {
  final events = <AppLifecycleState>[];
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => events.add(state);
}

// The host briefly opens Clock and returns to Say Ring after the marker.
// Preview only: never tap the shutter, change binding or save a photograph.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'XR real camera preview survives foreground recovery',
    (tester) async {
      final app = AppController.production();
      addTearDown(app.dispose);
      final lifecycle = _Lifecycle();
      binding.addObserver(lifecycle);
      addTearDown(() => binding.removeObserver(lifecycle));
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      final owner = app.session?.accountKey;
      final target = app.rememberedDevice?.id;
      expect(owner, isNotNull);
      expect(target, isNotNull);
      final proof = <String, Object?>{};
      Future<void> waitFor(bool Function() ready, int seconds) async {
        for (var i = 0; i < seconds * 4 && !ready(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await tester.pump().timeout(const Duration(seconds: 15));
        }
        expect(ready(), isTrue);
      }

      CameraController? camera() {
        final preview = find.byType(CameraPreview);
        return preview.evaluate().isEmpty
            ? null
            : tester.widget<CameraPreview>(preview).controller;
      }

      try {
        await waitFor(
          () =>
              app.connectedDevice?.id == target &&
              app.deviceCapabilityState == DeviceCapabilityState.ready &&
              !app.isDeviceSyncing,
          100,
        );
        proof['bindingLifecycleBeforeNative'] = binding.lifecycleState?.name;
        // Widget tests reset ServicesBinding between cases while the physical
        // app can stay foreground. Re-establish state with real OS transitions.
        lifecycle.events.clear();
        debugPrint('XR CAMERA: establish-native-foreground');
        await waitFor(
          () =>
              lifecycle.events.contains(AppLifecycleState.resumed) &&
              binding.lifecycleState == AppLifecycleState.resumed,
          40,
        );
        proof['nativeForegroundEstablished'] = true;
        await waitFor(
          () =>
              app.connectedDevice?.id == target &&
              app.deviceCapabilityState == DeviceCapabilityState.ready &&
              !app.isDeviceSyncing,
          100,
        );
        expect(app.availabilityFor(DeviceFeature.camera).isReady, isTrue);
        app.selectTab(1);
        await tester.pump(const Duration(seconds: 1));
        final tile = find.byKey(const Key('device-feature-camera'));
        await tester.scrollUntilVisible(
          tile,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(tile), alignment: .5);
        await tester.pump();
        await tester.tap(tile.hitTestable());
        await waitFor(() => camera()?.value.isInitialized == true, 40);
        final first = camera();
        proof['initialPreviewInitialized'] = true;
        // Deliberately overlap resumed with unfinished native camera disposal.
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await waitFor(
          () =>
              camera()?.value.isInitialized == true &&
              !identical(first, camera()),
          40,
        );
        proof['rapidResumeRecreatedPreview'] = true;
        final beforeNative = camera();
        lifecycle.events.clear();
        debugPrint('XR CAMERA: ready-for-native-background');
        await waitFor(
          () =>
              lifecycle.events.any((s) => s != AppLifecycleState.resumed) &&
              binding.lifecycleState == AppLifecycleState.resumed &&
              camera()?.value.isInitialized == true &&
              !identical(beforeNative, camera()),
          60,
        );
        proof['nativeBackgroundAndResume'] = true;
        proof['nativeLifecycleEvents'] = lifecycle.events
            .map((s) => s.name)
            .toList();
        final panel = tester.widget<RingCameraPanel>(
          find.byType(RingCameraPanel),
        );
        expect(panel.saved, isFalse);
        expect(panel.onRetrySave, isNull);
        expect(panel.takingPhoto, isFalse);
        proof['noPhotoRequestedOrSaved'] = true;
        await binding.takeScreenshot('xr-camera-resumed-private');
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(seconds: 1));
        await waitFor(
          () => !app.deviceFeatureBusy.contains(DeviceFeature.camera),
          20,
        );
        expect(app.session?.accountKey, owner);
        expect(app.rememberedDevice?.id, target);
        expect(tester.takeException(), isNull);
      } finally {
        binding.reportData = {...?binding.reportData, 'cameraLifecycle': proof};
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
