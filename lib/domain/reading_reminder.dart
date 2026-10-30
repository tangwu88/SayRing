import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'health_reminder.dart';
import 'models.dart';

/// A personal reference belongs to one physical ring and firmware, not a name.
String readingReminderReferenceKey(DeviceInfo device) => sha256
    .convert(utf8.encode('${device.id}|${device.firmwareVersion ?? ''}'))
    .toString();

/// Personal reading limits, separate from reviewed clinical monitoring rules.
/// Saving limits never enables a sensor, changes a device setting or claims a
/// continuous stream. A member explicitly enables each reminder.
final class ReadingReminderSettings {
  const ReadingReminderSettings({
    this.highEnabled = false,
    this.lowEnabled = false,
    this.oxygenEnabled = false,
    this.hrvEnabled = false,
    this.temperatureEnabled = false,
    this.hrvBaselineMs,
    this.hrvReferenceKey,
    this.hrvDropPercent = 30,
    this.skinTemperatureBaseline,
    this.temperatureReferenceKey,
    this.temperatureRiseC = 0.8,
    this.ringVibrationEnabled = true,
    this.phoneSoundEnabled = true,
    this.high = 120,
    this.low = 40,
    this.oxygen = 92,
  });

  final bool highEnabled;
  final bool lowEnabled;
  final bool oxygenEnabled;
  final bool hrvEnabled;
  final bool temperatureEnabled;
  final double? hrvBaselineMs;
  final String? hrvReferenceKey;
  final int hrvDropPercent;
  final double? skinTemperatureBaseline;
  final String? temperatureReferenceKey;
  final double temperatureRiseC;
  final bool ringVibrationEnabled;
  final bool phoneSoundEnabled;
  final int high;
  final int low;
  final int oxygen;
  bool get enabled =>
      highEnabled ||
      lowEnabled ||
      oxygenEnabled ||
      hrvEnabled ||
      temperatureEnabled;
  bool hrvReadyFor(DeviceInfo device) =>
      hrvBaselineMs != null &&
      hrvReferenceKey == readingReminderReferenceKey(device);
  bool temperatureReadyFor(DeviceInfo device) =>
      skinTemperatureBaseline != null &&
      temperatureReferenceKey == readingReminderReferenceKey(device);
  static bool _referenceValid(
    double? value,
    String? key,
    double min,
    double max,
  ) =>
      (value == null && key == null) ||
      (value != null &&
          value.isFinite &&
          value >= min &&
          value <= max &&
          key != null &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(key));
  bool get valid =>
      high >= 80 &&
      high <= 200 &&
      low >= 30 &&
      low <= 80 &&
      low < high &&
      oxygen >= 80 &&
      oxygen <= 95 &&
      hrvDropPercent >= 10 &&
      hrvDropPercent <= 60 &&
      temperatureRiseC.isFinite &&
      temperatureRiseC >= 0.3 &&
      temperatureRiseC <= 3 &&
      _referenceValid(hrvBaselineMs, hrvReferenceKey, 1, 300) &&
      _referenceValid(
        skinTemperatureBaseline,
        temperatureReferenceKey,
        20,
        40,
      ) &&
      (!hrvEnabled || hrvBaselineMs != null) &&
      (!temperatureEnabled || skinTemperatureBaseline != null);

  ReadingReminderSettings copyWith({
    bool? highEnabled,
    bool? lowEnabled,
    bool? oxygenEnabled,
    bool? hrvEnabled,
    bool? temperatureEnabled,
    double? hrvBaselineMs,
    String? hrvReferenceKey,
    int? hrvDropPercent,
    double? skinTemperatureBaseline,
    String? temperatureReferenceKey,
    double? temperatureRiseC,
    bool? ringVibrationEnabled,
    bool? phoneSoundEnabled,
    int? high,
    int? low,
    int? oxygen,
  }) => ReadingReminderSettings(
    highEnabled: highEnabled ?? this.highEnabled,
    lowEnabled: lowEnabled ?? this.lowEnabled,
    oxygenEnabled: oxygenEnabled ?? this.oxygenEnabled,
    hrvEnabled: hrvEnabled ?? this.hrvEnabled,
    temperatureEnabled: temperatureEnabled ?? this.temperatureEnabled,
    hrvBaselineMs: hrvBaselineMs ?? this.hrvBaselineMs,
    hrvReferenceKey: hrvReferenceKey ?? this.hrvReferenceKey,
    hrvDropPercent: hrvDropPercent ?? this.hrvDropPercent,
    skinTemperatureBaseline:
        skinTemperatureBaseline ?? this.skinTemperatureBaseline,
    temperatureReferenceKey:
        temperatureReferenceKey ?? this.temperatureReferenceKey,
    temperatureRiseC: temperatureRiseC ?? this.temperatureRiseC,
    ringVibrationEnabled: ringVibrationEnabled ?? this.ringVibrationEnabled,
    phoneSoundEnabled: phoneSoundEnabled ?? this.phoneSoundEnabled,
    high: high ?? this.high,
    low: low ?? this.low,
    oxygen: oxygen ?? this.oxygen,
  );

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'highEnabled': highEnabled,
    'lowEnabled': lowEnabled,
    'oxygenEnabled': oxygenEnabled,
    'hrvEnabled': hrvEnabled,
    'temperatureEnabled': temperatureEnabled,
    'hrvBaselineMs': ?hrvBaselineMs,
    'hrvReferenceKey': ?hrvReferenceKey,
    'hrvDropPercent': hrvDropPercent,
    'skinTemperatureBaseline': ?skinTemperatureBaseline,
    'temperatureReferenceKey': ?temperatureReferenceKey,
    'temperatureRiseC': temperatureRiseC,
    'ringVibrationEnabled': ringVibrationEnabled,
    'phoneSoundEnabled': phoneSoundEnabled,
    'high': high,
    'low': low,
    'oxygen': oxygen,
  };
  String get fingerprint =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();
  // A delivery preference must not turn the same measurement into a new event.
  String get comparisonFingerprint => sha256
      .convert(utf8.encode(jsonEncode(toJson()..remove('phoneSoundEnabled'))))
      .toString();
  static ReadingReminderSettings? parse(String? value) {
    try {
      final raw = jsonDecode(value ?? '');
      if (raw is! Map ||
          raw['schemaVersion'] != 1 ||
          raw['highEnabled'] is! bool ||
          raw['lowEnabled'] is! bool ||
          raw['oxygenEnabled'] is! bool ||
          (raw.containsKey('hrvEnabled') && raw['hrvEnabled'] is! bool) ||
          (raw.containsKey('temperatureEnabled') &&
              raw['temperatureEnabled'] is! bool) ||
          (raw.containsKey('hrvBaselineMs') && raw['hrvBaselineMs'] is! num) ||
          (raw.containsKey('hrvReferenceKey') &&
              raw['hrvReferenceKey'] is! String) ||
          (raw.containsKey('hrvDropPercent') &&
              raw['hrvDropPercent'] is! int) ||
          (raw.containsKey('skinTemperatureBaseline') &&
              raw['skinTemperatureBaseline'] is! num) ||
          (raw.containsKey('temperatureReferenceKey') &&
              raw['temperatureReferenceKey'] is! String) ||
          (raw.containsKey('temperatureRiseC') &&
              raw['temperatureRiseC'] is! num) ||
          (raw.containsKey('ringVibrationEnabled') &&
              raw['ringVibrationEnabled'] is! bool) ||
          (raw.containsKey('phoneSoundEnabled') &&
              raw['phoneSoundEnabled'] is! bool) ||
          raw['high'] is! int ||
          raw['low'] is! int ||
          raw['oxygen'] is! int) {
        return null;
      }
      final result = ReadingReminderSettings(
        highEnabled: raw['highEnabled'] as bool,
        lowEnabled: raw['lowEnabled'] as bool,
        oxygenEnabled: raw['oxygenEnabled'] as bool,
        hrvEnabled: raw['hrvEnabled'] as bool? ?? false,
        temperatureEnabled: raw['temperatureEnabled'] as bool? ?? false,
        hrvBaselineMs: (raw['hrvBaselineMs'] as num?)?.toDouble(),
        hrvReferenceKey: raw['hrvReferenceKey'] as String?,
        hrvDropPercent: raw['hrvDropPercent'] as int? ?? 30,
        skinTemperatureBaseline: (raw['skinTemperatureBaseline'] as num?)
            ?.toDouble(),
        temperatureReferenceKey: raw['temperatureReferenceKey'] as String?,
        temperatureRiseC: (raw['temperatureRiseC'] as num?)?.toDouble() ?? 0.8,
        ringVibrationEnabled: raw['ringVibrationEnabled'] as bool? ?? true,
        phoneSoundEnabled: raw['phoneSoundEnabled'] as bool? ?? true,
        high: raw['high'] as int,
        low: raw['low'] as int,
        oxygen: raw['oxygen'] as int,
      );
      return result.valid ? result : null;
    } catch (_) {
      return null;
    }
  }
}

bool isPersonalReadingReminder(HealthReminderDetails? detail) {
  if (detail == null) return false;
  if (detail.ruleVersion == 'personal-reading-v1') {
    return const {
      HealthReminderKind.highHeartRate,
      HealthReminderKind.lowHeartRate,
      HealthReminderKind.lowBloodOxygen,
    }.contains(detail.kind);
  }
  final baseline = detail.baselineValue;
  final threshold = detail.threshold;
  if (detail.ruleVersion != 'personal-reading-v2' ||
      baseline == null ||
      threshold == null ||
      !baseline.isFinite ||
      !threshold.isFinite) {
    return false;
  }
  return switch (detail.kind) {
    HealthReminderKind.lowHrv =>
      baseline >= 1 && baseline <= 300 && threshold > 0 && threshold < baseline,
    HealthReminderKind.highSkinTemperature =>
      baseline >= 20 &&
          baseline <= 40 &&
          threshold > baseline &&
          threshold <= 43,
    _ => false,
  };
}

final class ReadingReminderCandidate {
  const ReadingReminderCandidate({
    required this.id,
    required this.metric,
    required this.details,
  });
  final String id;
  final HealthMetric metric;
  final HealthReminderDetails details;
}

/// Single completed, current measurements can prompt a recheck. This does not
/// infer rest, duration, illness or recovery from historical/sparse samples.
final class ReadingReminderEngine {
  String? _scope;
  final Set<String> _seen = {};
  void reset() {
    _scope = null;
    _seen.clear();
  }

  ReadingReminderCandidate? observe({
    required HealthRecord record,
    required DeviceInfo device,
    required String owner,
    required ReadingReminderSettings settings,
    required DateTime now,
    required bool live,
  }) {
    final scope = '$owner|${device.id}|${settings.comparisonFingerprint}';
    if (_scope != scope) {
      reset();
      _scope = scope;
    }
    final value = record.metric == HealthMetric.bodyTemperature
        ? record.values['skinTemperature']
        : record.values['value'];
    if (!settings.valid ||
        !settings.enabled ||
        !live ||
        owner.isEmpty ||
        owner == 'anonymous' ||
        record.deviceId != device.id ||
        record.id.isEmpty ||
        record.source != MeasurementSource.wearable ||
        record.origin != MeasurementOrigin.appMeasurement ||
        record.quality != 'device_reported' ||
        value == null ||
        !value.isFinite ||
        record.measuredAt.isAfter(now) ||
        now.difference(record.measuredAt) > const Duration(seconds: 90) ||
        _seen.contains(record.id)) {
      return null;
    }
    HealthReminderKind? kind;
    double? threshold;
    double? baselineValue;
    if (record.metric == HealthMetric.heartRate &&
        record.unit == 'bpm' &&
        value > 0 &&
        value <= 250) {
      if (settings.highEnabled && value > settings.high) {
        kind = HealthReminderKind.highHeartRate;
        threshold = settings.high.toDouble();
      } else if (settings.lowEnabled && value < settings.low) {
        kind = HealthReminderKind.lowHeartRate;
        threshold = settings.low.toDouble();
      }
    } else if (record.metric == HealthMetric.bloodOxygen &&
        record.unit == '%' &&
        value > 0 &&
        value <= 100 &&
        settings.oxygenEnabled &&
        value <= settings.oxygen) {
      kind = HealthReminderKind.lowBloodOxygen;
      threshold = settings.oxygen.toDouble();
    } else if (record.metric == HealthMetric.hrv &&
        record.unit == 'ms' &&
        value >= 1 &&
        value <= 300 &&
        settings.hrvEnabled &&
        settings.hrvReadyFor(device)) {
      baselineValue = settings.hrvBaselineMs!;
      threshold = baselineValue * (100 - settings.hrvDropPercent) / 100;
      if (value <= threshold) kind = HealthReminderKind.lowHrv;
    } else if (record.metric == HealthMetric.bodyTemperature &&
        const {'℃', '°C'}.contains(record.unit) &&
        value >= 20 &&
        value <= 45 &&
        settings.temperatureEnabled &&
        settings.temperatureReadyFor(device)) {
      baselineValue = settings.skinTemperatureBaseline!;
      threshold = baselineValue + settings.temperatureRiseC;
      if (value >= threshold) kind = HealthReminderKind.highSkinTemperature;
    }
    if (kind == null) return null;
    _seen.add(record.id);
    if (_seen.length > 512) _seen.remove(_seen.first);
    final id = sha256
        .convert(utf8.encode('$scope|${kind.wireName}|${record.id}'))
        .toString();
    return ReadingReminderCandidate(
      id: 'reading-$id',
      metric: record.metric,
      details: HealthReminderDetails(
        kind: kind,
        recordedAt: now.toUtc(),
        measuredAt: record.measuredAt,
        deviceName: device.displayName,
        reading: value.toDouble(),
        threshold: threshold,
        baselineValue: baselineValue,
        ruleVersion: baselineValue == null
            ? 'personal-reading-v1'
            : 'personal-reading-v2',
        sampleIds: [record.id],
      ),
    );
  }
}
