import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:saydian_app/domain/health_reminder.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// The injected FFI opener verifies the production SQL queue/schema contract.
// It does not claim to validate SQLCipher encryption on a physical device.
EncryptedHealthStore _store(String file) => EncryptedHealthStore(
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

HealthWarningAlert _event({bool legacy = false}) => HealthWarningAlert(
  id: legacy ? 'legacy' : 'same-id-across-owners',
  metric: HealthMetric.heartRate,
  title: 'Synthetic test fixture',
  message: 'Synthetic test fixture',
  triggeredAt: DateTime.utc(2026, 10, 27, 1),
  reminder: legacy
      ? null
      : HealthReminderDetails(
          kind: HealthReminderKind.symptoms,
          recordedAt: DateTime.utc(2026, 10, 27, 1),
          symptoms: {HealthReminderSymptom.breathlessness},
          acknowledgedAt: DateTime.utc(2026, 10, 27, 1, 2),
        ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'SQL round-trip, restart and delete keep owner and legacy data intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sayring-reminder-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = path.join(directory.path, 'health.db');
      var store = _store(file);
      addTearDown(() => store.close());
      await store.initialize();
      await store.switchOwner('account-a');
      await store.saveHealthWarningAlert(_event());
      await store.saveHealthWarningAlert(_event(legacy: true));
      await store.switchOwner('account-b');
      expect(await store.healthWarningAlerts(), isEmpty);
      await store.saveHealthWarningAlert(_event());
      await store.close();

      store = _store(file);
      await store.initialize();
      await store.switchOwner('account-a');
      final restored = await store.healthWarningAlerts();
      expect(restored, hasLength(2));
      final details = restored
          .firstWhere((event) => event.reminder != null)
          .reminder!;
      expect(details.symptoms, {HealthReminderSymptom.breathlessness});
      expect(details.acknowledgedAt, DateTime.utc(2026, 10, 27, 1, 2));
      expect(details.dialRequestedAt, isNull);
      await store.deleteHealthReminder(_event().id);
      expect((await store.healthWarningAlerts()).single.id, 'legacy');
      await store.switchOwner('account-b');
      expect((await store.healthWarningAlerts()).single.id, _event().id);
      expect(await store.pending(), isEmpty);
    },
  );

  test(
    'queued delete captures its original owner before an account switch',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sayring-reminder-queue-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = _store(path.join(directory.path, 'health.db'));
      addTearDown(store.close);
      await store.initialize();
      await store.switchOwner('account-a');
      await store.saveHealthWarningAlert(_event());
      await store.switchOwner('account-b');
      await store.saveHealthWarningAlert(_event());
      await store.switchOwner('account-a');
      final deletion = store.deleteHealthReminder(_event().id);
      final switching = store.switchOwner('account-b');
      await Future.wait([deletion, switching]);
      expect((await store.healthWarningAlerts()).single.id, _event().id);
      await store.switchOwner('account-a');
      expect(await store.healthWarningAlerts(), isEmpty);
    },
  );
}
