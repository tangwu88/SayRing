/// Strict diagnostic boundary: fixed enums and counts, never raw SDK objects.
bool isBoundedSyncReadEvidence(Object? value) {
  bool object(Object? v, Set<String> keys) =>
      v is Map && v.keys.every(keys.contains);
  const counters = {
    'requests',
    'packets',
    'wireRows',
    'decodedRows',
    'mappedRecords',
    'filteredRecords',
  };
  if (!object(value, {'metrics', 'clock', 'monitoring'})) return false;
  final root = value as Map;
  final rows = root['metrics'];
  if (rows is! List || rows.length > 7) return false;
  final seen = <String>{};
  for (final row in rows) {
    if (!object(row, {'metric', 'state', 'mappingObserved', ...counters})) {
      return false;
    }
    final r = row as Map;
    if (r['mappingObserved'] is! bool) return false;
    if (!const {
          'steps',
          'sleep',
          'heart_rate',
          'blood_oxygen',
          'hrv',
          'stress',
          'body_temperature',
        }.contains(r['metric']) ||
        !seen.add(r['metric'] as String) ||
        !const {
          'not_received',
          'partial',
          'complete',
          'no_data',
          'failed',
        }.contains(r['state'])) {
      return false;
    }
    for (final key in counters) {
      final n = r[key];
      if (n is! int || n < 0 || n > 1000000) return false;
    }
  }
  final clock = root['clock'];
  if (!object(clock, {'format', 'submission', 'verification'})) return false;
  final c = clock as Map;
  if (!const {'not_confirmed', 'confirmed'}.contains(c['format']) ||
      !const {
        'not_requested',
        'pending',
        'attempted',
        'expired',
      }.contains(c['submission']) ||
      c['verification'] != 'not_observed') {
    return false;
  }
  if (root.containsKey('monitoring')) {
    final m = root['monitoring'];
    if (!object(m, {'heartRate', 'bloodOxygen'}) ||
        (m as Map).values.any((v) => v is! bool)) {
      return false;
    }
  }
  return true;
}
