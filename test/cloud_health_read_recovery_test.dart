import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/read_only_health_features.dart';
import 'package:saydian_app/domain/u19_health_features.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'policy refresh retries the cloud read once without requeueing imports',
    () async {
      final api = _CloudApi((call, _) async {
        if (call == 1) throw _policyChanged;
        return _page;
      });
      final (controller, store) = await _controller(api);
      addTearDown(controller.dispose);

      await controller.synchronizeCloud();

      expect(api.requestedBefore, [null, null]);
      expect(controller.healthRecords.map((record) => record.id), [
        'cloud-heart',
      ]);
      expect((await store.recent()).map((record) => record.id), [
        'cloud-heart',
      ]);
      expect(await store.pending(), isEmpty);
      expect(controller.cloudSyncStatus, contains('读取 1 条'));
    },
  );

  test(
    'policy changes on later pages restart with current policy and deduplicate',
    () async {
      final api = _CloudApi((call, before) async {
        if (call == 2) throw _policyChanged;
        return before == null
            ? CloudHealthPage(records: [_record], nextCursor: 'older')
            : const CloudHealthPage(records: [], nextCursor: null);
      });
      final (controller, store) = await _controller(api);
      addTearDown(controller.dispose);

      await controller.synchronizeCloud();

      expect(api.requestedBefore, [null, 'older', null, 'older']);
      expect((await store.recent()).map((record) => record.id), [
        'cloud-heart',
      ]);
      expect(await store.pending(), isEmpty);
    },
  );

  test('repeated policy changes stop after one retry', () async {
    final api = _CloudApi((_, _) async => throw _policyChanged);
    final (controller, _) = await _controller(api);
    addTearDown(controller.dispose);

    await controller.synchronizeCloud();

    expect(api.requestedBefore, [null, null]);
    expect(controller.cloudSyncStatus, isNot(contains('读取 1 条')));
  });

  test('retry waits for both ring and U19 configuration to finish', () async {
    final policy = WellnessReleasePolicy(
      enabled: true,
      readOnlyFeatures: ReadOnlyHealthFeatures(),
      manualFeatures: ManualHealthFeatures(),
      u19Features: U19HealthFeatures(),
    );
    final api = _PolicyApi((call, _) async {
      if (call == 1 || !policy.u19Features!.active) throw _policyChanged;
      return _page;
    });
    final (controller, store) = await _controller(
      api,
      policy: policy,
      wearable: _PolicyWearable(),
    );
    addTearDown(controller.dispose);
    final refresh = controller.refreshReadOnlyHealthFeatures();
    await api.u19Entered.future;
    var completed = false;
    final sync = controller.synchronizeCloud().then((_) => completed = true);
    try {
      await pumpEventQueue();
      expect(api.requestedBefore, [null]);
      expect(completed, isFalse);
    } finally {
      api.u19Response.complete(
        const U19HealthSnapshot(
          {HealthMetric.heartRate},
          {HealthMetric.heartRate},
          Duration(minutes: 5),
        ),
      );
      await Future.wait([refresh, sync]);
    }
    expect(api.requestedBefore, [null, null]);
    expect((await store.recent()).map((record) => record.id), ['cloud-heart']);
    expect(controller.cloudSyncStatus, contains('读取 1 条'));
  });

  test('authentication and ordinary read errors are not retried', () async {
    for (final code in ['UNAUTHORIZED', 'INVALID_HEALTH_PAGE']) {
      final api = _CloudApi(
        (_, _) async => throw ApiException('read failed', code: code),
      );
      final (controller, store) = await _controller(api);
      try {
        await controller.synchronizeCloud();
        expect(api.requestedBefore, [null]);
        expect(await store.recent(), isEmpty);
      } finally {
        controller.dispose();
      }
    }
  });

  test(
    'a second sync caller waits for the active operation without duplicating it',
    () async {
      final entered = Completer<void>();
      final response = Completer<CloudHealthPage>();
      final api = _CloudApi((_, _) {
        if (!entered.isCompleted) entered.complete();
        return response.future;
      });
      final (controller, _) = await _controller(api);
      addTearDown(controller.dispose);
      final first = controller.synchronizeCloud();
      await entered.future;
      var secondCompleted = false;
      final second = controller.synchronizeCloud().then(
        (_) => secondCompleted = true,
      );
      try {
        await Future<void>.delayed(Duration.zero);
        expect(secondCompleted, isFalse);
        expect(api.requestedBefore, [null]);
      } finally {
        response.complete(_page);
        await Future.wait([first, second]);
      }
      expect(controller.healthRecords.map((record) => record.id), [
        'cloud-heart',
      ]);
    },
  );

  test('disposal prevents a policy retry and late record import', () async {
    final entered = Completer<void>();
    final response = Completer<CloudHealthPage>();
    final api = _CloudApi((_, _) {
      entered.complete();
      return response.future;
    });
    final (controller, _) = await _controller(api);
    final first = controller.synchronizeCloud();
    await entered.future;
    controller.dispose();
    response.completeError(_policyChanged);
    await first;
    expect(api.requestedBefore, [null]);
    expect(controller.healthRecords, isEmpty);
  });

  test('policy retry never repeats an already acknowledged upload', () async {
    final api = _CloudApi((call, _) async {
      if (call == 1) throw _policyChanged;
      return _page;
    });
    final (controller, store) = await _controller(api);
    addTearDown(controller.dispose);
    await store.upsert([_record]);

    await controller.synchronizeCloud();

    expect(api.uploads, 1);
    expect(api.requestedBefore, [null, null]);
    expect(await store.pending(), isEmpty);
  });

  test('logout prevents a policy retry while the old sync drains', () async {
    final entered = Completer<void>();
    final response = Completer<CloudHealthPage>();
    final api = _CloudApi((_, _) {
      entered.complete();
      return response.future;
    });
    final (controller, store) = await _controller(api);
    addTearDown(controller.dispose);
    final sync = controller.synchronizeCloud();
    await entered.future;
    final logout = controller.logout();
    response.completeError(_policyChanged);
    await Future.wait([sync, logout]);

    expect(api.requestedBefore, [null]);
    expect(store.importedIds, isEmpty);
    expect(controller.session, isNull);
  });

  test(
    'logout rejects a late successful cloud page before importing it',
    () async {
      final entered = Completer<void>();
      final response = Completer<CloudHealthPage>();
      final api = _CloudApi((_, _) {
        entered.complete();
        return response.future;
      });
      final (controller, store) = await _controller(api);
      addTearDown(controller.dispose);
      final sync = controller.synchronizeCloud();
      await entered.future;
      final logout = controller.logout();
      response.complete(_page);
      await Future.wait([sync, logout]);

      expect(api.requestedBefore, [null]);
      expect(store.importedIds, isEmpty);
      expect(controller.session, isNull);
    },
  );
}

const _policyChanged = ApiException(
  'configuration updated',
  code: 'HEALTH_POLICY_CHANGED',
);

final _record = HealthRecord(
  id: 'cloud-heart',
  metric: HealthMetric.heartRate,
  values: const {'value': 72},
  unit: 'bpm',
  measuredAt: DateTime.utc(2026, 9, 13, 1),
  timezone: '+00:00',
  deviceId:
      'server:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  firmwareVersion: 'test',
  quality: 'valid',
  source: MeasurementSource.wearable,
  rawVersion: 1,
  sourceVendor: 'urion',
  sourceDeviceCategory: 'watch',
  sourceApp: 'say-ring',
);
final _page = CloudHealthPage(records: [_record], nextCursor: null);

Future<(AppController, _Store)> _controller(
  _CloudApi api, {
  WellnessReleasePolicy? policy,
  WearableBridge? wearable,
}) async {
  final store = _Store();
  await store.initialize();
  await store.switchOwner('global:member:owner-a');
  final controller =
      AppController(
          MemorySessionVault(),
          api,
          store,
          wearable ?? _Wearable(),
          allowAutomaticWearableRestore: false,
          wellnessOnly: policy != null,
          healthReadPolicy: policy,
        )
        ..session = Session(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
          expiresAt: DateTime.utc(2030),
          memberId: 'owner-a',
          displayName: 'Owner A',
          accountKey: 'global:member:owner-a',
        );
  return (controller, store);
}

class _CloudApi extends Fake implements SaydianApi, CloudHealthRecordReader {
  _CloudApi(this.read);
  final Future<CloudHealthPage> Function(int call, String? before) read;
  final List<String?> requestedBefore = [];
  int uploads = 0;

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    uploads++;
    return BatchUploadResult(
      acceptedIds: batch.records.map((record) => record.id).toSet(),
      rejected: const {},
      nextCursor: null,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<CloudHealthPage> getCloudHealthRecords({
    int limit = 200,
    String? before,
  }) {
    requestedBefore.add(before);
    return read(requestedBefore.length, before);
  }
}

class _Wearable extends Fake implements WearableBridge {}

class _PolicyApi extends _CloudApi
    implements SayRingReadOnlyHealthApi, SayRingU19HealthApi {
  _PolicyApi(super.read);
  final u19Entered = Completer<void>();
  final u19Response = Completer<U19HealthSnapshot>();

  @override
  Future<ReadOnlyHealthFeatureSnapshot> getReadOnlyHealthFeatures() async =>
      const ReadOnlyHealthFeatureSnapshot(
        metrics: {HealthMetric.heartRate},
        validity: Duration(minutes: 5),
      );

  @override
  Future<U19HealthSnapshot> getU19HealthFeatures() {
    if (!u19Entered.isCompleted) u19Entered.complete();
    return u19Response.future;
  }
}

class _PolicyWearable extends _Wearable
    implements
        WearableReadOnlyHealthPolicyBridge,
        WearableManualHealthPolicyBridge,
        WearableU19HealthPolicyBridge {
  @override
  Future<void> configureReadOnlyHealthMetrics(
    Set<HealthMetric> metrics, {
    required Duration validity,
  }) async {}

  @override
  Future<void> configureManualHealthMetrics(
    Set<HealthMetric> metrics, {
    required Duration validity,
  }) async {}

  @override
  Future<void> configureU19HealthMetrics(
    Set<HealthMetric> reads,
    Set<HealthMetric> manual, {
    required Duration validity,
  }) async {}
}

class _Store extends MemoryHealthStore {
  final List<String> importedIds = [];

  @override
  Future<void> upsertSynced(List<HealthRecord> records) async {
    importedIds.addAll(records.map((record) => record.id));
    await super.upsertSynced(records);
  }
}
