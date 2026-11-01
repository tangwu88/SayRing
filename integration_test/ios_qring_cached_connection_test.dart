import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/module_visibility.dart';
import 'package:saydian_app/domain/read_only_health_features.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_notification_service.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/global_environment.dart';
import 'package:saydian_app/services/health_reminder_notifications.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/qring_wearable_bridge.dart';
import 'package:saydian_app/services/safe_secure_storage.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bootstrap.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/services/wearable_routing.dart';

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
  testWidgets(
    'known QRing cache handshake and unbind selection retention',
    (tester) async {
      const id = String.fromEnvironment('SAYRING_QA_TARGET_ID');
      const name = String.fromEnvironment('SAYRING_QA_TARGET_NAME');
      const owner = String.fromEnvironment('SAYRING_QA_OWNER_HASH');
      expect(RegExp(r'^qring:[0-9a-fA-F-]{36}$').hasMatch(id), isTrue);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(owner), isTrue);
      expect(
        WearableDeviceClassifier.transportFor(name),
        WearableTransport.qring,
      );
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
        app.isAuthenticated && !app.isPreviewMode && !app.isLocalMode,
        isTrue,
      );
      expect(app.homeHealthCardOwner, owner);
      final account = app.session!.accountKey;
      expect(
        app.rememberedDevice == null || app.rememberedDevice!.id == id,
        isTrue,
      );
      final store = SecureWearableTransportPreferenceStore();
      final proof = <String, Object?>{'stage': 'initialized', 'model': name};
      final file = File(
        '${(await getApplicationDocumentsDirectory()).path}/qring-connection-qa-proof.json',
      );
      Future<void> save(String stage) async {
        expect(app.homeHealthCardOwner, owner);
        expect(app.session?.accountKey, account);
        expect(native.clearAttempts, 0);
        proof['stage'] = stage;
        binding.reportData = Map.from(proof);
        await file.writeAsString(jsonEncode(proof), flush: true);
      }

      if (app.rememberedDevice == null &&
          !(await store.readRecentBindings(owner)).any(
            (x) => RoutedDevice.scopedID(x.transport, x.nativeIdentifier) == id,
          )) {
        // User-authorized one-time import from this phone's successful-handshake
        // log. Require the same target in the current account's genuine history;
        // this adds a manual choice, never a binding or an SDK result.
        expect(
          app.healthRecords.any(
            (record) =>
                record.deviceId == id &&
                record.sourceVendor == 'qring' &&
                record.sourceModel == name,
          ),
          isTrue,
        );
        final key =
            'saydian.global.env.${GlobalEnvironment.storageNamespace}.'
            'wearable.selection-history.v1.${sha256.convert(utf8.encode(owner))}';
        expect(await safeSecureStorage.read(key: key), isNull);
        await safeSecureStorage.write(
          key: key,
          value: jsonEncode({
            'schemaVersion': 1,
            'environment': GlobalEnvironment.storageNamespace,
            'ownerKey': owner,
            'bindings': [
              {
                'transport': 'qring',
                'nativeIdentifier': id.substring('qring:'.length),
                'deviceName': name,
              },
            ],
          }),
        );
        proof['verifiedLogCandidateImported'] = true;
      }
      await save('candidate available');

      Future<void> connectFromCache(String stage) async {
        final before = await store.readBinding();
        await app.listBondedDevicesForSelection().timeout(
          const Duration(seconds: 35),
        );
        final candidate = app.scannedDevices.singleWhere(
          (device) => device.id == id,
        );
        expect(candidate.name, name);
        expect(candidate.rssi, isNull);
        expect(
          (await store.readBinding())?.nativeIdentifier,
          before?.nativeIdentifier,
        );
        final started = DateTime.now();
        await app.connectDevice(candidate).timeout(const Duration(seconds: 60));
        expect(app.connectedDevice?.id, id);
        expect(app.deviceState, DeviceConnectionState.ready);
        expect(app.deviceCapabilityState, DeviceCapabilityState.ready);
        expect(app.connectedDevice?.firmwareVersion?.isNotEmpty, isTrue);
        expect(
          (await store.readBinding())?.nativeIdentifier,
          id.substring('qring:'.length),
        );
        proof['${stage}Milliseconds'] = DateTime.now()
            .difference(started)
            .inMilliseconds;
        proof['firmware'] = app.connectedDevice?.firmwareVersion;
        await save(stage);
      }

      if (app.connectedDevice == null) {
        await connectFromCache('initial cached handshake');
      }
      await app.unbindDevice().timeout(const Duration(seconds: 30));
      expect(await store.readBinding(), isNull);
      expect(app.rememberedDevice, isNull);
      await Future<void>.delayed(const Duration(seconds: 4));
      expect(app.connectedDevice, isNull);
      expect(app.isWearableRecovering, isFalse);
      expect(
        (await store.readRecentBindings(owner)).any(
          (x) => RoutedDevice.scopedID(x.transport, x.nativeIdentifier) == id,
        ),
        isTrue,
      );
      await save('unbound without automatic rebinding');
      await connectFromCache('retained cached handshake');
      final oldCapabilities = app.capabilities;
      await app.reconnectDevice().timeout(const Duration(seconds: 60));
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while ((app.connectedDevice?.id != id ||
              app.deviceState != DeviceConnectionState.ready ||
              identical(app.capabilities, oldCapabilities)) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(app.connectedDevice?.id, id);
      expect(app.deviceState, DeviceConnectionState.ready);
      expect(app.deviceCapabilityState, DeviceCapabilityState.ready);
      expect(identical(app.capabilities, oldCapabilities), isFalse);
      await save('controlled reconnect ready');
      app.selectTab(1);
      await tester.pump();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
