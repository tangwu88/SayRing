import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/local_health_store.dart';

void main() {
  test(
    'memory health store isolates records, queues, cursors, sports and alerts',
    () async {
      final store = MemoryHealthStore();
      await store.initialize();

      await store.switchOwner('legacy-unscoped');
      await store.upsert([_record(value: 66)]);
      await store.writeCursor('legacy-cursor');
      await store.adoptLegacyData(
        healthOwnerId: 'account-a',
        notificationOwnerId: 'notifications-a',
      );

      await store.switchOwner('account-a');
      expect((await store.recent()).single.values['value'], 66);
      expect(await store.readCursor(), 'legacy-cursor');
      await store.upsert([_record(id: 'account-a-id', value: 71)]);
      await store.writeCursor('cursor-a');
      await store.saveSportRecord(_sport(distance: 1.2));
      await store.saveHealthWarningAlert(_warning(message: 'A alert'));

      await store.switchOwner('account-b');
      expect(await store.recent(), isEmpty);
      expect(await store.pending(), isEmpty);
      expect(await store.readCursor(), isNull);
      expect(await store.localSportRecords(), isEmpty);
      expect(await store.healthWarningAlerts(), isEmpty);

      await store.upsert([_record(value: 88)]);
      await store.writeCursor('cursor-b');
      await store.saveSportRecord(_sport(distance: 3.4));
      await store.saveHealthWarningAlert(_warning(message: 'B alert'));
      await store.markSynced(const ['shared-id']);
      expect(await store.pending(), isEmpty);

      await store.switchOwner('account-a');
      final accountARecords = {
        for (final record in await store.recent()) record.id: record,
      };
      expect(accountARecords['shared-id']?.values['value'], 66);
      expect(accountARecords['account-a-id']?.values['value'], 71);
      expect(
        (await store.pending()).map((record) => record.id),
        containsAll(<String>['shared-id', 'account-a-id']),
      );
      expect(await store.readCursor(), 'cursor-a');
      expect((await store.localSportRecords()).single.distanceKm, 1.2);
      expect((await store.healthWarningAlerts()).single.message, 'A alert');

      await store.switchOwner('account-b');
      expect((await store.recent()).single.values['value'], 88);
      expect(await store.readCursor(), 'cursor-b');
      expect((await store.localSportRecords()).single.distanceKm, 3.4);
      expect((await store.healthWarningAlerts()).single.message, 'B alert');
    },
  );
}

HealthRecord _record({String id = 'shared-id', required num value}) =>
    HealthRecord(
      id: id,
      metric: HealthMetric.heartRate,
      values: {'value': value},
      unit: 'bpm',
      measuredAt: DateTime.utc(2026, 8, 29, 8),
      timezone: '+08:00',
      deviceId: 'watch',
      firmwareVersion: '1.0',
      quality: 'good',
      source: MeasurementSource.wearable,
      rawVersion: 1,
    );

SportRecord _sport({required double distance}) => SportRecord(
  id: 'shared-sport',
  mode: SportMode.running,
  startedAt: DateTime.utc(2026, 8, 29, 8),
  durationSeconds: 600,
  distanceKm: distance,
  calories: 100,
);

HealthWarningAlert _warning({required String message}) => HealthWarningAlert(
  id: 'shared-warning',
  metric: HealthMetric.heartRate,
  title: '心率提醒',
  message: message,
  triggeredAt: DateTime.utc(2026, 8, 29, 8),
);
