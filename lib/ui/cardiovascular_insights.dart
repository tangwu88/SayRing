import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/ring_experience.dart';
import '../services/cardiovascular_trend_summary.dart';
import 'ring_share_page.dart';

String cardioNumber(double value) =>
    value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

String cardioMetric(BuildContext c, HealthMetric metric) => switch (metric) {
  HealthMetric.heartRate => ringText(c, '心率', 'Heart rate'),
  HealthMetric.sleep => ringText(c, '睡眠', 'Sleep'),
  HealthMetric.steps => ringText(c, '步数', 'Steps'),
  _ => throw ArgumentError.value(metric),
};

String cardioValue(BuildContext c, HealthMetric metric, double value) {
  if (metric == HealthMetric.sleep) {
    final minutes = value.round(), h = minutes ~/ 60, m = minutes % 60;
    if (h == 0) return ringText(c, '$m 分钟', '$m min');
    if (m == 0) return ringText(c, '$h 小时', '$h h');
    return ringText(c, '$h 小时 $m 分钟', '$h h $m min');
  }
  if (metric == HealthMetric.steps) {
    return ringText(c, '${value.round()} 步', '${value.round()} steps');
  }
  return '${value.round()} bpm';
}

String _movement(BuildContext c, double value) {
  final rounded = double.parse(value.toStringAsFixed(1));
  if (rounded == 0) return ringText(c, '持平', 'was unchanged');
  final amount = '${cardioNumber(rounded.abs())} mmHg';
  return rounded > 0
      ? ringText(c, '升高 $amount', 'rose by $amount')
      : ringText(c, '降低 $amount', 'fell by $amount');
}

/// Only reviewed, release-bundled language is used. Record data never enters the copy service.
class CardioInsightCopy {
  CardioInsightCopy(this._languages);
  final Map<String, Map<String, String>> _languages;
  static Future<CardioInsightCopy?> load() async {
    try {
      return await rootBundle.loadStructuredData(
        'assets/cardiovascular/insights.json',
        (raw) async {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          if (json['version'] != 1) {
            throw const FormatException('Unexpected insight copy version');
          }
          return CardioInsightCopy({
            for (final lang in ['zh', 'en'])
              lang: Map<String, String>.from(json[lang] as Map),
          });
        },
      );
    } on FlutterError {
      return null;
    } on TypeError {
      return null;
    } on Exception {
      return null;
    }
  }

  String message(
    BuildContext c,
    String key, [
    Map<String, Object> fields = const {},
  ]) {
    final lang = Localizations.localeOf(c).languageCode == 'zh' ? 'zh' : 'en';
    return _languages[lang]![key]!.replaceAllMapped(
      RegExp(r'\{([a-zA-Z]+)\}'),
      (match) => fields[match[1]]!.toString(),
    );
  }
}

List<String> cardioInsights(
  BuildContext c,
  CardioInsightCopy copy,
  CardiovascularSummary report,
  List<PressureDay> days,
  List<CardioContextSeries> series, {
  required bool pressureReadFailed,
}) {
  final current = {
    for (final d in days)
      if (!d.date.isBefore(report.start)) d.date: d,
  };
  final previous = {
    for (final d in days)
      if (d.date.isBefore(report.start)) d.date: d,
  };
  String span(int n) => ringText(c, '$n 天', n == 1 ? 'one day' : '$n days');
  final delta = pressureChange(days, report.start, report.previousStart);
  final notes = <String>[];
  if (delta != null) {
    notes.add(
      copy.message(c, 'bpChange', {
        'upper': _movement(c, delta.systolic),
        'lower': _movement(c, delta.diastolic),
      }),
    );
  } else if (current.isNotEmpty) {
    notes.add(
      copy.message(c, 'sparseBp', {
        'span': span(current.length),
        'previousSpan': span(previous.length),
      }),
    );
  } else if (series.isNotEmpty && !pressureReadFailed) {
    notes.add(copy.message(c, 'noBp'));
  }
  final observations = <String>[];
  for (final item in series) {
    final measured = item.period(report.start, report.end);
    final joint = measured.keys.where(current.containsKey).toList();
    final prior = item.values.keys.where(previous.containsKey).toList();
    final name = cardioMetric(c, item.metric).toLowerCase();
    String mean(Iterable<double> values) =>
        cardioValue(c, item.metric, cardioMean(values));
    if (joint.isNotEmpty) {
      final value = mean(joint.map((d) => measured[d]!));
      final upper = cardioMean(joint.map((d) => current[d]!.systolic));
      if (joint.length >= 3 && prior.length >= 3) {
        final previousUpper = cardioMean(
          prior.map((d) => previous[d]!.systolic),
        );
        observations.add(
          copy.message(
            c,
            joint.length == current.length && prior.length == previous.length
                ? 'pairedAlignedChange'
                : 'pairedChange',
            {
              'metric': name,
              'upper': _movement(c, upper - previousUpper),
              'prior': mean(prior.map((d) => item.values[d]!)),
              'value': value,
              'span': span(joint.length),
              'previousSpan': span(prior.length),
            },
          ),
        );
      } else {
        final lower = cardioMean(joint.map((d) => current[d]!.diastolic));
        observations.add(
          copy.message(c, joint.length == 1 ? 'pairedDay' : 'pairedDays', {
            'date': MaterialLocalizations.of(c).formatShortDate(joint.first),
            'days': joint.length,
            'bp': '${cardioNumber(upper)}/${cardioNumber(lower)}',
            'metric': name,
            'value': value,
          }),
        );
      }
    } else if (current.isEmpty) {
      final before = item.period(
        report.previousStart,
        ringAddDays(report.start, -1),
      );
      if (measured.length >= 3 && before.length >= 3) {
        observations.add(
          copy.message(c, 'contextChange', {
            'metric': name,
            'prior': mean(before.values),
            'value': mean(measured.values),
          }),
        );
      }
    }
  }
  if (observations.isEmpty && series.isNotEmpty) {
    if (current.isEmpty) {
      final item = series.first, data = item.period(report.start, report.end);
      observations.add(
        copy.message(c, 'contextOnly', {
          'metric': cardioMetric(c, item.metric).toLowerCase(),
          'span': span(data.length),
          'value': cardioValue(c, item.metric, cardioMean(data.values)),
        }),
      );
    } else {
      observations.add(copy.message(c, 'differentDates'));
    }
  }
  return [...notes, ...observations];
}
