import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/cycle_tracking.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

HealthRecord sample(
  String id,
  DateTime at, {
  String device = 'ring:a',
  String firmware = '1',
  bool contact = true,
  String origin = 'watch_history',
}) => HealthRecord(
  id: id,
  metric: HealthMetric.bodyTemperature,
  values: const {'value': 32.5},
  unit: '℃',
  measuredAt: at,
  timezone: '+08:00',
  deviceId: device,
  firmwareVersion: firmware,
  quality: 'device_reported',
  source: MeasurementSource.wearable,
  origin: MeasurementOrigin.fromWire(
    origin,
    source: MeasurementSource.wearable,
  ),
  rawVersion: 1,
  sourceVendor: 'test_vendor',
  sourceModel: 'test_model',
  provenance: {
    'timeBasis': 'sdk',
    'temperatureKind': 'skin',
    'contactVerified': contact,
    'intervalSeconds': 300,
  },
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'night feature uses real windows, deduplicates samples and preserves original values',
    () {
      final at = DateTime.utc(2026, 10, 2, 0),
          records = [
            HealthRecord(
              id: 'sleep',
              metric: HealthMetric.sleep,
              values: const {'value': 4},
              unit: 'h',
              measuredAt: at,
              timezone: '+00:00',
              deviceId: 'ring:a',
              firmwareVersion: '1',
              quality: 'device_reported',
              source: MeasurementSource.wearable,
              rawVersion: 1,
              nightWindows: [
                {
                  'kind': 'night',
                  'startAt': at.toIso8601String(),
                  'endAt': at.add(const Duration(hours: 4)).toIso8601String(),
                  'date': '2026-10-02',
                },
              ],
            ),
            for (var i = 0; i < 48; i++)
              sample('t$i', at.add(Duration(minutes: 5 * i))),
          ];
      final result = cycleNightFeatures([
        ...records,
        records.last,
      ], asOf: at.add(const Duration(days: 1)));
      expect(result.length, 1);
      expect(result.single.value, 32.5);
      expect(result.single.samples, 48);
      expect(result.single.enhancementEligible, true);
      expect(records.last.values, {'value': 32.5});
      expect(
        cycleNightFeatures(
          records.where((r) => r.metric != HealthMetric.sleep).toList(),
        ),
        isEmpty,
      );
      expect(
        cycleNightFeatures([records.first, ...records.skip(1).take(10)]),
        isEmpty,
      );
      expect(
        cycleNightFeatures([
          records.first,
          ...records
              .skip(1)
              .map(
                (r) => r.copyWith(
                  provenance: {...r.provenance, 'temperatureKind': 'unknown'},
                ),
              ),
        ]),
        isEmpty,
      );
      expect(
        cycleNightFeatures([
          records.first,
          ...records
              .skip(1)
              .map((r) => r.copyWith(origin: MeasurementOrigin.appMeasurement)),
        ]),
        isEmpty,
      );
    },
  );
  test(
    'additive v6-to-v7 upgrade retains existing rows and isolates cycle owners',
    () async {
      final dir = await Directory.systemTemp.createTemp('cycle-sql-');
      addTearDown(() => dir.delete(recursive: true));
      final file = '${dir.path}/test.db';
      final old = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (db, v) async {
            await db.execute(
              'CREATE TABLE health_records(owner_id TEXT,id TEXT,metric TEXT,measured_at TEXT,payload TEXT,synced INTEGER,PRIMARY KEY(owner_id,id))',
            );
            await db.execute(
              'CREATE TABLE metadata(owner_id TEXT,key TEXT,value TEXT,PRIMARY KEY(owner_id,key))',
            );
            await db.insert('metadata', {
              'owner_id': 'a',
              'key': 'retention',
              'value': 'unchanged',
            });
          },
        ),
      );
      await old.close();
      final store = EncryptedHealthStore(
        MemorySessionVault(),
        databasePathProvider: () async => file,
        databaseOpener:
            (
              p, {
              required password,
              required version,
              onConfigure,
              onCreate,
              onUpgrade,
            }) => databaseFactoryFfi.openDatabase(
              p,
              options: OpenDatabaseOptions(
                version: version,
                onConfigure: onConfigure,
                onCreate: onCreate,
                onUpgrade: onUpgrade,
              ),
            ),
      );
      await store.initialize();
      await store.putCycleRow('a', 'x', {'id': 'x', 'value': 'private-a'});
      await store.putCycleRow('b', 'x', {'id': 'x', 'value': 'private-b'});
      expect((await store.cycleRows('a')).single['value'], 'private-a');
      await store.clearCycleRows('a');
      expect(await store.cycleRows('a'), isEmpty);
      expect((await store.cycleRows('b')).single['value'], 'private-b');
      await store.close();
      final db = await databaseFactoryFfi.openDatabase(file);
      expect((await db.query('metadata')).single['value'], 'unchanged');
      await db.close();
    },
  );
}
