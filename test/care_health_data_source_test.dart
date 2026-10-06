import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/global_care.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/health_view_data_source.dart';

Session account(String id) => Session(
  accessToken: 'synthetic',
  refreshToken: '',
  expiresAt: DateTime.utc(2030),
  memberId: id,
  accountKey: 'global:member:$id',
  displayName: 'Synthetic',
);
Map<String, Object?> sample(String metric) => {
  'id': 'synthetic-record',
  'metric': metric,
  'observedAt': '2026-10-02T23:00:00Z',
  'timezoneOffsetMinutes': 480,
  'values': {'value': 6.5},
  'unit': 'h',
  'quality': 'device_reported',
  'sleepTimeline': {'must': 'not be imported'},
};

class Controller extends Fake implements AppController {
  @override
  WellnessReleasePolicy get healthReleasePolicy =>
      const WellnessReleasePolicy();
  @override
  bool get isWellnessOnly => false;
  @override
  bool isMetricAvailableInRelease(HealthMetric metric) => true;
  @override
  Session? session = account('one');
  final listeners = <VoidCallback>[];
  bool active = true;
  Set<String> metrics = {'sleep', 'heart_rate'};
  Completer<List<Map<String, Object?>>>? pending;
  int rangeCalls = 0;
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  void changeAccount() {
    session = account('two');
    for (final listener in List.of(listeners)) {
      listener();
    }
  }

  @override
  Future<List<GlobalCareRelationship>> globalCareRelationships() async => [
    GlobalCareRelationship(
      id: 'relationship',
      status: active ? 'active' : 'revoked',
      received: false,
      name: 'Synthetic member',
      metrics: metrics,
    ),
  ];
  @override
  Future<List<Map<String, Object?>>> globalCareRecordsRange(
    String id,
    String metric,
    DateTime start,
    DateTime end,
  ) {
    rangeCalls++;
    return pending?.future ?? Future.value([sample(metric)]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Controller controller;
  late CareHealthDataSource source;
  setUp(() {
    controller = Controller();
    source = CareHealthDataSource(
      controller: controller,
      owner: controller.session!.accountKey,
      relationshipId: 'relationship',
      label: 'Synthetic member',
    );
  });
  tearDown(() => source.dispose());
  test(
    'authorized summaries remain read-only and never import local sleep timeline',
    () async {
      final rows = await source.load(
        HealthMetric.sleep,
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 4),
      );
      expect(rows.single.values['value'], 6.5);
      expect(rows.single.deviceId, 'care:relationship');
      expect(rows.single.sleepTimeline, isNull);
      expect(rows.single.timezone, '+08:00');
      expect(controller.rangeCalls, 1);
    },
  );
  test('late response is discarded after account switch', () async {
    controller.pending = Completer();
    final loading = source.load(
      HealthMetric.sleep,
      DateTime(2026, 10, 3),
      DateTime(2026, 10, 4),
    );
    await Future<void>.delayed(Duration.zero);
    final failure = expectLater(loading, throwsA(isA<ApiException>()));
    controller.changeAccount();
    controller.pending!.complete([sample('sleep')]);
    await failure;
    expect(source.valid, isFalse);
    expect(source.metrics, isEmpty);
  });
  test('revocation clears previously available grants', () async {
    await source.revalidate();
    controller.active = false;
    await expectLater(source.revalidate(), throwsA(isA<ApiException>()));
    expect(source.valid, isFalse);
    expect(source.metrics, isEmpty);
  });
  test(
    'grant reduction invalidates all displayed data and blocks unsupported metrics',
    () async {
      await source.revalidate();
      controller.metrics = {'heart_rate'};
      await expectLater(
        source.load(
          HealthMetric.sleep,
          DateTime(2026, 10, 3),
          DateTime(2026, 10, 4),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(controller.rangeCalls, 0);
      expect(source.valid, isFalse);
    },
  );
  test('malformed summaries never invent values or timestamps', () {
    for (final malformed in [
      <String, Object?>{},
      {
        ...sample('sleep'),
        'values': {'value': double.nan},
      },
      {...sample('sleep'), 'timezoneOffsetMinutes': 9999},
      {...sample('sleep'), 'observedAt': 'invalid'},
    ]) {
      expect(
        careHealthRecord(malformed, HealthMetric.sleep, 'relationship'),
        isNull,
      );
    }
  });
}
