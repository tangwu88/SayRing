import 'dart:async';

import 'package:camera/camera.dart';
// The camera plugin's existing locked platform dependency is used as its test seam.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
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

class _Camera extends CameraPlatform {
  int created = 0;
  int disposed = 0;
  String? accessError;
  Completer<void>? disposeGate;
  final initialized = <int, StreamController<CameraInitializedEvent>>{};
  final errors = StreamController<CameraErrorEvent>.broadcast();
  final orientation =
      StreamController<DeviceOrientationChangedEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'fixture-camera',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];

  @override
  Future<int> createCamera(
    CameraDescription description,
    ResolutionPreset? resolution, {
    bool enableAudio = false,
  }) async {
    if (accessError != null) throw CameraException(accessError!, 'permission');
    final id = ++created;
    initialized[id] = StreamController<CameraInitializedEvent>.broadcast();
    return id;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      initialized[cameraId]!.stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => errors.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      orientation.stream;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    initialized[cameraId]!.add(
      CameraInitializedEvent(
        cameraId,
        640,
        480,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposed++;
    await disposeGate?.future;
  }

  @override
  Widget buildPreview(int cameraId) =>
      SizedBox(key: ValueKey('fixture-preview-$cameraId'));
}

class _Api extends Fake implements SaydianApi {}

class _Wearable extends Fake implements WearableBridge {
  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {}

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      const {};
}

void main() {
  for (final denied in [true, false]) {
    testWidgets(
      'iOS camera ${denied ? 'denied' : 'restricted'} recovery',
      (tester) async {
        final original = CameraPlatform.instance;
        final camera = _Camera()
          ..accessError = denied
              ? 'CameraAccessDeniedWithoutPrompt'
              : 'CameraAccessRestricted';
        CameraPlatform.instance = camera;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        var settingsOpened = 0;
        const permissions = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          permissions,
          (call) async {
            if (call.method == 'openAppSettings') {
              settingsOpened++;
              return true;
            }
            return null;
          },
        );
        final app =
            AppController(
                MemorySessionVault(),
                _Api(),
                MemoryHealthStore(),
                _Wearable(),
              )
              ..connectedDevice = const DeviceInfo(
                id: 'qring:fixture',
                name: 'R21',
              )
              ..deviceCapabilityState = DeviceCapabilityState.ready
              ..capabilities = const DeviceCapabilities(
                metrics: {},
                features: {DeviceFeature.camera},
                integratedFeatures: {DeviceFeature.camera},
              );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          app.dispose();
          CameraPlatform.instance = original;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            permissions,
            null,
          );
        });
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceFeaturePage(
              controller: app,
              feature: DeviceFeature.camera,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CameraPreview), findsNothing);
        if (denied) {
          expect(find.text('前往设置开启相机'), findsOneWidget);
          final retry = find.byKey(const Key('camera-retry-button'));
          await tester.ensureVisible(retry);
          await tester.pumpAndSettle();
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(settingsOpened, 1);
          expect(camera.created, 0);
        } else {
          expect(find.textContaining('相机受到系统限制'), findsOneWidget);
          expect(find.text('前往设置开启相机'), findsNothing);
        }
        // Once the user has changed the OS setting, returning to the app retries
        // the actual camera initialization instead of retaining the old error.
        camera.accessError = null;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.byType(CameraPreview), findsOneWidget);
        expect(find.text('前往设置开启相机'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }
  for (final state in ['resumed', 'background', 'owner-lost', 'unmounted']) {
    testWidgets(
      'camera delayed disposal followed by $state',
      (tester) async {
        final original = CameraPlatform.instance;
        final camera = _Camera();
        CameraPlatform.instance = camera;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final app =
            AppController(
                MemorySessionVault(),
                _Api(),
                MemoryHealthStore(),
                _Wearable(),
              )
              ..connectedDevice = const DeviceInfo(
                id: 'qring:fixture',
                name: 'R21',
              )
              ..deviceCapabilityState = DeviceCapabilityState.ready
              ..capabilities = const DeviceCapabilities(
                metrics: {},
                features: {DeviceFeature.camera},
                integratedFeatures: {DeviceFeature.camera},
              );
        addTearDown(() async {
          if (camera.disposeGate?.isCompleted == false) {
            camera.disposeGate!.complete();
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          app.dispose();
          CameraPlatform.instance = original;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        });
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceFeaturePage(
              controller: app,
              feature: DeviceFeature.camera,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(camera.created, 1);
        expect(find.byType(CameraPreview), findsOneWidget);
        camera.disposeGate = Completer<void>();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        for (var i = 0; i < 10 && camera.disposed == 0; i++) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        expect(camera.disposed, 1);
        if (state != 'background') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
        }
        expect(
          camera.created,
          1,
          reason: 'Never reopen before disposal completes',
        );
        if (state == 'owner-lost') app.connectedDevice = null;
        if (state == 'unmounted') {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        camera.disposeGate!.complete();
        await tester.pumpAndSettle();
        expect(camera.created, state == 'resumed' ? 2 : 1);
        if (state == 'resumed') {
          expect(find.byType(CameraPreview), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }
}
