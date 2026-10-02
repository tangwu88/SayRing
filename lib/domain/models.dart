import 'dart:convert';

import 'feature_models.dart';
import 'sleep_timeline.dart';

enum DeviceConnectionState {
  disconnected,
  scanning,
  connecting,
  authenticating,
  syncing,
  ready,
  measuring,
  error,
}

enum HealthMetric {
  steps('steps', '步数', '步'),
  distance('distance', '距离', 'km'),
  calories('calories', '热量', 'kcal'),
  sleep('sleep', '睡眠', 'h'),
  heartRate('heart_rate', '心率', 'bpm'),
  bloodOxygen('blood_oxygen', '血氧', '%'),
  bloodPressure('blood_pressure', '血压', 'mmHg'),
  bloodGlucose('blood_glucose', '血糖', 'mmol/L'),
  bodyTemperature('body_temperature', '皮肤温度', '℃'),
  ecg('ecg', '心电', ''),
  hrv('hrv', 'HRV', 'ms'),
  stress('stress', '压力', ''),
  bodyComposition('body_composition', '身体成分', ''),
  bloodComposition('blood_composition', '血液成分', '');

  const HealthMetric(this.wireName, this.label, this.defaultUnit);

  final String wireName;
  final String label;
  final String defaultUnit;

  static HealthMetric fromWire(String value) => values.firstWhere(
    (metric) => metric.wireName == value,
    orElse: () => HealthMetric.steps,
  );
}

enum MeasurementSource { wearable, manual, imported }

enum MeasurementOrigin {
  watchHistory('watch_history', '戒指历史数据'),
  appMeasurement('app_measurement', 'App 手动测量数据'),
  remoteMember('remote_member', '远程成员数据'),
  manualEntry('manual_entry', '人工录入数据'),
  imported('imported', '导入数据'),
  unknown('unknown', '来源未标记');

  const MeasurementOrigin(this.wireName, this.label);

  final String wireName;
  final String label;

  static MeasurementOrigin fromWire(
    Object? raw, {
    required MeasurementSource source,
  }) {
    final value = '${raw ?? ''}'.trim();
    for (final origin in values) {
      if (origin.wireName == value || origin.name == value) return origin;
    }
    return switch (source) {
      MeasurementSource.wearable => MeasurementOrigin.watchHistory,
      MeasurementSource.manual => MeasurementOrigin.manualEntry,
      MeasurementSource.imported => MeasurementOrigin.imported,
    };
  }
}

enum SportMode {
  running('running', '跑步'),
  indoorRunning('indoor_running', '室内跑'),
  walking('walking', '步行'),
  cycling('cycling', '骑行'),
  indoorCycling('indoor_cycling', '室内骑行'),
  basketball('basketball', '篮球'),
  football('football', '足球'),
  badminton('badminton', '羽毛球'),
  swimming('swimming', '游泳'),
  jumpRope('jump_rope', '跳绳'),
  yoga('yoga', '瑜伽'),
  hiking('hiking', '徒步'),
  mountaineering('mountaineering', '登山');

  const SportMode(this.wireName, this.label);

  final String wireName;
  final String label;

  static SportMode fromWire(String value) => values.firstWhere(
    (mode) => mode.wireName == value,
    orElse: () => SportMode.running,
  );

  static SportMode? tryFromWire(String value) {
    for (final mode in values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}

class SportRecord {
  const SportRecord({
    required this.id,
    required this.mode,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceKm,
    required this.calories,
    this.steps = 0,
    this.heartRate = 0,
    this.minimumHeartRate = 0,
    this.maximumHeartRate = 0,
    this.routePoints = const [],
    this.heartRateSamples = const [],
  });

  final String id;
  final SportMode mode;
  final DateTime? startedAt;
  final int durationSeconds;
  final double distanceKm;
  final double calories;
  final int steps;
  final int heartRate;
  final int minimumHeartRate;
  final int maximumHeartRate;
  final List<SportRoutePoint> routePoints;
  final List<SportHeartRateSample> heartRateSamples;

  /// Average active pace. Unknown indoor distance remains unknown.
  double? get paceSecondsPerKm => distanceKm > 0 && durationSeconds > 0
      ? durationSeconds / distanceKm
      : null;

  factory SportRecord.fromMap(Map<Object?, Object?> map) => SportRecord(
    id: '${map['id'] ?? ''}',
    mode: SportMode.fromWire('${map['mode'] ?? 'running'}'),
    startedAt: DateTime.tryParse('${map['startedAt'] ?? ''}'),
    durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
    distanceKm: map.containsKey('distanceKm')
        ? _number(map['distanceKm'])
        : _number(map['distanceMeters']) / 1000,
    calories: map.containsKey('calories')
        ? _number(map['calories'])
        : _number(map['caloriesCal']) / 1000,
    steps: (map['steps'] as num?)?.toInt() ?? 0,
    heartRate: (map['heartRate'] as num?)?.toInt() ?? 0,
    minimumHeartRate: (map['minimumHeartRate'] as num?)?.toInt() ?? 0,
    maximumHeartRate: (map['maximumHeartRate'] as num?)?.toInt() ?? 0,
    routePoints: map['routePoints'] is List
        ? (map['routePoints'] as List)
              .whereType<Map>()
              .map(SportRoutePoint.fromMap)
              .toList()
        : const [],
    heartRateSamples: map['heartRateSamples'] is List
        ? (map['heartRateSamples'] as List)
              .whereType<Map>()
              .map(SportHeartRateSample.fromMap)
              .toList()
        : const [],
  );

  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  Map<String, Object?> toMap() => {
    'id': id,
    'mode': mode.wireName,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'durationSeconds': durationSeconds,
    'distanceKm': distanceKm,
    'calories': calories,
    'steps': steps,
    'heartRate': heartRate,
    'minimumHeartRate': minimumHeartRate,
    'maximumHeartRate': maximumHeartRate,
    'routePoints': routePoints.map((point) => point.toMap()).toList(),
    'heartRateSamples': heartRateSamples
        .map((sample) => sample.toMap())
        .toList(),
  };
}

class SportHeartRateSample {
  const SportHeartRateSample({required this.elapsedSeconds, required this.bpm});

  final int elapsedSeconds;
  final int bpm;

  factory SportHeartRateSample.fromMap(Map<Object?, Object?> map) =>
      SportHeartRateSample(
        elapsedSeconds: (map['elapsedSeconds'] as num?)?.toInt() ?? 0,
        bpm: (map['bpm'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toMap() => {
    'elapsedSeconds': elapsedSeconds,
    'bpm': bpm,
  };
}

class SportRoutePoint {
  const SportRoutePoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? accuracy;

  factory SportRoutePoint.fromMap(Map<Object?, Object?> map) => SportRoutePoint(
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
    recordedAt:
        DateTime.tryParse('${map['recordedAt'] ?? ''}') ?? DateTime.now(),
    accuracy: (map['accuracy'] as num?)?.toDouble(),
  );

  Map<String, Object?> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'accuracy': accuracy,
  };
}

enum DeviceBatteryChargeState {
  normal,
  charging,
  lowPressureDeprecated,
  fullUnreliable,
  unknown;

  factory DeviceBatteryChargeState.fromWire(Object? value) =>
      switch ('${value ?? ''}'.trim().toLowerCase()) {
        'normal' => normal,
        'charging' => charging,
        'low_pressure_deprecated' => lowPressureDeprecated,
        'full_unreliable' => fullUnreliable,
        _ => unknown,
      };

  String get wireName => switch (this) {
    normal => 'normal',
    charging => 'charging',
    lowPressureDeprecated => 'low_pressure_deprecated',
    fullUnreliable => 'full_unreliable',
    unknown => 'unknown',
  };

  String get label => switch (this) {
    charging => '充电中',
    lowPressureDeprecated => '低电状态',
    normal => '未充电',
    fullUnreliable || unknown => '充电状态未知',
  };
}

class DeviceBatteryInfo {
  const DeviceBatteryInfo({
    required this.value,
    required this.scale,
    required this.isPercent,
    required this.chargeState,
    this.low,
    this.updatedAt,
  });

  final int value;
  final int scale;
  final bool isPercent;
  final bool? low;
  final DeviceBatteryChargeState chargeState;
  final DateTime? updatedAt;

  int? get percent => isPercent ? value : null;
  bool get isCharging => chargeState == DeviceBatteryChargeState.charging;
  bool get isLow => low ?? (!isPercent && value <= 1);
  String get displayLabel => isPercent ? '$value%' : '$value/$scale 格';

  factory DeviceBatteryInfo.percentage(int value) => DeviceBatteryInfo(
    value: value.clamp(0, 100),
    scale: 100,
    isPercent: true,
    chargeState: DeviceBatteryChargeState.unknown,
  );

  static DeviceBatteryInfo? tryFromDeviceMap(Map<Object?, Object?> map) {
    final nested = map['battery'];
    if (nested is Map) {
      return _tryParse(
        nested.map((key, value) => MapEntry<Object?, Object?>(key, value)),
      );
    }
    final hasStructuredFields = const [
      'batteryValue',
      'batteryScale',
      'batteryIsPercent',
      'batteryChargeState',
      'batteryUpdatedAt',
    ].any(map.containsKey);
    if (hasStructuredFields) {
      return _tryParse(<Object?, Object?>{
        'value': map['batteryValue'],
        'scale': map['batteryScale'],
        'isPercent': map['batteryIsPercent'],
        'low': map['batteryLow'],
        'chargeState': map['batteryChargeState'],
        'updatedAt': map['batteryUpdatedAt'],
      });
    }
    final legacy = _batteryInt(map['batteryPercent']);
    return legacy == null || legacy < 0 || legacy > 100
        ? null
        : DeviceBatteryInfo.percentage(legacy);
  }

  static DeviceBatteryInfo? _tryParse(Map<Object?, Object?> map) {
    final value = _batteryInt(map['value']);
    final scale = _batteryInt(map['scale']);
    final isPercent = map['isPercent'];
    if (value == null ||
        scale == null ||
        isPercent is! bool ||
        (scale != 4 && scale != 100) ||
        isPercent != (scale == 100) ||
        value < 0 ||
        value > scale) {
      return null;
    }
    final rawLow = map['low'];
    if (rawLow != null && rawLow is! bool) return null;
    final updatedAt = DateTime.tryParse('${map['updatedAt'] ?? ''}');
    return DeviceBatteryInfo(
      value: value,
      scale: scale,
      isPercent: isPercent,
      low: isPercent ? rawLow as bool? : null,
      chargeState: DeviceBatteryChargeState.fromWire(map['chargeState']),
      updatedAt: updatedAt?.toUtc(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'value': value,
    'scale': scale,
    'isPercent': isPercent,
    'low': low,
    'chargeState': chargeState.wireName,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}

int? _batteryInt(Object? value) => value is num
    ? value.toInt()
    : value is String
    ? int.tryParse(value.trim())
    : null;

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    this.model,
    this.serialNumber,
    this.hardwareAddress,
    this.firmwareVersion,
    this.battery,
    this.batteryPercent,
    this.rssi,
    this.lastSyncAt,
  });

  final String id;
  final String name;
  final String? model;
  final String? serialNumber;
  final String? hardwareAddress;
  final String? firmwareVersion;
  final DeviceBatteryInfo? battery;
  final int? batteryPercent;
  final int? rssi;
  final DateTime? lastSyncAt;

  factory DeviceInfo.fromMap(Map<Object?, Object?> map) {
    final battery = DeviceBatteryInfo.tryFromDeviceMap(map);
    return DeviceInfo(
      id: '${map['id'] ?? map['identifier'] ?? ''}',
      name: _displayName(map['name']),
      model: map['model']?.toString(),
      serialNumber: map['serialNumber']?.toString(),
      hardwareAddress: map['hardwareAddress']?.toString(),
      firmwareVersion: map['firmwareVersion']?.toString(),
      battery: battery,
      batteryPercent: battery?.percent,
      rssi: map['rssi'] is num ? (map['rssi'] as num).toInt() : null,
      lastSyncAt: DateTime.tryParse('${map['lastSyncAt'] ?? ''}'),
    );
  }

  DeviceBatteryInfo? get effectiveBattery =>
      battery ??
      (batteryPercent == null
          ? null
          : DeviceBatteryInfo.percentage(batteryPercent!));

  static String _displayName(Object? raw) {
    final cleaned = '${raw ?? ''}'
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F\uFFFD]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    final normalized = cleaned.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (normalized.contains('W9S')) return 'SD-Watch-W9S';
    if (normalized.contains('W9')) return 'SD-Watch-W9';
    return cleaned.isEmpty ? 'Say Ring device' : cleaned;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'model': model,
    'serialNumber': serialNumber,
    'hardwareAddress': hardwareAddress,
    'firmwareVersion': firmwareVersion,
    'battery': battery?.toJson(),
    'batteryPercent': batteryPercent,
    'rssi': rssi,
    'lastSyncAt': lastSyncAt?.toUtc().toIso8601String(),
  };

  WearableSdkSource get sdkSource => WearableSdkSource.fromDeviceId(id);

  String get nativeId {
    final source = sdkSource;
    if (source == WearableSdkSource.unknown) return id;
    return id.substring(id.indexOf(':') + 1);
  }

  String get displayModel {
    final reportedModel = model?.trim() ?? '';
    if (reportedModel.isNotEmpty) return reportedModel;
    final separator = name.lastIndexOf('-');
    if (separator < 0) return '--';
    final suffix = name.substring(separator + 1).trim();
    return suffix.isEmpty ? '--' : suffix;
  }

  /// Upload only hardware metadata, never derive a MAC from an iOS UUID.
  String? get verifiedHardwareMacAddress {
    final value = hardwareAddress?.trim() ?? '';
    final separated = value.replaceAll('-', ':').toUpperCase();
    if (RegExp(r'^(?:[0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(separated)) {
      return separated;
    }
    if (RegExp(r'^[0-9A-Fa-f]{12}$').hasMatch(value)) {
      return List.generate(
        6,
        (index) => value.substring(index * 2, index * 2 + 2),
      ).join(':').toUpperCase();
    }
    return null;
  }

  String? get macAddress {
    for (final candidate in [hardwareAddress, nativeId]) {
      final value = candidate?.trim() ?? '';
      if (value.isEmpty) continue;
      final separated = value.replaceAll('-', ':').toUpperCase();
      if (RegExp(r'^(?:[0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(separated)) {
        return separated;
      }
      final compact = value.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
      if (compact.length == 12) {
        return List.generate(
          6,
          (index) => compact.substring(index * 2, index * 2 + 2),
        ).join(':').toUpperCase();
      }
    }
    return null;
  }

  String get identifierLabel {
    final address = macAddress;
    if (address != null) return 'MAC · $address';
    final identifier = nativeId;
    if (RegExp(
      r'^[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$',
    ).hasMatch(identifier)) {
      return 'iOS 连接标识 · ${identifier.substring(0, 8)}…${identifier.substring(identifier.length - 8)}';
    }
    return '设备标识 · $identifier';
  }
}

enum WearableSdkSource {
  veepoo('Vep', 'Veepoo'),
  yucheng('Yuc', 'Yucheng'),
  moyoung('Moy', 'Moyoung'),
  coolwear('Coo', 'CoolWear'),
  qring('QR', 'QRing'),
  unknown('--', '未标识');

  const WearableSdkSource(this.shortLabel, this.fullLabel);

  final String shortLabel;
  final String fullLabel;

  static WearableSdkSource fromDeviceId(String deviceId) {
    final normalized = deviceId.trim().toLowerCase();
    if (normalized.startsWith('veepoo:')) return WearableSdkSource.veepoo;
    if (normalized.startsWith('yucheng:')) return WearableSdkSource.yucheng;
    if (normalized.startsWith('moyoung:')) return WearableSdkSource.moyoung;
    if (normalized.startsWith('coolwear:')) return WearableSdkSource.coolwear;
    if (normalized.startsWith('qring:')) return WearableSdkSource.qring;
    return WearableSdkSource.unknown;
  }
}

class WearableUserProfile {
  const WearableUserProfile({
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.birthYear,
    required this.age,
    required this.targetSteps,
  });

  final int gender;
  final int heightCm;
  final int weightKg;
  final int birthYear;
  final int age;
  final int targetSteps;

  factory WearableUserProfile.fromMember(
    Map<String, Object?> member, {
    required int targetSteps,
  }) {
    final birthday = DateTime.tryParse('${member['birthday'] ?? ''}');
    final now = DateTime.now();
    var age = birthday == null ? 30 : now.year - birthday.year;
    if (birthday != null &&
        (now.month < birthday.month ||
            (now.month == birthday.month && now.day < birthday.day))) {
      age--;
    }
    return WearableUserProfile(
      gender: (int.tryParse('${member['gender'] ?? 1}') ?? 1).clamp(1, 2),
      heightCm: (num.tryParse('${member['height'] ?? ''}')?.round() ?? 175)
          .clamp(80, 240),
      weightKg: (num.tryParse('${member['weight'] ?? ''}')?.round() ?? 70)
          .clamp(20, 250),
      birthYear: (birthday?.year ?? (now.year - 30)).clamp(1900, now.year),
      age: age.clamp(5, 120),
      targetSteps: targetSteps.clamp(1000, 100000),
    );
  }

  Map<String, Object?> toMap() => {
    'gender': gender,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'birthYear': birthYear,
    'age': age,
    'targetSteps': targetSteps,
  };
}

class DeviceCapabilities {
  const DeviceCapabilities({
    required this.metrics,
    this.manualMetrics,
    this.sportModes,
    this.features = const <DeviceFeature>{},
    this.integratedFeatures = const <DeviceFeature>{},
    this.supportsSportPause = false,
    this.supportsBackgroundSync = false,
    this.supportsWatchFaces = false,
    this.supportsOta = false,
  });

  final Set<HealthMetric> metrics;
  final Set<HealthMetric>? manualMetrics;

  /// Sports that the connected watch can enter from the phone.
  ///
  /// `null` means an older bridge did not report this capability. An empty
  /// set is a resolved device that does not expose app-controlled sports.
  final Set<SportMode>? sportModes;
  final Set<DeviceFeature> features;
  final Set<DeviceFeature> integratedFeatures;
  final bool supportsSportPause;
  final bool supportsBackgroundSync;
  final bool supportsWatchFaces;
  final bool supportsOta;

  factory DeviceCapabilities.fromMap(Map<Object?, Object?> map) {
    final raw = map['metrics'];
    final metrics = raw is List
        ? raw.map((value) => HealthMetric.fromWire('$value')).toSet()
        : <HealthMetric>{};
    final rawFeatures = map['features'];
    final rawManualMetrics = map['manualMetrics'];
    final manualMetrics = rawManualMetrics is List
        ? rawManualMetrics
              .map((value) => HealthMetric.fromWire('$value'))
              .toSet()
        : null;
    final rawSportModes = map['sportModes'];
    final sportModes = rawSportModes is List
        ? rawSportModes
              .map((value) => SportMode.tryFromWire('$value'))
              .whereType<SportMode>()
              .toSet()
        : null;
    final features = rawFeatures is List
        ? rawFeatures
              .map((value) => DeviceFeature.tryFromWire('$value'))
              .whereType<DeviceFeature>()
              .toSet()
        : <DeviceFeature>{};
    if (map['supportsWatchFaces'] == true) {
      features.add(DeviceFeature.watchFaces);
    }
    final rawIntegratedFeatures = map['integratedFeatures'];
    final integratedFeatures = rawIntegratedFeatures is List
        ? rawIntegratedFeatures
              .map((value) => DeviceFeature.tryFromWire('$value'))
              .whereType<DeviceFeature>()
              .toSet()
        : <DeviceFeature>{};
    return DeviceCapabilities(
      metrics: metrics,
      manualMetrics: manualMetrics,
      sportModes: sportModes,
      features: features,
      integratedFeatures: integratedFeatures,
      supportsSportPause: map['supportsSportPause'] == true,
      supportsBackgroundSync: map['supportsBackgroundSync'] == true,
      supportsWatchFaces: map['supportsWatchFaces'] == true,
      supportsOta: map['supportsOta'] == true,
    );
  }

  bool supports(HealthMetric metric) => metrics.contains(metric);

  bool supportsManualMeasurement(HealthMetric metric) =>
      manualMetrics?.contains(metric) ?? supports(metric);

  bool supportsFeature(DeviceFeature feature) => features.contains(feature);

  Map<String, Object?> toJson() => {
    'metrics': metrics.map((metric) => metric.wireName).toList(),
    if (manualMetrics != null)
      'manualMetrics': manualMetrics!.map((metric) => metric.wireName).toList(),
    if (sportModes != null)
      'sportModes': sportModes!.map((mode) => mode.wireName).toList(),
    'features': features.map((feature) => feature.wireName).toList(),
    'integratedFeatures': integratedFeatures
        .map((feature) => feature.wireName)
        .toList(),
    'supportsSportPause': supportsSportPause,
    'supportsBackgroundSync': supportsBackgroundSync,
    'supportsWatchFaces': supportsWatchFaces,
    'supportsOta': supportsOta,
  };
}

class HealthRecord {
  HealthRecord({
    required this.id,
    required this.metric,
    required this.values,
    required this.unit,
    required this.measuredAt,
    required this.timezone,
    required this.deviceId,
    required this.firmwareVersion,
    required this.quality,
    required this.source,
    required this.rawVersion,
    MeasurementOrigin? origin,
    this.samples = const [],
    this.sourceModel = '',
    this.sourceVendor = '',
    this.sourceDeviceCategory = '',
    this.sourceApp = '',
    this.sleepTimeline,
  }) : origin = origin ?? MeasurementOrigin.fromWire(null, source: source);

  final String id;
  final HealthMetric metric;
  final Map<String, num> values;
  final String unit;
  final DateTime measuredAt;
  final String timezone;
  final String deviceId;
  final String firmwareVersion;
  final String quality;
  final MeasurementSource source;
  final MeasurementOrigin origin;
  final int rawVersion;
  final List<num> samples;
  final String sourceModel;
  final String sourceVendor;
  final String sourceDeviceCategory;
  final String sourceApp;
  final SleepTimeline? sleepTimeline;

  factory HealthRecord.fromJson(Map<String, Object?> json) {
    final rawValues = json['values'];
    final source = MeasurementSource.values.firstWhere(
      (source) => source.name == json['source'],
      orElse: () => MeasurementSource.wearable,
    );
    return HealthRecord(
      id: '${json['id']}',
      metric: HealthMetric.fromWire('${json['type']}'),
      values: rawValues is Map
          ? rawValues.map(
              (key, value) =>
                  MapEntry('$key', value is num ? value : num.parse('$value')),
            )
          : <String, num>{},
      unit: '${json['unit'] ?? ''}',
      measuredAt: DateTime.parse('${json['measuredAt']}').toUtc(),
      timezone: '${json['timezone'] ?? '+08:00'}',
      deviceId: '${json['deviceId'] ?? ''}',
      firmwareVersion: '${json['firmwareVersion'] ?? ''}',
      quality: '${json['quality'] ?? 'unknown'}',
      source: source,
      origin: MeasurementOrigin.fromWire(
        json['origin'] ?? json['captureMode'],
        source: source,
      ),
      rawVersion: (json['rawVersion'] as num?)?.toInt() ?? 1,
      samples: json['samples'] is List
          ? (json['samples'] as List).whereType<num>().toList()
          : const [],
      sourceModel: '${json['sourceModel'] ?? ''}'.trim(),
      sourceVendor: '${json['sourceVendor'] ?? ''}'.trim(),
      sourceDeviceCategory: '${json['sourceDeviceCategory'] ?? ''}'.trim(),
      sourceApp: '${json['sourceApp'] ?? ''}'.trim(),
      sleepTimeline: json['sleepTimeline'] is Map
          ? SleepTimeline.fromJson(
              (json['sleepTimeline'] as Map).map(
                (key, value) => MapEntry('$key', value),
              ),
            )
          : null,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'type': metric.wireName,
    'values': values,
    'unit': unit,
    'measuredAt': measuredAt.toUtc().toIso8601String(),
    'timezone': timezone,
    'deviceId': deviceId,
    'firmwareVersion': firmwareVersion,
    'quality': quality,
    'source': source.name,
    'origin': origin.wireName,
    'rawVersion': rawVersion,
    if (samples.isNotEmpty) 'samples': samples,
    if (sourceModel.isNotEmpty) 'sourceModel': sourceModel,
    if (sourceVendor.isNotEmpty) 'sourceVendor': sourceVendor,
    if (sourceDeviceCategory.isNotEmpty)
      'sourceDeviceCategory': sourceDeviceCategory,
    if (sourceApp.isNotEmpty) 'sourceApp': sourceApp,
    if (sleepTimeline != null) 'sleepTimeline': sleepTimeline!.toJson(),
  };

  HealthRecord copyWith({
    Map<String, num>? values,
    String? quality,
    MeasurementSource? source,
    MeasurementOrigin? origin,
    int? rawVersion,
    List<num>? samples,
    String? deviceId,
    String? firmwareVersion,
    String? sourceModel,
    String? sourceVendor,
    String? sourceDeviceCategory,
    String? sourceApp,
    SleepTimeline? sleepTimeline,
  }) => HealthRecord(
    id: id,
    metric: metric,
    values: values ?? this.values,
    unit: unit,
    measuredAt: measuredAt,
    timezone: timezone,
    deviceId: deviceId ?? this.deviceId,
    firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    quality: quality ?? this.quality,
    source: source ?? this.source,
    origin: origin ?? this.origin,
    rawVersion: rawVersion ?? this.rawVersion,
    samples: samples ?? this.samples,
    sourceModel: sourceModel ?? this.sourceModel,
    sourceVendor: sourceVendor ?? this.sourceVendor,
    sourceDeviceCategory: sourceDeviceCategory ?? this.sourceDeviceCategory,
    sourceApp: sourceApp ?? this.sourceApp,
    sleepTimeline: sleepTimeline ?? this.sleepTimeline,
  );

  String get displayValue {
    if (metric == HealthMetric.bloodPressure) {
      final systolic = values['systolic'];
      final diastolic = values['diastolic'];
      if (systolic != null && diastolic != null) {
        return '${_number(systolic)}/${_number(diastolic)}';
      }
    }
    final value =
        values['value'] ?? (values.isEmpty ? null : values.values.first);
    return value == null ? '--' : _number(value);
  }

  static String _number(num value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

  String encode() => jsonEncode(toJson());
}

class HealthWarningSettings {
  const HealthWarningSettings({
    this.heartRateEnabled = false,
    this.heartRateUpper = 120,
    this.bloodPressureEnabled = false,
    this.systolicUpper = 140,
    this.diastolicUpper = 90,
    this.temperatureEnabled = false,
    this.temperatureUpper = 37.5,
  });

  final bool heartRateEnabled;
  final int heartRateUpper;
  final bool bloodPressureEnabled;
  final int systolicUpper;
  final int diastolicUpper;
  final bool temperatureEnabled;
  final double temperatureUpper;

  Map<String, Object?> toJson() => {
    'heartRateEnabled': heartRateEnabled,
    'heartRateUpper': heartRateUpper,
    'bloodPressureEnabled': bloodPressureEnabled,
    'systolicUpper': systolicUpper,
    'diastolicUpper': diastolicUpper,
    'temperatureEnabled': temperatureEnabled,
    'temperatureUpper': temperatureUpper,
  };

  factory HealthWarningSettings.fromJson(Map<String, Object?> json) =>
      HealthWarningSettings(
        heartRateEnabled: json['heartRateEnabled'] == true,
        heartRateUpper: (json['heartRateUpper'] as num?)?.toInt() ?? 120,
        bloodPressureEnabled: json['bloodPressureEnabled'] == true,
        systolicUpper: (json['systolicUpper'] as num?)?.toInt() ?? 140,
        diastolicUpper: (json['diastolicUpper'] as num?)?.toInt() ?? 90,
        temperatureEnabled: json['temperatureEnabled'] == true,
        temperatureUpper:
            (json['temperatureUpper'] as num?)?.toDouble() ?? 37.5,
      );
}

class HealthWarningAlert {
  const HealthWarningAlert({
    required this.id,
    required this.metric,
    required this.title,
    required this.message,
    required this.triggeredAt,
    this.origin = MeasurementOrigin.unknown,
  });

  final String id;
  final HealthMetric metric;
  final String title;
  final String message;
  final DateTime triggeredAt;
  final MeasurementOrigin origin;

  Map<String, Object?> toJson() => {
    'id': id,
    'metric': metric.wireName,
    'title': title,
    'message': message,
    'triggeredAt': triggeredAt.toUtc().toIso8601String(),
    'origin': origin.wireName,
  };

  factory HealthWarningAlert.fromJson(Map<String, Object?> json) =>
      HealthWarningAlert(
        id: '${json['id'] ?? ''}',
        metric: HealthMetric.fromWire('${json['metric'] ?? ''}'),
        title: '${json['title'] ?? ''}',
        message: '${json['message'] ?? ''}',
        triggeredAt:
            DateTime.tryParse('${json['triggeredAt'] ?? ''}')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        origin: MeasurementOrigin.fromWire(
          json['origin'],
          source: MeasurementSource.wearable,
        ),
      );
}

class SyncBatch {
  const SyncBatch({required this.cursor, required this.records});

  final String? cursor;
  final List<HealthRecord> records;

  Map<String, Object?> toJson() => {
    'cursor': cursor,
    'records': records.map((record) => record.toJson()).toList(),
  };
}

class CarePermission {
  const CarePermission({
    required this.memberId,
    required this.metrics,
    required this.accepted,
    this.expiresAt,
  });

  factory CarePermission.privateByDefault(String memberId) => CarePermission(
    memberId: memberId,
    metrics: const <HealthMetric>{},
    accepted: false,
  );

  final String memberId;
  final Set<HealthMetric> metrics;
  final bool accepted;
  final DateTime? expiresAt;

  bool canRead(HealthMetric metric, {DateTime? now}) {
    if (!accepted || !metrics.contains(metric)) return false;
    if (expiresAt == null) return true;
    return expiresAt!.isAfter(now ?? DateTime.now());
  }
}

class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.memberId,
    required this.displayName,
    this.accountKey = '',
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String memberId;
  final String displayName;
  final String accountKey;

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'memberId': memberId,
    'displayName': displayName,
    if (accountKey.isNotEmpty) 'accountKey': accountKey,
  };

  factory Session.fromJson(Map<String, Object?> json) => Session(
    accessToken: '${json['accessToken']}',
    refreshToken: '${json['refreshToken']}',
    expiresAt: DateTime.parse('${json['expiresAt']}'),
    memberId: '${json['memberId']}',
    displayName: '${json['displayName']}',
    accountKey: '${json['accountKey'] ?? ''}',
  );

  Session copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? memberId,
    String? displayName,
    String? accountKey,
  }) => Session(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresAt: expiresAt ?? this.expiresAt,
    memberId: memberId ?? this.memberId,
    displayName: displayName ?? this.displayName,
    accountKey: accountKey ?? this.accountKey,
  );
}

class WearableEvent {
  const WearableEvent({required this.type, required this.payload});

  final String type;
  final Map<String, Object?> payload;

  factory WearableEvent.fromMap(Map<Object?, Object?> map) {
    final rawPayload = map['payload'];
    final payloadSource = rawPayload is Map
        ? Map<Object?, Object?>.from(rawPayload)
        : Map<Object?, Object?>.fromEntries(
            map.entries.where((entry) => entry.key != 'type'),
          );
    return WearableEvent(
      type: '${map['type'] ?? 'unknown'}',
      payload: payloadSource.map((key, value) => MapEntry('$key', value)),
    );
  }
}
