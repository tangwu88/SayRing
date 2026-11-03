import 'dart:convert';

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

  group('durable initialization operation v2', () {
    const operation = '11111111-2222-4333-8444-555555555555';
    const replacement = '99999999-2222-4333-8444-555555555555';
    const owner = 'owner-a';
    const target = 'qring:target-a';
    SecureSessionVault vault() => SecureSessionVault.global(
      storageNamespace: List.filled(64, 'a').join(),
    );

    test(
      'one durable value retains the operation across restart and stages',
      () async {
        final first = vault();
        await first.writeRingInitializationStage(
          owner,
          target,
          RingInitializationStage.decisionRequired,
        );
        await first.writeRingInitializationRequest(owner, target, operation);
        final raw = await const FlutterSecureStorage().readAll();
        expect(raw, hasLength(1));
        expect(jsonDecode(raw.values.single), {
          'version': 2,
          'stage': 'decisionRequired',
          'operationId': operation,
        });
        for (final stage in RingInitializationStage.values) {
          final restarted = vault();
          await restarted.writeRingInitializationStage(owner, target, stage);
          expect(
            await vault().readRingInitializationStage(owner, target),
            stage,
          );
          expect(
            await vault().readRingInitializationOperationId(owner, target),
            operation,
          );
          expect(await const FlutterSecureStorage().readAll(), hasLength(1));
        }
        await first.clearSession();
        expect(
          await vault().readRingInitializationOperationId(owner, target),
          operation,
        );
        await first.clearRingInitializationStage(owner, target);
        expect(
          await vault().readRingInitializationStage(owner, target),
          isNull,
        );
        expect(
          await vault().readRingInitializationOperationId(owner, target),
          isNull,
        );
      },
    );

    test('operation is isolated by owner target and environment', () async {
      final first = vault();
      await first.writeRingInitializationStage(
        owner,
        target,
        RingInitializationStage.decisionRequired,
      );
      await first.writeRingInitializationRequest(owner, target, operation);
      expect(
        await first.readRingInitializationOperationId('owner-b', target),
        isNull,
      );
      expect(
        await first.readRingInitializationOperationId(owner, 'qring:target-b'),
        isNull,
      );
      expect(
        await SecureSessionVault.global(
          storageNamespace: List.filled(64, 'b').join(),
        ).readRingInitializationOperationId(owner, target),
        isNull,
      );
      await first.clearRingInitializationStage('owner-b', target);
      expect(
        await first.readRingInitializationOperationId(owner, target),
        operation,
      );
    });

    for (final stage in RingInitializationStage.values.where(
      (value) => value != RingInitializationStage.decisionRequired,
    )) {
      test(
        'legacy $stage cannot acquire a fabricated retry operation',
        () async {
          final first = vault();
          await first.writeRingInitializationStage(owner, target, stage);
          await expectLater(
            first.writeRingInitializationRequest(owner, target, operation),
            throwsStateError,
          );
          expect(await first.readRingInitializationStage(owner, target), stage);
          expect(
            await first.readRingInitializationOperationId(owner, target),
            isNull,
          );
        },
      );
    }

    test('missing guard cannot silently create a request', () async {
      final first = vault();
      await expectLater(
        first.writeRingInitializationRequest(owner, target, operation),
        throwsStateError,
      );
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    });

    test(
      'same request is idempotent but its operation cannot be replaced',
      () async {
        final first = vault();
        await first.writeRingInitializationStage(
          owner,
          target,
          RingInitializationStage.decisionRequired,
        );
        await first.writeRingInitializationRequest(owner, target, operation);
        await first.writeRingInitializationRequest(owner, target, operation);
        await expectLater(
          first.writeRingInitializationRequest(owner, target, replacement),
          throwsStateError,
        );
        expect(
          await first.readRingInitializationOperationId(owner, target),
          operation,
        );
        await first.writeRingInitializationStage(
          owner,
          target,
          RingInitializationStage.decisionUnknown,
        );
        await expectLater(
          first.writeRingInitializationRequest(owner, target, operation),
          throwsStateError,
        );
        expect(
          await first.readRingInitializationStage(owner, target),
          RingInitializationStage.decisionUnknown,
        );
      },
    );

    for (final invalid in [
      '',
      'not-a-uuid',
      '11111111-2222-3333-8444-555555555555',
      'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee '.trimRight().toUpperCase(),
    ]) {
      test(
        'invalid operation is rejected without changing the guard: $invalid',
        () async {
          final first = vault();
          await first.writeRingInitializationStage(
            owner,
            target,
            RingInitializationStage.decisionRequired,
          );
          await expectLater(
            first.writeRingInitializationRequest(owner, target, invalid),
            throwsFormatException,
          );
          expect(
            await first.readRingInitializationOperationId(owner, target),
            isNull,
          );
          expect(
            await first.readRingInitializationStage(owner, target),
            RingInitializationStage.decisionRequired,
          );
        },
      );
    }

    final malformed = <Object?>[
      null,
      [],
      {'version': 3, 'stage': 'decisionUnknown', 'operationId': operation},
      {'version': 2, 'stage': 'unknown-stage', 'operationId': operation},
      {'version': 2, 'stage': 'decisionUnknown'},
      {'version': 2, 'stage': 'decisionUnknown', 'operationId': 123},
      {'version': 2, 'stage': 'decisionUnknown', 'operationId': 'invalid'},
    ];
    for (var index = 0; index < malformed.length; index++) {
      test(
        'malformed v2 value $index cannot appear absent or be overwritten',
        () async {
          final first = vault();
          await first.writeRingInitializationStage(
            owner,
            target,
            RingInitializationStage.decisionRequired,
          );
          final storage = const FlutterSecureStorage();
          final key = (await storage.readAll()).keys.single;
          final raw = jsonEncode(malformed[index]);
          await storage.write(key: key, value: raw);
          await expectLater(
            first.readRingInitializationStage(owner, target),
            throwsFormatException,
          );
          await expectLater(
            first.readRingInitializationOperationId(owner, target),
            throwsFormatException,
          );
          await expectLater(
            first.writeRingInitializationStage(
              owner,
              target,
              RingInitializationStage.decisionRequired,
            ),
            throwsFormatException,
          );
          await expectLater(
            first.writeRingInitializationRequest(owner, target, operation),
            throwsFormatException,
          );
          expect(await storage.read(key: key), raw);
        },
      );
    }

    test('memory vault preserves the same retry and scope contract', () async {
      final first = MemorySessionVault();
      await expectLater(
        first.writeRingInitializationRequest(owner, target, operation),
        throwsStateError,
      );
      await first.writeRingInitializationStage(
        owner,
        target,
        RingInitializationStage.decisionRequired,
      );
      await first.writeRingInitializationRequest(owner, target, operation);
      await expectLater(
        first.writeRingInitializationRequest(owner, target, replacement),
        throwsStateError,
      );
      await first.writeRingInitializationStage(
        owner,
        target,
        RingInitializationStage.decisionUnknown,
      );
      expect(
        await first.readRingInitializationOperationId(owner, target),
        operation,
      );
      expect(
        await first.readRingInitializationOperationId('owner-b', target),
        isNull,
      );
      await expectLater(
        first.writeRingInitializationRequest(owner, target, operation),
        throwsStateError,
      );
      await first.clearRingInitializationStage(owner, target);
      expect(
        await first.readRingInitializationOperationId(owner, target),
        isNull,
      );
      expect(await first.readRingInitializationStage(owner, target), isNull);
    });
  });
}
