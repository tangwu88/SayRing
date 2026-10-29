enum HealthReminderKind {
  highHeartRate('high_heart_rate', '心率偏高提醒'),
  lowHeartRate('low_heart_rate', '心率偏低提醒'),
  lowBloodOxygen('low_blood_oxygen', '血氧偏低提醒'),
  symptoms('symptoms', '不适记录');

  const HealthReminderKind(this.wireName, this.label);
  final String wireName;
  final String label;
}

enum HealthReminderSymptom {
  chestDiscomfort('chest_discomfort', '胸部不适'),
  breathlessness('breathlessness', '明显气短或呼吸困难'),
  faintness('faintness', '晕厥或接近晕厥');

  const HealthReminderSymptom(this.wireName, this.label);
  final String wireName;
  final String label;
}

/// Optional metadata in the existing owner-scoped encrypted alert table.
/// Acknowledgement and dialler opening are user actions, never recovery or rescue.
final class HealthReminderDetails {
  HealthReminderDetails({
    required this.kind,
    required this.recordedAt,
    this.ruleVersion,
    this.measuredAt,
    this.deviceName,
    this.reading,
    this.threshold,
    this.sampleIds = const [],
    this.symptoms = const {},
    this.acknowledgedAt,
    this.dialRequestedAt,
    this.notificationRequestedAt,
    this.ringVibrationRequestedAt,
    this.ringVibrationAcknowledgedAt,
  });

  final HealthReminderKind kind;
  final DateTime recordedAt;
  final String? ruleVersion;
  final DateTime? measuredAt;
  final String? deviceName;
  final double? reading;
  final double? threshold;
  final List<String> sampleIds;
  final Set<HealthReminderSymptom> symptoms;
  final DateTime? acknowledgedAt;
  final DateTime? dialRequestedAt;
  final DateTime? notificationRequestedAt;
  final DateTime? ringVibrationRequestedAt;
  final DateTime? ringVibrationAcknowledgedAt;

  HealthReminderDetails copyWith({
    DateTime? acknowledgedAt,
    DateTime? dialRequestedAt,
    DateTime? notificationRequestedAt,
    DateTime? ringVibrationRequestedAt,
    DateTime? ringVibrationAcknowledgedAt,
  }) => HealthReminderDetails(
    kind: kind,
    recordedAt: recordedAt,
    ruleVersion: ruleVersion,
    measuredAt: measuredAt,
    deviceName: deviceName,
    reading: reading,
    threshold: threshold,
    sampleIds: sampleIds,
    symptoms: symptoms,
    acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    dialRequestedAt: dialRequestedAt ?? this.dialRequestedAt,
    notificationRequestedAt:
        notificationRequestedAt ?? this.notificationRequestedAt,
    ringVibrationRequestedAt:
        ringVibrationRequestedAt ?? this.ringVibrationRequestedAt,
    ringVibrationAcknowledgedAt:
        ringVibrationAcknowledgedAt ?? this.ringVibrationAcknowledgedAt,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'kind': kind.wireName,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    if (ruleVersion != null) 'ruleVersion': ruleVersion,
    if (measuredAt != null) 'measuredAt': measuredAt!.toUtc().toIso8601String(),
    if (deviceName != null) 'deviceName': deviceName,
    if (reading != null) 'reading': reading,
    if (threshold != null) 'threshold': threshold,
    'sampleIds': sampleIds,
    'symptoms': symptoms.map((value) => value.wireName).toList(),
    if (acknowledgedAt != null)
      'acknowledgedAt': acknowledgedAt!.toUtc().toIso8601String(),
    if (dialRequestedAt != null)
      'dialRequestedAt': dialRequestedAt!.toUtc().toIso8601String(),
    if (notificationRequestedAt != null)
      'notificationRequestedAt': notificationRequestedAt!
          .toUtc()
          .toIso8601String(),
    if (ringVibrationRequestedAt != null)
      'ringVibrationRequestedAt': ringVibrationRequestedAt!
          .toUtc()
          .toIso8601String(),
    if (ringVibrationAcknowledgedAt != null)
      'ringVibrationAcknowledgedAt': ringVibrationAcknowledgedAt!
          .toUtc()
          .toIso8601String(),
  };

  static HealthReminderDetails? tryParse(Object? value) {
    if (value is! Map || value['schemaVersion'] != 1) return null;
    final kind = HealthReminderKind.values
        .where((item) => item.wireName == value['kind'])
        .firstOrNull;
    final recorded = DateTime.tryParse('${value['recordedAt'] ?? ''}');
    if (kind == null || recorded == null) return null;
    final symptoms = value['symptoms'];
    final sampleIds = value['sampleIds'];
    final reading = value['reading'];
    return HealthReminderDetails(
      kind: kind,
      recordedAt: recorded.toUtc(),
      ruleVersion: value['ruleVersion'] is String
          ? value['ruleVersion'] as String
          : null,
      measuredAt: DateTime.tryParse('${value['measuredAt'] ?? ''}')?.toUtc(),
      deviceName: value['deviceName'] is String
          ? value['deviceName'] as String
          : null,
      reading: reading is num && reading.isFinite ? reading.toDouble() : null,
      threshold:
          value['threshold'] is num && (value['threshold'] as num).isFinite
          ? (value['threshold'] as num).toDouble()
          : null,
      sampleIds: sampleIds is List
          ? List.unmodifiable(sampleIds.whereType<String>())
          : const [],
      symptoms: symptoms is List
          ? Set.unmodifiable(
              HealthReminderSymptom.values.where(
                (item) => symptoms.contains(item.wireName),
              ),
            )
          : const {},
      acknowledgedAt: DateTime.tryParse(
        '${value['acknowledgedAt'] ?? ''}',
      )?.toUtc(),
      dialRequestedAt: DateTime.tryParse(
        '${value['dialRequestedAt'] ?? ''}',
      )?.toUtc(),
      notificationRequestedAt: DateTime.tryParse(
        '${value['notificationRequestedAt'] ?? ''}',
      )?.toUtc(),
      ringVibrationRequestedAt: DateTime.tryParse(
        '${value['ringVibrationRequestedAt'] ?? ''}',
      )?.toUtc(),
      ringVibrationAcknowledgedAt: DateTime.tryParse(
        '${value['ringVibrationAcknowledgedAt'] ?? ''}',
      )?.toUtc(),
    );
  }
}
