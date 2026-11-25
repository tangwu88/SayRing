Map<String, Object?> firstReadEvidence() => {
  'metrics': <Map<String, Object?>>[
    {
      'metric': 'heart_rate',
      'state': 'partial',
      'mappingObserved': true,
      'requests': 1,
      'packets': 2,
      'wireRows': 3,
      'decodedRows': 3,
      'mappedRecords': 1,
      'filteredRecords': 2,
    },
  ],
  'clock': {
    'format': 'confirmed',
    'submission': 'attempted',
    'verification': 'not_observed',
  },
  'monitoring': {'heartRate': true},
};
