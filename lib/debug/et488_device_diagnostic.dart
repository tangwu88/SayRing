import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import '../services/app_controller.dart';

/// Opt-in ET488 physical-device regression runner for tethered debug builds.
///
/// Enable with `--dart-define=SAYDIAN_ET488_QA_AUTORUN=true`. It never changes
/// settings, installs a watch face, starts OTA, or deletes data. Structured log
/// output deliberately excludes account details and measured health values.
Future<void> runEt488DeviceDiagnostic(AppController controller) async {
  if (!kDebugMode) return;
  await _Et488DeviceDiagnostic(controller).run();
}

class _Et488DeviceDiagnostic {
  _Et488DeviceDiagnostic(this.controller);

  final AppController controller;

  static const _manualMetrics = <HealthMetric>[
    HealthMetric.ecg,
    HealthMetric.heartRate,
    HealthMetric.bloodOxygen,
    HealthMetric.bloodPressure,
    HealthMetric.bodyTemperature,
    HealthMetric.bloodGlucose,
    HealthMetric.bodyComposition,
    HealthMetric.bloodComposition,
  ];

  static const _safeReadableFeatures = <DeviceFeature>{
    DeviceFeature.watchFaces,
    DeviceFeature.photoWatchFace,
    DeviceFeature.camera,
    DeviceFeature.phoneCalls,
    DeviceFeature.contacts,
    DeviceFeature.notifications,
    DeviceFeature.alarms,
    DeviceFeature.weather,
    DeviceFeature.worldClock,
    DeviceFeature.healthReminders,
    DeviceFeature.healthAssessment,
    DeviceFeature.screenDisplay,
  };

  Future<void> run() async {
    _log('suite_start', true, {'platform': defaultTargetPlatform.name});
    try {
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!await _connectEt488()) {
        _log('suite_complete', false, {'reason': 'et488_not_connected'});
        return;
      }
      await _waitForInitialSync();
      await _verifyDeviceDetailsAndBattery();
      await _verifyCapabilities();
      await _verifyHealthSync();
      await _verifyDeviceSettingsRead();
      await _verifyReadableFeatures();
      await _verifyFindWatch();
      await _verifyCameraRemote();
      await _verifyMeasurements();
      await _verifySport();
      await _verifyReconnect();
      _log('suite_complete', controller.connectedDevice != null, {
        'state': controller.deviceState.name,
        'connected': controller.connectedDevice != null,
      });
    } catch (error, stackTrace) {
      _log('suite_complete', false, {
        'error': _safeError(error),
        'stack': stackTrace.toString().split('\n').take(3).join(' | '),
      });
    }
  }

  Future<bool> _connectEt488() async {
    final current = controller.connectedDevice;
    if (current != null && _isEt488(current)) {
      _log('connect', true, _deviceSummary(current));
      return true;
    }
    if (current != null) {
      _log('disconnect_other_device', true, {'name': current.name});
      await controller.disconnectDevice();
    }
    for (var attempt = 1; attempt <= 3; attempt++) {
      controller.clearError();
      await controller.scanDevices();
      final matches = controller.scannedDevices.where(_isEt488).toList()
        ..sort(
          (left, right) => (right.rssi ?? -999).compareTo(left.rssi ?? -999),
        );
      _log('scan', matches.isNotEmpty, {
        'attempt': attempt,
        'found': matches.length,
        'visibleDevices': controller.scannedDevices.length,
        if (controller.errorMessage != null) 'error': controller.errorMessage,
      });
      if (matches.isEmpty) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      await controller.connectDevice(matches.first);
      final ready = await _waitUntil(
        () =>
            controller.connectedDevice != null &&
            controller.deviceState != DeviceConnectionState.connecting &&
            controller.deviceState != DeviceConnectionState.authenticating,
        const Duration(seconds: 45),
      );
      final device = controller.connectedDevice;
      final success = ready && device != null && _isEt488(device);
      _log('connect', success, {
        if (device != null) ..._deviceSummary(device),
        'state': controller.deviceState.name,
        if (controller.errorMessage != null) 'error': controller.errorMessage,
      });
      if (success) return true;
    }
    return false;
  }

  Future<void> _waitForInitialSync() async {
    final settled = await _waitUntil(
      () => !controller.isDeviceSyncing,
      const Duration(seconds: 90),
    );
    _log('initial_sync', settled && controller.connectedDevice != null, {
      'status': controller.syncStatus,
      'records': controller.healthRecords.length,
      'connected': controller.connectedDevice != null,
      if (controller.errorMessage != null) 'error': controller.errorMessage,
    });
  }

  Future<void> _verifyDeviceDetailsAndBattery() async {
    var refreshed = false;
    DeviceBatteryInfo? battery;
    for (var attempt = 1; attempt <= 4; attempt++) {
      controller.clearError();
      refreshed = await controller.refreshConnectedDeviceDetails();
      battery = controller.connectedDevice?.effectiveBattery;
      if (battery != null) break;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    final device = controller.connectedDevice;
    _log('device_details', refreshed && device != null, {
      if (device != null) ..._deviceSummary(device),
      if (controller.errorMessage != null) 'error': controller.errorMessage,
    });
    _log('battery', battery != null, {
      if (battery != null) ...{
        'display': battery.displayLabel,
        'scale': battery.scale,
        'isPercent': battery.isPercent,
        'charging': battery.isCharging,
        'low': battery.isLow,
      },
      if (battery == null) 'reason': 'no_value_after_refresh',
    });
  }

  Future<void> _verifyCapabilities() async {
    controller.clearError();
    final refreshed = await controller.refreshDeviceCapabilities();
    final capabilities = controller.capabilities;
    _log('capabilities', refreshed && capabilities != null, {
      'state': controller.deviceCapabilityState.name,
      if (capabilities != null) ...{
        'metrics': _sorted(capabilities.metrics.map((e) => e.wireName)),
        'manualMetrics': _sorted(
          capabilities.manualMetrics?.map((e) => e.wireName) ?? const [],
        ),
        'features': _sorted(capabilities.features.map((e) => e.wireName)),
        'integratedFeatures': _sorted(
          capabilities.integratedFeatures.map((e) => e.wireName),
        ),
        'sportModes': _sorted(
          capabilities.sportModes?.map((e) => e.wireName) ?? const [],
        ),
      },
      if (controller.errorMessage != null) 'error': controller.errorMessage,
    });
  }

  Future<void> _verifyHealthSync() async {
    controller.clearError();
    final before = controller.healthRecords.length;
    await controller.syncDeviceData();
    final settled = await _waitUntil(
      () => !controller.isDeviceSyncing,
      const Duration(seconds: 90),
    );
    _log(
      'health_sync',
      settled &&
          controller.connectedDevice != null &&
          !controller.syncStatus.contains('失败'),
      {
        'status': controller.syncStatus,
        'recordsBefore': before,
        'recordsAfter': controller.healthRecords.length,
        if (controller.errorMessage != null) 'error': controller.errorMessage,
      },
    );
  }

  Future<void> _verifyDeviceSettingsRead() async {
    controller.clearError();
    try {
      await controller.refreshDeviceSettings().timeout(
        const Duration(seconds: 30),
      );
      _log('device_settings_read', controller.connectedDevice != null, {
        'status': controller.deviceSettingsStatus,
        'autoMeasureItems': controller.autoMeasureSettings.length,
        'intervalItems': controller.autoMeasureIntervals.length,
        'heartWarningSupported': controller.heartRateWarningSupported,
        if (controller.errorMessage != null) 'error': controller.errorMessage,
      });
    } on TimeoutException {
      _log('device_settings_read', false, {'error': 'timeout'});
    }
  }

  Future<void> _verifyReadableFeatures() async {
    final visible = controller.visibleDeviceFeatures;
    for (final feature in DeviceFeature.values) {
      if (!visible.contains(feature) ||
          !_safeReadableFeatures.contains(feature)) {
        continue;
      }
      controller.clearError();
      try {
        final value = await controller
            .readDeviceFeature(feature)
            .timeout(const Duration(seconds: 45));
        _log(
          'feature_read_${feature.wireName}',
          controller.errorMessage == null,
          {
            'keys': _sorted(value.keys),
            if (controller.errorMessage != null)
              'error': controller.errorMessage,
          },
        );
      } on TimeoutException {
        _log('feature_read_${feature.wireName}', false, {'error': 'timeout'});
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _verifyFindWatch() async {
    if (!controller.visibleDeviceFeatures.contains(DeviceFeature.findWatch)) {
      _log('find_watch', true, {'status': 'unsupported_not_exposed'});
      return;
    }
    controller.clearError();
    final started = await controller.triggerDeviceAction(
      DeviceFeature.findWatch,
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    final stopped = await controller.triggerDeviceAction(
      DeviceFeature.findWatch,
      enabled: false,
    );
    _log('find_watch', started && stopped, {
      'started': started,
      'stopped': stopped,
      if (controller.errorMessage != null) 'error': controller.errorMessage,
    });
  }

  Future<void> _verifyCameraRemote() async {
    if (!controller.visibleDeviceFeatures.contains(DeviceFeature.camera)) {
      _log('camera_remote', true, {'status': 'unsupported_not_exposed'});
      return;
    }
    controller.clearError();
    final started = await controller.triggerDeviceAction(DeviceFeature.camera);
    await Future<void>.delayed(const Duration(seconds: 2));
    final stopped = await controller.triggerDeviceAction(
      DeviceFeature.camera,
      enabled: false,
    );
    _log('camera_remote', started && stopped, {
      'started': started,
      'stopped': stopped,
      'shutterEvents': controller.cameraShutterSequence,
      if (controller.errorMessage != null) 'error': controller.errorMessage,
    });
  }

  Future<void> _verifyMeasurements() async {
    final capabilities = controller.capabilities;
    if (capabilities == null) return;
    for (final metric in _manualMetrics) {
      if (!capabilities.supportsManualMeasurement(metric)) continue;
      controller.clearError();
      final recordsBefore = controller.healthRecords
          .where((record) => record.metric == metric)
          .length;
      final started = await controller.startMeasurement(metric);
      var maximumProgress = controller.measurementProgress;
      var maximumSamples = controller.measurementSamples.length;
      var stayedConnected = controller.connectedDevice != null;
      final duration = metric == HealthMetric.ecg
          ? const Duration(seconds: 25)
          : metric == HealthMetric.bloodPressure
          ? const Duration(seconds: 18)
          : const Duration(seconds: 10);
      if (started) {
        final deadline = DateTime.now().add(duration);
        while (DateTime.now().isBefore(deadline) &&
            controller.activeMeasurementMetric == metric) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          maximumProgress = maximumProgress < controller.measurementProgress
              ? controller.measurementProgress
              : maximumProgress;
          maximumSamples = maximumSamples < controller.measurementSamples.length
              ? controller.measurementSamples.length
              : maximumSamples;
          stayedConnected =
              stayedConnected && controller.connectedDevice != null;
        }
      }
      final completedNaturally = controller.activeMeasurementMetric != metric;
      if (controller.activeMeasurementMetric == metric) {
        await controller.stopMeasurement(metric);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      final recordsAfter = controller.healthRecords
          .where((record) => record.metric == metric)
          .length;
      _log('measurement_${metric.wireName}', started && stayedConnected, {
        'started': started,
        'stayedConnected': stayedConnected,
        'completedNaturally': completedNaturally,
        'recordAdded': recordsAfter > recordsBefore,
        'maximumProgress': maximumProgress,
        'waveformSamples': maximumSamples,
        'wearConfirmed': controller.measurementWearConfirmed,
        if (controller.errorMessage != null) 'error': controller.errorMessage,
      });
      if (controller.connectedDevice == null) return;
    }
  }

  Future<void> _verifySport() async {
    controller.clearError();
    final before = controller.sportRecords.length;
    await controller.refreshSportRecords();
    final modes = controller.availableSportModes;
    if (modes.isEmpty) {
      _log('sport', true, {
        'status': 'no_app_controlled_modes_reported',
        'historyRecords': controller.sportRecords.length,
        if (controller.errorMessage != null) 'error': controller.errorMessage,
      });
      return;
    }
    final mode = modes.contains(SportMode.walking)
        ? SportMode.walking
        : modes.first;
    final started = await controller.startSport(mode);
    if (started) {
      await Future<void>.delayed(const Duration(seconds: 4));
      await controller.stopSport();
    }
    _log('sport', started && controller.connectedDevice != null, {
      'mode': mode.wireName,
      'started': started,
      'activeAfterStop': controller.activeSport?.wireName,
      'historyBefore': before,
      'historyAfter': controller.sportRecords.length,
      if (controller.errorMessage != null) 'error': controller.errorMessage,
    });
  }

  Future<void> _verifyReconnect() async {
    final current = controller.connectedDevice;
    if (current == null) {
      _log('reconnect', false, {'reason': 'already_disconnected'});
      return;
    }
    final nativeId = current.nativeId;
    await controller.disconnectDevice();
    await Future<void>.delayed(const Duration(seconds: 2));
    DeviceInfo? rediscovered;
    for (var attempt = 1; attempt <= 3 && rediscovered == null; attempt++) {
      await controller.scanDevices();
      for (final candidate in controller.scannedDevices) {
        if (_isEt488(candidate) && candidate.nativeId == nativeId) {
          rediscovered = candidate;
          break;
        }
      }
      if (rediscovered == null) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    if (rediscovered == null) {
      _log('reconnect', false, {'reason': 'not_rediscovered'});
      return;
    }
    await controller.connectDevice(rediscovered);
    final ready = await _waitUntil(
      () =>
          controller.connectedDevice?.nativeId == nativeId &&
          controller.deviceState == DeviceConnectionState.ready,
      const Duration(seconds: 45),
    );
    _log('reconnect', ready, {
      'state': controller.deviceState.name,
      'connected': controller.connectedDevice != null,
      if (controller.errorMessage != null) 'error': controller.errorMessage,
    });
  }

  bool _isEt488(DeviceInfo device) => device.name
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '')
      .contains('ET488');

  Map<String, Object?> _deviceSummary(DeviceInfo device) => {
    'name': device.name,
    'source': device.sdkSource.shortLabel,
    'identifier': device.identifierLabel,
    'firmwarePresent': (device.firmwareVersion ?? '').trim().isNotEmpty,
  };

  Future<bool> _waitUntil(bool Function() condition, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return condition();
  }

  List<String> _sorted(Iterable<String> values) => values.toList()..sort();

  String _safeError(Object error) {
    final value = '$error'.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return value.length <= 240 ? value : '${value.substring(0, 240)}…';
  }

  void _log(String stage, bool passed, Map<String, Object?> details) {
    debugPrint(
      'ET488_QA:${jsonEncode(<String, Object?>{'stage': stage, 'passed': passed, ...details})}',
      wrapWidth: 1024,
    );
  }
}
