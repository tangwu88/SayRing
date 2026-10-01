import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:saydian_app/domain/sleep_timeline.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  for (final encrypted in [false, true]) {
    test(
      '${encrypted ? 'database' : 'memory'} latest includes real summary-only days',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'say-ring-sleep-summary-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final HealthStore store = encrypted
            ? _encrypted(path.join(directory.path, 'health.db'))
            : MemoryHealthStore();
        final details = store as SleepDetailStore;
        await store.initialize();
        addTearDown(store.close);
        await details.saveConfirmedDay(_day(60));
        await details.saveConfirmedDay(
          _day(
            0,
            date: '2026-10-02',
            rawSummary: const {'deepSeconds': 3600, 'totalSeconds': 4200},
          ),
        );
        await details.saveConfirmedDay(_day(0, date: '2026-10-03'));
        final latest = await details.loadLatestDay();
        expect(latest!.sdkDate, '2026-10-02');
        expect(latest.hasSegments, isFalse);
        expect(latest.hasConfirmedSummary, isTrue);
        expect(latest.summaryValues['value'], 1);
        expect(latest.startedAt, isNull);
      },
    );
    test(
      '${encrypted ? 'encrypted database contract' : 'memory'} preserves day revisions and scope',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'say-ring-sleep-store-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = path.join(directory.path, 'health.db');
        final HealthStore store = encrypted
            ? _encrypted(file)
            : MemoryHealthStore();
        final details = store as SleepDetailStore;
        await store.initialize();
        addTearDown(store.close);
        await store.switchOwner('account-a');
        expect((await details.saveConfirmedDay(_day(60))).revision, 1);
        expect(
          (await details.saveConfirmedDay(_day(60, readHour: 20))).revision,
          1,
        );
        expect((await details.saveConfirmedDay(_day(90))).revision, 2);
        // Reverting to earlier SDK contents is a new confirmed revision, not a
        // lookup of the old packet by its digest.
        expect((await details.saveConfirmedDay(_day(60))).revision, 3);
        expect((await details.loadLatestDay())!.asleepMinutes, 60);
        expect(await store.pending(), isEmpty);
        await details.saveConfirmedDay(_day(20, device: 'qring:other'));
        expect(
          (await details.loadDays(
            startSdkDate: '2026-10-01',
            endSdkDate: '2026-10-01',
          )).length,
          2,
        );
        expect(
          (await details.loadDays(
            deviceId: 'qring:device',
            startSdkDate: '2026-10-01',
            endSdkDate: '2026-10-01',
          )).single.revision,
          3,
        );
        await details.saveConfirmedDay(_day(0, date: '2026-10-02'));
        expect(
          (await details.loadDays(
            deviceId: 'qring:device',
            startSdkDate: '2026-10-02',
            endSdkDate: '2026-10-02',
          )).single.hasSegments,
          isFalse,
        );
        expect(
          (await details.loadLatestDay(deviceId: 'qring:device'))!.sdkDate,
          '2026-10-01',
        );

        await store.switchOwner('account-b');
        expect(await details.loadLatestDay(), isNull);
        expect(
          await details.loadDays(
            startSdkDate: '2026-10-01',
            endSdkDate: '2026-10-02',
          ),
          isEmpty,
        );
        expect((await details.saveConfirmedDay(_day(30))).revision, 1);
        await store.switchOwner('account-a');
        expect(
          (await details.loadLatestDay(deviceId: 'qring:device'))!.revision,
          3,
        );

        if (encrypted) {
          await store.close();
          final database = await databaseFactoryFfi.openDatabase(file);
          final snapshots = await database.query(
            'metadata',
            where: 'owner_id = ? AND key LIKE ?',
            whereArgs: ['account-a', 'sleep.snapshot.%'],
          );
          expect(
            snapshots.length,
            5,
          ); // 3 revisions, another device, explicit empty day.
          expect(
            (await database.rawQuery(
              'PRAGMA user_version',
            )).single['user_version'],
            6,
          );
          await database.close();
          final reopened = _encrypted(file);
          await reopened.initialize();
          await reopened.switchOwner('account-a');
          expect(
            (await reopened.loadLatestDay(deviceId: 'qring:device'))!.revision,
            3,
          );
          await reopened.close();
        }
      },
    );
  }

  test(
    'database serializes concurrent changed snapshots and keeps date range inclusive',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'say-ring-sleep-concurrent-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = _encrypted(path.join(directory.path, 'health.db'));
      await store.initialize();
      addTearDown(store.close);
      final revisions = await Future.wait([
        store.saveConfirmedDay(_day(60)),
        store.saveConfirmedDay(_day(90)),
      ]);
      expect(revisions.map((day) => day.revision), [1, 2]);
      expect(
        (await store.loadDays(
          startSdkDate: '2026-10-01',
          endSdkDate: '2026-10-01',
        )).single.asleepMinutes,
        90,
      );
      expect(
        () => store.loadDays(
          startSdkDate: '2026-10-02',
          endSdkDate: '2026-10-01',
        ),
        throwsArgumentError,
      );
    },
  );
}

EncryptedHealthStore _encrypted(String file) => EncryptedHealthStore(
  MemorySessionVault(),
  databasePathProvider: () async => file,
  databaseOpener:
      (
        databasePath, {
        required password,
        required version,
        onConfigure,
        onCreate,
        onUpgrade,
      }) => databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: version,
          onConfigure: onConfigure,
          onCreate: onCreate,
          onUpgrade: onUpgrade,
        ),
      ),
);

SleepTimeline _day(
  int minutes, {
  String device = 'qring:device',
  String date = '2026-10-01',
  int readHour = 18,
  Map<String, num> rawSummary = const {},
}) => SleepTimeline(
  deviceId: device,
  sdkDate: date,
  timezone: '+08:00',
  readAt: DateTime.utc(2026, 10, 3, readHour),
  rawSummary: rawSummary,
  sessions: minutes == 0
      ? []
      : [
          SleepSession(
            kind: SleepSessionKind.night,
            segments: [
              SleepStageSegment(
                startAt: DateTime.utc(2026, 9, 30, 14),
                endAt: DateTime.utc(
                  2026,
                  9,
                  30,
                  14,
                ).add(Duration(minutes: minutes)),
                stage: SleepStage.deep,
                rawStage: 1,
              ),
            ],
          ),
        ],
);
