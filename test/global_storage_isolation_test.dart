import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jpush_flutter/jpush_interface.dart';
import 'package:path/path.dart' as path;
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_notification_service.dart';
import 'package:saydian_app/services/global_environment.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_routing.dart';
import 'package:saydian_app/services/yucheng_wearable_bridge.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _environmentA = 'a' * 64;
final _environmentB = 'b' * 64;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'global production defaults share the configured environment digest',
    () {
      final vault = SecureSessionVault.global();
      final store = EncryptedHealthStore(vault, globalEdition: true);
      expect(vault.storageNamespace, GlobalEnvironment.storageNamespace);
      expect(store.storageNamespace, vault.storageNamespace);
      expect(
        store.databaseFileName,
        contains(GlobalEnvironment.storageNamespace),
      );
    },
  );

  test('invalid namespaces and mismatched vault/database are rejected', () {
    for (final invalid in [
      '',
      '../other',
      'https://app.saydian.cn',
      'A' * 64,
    ]) {
      expect(
        () => SecureSessionVault.global(storageNamespace: invalid),
        throwsArgumentError,
      );
    }
    expect(
      () => EncryptedHealthStore(
        SecureSessionVault.global(storageNamespace: _environmentA),
        globalEdition: true,
        storageNamespace: _environmentB,
      ),
      throwsArgumentError,
    );
  });

  test(
    'new global session ignores and preserves all previous storage keys',
    () async {
      final legacySession = _session('legacy');
      final legacy = {
        'saydian.global.session.v1': jsonEncode(legacySession.toJson()),
        'saydian.global.database.key.v1':
            'retained-legacy-encryption-key-123456',
        'saydian.global.privacy-consent.v1': 'granted',
        'saydian.global.shop-cart.v1': '[{"id":"legacy-item"}]',
        'saydian.global.health.legacy-migration-handled.v1': 'handled',
      };
      FlutterSecureStorage.setMockInitialValues(legacy);
      final vault = SecureSessionVault.global(storageNamespace: _environmentA);
      expect(await vault.readSession(), isNull);
      expect(await vault.readPrivacyConsentGranted(), isFalse);
      expect(await vault.readShopCart(), isEmpty);
      expect(await vault.readLegacyHealthMigrationHandled(), isFalse);
      expect(
        await vault.databaseKey(),
        isNot(legacy['saydian.global.database.key.v1']),
      );
      await vault.clearSession();
      final stored = await const FlutterSecureStorage().readAll();
      for (final entry in legacy.entries) {
        expect(stored[entry.key], entry.value);
      }
    },
  );

  test(
    'A-B-A preserves separate sessions, secrets, consent, carts and push cleanup',
    () async {
      final a = SecureSessionVault.global(storageNamespace: _environmentA);
      final b = SecureSessionVault.global(storageNamespace: _environmentB);
      await a.writeSession(_session('account-a'));
      await a.writePrivacyConsentGranted(true);
      await a.writeHealthWarningSettings(
        const HealthWarningSettings(heartRateEnabled: true),
      );
      await a.writeShopCart([
        {'id': 'cart-a'},
      ]);
      await a.writePendingPushUnregisterInstallationId('installation-a');
      await a.writeLegacyHealthMigrationHandled();
      final keyA = await a.databaseKey();

      expect(await b.readSession(), isNull);
      expect(await b.readPrivacyConsentGranted(), isFalse);
      expect((await b.readHealthWarningSettings()).heartRateEnabled, isFalse);
      expect(await b.readShopCart(), isEmpty);
      expect(await b.readPendingPushUnregisterInstallationId(), isNull);
      expect(await b.readLegacyHealthMigrationHandled(), isFalse);
      expect(await b.databaseKey(), isNot(keyA));
      expect(
        await b.writeSessionIfUnchanged(
          _session('account-a'),
          _session('bad-refresh'),
        ),
        isFalse,
      );
      await b.writeSession(_session('account-b'));
      await b.clearSession();

      final reopened = SecureSessionVault.global(
        storageNamespace: _environmentA,
      );
      expect((await reopened.readSession())?.memberId, 'account-a');
      expect(await reopened.databaseKey(), keyA);
      expect(await reopened.readPrivacyConsentGranted(), isTrue);
      expect(
        (await reopened.readHealthWarningSettings()).heartRateEnabled,
        isTrue,
      );
      expect((await reopened.readShopCart()).single['id'], 'cart-a');
      expect(
        await reopened.readPendingPushUnregisterInstallationId(),
        'installation-a',
      );
      expect(await reopened.readLegacyHealthMigrationHandled(), isTrue);
    },
  );

  test(
    'health, sports, warnings, cursors and inbox stay within environment and owner',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'saydian-env-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final legacyFile = File(
        path.join(directory.path, 'saydian_global_health_v1.db'),
      );
      const legacyBytes = [8, 3, 19, 4];
      await legacyFile.writeAsBytes(legacyBytes);
      final a = _store(directory, _environmentA);
      final b = _store(directory, _environmentB);
      addTearDown(a.close);
      addTearDown(b.close);
      await a.initialize();
      await b.initialize();
      await a.switchOwner('same-uuid');
      await b.switchOwner('same-uuid');
      await a.upsert([_record('record-a')]);
      await a.writeCursor('cursor-a');
      await a.saveSportRecord(
        SportRecord(
          id: 'sport-a',
          mode: SportMode.walking,
          startedAt: _measuredAt,
          durationSeconds: 20,
          distanceKm: 0.02,
          calories: 1,
        ),
      );
      await a.saveHealthWarningAlert(
        HealthWarningAlert(
          id: 'warning-a',
          metric: HealthMetric.heartRate,
          title: 'Test fixture',
          message: 'Test fixture',
          triggeredAt: _measuredAt,
        ),
      );
      await a.replaceAll([
        {
          'event_id': 'event-a',
          'created_at': _measuredAt.millisecondsSinceEpoch ~/ 1000,
        },
      ], ownerId: 'same-uuid');

      expect(await b.recent(), isEmpty);
      expect(await b.pending(), isEmpty);
      expect(await b.readCursor(), isNull);
      expect(await b.localSportRecords(), isEmpty);
      expect(await b.healthWarningAlerts(), isEmpty);
      expect(await b.readAll(ownerId: 'same-uuid'), isEmpty);
      await b.upsert([_record('record-b')]);
      await b.markSynced(['record-a']);
      expect((await a.pending()).single.id, 'record-a');

      await a.switchOwner('other-account');
      expect(await a.recent(), isEmpty);
      expect(await a.readCursor(), isNull);
      await a.close();
      final restarted = _store(directory, _environmentA);
      addTearDown(restarted.close);
      await restarted.initialize();
      await restarted.switchOwner('same-uuid');
      expect((await restarted.recent()).single.id, 'record-a');
      expect((await restarted.pending()).single.id, 'record-a');
      expect(await restarted.readCursor(), 'cursor-a');
      expect((await restarted.localSportRecords()).single.id, 'sport-a');
      expect((await restarted.healthWarningAlerts()).single.id, 'warning-a');
      expect(
        (await restarted.readAll(ownerId: 'same-uuid')).single['event_id'],
        'event-a',
      );
      expect(await legacyFile.readAsBytes(), legacyBytes);
      expect(
        await File('${legacyFile.path}.recovery-pending').exists(),
        isFalse,
      );
    },
  );

  test('international store never adopts legacy-unscoped records', () async {
    final directory = await Directory.systemTemp.createTemp(
      'saydian-env-legacy-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = _store(directory, _environmentA);
    addTearDown(store.close);
    await store.initialize();
    await store.switchOwner('legacy-unscoped');
    await store.upsert([_record('unowned-record')]);
    await store.adoptLegacyData(
      healthOwnerId: 'signed-in-account',
      notificationOwnerId: 'signed-in-account',
    );
    await store.switchOwner('signed-in-account');
    expect(await store.recent(), isEmpty);
    expect(await store.pending(), isEmpty);
    await store.switchOwner('legacy-unscoped');
    expect((await store.pending()).single.id, 'unowned-record');
  });

  test(
    'push installation and explanation are environment scoped; old keys remain',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'saydian.push.installation-id.v1': 'old-installation',
        'saydian.push.permission-explained.v1': 'shown',
      });
      final a = JPushAppNotificationService(
        jpush: _NoopPush(),
        appKey: '',
        storageNamespace: _environmentA,
      );
      final b = JPushAppNotificationService(
        jpush: _NoopPush(),
        appKey: '',
        storageNamespace: _environmentB,
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final installationA = await a.installationId();
      expect(installationA, isNot('old-installation'));
      expect(await b.installationId(), isNot(installationA));
      expect(await a.shouldExplainPermission(), isTrue);
      await a.markPermissionExplanationShown();
      expect(await a.shouldExplainPermission(), isFalse);
      expect(await b.shouldExplainPermission(), isTrue);
      expect(
        await const FlutterSecureStorage().read(
          key: 'saydian.push.installation-id.v1',
        ),
        'old-installation',
      );
    },
  );

  test(
    'saved transport and exact watch identity are separate across A-B-A',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'wearable.last.transport': 'veepoo',
      });
      final a = SecureWearableTransportPreferenceStore(
        storageNamespace: _environmentA,
      );
      final b = SecureWearableTransportPreferenceStore(
        storageNamespace: _environmentB,
      );
      expect(await a.read(), isNull);
      expect(await a.readBinding(), isNull);
      await a.writeBinding(
        const SavedWearableBinding(
          WearableTransport.veepoo,
          'watch-a',
          deviceName: 'V Ring',
        ),
      );
      expect(await b.readBinding(), isNull);
      await b.writeBinding(
        const SavedWearableBinding(WearableTransport.veepoo, 'watch-b'),
      );
      final reopened = SecureWearableTransportPreferenceStore(
        storageNamespace: _environmentA,
      );
      expect((await reopened.readBinding())?.nativeIdentifier, 'watch-a');
      expect((await reopened.readBinding())?.deviceName, 'V Ring');
      await b.clear();
      expect((await reopened.readBinding())?.nativeIdentifier, 'watch-a');
      expect(
        await const FlutterSecureStorage().read(key: 'wearable.last.transport'),
        'veepoo',
      );
    },
  );

  test(
    'Yucheng saved target is environment scoped and never inherits old target',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'wearable.yuc.last.identifier': 'old-watch',
        'wearable.yuc.last.name': 'W8',
      });
      final a = SecureYuchengSavedDeviceStore(storageNamespace: _environmentA);
      final b = SecureYuchengSavedDeviceStore(storageNamespace: _environmentB);
      expect(await a.read(), isNull);
      await a.write(
        const YuchengSavedDevice(identifier: 'watch-a', name: 'W8'),
      );
      expect(await b.read(), isNull);
      await b.write(
        const YuchengSavedDevice(identifier: 'watch-b', name: 'W8'),
      );
      await b.clear();
      expect((await a.read())?.identifier, 'watch-a');
      expect(
        await const FlutterSecureStorage().read(
          key: 'wearable.yuc.last.identifier',
        ),
        'old-watch',
      );
    },
  );
}

Session _session(String account) => Session(
  accessToken: 'test-token-$account',
  refreshToken: 'test-refresh-$account',
  expiresAt: DateTime.utc(2030),
  memberId: account,
  displayName: 'Synthetic test account',
  accountKey: account,
);

final _measuredAt = DateTime.utc(2026, 9, 9, 3, 4, 5);
HealthRecord _record(String id) => HealthRecord(
  id: id,
  metric: HealthMetric.heartRate,
  values: const {'value': 72},
  unit: 'bpm',
  measuredAt: _measuredAt,
  timezone: '+00:00',
  deviceId: 'synthetic-watch',
  firmwareVersion: 'test',
  quality: 'good',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);

EncryptedHealthStore _store(Directory directory, String namespace) {
  late EncryptedHealthStore store;
  store = EncryptedHealthStore(
    SecureSessionVault.global(storageNamespace: namespace),
    globalEdition: true,
    storageNamespace: namespace,
    databasePathProvider: () async =>
        path.join(directory.path, store.databaseFileName),
    databaseOpener:
        (
          file, {
          required password,
          required version,
          onConfigure,
          onCreate,
          onUpgrade,
        }) => databaseFactoryFfi.openDatabase(
          file,
          options: OpenDatabaseOptions(
            version: version,
            onConfigure: onConfigure,
            onCreate: onCreate,
            onUpgrade: onUpgrade,
          ),
        ),
  );
  return store;
}

class _NoopPush extends Fake implements JPushFlutterInterface {}
