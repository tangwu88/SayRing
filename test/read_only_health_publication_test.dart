import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/read_only_health_features.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/read_only_health_service.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/health_trend_page.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/wellness_release.dart';

const _three = {
  HealthMetric.heartRate,
  HealthMetric.hrv,
  HealthMetric.bloodOxygen,
};

Map<String, Object?> _config([Map<String, Object?>? flags]) => {
  'product': 'say-ring',
  'platform': 'ios',
  'readOnlyHealth': {
    'schemaVersion': 1,
    'validForSeconds': 300,
    'metrics': flags ?? {'heart_rate': true, 'hrv': true, 'blood_oxygen': true},
  },
};

class _Api extends Fake implements SaydianApi, SayRingReadOnlyHealthApi {
  Set<HealthMetric> metrics = _three;
  bool fail = false;
  Completer<ReadOnlyHealthFeatureSnapshot>? response;
  Duration validity = const Duration(minutes: 5);
  int reads = 0;
  @override
  Future<ReadOnlyHealthFeatureSnapshot> getReadOnlyHealthFeatures() async {
    reads++;
    if (fail) throw const ApiException('synthetic-failure');
    return response?.future ??
        ReadOnlyHealthFeatureSnapshot(metrics: metrics, validity: validity);
  }
}

class _Bridge extends Fake
    implements WearableBridge, WearableReadOnlyHealthPolicyBridge {
  final grants = <Set<HealthMetric>>[];
  bool fail = false;
  @override
  Future<void> configureReadOnlyHealthMetrics(
    Set<HealthMetric> metrics, {
    required Duration validity,
  }) async {
    grants.add(metrics.toSet());
    if (fail) throw StateError('synthetic-native-rejection');
  }
}

HealthRecord _record(HealthMetric metric, {DateTime? measuredAt}) =>
    HealthRecord(
      id: 'synthetic-${metric.wireName}',
      metric: metric,
      values: {'value': metric == HealthMetric.bloodOxygen ? 98 : 70},
      unit: metric.defaultUnit,
      measuredAt: measuredAt ?? DateTime.utc(2026, 10, 18, 1),
      timezone: '+08:00',
      deviceId: 'qring:SYNTHETIC',
      firmwareVersion: 'synthetic',
      quality: 'unknown',
      source: MeasurementSource.wearable,
      rawVersion: 1,
    );

void main() {
  test(
    'public config request is product/platform bound and sends no identity',
    () async {
      final api = GlobalSaydianApiClient(
        MemorySessionVault(),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.host, 'app.saydian.cn');
          expect(
            request.url.path,
            '/global/api/saydian-app/v2/support/app-display',
          );
          expect(request.url.queryParameters, {
            'product': 'say-ring',
            'platform': 'ios',
          });
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(
            jsonEncode({'code': 200, 'data': _config()}),
            200,
          );
        }),
      );
      final snapshot = await api.getReadOnlyHealthFeatures();
      expect(snapshot.metrics, _three);
      expect(snapshot.validity, const Duration(minutes: 5));
    },
  );

  test('malformed, foreign and medical configurations cannot grant access', () {
    final valid = _config();
    for (final data in [
      <String, Object?>{},
      {...valid, 'product': 'saydian'},
      {...valid, 'platform': 'android'},
      {...valid, 'readOnlyHealth': null},
      _config({'heart_rate': 'true'}),
      _config({'blood_pressure': true}),
      _config({'new_metric': true}),
      {
        ...valid,
        'readOnlyHealth': {
          'schemaVersion': 2,
          'validForSeconds': 300,
          'metrics': {},
        },
      },
      {
        ...valid,
        'readOnlyHealth': {
          'schemaVersion': 1,
          'validForSeconds': 301,
          'metrics': {},
        },
      },
      {
        ...valid,
        'readOnlyHealth': {
          'schemaVersion': 1,
          'validForSeconds': true,
          'metrics': {},
        },
      },
    ]) {
      expect(
        () => ReadOnlyHealthFeatureSnapshot.fromMap(data),
        throwsFormatException,
      );
    }
    expect(
      ReadOnlyHealthFeatureSnapshot.fromMap(
        _config({'heart_rate': false}),
      ).metrics,
      isEmpty,
    );
  });

  test(
    'refresh failure closes the native and Dart grant without persistence',
    () async {
      final features = ReadOnlyHealthFeatures();
      final api = _Api();
      final bridge = _Bridge();
      final service = ReadOnlyHealthFeatureService(
        policy: WellnessReleasePolicy(
          enabled: true,
          readOnlyFeatures: features,
        ),
        api: api,
        bridge: bridge,
      );
      addTearDown(service.dispose);
      await service.refresh();
      expect(features.metrics, _three);
      api.fail = true;
      await service.refresh();
      expect(features.metrics, isEmpty);
      expect(bridge.grants.last, isEmpty);
      expect(ReadOnlyHealthFeatures().metrics, isEmpty);
    },
  );

  test('native rejection cannot publish a card grant', () async {
    final features = ReadOnlyHealthFeatures();
    final service = ReadOnlyHealthFeatureService(
      policy: WellnessReleasePolicy(enabled: true, readOnlyFeatures: features),
      api: _Api(),
      bridge: _Bridge()..fail = true,
    );
    addTearDown(service.dispose);
    await service.refresh();
    expect(features.metrics, isEmpty);
  });

  test('single-flight refresh and dispose reject late configuration', () async {
    final features = ReadOnlyHealthFeatures();
    final api = _Api()..response = Completer<ReadOnlyHealthFeatureSnapshot>();
    final bridge = _Bridge();
    final service = ReadOnlyHealthFeatureService(
      policy: WellnessReleasePolicy(enabled: true, readOnlyFeatures: features),
      api: api,
      bridge: bridge,
    );
    final first = service.refresh();
    final second = service.refresh();
    expect(api.reads, 1);
    service.dispose();
    api.response!.complete(
      const ReadOnlyHealthFeatureSnapshot(
        metrics: _three,
        validity: Duration(minutes: 5),
      ),
    );
    await Future.wait([first, second]);
    expect(features.metrics, isEmpty);
    expect(bridge.grants.every((grant) => grant.isEmpty), isTrue);
  });

  testWidgets('expiry closes a real lease without another API result', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 18);
    final features = ReadOnlyHealthFeatures(now: () => now);
    final bridge = _Bridge();
    final service = ReadOnlyHealthFeatureService(
      policy: WellnessReleasePolicy(enabled: true, readOnlyFeatures: features),
      api: _Api()..validity = const Duration(seconds: 1),
      bridge: bridge,
    );
    await service.refresh();
    expect(features.metrics, _three);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(features.metrics, isEmpty);
    expect(bridge.grants.last, isEmpty);
    service.dispose();
  });

  testWidgets(
    'home cards and all-data follow flags while manual actions stay closed',
    (tester) async {
      final features = ReadOnlyHealthFeatures();
      final api = _Api();
      final store = MemoryHealthStore();
      final records = [
        ..._three.map(_record),
        _record(HealthMetric.bloodPressure),
      ];
      await store.upsert(records);
      final controller = AppController(
        MemorySessionVault(),
        api,
        store,
        _Bridge(),
        wellnessOnly: true,
        healthReadPolicy: WellnessReleasePolicy(
          enabled: true,
          readOnlyFeatures: features,
        ),
      );
      controller.healthRecords = records;
      Future<void> pumpHome() async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DashboardPage(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpHome();
      expect(
        find.byKey(const ValueKey('health-metric-heartRate')),
        findsNothing,
      );
      await controller.refreshReadOnlyHealthFeatures();
      await pumpHome();
      for (final metric in _three) {
        expect(controller.shouldShowHealthMetric(metric), isTrue);
        expect(controller.canMeasureHealthMetric(metric), isFalse);
      }
      expect(controller.homeHealthCardMetrics, [
        HealthMetric.heartRate,
        HealthMetric.hrv,
        HealthMetric.bloodOxygen,
      ]);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('health-metric-heartRate')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('health-metric-heartRate')),
        findsOneWidget,
      );
      expect(
        controller.shouldShowHealthMetric(HealthMetric.bloodPressure),
        isFalse,
      );
      expect(controller.healthAlertsAvailable, isFalse);
      api.metrics = const {};
      await controller.refreshReadOnlyHealthFeatures();
      await pumpHome();
      expect(
        find.byKey(const ValueKey('health-metric-heartRate')),
        findsNothing,
      );
      expect((await store.recent()).length, records.length);
      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final metric in _three) {
    testWidgets('historical ${metric.wireName} card opens its record date', (
      tester,
    ) async {
      final features = ReadOnlyHealthFeatures();
      final store = MemoryHealthStore();
      final record = _record(metric, measuredAt: DateTime.utc(2025, 1, 4, 21));
      await store.upsert([record]);
      final controller = AppController(
        MemorySessionVault(),
        _Api(),
        store,
        _Bridge(),
        wellnessOnly: true,
        healthReadPolicy: WellnessReleasePolicy(
          enabled: true,
          readOnlyFeatures: features,
        ),
      );
      try {
        await controller.refreshReadOnlyHealthFeatures();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DashboardPage(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(ValueKey('health-metric-${metric.name}'));
        await tester.scrollUntilVisible(
          card,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<HealthTrendPage>(find.byType(HealthTrendPage))
              .initialDate,
          record.measuredAt,
        );
        expect(find.text('该时间段暂无数据'), findsNothing);
        expect(controller.canMeasureHealthMetric(metric), isFalse);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    });
  }

  testWidgets('an already-open detail reacts to feature withdrawal', (
    tester,
  ) async {
    final features = ReadOnlyHealthFeatures();
    final api = _Api();
    final controller = AppController(
      MemorySessionVault(),
      api,
      MemoryHealthStore(),
      _Bridge(),
      wellnessOnly: true,
      healthReadPolicy: WellnessReleasePolicy(
        enabled: true,
        readOnlyFeatures: features,
      ),
    );
    await controller.refreshReadOnlyHealthFeatures();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HealthRecordDetailPage(
          controller: controller,
          record: _record(HealthMetric.heartRate),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WellnessReleaseUnavailablePage), findsNothing);
    api.metrics = const {};
    await controller.refreshReadOnlyHealthFeatures();
    await tester.pumpAndSettle();
    expect(find.byType(WellnessReleaseUnavailablePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
