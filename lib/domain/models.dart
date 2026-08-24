import 'dart:convert';

import 'feature_models.dart';

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
  bodyTemperature('body_temperature', '体温', '℃'),
  ecg('ecg', '心电', ''),
  hrv('hrv', 'HRV', 'ms'),
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

enum SportMode {
  running('running', '跑步'),
  walking('walking', '步行'),
  cycling('cycling', '骑行'),
  hiking('hiking', '徒步');

  const SportMode(this.wireName, this.label);

  final String wireName;
  final String label;

  static SportMode fromWire(String value) => values.firstWhere(
    (mode) => mode.wireName == value,
    orElse: () => SportMode.running,
  );
}

class SportRecord {
  const SportRecord({
    required this.id,
    required this.mode,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceKm,
    required this.calories,
    this.routePoints = const [],
  });

  final String id;
  final SportMode mode;
  final DateTime? startedAt;
  final int durationSeconds;
  final double distanceKm;
  final double calories;
  final List<SportRoutePoint> routePoints;

  factory SportRecord.fromMap(Map<Object?, Object?> map) => SportRecord(
    id: '${map['id'] ?? ''}',
    mode: SportMode.fromWire('${map['mode'] ?? 'running'}'),
    startedAt: DateTime.tryParse('${map['startedAt'] ?? ''}'),
    durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
    distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
    calories: (map['calories'] as num?)?.toDouble() ?? 0,
    routePoints: map['routePoints'] is List
        ? (map['routePoints'] as List)
              .whereType<Map>()
              .map(SportRoutePoint.fromMap)
              .toList()
        : const [],
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'mode': mode.wireName,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'durationSeconds': durationSeconds,
    'distanceKm': distanceKm,
    'calories': calories,
    'routePoints': routePoints.map((point) => point.toMap()).toList(),
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

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    this.model,
    this.serialNumber,
    this.hardwareAddress,
    this.firmwareVersion,
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
  final int? batteryPercent;
  final int? rssi;
  final DateTime? lastSyncAt;

  factory DeviceInfo.fromMap(Map<Object?, Object?> map) => DeviceInfo(
    id: '${map['id'] ?? map['identifier'] ?? ''}',
    name: _displayName(map['name']),
    model: map['model']?.toString(),
    serialNumber: map['serialNumber']?.toString(),
    hardwareAddress: map['hardwareAddress']?.toString(),
    firmwareVersion: map['firmwareVersion']?.toString(),
    batteryPercent: map['batteryPercent'] is num
        ? (map['batteryPercent'] as num).toInt().clamp(0, 100).toInt()
        : null,
    rssi: map['rssi'] is num ? (map['rssi'] as num).toInt() : null,
    lastSyncAt: DateTime.tryParse('${map['lastSyncAt'] ?? ''}'),
  );

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
    return cleaned.isEmpty ? '赛电设备' : cleaned;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'model': model,
    'serialNumber': serialNumber,
    'hardwareAddress': hardwareAddress,
    'firmwareVersion': firmwareVersion,
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
  unknown('--', '未标识');

  const WearableSdkSource(this.shortLabel, this.fullLabel);

  final String shortLabel;
  final String fullLabel;

  static WearableSdkSource fromDeviceId(String deviceId) {
    final normalized = deviceId.trim().toLowerCase();
    if (normalized.startsWith('veepoo:')) return WearableSdkSource.veepoo;
    if (normalized.startsWith('yucheng:')) return WearableSdkSource.yucheng;
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
    this.features = const <DeviceFeature>{},
    this.integratedFeatures = const <DeviceFeature>{},
    this.supportsBackgroundSync = false,
    this.supportsWatchFaces = false,
    this.supportsOta = false,
  });

  final Set<HealthMetric> metrics;
  final Set<HealthMetric>? manualMetrics;
  final Set<DeviceFeature> features;
  final Set<DeviceFeature> integratedFeatures;
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
      features: features,
      integratedFeatures: integratedFeatures,
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
    'features': features.map((feature) => feature.wireName).toList(),
    'integratedFeatures': integratedFeatures
        .map((feature) => feature.wireName)
        .toList(),
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
    this.samples = const [],
  });

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
  final int rawVersion;
  final List<num> samples;

  factory HealthRecord.fromJson(Map<String, Object?> json) {
    final rawValues = json['values'];
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
      source: MeasurementSource.values.firstWhere(
        (source) => source.name == json['source'],
        orElse: () => MeasurementSource.wearable,
      ),
      rawVersion: (json['rawVersion'] as num?)?.toInt() ?? 1,
      samples: json['samples'] is List
          ? (json['samples'] as List).whereType<num>().toList()
          : const [],
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
    'rawVersion': rawVersion,
    if (samples.isNotEmpty) 'samples': samples,
  };

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
  });

  final String id;
  final HealthMetric metric;
  final String title;
  final String message;
  final DateTime triggeredAt;
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
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String memberId;
  final String displayName;

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'memberId': memberId,
    'displayName': displayName,
  };

  factory Session.fromJson(Map<String, Object?> json) => Session(
    accessToken: '${json['accessToken']}',
    refreshToken: '${json['refreshToken']}',
    expiresAt: DateTime.parse('${json['expiresAt']}'),
    memberId: '${json['memberId']}',
    displayName: '${json['displayName']}',
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
