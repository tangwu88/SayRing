import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/ui/report_visual_summary.dart';

// Synthetic report-only data; no upload, account or provider calls.
const sleep = <String, Object?>{
  'version': 1,
  'kind': 'sleep',
  'metrics': <Object?>[],
  'sleep': <String, Object?>{
    'totalSeconds': 25200,
    'wakeCount': null,
    'sessionCount': 1,
    'stages': <Object?>[
      {'key': 'deepSeconds', 'label': '深睡', 'seconds': 5400},
      {'key': 'lightSeconds', 'label': '浅睡', 'seconds': null},
      {'key': 'remSeconds', 'label': '快速眼动', 'seconds': null},
    ],
    'unclassifiedSeconds': 19800,
  },
};
void main() {
  testWidgets(
    'sleep report graphs keep missing values unknown at narrow large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ReportVisualSummary(
                    visuals: sleep,
                    score: 78,
                    explanation: '仅为合成测试说明',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('78 / 100'), findsOneWidget);
      expect(find.text('7小时0分'), findsOneWidget);
      expect(find.text('未记录'), findsWidgets);
      expect(find.text('0 次'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'health metrics and advice stay readable without continuous or normal-range claims',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ReportVisualSummary(
                    visuals: const {
                      'metrics': [
                        {
                          'label': '心率',
                          'unit': 'bpm',
                          'average': 71,
                          'latest': 72,
                          'sampleCount': 2,
                          'points': [
                            {'date': '2026-10-01', 'value': 70},
                            {'date': '2026-10-04', 'value': 72},
                          ],
                        },
                      ],
                    },
                  ),
                  const ReportAdviceList(items: ['保持规律作息']),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('71'), findsOneWidget);
      expect(find.text('bpm · 样本均值'), findsOneWidget);
      expect(find.text('保持规律作息'), findsOneWidget);
      await tester.tap(find.text('查看每日数值'));
      await tester.pumpAndSettle();
      expect(find.text('70 bpm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'older report without visuals keeps empty summary, never a fabricated score',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReportVisualSummary(visuals: {})),
        ),
      );
      expect(find.text('0'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
