import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

/// 用户明确要求在 XR 选择 R7y。只选本轮真实发现的唯一目标；不解绑、
/// 不恢复出厂、不修改监测或提醒。必须先证明既有账号绑定历史可保留。
/// 用已验签 Profile + preserving runner 执行，结束后恢复普通主程序。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'XR explicitly selected R7y connection and sync',
    (tester) async {
      final app = AppController.production();
      final proof = <String, Object?>{'model': 'R7y', 'build': 1275};
      final private = <String, Object?>{};
      final total = Stopwatch()..start();
      String? owner;
      String? selectedId;
      final documents = await getApplicationDocumentsDirectory();
      final report = File('${documents.path}/r7y-1275-acceptance-private.json');
      // 重跑时沿用上轮真实选中的标识，避免同名新设备替代本轮目标。
      String? expectedTargetId;
      if (await report.exists()) {
        final previous = jsonDecode(await report.readAsString());
        final selected = previous is Map ? previous['selectedTarget'] : null;
        if (selected is Map && selected['id'] is String) {
          expectedTargetId = selected['id'] as String;
        }
      }
      // 只旁观真实原生通道：原消息、原回包逐字节透传，不伪造 SDK 成功。
      // 仅记录方法名、耗时和错误码，不保存参数、健康值或设备标识。
      final nativeCommands = <Map<String, Object?>>[];
      proof['nativeCommands'] = nativeCommands;
      const channel = 'cc.saidian.ring/commands';
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      expect(messenger.checkMockMessageHandler(channel, null), isTrue);
      messenger.setMockMessageHandler(channel, (message) async {
        if (message == null) return messenger.delegate.send(channel, message);
        final method = codec.decodeMethodCall(message).method;
        final callClock = Stopwatch()..start();
        final trace = <String, Object?>{
          'method': method,
          'startedAtMs': total.elapsedMilliseconds,
        };
        nativeCommands.add(trace);
        try {
          final reply = await messenger.delegate.send(channel, message);
          trace['status'] = reply == null ? 'no_reply' : 'returned';
          if (reply != null) {
            try {
              codec.decodeEnvelope(reply);
              trace['status'] = 'ok';
            } on PlatformException catch (error) {
              trace['status'] = 'error';
              trace['code'] = error.code;
              final details = error.details;
              if (details is Map) {
                for (final key in const [
                  'handshakeCommand',
                  'nativeErrorCode',
                  'deviceInfoReceived',
                  'capabilitiesReceived',
                ]) {
                  final value = details[key];
                  if (value is String || value is num || value is bool) {
                    trace[key] = value;
                  }
                }
              }
            } on FormatException {
              trace['status'] = 'invalid_envelope';
            }
          }
          trace['appStateAtReply'] = app.deviceState.name;
          trace['appCapabilityAtReply'] = app.deviceCapabilityState.name;
          trace['selectedTargetConnectedAtReply'] =
              selectedId != null && app.connectedDevice?.id == selectedId;
          return reply;
        } finally {
          trace['durationMs'] = callClock.elapsedMilliseconds;
        }
      });
      addTearDown(() => messenger.setMockMessageHandler(channel, null));
      Future<void> save(String stage) async {
        proof['stage'] = stage;
        proof['elapsedSeconds'] = total.elapsedMilliseconds / 1000;
        binding.reportData = {'r7yAcceptance': Map.of(proof)};
        await report.writeAsString(
          jsonEncode({'proof': proof, ...private}),
          flush: true,
        );
        debugPrint('R7Y QA: $stage');
      }

      Future<void> tick() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump().timeout(const Duration(seconds: 15));
      }

      Future<void> waitFor(bool Function() ready, int seconds) async {
        final clock = Stopwatch()..start();
        while (!ready() && clock.elapsed < Duration(seconds: seconds)) {
          await tick();
        }
      }

      bool isR7y(String name) =>
          name.toUpperCase().replaceAll(RegExp(r'[\s_-]'), '').contains('R7Y');
      bool connected() =>
          selectedId != null &&
          app.connectedDevice?.id == selectedId &&
          app.deviceCapabilityState == DeviceCapabilityState.ready;
      try {
        runApp(SaydianApp(controller: app));
        await app.initialize().timeout(const Duration(seconds: 60));
        owner = app.session?.accountKey;
        expect(owner, isNotNull, reason: 'Keep the existing real member');
        expect(app.isLocalMode || app.isPreviewMode, isFalse);
        expect(
          app.rememberedDevice,
          isNotNull,
          reason: 'No first-binding initialization in data-preserving QA',
        );
        expect(app.isRingInitializationPending, isFalse);
        private['originalTarget'] = app.rememberedDevice!.toJson();
        await save('initialized');
        // 保留生产初始化以读取原绑定，再中止旧目标的在途恢复后搜索 R7y。
        await app.disconnectDevice().timeout(const Duration(seconds: 30));
        app.selectTab(1);
        await tick();
        final scans = <Map<String, Object?>>[];
        proof['scans'] = scans;
        DeviceInfo? target;
        for (var round = 0; round < 2 && target == null; round++) {
          await app.scanDevices().timeout(const Duration(seconds: 45));
          final matches = app.scannedDevices
              .where((d) => isR7y(d.name))
              .toList();
          scans.add({
            'count': app.scannedDevices.length,
            'matchingTargets': matches.length,
            'issue': app.deviceScanIssue?.name,
            'errorPresent': app.errorMessage != null,
          });
          private['scan$round'] = app.scannedDevices
              .map((d) => d.toJson())
              .toList();
          await app.stopDeviceScan(resumeRecovery: false);
          await save('scan-${round + 1}');
          expect(
            matches.length <= 1,
            isTrue,
            reason: 'Never choose an arbitrary ring among several R7y',
          );
          if (matches.length == 1) target = matches.single;
        }
        proof['targetFound'] = target != null;
        expect(target, isNotNull, reason: 'R7y must actually be discoverable');
        if (expectedTargetId != null) {
          expect(
            target!.id,
            expectedTargetId,
            reason: 'Repeat only the same physically selected R7y',
          );
          proof['sameTargetAsPreviousRound'] = true;
        }
        selectedId = target!.id;
        private['selectedTarget'] = target.toJson();
        final vault = SecureSessionVault.global();
        final ownerKey = app.homeHealthCardOwner;
        expect(ownerKey, isNotEmpty);
        expect(
          await vault.readRingInitializationStage(ownerKey, selectedId),
          isNull,
          reason: 'Never resume a pending destructive operation',
        );
        final api = GlobalSaydianApiClient(vault);
        final prior = await api
            .hasPriorBindingBeforeDevice(
              expectedSession: app.session!,
              deviceId: selectedId,
            )
            .timeout(const Duration(seconds: 30));
        proof['serverPriorBindingConfirmed'] = prior;
        expect(prior, isTrue, reason: 'Preserve ring data and all settings');
        await save('preservation-confirmed');
        final clock = Stopwatch()..start();
        await app.connectDevice(target).timeout(const Duration(seconds: 75));
        proof['connectionOperationSeconds'] = clock.elapsedMilliseconds / 1000;
        await waitFor(connected, 20);
        proof['connectionSeconds'] = clock.elapsedMilliseconds / 1000;
        proof['exactTargetReady'] = connected();
        private['connectionError'] = app.errorMessage;
        await save('connection-returned');
        expect(connected(), isTrue, reason: 'Actual vendor handshake required');
        expect(app.isRingInitializationPending, isFalse);
        proof['batteryRead'] = app.connectedDevice?.battery?.updatedAt != null;
        proof['supportsHistorySync'] = app.capabilities?.supportsHistorySync;
        await waitFor(() => !app.isDeviceSyncing, 130);
        proof['automaticSyncStopped'] = !app.isDeviceSyncing;
        private['automaticSyncStatus'] = app.syncStatus;
        private['automaticSyncError'] = app.errorMessage;
        await save('automatic-sync-observed');
        expect(app.isDeviceSyncing, isFalse);
        final sync = Stopwatch()..start();
        proof['manualSyncComplete'] = await app.syncDeviceData().timeout(
          const Duration(seconds: 130),
        );
        proof['manualSyncSeconds'] = sync.elapsedMilliseconds / 1000;
        private['manualSyncStatus'] = app.syncStatus;
        private['manualSyncError'] = app.errorMessage;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final start = today.subtract(const Duration(days: 7));
        final steps = (await app.loadHealthRecords(
          metric: HealthMetric.steps,
          start: start,
          end: today.add(const Duration(days: 1)),
        )).where((r) => r.deviceId == selectedId).toList();
        proof['targetActivityRecords'] = steps.length;
        proof['activityIdsUnique'] =
            steps.map((r) => r.id).toSet().length == steps.length;
        final sleeps = await app.loadSleepDays(start: start, end: today);
        proof['targetSleepDays'] = sleeps
            .where((r) => r.deviceId == selectedId)
            .length;
        private['steps'] = steps.map((r) => r.toJson()).toList();
        private['sleepDays'] = sleeps.map((r) => r.toJson()).toList();
        private['sleepReadStatuses'] = app.sleepReadStatuses;
        await save('manual-sync-observed');
        app.selectTab(0);
        await tick();
        final entry = find.byKey(const Key('home-sleep-overview-entry'));
        await tester.ensureVisible(entry);
        await tester.tap(entry.hitTestable());
        await tick();
        expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
        proof['sleepEntryAndPage'] = true;
        await binding.takeScreenshot('xr-r7y-sleep-private');
        await tester.binding.handlePopRoute();
        app.selectTab(1);
        await tick();
        await waitFor(() => !app.isDeviceSyncing, 60);
        await app.disconnectDevice().timeout(const Duration(seconds: 30));
        expect(app.rememberedDevice?.id, selectedId);
        final reconnect = Stopwatch()..start();
        await app.reconnectDevice().timeout(const Duration(seconds: 75));
        await waitFor(connected, 15);
        proof['controlledReconnectSeconds'] =
            reconnect.elapsedMilliseconds / 1000;
        proof['controlledReconnectReady'] = connected();
        await save('controlled-reconnect-observed');
        expect(connected(), isTrue);
        var disconnectedSamples = 0;
        for (var i = 0; i < 120; i++) {
          await tick();
          if (!connected()) disconnectedSamples++;
        }
        proof['foregroundObservationSeconds'] = 60;
        proof['disconnectedSamplesDuringObservation'] = disconnectedSamples;
        proof['ownerUnchanged'] = app.session?.accountKey == owner;
        proof['selectedTargetRetained'] =
            app.rememberedDevice?.id == selectedId;
        expect(proof['ownerUnchanged'], isTrue);
        expect(proof['selectedTargetRetained'], isTrue);
        expect(tester.takeException(), isNull);
        await save('finished');
      } finally {
        proof['ownerUnchanged'] =
            owner != null && app.session?.accountKey == owner;
        private['finalError'] = app.errorMessage;
        private['connectionDiagnostics'] = app.connectionDiagnostics;
        await save('final');
        app.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
