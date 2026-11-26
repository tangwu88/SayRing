import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/ring_experience.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/cardiovascular_model.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/cardiovascular_trends_page.dart';

class _FixtureDevice extends Fake implements WearableBridge {}

class _FixtureModel extends Fake
    implements SaydianApi, GlobalAccountApi, CardiovascularModelApi {
  int calls = 0;
  @override
  Future<CardiovascularModelReply> analyzeCardiovascularTrends(
    Session expected,
    CardiovascularModelInput input,
    String locale,
  ) async {
    calls++;
    return CardiovascularModelReply.parse(
      jsonEncode({
        'focus': 'heartRate',
        'observations': {
          for (final metric in input.expectedMetrics) metric: 'movement',
        },
      }),
      input,
      locale,
    );
  }
}

/// Uses the normal page with in-memory records and a deterministic model reply.
Future<void> cardioChartScenario(
  WidgetTester t,
  String language,
  double scale, {
  Future<void> Function(String name)? capture,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  final store = MemoryHealthStore(), api = _FixtureModel();
  final date = ringDate(DateTime.now());
  final owner = Session(
    accessToken: 'fixture',
    refreshToken: 'fixture',
    accountKey: 'qa',
    memberId: 'qa',
    displayName: 'QA',
    expiresAt: DateTime.utc(2099),
  );
  final controller = AppController(
    MemorySessionVault()..session = owner,
    api,
    store,
    _FixtureDevice(),
  )..session = owner;
  addTearDown(controller.dispose);
  final zh = language == 'zh';
  for (final (ago, upper, lower, pulse, hours, steps) in [
    (11, 126, 84, 72, 6.0, 3200),
    (10, 124, 83, 70, 6.5, 4000),
    (9, 125, 82, 71, 7.0, 5400),
    (6, 121, 76, 68, 7.5, 6200),
    (5, 127, 81, 74, 6.0, 4800),
    (3, 119, 75, 65, 8.0, 0),
    (2, 123, 79, 70, 7.25, 6100),
    (1, 120, 76, 71, 7.0, 5800),
  ]) {
    final day = ringAddDays(date, -ago);
    final at = DateTime(day.year, day.month, day.day, 9);
    await controller.savePressureReference(
      PressureSample(
        at: at,
        systolic: upper,
        diastolic: lower,
        source: 'reference',
      ),
    );
    await store.upsert([
      for (final (metric, value, unit) in [
        (HealthMetric.heartRate, pulse, 'bpm'),
        (HealthMetric.sleep, hours, 'h'),
        (HealthMetric.steps, steps, 'steps'),
      ])
        HealthRecord(
          id: 'fixture-$ago-${metric.name}',
          metric: metric,
          values: {'value': value},
          unit: unit,
          measuredAt: DateTime.utc(day.year, day.month, day.day, 10),
          timezone: '+00:00',
          deviceId: 'qring:fixture',
          sourceModel: 'QA',
          firmwareVersion: '',
          quality: 'valid',
          source: MeasurementSource.wearable,
          rawVersion: 3,
        ),
    ]);
  }
  final last = ringAddDays(date, -1);
  await controller.savePressureReference(
    PressureSample(
      at: DateTime(last.year, last.month, last.day, 18),
      systolic: 128,
      diastolic: 80,
      source: 'reference',
    ),
  );
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildSaydianTheme(),
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      initialRoute: '/trends',
      routes: {
        '/': (_) => const Scaffold(),
        '/trends': (_) => CardiovascularTrendsPage(controller: controller),
      },
    ),
  );
  await t.pumpAndSettle();
  final overview = find.byKey(const Key('cardio-overview'));
  Finder number(String text) =>
      find.descendant(of: overview, matching: find.text(text));
  expect(number('128'), findsOneWidget);
  expect(number('80'), findsOneWidget);
  if (capture != null) await capture('overview-$language');
  final plot = find.byKey(const Key('cardio-pressure-plot'));
  Future<void> pick(int daysAgo) async {
    await t.ensureVisible(plot);
    await t.pumpAndSettle();
    final rect = t.getRect(plot);
    await t.tapAt(
      Offset(rect.left + rect.width * (6 - daysAgo) / 6, rect.center.dy),
    );
    await t.pumpAndSettle();
  }

  final explore = find.byKey(const Key('cardio-explore-days'));
  await t.ensureVisible(explore);
  await t.pumpAndSettle();
  await t.tap(explore);
  await t.pumpAndSettle();
  expect(number('124'), findsOneWidget);
  expect(number('78'), findsOneWidget);
  expect(number('128'), findsNothing);
  final next = find.byTooltip(zh ? '下一天' : 'Next day');
  await t.ensureVisible(next);
  await t.pumpAndSettle();
  await t.tap(next);
  await t.pumpAndSettle();
  expect(
    find.text(zh ? '当天没有血压记录' : 'No pressure reading that day'),
    findsOneWidget,
  );
  await pick(4);
  expect(
    find.text(zh ? '当天没有血压记录' : 'No pressure reading that day'),
    findsOneWidget,
  );
  final add = find.byKey(const Key('record-pressure-reference'));
  await t.ensureVisible(add);
  await t.pumpAndSettle();
  await t.tap(add);
  await t.pumpAndSettle();
  final dialog = find.byType(AlertDialog);
  final l = MaterialLocalizations.of(t.element(dialog));
  expect(
    find.descendant(
      of: dialog,
      matching: find.textContaining(l.formatCompactDate(ringAddDays(date, -4))),
    ),
    findsOneWidget,
  );
  await t.tap(find.text(l.cancelButtonLabel));
  await t.pumpAndSettle();
  await t.ensureVisible(plot);
  await t.pumpAndSettle();
  final rect = t.getRect(plot);
  await t.dragFrom(
    Offset(rect.left + rect.width / 3, rect.center.dy),
    Offset(rect.width / 6, 0),
  );
  await t.pumpAndSettle();
  expect(number('119'), findsOneWidget);
  final zero = find.text(zh ? '0 步' : '0 steps');
  await t.scrollUntilVisible(zero.hitTestable(), 160);
  expect(zero.hitTestable(), findsOneWidget);
  final details = find.byKey(const Key('cardio-model-details'));
  await t.scrollUntilVisible(details.hitTestable(), -150);
  await t.tap(details);
  await t.pumpAndSettle();
  final sleep = find.widgetWithText(ChoiceChip, zh ? '睡眠' : 'Sleep');
  await t.scrollUntilVisible(sleep.hitTestable(), 140);
  await t.pumpAndSettle();
  await t.tap(sleep);
  await t.pumpAndSettle();
  expect(t.widget<ChoiceChip>(sleep).selected, isTrue);
  expect(api.calls, 1);
  if (capture != null) {
    await t.ensureVisible(find.byKey(const Key('cardio-model-summary')));
    await t.pumpAndSettle();
    await capture('details-$language');
  }
  final back = find.byKey(const Key('cardio-show-latest'));
  await t.scrollUntilVisible(back.hitTestable(), -180);
  await t.tap(back);
  await t.pumpAndSettle();
  expect(number('128'), findsOneWidget);
  expect(t.takeException(), isNull);
  await t.pumpWidget(const SizedBox.shrink());
}
