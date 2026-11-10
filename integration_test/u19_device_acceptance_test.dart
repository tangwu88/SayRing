import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_routing.dart';

/// 实物验收：默认只读。校时/新测量必须由本轮机主明确授权后单独编译开启。
/// 不允许重置或修改监测开关；校时以账号+目标回执阻止歧义重放。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'U19 exact connection, explicitly authorized actions and history preserve the existing owner',
    (tester) async {
      final app = AppController.production(
        allowAutomaticWearableRestore: false,
      );
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      final proof = <String, Object?>{
        'resetRequested': false,
        'settingsWritten': false,
      };
      final settingsFailures = <String>[];
      Future<void> save() async {
        final root = await getApplicationSupportDirectory();
        await File(
          '${root.path}/u19-device-acceptance.json',
        ).writeAsString(jsonEncode(proof));
        binding.reportData = proof;
      }

      try {
        await app.initialize().timeout(const Duration(seconds: 75));
        expect(
          app.isAuthenticated && !app.isLocalMode && !app.isPreviewMode,
          isTrue,
        );
        final owner = app.session!.accountKey;
        final savedBinding =
            await const SecureWearableTransportPreferenceStore().readBinding();
        if (savedBinding?.ownerKey == app.homeHealthCardOwner &&
            savedBinding?.transport == WearableTransport.urion) {
          // 禁用后台自动恢复的测试宿主也必须先经生产入口建立账号上下文。
          proof['cachedFirstAttempted'] = true;
          await app.reconnectDevice().timeout(const Duration(seconds: 75));
        }
        // 已经成功握手过的手表可能不再广播，先走生产的账号缓存恢复入口。
        if (app.connectedDevice == null) {
          await app.listBondedDevicesForSelection().timeout(
            const Duration(seconds: 45),
          );
        }
        var watches =
            [
                  if (app.connectedDevice != null) app.connectedDevice!,
                  ...app.scannedDevices,
                ]
                .where(
                  (d) =>
                      d.sdkSource == WearableSdkSource.urion &&
                      d.name.toUpperCase().contains('U19'),
                )
                .toList();
        proof['discovery'] = 'verified-owner-cache';
        if (watches.isEmpty) {
          await app.scanDevices().timeout(const Duration(seconds: 45));
          watches = app.scannedDevices
              .where(
                (d) =>
                    d.sdkSource == WearableSdkSource.urion &&
                    d.name.toUpperCase().contains('U19'),
              )
              .toList();
          proof['discovery'] = 'verified-advertisement';
        }
        proof['verifiedWatchCandidates'] = watches.length;
        expect(
          watches,
          isNotEmpty,
          reason: 'Only select a verified U19; never substitute a ring.',
        );
        watches.sort((a, b) => (b.rssi ?? -127).compareTo(a.rssi ?? -127));
        const clockLanguage = String.fromEnvironment(
          'U19_ACCEPTANCE_CLOCK_LANGUAGE',
        );
        const measure = bool.fromEnvironment('U19_ACCEPTANCE_MEASUREMENTS');
        final authorizedWatches = watches
            .where((candidate) => candidate.name == 'U19S_SD_2765')
            .toList();
        if (clockLanguage.isNotEmpty) {
          expect(
            authorizedWatches,
            hasLength(1),
            reason:
                'Only the uniquely verified, user-authorized watch may be calibrated.',
          );
        }
        final watch = clockLanguage.isEmpty
            ? watches.first
            : authorizedWatches.single;
        final timer = Stopwatch()..start();
        if (app.connectedDevice?.id != watch.id) {
          await app.connectDevice(watch).timeout(const Duration(seconds: 90));
        }
        expect(app.connectedDevice?.id, watch.id);
        proof['watchName'] = app.connectedDevice?.name;
        proof['connectedSeconds'] = timer.elapsedMilliseconds / 1000;
        proof['firmwareRead'] =
            app.connectedDevice?.firmwareVersion?.isNotEmpty == true;
        expect(app.capabilities, isNotNull);
        proof['metrics'] = app.capabilities!.metrics
            .map((m) => m.wireName)
            .toList();
        proof['manualMetrics'] = app.capabilities!.manualMetrics
            ?.map((m) => m.wireName)
            .toList();
        proof['features'] = app.visibleDeviceFeatures
            .map((f) => f.wireName)
            .toList();
        while (app.isDeviceSyncing) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        final before = <DeviceFeature, Map<String, Object?>>{};
        for (final feature in [
          DeviceFeature.healthMonitoring,
          DeviceFeature.basicSettings,
          DeviceFeature.screenDisplay,
        ]) {
          if (app.availabilityFor(feature).isReady) {
            before[feature] = await app.readDeviceFeature(feature);
            if (before[feature]!.isEmpty) {
              settingsFailures.add(
                '${feature.wireName}: initial read unavailable',
              );
            }
          }
        }
        if (clockLanguage.isNotEmpty) {
          expect(
            clockLanguage,
            'zh',
            reason: 'This test has authorization for Simplified Chinese only.',
          );
          final root = await getApplicationSupportDirectory();
          final receipt = File(
            '${root.path}/u19-time-adjustment-20261110.json',
          );
          final scope = sha256
              .convert(utf8.encode('$owner\u0000${watch.id}'))
              .toString();
          final prior = await receipt.exists()
              ? jsonDecode(await receipt.readAsString()) as Map
              : null;
          if (prior != null) {
            expect(prior['scope'], scope);
            expect(
              prior['acknowledged'],
              true,
              reason: 'An ambiguous time write must never be replayed.',
            );
            proof['clockAlreadyAdjusted'] = true;
          } else {
            await receipt.writeAsString(
              jsonEncode({
                'scope': scope,
                'attempted': true,
                'acknowledged': false,
              }),
              flush: true,
            );
            final accepted = await app.writeDeviceFeature(
              DeviceFeature.basicSettings,
              {'syncTime': clockLanguage},
            );
            proof['settingsWritten'] = true;
            proof['authorizedSettings'] = ['watchTime', 'watchLanguage=zh'];
            expect(accepted, true);
            await receipt.writeAsString(
              jsonEncode({
                'scope': scope,
                'attempted': true,
                'acknowledged': true,
              }),
              flush: true,
            );
          }
        }
        final sync = Stopwatch()..start();
        proof['syncCompleted'] = await app.syncDeviceData().timeout(
          const Duration(seconds: 100),
        );
        proof['syncSeconds'] = sync.elapsedMilliseconds / 1000;
        proof['syncStatus'] = app.syncStatus;
        proof['syncError'] = app.errorMessage;
        proof['ringInitializationPending'] = app.isRingInitializationPending;
        proof['syncPreparing'] = app.isDeviceSyncPreparing;
        proof['activeSport'] = app.activeSport?.wireName;
        proof['historyCapability'] = app.capabilities?.supportsHistorySync;
        proof['u19GrantActive'] = app.healthReleasePolicy.u19Features?.active;
        proof['settingsRead'] = before.keys.map((f) => f.wireName).toList();
        for (final entry in before.entries) {
          final after = Map<String, Object?>.from(
            await app.readDeviceFeature(entry.key),
          );
          final expected = Map<String, Object?>.from(entry.value);
          if (after.isEmpty && expected.isNotEmpty) {
            // 继续采集重连/测量证据，末尾仍严格判失败；无回包不等于设置已变更。
            settingsFailures.add('${entry.key.wireName}: readback unavailable');
            proof['settingsReadbackState'] = {
              'feature': entry.key.wireName,
              'availability': app.availabilityFor(entry.key).status.name,
              'connected': app.connectedDevice?.id == watch.id,
              'message': app.errorMessage,
            };
            continue;
          }
          if (clockLanguage.isNotEmpty &&
              entry.key == DeviceFeature.basicSettings) {
            expected.remove('timeLanguage');
            after.remove('timeLanguage');
          }
          expect(
            after,
            expected,
            reason: 'Read-only synchronization must retain settings.',
          );
        }
        proof['settingsRetained'] = settingsFailures.isEmpty;
        proof['settingsFailures'] = settingsFailures;
        proof['sameAccount'] = app.session?.accountKey == owner;
        expect(proof['sameAccount'], true);
        expect(app.connectedDevice?.id, watch.id);
        app.selectTab(1);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const Key('device-sync-data')), findsOneWidget);
        proof['syncButtonVisible'] = true;
        await save();
        if (clockLanguage.isNotEmpty) {
          expect(
            proof['syncCompleted'],
            true,
            reason: 'Connection alone does not prove history synchronization.',
          );
        }
        final reconnect = Stopwatch()..start();
        await app.reconnectDevice().timeout(const Duration(seconds: 75));
        proof['reconnectStatus'] = app.sdkStatus;
        proof['reconnectError'] = app.errorMessage;
        await save();
        expect(app.connectedDevice?.id, watch.id);
        proof['cachedReconnectSeconds'] = reconnect.elapsedMilliseconds / 1000;
        final stable = Stopwatch()..start();
        while (stable.elapsed < const Duration(seconds: 60)) {
          await Future<void>.delayed(const Duration(seconds: 2));
          expect(app.connectedDevice?.id, watch.id);
          expect(app.session?.accountKey, owner);
        }
        proof['stationaryForegroundSeconds'] = stable.elapsed.inSeconds;
        if (measure) {
          await app.refreshReadOnlyHealthFeatures();
          await app.refreshDeviceCapabilities();
          expect(app.healthReleasePolicy.u19Features?.active, true);
          final checks = <String, Object?>{};
          for (final metric in [
            HealthMetric.bloodPressure,
            HealthMetric.heartRate,
            HealthMetric.bloodOxygen,
          ]) {
            expect(
              app.capabilities?.supportsManualMeasurement(metric),
              true,
              reason: 'Only verify actual supported watch metrics.',
            );
            while (app.isDeviceSyncing) {
              await Future<void>.delayed(const Duration(milliseconds: 250));
            }
            final started = DateTime.now().toUtc();
            expect(await app.startMeasurement(metric), true);
            final wait = Stopwatch()..start();
            while (app.activeMeasurementMetric != null &&
                wait.elapsed < const Duration(seconds: 160)) {
              await Future<void>.delayed(const Duration(seconds: 1));
            }
            final result = app.measurementResult;
            final valid =
                result != null &&
                result.metric == metric &&
                result.deviceId == watch.id &&
                !result.measuredAt.isBefore(
                  started.subtract(const Duration(seconds: 2)),
                );
            checks[metric.wireName] = {
              'freshResult': valid,
              'seconds': wait.elapsed.inSeconds,
            };
            proof['measurements'] = checks;
            await save();
            expect(
              valid,
              true,
              reason:
                  'A start acknowledgement or an old record is not a new reading.',
            );
            final local = await app.loadHealthRecords(
              metric: metric,
              start: started.subtract(const Duration(minutes: 1)),
              end: DateTime.now().toUtc().add(const Duration(minutes: 1)),
            );
            expect(local.any((record) => record.id == result!.id), true);
            await app.synchronizeCloud();
            final api = GlobalSaydianApiClient(
              SecureSessionVault.global(),
              healthReadPolicyOverride: app.healthReleasePolicy,
            );
            HealthRecord? remote;
            for (var attempt = 0; attempt < 5 && remote == null; attempt++) {
              final page = await api.getCloudHealthRecords();
              for (final record in page.records) {
                if (record.id == result!.id) remote = record;
              }
              if (remote == null) {
                await Future<void>.delayed(const Duration(seconds: 2));
              }
            }
            final cloudMatches =
                remote != null &&
                remote.metric == result!.metric &&
                remote.deviceId == result.deviceId &&
                remote.unit == result.unit &&
                remote.values.length == result.values.length &&
                result.values.entries.every(
                  (entry) => remote!.values[entry.key] == entry.value,
                ) &&
                remote.measuredAt == result.measuredAt &&
                remote.sourceVendor == 'urion' &&
                remote.sourceDeviceCategory == 'watch';
            checks[metric.wireName] = {
              'freshResult': true,
              'localSaved': true,
              'cloudReadbackMatches': cloudMatches,
              'seconds': wait.elapsed.inSeconds,
            };
            await save();
            expect(cloudMatches, true);
          }
        }
        await save();
        expect(
          settingsFailures,
          isEmpty,
          reason: 'Settings preservation requires complete readback.',
        );
        proof['status'] = measure
            ? 'connection, settings, history and fresh measurement cloud readback passed'
            : 'connection, settings and history passed; new measurements pending';
        await save();
      } catch (error) {
        proof['status'] = 'incomplete';
        proof['failureType'] = error.runtimeType.toString();
        await save();
        rethrow;
      }
    },
    timeout: const Timeout(Duration(minutes: 14)),
  );
}
