import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'health_reminder.dart';
import 'models.dart';

/// Personal reading limits, separate from reviewed clinical monitoring rules.
/// Saving limits never enables a sensor, changes a device setting or claims a
/// continuous stream. A member explicitly enables each reminder.
final class ReadingReminderSettings {
  const ReadingReminderSettings({
    this.highEnabled = false,
    this.lowEnabled = false,
    this.oxygenEnabled = false,
    this.high = 120,
    this.low = 40,
    this.oxygen = 92,
  });

  final bool highEnabled;
  final bool lowEnabled;
  final bool oxygenEnabled;
  final int high;
  final int low;
  final int oxygen;
  bool get enabled => highEnabled || lowEnabled || oxygenEnabled;
  bool get valid =>
      high >= 80 &&
      high <= 200 &&
      low >= 30 &&
      low <= 80 &&
      low < high &&
      oxygen >= 80 &&
      oxygen <= 95;

  ReadingReminderSettings copyWith({
    bool? highEnabled,
    bool? lowEnabled,
    bool? oxygenEnabled,
    int? high,
    int? low,
    int? oxygen,
  }) => ReadingReminderSettings(
    highEnabled: highEnabled ?? this.highEnabled,
    lowEnabled: lowEnabled ?? this.lowEnabled,
    oxygenEnabled: oxygenEnabled ?? this.oxygenEnabled,
    high: high ?? this.high,
    low: low ?? this.low,
    oxygen: oxygen ?? this.oxygen,
  );

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'highEnabled': highEnabled,
    'lowEnabled': lowEnabled,
    'oxygenEnabled': oxygenEnabled,
    'high': high,
    'low': low,
    'oxygen': oxygen,
  };
  String get fingerprint =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();
  static ReadingReminderSettings? parse(String? value) {
    try {
      final raw = jsonDecode(value ?? '');
      if (raw is! Map ||
          raw['schemaVersion'] != 1 ||
          raw['highEnabled'] is! bool ||
          raw['lowEnabled'] is! bool ||
          raw['oxygenEnabled'] is! bool ||
          raw['high'] is! int ||
          raw['low'] is! int ||
          raw['oxygen'] is! int) {
        return null;
      }
      final result = ReadingReminderSettings(
        highEnabled: raw['highEnabled'] as bool,
        lowEnabled: raw['lowEnabled'] as bool,
        oxygenEnabled: raw['oxygenEnabled'] as bool,
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

bool isPersonalReadingReminder(HealthReminderDetails? detail) =>
    detail != null &&
    detail.ruleVersion == 'personal-reading-v1' &&
    detail.kind != HealthReminderKind.symptoms;

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
    final scope = '$owner|${device.id}|${settings.fingerprint}';
    if (_scope != scope) {
      reset();
      _scope = scope;
    }
    final value = record.values['value'];
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
        ruleVersion: 'personal-reading-v1',
        sampleIds: [record.id],
      ),
    );
  }
}
