import 'dart:async';
import 'package:flutter/widgets.dart';
import '../domain/models.dart';
import 'api_client.dart';
import 'app_controller.dart';

abstract class HealthViewDataSource extends ChangeNotifier {
  String get label;
  bool get valid;
  Future<List<HealthRecord>> load(
    HealthMetric metric,
    DateTime start,
    DateTime end,
  );
}

/// Account- and relationship-owned read-only data. Never writes the local
/// health store and never supplies synthetic sleep intervals from summaries.
class CareHealthDataSource extends HealthViewDataSource
    with WidgetsBindingObserver {
  CareHealthDataSource({
    required this.controller,
    required this.owner,
    required this.relationshipId,
    required this.label,
  }) {
    controller.addListener(_accountChanged);
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground && valid) {
        unawaited(revalidate().catchError((Object _) {}));
      }
    });
  }
  final AppController controller;
  final String owner;
  final String relationshipId;
  @override
  final String label;
  Set<String> metrics = const {};
  bool _valid = true;
  bool _disposed = false;
  bool _foreground = true;
  Timer? _poll;
  int _generation = 0;
  @override
  bool get valid =>
      owner.trim().isNotEmpty &&
      !_disposed &&
      _valid &&
      controller.session?.accountKey == owner;
  void _invalidate() {
    if (!_valid || _disposed) return;
    _valid = false;
    _generation++;
    metrics = const {};
    notifyListeners();
  }

  void _accountChanged() {
    if (controller.session?.accountKey != owner) _invalidate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && valid) unawaited(revalidate().catchError((Object _) {}));
  }

  Future<void> revalidate() async {
    if (!valid) throw const ApiException('Permission changed', statusCode: 403);
    final generation = _generation;
    try {
      final rows = await controller.globalCareRelationships();
      if (!valid || generation != _generation) {
        throw const ApiException('Permission changed', statusCode: 403);
      }
      final matches = rows.where(
        (row) => row.id == relationshipId && row.active && !row.received,
      );
      if (matches.isEmpty) {
        _invalidate();
        throw const ApiException('Permission changed', statusCode: 403);
      }
      final next = matches.first.metrics
          .where(controller.healthReleasePolicy.allowsWireMetric)
          .toSet();
      if (metrics.isNotEmpty && !next.containsAll(metrics)) {
        // Clear all already displayed data on any grant reduction. A fresh
        // dashboard may be opened for the remaining server-approved grants.
        _invalidate();
        throw const ApiException('Permission changed', statusCode: 403);
      }
      metrics = Set.unmodifiable(next);
    } on ApiException catch (error) {
      if (const {401, 403, 404, 410}.contains(error.statusCode)) _invalidate();
      rethrow;
    }
  }

  @override
  Future<List<HealthRecord>> load(
    HealthMetric metric,
    DateTime start,
    DateTime end,
  ) async {
    if (!controller.healthReleasePolicy.allowsMetric(metric)) {
      throw const FeatureNotConfiguredException('此版本未提供该项目');
    }
    final generation = _generation;
    final wire = metric == HealthMetric.bodyTemperature
        ? 'temperature'
        : metric.wireName;
    await revalidate();
    if (!valid || !metrics.contains(wire)) {
      _invalidate();
      throw const ApiException('Permission changed', statusCode: 403);
    }
    try {
      final rows = await controller.globalCareRecordsRange(
        relationshipId,
        wire,
        start,
        end,
      );
      if (!valid || generation != _generation) {
        throw const ApiException('Permission changed', statusCode: 403);
      }
      return rows
          .map((row) => careHealthRecord(row, metric, relationshipId))
          .whereType<HealthRecord>()
          .map(controller.healthReleasePolicy.projectRecord)
          .whereType<HealthRecord>()
          .toList(growable: false);
    } on ApiException catch (error) {
      if (const {401, 403, 404, 410}.contains(error.statusCode)) _invalidate();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _poll?.cancel();
    controller.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

HealthRecord? careHealthRecord(
  Map<String, Object?> row,
  HealthMetric metric,
  String relationshipId,
) {
  final time = DateTime.tryParse('${row['observedAt'] ?? ''}');
  final values = row['values'];
  final id = '${row['id'] ?? ''}'.trim();
  final offset = row['timezoneOffsetMinutes'];
  final expectedMetric = metric == HealthMetric.bodyTemperature
      ? 'temperature'
      : metric.wireName;
  if (row['metric'] != null && row['metric'] != expectedMetric) return null;
  if (time == null ||
      id.isEmpty ||
      values is! Map ||
      offset is! int ||
      offset.abs() > 840) {
    return null;
  }
  final numeric = <String, num>{};
  for (final entry in values.entries) {
    if (entry.value is num && (entry.value as num).isFinite) {
      numeric['${entry.key}'] = entry.value as num;
    }
  }
  if (numeric.isEmpty) return null;
  final timezone =
      '${offset < 0 ? '-' : '+'}${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:${(offset.abs() % 60).toString().padLeft(2, '0')}';
  return HealthRecord.fromJson({
    'id': id,
    'type': metric.wireName,
    'values': numeric,
    'measuredAt': time.toUtc().toIso8601String(),
    'timezone': timezone,
    'unit': row['unit'] ?? '',
    'quality': row['quality'] ?? 'unknown',
    'deviceId': 'care:$relationshipId',
    'origin': 'remote_member',
    'source': 'care',
    'aggregation': row['aggregation'],
  });
}
