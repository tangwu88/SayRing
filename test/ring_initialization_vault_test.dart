import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/secure_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'initialization uncertainty persists by environment owner and target',
    () async {
      final vault = SecureSessionVault.global(
        storageNamespace: List.filled(64, 'a').join(),
      );
      await vault.writeRingInitializationStage(
        'owner-a',
        'qring:target-a',
        RingInitializationStage.decisionUnknown,
      );
      final restarted = SecureSessionVault.global(
        storageNamespace: List.filled(64, 'a').join(),
      );
      expect(
        await restarted.readRingInitializationStage(
          'owner-a',
          'qring:target-a',
        ),
        RingInitializationStage.decisionUnknown,
      );
      expect(
        await restarted.readRingInitializationStage(
          'owner-b',
          'qring:target-a',
        ),
        isNull,
      );
      expect(
        await restarted.readRingInitializationStage(
          'owner-a',
          'qring:target-b',
        ),
        isNull,
      );
      expect(
        await SecureSessionVault.global(
          storageNamespace: List.filled(64, 'b').join(),
        ).readRingInitializationStage('owner-a', 'qring:target-a'),
        isNull,
      );
      await restarted.clearRingInitializationStage('owner-b', 'qring:target-a');
      expect(
        await restarted.readRingInitializationStage(
          'owner-a',
          'qring:target-a',
        ),
        RingInitializationStage.decisionUnknown,
      );
      final values = await const FlutterSecureStorage().readAll();
      expect(values.keys.single, isNot(contains('owner-a')));
      expect(values.keys.single, isNot(contains('target-a')));
      await restarted.clearSession();
      expect(
        await restarted.readRingInitializationStage(
          'owner-a',
          'qring:target-a',
        ),
        RingInitializationStage.decisionUnknown,
      );
      await restarted.clearRingInitializationStage('owner-a', 'qring:target-a');
      expect(
        await restarted.readRingInitializationStage(
          'owner-a',
          'qring:target-a',
        ),
        isNull,
      );
    },
  );

  test(
    'malformed durable guard fails closed instead of appearing absent',
    () async {
      final vault = SecureSessionVault.global(
        storageNamespace: List.filled(64, 'a').join(),
      );
      await vault.writeRingInitializationStage(
        'owner-a',
        'qring:target-a',
        RingInitializationStage.resetAttempted,
      );
      final storage = const FlutterSecureStorage();
      final key = (await storage.readAll()).keys.single;
      await storage.write(key: key, value: 'broken');
      await expectLater(
        vault.readRingInitializationStage('owner-a', 'qring:target-a'),
        throwsFormatException,
      );
      expect(await storage.read(key: key), 'broken');
    },
  );
}
