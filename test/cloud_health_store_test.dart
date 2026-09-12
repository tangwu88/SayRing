import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

HealthRecord _record(String id, num value) => HealthRecord(
  id: id,
  metric: HealthMetric.heartRate,
  values: {'value': value},
  unit: 'bpm',
  measuredAt: DateTime.utc(2026, 9, 13, 1),
  timezone: '+00:00',
  deviceId: 'server:${List.filled(64, 'a').join()}',
  firmwareVersion: '1.0',
  quality: 'valid',
  source: MeasurementSource.wearable,
  rawVersion: 1,
  sourceVendor: 'yucheng',
  sourceDeviceCategory: 'ring',
  sourceApp: 'say-ring',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'encrypted store keeps cloud imports synced and local conflicts pending',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'say-ring-cloud-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = path.join(directory.path, 'health.db');
      final factory = databaseFactoryFfi;
      final store = EncryptedHealthStore(
        MemorySessionVault(),
        globalEdition: true,
        storageNamespace:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        databasePathProvider: () async => file,
        databaseOpener:
            (
              databasePath, {
              required password,
              required version,
              onConfigure,
              onCreate,
              onUpgrade,
            }) => factory.openDatabase(
              databasePath,
              options: OpenDatabaseOptions(
                version: version,
                onConfigure: onConfigure,
                onCreate: onCreate,
                onUpgrade: onUpgrade,
              ),
            ),
      );
      addTearDown(store.close);
      await store.initialize();
      await store.switchOwner('global:member:test');
      final local = _record('same-id', 78);
      await store.upsert([local]);
      await store.upsertSynced([
        local.copyWith(values: {'value': 79}),
        _record('cloud-only', 75),
      ]);

      expect((await store.pending()).map((record) => record.id), ['same-id']);
      expect(
        (await store.recent())
            .firstWhere((record) => record.id == 'same-id')
            .values['value'],
        78,
      );
      await store.upsertSynced([local]);
      expect(await store.pending(), isEmpty);
    },
  );
}
