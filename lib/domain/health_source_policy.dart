import 'health_record_validation.dart';
import 'models.dart';

List<HealthRecord> ringPreferredHealthRecords(
  Iterable<HealthRecord> records, {
  String? preferredDeviceId,
}) {
  final source = records.toList(growable: false);
  final selectedIds = <String>{};
  final groups = <String, List<HealthRecord>>{};
  for (final record in source) {
    final day = _localDay(record.measuredAt, record.timezone);
    final key = '${record.metric.wireName}\u0000$day';
    groups.putIfAbsent(key, () => <HealthRecord>[]).add(record);
  }
  for (final group in groups.values) {
    final unknown = group.where(
      (record) =>
          record.sourceDeviceCategory != 'ring' &&
          record.sourceDeviceCategory != 'watch',
    );
    selectedIds.addAll(unknown.map((record) => record.id));
    final rings = _usableCategory(group, 'ring');
    final watches = _usableCategory(group, 'watch');
    final preferred = rings.isNotEmpty ? rings : watches;
    if (preferred.isEmpty) {
      selectedIds.addAll(group.map((record) => record.id));
      continue;
    }
    final selectedDevice = _selectDevice(preferred, preferredDeviceId);
    selectedIds.addAll(
      _collapseCumulative(selectedDevice).map((record) => record.id),
    );
  }
  return source
      .where((record) => selectedIds.contains(record.id))
      .toList(growable: false);
}

List<HealthRecord> _usableCategory(
  List<HealthRecord> records,
  String category,
) => records
    .where(
      (record) =>
          record.sourceDeviceCategory == category &&
          record.quality.toLowerCase() != 'invalid' &&
          hasSaneWearableTransportValues(record),
    )
    .toList(growable: false);

List<HealthRecord> _selectDevice(
  List<HealthRecord> records,
  String? preferredDeviceId,
) {
  final withoutIdentity = records
      .where((record) => record.deviceId.isEmpty)
      .toList(growable: false);
  final withIdentity = records
      .where((record) => record.deviceId.isNotEmpty)
      .toList(growable: false);
  if (withIdentity.isEmpty) return records;
  final available = withIdentity.map((record) => record.deviceId).toSet();
  final chosen =
      preferredDeviceId != null && available.contains(preferredDeviceId)
      ? preferredDeviceId
      : ([...withIdentity]..sort(_compareLatestStable)).first.deviceId;
  return [
    ...withoutIdentity,
    ...withIdentity.where((record) => record.deviceId == chosen),
  ];
}

List<HealthRecord> _collapseCumulative(List<HealthRecord> records) {
  const cumulative = {
    HealthMetric.steps,
    HealthMetric.distance,
    HealthMetric.calories,
  };
  final keyless = records
      .where((record) => record.deviceId.isEmpty)
      .toList(growable: false);
  final latest = <String, HealthRecord>{};
  for (final record in records.where((record) => record.deviceId.isNotEmpty)) {
    if (!cumulative.contains(record.metric)) {
      latest['record:${record.id}'] = record;
      continue;
    }
    final key = '${record.metric.wireName}\u0000${record.deviceId}';
    final current = latest[key];
    if (current == null || _compareLatestStable(record, current) < 0) {
      latest[key] = record;
    }
  }
  return [...keyless, ...latest.values];
}

int _compareLatestStable(HealthRecord left, HealthRecord right) {
  final time = right.measuredAt.compareTo(left.measuredAt);
  if (time != 0) return time;
  final identity = left.deviceId.compareTo(right.deviceId);
  return identity != 0 ? identity : left.id.compareTo(right.id);
}

String _localDay(DateTime measuredAt, String timezone) {
  final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(timezone.trim());
  var minutes = 0;
  if (match != null) {
    final hours = int.tryParse(match[2]!) ?? 0;
    final remainder = int.tryParse(match[3]!) ?? 0;
    if (hours <= 14 && remainder <= 59 && !(hours == 14 && remainder != 0)) {
      minutes = (hours * 60 + remainder) * (match[1] == '-' ? -1 : 1);
    }
  }
  return measuredAt
      .toUtc()
      .add(Duration(minutes: minutes))
      .toIso8601String()
      .substring(0, 10);
}
