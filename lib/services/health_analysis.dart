import 'dart:math' as math;

import '../domain/models.dart';
import 'sleep_health_projection.dart' show sleepRecordSdkDate;

enum HealthTrendPeriod {
  day('日'),
  week('周'),
  month('月');

  const HealthTrendPeriod(this.label);

  final String label;
}

class HealthTrendRange {
  const HealthTrendRange({
    required this.start,
    required this.end,
    required this.previousStart,
    required this.previousEnd,
  });

  final DateTime start;
  final DateTime end;
  final DateTime previousStart;
  final DateTime previousEnd;

  static HealthTrendRange forPeriod(HealthTrendPeriod period, DateTime anchor) {
    final local = DateTime(anchor.year, anchor.month, anchor.day);
    final DateTime start;
    final DateTime end;
    switch (period) {
      case HealthTrendPeriod.day:
        start = local;
        end = local.add(const Duration(days: 1));
        break;
      case HealthTrendPeriod.week:
        start = local.subtract(Duration(days: local.weekday - 1));
        end = start.add(const Duration(days: 7));
        break;
      case HealthTrendPeriod.month:
        start = DateTime(local.year, local.month);
        end = DateTime(local.year, local.month + 1);
        break;
    }
    final span = end.difference(start);
    return HealthTrendRange(
      start: start,
      end: end,
      previousStart: period == HealthTrendPeriod.month
          ? DateTime(start.year, start.month - 1)
          : start.subtract(span),
      previousEnd: start,
    );
  }
}

class HealthTrendPoint {
  const HealthTrendPoint({
    required this.at,
    required this.value,
    this.secondaryValue,
    this.sampleCount = 1,
  });

  final DateTime at;
  final double value;
  final double? secondaryValue;
  final int sampleCount;
}

class HealthMetricSummary {
  const HealthMetricSummary({
    required this.recordCount,
    this.minimum,
    this.maximum,
    this.average,
    this.secondaryMinimum,
    this.secondaryMaximum,
    this.secondaryAverage,
    this.previousAverage,
  });

  final int recordCount;
  final double? minimum;
  final double? maximum;
  final double? average;
  final double? secondaryMinimum;
  final double? secondaryMaximum;
  final double? secondaryAverage;
  final double? previousAverage;

  double? get changeFromPrevious {
    final current = average;
    final previous = previousAverage;
    if (current == null || previous == null) return null;
    return current - previous;
  }
}

class HealthTrendData {
  const HealthTrendData({
    required this.records,
    required this.points,
    required this.summary,
    required this.range,
    required this.valueKey,
    this.secondaryValueKey,
  });

  final List<HealthRecord> records;
  final List<HealthTrendPoint> points;
  final HealthMetricSummary summary;
  final HealthTrendRange range;
  final String valueKey;
  final String? secondaryValueKey;
}

class HealthAnalysisService {
  const HealthAnalysisService();

  HealthTrendData analyze({
    required HealthMetric metric,
    required List<HealthRecord> records,
    required List<HealthRecord> previousRecords,
    required HealthTrendPeriod period,
    required DateTime anchor,
    String? selectedValueKey,
  }) {
    final range = HealthTrendRange.forPeriod(period, anchor);
    final unique = _unique(records);
    final previousUnique = _unique(previousRecords);
    final valueKey = selectedValueKey ?? preferredValueKey(metric, unique);
    final secondaryKey = metric == HealthMetric.bloodPressure
        ? 'diastolic'
        : null;
    final points = _points(
      metric: metric,
      records: unique,
      period: period,
      valueKey: valueKey,
      secondaryKey: secondaryKey,
    );
    final previousPoints = _points(
      metric: metric,
      records: previousUnique,
      period: period,
      valueKey: valueKey,
      secondaryKey: secondaryKey,
    );
    return HealthTrendData(
      records: unique
        ..sort((a, b) {
          if (metric == HealthMetric.sleep) {
            final sdkDate = sleepRecordSdkDate(
              b,
            ).compareTo(sleepRecordSdkDate(a));
            if (sdkDate != 0) return sdkDate;
          }
          return b.measuredAt.compareTo(a.measuredAt);
        }),
      points: points,
      summary: _summary(points, previousPoints, recordCount: unique.length),
      range: range,
      valueKey: valueKey,
      secondaryValueKey: secondaryKey,
    );
  }

  static List<String> availableValueKeys(
    HealthMetric metric,
    List<HealthRecord> records,
  ) {
    final present = records.expand((record) => record.values.keys).toSet();
    if (metric == HealthMetric.bodyComposition) {
      const preferred = [
        'bmi',
        'bodyFatRate',
        'fatMass',
        'fatFreeMass',
        'muscleRate',
        'muscleMass',
        'subcutaneousFat',
        'bodyWaterRate',
        'waterMass',
        'skeletalMuscleRate',
        'boneMass',
        'proteinRate',
        'proteinMass',
        'basalMetabolicRate',
      ];
      final result = preferred.where((key) {
        return _aliasesFor(key).any(present.contains);
      }).toList();
      if (result.isNotEmpty) return result;
      return present.where((key) => key != 'diastolic').toList()..sort();
    }
    final preferred = switch (metric) {
      HealthMetric.bloodComposition => const [
        'uricAcid',
        'totalCholesterol',
        'triglycerides',
        'highDensityLipoprotein',
        'lowDensityLipoprotein',
      ],
      _ => const <String>[],
    };
    final result = preferred.where(present.contains).toList();
    if (result.isNotEmpty) return result;
    return present.where((key) => key != 'diastolic').toList()..sort();
  }

  static String preferredValueKey(
    HealthMetric metric,
    List<HealthRecord> records,
  ) {
    if (metric == HealthMetric.bloodPressure) return 'systolic';
    final available = availableValueKeys(metric, records);
    for (final candidate in const [
      'value',
      'meanHeartRate',
      'averageHeartRate',
      'bmi',
      'uricAcid',
    ]) {
      if (available.contains(candidate)) return candidate;
    }
    return available.isEmpty ? 'value' : available.first;
  }

  static DateTime displayTime(HealthRecord record) {
    // Older Yuc builds stored every SDK epoch as `+00:00`, even though the
    // watch data represents an absolute instant that must be shown in the
    // phone's local timezone. Keep existing encrypted history readable after
    // upgrading without rewriting or deleting user records.
    if (record.id.startsWith('yc-') && record.timezone.trim() == '+00:00') {
      return record.measuredAt.toLocal();
    }
    final offset = _timezoneOffset(record.timezone);
    if (offset == null) return record.measuredAt.toLocal();
    final adjusted = record.measuredAt.toUtc().add(offset);
    return DateTime(
      adjusted.year,
      adjusted.month,
      adjusted.day,
      adjusted.hour,
      adjusted.minute,
      adjusted.second,
      adjusted.millisecond,
      adjusted.microsecond,
    );
  }

  static Duration? _timezoneOffset(String value) {
    final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final minutes =
        int.parse(match.group(2)!) * 60 + int.parse(match.group(3)!);
    return Duration(minutes: match.group(1) == '-' ? -minutes : minutes);
  }

  static List<HealthRecord> _unique(List<HealthRecord> records) {
    final byId = <String, HealthRecord>{};
    for (final record in records) {
      byId[record.id] = record;
    }
    return byId.values.toList();
  }

  static List<HealthTrendPoint> _points({
    required HealthMetric metric,
    required List<HealthRecord> records,
    required HealthTrendPeriod period,
    required String valueKey,
    required String? secondaryKey,
  }) {
    if (period == HealthTrendPeriod.day || metric == HealthMetric.ecg) {
      final result =
          records
              .map((record) {
                final value = _value(record, valueKey);
                if (value == null) return null;
                return HealthTrendPoint(
                  at: displayTime(record),
                  value: value,
                  secondaryValue: secondaryKey == null
                      ? null
                      : _value(record, secondaryKey),
                );
              })
              .whereType<HealthTrendPoint>()
              .toList()
            ..sort((a, b) => a.at.compareTo(b.at));
      return result;
    }

    final buckets = <DateTime, List<HealthRecord>>{};
    for (final record in records) {
      final local = displayTime(record);
      final day = DateTime(local.year, local.month, local.day);
      buckets.putIfAbsent(day, () => []).add(record);
    }
    final sumMetric =
        metric == HealthMetric.steps ||
        metric == HealthMetric.distance ||
        metric == HealthMetric.calories;
    final result = <HealthTrendPoint>[];
    for (final entry in buckets.entries) {
      final values = entry.value
          .map((record) => _value(record, valueKey))
          .whereType<double>()
          .toList();
      if (values.isEmpty) continue;
      final secondaryValues = secondaryKey == null
          ? const <double>[]
          : entry.value
                .map((record) => _value(record, secondaryKey))
                .whereType<double>()
                .toList();
      result.add(
        HealthTrendPoint(
          at: entry.key,
          value: sumMetric ? values.reduce((a, b) => a + b) : _average(values),
          secondaryValue: secondaryValues.isEmpty
              ? null
              : _average(secondaryValues),
          sampleCount: values.length,
        ),
      );
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  static double? _value(HealthRecord record, String key) {
    for (final alias in _aliasesFor(key)) {
      final value = record.values[alias];
      if (value != null && value.isFinite) return value.toDouble();
    }
    return null;
  }

  static List<String> _aliasesFor(String key) => switch (key) {
    'bmi' || 'BMI' => const ['bmi', 'BMI'],
    'bodyFatRate' ||
    'bodyFatPercentage' => const ['bodyFatRate', 'bodyFatPercentage'],
    'bodyWaterRate' ||
    'bodyMoisture' => const ['bodyWaterRate', 'bodyMoisture'],
    'basalMetabolicRate' ||
    'basalMetabolism' => const ['basalMetabolicRate', 'basalMetabolism'],
    _ => [key],
  };

  static HealthMetricSummary _summary(
    List<HealthTrendPoint> points,
    List<HealthTrendPoint> previousPoints, {
    required int recordCount,
  }) {
    final values = points.map((point) => point.value).toList();
    final secondary = points
        .map((point) => point.secondaryValue)
        .whereType<double>()
        .toList();
    final previous = previousPoints.map((point) => point.value).toList();
    return HealthMetricSummary(
      recordCount: recordCount,
      minimum: values.isEmpty ? null : values.reduce(math.min),
      maximum: values.isEmpty ? null : values.reduce(math.max),
      average: values.isEmpty ? null : _average(values),
      secondaryMinimum: secondary.isEmpty ? null : secondary.reduce(math.min),
      secondaryMaximum: secondary.isEmpty ? null : secondary.reduce(math.max),
      secondaryAverage: secondary.isEmpty ? null : _average(secondary),
      previousAverage: previous.isEmpty ? null : _average(previous),
    );
  }

  static double _average(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;
}
