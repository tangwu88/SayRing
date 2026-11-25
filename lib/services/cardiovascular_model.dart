import 'dart:convert';

import '../domain/models.dart';
import '../domain/ring_experience.dart';
import 'cardiovascular_trend_summary.dart';

/// Evidence for the configured wellness model. Only relative levels and recorded-day
/// counts leave the phone. Dates, absolute readings, free text and identifiers stay local.
class CardiovascularModelInput {
  CardiovascularModelInput._(Map<String, Object?> fields, List<String> metrics)
    : encodedEvidence = jsonEncode(fields),
      expectedMetrics = List.unmodifiable(metrics);
  final String encodedEvidence;
  final List<String> expectedMetrics;

  static const names = {
    HealthMetric.heartRate: 'heartRate',
    HealthMetric.sleep: 'sleep',
    HealthMetric.steps: 'steps',
  };

  static CardiovascularModelInput? from(
    CardiovascularSummary summary,
    String? source,
  ) {
    if (source == null) return null;
    final daily = pressureDays(summary.pressure[source] ?? []);
    final current = daily
        .where((d) => !d.date.isBefore(summary.start))
        .toList();
    if (current.isEmpty) return null;
    final previous = daily
        .where((d) => d.date.isBefore(summary.start))
        .toList();
    final series = {
      for (final s in summary.contextFor(source)) s.metric: s.values,
    };
    final expected = <String>[];
    final contexts = <String, Object?>{};
    final levels = <HealthMetric, _Levels>{};
    for (final metric in CardiovascularSummary.contextMetrics) {
      final samples = series[metric] ?? const <DateTime, double>{};
      final now = current.where((d) => samples.containsKey(d.date)).toList();
      final prior = previous.where((d) => samples.containsKey(d.date)).toList();
      final name = names[metric]!;
      if (now.isNotEmpty) expected.add(name);
      levels[metric] = _Levels(now.map((d) => samples[d.date]!));
      contexts[name] = {
        'prior': prior.length,
        'now': now.length,
        if (now.length >= 3)
          'pairedMoves': {
            'systolic': _pairedMoves(now, samples, (d) => d.systolic),
            'diastolic': _pairedMoves(now, samples, (d) => d.diastolic),
          },
        if (now.length >= 3 && prior.length >= 3)
          'change': [
            _change(prior.map((d) => d.systolic), now.map((d) => d.systolic)),
            _change(prior.map((d) => d.diastolic), now.map((d) => d.diastolic)),
            _change(
              prior.map((d) => samples[d.date]!),
              now.map((d) => samples[d.date]!),
            ),
          ].join(),
      };
    }
    final upper = _Levels(current.map((d) => d.systolic));
    final lower = _Levels(current.map((d) => d.diastolic));
    int calendarDay(DateTime date) =>
        DateTime.utc(date.year, date.month, date.day)
            .difference(
              DateTime.utc(
                summary.start.year,
                summary.start.month,
                summary.start.day,
              ),
            )
            .inDays;
    return CardiovascularModelInput._({
      'windowDays': calendarDay(summary.end) + 1,
      'source': source == 'reference' ? 'upper-arm' : 'wearable',
      'bp': {
        'prior': previous.length,
        'now': current.length,
        if (previous.length >= 3 && current.length >= 3)
          'change': [
            _change(
              previous.map((d) => d.systolic),
              current.map((d) => d.systolic),
            ),
            _change(
              previous.map((d) => d.diastolic),
              current.map((d) => d.diastolic),
            ),
          ].join(),
      },
      'paired': contexts,
      'days': [
        for (final d in current)
          '${calendarDay(d.date)}:${upper.of(d.systolic)}${lower.of(d.diastolic)}${CardiovascularSummary.contextMetrics.map((m) => levels[m]!.of(series[m]?[d.date])).join()}',
      ],
    }, expected);
  }

  // Count changes between successive ACTUAL paired observations. Missing days
  // are never filled, and a tie in either series is not an opposite movement.
  static Map<String, int> _pairedMoves(
    List<PressureDay> rows,
    Map<DateTime, double> values,
    double Function(PressureDay) field,
  ) {
    var same = 0, opposite = 0, flat = 0;
    for (var index = 1; index < rows.length; index++) {
      final a = rows[index - 1], b = rows[index];
      final product =
          (field(b) - field(a)).sign * (values[b.date]! - values[a.date]!).sign;
      if (product > 0) {
        same++;
      } else if (product < 0) {
        opposite++;
      } else {
        flat++;
      }
    }
    return {'same': same, 'opposite': opposite, 'flat': flat};
  }

  // Use the same one-decimal rounding as the numeric evidence on the page.
  static String _change(Iterable<double> previous, Iterable<double> current) {
    final difference = double.parse(
      (cardioMean(current) - cardioMean(previous)).toStringAsFixed(1),
    );
    return difference == 0
        ? '='
        : difference > 0
        ? '+'
        : '-';
  }

  String prompt(String locale) =>
      '''
Write a brief Say Ring trend analysis in ${locale == 'en' ? 'English' : 'Simplified Chinese'}. Use only this anonymous evidence. No diagnosis, risk labels, causes, treatment, precise readings or generic advice. Always name the comparison (e.g. 较上一周期升高, higher than the previous average); never give an absolute high/low label like 偏高/偏低.
bp and paired counts are previous/current recorded days. change compares means on those SAME dates: + higher, - lower, = unchanged. bp order is systolic,diastolic; paired order is systolic,diastolic,metric. No change field means insufficient days for a period comparison.
pairedMoves gives EXACT counts between successive current paired observations, for each pressure component: same direction, opposite direction or either flat. Use these counts to describe co-movement. Never describe mixed directions unless both same and opposite are positive. Do not infer a link when there are fewer than three paired days. days are offsets with ranks in order systolic,diastolic,heart rate,sleep duration,steps. L/M/H are relative ranks, X is sparse, - is missing; these ranks never override pairedMoves.
Return only JSON {"summary":"one short BP observation","observations":{...}}. Use exactly these observation keys: ${jsonEncode(expectedMetrics)}. One short sentence per metric about its relationship with BP. Distinguish within-period observations from period averages.
$encodedEvidence''';
}

class _Levels {
  _Levels(Iterable<double> entries) : values = entries.toList()..sort();
  final List<double> values;

  String of(double? value) {
    if (value == null) return '-';
    if (values.length < 3) return 'X';
    // Midranks keep identical values together; a flat series is entirely M.
    final below = values.indexOf(value);
    final above = values.lastIndexOf(value);
    final rank = (below + above + 1) / (2 * values.length);
    return rank < 1 / 3
        ? 'L'
        : rank > 2 / 3
        ? 'H'
        : 'M';
  }
}

class CardiovascularModelReply {
  const CardiovascularModelReply(this.summary, this.observations);
  final String summary;
  final Map<String, String> observations;

  factory CardiovascularModelReply.parse(String reply, List<String> metrics) {
    String content = reply.trim();
    if (content.startsWith('```') && content.endsWith('```')) {
      final firstLine = content.indexOf('\n');
      if (firstLine > 0) {
        content = content.substring(firstLine + 1, content.length - 3).trim();
      }
    }
    if (content.length > 4500) {
      throw const FormatException('Oversized model response');
    }
    final value = jsonDecode(content);
    if (value is! Map || value['observations'] is! Map) {
      throw const FormatException('Invalid model response');
    }
    final items = value['observations'] as Map;
    String sentence(Object? text) {
      if (text is! String ||
          text.trim().isEmpty ||
          text.length > 650 ||
          RegExp(
            r'\d\s*(?:/\s*\d|mm\s*hg|bpm|分钟|小时|毫秒|步|beats|hours|minutes|steps|%)',
            caseSensitive: false,
          ).hasMatch(text)) {
        throw const FormatException('Invalid trend observation');
      }
      return text.trim();
    }

    if (items.length != metrics.length || !metrics.every(items.containsKey)) {
      throw const FormatException('Mismatched trend observations');
    }
    return CardiovascularModelReply(sentence(value['summary']), {
      for (final key in metrics) key: sentence(items[key]),
    });
  }
}
