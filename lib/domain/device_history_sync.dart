/// Written only after a confirmed range has been durably stored.
class DeviceHistorySyncCheckpoint {
  const DeviceHistorySyncCheckpoint({
    required this.signature,
    required this.fullAt,
    required this.latestAt,
  });
  final String signature;
  final DateTime fullAt;
  final DateTime latestAt;

  static DeviceHistorySyncCheckpoint? parse(Object? value) {
    if (value is! Map || value['version'] != 1) {
      return null;
    }
    final full = DateTime.tryParse('${value['fullAt']}');
    final latest = DateTime.tryParse('${value['latestAt']}');
    if (full == null || latest == null || value['signature'] is! String) {
      return null;
    }
    return DeviceHistorySyncCheckpoint(
      signature: value['signature'] as String,
      fullAt: full,
      latestAt: latest,
    );
  }

  bool permitsRecent(DateTime now, String currentSignature) {
    final age = now.difference(fullAt);
    final lastAge = now.difference(latestAt);
    final local = fullAt.toLocal();
    return signature == currentSignature &&
        !age.isNegative &&
        !lastAge.isNegative &&
        !latestAt.isBefore(fullAt) &&
        age < const Duration(hours: 18) &&
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  bool recentlyCompleted(DateTime now, String currentSignature) =>
      permitsRecent(now, currentSignature) &&
      now.difference(latestAt) < const Duration(seconds: 90);

  Map<String, Object?> toJson() => {
    'version': 1,
    'signature': signature,
    'fullAt': fullAt.toUtc().toIso8601String(),
    'latestAt': latestAt.toUtc().toIso8601String(),
  };
}
