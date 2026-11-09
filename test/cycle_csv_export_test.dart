import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/cycle_tracking.dart';

void main() {
  test('cycle CSV exports customer-readable Chinese without raw fields', () {
    final entries = [
      const CycleEntry(id: 'p', kind: 'period', data: {'start': '2026-11-06'}),
      const CycleEntry(
        id: 'd',
        kind: 'daily',
        data: {
          'date': '2026-11-06',
          'flow': 'medium',
          'pain': 'severe',
          'mood': 'calm',
          'fatigue': 'strong',
          'symptoms': ['headache', 'bloating'],
          'tags': ['travel', 'late_sleep'],
        },
      ),
      const CycleEntry(
        id: 'old',
        kind: 'daily',
        deleted: true,
        data: {'date': '2026-11-05', 'fatigue': 'mild'},
      ),
    ];
    final original = jsonEncode(entries.map((e) => e.toJson()).toList());
    expect(
      cycleCsv(entries),
      '\uFEFF类型,开始或日期,结束,记录\r\n'
      '"经期","2026-11-06","","经期开始：2026-11-06；经期结束：未填写"\r\n'
      '"每日记录","2026-11-06","","经量：中等；疼痛：明显；心情：平稳；疲劳：明显；身体感受：头痛、腹胀；生活标记：旅行、晚睡"',
    );
    expect(jsonEncode(entries.map((e) => e.toJson()).toList()), original);
  });

  test(
    'missing feelings stay unspecified while explicit no-symptom stays visible',
    () {
      final csv = cycleCsv(const [
        CycleEntry(id: 'none', kind: 'daily', data: {'date': '2026-11-01'}),
        CycleEntry(
          id: 'explicit',
          kind: 'daily',
          data: {
            'date': '2026-11-02',
            'pain': 'none',
            'symptoms': [],
            'tags': [],
          },
        ),
        CycleEntry(
          id: 'ended',
          kind: 'period',
          data: {'start': '2026-10-01', 'end': '2026-10-05'},
        ),
      ]);
      expect(csv, contains('"每日记录","2026-11-01","","仅记录日期"'));
      expect(csv, contains('疼痛：无；身体感受：无；生活标记：无'));
      expect(csv, contains('"经期","2026-10-01","2026-10-05"'));
      expect(csv, isNot(contains('null')));
    },
  );

  test('unrecognised values are not guessed or exposed as internal names', () {
    final csv = cycleCsv(const [
      CycleEntry(
        id: 'new-format',
        kind: 'daily',
        data: {
          'date': '2026-11-03',
          'fatigue': 'future-option',
          'newField': 'private',
        },
      ),
    ]);
    expect(csv, contains('疲劳：未识别的选项；其他记录：暂无法解读'));
    for (final internal in [
      'fatigue',
      'future-option',
      'newField',
      'private',
    ]) {
      expect(csv, isNot(contains(internal)));
    }
    expect(cycleCsv(const []), '\uFEFF类型,开始或日期,结束,记录\r\n');
  });
}
