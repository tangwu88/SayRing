import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models.dart';
import '../domain/ring_experience.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/ui_labels.dart';
import '../services/app_controller.dart';
import '../services/health_analysis.dart';

String ringText(BuildContext context, String chinese, String english) =>
    Localizations.localeOf(context).languageCode == 'zh' ? chinese : english;

const _labels = <String, (String, String, String)>{
  'sleepMinutes': ('睡眠时长', 'Sleep duration', 'min'),
  'sleepAverageMinutes': ('平均睡眠', 'Average sleep', 'min'),
  'previousSleepAverageMinutes': (
    '上周同期平均睡眠',
    'Previous week’s average sleep',
    'min',
  ),
  'rangeEnd': ('记录截至', 'Through', ''),
  'deepMinutes': ('深睡', 'Deep sleep', 'min'),
  'lightMinutes': ('浅睡', 'Light sleep', 'min'),
  'remMinutes': ('快速眼动', 'REM sleep', 'min'),
  'awakeMinutes': ('清醒时长', 'Awake time', 'min'),
  'sleepStart': ('入睡', 'Fell asleep', ''),
  'sleepEnd': ('醒来', 'Woke up', ''),
  'sleepScore': ('睡眠评分', 'Sleep score', ''),
  'sportName': ('运动', 'Activity', ''),
  'sportMinutes': ('运动时长', 'Duration', 'min'),
  'previousSportMinutes': ('上周同期运动时长', 'Previous week’s activity', 'min'),
  'distanceKm': ('距离', 'Distance', 'km'),
  'steps': ('步数', 'Steps', ''),
  'heartRate': ('心率', 'Heart rate', 'bpm'),
  'hrv': ('心率变异性', 'HRV', 'ms'),
  'oxygen': ('血氧', 'Blood oxygen', '%'),
  'temperatureC': ('温度', 'Temperature', '°C'),
  'systolic': ('收缩压', 'Systolic pressure', 'mmHg'),
  'diastolic': ('舒张压', 'Diastolic pressure', 'mmHg'),
  'pulse': ('脉搏', 'Pulse', 'bpm'),
  'measuredTime': ('测量时间', 'Reading time', ''),
  'recordDays': ('有记录天数', 'Days recorded', ''),
  'stress': ('压力', 'Stress', ''),
  'bloodGlucose': ('血糖', 'Blood glucose', 'mmol/L'),
};

String ringShareField(BuildContext context, String key) {
  final label = _labels[key];
  return label == null ? '' : ringText(context, label.$1, label.$2);
}

String ringShareValue(BuildContext context, String key, Object value) {
  final unit = _labels[key]?.$3 ?? '';
  final text = value is num
      ? NumberFormat(
          '0.#####',
          Localizations.localeOf(context).toLanguageTag(),
        ).format(value)
      : '$value';
  return unit.isEmpty ? text : '$text $unit';
}

String ringSnapshotTitle(BuildContext context, String kind) => switch (kind) {
  'sleep' => ringText(context, '睡眠报告', 'Sleep report'),
  'health' => ringText(context, '健康记录', 'Health record'),
  'workout' => ringText(context, '运动记录', 'Workout'),
  'week' => ringText(context, '我的这一周', 'My week'),
  _ => 'Say Ring',
};

String ringReactionText(BuildContext context, String kind) => switch (kind) {
  'hug' => ringText(context, '抱抱你', 'Sending a hug'),
  'walk' => ringText(context, '下次一起走', 'Let’s walk together'),
  _ => ringText(context, '为你开心', 'Happy for you'),
};

void showRingError(BuildContext context, Object _) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ringText(context, '暂未成功，请稍后重试', 'Please try again shortly'),
      ),
    ),
  );
}

Rect _shareAnchor(BuildContext context) {
  final box = context.findRenderObject();
  return box is RenderBox && box.hasSize && !box.size.isEmpty
      ? box.localToGlobal(Offset.zero) & box.size
      : const Rect.fromLTWH(0, 0, 1, 1);
}

Future<void> ringSystemShare(BuildContext context, Uri link) async {
  await SharePlus.instance.share(
    ShareParams(
      text: link.toString(),
      sharePositionOrigin: _shareAnchor(context),
    ),
  );
}

Future<void> ringCopy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ringText(context, '已复制', 'Copied'))));
  }
}

RingSnapshot? ringWorkoutSnapshot(BuildContext context, SportRecord record) {
  final start = record.startedAt?.toLocal();
  if (start == null ||
      start.isAfter(DateTime.now()) ||
      record.durationSeconds <= 0) {
    return null;
  }
  return RingSnapshot('workout', start, {
    'sportName': AppLocalizations.of(context)!.sportModeName(record.mode),
    'sportMinutes': (record.durationSeconds / 60 * 10).round() / 10,
    if (!record.missingMetrics.contains('distanceKm') && record.distanceKm > 0)
      'distanceKm': record.distanceKm,
    if (!record.missingMetrics.contains('steps') && record.steps > 0)
      'steps': record.steps,
    if (record.heartRate > 0 && !record.missingMetrics.contains('heartRate'))
      'heartRate': record.heartRate,
  });
}

List<RingSnapshot> ringWorkoutSnapshotsOn(
  BuildContext context,
  List<SportRecord> records,
  DateTime day,
) {
  final wanted = ringDate(day);
  final rows =
      records
          .where(
            (r) =>
                r.startedAt != null &&
                ringDate(r.startedAt!.toLocal()) == wanted,
          )
          .toList()
        ..sort((a, b) => b.startedAt!.compareTo(a.startedAt!));
  return rows.map((r) => ringWorkoutSnapshot(context, r)).nonNulls.toList();
}

RingSnapshot? ringHealthSnapshot(HealthRecord record) {
  final map = switch (record.metric) {
    HealthMetric.bloodPressure => {
      'systolic': 'systolic',
      'diastolic': 'diastolic',
      'pulse': 'pulse',
    },
    HealthMetric.heartRate => {'bpm': 'heartRate', 'value': 'heartRate'},
    HealthMetric.hrv => {'hrv': 'hrv', 'value': 'hrv'},
    HealthMetric.bloodOxygen => {'spo2': 'oxygen', 'value': 'oxygen'},
    HealthMetric.bodyTemperature => {
      'temperature': 'temperatureC',
      'value': 'temperatureC',
    },
    HealthMetric.steps => {'steps': 'steps', 'value': 'steps'},
    HealthMetric.distance => {
      'distance': 'distanceKm',
      'km': 'distanceKm',
      'value': 'distanceKm',
    },
    HealthMetric.bloodGlucose => {
      'glucose': 'bloodGlucose',
      'value': 'bloodGlucose',
    },
    HealthMetric.stress => {'stress': 'stress', 'value': 'stress'},
    _ => const <String, String>{},
  };
  final values = <String, Object>{};
  for (final entry in map.entries) {
    final value = record.values[entry.key];
    if (value != null && value.isFinite && value >= 0) {
      values.putIfAbsent(entry.value, () => value);
    }
  }
  if (values.isEmpty || record.measuredAt.isAfter(DateTime.now())) return null;
  final date = HealthAnalysisService.displayTime(record);
  return RingSnapshot('health', date, {
    ...values,
    'measuredTime': ringClockText(date),
  });
}

Future<List<RingSnapshot>> ringHealthSnapshotsOn(
  AppController controller,
  HealthRecord source,
  DateTime day,
) async {
  final wanted = ringDate(day);
  final records = await controller.loadHealthRecords(
    metric: source.metric,
    start: ringAddDays(wanted, -1),
    end: ringAddDays(wanted, 2),
  );
  final rows =
      records
          .where(
            (row) =>
                row.deviceId == source.deviceId &&
                row.source == source.source &&
                ringDate(HealthAnalysisService.displayTime(row)) == wanted,
          )
          .toList()
        ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  return rows.map(ringHealthSnapshot).nonNulls.toList();
}

class RingSnapshotView extends StatelessWidget {
  const RingSnapshotView({required this.snapshot, super.key});
  final RingSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ringSnapshotTitle(context, snapshot.kind),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            MaterialLocalizations.of(context).formatMediumDate(snapshot.date),
          ),
          if (snapshot.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(snapshot.note),
          ],
          for (final entry in snapshot.fields.entries)
            if (_labels.containsKey(entry.key))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ringShareField(context, entry.key)),
                subtitle: Text(ringShareValue(context, entry.key, entry.value)),
              ),
        ],
      ),
    ),
  );
}

class RingShareButton extends StatefulWidget {
  const RingShareButton({
    required this.controller,
    required this.snapshot,
    this.compact = false,
    this.loadDate,
    this.canRead,
    super.key,
  });
  final AppController controller;
  final RingSnapshot? snapshot;
  final bool compact;
  final Future<List<RingSnapshot>> Function(DateTime)? loadDate;
  final bool Function()? canRead;

  @override
  State<RingShareButton> createState() => _RingShareButtonState();
}

class _RingShareButtonState extends State<RingShareButton> {
  late final AppController _controller;
  late final String? _owner;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _owner = _controller.ringExperience
        ? _controller.ringExperienceOwner
        : null;
  }

  bool get _canShare {
    return identical(widget.controller, _controller) &&
        _controller.ringSharingEnabled &&
        _controller.isAuthenticated &&
        _owner == _controller.ringExperienceOwner &&
        widget.canRead?.call() != false;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final input = widget.snapshot;
      if (input == null || input.fields.isEmpty || !_canShare) {
        return const SizedBox.shrink();
      }
      final title = ringText(context, '分享给好友', 'Share with friends');
      void open() {
        if (!_canShare) return;
        final loadDate = widget.loadDate;
        final canRead = widget.canRead;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RingComposeSharePage(
              controller: _controller,
              snapshot: input,
              loadDate: loadDate,
              canRead: () =>
                  _owner == _controller.ringExperienceOwner &&
                  canRead?.call() != false,
            ),
          ),
        );
      }

      return widget.compact
          ? IconButton(
              tooltip: title,
              onPressed: open,
              icon: const Icon(Icons.ios_share_rounded),
            )
          : OutlinedButton.icon(
              onPressed: open,
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(title),
            );
    },
  );
}

class RingComposeSharePage extends StatefulWidget {
  const RingComposeSharePage({
    required this.controller,
    required this.snapshot,
    this.loadDate,
    this.canRead,
    super.key,
  });
  final AppController controller;
  final RingSnapshot snapshot;
  final Future<List<RingSnapshot>> Function(DateTime)? loadDate;
  final bool Function()? canRead;

  @override
  State<RingComposeSharePage> createState() => _RingComposeSharePageState();
}

class _RingComposeSharePageState extends State<RingComposeSharePage> {
  late final String owner = widget.controller.ringExperienceOwner;
  late final TextEditingController note = TextEditingController(
    text: widget.snapshot.note,
  );
  late RingSnapshot? draft = widget.snapshot;
  late DateTime date = ringDate(widget.snapshot.date);
  late List<RingSnapshot> choices = [widget.snapshot];
  late Set<String> selected = _defaultFields(widget.snapshot);
  String? token;
  Uri? link;
  bool confirmed = false;
  bool busy = false;
  bool loadingDate = false;
  bool dateFailed = false;

  bool get current =>
      mounted &&
      owner == widget.controller.ringExperienceOwner &&
      (widget.canRead?.call() ?? true);

  Set<String> _defaultFields(RingSnapshot? row) =>
      row == null || row.kind == 'health'
      ? <String>{}
      : row.fields.keys.where((key) => key != 'heartRate').toSet();

  RingSnapshot? get preview {
    final row = draft;
    return row == null
        ? null
        : RingSnapshot(row.kind, row.date, {
            for (final entry in row.fields.entries)
              if (selected.contains(entry.key)) entry.key: entry.value,
          }, note: note.text.trim());
  }

  Future<void> _pickShareDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (current && chosen != null) await _readDate(chosen);
  }

  Future<void> _readDate(DateTime day) async {
    final load = widget.loadDate;
    if (!current || loadingDate || load == null) return;
    setState(() {
      loadingDate = true;
      dateFailed = false;
      date = ringDate(day);
      draft = null;
      choices = [];
      selected = {};
      confirmed = false;
      token = null;
    });
    try {
      final rows = (await load(day)).where((r) => r.fields.isNotEmpty).toList();
      if (current) {
        setState(() {
          choices = rows;
          draft = rows.firstOrNull;
          selected = _defaultFields(draft);
        });
      }
    } catch (_) {
      if (current) setState(() => dateFailed = true);
    } finally {
      if (mounted) setState(() => loadingDate = false);
    }
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final snapshot = preview;
    if (busy ||
        loadingDate ||
        !confirmed ||
        selected.isEmpty ||
        !current ||
        snapshot == null) {
      return;
    }
    setState(() => busy = true);
    final key = token ??= newRingShareToken();
    try {
      await widget.controller.ringRequest(
        'POST',
        'shares',
        data: {'token': key, 'confirmed': true, 'snapshot': snapshot.toJson()},
      );
      if (!mounted || !current) return;
      final issued = RingLink.url('share', key);
      setState(() => link = issued);
      await ringSystemShare(context, issued);
    } catch (error) {
      if (mounted) showRingError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _changed() => setState(() {
    confirmed = false;
    token = null;
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = !busy && !loadingDate && link == null;
    final row = draft;
    final snapshot = preview;
    return Scaffold(
      appBar: AppBar(
        title: Text(ringText(context, '分享给好友', 'Share with friends')),
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => !current
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (link == null) ...[
                    if (widget.loadDate != null)
                      OutlinedButton.icon(
                        key: const Key('ring-share-date'),
                        onPressed: canEdit ? _pickShareDate : null,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(date),
                        ),
                      ),
                    if (loadingDate)
                      const LinearProgressIndicator()
                    else if (dateFailed)
                      TextButton(
                        onPressed: () => _readDate(date),
                        child: Text(ringText(context, '重试读取', 'Retry loading')),
                      )
                    else if (row == null)
                      Text(
                        ringText(
                          context,
                          '这一天没有可分享的记录。',
                          'Nothing to share for this date.',
                        ),
                      ),
                    if (choices.length > 1)
                      for (final choice in choices)
                        ListTile(
                          title: Text(
                            '${choice.fields['sportName'] ?? ringSnapshotTitle(context, choice.kind)} · ${ringClockText(choice.date)}',
                          ),
                          selected: identical(choice, row),
                          leading: Icon(
                            identical(choice, row)
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          onTap: canEdit
                              ? () {
                                  setState(() {
                                    draft = choice;
                                    selected = _defaultFields(choice);
                                    confirmed = false;
                                    token = null;
                                  });
                                }
                              : null,
                        ),
                    for (final key in row?.fields.keys ?? const <String>[])
                      CheckboxListTile(
                        value: selected.contains(key),
                        title: Text(ringShareField(context, key)),
                        subtitle: Text(
                          ringShareValue(context, key, row!.fields[key]!),
                        ),
                        onChanged: canEdit
                            ? (value) {
                                if (value == true) {
                                  selected.add(key);
                                } else {
                                  selected.remove(key);
                                }
                                _changed();
                              }
                            : null,
                      ),
                    TextField(
                      controller: note,
                      maxLength: 140,
                      enabled: canEdit,
                      onChanged: (_) => _changed(),
                      decoration: InputDecoration(
                        labelText: ringText(
                          context,
                          '说一句（可选）',
                          'Add a note (optional)',
                        ),
                      ),
                    ),
                    Text(ringText(context, '好友看到的内容', 'What friends will see')),
                  ],
                  if (snapshot != null && selected.isNotEmpty)
                    RingSnapshotView(snapshot: snapshot),
                  if (link == null) ...[
                    CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        ringText(
                          context,
                          '任何持链接的人都能查看所选内容。链接 7 天有效，可提前撤回。',
                          'Anyone with the link can view what is selected. The link expires after 7 days and can be revoked earlier.',
                        ),
                      ),
                      value: confirmed,
                      onChanged: canEdit
                          ? (value) => setState(() => confirmed = value == true)
                          : null,
                    ),
                    FilledButton.icon(
                      onPressed: confirmed && selected.isNotEmpty && canEdit
                          ? _publish
                          : null,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(
                        ringText(context, '生成并分享链接', 'Create and share link'),
                      ),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: () => ringSystemShare(context, link!),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(ringText(context, '分享链接', 'Share link')),
                    ),
                    OutlinedButton(
                      onPressed: () => ringCopy(context, link.toString()),
                      child: Text(ringText(context, '复制链接', 'Copy link')),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class RingMySharesPage extends StatefulWidget {
  const RingMySharesPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<RingMySharesPage> createState() => _RingMySharesPageState();
}

class _RingMySharesPageState extends State<RingMySharesPage> {
  late final String owner = widget.controller.ringExperienceOwner;
  late Future<Map<String, Object?>> entries = _list();
  bool loadingMore = false;

  Future<Map<String, Object?>> _list([String? before]) =>
      widget.controller.ringRequest(
        'GET',
        'shares',
        query: {'history': 'true', 'before': ?before},
      );

  Future<void> _more(String before, List<Map<String, Object?>> rows) async {
    if (loadingMore || owner != widget.controller.ringExperienceOwner) return;
    final current = entries;
    setState(() => loadingMore = true);
    try {
      final next = await _list(before);
      if (!mounted ||
          owner != widget.controller.ringExperienceOwner ||
          entries != current) {
        return;
      }
      final seen = rows.map((row) => row['id']).toSet();
      setState(() {
        entries = Future.value({
          ...next,
          'entries': [
            ...rows,
            for (final row in ringRows(next['entries']))
              if (seen.add(row['id'])) row,
          ],
        });
      });
    } catch (error) {
      if (mounted && owner == widget.controller.ringExperienceOwner) {
        showRingError(context, error);
      }
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> _revoke(String id) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(ringText(dialog, '撤回分享？', 'Revoke this share?')),
        content: Text(
          ringText(
            dialog,
            '好友将无法再打开这个链接。',
            'Friends will lose access to this link.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(ringText(dialog, '撤回', 'Revoke')),
          ),
        ],
      ),
    );
    if (!mounted ||
        agreed != true ||
        owner != widget.controller.ringExperienceOwner) {
      return;
    }
    try {
      await widget.controller.ringRequest('DELETE', 'shares/$id');
      if (mounted) {
        setState(() {
          entries = _list();
        });
      }
    } catch (error) {
      if (mounted) showRingError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(ringText(context, '我的分享', 'My shares'))),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => owner != widget.controller.ringExperienceOwner
          ? const SizedBox.shrink()
          : FutureBuilder(
              future: entries,
              builder: (context, result) {
                if (result.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (result.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        entries = _list();
                      }),
                      child: Text(ringText(context, '重试', 'Try again')),
                    ),
                  );
                }
                final rows = ringRows(result.data?['entries']);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (rows.isEmpty)
                      Text(ringText(context, '还没有分享记录', 'No shares yet')),
                    for (final row in rows) _shareRow(context, row),
                    if (result.data?['nextBefore'] case final String before)
                      TextButton(
                        onPressed: loadingMore
                            ? null
                            : () => _more(before, rows),
                        child: Text(
                          loadingMore
                              ? ringText(context, '正在读取…', 'Loading…')
                              : ringText(
                                  context,
                                  '查看更早的分享',
                                  'See older shares',
                                ),
                        ),
                      ),
                  ],
                );
              },
            ),
    ),
  );

  Widget _shareRow(BuildContext context, Map<String, Object?> row) {
    final expires = DateTime.tryParse('${row['expiresAt']}')?.toLocal();
    final expired = expires != null && !expires.isAfter(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (RingSnapshot.fromJson(row['snapshot']) case final snapshot?)
              Text(
                '${ringSnapshotTitle(context, snapshot.kind)} · ${MaterialLocalizations.of(context).formatMediumDate(snapshot.date)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            for (final reaction in ringRows(row['reactions']))
              ListTile(
                leading: const Icon(Icons.favorite_border),
                title: Text(
                  '${reaction['name'] ?? ringText(context, '有位朋友', 'A friend')}',
                ),
                subtitle: Text(
                  ringReactionText(context, '${reaction['kind']}'),
                ),
              ),
            if (expired)
              Text(ringText(context, '链接已过期', 'Link expired'))
            else
              TextButton(
                onPressed: () => _revoke('${row['id']}'),
                child: Text(ringText(context, '撤回链接', 'Revoke link')),
              ),
          ],
        ),
      ),
    );
  }
}

class RingNamedResponsePage extends StatefulWidget {
  const RingNamedResponsePage({
    required this.controller,
    required this.token,
    super.key,
  });
  final AppController controller;
  final String token;

  @override
  State<RingNamedResponsePage> createState() => _RingNamedResponsePageState();
}

class _RingNamedResponsePageState extends State<RingNamedResponsePage> {
  late final String owner = widget.controller.ringExperienceOwner;
  late final Future<Map<String, Object?>> _share = widget.controller
      .ringRequest('POST', 'shares/open', data: {'token': widget.token});
  bool named = false;
  bool working = false;

  Future<void> respond(String kind) async {
    if (working || owner != widget.controller.ringExperienceOwner) return;
    setState(() => working = true);
    try {
      await widget.controller.ringRequest(
        'POST',
        'shares/member-response',
        data: {'token': widget.token, 'kind': kind, 'named': named},
      );
      if (mounted && owner == widget.controller.ringExperienceOwner) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showRingError(context, error);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(ringText(context, '回应好友', 'Respond to a friend')),
    ),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (owner != widget.controller.ringExperienceOwner) {
          return const SizedBox.shrink();
        }
        return FutureBuilder(
          future: _share,
          builder: (context, result) {
            final snapshot = RingSnapshot.fromJson(result.data?['snapshot']);
            if (result.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot == null) {
              return Center(
                child: Text(ringText(context, '链接已失效', 'Link unavailable')),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RingSnapshotView(snapshot: snapshot),
                CheckboxListTile(
                  title: Text(
                    ringText(
                      context,
                      '向已关联的亲友显示我的昵称',
                      'Show my name to connected friends and family',
                    ),
                  ),
                  value: named,
                  onChanged: working
                      ? null
                      : (value) => setState(() => named = value == true),
                ),
                for (final kind in ['cheer', 'hug', 'walk'])
                  OutlinedButton(
                    onPressed: working ? null : () => respond(kind),
                    child: Text(ringReactionText(context, kind)),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}
