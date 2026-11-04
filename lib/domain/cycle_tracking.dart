import 'dart:convert';
import 'dart:math' as math;
import 'models.dart';

/// 经期是日历日期，不能用UTC瞬时或DST间隔相除来算周期。
String cycleDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
DateTime parseCycleDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('日期不正确');
  }
  final date = DateTime.tryParse('${value}T00:00:00Z');
  if (date == null || cycleDate(date) != value) {
    throw const FormatException('日期不正确');
  }
  return date;
}

int cycleDays(String a, String b) =>
    parseCycleDate(b).difference(parseCycleDate(a)).inDays;

class CycleSettings {
  const CycleSettings({
    this.enabled = false,
    this.adultConfirmed = false,
    this.purposeAccepted = false,
    this.recordOnly = false,
    this.historyComplete = false,
    this.hideSummary = false,
    this.remind = false,
    this.recordRemind = false,
    this.leadDays = 2,
    this.hour = 9,
    this.minute = 0,
  });
  final bool enabled,
      adultConfirmed,
      purposeAccepted,
      recordOnly,
      historyComplete,
      hideSummary,
      remind,
      recordRemind;
  final int leadDays, hour, minute;
  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'adultConfirmed': adultConfirmed,
    'purposeAccepted': purposeAccepted,
    'recordOnly': recordOnly,
    'historyComplete': historyComplete,
    'hideSummary': hideSummary,
    'remind': remind,
    'recordRemind': recordRemind,
    'leadDays': leadDays,
    'hour': hour,
    'minute': minute,
  };
  factory CycleSettings.fromJson(Map<String, Object?> j) => CycleSettings(
    enabled: j['enabled'] == true,
    adultConfirmed: j['adultConfirmed'] == true,
    purposeAccepted: j['purposeAccepted'] == true,
    recordOnly: j['recordOnly'] == true,
    historyComplete: j['historyComplete'] == true,
    hideSummary: j['hideSummary'] == true,
    remind: j['remind'] == true,
    recordRemind: j['recordRemind'] == true,
    leadDays: (j['leadDays'] as num?)?.toInt() ?? 2,
    hour: (j['hour'] as num?)?.toInt() ?? 9,
    minute: (j['minute'] as num?)?.toInt() ?? 0,
  );
}

class CycleEntry {
  const CycleEntry({
    required this.id,
    required this.kind,
    required this.data,
    this.revision = 0,
    this.deleted = false,
    this.pending = false,
    this.mutationId = '',
    this.conflict,
  });
  final String id, kind, mutationId;
  final Map<String, Object?> data;
  final int revision;
  final bool deleted, pending;
  final Map<String, Object?>? conflict;
  String get start => '${data[kind == 'period' ? 'start' : 'date'] ?? ''}';
  String? get end => data['end'] as String?;
  CycleEntry copy({
    int? revision,
    bool? pending,
    Map<String, Object?>? conflict,
    bool clearConflict = false,
  }) => CycleEntry(
    id: id,
    kind: kind,
    data: data,
    revision: revision ?? this.revision,
    deleted: deleted,
    pending: pending ?? this.pending,
    mutationId: mutationId,
    conflict: clearConflict ? null : conflict ?? this.conflict,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'data': data,
    'revision': revision,
    'deleted': deleted,
    'pending': pending,
    'mutationId': mutationId,
    if (conflict != null) 'conflict': conflict,
  };
  factory CycleEntry.fromJson(Map<String, Object?> j) => CycleEntry(
    id: j['id'] as String,
    kind: j['kind'] as String,
    data: Map<String, Object?>.from(j['data'] as Map),
    revision: (j['revision'] as num?)?.toInt() ?? 0,
    deleted: j['deleted'] == true,
    pending: j['pending'] == true,
    mutationId: j['mutationId'] as String? ?? '',
    conflict: j['conflict'] is Map
        ? Map<String, Object?>.from(j['conflict'] as Map)
        : null,
  );
}

void validateCycleEntry(
  CycleEntry entry,
  Iterable<CycleEntry> others,
  String today,
) {
  parseCycleDate(entry.start);
  if (entry.start.compareTo(today) > 0) {
    throw const FormatException('实际记录不能填写未来日期');
  }
  if (entry.kind == 'period') {
    if (entry.end != null) {
      parseCycleDate(entry.end!);
      if (entry.end!.compareTo(entry.start) < 0 ||
          entry.end!.compareTo(today) > 0) {
        throw const FormatException('请核对经期结束日期');
      }
    }
    for (final other in others.where(
      (e) => e.kind == 'period' && e.id != entry.id && !e.deleted,
    )) {
      // 未结束的经期不能悄悄推断结束日期，也不能与新增经期重叠。
      if ((entry.end ?? '9999-12-31').compareTo(other.start) >= 0 &&
          (other.end ?? '9999-12-31').compareTo(entry.start) >= 0) {
        throw const FormatException('这段经期与已有记录重叠，请先核对或补充结束日期');
      }
    }
  } else if (entry.kind == 'daily') {
    const allowed = {
      'flow': ['none', 'light', 'medium', 'heavy'],
      'pain': ['none', 'mild', 'moderate', 'severe'],
      'mood': ['calm', 'low', 'irritable'],
      'fatigue': ['none', 'mild', 'strong'],
    };
    for (final item in entry.data.entries) {
      if (item.key == 'date') continue;
      if (item.key == 'tags') {
        if (item.value is! List ||
            (item.value as List).any(
              (x) =>
                  !['travel', 'unwell', 'medication', 'late_sleep'].contains(x),
            )) {
          throw const FormatException('感受记录不正确');
        }
      } else if (!(allowed[item.key]?.contains(item.value) ?? false)) {
        throw const FormatException('感受记录不正确');
      }
    }
  } else {
    throw const FormatException('记录类型不正确');
  }
}

class CyclePrediction {
  const CyclePrediction({
    required this.status,
    this.from,
    this.to,
    this.basis = const [],
    this.lengths = const [],
    this.generatedOn = '',
    this.modelVersion = 'calendar-v1',
  });
  final String status, generatedOn, modelVersion;
  final String? from, to;
  final List<String> basis;
  final List<int> lengths;
  int get completeCycles => lengths.length;
  Map<String, Object?> toJson() => {
    'status': status,
    'from': from,
    'to': to,
    'basis': basis,
    'lengths': lengths,
    'generatedOn': generatedOn,
    'modelVersion': modelVersion,
    'enhanced': false,
  };
}

CyclePrediction cyclePrediction(
  Iterable<CycleEntry> entries,
  CycleSettings settings,
  String today,
) {
  final periods =
      entries.where((e) => !e.deleted && e.kind == 'period').toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final available = periods.length > 7
      ? periods.sublist(periods.length - 7)
      : periods;
  final lengths = <int>[];
  if (settings.enabled && settings.historyComplete && !settings.recordOnly) {
    for (var i = 0; i + 1 < available.length; i++) {
      if (available[i].end == null ||
          available[i].end!.compareTo(available[i + 1].start) >= 0) {
        return CyclePrediction(status: 'incomplete', generatedOn: today);
      }
      lengths.add(cycleDays(available[i].start, available[i + 1].start));
    }
  }
  if (!settings.enabled ||
      settings.recordOnly ||
      !settings.historyComplete ||
      lengths.length < 3) {
    return CyclePrediction(
      status: settings.recordOnly ? 'record_only' : 'collecting',
      generatedOn: today,
    );
  }
  final last = parseCycleDate(available.last.start);
  final from = cycleDate(last.add(Duration(days: lengths.reduce(math.min))));
  final to = cycleDate(last.add(Duration(days: lengths.reduce(math.max))));
  return CyclePrediction(
    status: to.compareTo(today) < 0 ? 'needs_confirmation' : 'reference',
    from: from,
    to: to,
    basis: available.map((x) => '${x.id}:${x.revision}').toList(),
    lengths: lengths,
    generatedOn: today,
  );
}

/// 周期特征的质量门槛与原有新鲜读数告警不同：已验证历史可以用于回顾，不能触发实时告警。
class CycleNightFeature {
  const CycleNightFeature({
    required this.date,
    required this.sourceKey,
    required this.metric,
    required this.value,
    required this.samples,
    required this.coverageMinutes,
    required this.maxGapMinutes,
    required this.recordIds,
    this.enhancementEligible = false,
  });
  final String date, sourceKey, metric;
  final double value, coverageMinutes, maxGapMinutes;
  final int samples;
  final List<String> recordIds;
  final bool enhancementEligible;
  Map<String, Object?> toJson() => {
    'date': date,
    'sourceKey': sourceKey,
    'metric': metric,
    'value': value,
    'samples': samples,
    'coverageMinutes': coverageMinutes,
    'maxGapMinutes': maxGapMinutes,
    'recordIds': recordIds,
    'enhancementEligible': enhancementEligible,
  };
}

List<CycleNightFeature> cycleNightFeatures(
  List<HealthRecord> records, {
  DateTime? asOf,
}) {
  final now = asOf ?? DateTime.now();
  final nights = <CycleNightFeature>[];
  // 只使用有真实起止的主夜睡；总时长不能倒推出时间窗。
  for (final sleep in records.where(
    (r) =>
        r.metric == HealthMetric.sleep &&
        (r.sleepTimeline != null || r.nightWindows.isNotEmpty),
  )) {
    final windows = sleep.sleepTimeline == null
        ? sleep.nightWindows
        : [
            for (final session in sleep.sleepTimeline!.sessions.where(
              (s) => s.startedAt != null && s.endedAt != null,
            ))
              {
                'kind': session.kind.name,
                'startAt': session.startedAt!.toIso8601String(),
                'endAt': session.endedAt!.toIso8601String(),
                'date': sleep.sleepTimeline!.sdkDate,
              },
          ];
    for (final window in windows.where((w) => w['kind'] == 'night')) {
      final start = DateTime.tryParse('${window['startAt']}'),
          end = DateTime.tryParse('${window['endAt']}');
      if (start == null ||
          end == null ||
          end.isAfter(now) ||
          end.difference(start).inMinutes < 240) {
        continue;
      }
      final groups = <String, List<HealthRecord>>{};
      for (final r in records) {
        final p = r.provenance;
        if (r.deviceId != sleep.deviceId ||
            r.source != MeasurementSource.wearable ||
            r.origin != MeasurementOrigin.watchHistory ||
            r.measuredAt.isBefore(start) ||
            !r.measuredAt.isBefore(end) ||
            r.measuredAt.isAfter(now) ||
            !['sdk', 'slot'].contains(p['timeBasis']) ||
            p['contactVerified'] == false ||
            p['sdkQuality'] == 0 ||
            r.values['sdkQuality'] == 0 ||
            (p['validCount'] is num && (p['validCount'] as num) < 2) ||
            r.firmwareVersion.isEmpty ||
            r.sourceVendor.isEmpty ||
            ['invalid', 'suspect'].contains(r.quality)) {
          continue;
        }
        final metric =
            r.metric == HealthMetric.bodyTemperature &&
                p['temperatureKind'] == 'skin'
            ? 'skin_temperature'
            : r.metric == HealthMetric.heartRate
            ? 'sleep_heart_rate'
            : r.metric == HealthMetric.hrv &&
                  ['sdnn', 'rmssd'].contains(p['algorithm'])
            ? 'hrv_${p['algorithm']}'
            : null;
        if (metric == null || r.origin == MeasurementOrigin.appMeasurement) {
          continue;
        }
        final key =
            '${r.deviceId}|${r.sourceVendor}|${r.sourceModel}|${r.firmwareVersion}|$metric|${r.rawVersion}';
        (groups[key] ??= []).add(r);
      }
      for (final entry in groups.entries) {
        final samples = entry.value
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        final interval = (samples.first.provenance['intervalSeconds'] as num?)
            ?.toDouble();
        if (interval == null ||
            interval <= 0 ||
            samples.any((r) => r.provenance['intervalSeconds'] != interval)) {
          continue;
        }
        final unique = <int, HealthRecord>{
          for (final r in samples) r.measuredAt.millisecondsSinceEpoch: r,
        };
        final ordered = unique.values.toList()
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        final span = end.difference(start).inSeconds;
        final coverage = math.min(span.toDouble(), ordered.length * interval);
        var gap = ordered.first.measuredAt
            .difference(start)
            .inSeconds
            .toDouble();
        for (var i = 1; i < ordered.length; i++) {
          gap = math.max(
            gap,
            ordered[i].measuredAt
                .difference(ordered[i - 1].measuredAt)
                .inSeconds
                .toDouble(),
          );
        }
        gap = math.max(
          gap,
          end.difference(ordered.last.measuredAt).inSeconds.toDouble(),
        );
        // 研究数据集的保守工程过滤，不代表临床验证或开放增强模型。
        if (coverage / span < .7 || gap > 3600 || ordered.length < 4) continue;
        final metric = entry.key.split('|')[4];
        final values =
            ordered
                .map((r) {
                  final raw = metric == 'skin_temperature'
                      ? (r.values['skinTemperature'] ?? r.values['value'])
                      : r.values[metric.startsWith('hrv_')
                            ? '${r.provenance['algorithm']}'
                            : 'value'];
                  return (raw ?? double.nan).toDouble();
                })
                .where((v) => v.isFinite)
                .toList()
              ..sort();
        if (values.length != ordered.length) continue;
        final value = values.length.isOdd
            ? values[values.length ~/ 2]
            : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2;
        nights.add(
          CycleNightFeature(
            date: '${window['date']}',
            sourceKey: entry.key,
            metric: metric,
            value: value,
            samples: ordered.length,
            coverageMinutes: coverage / 60,
            maxGapMinutes: gap / 60,
            recordIds: ordered.map((r) => r.id).toList(),
            enhancementEligible: ordered.every(
              (r) => r.provenance['contactVerified'] == true,
            ),
          ),
        );
      }
    }
  }
  // 同一主夜睡快照重复到达也不能提高有效夜数。
  return {for (final n in nights) '${n.sourceKey}|${n.date}': n}.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

List<String> cycleExplanation(CyclePrediction p, int nights) => [
  p.status == 'reference'
      ? '下次经期参考：${p.from} 至 ${p.to}。'
      : p.status == 'needs_confirmation'
      ? '上次参考日期已过，请核对经期记录。'
      : '继续记录，逐步了解你的周期。',
  '依据${p.completeCycles}个完整周期；有$nights晚可用戒指数据。',
  p.status == 'reference'
      ? '可以按参考范围提前准备，并继续记录实际日期。'
      : '记录实际开始与结束日期，佩戴戒指入睡可积累趋势。',
];
String cycleCsv(Iterable<CycleEntry> entries) {
  String cell(Object? v) => '"${'$v'.replaceAll('"', '""')}"';
  return '\uFEFF类型,开始或日期,结束,记录\r\n${entries.where((e) => !e.deleted).map((e) => [e.kind, e.start, e.end ?? '', jsonEncode(e.data)].map(cell).join(',')).join('\r\n')}';
}
