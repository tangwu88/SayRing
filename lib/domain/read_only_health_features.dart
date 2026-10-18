import 'models.dart';

class ReadOnlyHealthFeatureSnapshot {
  const ReadOnlyHealthFeatureSnapshot({
    required this.metrics,
    required this.validity,
  });

  factory ReadOnlyHealthFeatureSnapshot.fromMap(Map<String, Object?> data) {
    final config = data['readOnlyHealth'];
    if (data['product'] != 'say-ring' ||
        data['platform'] != 'ios' ||
        config is! Map ||
        config['schemaVersion'] is! int ||
        config['schemaVersion'] != 1) {
      throw const FormatException('Invalid health feature configuration');
    }
    final seconds = config['validForSeconds'];
    final flags = config['metrics'];
    if (seconds is! int || seconds < 1 || seconds > 300 || flags is! Map) {
      throw const FormatException('Invalid health feature configuration');
    }
    final metrics = <HealthMetric>{};
    for (final entry in flags.entries) {
      final metric = entry.key is String
          ? HealthMetric.tryFromWire(entry.key as String)
          : null;
      if (metric == null ||
          !ReadOnlyHealthFeatures.supportedMetrics.contains(metric) ||
          entry.value is! bool) {
        throw const FormatException('Invalid health feature flag');
      }
      if (entry.value == true) metrics.add(metric);
    }
    return ReadOnlyHealthFeatureSnapshot(
      metrics: Set.unmodifiable(metrics),
      validity: Duration(seconds: seconds),
    );
  }

  final Set<HealthMetric> metrics;
  final Duration validity;
}

/// The declared feature catalogue is a fixed client ceiling, not a way to
/// download new functionality or distinguish reviewers from other users.
class ReadOnlyHealthFeatures {
  ReadOnlyHealthFeatures({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const supportedMetrics = <HealthMetric>{
    HealthMetric.heartRate,
    HealthMetric.hrv,
    HealthMetric.bloodOxygen,
    HealthMetric.bodyTemperature,
    HealthMetric.stress,
  };
  static const maximumValidity = Duration(minutes: 5);

  final DateTime Function() _now;
  Set<HealthMetric> _metrics = const {};
  DateTime? _expiresAt;
  int _generation = 0;

  int get generation => _generation;
  DateTime? get expiresAt => _expiresAt;
  bool get expired => _expiresAt != null && !_now().isBefore(_expiresAt!);
  Set<HealthMetric> get metrics =>
      _expiresAt != null && _now().isBefore(_expiresAt!) ? _metrics : const {};

  /// No persisted grant: cold launches and failed refreshes start closed.
  /// Only a validated first-party snapshot may renew this short-lived lease.
  void replace(Set<HealthMetric> metrics, Duration validity) {
    if (validity <= Duration.zero || validity > maximumValidity) {
      throw const FormatException('Invalid health feature validity');
    }
    if (!supportedMetrics.containsAll(metrics)) {
      throw const FormatException('Unsupported read-only health feature');
    }
    final current = this.metrics;
    if (current.length != metrics.length || !current.containsAll(metrics)) {
      _generation++;
    }
    _metrics = Set.unmodifiable(metrics);
    _expiresAt = _now().add(validity);
  }

  void close() {
    _generation++;
    _metrics = const {};
    _expiresAt = null;
  }
}

/// A separate, native-acknowledged lease for this binary's manual commands.
/// It is never parsed from the server's read-only publication flags.
class ManualHealthFeatures {
  ManualHealthFeatures({DateTime Function()? now})
    : _lease = ReadOnlyHealthFeatures(now: now);

  static const supportedMetrics = <HealthMetric>{
    HealthMetric.heartRate,
    HealthMetric.hrv,
    HealthMetric.bloodOxygen,
  };

  final ReadOnlyHealthFeatures _lease;
  Set<HealthMetric> get metrics => _lease.metrics;
  bool get expired => _lease.expired;

  void replace(Set<HealthMetric> metrics, Duration validity) {
    if (!supportedMetrics.containsAll(metrics)) {
      throw const FormatException('Unsupported manual health feature');
    }
    _lease.replace(metrics, validity);
  }

  void close() => _lease.close();
}
