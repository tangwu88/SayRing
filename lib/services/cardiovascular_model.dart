import 'dart:convert';

import '../domain/models.dart';
import '../domain/ring_experience.dart';
import 'cardiovascular_trend_summary.dart';

/// Evidence for the configured wellness model. Only relative levels and recorded-day
/// counts leave the phone. Dates, absolute readings, free text and identifiers stay local.
class CardiovascularModelInput {
  CardiovascularModelInput._(this._evidence, List<String> metrics)
    : encodedEvidence = jsonEncode(_evidence),
      expectedMetrics = List.unmodifiable(metrics);
  final Map<String, Object?> _evidence;
  final String encodedEvidence;
  final List<String> expectedMetrics;

  Map<String, Object?> get _pressure =>
      (_evidence['bp'] as Map).cast<String, Object?>();

  Map<String, Object?> _metric(String name) =>
      ((_evidence['paired'] as Map)[name] as Map).cast<String, Object?>();

  List<String> _available(String name) {
    final metric = _metric(name);
    final period = metric.containsKey('change');
    final movement = metric.containsKey('pairedMoves');
    return [
      if (period) 'period',
      if (movement) 'movement',
      if (period && movement) 'both',
      if (!period && !movement) 'limited',
    ];
  }

  bool get hasTrend =>
      _pressure.containsKey('change') ||
      expectedMetrics.any((name) => !_available(name).contains('limited'));

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
Analyze the anonymous Say Ring trend evidence below. Select which synchronized metric to highlight, by coverage and consistency. Prefer a repeated same/opposite movement over sparse or mixed observations. If no metric offers a strong observation, prioritize pressure. The app will show the selected comparisons in ${locale == 'en' ? 'English' : 'Simplified Chinese'}.
change compares current with previous recorded days: + higher, - lower, = unchanged. bp order is systolic,diastolic; paired order adds the metric. pairedMoves counts same/opposite/flat between successive current matched days. L/M/H are within-period ranks, X is sparse, - is missing.
Return only JSON with "focus" and "observations". "focus" is "pressure" or one of the eligible metric keys. For every metric copy exactly one of its allowed observation types (choose both only if both comparisons add clarity). Never choose a "limited" metric as focus. Use no free text, extra keys or invented values.
Allowed observation types by key: ${jsonEncode({for (final name in expectedMetrics) name: _available(name)})}
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

  factory CardiovascularModelReply.parse(
    String reply,
    CardiovascularModelInput evidence,
    String locale,
  ) {
    String content = reply.trim();
    if (content.startsWith('```') && content.endsWith('```')) {
      final firstLine = content.indexOf('\n');
      if (firstLine > 0) {
        content = content.substring(firstLine + 1, content.length - 3).trim();
      }
    }
    if (content.length > 1024) {
      throw const FormatException('Oversized model response');
    }
    final value = jsonDecode(content);
    if (value is! Map ||
        value.length != 2 ||
        value['focus'] is! String ||
        value['observations'] is! Map) {
      throw const FormatException('Invalid model response');
    }
    final items = value['observations'] as Map,
        focus = value['focus'] as String;
    final metrics = evidence.expectedMetrics;
    if (items.length != metrics.length ||
        metrics.any(
          (name) => !evidence._available(name).contains(items[name]),
        ) ||
        (focus != 'pressure' &&
            (!metrics.contains(focus) || items[focus] == 'limited'))) {
      throw const FormatException('Mismatched trend observations');
    }
    return _TrendWording(evidence, locale == 'en').reply(focus, items);
  }
}

// The live model selects and orders comparisons. Every claim displayed to the
// member is rendered from the corresponding verified input field.
class _TrendWording {
  _TrendWording(this.evidence, this.english);
  final CardiovascularModelInput evidence;
  final bool english;

  String t(String zh, String en) => english ? en : zh;
  String direction(String sign) => switch (sign) {
    '+' => t('上升', 'rose'),
    '-' => t('下降', 'fell'),
    _ => t('持平', 'stayed level'),
  };

  String period(String codes, {String? metric}) {
    final systolic = direction(codes[0]), diastolic = direction(codes[1]);
    final label = metric == null ? null : _name(metric);
    final extra = label == null
        ? ''
        : t(
            '，$label${direction(codes[2])}',
            ', and $label ${direction(codes[2])}',
          );
    return t(
      '与上期相比，平均收缩压$systolic、平均舒张压$diastolic$extra。',
      'Compared with the previous period, average systolic pressure $systolic and average diastolic pressure $diastolic$extra.',
    );
  }

  String _name(String metric) => switch (metric) {
    'heartRate' => t('心率', 'heart rate'),
    'sleep' => t('睡眠时长', 'sleep duration'),
    _ => t('步数', 'steps'),
  };

  String movements(Map data) {
    String counts(Map row) => [
      if ((row['same'] as int) > 0)
        t('同向 ${row['same']} 次', '${row['same']} same direction'),
      if ((row['opposite'] as int) > 0)
        t('反向 ${row['opposite']} 次', '${row['opposite']} opposite direction'),
      if ((row['flat'] as int) > 0)
        t('一项持平 ${row['flat']} 次', '${row['flat']} with an unchanged reading'),
    ].join(t('、', ', '));
    final systolic = counts(data['systolic'] as Map);
    final diastolic = counts(data['diastolic'] as Map);
    return systolic == diastolic
        ? t(
            '与高低压的相邻记录中，$systolic。',
            'Across paired readings for both pressures: $systolic.',
          )
        : t(
            '收缩压 $systolic。舒张压 $diastolic。',
            'Systolic: $systolic. Diastolic: $diastolic.',
          );
  }

  String observation(String name, String choice) {
    final row = evidence._metric(name);
    if (choice == 'limited') {
      return t(
        '同日记录 ${row['now']} 天，暂不足以比较变化。',
        '${row['now']} days of paired readings. More are needed to compare changes.',
      );
    }
    return [
      if (choice != 'movement') period(row['change']! as String, metric: name),
      if (choice != 'period') movements(row['pairedMoves']! as Map),
    ].join(t('', ' '));
  }

  CardiovascularModelReply reply(String focus, Map items) {
    final pressure = evidence._pressure;
    final change = pressure['change'];
    final order = {if (focus != 'pressure') focus, ...evidence.expectedMetrics};
    return CardiovascularModelReply(
      change is String
          ? period(change)
          : t(
              '这段时间有 ${pressure['now']} 天血压记录，暂不足以比较两期均值。',
              '${pressure['now']} days of blood pressure readings in this period. More are needed to compare periods.',
            ),
      {
        for (final name in order)
          name: observation(name, items[name] as String),
      },
    );
  }
}
