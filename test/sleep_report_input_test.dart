import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/health_report_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/sleep_report_input.dart';

// Synthetic fixtures only, not a real member, ring or AI response.
HealthRecord _record({SleepTimeline? timeline, num hours = 7}) => HealthRecord(
  id: 'synthetic-sleep',
  metric: HealthMetric.sleep,
  values: {
    'value': hours,
    'deepHours': 2,
    'lightHours': 4,
    'remHours': 1,
    'awakeMinutes': 20,
  },
  unit: 'h',
  measuredAt: DateTime.utc(2026, 8, 4),
  timezone: '+08:00',
  deviceId: 'qring:synthetic-device',
  firmwareVersion: 'fixture',
  quality: 'fixture',
  source: MeasurementSource.wearable,
  rawVersion: 1,
  sleepTimeline: timeline,
);

Map<String, Object?> goldenSleepInput() => {
  'sdkDate': '2026-08-04',
  'timezone': '+08:00',
  'sourceKey': List.filled(64, 'a').join(),
  'totalSeconds': 25200,
  'deepSeconds': 7200,
  'lightSeconds': 14400,
  'remSeconds': 3600,
  'awakeSeconds': 1200,
  'sessions': [
    {
      'kind': 'night',
      'startAt': '2026-08-03T16:00:00.000Z',
      'endAt': '2026-08-04T00:00:00.000Z',
      'asleepSeconds': 25200,
    },
  ],
};

void main() {
  test(
    'sleep upload converts hours/minutes to exact seconds and omits raw identities',
    () {
      final input = sleepReportInput(_record());
      expect(input['totalSeconds'], 25200);
      expect(input['awakeSeconds'], 1200);
      expect(input['deepSeconds'], 7200);
      expect(input['deviceScore'], isNull);
      expect(input['sourceKey'], matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(jsonEncode(input), isNot(contains('synthetic-device')));
      expect(input.containsKey('segments'), isFalse);
      expect(input['sessions'], isEmpty);
    },
  );

  test('missing SDK phase is not silently filled with zero for AI', () {
    final timeline = SleepTimeline(
      deviceId: 'qring:synthetic-device',
      sdkDate: '2026-08-04',
      timezone: '+08:00',
      readAt: DateTime.utc(2026, 8, 4, 1),
      sessions: [],
      rawSummary: {'deepSeconds': 7200, 'lightSeconds': 14400},
    );
    expect(timeline.summaryValues.containsKey('remHours'), isFalse);
    expect(timeline.summaryValues.containsKey('awakeMinutes'), isFalse);
    final input = sleepReportInput(_record(timeline: timeline));
    expect(input['totalSeconds'], 21600);
    expect(input.containsKey('remSeconds'), isFalse);
    expect(input.containsKey('deviceScore'), isFalse);
  });

  test(
    'cross-night sessions preserve UTC and match the current snapshot rather than stale summary',
    () {
      final start = DateTime.utc(2026, 8, 3, 16);
      final timeline = SleepTimeline(
        deviceId: 'qring:synthetic-device',
        sdkDate: '2026-08-04',
        timezone: '+08:00',
        readAt: DateTime.utc(2026, 8, 4, 1),
        sessions: [
          SleepSession(
            kind: SleepSessionKind.night,
            segments: [
              SleepStageSegment(
                startAt: start,
                endAt: start.add(const Duration(hours: 2)),
                stage: SleepStage.deep,
                rawStage: 3,
              ),
            ],
          ),
        ],
      );
      final input = sleepReportInput(_record(timeline: timeline));
      expect(input['totalSeconds'], 7200);
      expect((input['sessions'] as List).single, {
        'kind': 'night',
        'startAt': '2026-08-03T16:00:00.000Z',
        'endAt': '2026-08-03T18:00:00.000Z',
        'asleepSeconds': 7200,
      });
      expect(input['deviceScore'], isNull);
    },
  );

  test(
    'stable hashing ignores map ordering and changes when sleep is refreshed',
    () {
      final input = goldenSleepInput();
      final hash = sleepReportSourceHash(input);
      expect(
        hash,
        '5a84ec3eff249db62cbf543968d138bbaa2f0452e03f81bbbb00847066356dce',
      );
      expect(
        hash,
        sleepReportSourceHash(Map.fromEntries(input.entries.toList().reversed)),
      );
      expect(
        hash,
        isNot(sleepReportSourceHash({...input, 'totalSeconds': 25000})),
      );
    },
  );

  test('invalid/no-data sleep cannot be uploaded', () {
    for (final hours in [0, -1, 25, double.nan]) {
      expect(
        () => sleepReportInput(_record(hours: hours)),
        throwsFormatException,
      );
    }
  });

  test(
    'sleep score requires a completed AI report and cannot become a fabricated device score',
    () {
      for (final value in [-1, 101, 85.5, '85']) {
        expect(
          HealthReportSummary.fromMap({
            'reportType': 'sleep',
            'status': 'ready',
            'aiGenerated': true,
            'sleepScore': value,
          }).sleepScore,
          isNull,
        );
      }
      expect(
        HealthReportSummary.fromMap({
          'reportType': 'sleep',
          'status': 'queued',
          'aiGenerated': true,
          'sleepScore': 85,
        }).sleepScore,
        isNull,
      );
      expect(
        HealthReportSummary.fromMap({
          'reportType': 'sleep',
          'status': 'ready',
          'aiGenerated': true,
          'sleepScore': 85,
        }).sleepScore,
        85,
      );
    },
  );

  test(
    'global routes remain authenticated, only aggregate POST creates a report',
    () async {
      final vault = MemorySessionVault();
      await vault.writeSession(
        Session(
          accessToken: 'synthetic',
          refreshToken: 'synthetic',
          expiresAt: DateTime.utc(2099),
          memberId: 'synthetic',
          displayName: 'Test',
          accountKey: 'synthetic',
        ),
      );
      final requests = <http.Request>[];
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          requests.add(request);
          expect(request.headers['Authorization'], 'Bearer synthetic');
          expect(
            request.url.path,
            startsWith('/global/api/saydian-app/v2/health/sleep-reports'),
          );
          if (request.method == 'POST') {
            expect(jsonDecode(request.body), goldenSleepInput());
          }
          final data = request.method == 'POST'
              ? {'id': 'synthetic', 'status': 'queued', 'reportType': 'sleep'}
              : request.url.path.endsWith('availability')
              ? {'available': true}
              : {'report': null};
          return http.Response(jsonEncode({'code': 200, 'data': data}), 200);
        }),
      );
      expect(await api.getSleepReport(goldenSleepInput()), isNull);
      expect(
        requests.single.url.queryParameters['sourceHash'],
        sleepReportSourceHash(goldenSleepInput()),
      );
      expect(await api.getSleepReportAvailability(), {'available': true});
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      expect(
        (await api.createSleepReport(goldenSleepInput())).status,
        HealthReportStatus.queued,
      );
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );
}
