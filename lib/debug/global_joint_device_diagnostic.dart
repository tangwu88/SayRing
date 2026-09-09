import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';
import '../services/global_environment.dart';

typedef GlobalJointQaSink = void Function(Map<String, Object?> record);

void emitGlobalJointQaRecord(Map<String, Object?> record) =>
    debugPrint('[SaydianJointQA] ${jsonEncode(record)}');

bool isApprovedGlobalJointQaEnvironment(Uri origin, String prefix) =>
    origin.scheme == 'https' &&
    origin.host == 'app.saydian.cn' &&
    origin.port == 443 &&
    origin.userInfo.isEmpty &&
    !origin.hasQuery &&
    !origin.hasFragment &&
    (origin.path.isEmpty || origin.path == '/') &&
    prefix == '/global/api/saydian-app/v2';

class GlobalJointQaConfig {
  GlobalJointQaConfig._({
    required this.targetDeviceId,
    required this.deviceOnly,
    required this.safeFindWatch,
    this.username,
    this.password,
  });

  final String targetDeviceId;
  final String? username;
  final String? password;
  final bool deviceOnly;
  final bool safeFindWatch;

  factory GlobalJointQaConfig.fromJson(Map<String, Object?> value) {
    const keys = {
      'targetDeviceId',
      'username',
      'password',
      'deviceOnly',
      'safeFindWatch',
    };
    final target = value['targetDeviceId'];
    final username = value['username'];
    final password = value['password'];
    if (value.keys.any((key) => !keys.contains(key)) ||
        target is! String ||
        target.length > 200 ||
        !RegExp(r'^(veepoo|yucheng):[^\s\x00-\x1f]+$').hasMatch(target) ||
        (value.containsKey('deviceOnly') && value['deviceOnly'] is! bool) ||
        (value.containsKey('safeFindWatch') &&
            value['safeFindWatch'] is! bool) ||
        (username != null &&
            (username is! String ||
                username.trim().isEmpty ||
                username.length > 254)) ||
        (password != null &&
            (password is! String ||
                password.isEmpty ||
                password.length > 512)) ||
        ((username == null) != (password == null)) ||
        (value['deviceOnly'] == true && username != null)) {
      throw const FormatException('Invalid private QA configuration');
    }
    return GlobalJointQaConfig._(
      targetDeviceId: target,
      username: username as String?,
      password: password as String?,
      deviceOnly: value['deviceOnly'] == true,
      safeFindWatch: value['safeFindWatch'] == true,
    );
  }
}

class GlobalJointQaTiming {
  const GlobalJointQaTiming({
    this.operation = const Duration(seconds: 75),
    this.sync = const Duration(minutes: 4),
    this.poll = const Duration(milliseconds: 250),
    this.betweenConnections = const Duration(seconds: 2),
  });
  final Duration operation;
  final Duration sync;
  final Duration poll;
  final Duration betweenConnections;
}

Future<GlobalJointQaConfig?> _readPrivateConfig() async {
  final directory = await getApplicationSupportDirectory();
  final file = File(path.join(directory.path, 'global-joint-qa.json'));
  if (!await file.exists()) return null;
  if (await file.length() > 8192) {
    throw const FormatException('QA config too large');
  }
  final content = await file.readAsString();
  final decoded = jsonDecode(content.replaceFirst(RegExp(r'^\uFEFF'), ''));
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Invalid QA config');
  }
  return GlobalJointQaConfig.fromJson(decoded);
}

/// Three bounded exact-target connect/read/sync cycles. Never starts a
/// measurement, changes settings, installs faces, invokes camera, or performs OTA.
Future<void> runGlobalJointDeviceDiagnostic(
  AppController controller, {
  Future<GlobalJointQaConfig?> Function()? readConfig,
  GlobalJointQaSink? log,
  GlobalJointQaTiming timing = const GlobalJointQaTiming(),
}) async {
  final sink = log ?? emitGlobalJointQaRecord;
  if (kReleaseMode ||
      !isApprovedGlobalJointQaEnvironment(
        GlobalEnvironment.configuredOrigin,
        GlobalEnvironment.apiPrefix,
      )) {
    sink({
      'case': 'configuration',
      'status': 'skipped',
      'reason': 'unapproved_build_environment',
    });
    return;
  }
  GlobalJointQaConfig? config;
  try {
    config = await (readConfig ?? _readPrivateConfig)().timeout(
      const Duration(seconds: 5),
    );
  } catch (error) {
    sink({
      'case': 'configuration',
      'status': 'failed',
      'reason': error.runtimeType.toString(),
    });
    return;
  }
  if (config == null) {
    sink({
      'case': 'configuration',
      'status': 'skipped',
      'reason': 'private_config_missing',
    });
    return;
  }
  await _GlobalJointDeviceDiagnostic(controller, config, sink, timing).run();
}

class _GlobalJointDeviceDiagnostic {
  _GlobalJointDeviceDiagnostic(
    this.controller,
    this.config,
    this.sink,
    this.timing,
  );
  final AppController controller;
  final GlobalJointQaConfig config;
  final GlobalJointQaSink sink;
  final GlobalJointQaTiming timing;
  final Map<String, int> _counts = {};
  String? _account;
  bool _contextLocked = false;
  int _completedRounds = 0;

  void _record(
    String name,
    String status, {
    String? reason,
    int? round,
    Map<String, Object?> details = const {},
  }) {
    _counts[status] = (_counts[status] ?? 0) + 1;
    sink({
      'case': name,
      'status': status,
      'reason': ?reason,
      'round': ?round,
      ...details,
    });
  }

  String? get _currentAccount => controller.session == null
      ? null
      : '${controller.session!.memberId}\u0000${controller.session!.accountKey}';

  void _assertSafeContext() {
    if (_contextLocked && _account != _currentAccount) {
      throw const _QaAbort('account_changed');
    }
    if (controller.activeMeasurementMetric != null ||
        controller.activeSport != null) {
      throw const _QaAbort('user_device_operation_active');
    }
    final current = controller.connectedDevice;
    if (current != null && current.id != config.targetDeviceId) {
      throw const _QaAbort('another_device_connected');
    }
  }

  Future<T> _bounded<T>(
    String name,
    Future<T> Function() action, {
    Duration? timeout,
    int? round,
  }) async {
    _assertSafeContext();
    final elapsed = Stopwatch()..start();
    try {
      final result = await action().timeout(timeout ?? timing.operation);
      _assertSafeContext();
      _record(
        name,
        'observed',
        round: round,
        details: {'elapsedMs': elapsed.elapsedMilliseconds},
      );
      return result;
    } catch (error) {
      _record(
        name,
        'failed',
        reason: error is _QaAbort ? error.reason : error.runtimeType.toString(),
        round: round,
        details: {'elapsedMs': elapsed.elapsedMilliseconds},
      );
      // A timeout does not cancel native work. Abort, never enqueue the next
      // operation or a speculative disconnect while that work may still run.
      throw const _QaAbort('operation_failed_or_unsettled');
    }
  }

  Future<void> _settle(int round) => _bounded(
    'device_queue_settled',
    () async {
      final elapsed = Stopwatch()..start();
      while (true) {
        if (elapsed.elapsed >= timing.sync) {
          throw TimeoutException('Device work did not settle');
        }
        _assertSafeContext();
        if (!controller.isDeviceSyncing &&
            !controller.isDeviceSettingsLoading &&
            controller.deviceFeatureBusy.isEmpty &&
            !controller.isBusy) {
          break;
        }
        await Future<void>.delayed(timing.poll);
      }
    },
    timeout: timing.sync + timing.poll,
    round: round,
  );

  Future<void> run() async {
    final stateSubscription = controller.deviceMachine.changes.listen((state) {
      _record('connection_state', 'observed', details: {'state': state.name});
    });
    _record(
      'suite_start',
      'observed',
      details: {'deviceOnly': config.deviceOnly, 'plannedRounds': 3},
    );
    try {
      _assertSafeContext();
      if (config.deviceOnly) {
        if (controller.isAuthenticated) {
          throw const _QaAbort('device_only_requires_signed_out');
        }
        controller.enterPreview();
        _record(
          'cloud_acceptance',
          'not_verified',
          reason: 'device_only_guest_no_cloud_session',
        );
      } else {
        if (config.username == null || config.password == null) {
          throw const _QaAbort('dedicated_test_credentials_missing');
        }
        // The production parser rejects any capabilities realm other than global.
        await _bounded(
          'global_realm_capabilities',
          controller.globalAuthCapabilities,
        );
        _record('global_realm', 'passed');
        final loggedIn = await _bounded(
          'test_account_login',
          () => controller.login(config.username!, config.password!),
        );
        if (!loggedIn || !controller.isAuthenticated) {
          throw const _QaAbort('test_account_login_not_confirmed');
        }
        _record('test_account_session', 'passed');
      }
      _account = _currentAccount;
      _contextLocked = true;
      controller.selectTab(1);
      for (var round = 1; round <= 3; round++) {
        await _settle(round);
        if (controller.connectedDevice != null) await _disconnect(round);
        controller.clearError();
        await _bounded(
          'exact_target_scan',
          controller.scanDevices,
          round: round,
        );
        final matches = controller.scannedDevices
            .where((device) => device.id == config.targetDeviceId)
            .toList();
        _record(
          'target_discovery',
          matches.length == 1 ? 'passed' : 'failed',
          round: round,
          details: {
            'visibleCount': controller.scannedDevices.length,
            'exactMatchCount': matches.length,
            'errorPresent': controller.errorMessage != null,
          },
        );
        if (matches.length != 1) {
          throw const _QaAbort('exact_target_not_uniquely_found');
        }
        controller.clearError();
        await _bounded(
          'connect_command',
          () => controller.connectDevice(matches.single),
          round: round,
        );
        if (controller.connectedDevice?.id != config.targetDeviceId ||
            controller.deviceState != DeviceConnectionState.ready) {
          _record(
            'connection_readiness',
            'failed',
            round: round,
            details: {
              'state': controller.deviceState.name,
              'capabilityState': controller.deviceCapabilityState.name,
              'errorPresent': controller.errorMessage != null,
              'connectedToTarget':
                  controller.connectedDevice?.id == config.targetDeviceId,
            },
          );
          throw const _QaAbort('target_connection_not_ready');
        }
        _record('target_connected', 'passed', round: round);
        await _settle(round);
        _record(
          'initial_sync_result',
          controller.errorMessage == null ? 'observed' : 'failed',
          round: round,
          details: {
            'cachedRecordCount': controller.healthRecords.length,
            'errorPresent': controller.errorMessage != null,
          },
        );
        await _readDetails(round);
        controller.clearError();
        final before = controller.healthRecords.length;
        await _bounded(
          'manual_device_sync',
          controller.syncDeviceData,
          timeout: timing.sync,
          round: round,
        );
        await _settle(round);
        _record(
          'device_sync_result',
          controller.errorMessage == null ? 'passed' : 'failed',
          round: round,
          details: {
            'cachedRecordsBefore': before,
            'cachedRecordsAfter': controller.healthRecords.length,
            'nonemptyCache': controller.healthRecords.isNotEmpty,
            'errorPresent': controller.errorMessage != null,
          },
        );
        if (controller.healthRecords.isEmpty) {
          _record(
            'health_samples',
            'not_verified',
            reason: 'no_nonempty_sample',
            round: round,
          );
        }
        _record(
          'pending_upload_count',
          'not_verified',
          reason: 'controller_does_not_expose_store_count',
          round: round,
        );
        _completedRounds++;
      }
      await _readFeatures();
      if (config.safeFindWatch &&
          controller.visibleDeviceFeatures.contains(DeviceFeature.findWatch)) {
        controller.clearError();
        final started = await _bounded(
          'find_watch_start',
          () => controller.triggerDeviceAction(DeviceFeature.findWatch),
        );
        await Future<void>.delayed(const Duration(seconds: 2));
        final stopped = await _bounded(
          'find_watch_stop',
          () => controller.triggerDeviceAction(
            DeviceFeature.findWatch,
            enabled: false,
          ),
        );
        _record(
          'find_watch_acknowledgement',
          started && stopped ? 'passed' : 'failed',
          reason: 'physical_response_requires_observer',
        );
      } else {
        _record(
          'find_watch',
          'skipped',
          reason: config.safeFindWatch
              ? 'not_exposed_for_current_device'
              : 'not_requested',
        );
      }
      if (!config.deviceOnly) {
        await _bounded(
          'cloud_sync_attempt',
          controller.synchronizeCloud,
          timeout: timing.sync,
        );
        _record(
          'cloud_upload_and_readback',
          'not_verified',
          reason: 'server_readback_required_no_public_result_contract',
        );
      }
      _record(
        'final_connection',
        controller.connectedDevice?.id == config.targetDeviceId
            ? 'passed'
            : 'failed',
        details: {'connected': controller.connectedDevice != null},
      );
    } on _QaAbort catch (error) {
      _record('suite_abort', 'failed', reason: error.reason);
    } catch (error) {
      _record('suite_abort', 'failed', reason: error.runtimeType.toString());
    } finally {
      await stateSubscription.cancel();
      sink({
        'case': 'suite_complete',
        'status': (_counts['failed'] ?? 0) == 0 ? 'partial' : 'failed',
        'completedRounds': _completedRounds,
        'counts': Map<String, int>.from(_counts),
        'connectedToTarget':
            controller.connectedDevice?.id == config.targetDeviceId,
        'cloudAccepted': false,
      });
    }
  }

  Future<void> _disconnect(int round) async {
    await _settle(round);
    await _bounded(
      'disconnect_command',
      controller.disconnectDevice,
      round: round,
    );
    if (controller.connectedDevice != null ||
        controller.deviceState != DeviceConnectionState.disconnected) {
      throw const _QaAbort('disconnect_not_confirmed');
    }
    _record('target_disconnected', 'passed', round: round);
    await Future<void>.delayed(timing.betweenConnections);
  }

  Future<void> _readDetails(int round) async {
    controller.clearError();
    final refreshed = await _bounded(
      'device_details_read',
      controller.refreshConnectedDeviceDetails,
      round: round,
    );
    _record(
      'device_details_result',
      refreshed ? 'passed' : 'failed',
      round: round,
    );
    final capabilities = controller.capabilities;
    final resolved =
        capabilities != null &&
        controller.deviceCapabilityState == DeviceCapabilityState.ready;
    _record(
      'capabilities',
      resolved ? 'passed' : 'failed',
      round: round,
      details: {
        'hardwareFeatureCount': capabilities?.features.length ?? 0,
        'visibleFeatureCount': controller.visibleDeviceFeatures.length,
        'metricCount': capabilities?.metrics.length ?? 0,
      },
    );
    final battery = controller.connectedDevice?.effectiveBattery;
    _record(
      'battery',
      battery != null ? 'passed' : 'not_verified',
      round: round,
      details: {
        'available': battery != null,
        'percentScale': battery?.isPercent ?? false,
      },
    );
  }

  Future<void> _readFeatures() async {
    for (final feature in DeviceFeature.values) {
      final name = 'feature_${feature.wireName}';
      if (!controller.visibleDeviceFeatures.contains(feature)) {
        _record(name, 'skipped', reason: 'not_exposed_for_current_device');
        continue;
      }
      if (feature == DeviceFeature.findWatch ||
          feature == DeviceFeature.camera) {
        _record(name, 'skipped', reason: 'action_only_no_read_command');
        continue;
      }
      controller.clearError();
      if (feature == DeviceFeature.healthMonitoring) {
        await _bounded(name, controller.refreshDeviceSettings);
        _record(
          '${name}_result',
          'not_verified',
          reason: 'public_settings_api_has_no_success_result',
          details: {
            'monitorItemCount': controller.autoMeasureSettings.length,
            'intervalItemCount': controller.autoMeasureIntervals.length,
          },
        );
        continue;
      }
      final data = await _bounded(
        name,
        () => controller.readDeviceFeature(feature),
      );
      _record(
        '${name}_result',
        controller.errorMessage != null
            ? 'failed'
            : data.isEmpty
            ? 'not_verified'
            : 'passed',
        details: {
          'responseFieldCount': data.length,
          'errorPresent': controller.errorMessage != null,
        },
      );
    }
  }
}

class _QaAbort implements Exception {
  const _QaAbort(this.reason);
  final String reason;
}
