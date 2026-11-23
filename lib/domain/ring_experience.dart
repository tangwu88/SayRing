import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'health_record_validation.dart';
import 'models.dart';

const ringH5Host = 'app.saydian.cn';
const ringH5Path = '/global/say-ring/';

String newRingShareToken() {
  final random = Random.secure();
  return base64UrlEncode(
    List.generate(32, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
}

enum RingLinkType { invite, respond }

class RingLink {
  const RingLink(this.type, this.token);

  final RingLinkType type;
  final String token;

  static String? invitationCode(String value) {
    final code = value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    return RegExp(r'^[A-HJ-NP-Z2-9]{20}$').hasMatch(code) ? code : null;
  }

  static RingLink? parse(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host != ringH5Host ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery) {
      return null;
    }
    if (uri.path == '${ringH5Path}invite') {
      final code = invitationCode(uri.fragment);
      return code == null ? null : RingLink(RingLinkType.invite, code);
    }
    if (uri.path == '${ringH5Path}respond' &&
        RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(uri.fragment)) {
      return RingLink(RingLinkType.respond, uri.fragment);
    }
    return null;
  }

  static Uri url(String path, String token) =>
      Uri.https(ringH5Host, '$ringH5Path$path').replace(fragment: token);
}

Map<String, Object?> ringMap(Object? raw) =>
    raw is Map ? Map<String, Object?>.from(raw) : const {};

List<Map<String, Object?>> ringRows(Object? raw) => raw is List
    ? raw.whereType<Map>().map((row) => ringMap(row)).toList(growable: false)
    : const [];

DateTime ringDate(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime ringAddDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

String ringDateText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String ringClockText(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class RingSnapshot {
  const RingSnapshot(this.kind, this.date, this.fields, {this.note = ''});

  final String kind;
  final DateTime date;
  final Map<String, Object> fields;
  final String note;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'date': ringDateText(date),
    'note': note,
    'fields': [
      for (final entry in fields.entries)
        {'key': entry.key, 'value': entry.value},
    ],
  };

  static RingSnapshot? fromJson(Object? raw) {
    final row = ringMap(raw);
    final kind = row['kind'];
    final date = DateTime.tryParse('${row['date']}');
    if (kind is! String || date == null) return null;
    final fields = <String, Object>{};
    for (final field in ringRows(row['fields'])) {
      final key = field['key'];
      final value = field['value'];
      if (key is String && value != null) fields[key] = value;
    }
    return RingSnapshot(kind, date, fields, note: '${row['note'] ?? ''}');
  }
}

class PressureSample {
  const PressureSample({
    required this.at,
    required this.systolic,
    required this.diastolic,
    required this.source,
    this.label = '',
  });

  final DateTime at;
  final num systolic;
  final num diastolic;
  final String source;
  final String label;

  static bool validPair(num? systolic, num? diastolic) =>
      systolic != null &&
      diastolic != null &&
      systolic.isFinite &&
      diastolic.isFinite &&
      systolic >= 60 &&
      systolic <= 300 &&
      diastolic >= 20 &&
      diastolic <= 200 &&
      systolic > diastolic;

  static PressureSample? fromReference(Object? raw) {
    final row = ringMap(raw);
    final at = DateTime.tryParse('${row['at']}');
    final upper = row['systolic'];
    final lower = row['diastolic'];
    if (at == null ||
        upper is! num ||
        lower is! num ||
        !validPair(upper, lower)) {
      return null;
    }
    return PressureSample(
      at: at.toLocal(),
      systolic: upper,
      diastolic: lower,
      source: 'reference',
    );
  }

  static PressureSample? fromDevice(HealthRecord record) {
    final upper = record.values['systolic'];
    final lower = record.values['diastolic'];
    if (record.metric != HealthMetric.bloodPressure ||
        record.source != MeasurementSource.wearable ||
        record.deviceId.isEmpty ||
        !hasSaneWearableTransportValues(record) ||
        !validPair(upper, lower) ||
        record.unit.trim().toLowerCase() != 'mmhg') {
      return null;
    }
    return PressureSample(
      at: record.measuredAt.toLocal(),
      systolic: upper!,
      diastolic: lower!,
      source: record.deviceId,
      label: record.sourceModel.trim(),
    );
  }

  Map<String, Object> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'systolic': systolic,
    'diastolic': diastolic,
  };
}

String? urionPressureEvidence(HealthRecord record) {
  if (record.sourceVendor.toLowerCase() != 'urion' &&
      WearableSdkSource.fromDeviceId(record.deviceId) !=
          WearableSdkSource.urion) {
    return null;
  }
  if (PressureSample.fromDevice(record) == null) return null;
  return sha256
      .convert(
        utf8.encode(
          jsonEncode([
            record.id,
            record.deviceId,
            record.firmwareVersion,
            record.measuredAt.toUtc().microsecondsSinceEpoch,
            record.values['systolic'],
            record.values['diastolic'],
            record.values['pulse'],
          ]),
        ),
      )
      .toString();
}

class PressureDay {
  const PressureDay(this.date, this.systolic, this.diastolic, this.count);
  final DateTime date;
  final double systolic;
  final double diastolic;
  final int count;
}

List<PressureDay> pressureDays(Iterable<PressureSample> samples) {
  final groups = <DateTime, List<PressureSample>>{};
  for (final sample in samples) {
    groups.putIfAbsent(ringDate(sample.at), () => []).add(sample);
  }
  return [
    for (final day in groups.keys.toList()..sort())
      PressureDay(
        day,
        groups[day]!.fold<double>(0, (sum, r) => sum + r.systolic) /
            groups[day]!.length,
        groups[day]!.fold<double>(0, (sum, r) => sum + r.diastolic) /
            groups[day]!.length,
        groups[day]!.length,
      ),
  ];
}

({double systolic, double diastolic, int previous, int current})?
pressureChange(List<PressureDay> days, DateTime start, DateTime previousStart) {
  final earlier = days
      .where(
        (row) => !row.date.isBefore(previousStart) && row.date.isBefore(start),
      )
      .toList();
  final current = days.where((row) => !row.date.isBefore(start)).toList();
  if (earlier.length < 3 || current.length < 3) return null;
  double mean(List<PressureDay> rows, double Function(PressureDay) field) =>
      rows.map(field).reduce((a, b) => a + b) / rows.length;
  return (
    systolic:
        mean(current, (day) => day.systolic) -
        mean(earlier, (day) => day.systolic),
    diastolic:
        mean(current, (day) => day.diastolic) -
        mean(earlier, (day) => day.diastolic),
    previous: earlier.length,
    current: current.length,
  );
}
