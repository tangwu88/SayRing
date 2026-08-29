import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/sync_service.dart';

void main() {
  test('uploads 1000 offline records once without duplicates', () async {
    final store = MemoryHealthStore();
    final api = _AcceptingApi();
    final service = HealthSyncService(store, api);
    await store.initialize();

    final records = List.generate(
      1000,
      (index) => HealthRecord(
        id: 'record-$index',
        metric: HealthMetric.heartRate,
        values: {'value': 60 + index % 40},
        unit: 'bpm',
        measuredAt: DateTime.utc(2026, 7, 29).add(Duration(minutes: index)),
        timezone: '+08:00',
        deviceId: 'device-1',
        firmwareVersion: '1.0.0',
        quality: 'good',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      ),
    );
    await store.upsert(records);
    await store.upsert(records);

    final outcome = await service.synchronizeNow();

    expect(outcome.uploaded, 1000);
    expect(outcome.rejected, 0);
    expect(api.receivedIds, hasLength(1000));
    expect(api.maximumBatchSize, lessThanOrEqualTo(10));
    expect(await store.pending(), isEmpty);
  });

  test('keeps the queue when the backend batch endpoint is absent', () async {
    final store = MemoryHealthStore();
    final service = HealthSyncService(store, _UnconfiguredApi());
    await store.upsert([
      HealthRecord(
        id: 'record-1',
        metric: HealthMetric.steps,
        values: const {'value': 1000},
        unit: '步',
        measuredAt: DateTime.utc(2026, 7, 29),
        timezone: '+08:00',
        deviceId: 'device-1',
        firmwareVersion: '1.0.0',
        quality: 'good',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      ),
    ]);

    final outcome = await service.synchronizeNow();

    expect(outcome.uploaded, 0);
    expect(outcome.message, contains('未配置'));
    expect(await store.pending(), hasLength(1));
  });

  test('quarantines SDK sentinel values instead of uploading them', () async {
    final store = MemoryHealthStore();
    final api = _AcceptingApi();
    final service = HealthSyncService(store, api);
    await store.initialize();
    await store.upsert([
      _measurement('invalid-heart', HealthMetric.heartRate, {'value': 1}),
      _measurement('invalid-oxygen', HealthMetric.bloodOxygen, {'value': 1}),
      _measurement('valid-heart', HealthMetric.heartRate, {'value': 78}),
    ]);

    final outcome = await service.synchronizeNow();

    expect(outcome.uploaded, 1);
    expect(outcome.rejected, 2);
    expect(api.receivedIds, {'valid-heart'});
    expect(await store.pending(), isEmpty);
    expect((await store.recent()).map((record) => record.id), ['valid-heart']);
  });

  test(
    'account switch prevents a delayed upload from marking or moving cursors',
    () async {
      final store = MemoryHealthStore();
      final api = _DelayedAcceptingApi();
      final service = HealthSyncService(store, api);
      await store.initialize();
      await store.switchOwner('account-a');
      await store.upsert([
        _measurement('account-a-record', HealthMetric.heartRate, {'value': 78}),
      ]);
      var current = true;

      final sync = service.synchronizeNow(isCurrent: () => current);
      await api.started.future;
      current = false;
      await store.switchOwner('account-b');
      api.result.complete(
        const BatchUploadResult(
          acceptedIds: {'account-a-record'},
          rejected: {},
          nextCursor: 'cursor-a',
        ),
      );
      await sync;

      expect(await store.pending(), isEmpty);
      expect(await store.readCursor(), isNull);
      await store.switchOwner('account-a');
      expect((await store.pending()).single.id, 'account-a-record');
      expect(await store.readCursor(), isNull);
    },
  );
}

HealthRecord _measurement(
  String id,
  HealthMetric metric,
  Map<String, num> values,
) => HealthRecord(
  id: id,
  metric: metric,
  values: values,
  unit: metric.defaultUnit,
  measuredAt: DateTime.utc(2026, 8, 15),
  timezone: '+08:00',
  deviceId: 'W9S',
  firmwareVersion: 'test',
  quality: 'device_reported',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);

class _AcceptingApi extends _BaseFakeApi {
  final Set<String> receivedIds = {};
  int maximumBatchSize = 0;

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    if (batch.records.length > maximumBatchSize) {
      maximumBatchSize = batch.records.length;
    }
    final accepted = batch.records.map((record) => record.id).toSet();
    receivedIds.addAll(accepted);
    return BatchUploadResult(
      acceptedIds: accepted,
      rejected: const {},
      nextCursor: 'cursor-${receivedIds.length}',
    );
  }
}

class _UnconfiguredApi extends _BaseFakeApi {
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) {
    throw const FeatureNotConfiguredException('批量健康同步接口未配置');
  }
}

class _DelayedAcceptingApi extends _BaseFakeApi {
  final Completer<void> started = Completer<void>();
  final Completer<BatchUploadResult> result = Completer<BatchUploadResult>();

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) {
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

abstract class _BaseFakeApi implements SaydianApi {
  @override
  Future<Map<String, Object?>> addCare(String mobile) async => const {};

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => const [];

  @override
  Future<Map<String, Object?>> getCareMemberPreview({
    required int id,
    required String day,
    int? memberId,
  }) async => const {};

  @override
  Future<Map<String, Object?>> getMemberProfile() async => const {};

  @override
  Future<void> saveMemberProfile({
    required String nickname,
    required int gender,
    required String birthday,
    required double height,
    required double weight,
    String? headPortrait,
  }) async {}

  @override
  Future<Map<String, Object?>> getActivityGoals() async => const {};

  @override
  Future<void> saveActivityGoals({
    required int steps,
    required double distance,
    required int calories,
  }) async {}

  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];

  @override
  Future<Map<String, Object?>> getArticle(int id) async => const {};

  @override
  Future<Map<String, Object?>> getSingleArticle(int id) async => const {};

  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      const [];

  @override
  Future<Map<String, Object?>> getNotification(int id) async => const {};

  @override
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  }) async => const [];

  @override
  Future<Map<String, Object?>> sendAiMessage({
    required int app,
    required String message,
    String? sessionId,
  }) async => const {};

  @override
  Future<List<Map<String, Object?>>> getOrders({int? status}) async => const [];

  @override
  Future<Map<String, Object?>> getOrderDetail(int id) async => const {};

  @override
  Future<List<Map<String, Object?>>> getAddresses() async => const [];

  @override
  Future<Session> login(String username, String password) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<Session> register(String mobile, String password) =>
      throw UnimplementedError();
}
