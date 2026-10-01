import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sleep_timeline.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

SleepTimeline _timeline({
  String device = 'qring:TEST',
  bool empty = false,
  String sdkDate = '2026-09-30',
}) => SleepTimeline(
  deviceId: device,
  sdkDate: sdkDate,
  timezone: '+08:00',
  readAt: DateTime.utc(2026, 9, 30, 1),
  sessions: empty
      ? []
      : [
          SleepSession(
            kind: SleepSessionKind.night,
            segments: [
              SleepStageSegment(
                startAt: DateTime.utc(2026, 9, 29, 16),
                endAt: DateTime.utc(2026, 9, 29, 18),
                stage: SleepStage.deep,
                rawStage: 3,
              ),
            ],
          ),
        ],
);

HealthRecord _summary({
  String device = 'qring:TEST',
  num hours = 8,
  DateTime? measuredAt,
}) => HealthRecord(
  id: 'summary-$device-$hours',
  metric: HealthMetric.sleep,
  values: {'value': hours},
  unit: 'h',
  measuredAt: measuredAt ?? DateTime.utc(2026, 9, 29, 16),
  timezone: '+08:00',
  deviceId: device,
  firmwareVersion: '',
  quality: 'unknown',
  source: MeasurementSource.wearable,
  origin: MeasurementOrigin.watchHistory,
  rawVersion: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<({AppController controller, MemoryHealthStore store, _Wearable ring})>
  setup({bool connect = false}) async {
    final ring = _Wearable();
    final store = MemoryHealthStore();
    final controller = AppController(MemorySessionVault(), _Api(), store, ring);
    addTearDown(controller.dispose);
    addTearDown(ring.emitter.close);
    await controller.initialize();
    expect(await controller.login('owner-a', 'fixture-password'), isTrue);
    if (connect) {
      await controller.connectDevice(
        const DeviceInfo(id: 'qring:TEST', name: 'R21'),
      );
      await _settle();
    }
    return (controller: controller, store: store, ring: ring);
  }

  test(
    'full sleep queries and latest do not depend on the home feed',
    () async {
      final test = await setup();
      await test.store.upsert([_summary()]);
      await test.store.saveConfirmedDay(_timeline());
      test.controller.healthRecords = const [];
      final days = await test.controller.loadSleepDays(
        start: DateTime(2026, 9, 30),
        end: DateTime(2026, 9, 30),
      );
      expect(days.single.sleepTimeline!.revision, 1);
      expect(days.single.values['value'], 2);
      expect((await test.controller.loadLatestSleepDay())!.values['value'], 2);
      expect(await test.store.pending(), hasLength(1));
      expect(
        (await test.store.pending()).single.id,
        isNot(startsWith('sleep-view-')),
      );
    },
  );

  test(
    'explicit empty day persists status without creating a zero sample',
    () async {
      final test = await setup();
      await test.store.saveConfirmedDay(_timeline(empty: true));
      expect(
        await test.controller.loadSleepDays(
          start: DateTime(2026, 9, 30),
          end: DateTime(2026, 9, 30),
        ),
        isEmpty,
      );
      expect(test.controller.sleepReadStatuses['2026-09-30'], 'noData');
      expect(await test.store.pending(), isEmpty);
    },
  );

  test('invalid legacy units never become the latest sleep summary', () async {
    final test = await setup();
    await test.store.upsert([_summary(hours: 395)]);
    expect(await test.controller.loadLatestSleepDay(), isNull);
  });

  test(
    'latest confirmed empty day suppresses its newer stale summary',
    () async {
      final test = await setup();
      await test.store.saveConfirmedDay(_timeline());
      await test.store.upsert([
        _summary(hours: 9, measuredAt: DateTime.utc(2026, 9, 30, 16)),
      ]);
      await test.store.saveConfirmedDay(
        _timeline(sdkDate: '2026-10-01', empty: true),
      );
      final latest = await test.controller.loadLatestSleepDay();
      expect(latest!.sleepTimeline!.sdkDate, '2026-09-30');
      expect(latest.values['value'], 2);
      expect(
        await test.controller.loadSleepDays(
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 1),
        ),
        isEmpty,
      );
    },
  );

  test('empty latest day falls back to older valid legacy sleep', () async {
    final test = await setup();
    await test.store.upsert([
      _summary(hours: 7),
      _summary(hours: 9, measuredAt: DateTime.utc(2026, 9, 30, 16)),
    ]);
    await test.store.saveConfirmedDay(
      _timeline(sdkDate: '2026-10-01', empty: true),
    );
    expect((await test.controller.loadLatestSleepDay())!.values['value'], 7);
  });

  test('bound ring no-data does not borrow another ring sleep', () async {
    final test = await setup(connect: true);
    await test.store.saveConfirmedDay(_timeline(empty: true));
    await test.store.upsert([_summary(device: 'qring:OTHER')]);
    expect(
      await test.controller.loadSleepDays(
        start: DateTime(2026, 9, 30),
        end: DateTime(2026, 9, 30),
      ),
      isEmpty,
    );
    expect(await test.controller.loadLatestSleepDay(), isNull);
    expect(test.controller.sleepReadStatuses['2026-09-30'], 'noData');
  });

  test(
    'preferred device newer legacy summary is not hidden by another ring',
    () async {
      final test = await setup(connect: true);
      await test.store.saveConfirmedDay(_timeline());
      await test.store.upsert([
        _summary(hours: 7, measuredAt: DateTime.utc(2026, 9, 30, 16)),
        _summary(
          device: 'qring:OTHER',
          hours: 9,
          measuredAt: DateTime.utc(2026, 10, 1, 16),
        ),
      ]);
      final latest = await test.controller.loadLatestSleepDay();
      expect(latest!.deviceId, 'qring:TEST');
      expect(latest.values['value'], 7);
    },
  );

  test(
    'empty latest summary still checks legacy days newer than latest details',
    () async {
      final test = await setup();
      await test.store.saveConfirmedDay(_timeline());
      await test.store.upsert([
        _summary(hours: 7, measuredAt: DateTime.utc(2026, 9, 30, 16)),
        _summary(hours: 9, measuredAt: DateTime.utc(2026, 10, 1, 16)),
      ]);
      await test.store.saveConfirmedDay(
        _timeline(sdkDate: '2026-10-02', empty: true),
      );
      expect((await test.controller.loadLatestSleepDay())!.values['value'], 7);
    },
  );

  test(
    'account switch clears status and cannot read another owner timeline',
    () async {
      final test = await setup();
      await test.store.saveConfirmedDay(_timeline(empty: true));
      await test.controller.loadSleepDays(
        start: DateTime(2026, 9, 30),
        end: DateTime(2026, 9, 30),
      );
      expect(test.controller.sleepReadStatuses, isNotEmpty);
      expect(
        await test.controller.login('owner-b', 'fixture-password'),
        isTrue,
      );
      expect(test.controller.sleepReadStatuses, isEmpty);
      expect(await test.controller.loadLatestSleepDay(), isNull);
    },
  );

  test(
    'failed SDK sleep read retains cached timeline and reports partial sync',
    () async {
      final test = await setup(connect: true);
      await test.store.saveConfirmedDay(_timeline());
      final reading = Completer<List<HealthRecord>>();
      test.ring.nextSync = reading.future;
      final sync = test.controller.syncDeviceData();
      await _settle();
      test.ring.emitter.add(
        const WearableEvent(
          type: 'sleepReadStatus',
          payload: {
            'deviceId': 'qring:TEST',
            'sdkDate': '2026-09-30',
            'status': 'failed',
          },
        ),
      );
      await _settle();
      reading.complete([]);
      expect(await sync, isFalse);
      expect(test.controller.sleepReadStatuses['2026-09-30'], 'failed');
      final records = await test.controller.loadSleepDays(
        start: DateTime(2026, 9, 30),
        end: DateTime(2026, 9, 30),
      );
      expect(records.single.sleepTimeline!.asleepMinutes, 120);
      expect(test.controller.sleepReadStatuses['2026-09-30'], 'failed');
    },
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Api extends Fake implements SaydianApi {
  @override
  Future<Session> login(String username, String password) async => Session(
    accessToken: 'fixture-token',
    refreshToken: '',
    expiresAt: DateTime.utc(2030),
    memberId: username,
    displayName: username,
  );
  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => [];
  @override
  Future<Map<String, Object?>> getMemberProfile() async => {};
  @override
  Future<Map<String, Object?>> getActivityGoals() async => {};
  @override
  Future<List<Map<String, Object?>>> getArticles() async => [];
  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      [];
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async =>
      BatchUploadResult(
        acceptedIds: batch.records.map((record) => record.id).toSet(),
        rejected: {},
        nextCursor: null,
      );
}

class _Wearable extends Fake implements WearableBridge {
  final emitter = StreamController<WearableEvent>.broadcast();
  Future<List<HealthRecord>>? nextSync;
  @override
  Stream<WearableEvent> get events => emitter.stream;
  @override
  Future<void> connect(
    String id, {
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(metrics: {HealthMetric.sleep});
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) =>
      nextSync ?? Future.value([]);
  @override
  Future<List<SportRecord>> readSportRecords() async => [];
}
