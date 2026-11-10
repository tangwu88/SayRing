import 'models.dart';

/// U19 使用独立目录，避免旧版对 readOnlyHealth 的严格解析影响戒指功能。
class U19HealthSnapshot {
  const U19HealthSnapshot(this.readMetrics, this.manualMetrics, this.validity);

  factory U19HealthSnapshot.fromMap(Map<String, Object?> data) {
    final config = data['u19Health'];
    if (data['product'] != 'say-ring' ||
        data['platform'] != 'ios' ||
        config is! Map ||
        config['schemaVersion'] != 1) {
      throw const FormatException('Invalid U19 health configuration');
    }
    final seconds = config['validForSeconds'];
    if (seconds is! int || seconds < 1 || seconds > 300) {
      throw const FormatException('Invalid U19 health validity');
    }
    Set<HealthMetric> parse(Object? raw) {
      if (raw is! List) throw const FormatException('Invalid U19 metrics');
      final result = <HealthMetric>{};
      for (final key in raw) {
        final metric = key is String ? HealthMetric.tryFromWire(key) : null;
        if (metric == null ||
            !U19HealthFeatures.ceiling.contains(metric) ||
            !result.add(metric)) {
          throw const FormatException('Invalid U19 metric');
        }
      }
      return Set.unmodifiable(result);
    }

    final read = parse(config['readMetrics']);
    final manual = parse(config['manualMetrics']);
    if (!read.containsAll(manual)) {
      throw const FormatException('Invalid U19 manual scope');
    }
    return U19HealthSnapshot(read, manual, Duration(seconds: seconds));
  }

  final Set<HealthMetric> readMetrics;
  final Set<HealthMetric> manualMetrics;
  final Duration validity;
}

class U19HealthFeatures {
  U19HealthFeatures({DateTime Function()? now}) : _now = now ?? DateTime.now;
  static const ceiling = {
    HealthMetric.bloodPressure,
    HealthMetric.heartRate,
    HealthMetric.bloodOxygen,
  };
  final DateTime Function() _now;
  DateTime? _expiresAt;
  Set<HealthMetric> _read = const {};
  Set<HealthMetric> _manual = const {};
  int generation = 0;
  bool get hasLease => _expiresAt != null;
  bool get active => _expiresAt != null && _now().isBefore(_expiresAt!);
  Set<HealthMetric> get readMetrics => active ? _read : const {};
  Set<HealthMetric> get manualMetrics => active ? _manual : const {};
  void replace(U19HealthSnapshot snapshot, Duration remaining) {
    if (remaining <= Duration.zero ||
        remaining > const Duration(minutes: 5) ||
        !ceiling.containsAll(snapshot.readMetrics) ||
        !snapshot.readMetrics.containsAll(snapshot.manualMetrics)) {
      throw const FormatException('Invalid U19 lease');
    }
    if (!_read.containsAll(snapshot.readMetrics) ||
        !_manual.containsAll(snapshot.manualMetrics) ||
        _read.length != snapshot.readMetrics.length ||
        _manual.length != snapshot.manualMetrics.length ||
        !active) {
      generation++;
    }
    _read = Set.unmodifiable(snapshot.readMetrics);
    _manual = Set.unmodifiable(snapshot.manualMetrics);
    _expiresAt = _now().add(remaining);
  }

  void close() {
    generation++;
    _expiresAt = null;
    _read = const {};
    _manual = const {};
  }
}
