import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/sync_read_evidence.dart';
import 'fixtures/sync_read_evidence.dart';

void main() {
  test(
    'counts preserve wire/decoded/mapped differences and unverified clock',
    () {
      expect(isBoundedSyncReadEvidence(firstReadEvidence()), isTrue);
    },
  );
  for (final key in [
    'value',
    'address',
    'token',
    'timestamp',
    'rawPacket',
    'deviceId',
  ]) {
    test('rejects sensitive root field $key', () {
      expect(
        isBoundedSyncReadEvidence({...firstReadEvidence(), key: 'private'}),
        isFalse,
      );
    });
  }
  test('rejects invalid counters and hidden payload fields inside rows', () {
    for (final n in [-1, 1.5, 1000001, '2', null]) {
      final evidence = firstReadEvidence();
      ((evidence['metrics'] as List).single as Map)['packets'] = n;
      expect(isBoundedSyncReadEvidence(evidence), isFalse);
    }
    final evidence = firstReadEvidence();
    ((evidence['metrics'] as List).single as Map)['value'] = 72;
    expect(isBoundedSyncReadEvidence(evidence), isFalse);
  });
  test(
    'rejects duplicate metrics, fabricated verification and monitoring values',
    () {
      final evidence = firstReadEvidence();
      (evidence['metrics'] as List).add((evidence['metrics'] as List).single);
      expect(isBoundedSyncReadEvidence(evidence), isFalse);
      final verified = firstReadEvidence();
      (verified['clock'] as Map)['verification'] = 'verified';
      expect(isBoundedSyncReadEvidence(verified), isFalse);
      expect(
        isBoundedSyncReadEvidence({
          ...firstReadEvidence(),
          'monitoring': {'heartRate': 72},
        }),
        isFalse,
      );
    },
  );
}
