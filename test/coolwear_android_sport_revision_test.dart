import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Api extends Fake implements SaydianApi {}

class _Ring extends Fake implements WearableBridge {
  late Future<List<SportRecord>> Function() read;
  @override
  Future<List<SportRecord>> readSportRecords() => read();
}

const ring = DeviceInfo(
  id: 'coolwear:AA:BB:CC:DD:EE:FF',
  name: 'R7 Ultra',
  rssi: -55,
);
const workoutId = 'cw-83467701-e96c-3add-a3b1-01cdde122da3';
const lowerCaseId = 'cw-71667646-e89d-3274-a3fe-09a0d5c0681e';
const mixedCaseId = 'cw-b2798c3d-70ed-3935-b42f-f3121876fb0f';
const otherRingId = 'cw-f434404a-ddd0-3c56-94f9-fd1391ccc993';
const localId = 'local:2026-11-01T08:00:00.000Z';
final start = DateTime.utc(2026, 11, 1, 8);
SportRecord workout(int seconds, int steps, {String id = workoutId}) =>
    SportRecord(
      id: id,
      mode: SportMode.walking,
      startedAt: start,
      durationSeconds: seconds,
      distanceKm: steps / 1000,
      calories: 4,
      steps: steps,
    );
AppController _controller(
  HealthStore store,
  _Ring bridge, {
  bool wellnessOnly = false,
}) => AppController(
  MemorySessionVault(),
  _Api(),
  store,
  bridge,
  wellnessOnly: wellnessOnly,
)..connectedDevice = ring;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final partial in [false, true]) {
    test(
      'Android CoolWear cumulative history advances safely (partial=$partial)',
      () async {
        final store = MemoryHealthStore();
        final bridge = _Ring();
        final app = _controller(store, bridge);
        Future<void> receive(SportRecord r) {
          bridge.read = () async {
            if (partial) {
              throw PlatformException(
                code: 'COOLWEAR_SYNC_TIMEOUT',
                details: [r.toMap()],
              );
            }
            return [r];
          };
          return app.refreshSportRecords();
        }

        await store.saveSportRecord(workout(300, 250, id: localId));
        await receive(workout(120, 90));
        await receive(workout(130, 96));
        await receive(workout(120, 90)); // older packet
        await receive(workout(140, 85)); // ambiguous mixed counters
        final shown = app.sportRecords.firstWhere((r) => r.id == workoutId);
        final saved = (await store.localSportRecords()).firstWhere(
          (r) => r.id == workoutId,
        );
        expect(
          [
            shown.durationSeconds,
            shown.steps,
            saved.durationSeconds,
            saved.steps,
          ],
          [130, 96, 130, 96],
        );
        if (partial) expect(app.errorMessage, contains('收到的运动记录已保存'));
        await receive(workout(400, 300, id: localId));
        await receive(workout(400, 310, id: otherRingId));
        final local = (await store.localSportRecords()).firstWhere(
          (r) => r.id == localId,
        );
        expect([local.durationSeconds, local.steps], [300, 250]);
        expect(app.sportRecords.any((r) => r.id == otherRingId), isFalse);
      },
    );
  }

  test(
    'native MAC letter case stays on the exact ring and existing workout row',
    () async {
      for (final keys in [
        (lowerCaseId, workoutId),
        (workoutId, lowerCaseId),
        (mixedCaseId, workoutId),
        (workoutId, mixedCaseId),
      ]) {
        final store = MemoryHealthStore();
        final target = keys.$1 == mixedCaseId || keys.$2 == mixedCaseId
            ? 'aA:Bb:cC:Dd:eE:Ff'
            : 'aa:bb:cc:dd:ee:ff';
        expect(
          await store.importCoolWearAndroidSport(
            target,
            workout(120, 90, id: keys.$1),
          ),
          isTrue,
        );
        expect(
          await store.importCoolWearAndroidSport(
            keys.$1 == lowerCaseId ? target.toUpperCase() : target,
            workout(130, 96, id: keys.$2),
          ),
          isTrue,
        );
        expect(
          await store.importCoolWearAndroidSport(
            target,
            workout(150, 110, id: otherRingId),
          ),
          isFalse,
        );
        final saved = (await store.localSportRecords()).single;
        expect(
          [saved.id, saved.durationSeconds, saved.steps],
          [keys.$1, 130, 96],
        );
      }
    },
  );

  test('late overlapping read cannot roll back a newer completion', () async {
    final store = MemoryHealthStore(), bridge = _Ring();
    final app = _controller(store, bridge);
    final started = Completer<void>(), old = Completer<List<SportRecord>>();
    bridge.read = () {
      started.complete();
      return old.future;
    };
    final first = app.refreshSportRecords();
    await started.future;
    bridge.read = () async => [workout(140, 99)];
    await app.refreshSportRecords();
    old.complete([workout(120, 90)]);
    await first;
    expect(app.sportRecords.single.steps, 99);
    expect((await store.localSportRecords()).single.durationSeconds, 140);
  });

  test(
    'iOS keeps its previous duplicate policy for the same identifier',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final store = MemoryHealthStore(), bridge = _Ring();
      final app = _controller(store, bridge);
      await store.saveSportRecord(workout(120, 90));
      bridge.read = () async => [workout(130, 96)];
      await app.refreshSportRecords();
      expect(app.sportRecords.single.durationSeconds, 120);
    },
  );

  test(
    'database preserves owner, route, private and unrecognised fields under simultaneous revisions',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('sayring-workout-');
      addTearDown(() => dir.delete(recursive: true));
      late Database db;
      final store = EncryptedHealthStore(
        MemorySessionVault(),
        databasePathProvider: () async => '${dir.path}/health.db',
        databaseOpener:
            (
              file, {
              required password,
              required version,
              onConfigure,
              onCreate,
              onUpgrade,
            }) async {
              db = await databaseFactoryFfi.openDatabase(
                file,
                options: OpenDatabaseOptions(
                  version: version,
                  onConfigure: onConfigure,
                  onCreate: onCreate,
                  onUpgrade: onUpgrade,
                ),
              );
              return db;
            },
      );
      await store.initialize();
      addTearDown(store.close);
      await store.switchOwner('owner-a');
      const target = 'AA:BB:CC:DD:EE:FF';
      await store.saveSportRecord(workout(120, 90));
      final raw = workout(120, 90).toMap()
        ..addAll({
          'legacyCounter': {'version': 5},
          'heartRate': 143,
          'maximumHeartRate': 165,
          'routePoints': [
            {
              'latitude': 1.0,
              'longitude': 2.0,
              'recordedAt': start.toIso8601String(),
            },
          ],
          'heartRateSamples': [
            {'elapsedSeconds': 21, 'bpm': 143},
          ],
        });
      await db.update(
        'sport_records',
        {'payload': jsonEncode(raw)},
        where: 'owner_id = ? AND id = ?',
        whereArgs: ['owner-a', workoutId],
      );
      final app = _controller(
        store,
        _Ring()..read = (() async => [workout(125, 93)]),
        wellnessOnly: true,
      );
      await app.refreshSportRecords();
      expect(app.sportRecords.single.heartRate, 0);
      expect(app.sportRecords.single.durationSeconds, 125);
      await Future.wait([
        store.importCoolWearAndroidSport(
          target.toLowerCase(),
          workout(140, 99, id: lowerCaseId),
        ),
        store.importCoolWearAndroidSport(target, workout(130, 96)),
      ]);
      final payload = jsonDecode(
        (await db.query(
              'sport_records',
              where: 'owner_id = ?',
              whereArgs: ['owner-a'],
            )).single['payload']
            as String,
      );
      expect(payload, {
        ...raw,
        'durationSeconds': 140,
        'steps': 99,
        'distanceKm': 0.099,
      });
      await store.switchOwner('owner-b');
      expect(await store.localSportRecords(), isEmpty);
      await store.importCoolWearAndroidSport(target, workout(65, 38));
      await store.switchOwner('owner-a');
      expect((await store.localSportRecords()).single.durationSeconds, 140);
    },
  );
}
