import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/device_state_machine.dart';
import '../domain/feature_models.dart';
import '../domain/models.dart';
import '../domain/wellness_release_policy.dart';
import '../domain/u19_health_features.dart';
import 'safe_secure_storage.dart';
import 'urion_eb1_protocol.dart';
import 'wearable_bridge.dart';

/// A separate EB1 transport. It does not call either vendor SDK and never
/// claims a watch from its advertised name alone.
class UrionWearableBridge
    implements
        WearableBridge,
        WearableDeviceDetailsBridge,
        WearableOwnedSystemTargetBridge,
        WearableRememberedDeviceSelectionBridge,
        WearableU19HealthPolicyBridge {
  UrionWearableBridge({
    MethodChannel? methods,
    this.healthPolicy,
    EventChannel? eventChannel,
    this.requestTimeout = const Duration(seconds: 8),
    this.connectTimeout = const Duration(seconds: 30),
    this.resultPollInterval = const Duration(seconds: 6),
    this.completedResultTimeout = const Duration(seconds: 24),
    DateTime Function()? now,
  }) : _methods = methods ?? const MethodChannel('cc.saidian/urion_methods'),
       _now = now ?? DateTime.now,
       _eventChannel =
           eventChannel ?? const EventChannel('cc.saidian/urion_events') {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      _onNativeEvent,
    );
  }

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  final WellnessReleasePolicy? healthPolicy;
  WellnessReleasePolicy? get _policy =>
      healthPolicy?.forDevice("urion:${_deviceId ?? ''}");
  final Set<int> _quarantinedCommands = {};
  Timer? _resultPoll;
  Timer? _bloodPressureResultLimit;
  Set<HealthMetric> _nativeReads = const {};
  Set<HealthMetric> _nativeManual = const {};
  final Duration requestTimeout;
  final Duration connectTimeout;
  final Duration resultPollInterval;
  final Duration completedResultTimeout;
  final DateTime Function() _now;
  final SerialOperationQueue _queue = SerialOperationQueue();
  final FlutterSecureStorage _languageStorage = safeSecureStorage;
  final Eb1FrameBuffer _buffer = Eb1FrameBuffer();
  final StreamController<WearableEvent> _events =
      StreamController<WearableEvent>.broadcast();
  late final StreamSubscription<dynamic> _subscription;
  _Eb1Pending? _pending;
  String? _deviceId;
  int? _nativeGeneration;
  int _session = 0;
  DeviceInfo? _details;
  DeviceCapabilities? _capabilities;
  int? _operationSession;
  String? _operationDevice;
  _Eb1Measurement? _measurement;
  _Eb1SpotMeasurement? _spotMeasurement;
  _Eb1PulseMeasurement? _pulseMeasurement;
  Eb1DynamicBloodPressureSettings? _dynamicPressure;
  Eb1TimestampEncoding? _bloodPressureTimeEncoding;
  DateTime? _bloodPressureVerifiedSince;
  final Map<String, HealthRecord> _confirmedBloodPressureRecords = {};
  final Set<String> _knownBloodPressureFingerprints = {};
  final Map<String, DateTime> _bloodPressureFirstSeenAt = {};
  DateTime? _bloodPressureHistoryCheckedAt;
  DateTime? _watchBloodPressureNoticeAt;
  bool _findSupported = true;

  String _languageKey(String id) =>
      'sayring_urion_time_language_${sha256.convert(utf8.encode(id))}';

  @override
  Future<void> configureU19HealthMetrics(
    Set<HealthMetric> read,
    Set<HealthMetric> manual, {
    required Duration validity,
  }) async {
    if (!U19HealthFeatures.ceiling.containsAll(read) ||
        !read.containsAll(manual) ||
        validity > const Duration(minutes: 5)) {
      throw const FormatException('Invalid U19 native scope');
    }
    await _methods.invokeMethod<void>('configureHealthPolicy', {
      'readMetrics': read.map((m) => m.wireName).toList(),
      'manualMetrics': manual.map((m) => m.wireName).toList(),
      'validForSeconds': validity.inSeconds,
    });
    if (!setEquals(_nativeReads, read) || !setEquals(_nativeManual, manual)) {
      _capabilities = null;
    }
    _nativeReads = Set.of(read);
    _nativeManual = Set.of(manual);
  }

  @override
  Future<DeviceInfo?> lookupOwnedSystemTarget(String nativeIdentifier) =>
      prepareRememberedDeviceForSelection(nativeIdentifier, cacheOnly: true);

  @override
  Future<DeviceInfo?> prepareRememberedDeviceForSelection(
    String nativeIdentifier, {
    String? knownName,
    bool cacheOnly = false,
  }) async {
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'prepareRememberedDevice',
      {'deviceId': nativeIdentifier},
    );
    if (raw == null || raw['id'] != nativeIdentifier) return null;
    return DeviceInfo.fromMap(raw);
  }

  @override
  Stream<WearableEvent> get events => _events.stream;

  Future<void> dispose() async {
    _resultPoll?.cancel();
    _bloodPressureResultLimit?.cancel();
    await _subscription.cancel();
    await _events.close();
  }

  void _onNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    final event = WearableEvent.fromMap(Map<Object?, Object?>.from(raw));
    if (event.type == 'connectionPhase') {
      if (!kReleaseMode) {
        debugPrint(
          '[U19Connect] ${event.payload['phase']} code=${event.payload['code'] ?? 'none'}',
        );
      }
      return;
    }
    if (event.type == 'scanDevice') {
      _events.add(event);
      return;
    }
    // 原生回调可能在同一 MAC 的下一次连接之后才到达，必须同时匹配批次。
    if (event.type != 'bytes' &&
        event.payload['generation'] != _nativeGeneration) {
      return;
    }
    if (event.type == 'disconnected') {
      final id = '${event.payload['deviceId'] ?? ''}';
      if (_deviceId != null && id == _deviceId) {
        _retireSession();
        _events.add(event);
      }
      return;
    }
    if (event.type == 'deviceDetails') {
      if ('${event.payload['id'] ?? ''}' == _deviceId) {
        _details = DeviceInfo.fromMap(event.payload);
        _events.add(event);
      }
      return;
    }
    if (event.type != 'bytes' || _deviceId == null) return;
    if (event.payload['deviceId'] != _deviceId ||
        event.payload['generation'] != _nativeGeneration) {
      return;
    }
    final bytes = event.payload['bytes'];
    if (bytes is! Uint8List && bytes is! List<int>) return;
    for (final frame in _buffer.add(
      bytes is Uint8List ? bytes : bytes as List<int>,
    )) {
      // Urion monitoring and pulse features are available on iOS. Their
      // settings/result notices must reach the same handlers as explicit reads.
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          frame.command == 0x73 &&
          {4, 6}.contains(frame[1])) {
        continue;
      }
      if (frame.command == 0x37) {
        try {
          _dynamicPressure = Eb1DynamicBloodPressureSettings.parse(frame);
          _events.add(
            WearableEvent(
              type: 'deviceFeatureData',
              payload: {
                'feature': DeviceFeature.healthMonitoring.wireName,
                'deviceId': _deviceId,
                'dynamicBloodPressure': _dynamicPressure!.toMap(),
              },
            ),
          );
        } on FormatException {
          if (kDebugMode) debugPrint('[U19] invalid pressure settings notice');
        }
        continue;
      }
      if (frame.command == 0x73 || frame.command == 0x33) {
        final bloodPressureChanged = frame.command == 0x33 || frame[1] == 2;
        if (bloodPressureChanged) {
          if (kDebugMode) debugPrint('[U19Measurement] completion notice');
          if (_measurement == null) {
            _watchBloodPressureNoticeAt = _now().toUtc();
          } else {
            _scheduleMeasurementRead(
              completed: frame.command == 0x33,
              dataChanged: true,
            );
          }
        }
        if (frame.command == 0x73 && (frame[1] == 1 || frame[1] == 3)) {
          _scheduleSpotRead(frame[1]);
        }
        if (frame.command == 0x73 && frame[1] == 5) {
          _schedulePulseRead();
        }
        if (frame.command == 0x73 && frame[1] == 0x0c) {
          _scheduleBatteryRead();
        }
        if (frame.command == 0x33 || {1, 2, 3, 4, 6}.contains(frame[1])) {
          _events.add(
            WearableEvent(
              type: 'healthDataReady',
              payload: {'source': 'watchNotification', 'deviceId': _deviceId},
            ),
          );
        }
        continue;
      }
      final pending = _pending;
      if (pending == null || pending.session != _session) continue;
      if (frame.isError && frame.command == (pending.command | 0x80)) {
        if (frame.isUnsupported) _withdrawUnsupportedCommand(pending.command);
        pending.fail(
          PlatformException(
            code: frame.isUnsupported
                ? 'UNSUPPORTED_DEVICE'
                : 'DEVICE_REJECTED',
            message: frame.isUnsupported ? '当前手表不支持此功能' : '手表暂时无法完成操作，请重试',
          ),
        );
        continue;
      }
      if (frame.command == pending.command) pending.accept(frame);
    }
  }

  void _retireSession() {
    _resultPoll?.cancel();
    _resultPoll = null;
    _bloodPressureResultLimit?.cancel();
    _bloodPressureResultLimit = null;
    _session++;
    _pending?.fail(
      PlatformException(code: 'DEVICE_DISCONNECTED', message: '手表已断开连接'),
    );
    _pending = null;
    _deviceId = null;
    _nativeGeneration = null;
    _details = null;
    _capabilities = null;
    _measurement = null;
    _spotMeasurement = null;
    _pulseMeasurement = null;
    _dynamicPressure = null;
    _bloodPressureTimeEncoding = null;
    _bloodPressureVerifiedSince = null;
    _confirmedBloodPressureRecords.clear();
    _knownBloodPressureFingerprints.clear();
    _bloodPressureFirstSeenAt.clear();
    _bloodPressureHistoryCheckedAt = null;
    _watchBloodPressureNoticeAt = null;
    _findSupported = true;
    _buffer.reset();
    _quarantinedCommands.clear();
  }

  Future<T> _runConnected<T>(Future<T> Function() operation) {
    final session = _session;
    final id = _deviceId;
    return _queue.run(() async {
      void requireCurrent() {
        if (id == null || session != _session || id != _deviceId) {
          throw PlatformException(
            code: 'DEVICE_CHANGED',
            message: '手表连接已变化，请重试',
          );
        }
      }

      requireCurrent();
      _operationSession = session;
      _operationDevice = id;
      try {
        final result = await operation();
        requireCurrent();
        return result;
      } finally {
        _operationSession = null;
        _operationDevice = null;
      }
    });
  }

  Future<List<Eb1Frame>> _exchange(
    int command, [
    List<int> payload = const [],
    int count = 1,
  ]) async {
    final metric = switch (command) {
      0x14 || 0x32 => HealthMetric.bloodPressure,
      0x15 || 0x38 => HealthMetric.heartRate,
      0x2d || 0x39 => HealthMetric.bloodOxygen,
      _ => null,
    };
    if (metric != null &&
        _policy?.enabled == true &&
        (!(_policy?.allowsMetric(metric) ?? false) ||
            ({0x32, 0x38, 0x39}.contains(command) &&
                !(_policy?.allowsManualMeasurement(metric) ?? false)))) {
      throw PlatformException(
        code: 'U19_HEALTH_UNAVAILABLE',
        message: 'This measurement is not available.',
      );
    }
    // EB1 没有请求号。超时命令在本次会话内隔离，迟到包不得匹配下一次同命令；
    // 其他只读命令仍可继续，不能为一个可选设置超时反复拆连接。
    if (_quarantinedCommands.contains(command)) {
      throw PlatformException(
        code: 'U19_COMMAND_UNAVAILABLE',
        message: 'Please reconnect before retrying this operation.',
      );
    }
    final id = _deviceId;
    if (id == null) {
      throw PlatformException(code: 'NOT_CONNECTED', message: '请先连接手表');
    }
    if (_pending != null) throw StateError('EB1 commands must be serial');
    if (_operationSession != _session || _operationDevice != id) {
      throw PlatformException(code: 'DEVICE_CHANGED', message: '手表连接已变化，请重试');
    }
    final pending = _Eb1Pending(command, _session, count);
    _pending = pending;
    try {
      await _methods
          .invokeMethod<void>('writeFrame', {
            'bytes': Eb1Frame.request(command, payload).bytes,
          })
          .timeout(requestTimeout);
      final frames = await pending.result.timeout(requestTimeout);
      if (pending.session != _session || id != _deviceId) {
        throw PlatformException(code: 'DEVICE_CHANGED', message: '手表连接已变化，请重试');
      }
      return frames;
    } on TimeoutException {
      _quarantinedCommands.add(command);
      throw PlatformException(
        code: 'DEVICE_TIMEOUT',
        message: 'The device did not respond. Please try again.',
      );
    } on FormatException {
      _quarantinedCommands.add(command);
      rethrow;
    } finally {
      if (identical(_pending, pending)) _pending = null;
    }
  }

  Future<void> _sendWatchTime(String language) async {
    // 明确校时后旧时间依据不再适用。已保存记录和已见指纹保留，
    // 后续同步重新建立观察窗口，不能把旧记录的时间改成今天。
    _bloodPressureTimeEncoding = null;
    _bloodPressureVerifiedSince = null;
    _bloodPressureHistoryCheckedAt = null;
    _watchBloodPressureNoticeAt = null;
    _bloodPressureFirstSeenAt.clear();
    final now = _now();
    final response = (await _exchange(0x01, [
      eb1EncodeBcd(now.year % 100),
      eb1EncodeBcd(now.month),
      eb1EncodeBcd(now.day),
      eb1EncodeBcd(now.hour),
      eb1EncodeBcd(now.minute),
      eb1EncodeBcd(now.second),
      language == 'zh' ? 0 : 1,
    ])).single;
    if (response.command != 0x01) {
      throw const FormatException('Invalid EB1 time acknowledgement');
    }
    // EB1 has no clock readback. Daily data is still checked against the
    // phone date before it can become a health record.
  }

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    final raw = await _methods.invokeListMethod<Map<Object?, Object?>>(
      'scanDevices',
    );
    return (raw ?? const []).map(DeviceInfo.fromMap).toList(growable: false);
  }

  @override
  Future<void> stopScan() async {
    try {
      await _methods.invokeMethod<void>('stopScan');
    } on MissingPluginException {
      /* 没有原生宿主时此通道不可用。 */
    }
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    _retireSession();
    final connectionSession = _session;
    final Map<Object?, Object?>? raw;
    try {
      raw = await _methods
          .invokeMapMethod<Object?, Object?>('connect', {'deviceId': deviceId})
          .timeout(connectTimeout);
    } on TimeoutException {
      if (connectionSession == _session) {
        _retireSession();
        await _methods.invokeMethod<void>('disconnect');
      }
      throw PlatformException(
        code: 'CONNECT_TIMEOUT',
        message: '连接超时，请将手表靠近手机后重试',
      );
    }
    if (connectionSession != _session) {
      throw PlatformException(code: 'CONNECT_CANCELLED', message: '连接已取消');
    }
    _deviceId = deviceId;
    _nativeGeneration = (raw?['generation'] as num?)?.toInt();
    if (_nativeGeneration == null) {
      await disconnect();
      throw PlatformException(code: 'CONNECT_FAILED', message: '暂时无法连接手表');
    }
    final details = await getConnectedDeviceDetails();
    if (connectionSession != _session) {
      throw PlatformException(code: 'CONNECT_CANCELLED', message: '连接已取消');
    }
    if (details == null) {
      await disconnect();
      throw PlatformException(code: 'CONNECT_FAILED', message: '暂时无法连接手表');
    }
    // Notification subscription is completed by native before connect returns.
    // An EB1 read additionally verifies the byte-level session is responsive.
    try {
      final battery = (await _runConnected(() => _exchange(0x03))).single;
      final level = battery[1];
      if (level > 100) throw const FormatException('Invalid EB1 battery');
      _details = DeviceInfo(
        id: details.id,
        name: details.name,
        model: details.model,
        hardwareAddress: details.hardwareAddress,
        firmwareVersion: details.firmwareVersion,
        battery: DeviceBatteryInfo.percentage(level),
        rssi: details.rssi,
      );
      await _methods.invokeMethod<void>('rememberVerifiedDevice', {
        'deviceId': deviceId,
      });
      _events.add(
        WearableEvent(type: 'deviceDetails', payload: _details!.toJson()),
      );
    } catch (_) {
      if (connectionSession == _session) await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _retireSession();
    await _methods.invokeMethod<void>('disconnect');
  }

  @override
  Future<DeviceInfo?> getConnectedDeviceDetails({
    bool forceRefresh = false,
  }) async {
    final id = _deviceId;
    final session = _session;
    if (id == null) return null;
    final raw = await _methods.invokeMapMethod<Object?, Object?>(
      'getDeviceDetails',
    );
    if (raw == null ||
        '${raw['id']}' != id ||
        id != _deviceId ||
        session != _session) {
      return null;
    }
    final native = DeviceInfo.fromMap(raw);
    return _details = DeviceInfo(
      id: native.id,
      name: native.name,
      model: native.model,
      hardwareAddress: native.hardwareAddress,
      firmwareVersion: native.firmwareVersion,
      battery: _details?.battery ?? native.battery,
      rssi: native.rssi,
    );
  }

  @override
  Future<DeviceCapabilities> getCapabilities() => _runConnected(() async {
    if (_capabilities != null) return _capabilities!;
    final metrics = <HealthMetric>{};
    final features = <DeviceFeature>{};
    final manualMetrics = <HealthMetric>{};
    if (_findSupported) features.add(DeviceFeature.findWatch);
    try {
      await _readBloodPressure(count: 1);
      metrics.add(HealthMetric.bloodPressure);
      manualMetrics.add(HealthMetric.bloodPressure);
      if (kDebugMode) {
        debugPrint('[U19Capability] BP history structure verified');
      }
    } on PlatformException catch (error) {
      if (!{
        'UNSUPPORTED_DEVICE',
        'DEVICE_TIMEOUT',
        'U19_COMMAND_UNAVAILABLE',
        'U19_HEALTH_UNAVAILABLE',
      }.contains(error.code)) {
        rethrow;
      }
      if (kDebugMode) debugPrint('[U19Capability] BP history unsupported');
    }
    try {
      final daily = await _exchange(0x07, [0], 2);
      Eb1DailySnapshot.parse(daily[0], daily[1]);
      metrics.addAll({HealthMetric.steps, HealthMetric.sleep});
    } on PlatformException catch (error) {
      if (!{
        'UNSUPPORTED_DEVICE',
        'DEVICE_TIMEOUT',
        'U19_COMMAND_UNAVAILABLE',
        'U19_HEALTH_UNAVAILABLE',
      }.contains(error.code)) {
        rethrow;
      }
    }
    for (final metric in [HealthMetric.heartRate, HealthMetric.bloodOxygen]) {
      try {
        final history = await _readIndexed(metric);
        if (!history.hasNoData) {
          history.decodeHourlyOrFiveMinuteValues(
            expectedInterval: metric == HealthMetric.heartRate ? 5 : 60,
          );
        }
        metrics.add(metric);
        manualMetrics.add(metric);
      } on PlatformException catch (error) {
        if (!{
          'UNSUPPORTED_DEVICE',
          'DEVICE_TIMEOUT',
          'U19_COMMAND_UNAVAILABLE',
          'U19_HEALTH_UNAVAILABLE',
        }.contains(error.code)) {
          rethrow;
        }
      } on FormatException {
        // In particular, the supplier's five-packet oxygen layout is not a
        // verified scalar series. Do not present an undecodable result.
        if (kDebugMode) debugPrint('[U19Capability] indexed layout unverified');
      }
    }
    try {
      await _readPulse(count: 1);
      features.add(DeviceFeature.u19Pulse);
    } on PlatformException catch (error) {
      if (!{
        'UNSUPPORTED_DEVICE',
        'DEVICE_TIMEOUT',
        'U19_COMMAND_UNAVAILABLE',
        'U19_HEALTH_UNAVAILABLE',
      }.contains(error.code)) {
        rethrow;
      }
    }
    try {
      _dynamicPressure = Eb1DynamicBloodPressureSettings.parse(
        (await _exchange(0x36)).single,
      );
      features.add(DeviceFeature.healthMonitoring);
    } on PlatformException catch (error) {
      if (!{
        'UNSUPPORTED_DEVICE',
        'DEVICE_TIMEOUT',
        'U19_COMMAND_UNAVAILABLE',
        'U19_HEALTH_UNAVAILABLE',
      }.contains(error.code)) {
        rethrow;
      }
    } on FormatException {
      if (kDebugMode) debugPrint('[U19Capability] pressure settings invalid');
    }
    try {
      final screen = (await _exchange(0x1f, [1])).single;
      if (screen[1] == 1 && screen[2] >= 1 && screen[2] <= 20) {
        features.add(DeviceFeature.screenDisplay);
      }
    } on PlatformException catch (error) {
      if (!{
        'UNSUPPORTED_DEVICE',
        'DEVICE_TIMEOUT',
        'U19_COMMAND_UNAVAILABLE',
        'U19_HEALTH_UNAVAILABLE',
      }.contains(error.code)) {
        rethrow;
      }
    }
    final settingsReadable = <int>[];
    for (final command in [0x16, 0x2c]) {
      try {
        final answer = (await _exchange(command, [1])).single;
        if (answer[1] == 1 && {1, 2}.contains(answer[2])) {
          settingsReadable.add(command);
        }
      } on PlatformException catch (error) {
        if (!{
          'UNSUPPORTED_DEVICE',
          'DEVICE_TIMEOUT',
          'U19_COMMAND_UNAVAILABLE',
          'U19_HEALTH_UNAVAILABLE',
        }.contains(error.code)) {
          rethrow;
        }
      }
    }
    if (settingsReadable.isNotEmpty) {
      features.add(DeviceFeature.healthMonitoring);
    }
    try {
      final profile = (await _exchange(0x0a, [1])).single;
      final goals = (await _exchange(0x21, [1])).single;
      if (profile[1] == 1 &&
          (profile[2] == 0 || profile[2] == 1) &&
          goals[1] == 1) {
        features.add(DeviceFeature.basicSettings);
      }
    } on PlatformException catch (error) {
      if (!{
        'UNSUPPORTED_DEVICE',
        'DEVICE_TIMEOUT',
        'U19_COMMAND_UNAVAILABLE',
        'U19_HEALTH_UNAVAILABLE',
      }.contains(error.code)) {
        rethrow;
      }
    }
    // Measurements require a safe history read. Find uses the confirmed EB1
    // channel's protocol support and is withdrawn on an unsupported response.
    _capabilities = DeviceCapabilities(
      metrics: metrics,
      manualMetrics: manualMetrics,
      stoppableManualMetrics: const {},
      sportModes: const {},
      features: features,
      integratedFeatures: features,
    );
    return _capabilities!;
  });

  @override
  Future<List<HealthRecord>> syncHealthData({
    String? cursor,
  }) => _runConnected(() async {
    final packets = await _exchange(0x07, [0], 2);
    final snapshot = Eb1DailySnapshot.parse(packets[0], packets[1]);
    final today = _now().toLocal();
    final watchDate = snapshot.localDate;
    final dayDistance = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(watchDate).inDays;
    final unexpectedDayIndex = snapshot.daysAgo != 0;
    final unexpectedDate = dayDistance.abs() > 1;
    final invalidDuration =
        snapshot.sleepMinutes > 1440 ||
        snapshot.deepMinutes > 1440 ||
        snapshot.lightMinutes > 1440;
    if (!kReleaseMode) {
      debugPrint(
        '[U19Sync] daily: index=${snapshot.daysAgo} '
        'dayOffset=$dayDistance',
      );
    }
    if (unexpectedDayIndex || unexpectedDate || invalidDuration) {
      if (!kReleaseMode) {
        debugPrint(
          '[U19Sync] daily rejected: index=$unexpectedDayIndex '
          'date=$unexpectedDate duration=$invalidDuration',
        );
      }
      throw const FormatException('Unverified EB1 daily data');
    }
    final id = _deviceId!;
    final observedAt = _now().toUtc();
    final localDate =
        '${snapshot.localDate.year.toString().padLeft(4, '0')}-'
        '${snapshot.localDate.month.toString().padLeft(2, '0')}-'
        '${snapshot.localDate.day.toString().padLeft(2, '0')}';
    final offset = _now().timeZoneOffset;
    final offsetMinutes = offset.inMinutes;
    final timezone =
        '${offsetMinutes < 0 ? '-' : '+'}'
        '${(offsetMinutes.abs() ~/ 60).toString().padLeft(2, '0')}:'
        '${(offsetMinutes.abs() % 60).toString().padLeft(2, '0')}';
    HealthRecord summary(
      HealthMetric metric,
      num value,
      String unit, {
      String valueKey = 'value',
    }) {
      final versionContent = '$id|$localDate|${metric.wireName}|$value';
      final hash = sha256.convert(utf8.encode(versionContent)).bytes;
      final uuidBytes = hash.take(16).toList();
      uuidBytes[6] = (uuidBytes[6] & 0x0f) | 0x50;
      uuidBytes[8] = (uuidBytes[8] & 0x3f) | 0x80;
      final hex = uuidBytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final versionId =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      return HealthRecord(
        id: versionId,
        metric: metric,
        values: {valueKey: value},
        unit: unit,
        measuredAt: DateTime(
          snapshot.localDate.year,
          snapshot.localDate.month,
          snapshot.localDate.day,
        ).toUtc(),
        timezone: timezone,
        deviceId: 'urion:$id',
        firmwareVersion: _details?.firmwareVersion ?? '',
        sourceModel: _details?.model ?? '',
        sourceVendor: 'urion',
        sourceDeviceCategory: 'watch',
        sourceApp: 'say-ring',
        quality: 'valid',
        source: MeasurementSource.wearable,
        origin: MeasurementOrigin.watchHistory,
        rawVersion: 1,
        provenance: {
          'timePrecision': 'day',
          'aggregationLocalDate': localDate,
          'observedAt': observedAt.toIso8601String(),
        },
      );
    }

    final result = <HealthRecord>[];
    if (snapshot.steps > 0) {
      result.add(summary(HealthMetric.steps, snapshot.steps, '步'));
    }
    if (snapshot.sleepMinutes > 0) {
      result.add(
        summary(
          HealthMetric.sleep,
          snapshot.sleepMinutes / 60,
          'h',
          valueKey: 'value',
        ),
      );
    }
    for (final metric in [HealthMetric.heartRate, HealthMetric.bloodOxygen]) {
      if (_capabilities?.supports(metric) != true) continue;
      try {
        final record = await _latestIndexedRecord(metric, snapshot.localDate);
        if (record != null) result.add(record);
      } on FormatException {
        if (kDebugMode) debugPrint('[U19Sync] indexed data quarantined');
      }
    }
    if (_capabilities?.metrics.contains(HealthMetric.bloodPressure) == true) {
      final samples = await _readBloodPressure();
      final now = _now().toUtc();
      final previousCheck = _bloodPressureHistoryCheckedAt;
      final noticeAt = _watchBloodPressureNoticeAt;
      final unseen = samples
          .where(
            (sample) =>
                !_knownBloodPressureFingerprints.contains(sample.fingerprint),
          )
          .toList(growable: false);
      final watchNoticeCandidates =
          <String, (Eb1BloodPressureSample, Eb1TimestampMatch)>{};
      if (noticeAt != null &&
          now.difference(noticeAt) <= const Duration(minutes: 5)) {
        for (final sample in unseen) {
          final proof = eb1MatchMeasurementTimestamp(
            sample.rawTimestamp,
            startedAt: noticeAt.subtract(const Duration(minutes: 5)),
            endedAt: noticeAt,
          );
          if (proof != null) {
            watchNoticeCandidates[sample.fingerprint] = (sample, proof);
          }
        }
        // 通知可能排在一次历史回包之后。只补核对上一轮刚出现、尚未
        // 导入的记录；重复通知不能重新解释更早的基线或已确认结果。
        final noticeAlreadyMatched = samples.any(
          (sample) =>
              _confirmedBloodPressureRecords.containsKey(sample.fingerprint) &&
              eb1MatchMeasurementTimestamp(
                    sample.rawTimestamp,
                    startedAt: noticeAt.subtract(const Duration(minutes: 5)),
                    endedAt: noticeAt,
                  ) !=
                  null,
        );
        if (watchNoticeCandidates.isEmpty && !noticeAlreadyMatched) {
          for (final sample in samples) {
            final firstSeen = _bloodPressureFirstSeenAt[sample.fingerprint];
            if (firstSeen == null ||
                firstSeen != previousCheck ||
                _confirmedBloodPressureRecords.containsKey(
                  sample.fingerprint,
                )) {
              continue;
            }
            final proof = eb1MatchMeasurementTimestamp(
              sample.rawTimestamp,
              startedAt: noticeAt.subtract(const Duration(minutes: 5)),
              endedAt: firstSeen.isBefore(noticeAt) ? firstSeen : noticeAt,
            );
            if (proof != null) {
              watchNoticeCandidates[sample.fingerprint] = (sample, proof);
            }
          }
        }
      }
      if (watchNoticeCandidates.length == 1) {
        final (sample, proof) = watchNoticeCandidates.values.single;
        _bloodPressureTimeEncoding ??= proof.encoding;
        _bloodPressureVerifiedSince ??= DateTime.fromMillisecondsSinceEpoch(
          (noticeAt!.millisecondsSinceEpoch ~/ 1000) * 1000,
          isUtc: true,
        ).subtract(const Duration(minutes: 5));
        final record = _bloodPressureRecord(sample, proof.measuredAt);
        result.add(record);
        _confirmedBloodPressureRecords[sample.fingerprint] = record;
      }
      for (final sample in unseen) {
        if (watchNoticeCandidates.length == 1 &&
            sample.fingerprint == watchNoticeCandidates.keys.single) {
          continue;
        }
        if (previousCheck == null) continue;
        // 历史同步不要求收到实时测完通知。上一轮快照之后新增的样本，
        // 若设备时间只有一种解释落在两次读取之间，就已有独立的时间依据。
        // 这是 watchHistory，不发送手动测量完成事件，也不触发新读数提醒。
        final incrementalProof = eb1MatchMeasurementTimestamp(
          sample.rawTimestamp,
          startedAt: previousCheck,
          endedAt: now,
        );
        if (incrementalProof != null) {
          _bloodPressureTimeEncoding ??= incrementalProof.encoding;
          _bloodPressureVerifiedSince ??= previousCheck;
          final record = _bloodPressureRecord(
            sample,
            incrementalProof.measuredAt,
          );
          result.add(record);
          _confirmedBloodPressureRecords[sample.fingerprint] = record;
          continue;
        }
        final encoding = _bloodPressureTimeEncoding;
        final verifiedSince = _bloodPressureVerifiedSince;
        if (encoding == null || verifiedSince == null) continue;
        final measuredAt = eb1DecodeTimestamp(sample.rawTimestamp, encoding);
        final lowerBound = previousCheck.subtract(const Duration(minutes: 2));
        if (measuredAt.isBefore(lowerBound) ||
            measuredAt.isBefore(verifiedSince) ||
            measuredAt.isAfter(now)) {
          continue;
        }
        final record = _bloodPressureRecord(sample, measuredAt);
        result.add(record);
        _confirmedBloodPressureRecords[sample.fingerprint] = record;
      }
      // “已看到”与“已导入”分开：保留基线防止旧值变成本次新测量，
      // 同时保留最近一次出现时间，允许迟到通知补证，不永久丢掉刚读到的样本。
      final visible = samples.map((sample) => sample.fingerprint).toSet();
      _bloodPressureFirstSeenAt.removeWhere((key, _) => !visible.contains(key));
      for (final fingerprint in visible) {
        _bloodPressureFirstSeenAt.putIfAbsent(fingerprint, () => now);
      }
      _knownBloodPressureFingerprints.addAll(
        samples.map((sample) => sample.fingerprint),
      );
      _bloodPressureHistoryCheckedAt = now;
      if (noticeAt != null &&
          now.difference(noticeAt) > const Duration(minutes: 5)) {
        _watchBloodPressureNoticeAt = null;
      }
    }
    return result;
  });

  @override
  Future<void> startMeasurement(HealthMetric metric) => _runConnected(() async {
    if (_measurement != null ||
        _spotMeasurement != null ||
        _pulseMeasurement != null) {
      throw PlatformException(
        code: 'MEASUREMENT_IN_PROGRESS',
        message: 'End the current reading on your device first.',
      );
    }
    if (_capabilities?.manualMetrics?.contains(metric) != true) {
      throw PlatformException(code: 'UNSUPPORTED_DEVICE', message: '请在手表上操作');
    }
    if (metric == HealthMetric.heartRate ||
        metric == HealthMetric.bloodOxygen) {
      final baselineAt = _now().toLocal();
      final baselineDay = DateTime(
        baselineAt.year,
        baselineAt.month,
        baselineAt.day,
      );
      final before = await _readIndexed(metric, localDay: baselineDay);
      final previous = before.hasNoData
          ? const <int>[]
          : before.decodeHourlyOrFiveMinuteValues(
              expectedInterval: metric == HealthMetric.heartRate ? 5 : 60,
            );
      final measurement = _Eb1SpotMeasurement(
        session: _session,
        deviceId: _deviceId!,
        metric: metric,
        baselineDay: baselineDay,
        startedAt: _now().toUtc(),
        previous: previous,
      );
      _spotMeasurement = measurement;
      _measurement = null;
      try {
        await _exchange(metric == HealthMetric.heartRate ? 0x38 : 0x39);
        measurement.acknowledged = true;
        _startResultPoll();
      } catch (_) {
        if (identical(_spotMeasurement, measurement)) _spotMeasurement = null;
        rethrow;
      }
      return;
    }
    if (metric != HealthMetric.bloodPressure) {
      throw PlatformException(code: 'UNSUPPORTED_DEVICE', message: '请在手表上操作');
    }
    final before = await _readBloodPressure();
    final measurement = _Eb1Measurement(
      session: _session,
      deviceId: _deviceId!,
      startedAt: _now().toUtc(),
      previous: before.map((sample) => sample.fingerprint).toSet(),
    );
    _measurement = measurement;
    _spotMeasurement = null;
    try {
      await _exchange(0x32);
      measurement.acknowledged = true;
      _startResultPoll();
      if (kDebugMode) debugPrint('[U19Measurement] start acknowledged');
    } catch (_) {
      if (identical(_measurement, measurement)) _measurement = null;
      rethrow;
    }
  });

  @override
  Future<void> stopMeasurement(HealthMetric metric) async =>
      throw PlatformException(
        code: 'MEASUREMENT_STOP_UNSUPPORTED',
        message: '请在手表上结束测量',
      );

  Future<List<Eb1BloodPressureSample>> _readBloodPressure({
    int count = 50,
  }) async {
    // 原厂协议：时间戳为零时，两个回溯方向都表示取最新记录。
    // 仅在主请求明确返回空历史时补读一次；超时/拒绝不得绕过会话隔离重发。
    for (final direction in [0, 1]) {
      final frames = await _exchange(0x14, [
        0,
        0,
        0,
        0,
        direction,
        count,
      ], count);
      final samples = frames
          .map(Eb1BloodPressureSample.parse)
          .whereType<Eb1BloodPressureSample>()
          .toList(growable: false);
      if (samples.isNotEmpty) return samples;
    }
    return const [];
  }

  Future<List<Eb1PulseSample>> _readPulse({int count = 50}) async {
    final frames = await _exchange(0x34, [0, 0, 0, 0, 0, count], count);
    return frames
        .map(Eb1PulseSample.parse)
        .whereType<Eb1PulseSample>()
        .toList(growable: false);
  }

  Future<Eb1IndexedDay> _readIndexed(
    HealthMetric metric, {
    DateTime? localDay,
  }) async {
    final command = metric == HealthMetric.heartRate ? 0x15 : 0x2d;
    final today = localDay ?? _now().toLocal();
    final dayStart = DateTime(today.year, today.month, today.day);
    final seconds = dayStart.millisecondsSinceEpoch ~/ 1000;
    final frames = await _exchange(command, [
      for (var index = 0; index < 4; index++) (seconds >> (index * 8)) & 0xff,
    ]);
    return Eb1IndexedDay(command, frames);
  }

  String _recordId(String content) {
    final bytes = sha256
        .convert(utf8.encode('$_deviceId|$content'))
        .bytes
        .take(16)
        .toList();
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  HealthRecord _indexedRecord(
    HealthMetric metric,
    int value,
    DateTime measuredAt, {
    required String fingerprint,
    MeasurementOrigin origin = MeasurementOrigin.watchHistory,
  }) {
    final offset = measuredAt.toLocal().timeZoneOffset.inMinutes;
    return HealthRecord(
      id: _recordId('${metric.wireName}|$fingerprint'),
      metric: metric,
      values: {'value': value},
      unit: metric.defaultUnit,
      measuredAt: measuredAt.toUtc(),
      timezone:
          '${offset < 0 ? '-' : '+'}'
          '${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:'
          '${(offset.abs() % 60).toString().padLeft(2, '0')}',
      deviceId: 'urion:$_deviceId',
      firmwareVersion: _details?.firmwareVersion ?? '',
      sourceModel: _details?.model ?? '',
      sourceVendor: 'urion',
      sourceDeviceCategory: 'watch',
      sourceApp: 'say-ring',
      quality: 'valid',
      source: MeasurementSource.wearable,
      origin: origin,
      rawVersion: 1,
    );
  }

  Future<HealthRecord?> _latestIndexedRecord(
    HealthMetric metric,
    DateTime watchDate,
  ) async {
    final history = await _readIndexed(metric, localDay: watchDate);
    if (history.hasNoData) return null;
    final interval = metric == HealthMetric.heartRate ? 5 : 60;
    final values = history.decodeHourlyOrFiveMinuteValues(
      expectedInterval: interval,
    );
    final valid = <int>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (metric == HealthMetric.heartRate
          ? value >= 20 && value <= 300
          : value >= 2 && value <= 100) {
        valid.add(index);
      }
    }
    if (valid.isEmpty) return null;
    final slot = valid.last;
    final local = DateTime(
      watchDate.year,
      watchDate.month,
      watchDate.day,
    ).add(Duration(minutes: slot * interval));
    final now = _now().toUtc();
    if (local.toUtc().isAfter(now.add(Duration(minutes: interval)))) {
      throw const FormatException('Future EB1 indexed sample');
    }
    return _indexedRecord(
      metric,
      values[slot],
      local.toUtc(),
      fingerprint: '${watchDate.toIso8601String()}|$slot|${values[slot]}',
    );
  }

  void _startResultPoll() {
    _resultPoll?.cancel();
    final session = _session;
    final started = _now();
    _resultPoll = Timer.periodic(resultPollInterval, (timer) {
      if (session != _session ||
          _deviceId == null ||
          (_measurement == null &&
              _spotMeasurement == null &&
              _pulseMeasurement == null)) {
        timer.cancel();
        return;
      }
      if (_now().difference(started) >= const Duration(seconds: 150)) {
        timer.cancel();
        final pressure = _measurement;
        if (pressure != null) _finishBloodPressureWait(pressure);
        return;
      }
      // EB1 要在 0x73(2) 数据变更或 0x33 测完后读取结果。
      // 充气期间抢读可能超时并隔离 0x14，导致随后真实结果也无法读取。
      // 通知后才有界补读；缺少通知仍由总时限结束，绝不重新发起充气。
      if (_measurement?.resultReadReady == true) _scheduleMeasurementRead();
      final spot = _spotMeasurement;
      if (spot != null) {
        _scheduleSpotRead(spot.metric == HealthMetric.heartRate ? 1 : 3);
      }
      if (_pulseMeasurement != null && _pending == null) _schedulePulseRead();
    });
  }

  void _scheduleSpotRead(int noticeCode) {
    final measurement = _spotMeasurement;
    if (measurement == null ||
        measurement.session != _session ||
        measurement.deviceId != _deviceId ||
        noticeCode != (measurement.metric == HealthMetric.heartRate ? 1 : 3)) {
      return;
    }
    measurement.notices++;
    if (measurement.readQueued) return;
    measurement.readQueued = true;
    unawaited(
      _runConnected(() async {
        final notice = measurement.notices;
        try {
          if (!identical(_spotMeasurement, measurement) ||
              !measurement.acknowledged) {
            return;
          }
          // 日索引属于请求的本地日期。跨午夜后不能拿昨天同一索引的
          // 数值作为去重基线，也不能把当天任意旧时段的变化算作本次测量。
          final requestedAt = _now().toLocal();
          final requestedDay = DateTime(
            requestedAt.year,
            requestedAt.month,
            requestedAt.day,
          );
          final history = await _readIndexed(
            measurement.metric,
            localDay: requestedDay,
          );
          if (!identical(_spotMeasurement, measurement) ||
              measurement.session != _session ||
              history.hasNoData) {
            return;
          }
          final values = history.decodeHourlyOrFiveMinuteValues(
            expectedInterval: measurement.metric == HealthMetric.heartRate
                ? 5
                : 60,
          );
          final interval = measurement.metric == HealthMetric.heartRate
              ? 5
              : 60;
          final startedLocal = measurement.baselineDay;
          final sameBaselineDay =
              requestedDay.year == startedLocal.year &&
              requestedDay.month == startedLocal.month &&
              requestedDay.day == startedLocal.day;
          final endedAt = _now().toUtc();
          final changed = <int>[];
          for (var index = 0; index < values.length; index++) {
            final slotStart = DateTime(
              requestedDay.year,
              requestedDay.month,
              requestedDay.day,
              0,
              index * interval,
            ).toUtc();
            final slotEnd = DateTime(
              requestedDay.year,
              requestedDay.month,
              requestedDay.day,
              0,
              (index + 1) * interval,
            ).toUtc();
            // 只接受与本次操作窗口相交的采样时段；旧历史、未来时段和
            // 夏令时回拨导致的倒序区间不能冒充刚测出的值。
            if (slotStart.isAfter(endedAt) ||
                !slotEnd.isAfter(measurement.startedAt) ||
                !slotEnd.isAfter(slotStart)) {
              continue;
            }
            final value = values[index];
            if (sameBaselineDay &&
                index < measurement.previous.length &&
                value == measurement.previous[index]) {
              continue;
            }
            if (measurement.metric == HealthMetric.heartRate
                ? value >= 20 && value <= 300
                : value >= 2 && value <= 100) {
              changed.add(index);
            }
          }
          if (changed.length == 1 &&
              _now().toUtc().difference(measurement.startedAt) <=
                  const Duration(minutes: 3)) {
            final slot = changed.single;
            final record = _indexedRecord(
              measurement.metric,
              values[slot],
              _now().toUtc(),
              fingerprint:
                  '${measurement.startedAt.toIso8601String()}|$slot|${values[slot]}',
              origin: MeasurementOrigin.appMeasurement,
            );
            _spotMeasurement = null;
            _events.add(
              WearableEvent(
                type: 'healthRecord',
                payload: {
                  ...record.toJson(),
                  'measurementStartedAt': measurement.startedAt
                      .toIso8601String(),
                },
              ),
            );
          }
        } finally {
          measurement.readQueued = false;
          if (identical(_spotMeasurement, measurement) &&
              measurement.notices != notice) {
            _scheduleSpotRead(noticeCode);
          }
        }
      }).catchError((Object _) {
        measurement.readQueued = false;
        if (kDebugMode) debugPrint('[U19Measurement] indexed result not ready');
      }),
    );
  }

  void _schedulePulseRead() {
    if (_capabilities?.features.contains(DeviceFeature.u19Pulse) != true) {
      return;
    }
    unawaited(
      _runConnected(() async {
        final samples = await _readPulse(count: 1);
        if (samples.isEmpty) return;
        final sample = samples.first;
        final measurement = _pulseMeasurement;
        final proof =
            measurement != null &&
                measurement.session == _session &&
                measurement.deviceId == _deviceId &&
                measurement.acknowledged &&
                !measurement.previous.contains(sample.fingerprint)
            ? eb1MatchMeasurementTimestamp(
                sample.rawTimestamp,
                startedAt: measurement.startedAt,
                endedAt: _now().toUtc(),
              )
            : null;
        if (proof != null) _pulseMeasurement = null;
        _events.add(
          WearableEvent(
            type: 'deviceFeatureData',
            payload: {
              'feature': DeviceFeature.u19Pulse.wireName,
              'deviceId': _deviceId,
              'pulse': _pulseMap(sample, measuredAt: proof?.measuredAt),
              'justMeasured': proof != null,
            },
          ),
        );
      }).catchError((Object _) {
        if (kDebugMode) debugPrint('[U19Pulse] result read not completed');
      }),
    );
  }

  void _scheduleBatteryRead() {
    unawaited(
      _runConnected(() async {
        final details = _details;
        if (details == null) return;
        final response = (await _exchange(0x03)).single;
        if (response[1] > 100) return;
        _details = DeviceInfo(
          id: details.id,
          name: details.name,
          model: details.model,
          hardwareAddress: details.hardwareAddress,
          firmwareVersion: details.firmwareVersion,
          battery: DeviceBatteryInfo.percentage(response[1]),
          rssi: details.rssi,
        );
        _events.add(
          WearableEvent(type: 'deviceDetails', payload: _details!.toJson()),
        );
      }).catchError((Object _) {
        if (kDebugMode) debugPrint('[U19] battery refresh not completed');
      }),
    );
  }

  Map<String, Object?> _pulseMap(
    Eb1PulseSample sample, {
    DateTime? measuredAt,
  }) => {
    'rawTimestamp': sample.rawTimestamp,
    'bloodStasis': sample.bloodStasis,
    'qiBlood': sample.qiBlood,
    'dampness': sample.dampness,
    // EB1 4.15 carries epoch seconds. Do not use the history-read time.
    'measuredAt':
        (measuredAt ??
                eb1DecodeTimestamp(
                  sample.rawTimestamp,
                  _bloodPressureTimeEncoding ?? Eb1TimestampEncoding.utc,
                ))
            .toUtc()
            .toIso8601String(),
  };

  void _finishBloodPressureWait(_Eb1Measurement measurement) {
    if (!identical(_measurement, measurement) ||
        measurement.session != _session ||
        measurement.deviceId != _deviceId ||
        measurement.waitExpired) {
      return;
    }
    measurement.waitExpired = true;
    _bloodPressureResultLimit?.cancel();
    _bloodPressureResultLimit = null;
    _resultPoll?.cancel();
    _resultPoll = null;
    // 0x33证明测量已经结束；它不含读数，不能当作血压结果。
    // 未收到完成通知时保留物理测量屏障，须本人确认空闲后才可再次充气。
    if (measurement.completed) _measurement = null;
    _events.add(
      WearableEvent(
        type: 'error',
        payload: {
          'code': measurement.completed
              ? 'BLOOD_PRESSURE_RESULT_MISSING'
              : 'MEASUREMENT_TIMEOUT',
          'metric': HealthMetric.bloodPressure.wireName,
          'deviceId': 'urion:${measurement.deviceId}',
          'measurementStartedAt': measurement.startedAt.toIso8601String(),
          'message': measurement.completed
              ? '手表已测完，暂未取回结果，请同步数据重试'
              : '未收到新的血压结果，请先确认手表已结束测量',
        },
      ),
    );
  }

  void _scheduleMeasurementRead({
    bool completed = false,
    bool dataChanged = false,
  }) {
    final measurement = _measurement;
    if (measurement == null ||
        measurement.session != _session ||
        measurement.deviceId != _deviceId) {
      return;
    }
    if (measurement.waitExpired) {
      // 迟到完成只释放旧屏障；后续历史同步不能恢复已结束的手测窗口。
      if (completed) {
        _measurement = null;
        _watchBloodPressureNoticeAt = _now().toUtc();
      }
      return;
    }
    if (completed || dataChanged) measurement.resultReadReady = true;
    if (!measurement.resultReadReady) return;
    if (completed && !measurement.completed) {
      measurement.completed = true;
      _events.add(
        WearableEvent(
          type: 'measurementProgress',
          payload: {
            'metric': HealthMetric.bloodPressure.wireName,
            'deviceId': 'urion:${measurement.deviceId}',
            'measurementStartedAt': measurement.startedAt.toIso8601String(),
            'deviceState': 'READING_RESULT',
          },
        ),
      );
      // 给固件落盘和补读留出有界窗口；重复通知不得延长等待或重新充气。
      _bloodPressureResultLimit = Timer(completedResultTimeout, () {
        _finishBloodPressureWait(measurement);
      });
    }
    measurement.notices++;
    if (measurement.readQueued) return;
    measurement.readQueued = true;
    unawaited(
      _runConnected(() async {
        if (!identical(_measurement, measurement) ||
            measurement.waitExpired ||
            !measurement.acknowledged) {
          return;
        }
        final notice = measurement.notices;
        final samples = await _readBloodPressure();
        if (!identical(_measurement, measurement) ||
            measurement.waitExpired ||
            measurement.session != _session) {
          return;
        }
        final endedAt = _now().toUtc();
        final candidates =
            <String, (Eb1BloodPressureSample, Eb1TimestampMatch)>{};
        for (final sample in samples) {
          if (measurement.previous.contains(sample.fingerprint)) continue;
          final proof = eb1MatchMeasurementTimestamp(
            sample.rawTimestamp,
            startedAt: measurement.startedAt,
            endedAt: endedAt,
          );
          if (proof != null) candidates[sample.fingerprint] = (sample, proof);
        }
        // Multiple new samples or competing clock interpretations do not prove
        // which result belongs to this single user-initiated measurement.
        if (candidates.length == 1) {
          final (sample, proof) = candidates.values.single;
          _bloodPressureTimeEncoding = proof.encoding;
          _bloodPressureVerifiedSince = DateTime.fromMillisecondsSinceEpoch(
            measurement.startedAt.millisecondsSinceEpoch ~/ 1000 * 1000,
            isUtc: true,
          );
          final record = _bloodPressureRecord(
            sample,
            proof.measuredAt,
            origin: MeasurementOrigin.appMeasurement,
          );
          _confirmedBloodPressureRecords[sample.fingerprint] = record;
          _knownBloodPressureFingerprints.add(sample.fingerprint);
          _bloodPressureHistoryCheckedAt = endedAt;
          if (kDebugMode) {
            debugPrint(
              '[U19Measurement] unique new result verified '
              'clock=${proof.encoding?.name ?? 'equivalentInstant'}',
            );
          }
          _measurement = null;
          _bloodPressureResultLimit?.cancel();
          _bloodPressureResultLimit = null;
          _resultPoll?.cancel();
          _resultPoll = null;
          _events.add(
            WearableEvent(
              type: 'healthRecord',
              payload: {
                ...record.toJson(),
                'measurementStartedAt': measurement.startedAt.toIso8601String(),
              },
            ),
          );
        } else if (kDebugMode) {
          debugPrint('[U19Measurement] waiting for a verified new result');
        }
        measurement.readQueued = false;
        if (identical(_measurement, measurement) &&
            measurement.notices != notice) {
          _scheduleMeasurementRead();
        }
      }).catchError((Object error) {
        measurement.readQueued = false;
        if (kDebugMode) {
          final reason = error is PlatformException
              ? error.code
              : error.runtimeType;
          debugPrint('[U19Measurement] result read failed: $reason');
        }
        // 超时/畸形回包已隔离本次连接的命令，继续转圈不会恢复通道。
        // 立即结束页面等待；未确认物理测完时仍保留防重复充气屏障。
        _finishBloodPressureWait(measurement);
      }),
    );
  }

  HealthRecord _bloodPressureRecord(
    Eb1BloodPressureSample sample,
    DateTime measuredAt, {
    MeasurementOrigin origin = MeasurementOrigin.watchHistory,
  }) {
    final bytes = sha256
        .convert(utf8.encode('$_deviceId|bp|${sample.fingerprint}'))
        .bytes
        .take(16)
        .toList();
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final offset = measuredAt.toLocal().timeZoneOffset.inMinutes;
    return HealthRecord(
      id: '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}',
      metric: HealthMetric.bloodPressure,
      values: {
        'systolic': sample.systolic,
        'diastolic': sample.diastolic,
        'pulse': sample.pulse,
      },
      unit: 'mmHg',
      measuredAt: measuredAt,
      timezone:
          '${offset < 0 ? '-' : '+'}${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:${(offset.abs() % 60).toString().padLeft(2, '0')}',
      deviceId: 'urion:$_deviceId',
      firmwareVersion: _details?.firmwareVersion ?? '',
      sourceModel: _details?.model ?? '',
      sourceVendor: 'urion',
      sourceDeviceCategory: 'watch',
      sourceApp: 'say-ring',
      quality: 'valid',
      source: MeasurementSource.wearable,
      origin: origin,
      rawVersion: 1,
    );
  }

  void _withdrawUnsupportedCommand(int command) {
    if (command == 0x50) _findSupported = false;
    final previous = _capabilities;
    if (previous == null || !{0x50, 0x14, 0x32}.contains(command)) return;
    final next = DeviceCapabilities(
      metrics: {...previous.metrics}
        ..removeWhere(
          (metric) => command == 0x14 && metric == HealthMetric.bloodPressure,
        ),
      manualMetrics: {...?previous.manualMetrics}
        ..removeWhere(
          (metric) => command != 0x50 && metric == HealthMetric.bloodPressure,
        ),
      stoppableManualMetrics: const {},
      sportModes: const {},
      features: {...previous.features}
        ..removeWhere(
          (feature) => command == 0x50 && feature == DeviceFeature.findWatch,
        ),
      integratedFeatures: previous.integratedFeatures,
    );
    _capabilities = next;
    _events.add(
      WearableEvent(type: 'capabilitiesUpdated', payload: next.toJson()),
    );
  }

  @override
  Future<void> startSport(SportMode mode) async =>
      throw const WearableSdkNotConfigured();
  @override
  Future<void> stopSport() async => throw const WearableSdkNotConfigured();
  @override
  Future<List<SportRecord>> readSportRecords() async => const [];

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() =>
      _runConnected(() async {
        final result = <String, bool>{};
        for (final entry in {'heartRate': 0x16, 'bloodOxygen': 0x2c}.entries) {
          try {
            final response = (await _exchange(entry.value, [1])).single;
            if (response[1] == 1 && (response[2] == 1 || response[2] == 2)) {
              result[entry.key] = response[2] == 1;
            }
          } on PlatformException catch (error) {
            if (!{
              'UNSUPPORTED_DEVICE',
              'DEVICE_TIMEOUT',
              'U19_COMMAND_UNAVAILABLE',
              'U19_HEALTH_UNAVAILABLE',
            }.contains(error.code)) {
              rethrow;
            }
          }
        }
        return result;
      });

  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) =>
      _runConnected(() async {
        final command = switch (type) {
          'heartRate' => 0x16,
          'bloodOxygen' => 0x2c,
          _ => throw PlatformException(
            code: 'UNSUPPORTED_DEVICE',
            message: '当前手表不支持此功能',
          ),
        };
        final before = (await _exchange(command, [1])).single;
        if (before[1] != 1) throw const FormatException('Invalid setting read');
        await _exchange(command, [2, enabled ? 1 : 2]);
        final after = (await _exchange(command, [1])).single;
        if (after[2] != (enabled ? 1 : 2)) {
          throw PlatformException(
            code: 'SETTING_NOT_CONFIRMED',
            message: '设置未生效，请重试',
          );
        }
      });

  @override
  Future<int?> readHeartRateWarning() async => null;
  @override
  Future<void> setHeartRateWarning(int value) async =>
      throw const WearableSdkNotConfigured();

  @override
  Future<Map<String, Object?>> readDeviceFeature(
    DeviceFeature feature,
  ) => _runConnected(() async {
    if (feature == DeviceFeature.u19Pulse) {
      final samples = await _readPulse();
      if (samples.isEmpty) {
        return <String, Object?>{
          'pulse': null,
          'pulseHistory': <Map<String, Object?>>[],
          'awaitingCompletion': _pulseMeasurement != null,
        };
      }
      final sample = samples.first;
      final encoding = _bloodPressureTimeEncoding;
      return <String, Object?>{
        'awaitingCompletion': _pulseMeasurement != null,
        'pulseHistory': samples.map((sample) => _pulseMap(sample)).toList(),
        'pulse': _pulseMap(
          sample,
          measuredAt: encoding == null
              ? null
              : eb1DecodeTimestamp(sample.rawTimestamp, encoding),
        ),
      };
    }
    if (feature == DeviceFeature.basicSettings) {
      final profile = (await _exchange(0x0a, [1])).single;
      final goals = (await _exchange(0x21, [1])).single;
      if (profile[1] != 1 || goals[1] != 1) {
        throw const FormatException('Invalid EB1 settings response');
      }
      final timeLanguage = await _languageStorage.read(
        key: _languageKey(_deviceId!),
      );
      return <String, Object?>{
        'is24Hour': profile[2] == 0,
        'gender': profile[4],
        'age': profile[5],
        'heightCm': profile[6],
        'weightKg': profile[7],
        'stepGoal': eb1UnsignedLittle(goals, 2, 3),
        if (timeLanguage == 'zh' || timeLanguage == 'en')
          'timeLanguage': timeLanguage,
      };
    }
    if (feature == DeviceFeature.screenDisplay) {
      final response = (await _exchange(0x1f, [1])).single;
      if (response[1] != 1 || response[2] < 1 || response[2] > 20) {
        throw const FormatException('Invalid screen setting');
      }
      return <String, Object?>{
        'brightnessSupported': false,
        'brightness': 1,
        'maximumBrightness': 1,
        'automaticBrightness': false,
        'durationSeconds': response[2],
        'minimumDurationSeconds': 1,
        'maximumDurationSeconds': 20,
      };
    }
    if (feature == DeviceFeature.healthMonitoring) {
      final values = <String, Object?>{};
      for (final entry in {'heartRate': 0x16, 'bloodOxygen': 0x2c}.entries) {
        try {
          final response = (await _exchange(entry.value, [1])).single;
          if (response[1] == 1 && {1, 2}.contains(response[2])) {
            values[entry.key] = response[2] == 1;
          }
        } on PlatformException catch (error) {
          if (!{
            'UNSUPPORTED_DEVICE',
            'DEVICE_TIMEOUT',
            'U19_COMMAND_UNAVAILABLE',
            'U19_HEALTH_UNAVAILABLE',
          }.contains(error.code)) {
            rethrow;
          }
        }
      }
      try {
        final dynamic = Eb1DynamicBloodPressureSettings.parse(
          (await _exchange(0x36)).single,
        );
        _dynamicPressure = dynamic;
        values['dynamicBloodPressure'] = dynamic.toMap();
      } on PlatformException catch (error) {
        if (!{
          'UNSUPPORTED_DEVICE',
          'DEVICE_TIMEOUT',
          'U19_COMMAND_UNAVAILABLE',
          'U19_HEALTH_UNAVAILABLE',
        }.contains(error.code)) {
          rethrow;
        }
      }
      return values;
    }
    throw PlatformException(code: 'UNSUPPORTED_DEVICE', message: '当前手表不支持此功能');
  });

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    final requestSession = _session;
    final requestDevice = _deviceId;
    if (feature == DeviceFeature.basicSettings &&
        values['operation'] == 'confirmMeasurementIdle') {
      await _runConnected(() async {
        _measurement = null;
        _bloodPressureResultLimit?.cancel();
        _bloodPressureResultLimit = null;
        _spotMeasurement = null;
        _resultPoll?.cancel();
      });
      return;
    }
    if (feature == DeviceFeature.basicSettings) {
      await _runConnected(() async {
        if (values.length != 1) {
          throw const FormatException(
            'Only one EB1 setting may change at a time',
          );
        }
        final entry = values.entries.single;
        if (entry.key == 'syncTime') {
          final selectedLanguage = entry.value == true
              ? await _languageStorage.read(key: _languageKey(_deviceId!))
              : entry.value;
          if (selectedLanguage != 'zh' && selectedLanguage != 'en') {
            throw const FormatException(
              'Confirm watch language before time sync',
            );
          }
          await _sendWatchTime(selectedLanguage as String);
          await _languageStorage.write(
            key: _languageKey(_deviceId!),
            value: selectedLanguage,
          );
          return;
        }
        if (entry.key == 'stepGoal') {
          final goal = entry.value;
          if (goal is! int || goal < 1 || goal > 0xffffff) {
            throw const FormatException('Invalid EB1 step goal');
          }
          final before = (await _exchange(0x21, [1])).single;
          if (before[1] != 1) {
            throw const FormatException('Invalid EB1 goal read');
          }
          final payload = before.bytes.sublist(2, 15);
          payload[0] = goal & 0xff;
          payload[1] = (goal >> 8) & 0xff;
          payload[2] = (goal >> 16) & 0xff;
          await _exchange(0x21, [2, ...payload]);
          final after = (await _exchange(0x21, [1])).single;
          if (after[1] != 1 || eb1UnsignedLittle(after, 2, 3) != goal) {
            throw PlatformException(
              code: 'SETTING_NOT_CONFIRMED',
              message: '设置未生效，请重试',
            );
          }
          return;
        }
        final field = switch (entry.key) {
          'is24Hour' => 2,
          'gender' => 4,
          'age' => 5,
          'heightCm' => 6,
          'weightKg' => 7,
          _ => throw const FormatException('Unsupported EB1 setting'),
        };
        final value = entry.key == 'is24Hour'
            ? (entry.value == true ? 0 : 1)
            : entry.value;
        if (value is! int ||
            value < 0 ||
            value > 255 ||
            (entry.key == 'gender' && value > 1) ||
            (entry.key == 'age' && (value < 1 || value > 120)) ||
            (entry.key == 'heightCm' && (value < 50 || value > 240)) ||
            (entry.key == 'weightKg' && (value < 10 || value > 250))) {
          throw const FormatException('Invalid EB1 profile value');
        }
        final before = (await _exchange(0x0a, [1])).single;
        if (before[1] != 1) {
          throw const FormatException('Invalid EB1 profile read');
        }
        final payload = before.bytes.sublist(2, 10);
        payload[field - 2] = value;
        await _exchange(0x0a, [2, ...payload]);
        final after = (await _exchange(0x0a, [1])).single;
        if (after[1] != 1 || after[field] != value) {
          throw PlatformException(
            code: 'SETTING_NOT_CONFIRMED',
            message: '设置未生效，请重试',
          );
        }
      });
      return;
    }
    if (feature == DeviceFeature.screenDisplay) {
      final value = values['durationSeconds'];
      if (value is! num || value.toInt() < 1 || value.toInt() > 20) {
        throw const FormatException('Invalid screen timeout');
      }
      await _runConnected(() async {
        final before = (await _exchange(0x1f, [1])).single;
        if (before[1] != 1) throw const FormatException('Invalid setting read');
        await _exchange(0x1f, [2, value.toInt()]);
        final after = (await _exchange(0x1f, [1])).single;
        if (after[2] != value.toInt()) {
          throw PlatformException(
            code: 'SETTING_NOT_CONFIRMED',
            message: '设置未生效，请重试',
          );
        }
      });
      return;
    }
    if (feature == DeviceFeature.healthMonitoring) {
      if (values.containsKey('dynamicBloodPressure')) {
        if (values.length != 1 || values['dynamicBloodPressure'] is! Map) {
          throw const FormatException('Invalid dynamic pressure change');
        }
        final raw = Map<Object?, Object?>.from(
          values['dynamicBloodPressure']! as Map,
        );
        await _runConnected(() async {
          final before = Eb1DynamicBloodPressureSettings.parse(
            (await _exchange(0x36)).single,
          );
          final enabled = raw['enabled'];
          final startHour = raw['startHour'];
          final dayInterval = raw['dayIntervalMinutes'];
          final nightInterval = raw['nightIntervalMinutes'];
          if (enabled is! bool ||
              startHour is! int ||
              startHour < 0 ||
              startHour > 23 ||
              dayInterval is! int ||
              nightInterval is! int ||
              (enabled && !{60, 90, 120, 180}.contains(dayInterval)) ||
              (enabled && !{60, 90, 120, 180}.contains(nightInterval)) ||
              (!enabled &&
                  (dayInterval < 0 ||
                      dayInterval > 255 ||
                      nightInterval < 0 ||
                      nightInterval > 255))) {
            throw const FormatException('Unsafe dynamic pressure settings');
          }
          final requested = Eb1DynamicBloodPressureSettings(
            enabled: enabled,
            startHour: startHour,
            dayIntervalMinutes: dayInterval,
            nightIntervalMinutes: nightInterval,
          );
          if (before.enabled == requested.enabled &&
              before.startHour == requested.startHour &&
              before.dayIntervalMinutes == requested.dayIntervalMinutes &&
              before.nightIntervalMinutes == requested.nightIntervalMinutes) {
            _dynamicPressure = before;
            return;
          }
          await _exchange(0x35, requested.payload);
          final after = Eb1DynamicBloodPressureSettings.parse(
            (await _exchange(0x36)).single,
          );
          if (after.enabled != requested.enabled ||
              after.startHour != requested.startHour ||
              after.dayIntervalMinutes != requested.dayIntervalMinutes ||
              after.nightIntervalMinutes != requested.nightIntervalMinutes) {
            throw PlatformException(
              code: 'SETTING_NOT_CONFIRMED',
              message: '设置未生效，请重试',
            );
          }
          _dynamicPressure = after;
        });
        return;
      }
      for (final entry in values.entries) {
        if (requestSession != _session || requestDevice != _deviceId) {
          throw PlatformException(
            code: 'DEVICE_CHANGED',
            message: '手表连接已变化，请重试',
          );
        }
        if (entry.value is bool) {
          await setAutoMeasureSetting(entry.key, entry.value == true);
        }
      }
      return;
    }
    if (feature == DeviceFeature.u19Pulse) {
      if (values.length == 1 && values['operation'] == 'watchEnded') {
        await _runConnected(() async => _pulseMeasurement = null);
        return;
      }
      if (values.length != 1 || values['operation'] != 'start') {
        throw const FormatException('Invalid pulse action');
      }
      await _runConnected(() async {
        // 三类测量共用同一个传感器操作槽；脉搏入口也必须遵守同样的
        // 互斥约束，不能打断正在充气或等待结果的其他测量。
        if (_pulseMeasurement != null ||
            _measurement != null ||
            _spotMeasurement != null) {
          throw PlatformException(
            code: 'MEASUREMENT_IN_PROGRESS',
            message: '请先在手表上结束本次测量',
          );
        }
        final before = await _readPulse(count: 1);
        final measurement = _Eb1PulseMeasurement(
          session: _session,
          deviceId: _deviceId!,
          startedAt: _now().toUtc(),
          previous: before.map((sample) => sample.fingerprint).toSet(),
        );
        _pulseMeasurement = measurement;
        try {
          await _exchange(0x3a);
          measurement.acknowledged = true;
          _startResultPoll();
        } catch (_) {
          if (identical(_pulseMeasurement, measurement)) {
            _pulseMeasurement = null;
          }
          rethrow;
        }
      });
      return;
    }
    throw PlatformException(code: 'UNSUPPORTED_DEVICE', message: '当前手表不支持此功能');
  }

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {
    if (feature != DeviceFeature.findWatch || !enabled || !_findSupported) {
      throw PlatformException(
        code: 'UNSUPPORTED_DEVICE',
        message: '当前手表不支持此功能',
      );
    }
    await _runConnected(() => _exchange(0x50, [0x55, 0xaa]));
    if (kDebugMode) debugPrint('[U19Find] acknowledged');
  }
}

class _Eb1Pending {
  _Eb1Pending(this.command, this.session, int count)
    : _collector = Eb1ResponseCollector(command, count: count) {
    // A native write can fail before _exchange begins awaiting the response.
    // Register an error listener now so retiring that session is never an
    // unhandled asynchronous exception.
    unawaited(_completer.future.catchError((Object _) => <Eb1Frame>[]));
  }

  final int command;
  final int session;
  final Eb1ResponseCollector _collector;
  final Completer<List<Eb1Frame>> _completer = Completer<List<Eb1Frame>>();

  Future<List<Eb1Frame>> get result => _completer.future;

  void accept(Eb1Frame frame) {
    if (_completer.isCompleted) return;
    try {
      final frames = _collector.add(frame);
      if (frames != null) _completer.complete(frames);
    } catch (error) {
      fail(error);
    }
  }

  void fail(Object error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }
}

class _Eb1Measurement {
  _Eb1Measurement({
    required this.session,
    required this.deviceId,
    required this.startedAt,
    required this.previous,
  });
  final int session;
  final String deviceId;
  final DateTime startedAt;
  final Set<String> previous;
  bool acknowledged = false;
  bool completed = false;
  bool resultReadReady = false;
  bool waitExpired = false;
  bool readQueued = false;
  int notices = 0;
}

class _Eb1SpotMeasurement {
  _Eb1SpotMeasurement({
    required this.session,
    required this.deviceId,
    required this.metric,
    required this.baselineDay,
    required this.startedAt,
    required this.previous,
  });

  final int session;
  final String deviceId;
  final HealthMetric metric;
  final DateTime baselineDay;
  final DateTime startedAt;
  final List<int> previous;
  bool acknowledged = false;
  bool readQueued = false;
  int notices = 0;
}

class _Eb1PulseMeasurement {
  _Eb1PulseMeasurement({
    required this.session,
    required this.deviceId,
    required this.startedAt,
    required this.previous,
  });

  final int session;
  final String deviceId;
  final DateTime startedAt;
  final Set<String> previous;
  bool acknowledged = false;
}
