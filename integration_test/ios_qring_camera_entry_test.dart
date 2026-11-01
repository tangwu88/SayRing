import 'package:saydian_app/ui/widgets/ring_camera_panel.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/module_visibility.dart';
import 'package:saydian_app/domain/read_only_health_features.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_notification_service.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/health_reminder_notifications.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bootstrap.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

/// Normal native QRing operations, with destructive QA commands blocked.
class _NoClearQRing extends QRingWearableBridge {
  _NoClearQRing(WellnessReleasePolicy policy)
    : super(healthReleasePolicy: policy);
  int clearAttempts = 0;
  @override
  Future<RingDataClearResult> clearRingHistory({
    required String deviceId,
    required String ownerKey,
    bool allowFactoryReset = false,
  }) async {
    clearAttempts++;
    throw StateError('Connection QA never clears ring data');
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('owned QRing camera entry and real session', (tester) async {
    const target = String.fromEnvironment('SAYRING_QA_TARGET_ID');
    const owner = String.fromEnvironment('SAYRING_QA_OWNER_HASH');
    expect(RegExp(r'^qring:[0-9a-fA-F-]{36}$').hasMatch(target), isTrue);
    expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(owner), isTrue);
    final policy = WellnessReleasePolicy(
      enabled: true,
      readOnlyFeatures: ReadOnlyHealthFeatures(),
      manualFeatures: ManualHealthFeatures(),
    );
    final native = _NoClearQRing(policy);
    final vault = SecureSessionVault.global();
    final app = AppController(
      vault,
      GlobalSaydianApiClient(
        vault,
        locale: () => GlobalLocaleController.instance.locale.toLanguageTag(),
        healthReleasePolicy: const WellnessReleasePolicy(enabled: true),
        healthReadPolicyOverride: policy,
        moduleVisibilityPlatform: 'ios',
      ),
      EncryptedHealthStore(vault, globalEdition: true),
      createProductionWearableBridge(
        qring: native,
        healthReleasePolicy: policy,
      ),
      wellnessOnly: true,
      healthReadPolicy: policy,
      generalAiEnabled: false,
      moduleVisibility: ModuleVisibilityLease(),
      notificationService: const DisabledAppNotificationService(),
      healthReminderNotifications:
          const MethodChannelHealthReminderNotifications(),
    );
    addTearDown(app.dispose);
    runApp(SaydianApp(controller: app));
    await app.initialize().timeout(const Duration(seconds: 60));
    expect(
      app.isAuthenticated && !app.isLocalMode && !app.isPreviewMode,
      isTrue,
    );
    expect(app.homeHealthCardOwner, owner);
    final account = app.session!.accountKey;
    expect(app.rememberedDevice?.id, target);
    final proof = <String, Object?>{};
    final file = File(
      '${(await getApplicationDocumentsDirectory()).path}/qring-camera-entry-qa.json',
    );
    Future<void> save(String stage) async {
      expect(app.homeHealthCardOwner, owner);
      expect(app.session?.accountKey, account);
      expect(app.rememberedDevice?.id, target);
      expect(native.clearAttempts, 0);
      proof['stage'] = stage;
      binding.reportData = Map.of(proof);
      await file.writeAsString(jsonEncode(proof), flush: true);
    }

    Future<void> waitFor(bool Function() ready, int seconds) async {
      for (var i = 0; i < seconds * 4 && !ready(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump().timeout(const Duration(seconds: 15));
      }
      expect(ready(), isTrue);
    }

    try {
      await waitFor(
        () =>
            app.connectedDevice?.id == target &&
            app.deviceCapabilityState == DeviceCapabilityState.ready &&
            !app.isDeviceSyncing,
        120,
      );
      proof['firmware'] = app.connectedDevice?.firmwareVersion;
      proof['cameraOffered'] = app
          .availabilityFor(DeviceFeature.camera)
          .isReady;
      expect(proof['cameraOffered'], isTrue);
      final gesture = await app.readDeviceFeature(DeviceFeature.gestureControl);
      proof['gestureRead'] = gesture;
      await save('connected and camera offered');
      app.selectTab(1);
      await tester.pump(const Duration(seconds: 1));
      final tile = find.byKey(const Key('device-feature-camera'));
      await tester.scrollUntilVisible(
        tile,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(tile), alignment: .5);
      await tester.pump();
      await tester.tap(tile.hitTestable());
      await waitFor(() => find.byType(CameraPreview).evaluate().isNotEmpty, 45);
      final camera = tester
          .widget<CameraPreview>(find.byType(CameraPreview))
          .controller;
      expect(camera.value.isInitialized, isTrue);
      proof['realPreviewInitialized'] = true;
      await Future<void>.delayed(const Duration(seconds: 9));
      await tester.pump();
      final panel = tester.widget<RingCameraPanel>(
        find.byType(RingCameraPanel),
      );
      proof['remoteSessionConfirmed'] = panel.remoteReady;
      proof['remoteMessage'] = panel.message;
      proof['ringShutterSequence'] = app.cameraShutterSequence;
      await save('camera result observed');
      debugPrint('R21 CAMERA: preview ready for native capture');
      await Future<void>.delayed(const Duration(seconds: 15));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await save('camera closed');
    } finally {
      await save('finished');
    }
  });
}
