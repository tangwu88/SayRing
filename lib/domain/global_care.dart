class GlobalCareRelationship {
  const GlobalCareRelationship({
    required this.id,
    required this.status,
    required this.received,
    required this.name,
    required this.metrics,
    this.expiresAt,
  });
  final String id;
  final String status;
  final bool received;
  final String name;
  final Set<String> metrics;
  final DateTime? expiresAt;
  bool get active =>
      status == 'active' &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
  factory GlobalCareRelationship.fromJson(Map<String, Object?> value) {
    final id = value['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Missing care identifier');
    }
    final received = value['direction'] == 'received';
    final person = value[received ? 'inviter' : 'recipient'];
    return GlobalCareRelationship(
      id: id,
      status: '${value['status'] ?? ''}',
      received: received,
      name: person is Map ? '${person['nickname'] ?? ''}' : '',
      metrics: (value['metrics'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      expiresAt: DateTime.tryParse('${value['expiresAt'] ?? ''}'),
    );
  }
}

/// Calendar midnights, not fixed 24-hour durations, preserve DST boundaries.
({DateTime from, DateTime to}) globalLocalDayRange(DateTime date) => (
  from: DateTime(date.year, date.month, date.day).toUtc(),
  to: DateTime(date.year, date.month, date.day + 1).toUtc(),
);
