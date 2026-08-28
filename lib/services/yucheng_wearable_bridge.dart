import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/feature_models.dart';
import '../domain/models.dart';
import 'wearable_bridge.dart';
import 'wearable_routing.dart';
import 'yucheng_payload_mapper.dart';
import 'yucheng_product_client.dart';

class YuchengWearableBridge
    implements WearableBridge, WearableDeviceDetailsBridge {
  YuchengWearableBridge({
    YuchengProductClient? client,
    this.healthReadTimeout = const Duration(seconds: 8),
    this.initialHealthSettleDelay = const Duration(seconds: 3),
    this.capabilityRetryDelay = const Duration(milliseconds: 500),
  }) : _client = client ?? PluginYuchengProductClient();
  final YuchengProductClient _client;
  final Duration healthReadTimeout;
  final Duration initialHealthSettleDelay;
  final Duration capabilityRetryDelay;
  final _events = StreamController<WearableEvent>.broadcast();
  bool _initialized = false;
  String? _deviceId;
  final String _firmware = '';
  DeviceCapabilities? _capabilities;
  Future<DeviceCapabilities>? _capabilityLoad;
  final Map<String, String> _scannedNames = {};
  bool _needsInitialHealthSettle = false;
  bool _capabilitiesResolved = false;
  HealthMetric? _activeMeasurementMetric;
  DateTime? _measurementStartedAt;

  @override
  Stream<WearableEvent> get events => _events.stream;

  Future<void> _initialize() async {
    if (_initialized) return;
    // The vendor's automatic reconnect can establish a hidden GATT session
    // before this bridge knows the device identifier. The bound watch then
    // disappears from scans while the UI still reports it as disconnected.
    // Keep connection ownership in the app so native and visible state agree.
    await _client.initialize(reconnectEnabled: false, logEnabled: false);
    _client.events.listen(_handleEvent);
    _initialized = true;
  }

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    await _initialize();
    final devices = (await _client.scan())
        .map(
          (row) => DeviceInfo(
            id: '${row['identifier'] ?? ''}',
            name: '${row['name'] ?? ''}',
            rssi: (row['rssi'] as num?)?.toInt(),
            hardwareAddress: row['hardwareAddress']?.toString(),
            firmwareVersion: row['firmwareVersion']?.toString(),
          ),
        )
        .where((d) => d.id.isNotEmpty)
        .toList();
    _scannedNames
      ..clear()
      ..addEntries(devices.map((device) => MapEntry(device.id, device.name)));
    return devices;
  }

  @override
  Future<void> stopScan() async {
    await _initialize();
    await _client.stopScan();
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    await _initialize();
    final scannedName = _scannedNames[deviceId] ?? '';
    if (!YuchengDeviceClassifier.matches(scannedName)) {
      throw PlatformException(
        code: 'YUCHENG_MODEL_MISMATCH',
        message: '此设备暂时无法连接，请选择赛电手表',
      );
    }
    final connected = await _client
        .connect(deviceId)
        .timeout(const Duration(seconds: 30), onTimeout: () => false);
    if (!connected) {
      throw PlatformException(
        code: 'YUCHENG_CONNECT_FAILED',
        message: '连接失败，请将手表靠近手机后重试',
      );
    }
    // The plugin starts its own model/MCU/feature queries when BLE reaches the
    // ready state. Issuing another model and setup sequence here can leave its
    // native command queue waiting forever. BLE authentication is therefore
    // the connection boundary; optional metadata is loaded separately.
    _deviceId = deviceId;
    _capabilities = null;
    _capabilitiesResolved = false;
    _needsInitialHealthSettle = true;
    unawaited(_publishCapabilitiesWhenReady());
  }

  @override
  Future<void> disconnect() async {
    await _client.disconnect();
    _deviceId = null;
    _capabilities = null;
    _capabilityLoad = null;
    _capabilitiesResolved = false;
    _needsInitialHealthSettle = false;
    _activeMeasurementMetric = null;
    _measurementStartedAt = null;
  }

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async {
    final deviceId = _deviceId;
    if (deviceId == null) return null;
    final name = _scannedNames[deviceId] ?? '赛电手表';
    return DeviceInfo(
      id: deviceId,
      name: name,
      model: name,
      firmwareVersion: _firmware.isEmpty ? null : _firmware,
    );
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async {
    _connectedId;
    if (_capabilitiesResolved && _capabilities != null) return _capabilities!;
    final activeLoad = _capabilityLoad;
    if (activeLoad != null) return activeLoad;
    final load = _readCapabilities();
    _capabilityLoad = load;
    try {
      return await load;
    } finally {
      if (identical(_capabilityLoad, load)) _capabilityLoad = null;
    }
  }

  Future<DeviceCapabilities> _readCapabilities() async {
    // W8/JL reports the BLE connection before its device-info and watch-face
    // handshake has finished. Keep retrying through that real-device window;
    // the native failure response is safe after the Android patch below.
    for (var attempt = 0; attempt < 12; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(capabilityRetryDelay);
      }
      try {
        final flags = await _client.capabilities().timeout(
          const Duration(seconds: 2),
        );
        final reported = YuchengPayloadMapper.capabilities(flags);
        if (reported.metrics.isNotEmpty || reported.features.isNotEmpty) {
          _capabilities = reported;
          _capabilitiesResolved = true;
          return reported;
        }
      } catch (_) {
        // The device may still be completing its feature handshake.
      }
    }
    throw PlatformException(
      code: 'CAPABILITIES_UNAVAILABLE',
      message: '暂时无法读取此手表的功能',
    );
  }

  Future<void> _publishCapabilitiesWhenReady() async {
    try {
      final reported = await getCapabilities();
      if (_deviceId == null || _events.isClosed) return;
      _events.add(
        WearableEvent(type: 'capabilitiesUpdated', payload: reported.toJson()),
      );
    } catch (_) {
      // The page keeps a retry action; no guessed capability is published.
    }
  }

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    final id = _connectedId;
    if (_needsInitialHealthSettle) {
      _needsInitialHealthSettle = false;
      // Yuc/JL finishes its device-info handshake shortly after BLE reports
      // ready. Keep this vendor-specific delay inside the Yuc bridge so Vep
      // devices and unrelated UI flows are never held back.
      await Future<void>.delayed(initialHealthSettleDelay);
      if (_deviceId != id) {
        throw PlatformException(code: 'CONNECTION_DROPPED', message: '设备连接已断开');
      }
    }
    final rows = <int, List<Map<String, Object?>>>{};
    for (final type in [
      YuchengHealthDataType.step,
      YuchengHealthDataType.sleep,
      YuchengHealthDataType.heartRate,
      YuchengHealthDataType.bloodPressure,
      YuchengHealthDataType.combined,
    ]) {
      final result = await _client
          .health(type)
          .timeout(
            healthReadTimeout,
            onTimeout: () => throw PlatformException(
              code: 'YUCHENG_SYNC_TIMEOUT',
              message: '手表数据读取超时，请稍后重试',
            ),
          );
      if (result.status == 0) {
        rows[type] = result.data ?? const [];
      } else if (result.status != 2) {
        _require(result);
      }
    }
    return YuchengPayloadMapper.healthRecords(
      deviceId: id,
      firmwareVersion: _firmware,
      rowsByType: rows,
    );
  }

  static const _measurements = {
    HealthMetric.heartRate: YuchengMeasurementType.heartRate,
    HealthMetric.bloodPressure: YuchengMeasurementType.bloodPressure,
    HealthMetric.bloodOxygen: YuchengMeasurementType.bloodOxygen,
    HealthMetric.bodyTemperature: YuchengMeasurementType.bodyTemperature,
    HealthMetric.bloodGlucose: YuchengMeasurementType.bloodGlucose,
  };
  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    _connectedId;
    final type = _measurements[metric];
    if (type == null) throw _unsupported();
    _activeMeasurementMetric = metric;
    _measurementStartedAt = DateTime.now().toUtc();
    try {
      _require(await _client.measure(enabled: true, type: type));
    } catch (_) {
      _activeMeasurementMetric = null;
      _measurementStartedAt = null;
      rethrow;
    }
  }

  @override
  Future<void> stopMeasurement(HealthMetric metric) async {
    _connectedId;
    final type = _measurements[metric];
    if (type == null) throw _unsupported();
    if (_activeMeasurementMetric == metric) {
      _activeMeasurementMetric = null;
      _measurementStartedAt = null;
    }
    _require(await _client.measure(enabled: false, type: type));
  }

  static const _sports = {
    SportMode.running: 0x0F,
    SportMode.walking: 0x10,
    SportMode.cycling: 0x03,
    SportMode.hiking: 0x1B,
  };
  @override
  Future<void> startSport(SportMode mode) async {
    _connectedId;
    final type = _sports[mode];
    if (type == null) throw _unsupported();
    _require(await _client.sport(state: YuchengSportState.start, type: type));
  }

  @override
  Future<void> stopSport() async {
    _connectedId;
    _require(await _client.sport(state: YuchengSportState.stop, type: 0));
  }

  @override
  Future<List<SportRecord>> readSportRecords() async {
    _connectedId;
    final r = await _client.health(YuchengHealthDataType.sportHistory);
    _require(r);
    return YuchengPayloadMapper.sportRecords(r.data ?? const []);
  }

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async =>
      throw _unsupported();
  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) async {
    _connectedId;
    if (type != 'heart_rate') throw _unsupported();
    _require(await _client.setHealthMonitoring(enabled));
  }

  @override
  Future<int?> readHeartRateWarning() async => throw _unsupported();
  @override
  Future<void> setHeartRateWarning(int value) async {
    _connectedId;
    _require(await _client.setHeartRateAlarm(value));
  }

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    _connectedId;
    if (feature != DeviceFeature.watchFaces) {
      throw _unsupported();
    }
    final result = await _client.watchFaces();
    _require(result);
    return <String, Object?>{
      'items': result.data ?? const <Map<String, Object?>>[],
      // The Vep online catalogue uses another binary/profile protocol. Keep
      // it hidden until a Yuc-compatible catalogue is configured.
      'onlineMarketSupported': false,
      'source': 'Yuc',
    };
  }

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    _connectedId;
    if (feature != DeviceFeature.watchFaces ||
        values['operation'] != 'switch') {
      throw _unsupported();
    }
    final dialId = int.tryParse('${values['id'] ?? values['index'] ?? ''}');
    if (dialId == null) {
      throw PlatformException(code: 'INVALID_ARGUMENT', message: '表盘标识无效');
    }
    _require(await _client.changeWatchFace(dialId));
  }

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {
    _connectedId;
    if (feature == DeviceFeature.findWatch) {
      _require(await _client.findDevice());
    } else if (feature == DeviceFeature.camera) {
      _require(await _client.camera(enabled));
    } else {
      throw _unsupported();
    }
  }

  String get _connectedId =>
      _deviceId ??
      (throw PlatformException(code: 'NOT_CONNECTED', message: '请先连接手表'));
  void _require(YuchengOperationResult<Object?> result) {
    if (result.status == 2) throw _unsupported();
    if (result.status != 0) {
      throw PlatformException(
        code: 'YUCHENG_OPERATION_FAILED',
        message: '手表操作失败，请稍后重试',
      );
    }
  }

  static PlatformException _unsupported([String message = '请在手表上操作']) =>
      PlatformException(code: 'FEATURE_UNSUPPORTED', message: message);

  void _handleEvent(Map<String, Object?> event) {
    const nativeEventTypes = <String>{
      'bluetoothStateChange',
      'deviceRealHeartRate',
      'deviceRealBloodPressure',
      'deviceRealBloodOxygen',
      'deviceRealTemperature',
      'deviceRealBloodGlucose',
      'deviceRealHRV',
      'deviceHealthDataMeasureStateChange',
      'deviceControlPhotoStateChange',
      'deviceWatchFaceChange',
      'deviceJieLiWatchFaceChange',
    };
    final declaredType = '${event['type'] ?? event['eventType'] ?? ''}';
    final type = declaredType.isNotEmpty
        ? declaredType
        : event.keys.cast<String?>().firstWhere(
                nativeEventTypes.contains,
                orElse: () => null,
              ) ??
              '';
    final rawPayload = event['data'] ?? event[type];
    final payload = rawPayload is Map
        ? rawPayload.map((k, v) => MapEntry('$k', v))
        : <String, Object?>{'value': rawPayload};
    if (type == 'deviceHealthDataMeasureStateChange') {
      _handleMeasurementState(payload);
      return;
    }
    final mapped = switch (type) {
      'bluetoothStateChange' => WearableEvent(
        type: (payload['state'] ?? payload['value']) == 4
            ? 'disconnected'
            : 'state',
        payload: {
          'value': (payload['state'] ?? payload['value']) == 2
              ? 'ready'
              : 'connecting',
        },
      ),
      'deviceRealHeartRate' => _liveHealthRecord(HealthMetric.heartRate, {
        'value': _number(payload['value']),
      }),
      'deviceRealBloodPressure' =>
        _liveHealthRecord(HealthMetric.bloodPressure, {
          'systolic': _number(payload['systolicBloodPressure']),
          'diastolic': _number(payload['diastolicBloodPressure']),
          'pulse': _number(payload['heartRate']),
        }),
      'deviceRealBloodOxygen' => _liveHealthRecord(HealthMetric.bloodOxygen, {
        'value': _number(payload['value']),
      }),
      'deviceRealTemperature' => _liveHealthRecord(
        HealthMetric.bodyTemperature,
        {'value': _number(payload['value'])},
      ),
      'deviceRealBloodGlucose' => _liveHealthRecord(HealthMetric.bloodGlucose, {
        'value': _number(payload['value']),
      }),
      'deviceRealHRV' => _liveHealthRecord(HealthMetric.hrv, {
        'value': _number(payload['value']),
      }),
      'deviceControlPhotoStateChange' => WearableEvent(
        type: 'cameraShutter',
        payload: payload,
      ),
      'deviceWatchFaceChange' || 'deviceJieLiWatchFaceChange' => WearableEvent(
        type: 'deviceFeatureProgress',
        payload: {'feature': 'watch_faces', ...payload},
      ),
      _ => null,
    };
    if (mapped != null) {
      _events.add(mapped);
      final recordMetric = HealthMetric.fromWire('${mapped.payload['type']}');
      if (mapped.type == 'healthRecord' &&
          _activeMeasurementMetric == recordMetric) {
        _activeMeasurementMetric = null;
        _measurementStartedAt = null;
      }
    }
  }

  WearableEvent? _liveHealthRecord(
    HealthMetric metric,
    Map<String, num?> rawValues,
  ) {
    final values = <String, num>{
      for (final entry in rawValues.entries)
        if (entry.value != null && entry.value!.isFinite && entry.value! > 0)
          entry.key: entry.value!,
    };
    final hasRequiredValues = switch (metric) {
      HealthMetric.bloodPressure =>
        values.containsKey('systolic') && values.containsKey('diastolic'),
      _ => values.containsKey('value'),
    };
    if (!hasRequiredValues) return null;
    final now = DateTime.now();
    final record = HealthRecord(
      id: 'yc-live-${metric.wireName}-${now.toUtc().microsecondsSinceEpoch}',
      metric: metric,
      values: values,
      unit: metric.defaultUnit,
      measuredAt: now.toUtc(),
      timezone: _timezoneOffset(now.timeZoneOffset),
      deviceId: _deviceId ?? '',
      firmwareVersion: _firmware,
      quality: 'device_reported',
      source: MeasurementSource.wearable,
      rawVersion: 1,
    );
    return WearableEvent(type: 'healthRecord', payload: record.toJson());
  }

  void _handleMeasurementState(Map<String, Object?> payload) {
    final metric = _activeMeasurementMetric;
    if (metric == null) return;
    final state = _number(payload['state'])?.toInt();
    if (state == 0) {
      unawaited(_finishMeasurementFromHistory(metric));
      return;
    }
    _events.add(
      WearableEvent(
        type: 'measurementProgress',
        payload: {'metric': metric.wireName, 'progress': 0},
      ),
    );
  }

  Future<void> _finishMeasurementFromHistory(HealthMetric metric) async {
    final startedAt = _measurementStartedAt;
    final type = switch (metric) {
      HealthMetric.heartRate => YuchengHealthDataType.heartRate,
      HealthMetric.bloodPressure => YuchengHealthDataType.bloodPressure,
      HealthMetric.bloodOxygen ||
      HealthMetric.bodyTemperature ||
      HealthMetric.bloodGlucose ||
      HealthMetric.hrv => YuchengHealthDataType.combined,
      _ => null,
    };
    if (type == null) return;
    try {
      final result = await _client.health(type).timeout(healthReadTimeout);
      if (_activeMeasurementMetric != metric) return;
      _require(result);
      final records =
          YuchengPayloadMapper.healthRecords(
              deviceId: _connectedId,
              firmwareVersion: _firmware,
              rowsByType: {type: result.data ?? const []},
            ).where((record) => record.metric == metric).toList()
            ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
      final record = records.firstOrNull;
      if (record != null &&
          (startedAt == null ||
              !record.measuredAt.isBefore(
                startedAt.subtract(const Duration(minutes: 2)),
              ))) {
        _activeMeasurementMetric = null;
        _measurementStartedAt = null;
        _events.add(
          WearableEvent(type: 'healthRecord', payload: record.toJson()),
        );
        return;
      }
    } catch (_) {
      if (_activeMeasurementMetric != metric) return;
    }
    _activeMeasurementMetric = null;
    _measurementStartedAt = null;
    _events.add(
      const WearableEvent(
        type: 'error',
        payload: {
          'code': 'MEASUREMENT_STOP_FAILED',
          'message': '未收到有效测量结果，请确认手表已贴合手腕后重试',
        },
      ),
    );
  }

  static num? _number(Object? value) =>
      value is num ? value : num.tryParse('$value');

  static String _timezoneOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }
}
