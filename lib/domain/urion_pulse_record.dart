/// The three EB1 pulse indices are device scores, not heart rate or diagnoses.
/// Keep the original timestamp and scores; reading history never re-dates it.
class UrionPulseRecord {
  const UrionPulseRecord({
    required this.deviceId,
    required this.rawTimestamp,
    required this.bloodStasis,
    required this.qiBlood,
    required this.dampness,
    required this.measuredAt,
  });

  final String deviceId;
  final int rawTimestamp;
  final int bloodStasis;
  final int qiBlood;
  final int dampness;
  final DateTime measuredAt;

  String get fingerprint =>
      '$deviceId|$rawTimestamp|$bloodStasis|$qiBlood|$dampness';

  DateTime? displayTime({DateTime? now}) =>
      measuredAt.year >= 2000 &&
          !measuredAt.isAfter(
            (now ?? DateTime.now()).toUtc().add(const Duration(minutes: 10)),
          )
      ? measuredAt
      : null;

  Map<String, Object?> toMap() => {
    'deviceId': deviceId,
    'rawTimestamp': rawTimestamp,
    'bloodStasis': bloodStasis,
    'qiBlood': qiBlood,
    'dampness': dampness,
    'measuredAt': measuredAt.toUtc().toIso8601String(),
  };

  static UrionPulseRecord? tryParse(Object? raw, {required String deviceId}) {
    if (raw is! Map || !deviceId.startsWith('urion:')) return null;
    if (raw['deviceId'] != null && raw['deviceId'] != deviceId) return null;
    final stamp = raw['rawTimestamp'];
    final flow = raw['bloodStasis'];
    final vitality = raw['qiBlood'];
    final moisture = raw['dampness'];
    if (stamp is! int ||
        stamp <= 0 ||
        stamp >= 0xffffffff ||
        [
          flow,
          vitality,
          moisture,
        ].any((value) => value is! int || value < 0 || value > 10)) {
      return null;
    }
    final time = DateTime.tryParse('${raw['measuredAt'] ?? ''}');
    if (time == null) return null;
    return UrionPulseRecord(
      deviceId: deviceId,
      rawTimestamp: stamp,
      bloodStasis: flow as int,
      qiBlood: vitality as int,
      dampness: moisture as int,
      measuredAt: time.toUtc(),
    );
  }
}
