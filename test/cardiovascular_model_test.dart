import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/ring_experience.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/cardiovascular_model.dart';
import 'package:saydian_app/services/cardiovascular_trend_summary.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/cardiovascular_trends_page.dart';
import 'cardiovascular_trend_summary_test.dart' as fixtures;
import '../tool/cardio_model_live_device.dart' show syntheticCardioModelInput;

Session member(String id) => Session(
  accessToken: 'test-access-$id',
  refreshToken: 'test-refresh-$id',
  accountKey: 'account-$id',
  memberId: id,
  displayName: 'Test',
  expiresAt: DateTime.utc(2099),
);

const sampleReply =
    '{"summary":"Measured days varied.","observations":{"heartRate":"Heart rate moved similarly.","sleep":"Sleep moved differently.","steps":"Steps were mixed."}}';
http.Response gateway(String text, {String role = 'assistant'}) =>
    http.Response(
      jsonEncode({
        'code': 200,
        'data': {
          'id': 'caab82e0-9aa5-4079-a776-e318f8bc3a81',
          'role': role,
          'content': text,
        },
      }),
      201,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class _Device extends Fake implements WearableBridge {}

class _DelayedApi extends Fake
    implements SaydianApi, GlobalAccountApi, CardiovascularModelApi {
  final calls = <Completer<CardiovascularModelReply>>[];
  final selections = <(String, String)>[];
  @override
  Future<CardiovascularModelReply> analyzeCardiovascularTrends(
    Session expected,
    CardiovascularModelInput input,
    String locale,
  ) {
    final pending = Completer<CardiovascularModelReply>();
    selections.add((payload(input)['source'] as String, locale));
    calls.add(pending);
    return pending.future;
  }
}

Map<String, dynamic> payload(CardiovascularModelInput input) =>
    jsonDecode(input.encodedEvidence) as Map<String, dynamic>;

void main() {
  test(
    'daily aligned ranked evidence and paired windows are different when the same pressure and context move differently',
    () {
      final seven = syntheticCardioModelInput(7),
          thirty = syntheticCardioModelInput(30);
      expect(seven.expectedMetrics, ['heartRate', 'sleep', 'steps']);
      expect((payload(seven)['bp'] as Map)['change'], '++');
      expect((payload(thirty)['bp'] as Map)['change'], '--');
      expect(
        ((payload(seven)['paired'] as Map)['sleep'] as Map)['change'],
        '++-',
      );
      expect(
        ((payload(thirty)['paired'] as Map)['sleep'] as Map)['change'],
        '--+',
      );
      final moves = (payload(seven)['paired'] as Map);
      expect(moves['heartRate']['pairedMoves']['systolic'], {
        'same': 3,
        'opposite': 0,
        'flat': 0,
      });
      expect(moves['sleep']['pairedMoves']['systolic'], {
        'same': 0,
        'opposite': 3,
        'flat': 0,
      });
      final encoded = seven.encodedEvidence;
      for (final sensitive in [
        '2026-',
        'qring:',
        'reference',
        '121',
        '4800',
        '07:',
        'memberId',
      ]) {
        expect(encoded, isNot(contains(sensitive)));
      }
      expect(payload(seven)['days'], hasLength(4));
      expect(seven.prompt('en'), isNot(thirty.prompt('en')));
    },
  );
  test(
    'insufficient common days, missing metrics and same-value ties stay distinguishable',
    () {
      final r = fixtures.summary(
        [
          for (final day in [1, 2, 3, 8, 9, 10]) fixtures.pressure(day, 123),
        ],
        [
          fixtures.sample(HealthMetric.heartRate, 3, 70),
          fixtures.sample(HealthMetric.heartRate, 8, 70),
          fixtures.sample(HealthMetric.sleep, 11, 7),
        ],
      );
      final input = CardiovascularModelInput.from(r, 'reference')!;
      expect(payload(input)['days'], ['0:MMX--', '1:MM---', '2:MM---']);
      expect((payload(input)['paired'] as Map)['heartRate'], {
        'prior': 1,
        'now': 1,
      });
      expect(input.expectedMetrics, ['heartRate']);
      expect(CardiovascularModelInput.from(r, 'other-device'), isNull);
    },
  );
  test(
    'a fully populated thirty-day request fits the deployed gateway limit',
    () {
      final data = CardiovascularSummary(
        start: fixtures.day(31),
        end: fixtures.day(60),
        previousStart: fixtures.day(1),
        now: fixtures.day(61),
        readings: [
          for (var d = 1; d <= 60; d++) fixtures.pressure(d, 105 + d % 30),
        ],
        contextRecords: [
          for (var d = 1; d <= 60; d++) ...[
            fixtures.sample(HealthMetric.heartRate, d, 66 + d % 5),
            fixtures.sample(HealthMetric.sleep, d, 6 + d % 3),
            fixtures.sample(HealthMetric.steps, d, 4567 + d),
          ],
        ],
      );
      final r = CardiovascularModelInput.from(data, 'reference')!;
      expect(payload(r)['days'], hasLength(30));
      expect(r.prompt('zh-Hans').length, lessThanOrEqualTo(4000));
    },
  );
  test(
    'authenticated gateway uses a dedicated conversation and accepts only a new assistant reply for the requested metrics',
    () async {
      final owner = member('A'), vault = MemorySessionVault()..session = owner;
      final input = syntheticCardioModelInput(7);
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://app.saydian.cn/global/api/saydian-app/v2/ai/messages',
          );
          expect(request.followRedirects, isFalse);
          expect(request.headers['authorization'], 'Bearer test-access-A');
          final data = jsonDecode(request.body) as Map;
          expect(data['sessionId'], 'say-ring-cardio-trends-v1');
          expect(data['locale'], 'en');
          expect(data['content'], contains(input.encodedEvidence));
          return gateway(sampleReply);
        }),
      );
      final result = await api.analyzeCardiovascularTrends(owner, input, 'en');
      expect(result.summary, 'Measured days varied.');
      expect(result.observations.keys.toList(), input.expectedMetrics);
      for (final bad in [
        '{}',
        '{"summary":"ok","observations":{}}',
        sampleReply.replaceFirst('varied.', 'were 160 mmHg.'),
      ]) {
        expect(
          () => CardiovascularModelReply.parse(bad, input.expectedMetrics),
          throwsFormatException,
        );
      }
      expect(
        CardiovascularModelReply.parse(
          '```json\n$sampleReply\n```',
          input.expectedMetrics,
        ).summary,
        result.summary,
      );
      final refused = GlobalSaydianApiClient(
        vault,
        client: MockClient((_) async => gateway(sampleReply, role: 'user')),
      );
      await expectLater(
        refused.analyzeCardiovascularTrends(owner, input, 'en'),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test(
    'an account change during a real-shaped request drops its reply, and a mismatched owner never sends',
    () async {
      final a = member('A'),
          b = member('B'),
          vault = MemorySessionVault()..session = a;
      var count = 0;
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((_) async {
          count++;
          vault.session = b;
          return gateway(sampleReply);
        }),
      );
      final input = syntheticCardioModelInput(7);
      await expectLater(
        api.analyzeCardiovascularTrends(a, input, 'en'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.analyzeCardiovascularTrends(a, input, 'en'),
        throwsA(isA<ApiException>()),
      );
      expect(count, 1);
    },
  );
  testWidgets(
    'switching the pressure source or display language requests the right analysis and ignores late text',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final api = _DelayedApi(),
          owner = member('A'),
          store = MemoryHealthStore();
      final ctl = AppController(
        MemorySessionVault()..session = owner,
        api,
        store,
        _Device(),
      )..session = owner;
      addTearDown(ctl.dispose);
      final at = DateTime.now().subtract(const Duration(hours: 2));
      await store.upsert([
        HealthRecord(
          id: 'bp-fixture',
          metric: HealthMetric.bloodPressure,
          values: const {'systolic': 121, 'diastolic': 80},
          unit: 'mmHg',
          measuredAt: at,
          timezone: '+00:00',
          deviceId: 'qring:qa',
          sourceModel: 'Test wearable',
          firmwareVersion: '',
          quality: 'valid',
          source: MeasurementSource.wearable,
          rawVersion: 3,
        ),
      ]);
      await ctl.savePressureReference(
        PressureSample(
          at: at.subtract(const Duration(minutes: 1)),
          systolic: 125,
          diastolic: 82,
          source: 'reference',
        ),
      );
      Widget screen(String language) => MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardiovascularTrendsPage(controller: ctl),
      );
      await tester.pumpWidget(screen('en'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Upper-arm monitor'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(screen('zh'));
      await tester.pumpAndSettle();
      expect(api.selections, [
        ('wearable', 'en'),
        ('upper-arm', 'en'),
        ('upper-arm', 'zh-Hans'),
      ]);
      api.calls[0].complete(
        const CardiovascularModelReply('Older wearable result', {}),
      );
      api.calls[1].complete(
        const CardiovascularModelReply('Older English result', {}),
      );
      api.calls[2].complete(const CardiovascularModelReply('本次上臂血压解读', {}));
      await tester.pumpAndSettle();
      expect(find.text('本次上臂血压解读'), findsOneWidget);
      expect(find.text('Older English result'), findsNothing);
      expect(find.text('Older wearable result'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'the normal page discards an older period reply, offers retry on failure and reuses a completed period',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final api = _DelayedApi(), owner = member('A');
      final ctl = AppController(
        MemorySessionVault()..session = owner,
        api,
        MemoryHealthStore(),
        _Device(),
      )..session = owner;
      addTearDown(ctl.dispose);
      await ctl.savePressureReference(
        PressureSample(
          at: DateTime.now().subtract(const Duration(hours: 2)),
          systolic: 120,
          diastolic: 77,
          source: 'reference',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CardiovascularTrendsPage(controller: ctl),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls, hasLength(1));
      expect(find.text('Analyzing this period’s readings…'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pressure-period-30')));
      await tester.pumpAndSettle();
      expect(api.calls, hasLength(2));
      api.calls.first.complete(
        const CardiovascularModelReply('Seven day response.', {}),
      );
      await tester.pump();
      expect(find.text('Seven day response.'), findsNothing);
      api.calls[1].completeError(
        const ApiException('temporarily unavailable', statusCode: 503),
      );
      await tester.pumpAndSettle();
      final retry = find.text('Retry analysis');
      await tester.scrollUntilVisible(retry.hitTestable(), 150);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(api.calls, hasLength(3));
      api.calls.last.complete(
        const CardiovascularModelReply('Thirty day response.', {}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thirty day response.'), findsOneWidget);
      final seven = find.byKey(const ValueKey('pressure-period-7'));
      await tester.scrollUntilVisible(seven.hitTestable(), -160);
      await tester.tap(seven);
      await tester.pumpAndSettle();
      expect(api.calls, hasLength(3));
      expect(find.text('Seven day response.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
