// Explicit debug entry point for an operator-approved signed-in test phone.
// It never imports the member's health store or prints credentials. Fixtures live only in memory.
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/ring_experience.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/cardiovascular_model.dart';
import 'package:saydian_app/services/cardiovascular_trend_summary.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/cardiovascular_trends_page.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/cardiovascular_model_panel.dart';

({List<PressureSample> pressure, List<HealthRecord> records}) _fixture(
  int span,
  DateTime end,
) {
  final pressure = <PressureSample>[], records = <HealthRecord>[];
  for (final previous in [true, false]) {
    for (var i = 0; i < 4; i++) {
      final day = ringAddDays(end, i - 4 - (previous ? span : 0));
      final at = DateTime(day.year, day.month, day.day, 12);
      final n = previous ? 0 : 1;
      final sign = span == 7 ? 1 : -1;
      pressure.add(
        PressureSample(
          at: at,
          systolic: 121 + sign * (4 * n + i),
          diastolic: 77 + sign * (n + i),
          source: 'reference',
        ),
      );
      for (final (metric, value, unit) in [
        (HealthMetric.heartRate, 66 + sign * (4 * n + i), 'bpm'),
        (HealthMetric.sleep, 7.5 - sign * (n * .5 + i * .2), 'h'),
        (
          HealthMetric.steps,
          4800 + (span == 7 ? i * 300 + n * 400 : -i * 320 + n * 650),
          'steps',
        ),
      ]) {
        records.add(
          HealthRecord(
            id: 'qa-${metric.name}-${day.day}-${day.month}',
            metric: metric,
            values: {'value': value},
            unit: unit,
            measuredAt: at,
            timezone: '+00:00',
            deviceId: 'qring:qa',
            sourceModel: 'QA',
            firmwareVersion: '',
            quality: 'valid',
            source: MeasurementSource.wearable,
            rawVersion: 3,
          ),
        );
      }
    }
  }
  return (pressure: pressure, records: records);
}

CardiovascularModelInput syntheticCardioModelInput(int span) {
  final end = DateTime(2026, 7, 30), start = ringAddDays(end, 1 - span);
  final data = _fixture(span, end);
  final report = CardiovascularSummary(
    start: start,
    end: end,
    previousStart: ringAddDays(start, -span),
    readings: data.pressure,
    contextRecords: data.records,
    now: ringAddDays(end, 1),
  );
  return CardiovascularModelInput.from(report, 'reference')!;
}

class _NoHardware implements WearableBridge {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixtureController extends AppController {
  _FixtureController(
    SessionVault vault,
    SaydianApi api,
    MemoryHealthStore store,
  ) : super(vault, api, store, _NoHardware());
  // The physical session authenticates the model call. Local cuff and U19 keys
  // belong exclusively to the fixture, never to this member's health history.
  @override
  String get homeHealthCardOwner => 'qa-cardio-model-synthetic-1322';
}

class _Audit extends http.BaseClient {
  final delegate = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final reply = await delegate.send(request);
    // Never print request/response bodies, authorization headers or session tokens.
    if (request.url.path.endsWith('/ai/messages')) {
      debugPrint('CARDIO_QA_GATEWAY ${reply.statusCode}');
    }
    return reply;
  }

  @override
  void close() => delegate.close();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) throw StateError('Use a dedicated debug test device.');
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildSaydianTheme(),
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const _Harness(),
    ),
  );
}

class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int span = 7;
  final vault = SecureSessionVault.global();
  final audit = _Audit();
  late final api = GlobalSaydianApiClient(vault, client: audit);
  Future<CardiovascularModelReply> analyze(int days) async {
    final member = await vault.readSession();
    if (member == null) {
      debugPrint('CARDIO_QA_SIGN_IN_REQUIRED');
      throw const ApiException('No signed-in test member');
    }
    try {
      final result = await api.analyzeCardiovascularTrends(
        member,
        syntheticCardioModelInput(days),
        days == 7 ? 'zh-Hans' : 'en',
      );
      final hash = sha256
          .convert(
            utf8.encode(jsonEncode([result.summary, result.observations])),
          )
          .toString();
      debugPrint(
        'CARDIO_QA_OK days=$days keys=${result.observations.keys.join(",")} digest=$hash',
      );
      return result;
    } on ApiException catch (error) {
      debugPrint(
        'CARDIO_QA_ERROR days=$days code=${error.code} status=${error.statusCode}',
      );
      rethrow;
    }
  }

  Future<void> openNormalPage() async {
    final who = await vault.readSession();
    if (who == null || !mounted) return;
    final rows = _fixture(7, ringDate(DateTime.now()));
    final store = MemoryHealthStore();
    await store.upsert([
      ...rows.records,
      for (final row in rows.pressure)
        HealthRecord(
          id: 'fixture-bp-${row.at.toIso8601String()}',
          metric: HealthMetric.bloodPressure,
          values: {'systolic': row.systolic, 'diastolic': row.diastolic},
          unit: 'mmHg',
          measuredAt: row.at,
          timezone: '+00:00',
          deviceId: 'qring:qa',
          sourceModel: '合成测试设备',
          firmwareVersion: '',
          quality: 'valid',
          source: MeasurementSource.wearable,
          rawVersion: 3,
        ),
    ]);
    if (!mounted) return;
    final controller = _FixtureController(vault, api, store)..session = who;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CardiovascularTrendsPage(controller: controller),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    audit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('心血管趋势 · 合成数据联调')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          children: [
            for (final n in [7, 30])
              ChoiceChip(
                label: Text('$n 天样本'),
                selected: span == n,
                onSelected: (_) => setState(() => span = n),
              ),
          ],
        ),
        TextButton(
          onPressed: openNormalPage,
          child: const Text('打开完整趋势页（合成数据）'),
        ),
        CardiovascularModelPanel(
          key: ValueKey(span),
          analyze: () => analyze(span),
        ),
      ],
    ),
  );
}
