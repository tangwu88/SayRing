import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/services/wearable_routing.dart';

final _env = 'a' * 64;
String get _bindingKey => 'saydian.global.env.$_env.wearable.binding.v1';
String _historyKey(String owner) =>
    'saydian.global.env.$_env.wearable.selection-history.v1.'
    '${sha256.convert(utf8.encode(owner))}';
const _profile = WearableUserProfile(
  gender: 1,
  heightCm: 175,
  weightKg: 70,
  birthYear: 1996,
  age: 30,
  targetSteps: 10000,
);
SavedWearableBinding _binding(
  String id, {
  String owner = 'owner-a',
  String name = 'R21',
}) => SavedWearableBinding(
  WearableTransport.qring,
  id,
  deviceName: name,
  ownerKey: owner,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final model in ['SD_RING_R8', 'R21_C280', 'R22_C493']) {
    test(
      '$model unbind retains a manual exact candidate but never auto-arms it',
      () async {
        final store = SecureWearableTransportPreferenceStore(
          storageNamespace: _env,
        );
        await store.writeBinding(_binding('fixture-id', name: model));
        final native = _Ring();
        final bridge = RoutedWearableBridge(
          qring: native,
          preferenceStore: store,
          restoreOnlyBoundDevice: true,
          requireOwnerScopedBinding: true,
        );
        addTearDown(bridge.dispose);
        await bridge.setRecoveryContext(ownerKey: 'owner-a', profile: _profile);
        await bridge.forgetRememberedDevice();
        expect(await bridge.readRememberedDevice(), isNull);
        expect(await bridge.canAutomaticallyRecoverRememberedDevice(), isFalse);
        native.targets.clear();
        expect(await bridge.restoreConnection(profile: _profile), isNull);
        expect(native.targets.whereType<String>(), isEmpty);
        expect(native.connects, isEmpty);
        final choices = await bridge.listBondedDevicesForSelection();
        expect(choices.single.id, 'qring:fixture-id');
        expect(choices.single.name, model);
        expect(await store.readBinding(), isNull);
        expect(native.connects, isEmpty);
        await bridge.connect(choices.single.id, profile: _profile);
        expect(native.connects, ['fixture-id']);
        expect((await store.readBinding())?.deviceName, model);
        expect(await bridge.canAutomaticallyRecoverRememberedDevice(), isTrue);
        await bridge.setRecoveryContext(ownerKey: 'owner-b', profile: _profile);
        expect(await bridge.listBondedDevicesForSelection(), isEmpty);
      },
    );
  }

  test(
    'legacy v2 migrates before unbind, survives reopen and stays isolated',
    () async {
      await const FlutterSecureStorage().write(
        key: _bindingKey,
        value: jsonEncode({
          'schemaVersion': 2,
          'environment': _env,
          'ownerKey': 'owner-a',
          'transport': 'qring',
          'nativeIdentifier': 'recent-r21',
          'deviceName': 'R21',
          'recentBindings': [
            {
              'transport': 'qring',
              'nativeIdentifier': 'older-r8',
              'deviceName': 'SD_RING_R8',
            },
            {
              'transport': 'qring',
              'nativeIdentifier': 'older-r8',
              'deviceName': 'SD_RING_R8',
            },
          ],
        }),
      );
      final store = SecureWearableTransportPreferenceStore(
        storageNamespace: _env,
      );
      await store.clear();
      final reopened = SecureWearableTransportPreferenceStore(
        storageNamespace: _env,
      );
      expect(await reopened.readBinding(), isNull);
      expect(
        (await reopened.readRecentBindings(
          'owner-a',
        )).map((x) => x.nativeIdentifier),
        ['recent-r21', 'older-r8'],
      );
      expect(await reopened.readRecentBindings('owner-b'), isEmpty);
      expect(
        await SecureWearableTransportPreferenceStore(
          storageNamespace: 'b' * 64,
        ).readRecentBindings('owner-a'),
        isEmpty,
      );
      expect(await const FlutterSecureStorage().read(key: _bindingKey), isNull);
    },
  );

  test('unowned legacy v1 never becomes an account candidate', () async {
    await const FlutterSecureStorage().write(
      key: _bindingKey,
      value: jsonEncode({
        'transport': 'qring',
        'nativeIdentifier': 'unowned',
        'deviceName': 'R8',
      }),
    );
    final store = SecureWearableTransportPreferenceStore(
      storageNamespace: _env,
    );
    await store.clear();
    expect(await store.readRecentBindings('owner-a'), isEmpty);
  });

  test(
    'same-owner history is deduplicated, newest first and bounded to four',
    () async {
      final store = SecureWearableTransportPreferenceStore(
        storageNamespace: _env,
      );
      for (final id in ['one', 'two', 'three', 'four', 'five', 'three']) {
        await store.writeBinding(_binding(id));
      }
      await store.clear();
      expect(
        (await store.readRecentBindings(
          'owner-a',
        )).map((x) => x.nativeIdentifier),
        ['three', 'five', 'four', 'two'],
      );
      await store.writeBinding(_binding('owner-b-ring', owner: 'owner-b'));
      expect((await store.readRecentBindings('owner-a')).length, 4);
      expect(await store.readRecentBindings('owner-b'), isEmpty);
    },
  );

  test(
    'binding write failure restores the previous binding and history bytes',
    () async {
      final storage = _FaultStorage();
      final old = FlutterSecureStoragePlatform.instance;
      FlutterSecureStoragePlatform.instance = storage;
      addTearDown(() => FlutterSecureStoragePlatform.instance = old);
      final store = SecureWearableTransportPreferenceStore(
        storageNamespace: _env,
      );
      await store.writeBinding(_binding('old'));
      final before = Map<String, String>.from(storage.values);
      storage.failKey = _bindingKey;
      await expectLater(store.writeBinding(_binding('new')), throwsStateError);
      expect(storage.values, before);
      expect((await store.readBinding())?.nativeIdentifier, 'old');
    },
  );

  test(
    'late owner revocation rolls back both keys and cannot create history',
    () async {
      final storage = _FaultStorage();
      final old = FlutterSecureStoragePlatform.instance;
      FlutterSecureStoragePlatform.instance = storage;
      addTearDown(() => FlutterSecureStoragePlatform.instance = old);
      final store = SecureWearableTransportPreferenceStore(
        storageNamespace: _env,
      );
      await store.writeBinding(_binding('old'));
      final before = Map<String, String>.from(storage.values);
      storage.holdKey = _historyKey('owner-b');
      storage.release = Completer<void>();
      var current = true;
      final write = store.writeBindingIfCurrent(
        _binding('late', owner: 'owner-b'),
        isCurrent: () => current,
      );
      await storage.held.future;
      current = false;
      storage.release!.complete();
      expect(await write, isFalse);
      expect(storage.values, before);
      expect(await store.readRecentBindings('owner-b'), isEmpty);
    },
  );

  test(
    'malformed history is not overwritten or silently removed on unbind',
    () async {
      final store = SecureWearableTransportPreferenceStore(
        storageNamespace: _env,
      );
      await store.writeBinding(_binding('old'));
      await const FlutterSecureStorage().write(
        key: _historyKey('owner-a'),
        value: '{broken',
      );
      await expectLater(store.clear(), throwsStateError);
      expect((await store.readBinding())?.nativeIdentifier, 'old');
      expect(
        await const FlutterSecureStorage().read(key: _historyKey('owner-a')),
        '{broken',
      );
    },
  );
}

class _Ring extends Fake
    implements
        WearableBridge,
        WearableRememberedDeviceSelectionBridge,
        WearableExactTargetRecoveryBridge {
  final connects = <String>[];
  final targets = <String?>[];
  @override
  Stream<WearableEvent> get events => const Stream.empty();
  @override
  Future<void> stopScan() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<DeviceInfo?> prepareRememberedDeviceForSelection(
    String nativeIdentifier, {
    String? knownName,
    bool cacheOnly = false,
  }) async {
    expect(cacheOnly, isTrue);
    return DeviceInfo(id: nativeIdentifier, name: knownName!);
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connects.add(deviceId);
  }

  @override
  Future<void> configureRecoveryTarget({
    required String? nativeIdentifier,
    String? knownName,
    String? contextKey,
    WearableUserProfile? profile,
  }) async {
    targets.add(nativeIdentifier);
  }
}

class _FaultStorage extends FlutterSecureStoragePlatform {
  final values = <String, String>{};
  String? failKey;
  String? holdKey;
  Completer<void>? release;
  final held = Completer<void>();
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (key == failKey) {
      failKey = null;
      throw StateError('synthetic storage failure');
    }
    if (key == holdKey) {
      holdKey = null;
      held.complete();
      await release!.future;
    }
    values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => values[key];
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    values.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => values.containsKey(key);
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.from(values);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    values.clear();
  }
}
