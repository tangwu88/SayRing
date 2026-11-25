import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models.dart';
import '../domain/ring_experience.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/ui_labels.dart';
import '../services/api_client.dart';
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
    this.canRead,
    super.key,
  });
  final AppController controller;
  final RingSnapshot? snapshot;
  final bool compact;
  final bool Function()? canRead;

  @override
  State<RingShareButton> createState() => _RingShareButtonState();
}

class _RingShareButtonState extends State<RingShareButton> {
  late final AppController _controller;
  late final String? _owner;
  bool _sharing = false;
  String? _retryToken;
  RingSnapshot? _retrySnapshot;

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

  bool get _canPresent => _canShare && ModalRoute.isCurrentOf(context) != false;

  Future<void> _share(RingSnapshot input) async {
    if (_sharing || !mounted || !_canPresent) return;
    final snapshot = RingSnapshot(
      input.kind,
      ringDate(input.date),
      Map.unmodifiable(input.fields),
      note: input.note,
    );
    final previous = _retrySnapshot;
    final sameSnapshot =
        previous != null &&
        previous.kind == snapshot.kind &&
        previous.date == snapshot.date &&
        previous.note == snapshot.note &&
        mapEquals(previous.fields, snapshot.fields);
    final token = (sameSnapshot ? _retryToken : null) ?? newRingShareToken();
    _retrySnapshot = snapshot;
    _retryToken = token;
    setState(() => _sharing = true);
    Uri? issued;
    try {
      await _controller.ringRequest(
        'POST',
        'shares',
        data: {
          'token': token,
          'confirmed': true,
          'snapshot': snapshot.toJson(),
        },
      );
      _retrySnapshot = null;
      _retryToken = null;
      if (!mounted || !_canPresent) return;
      issued = RingLink.url('share', token);
      await ringSystemShare(context, issued);
    } catch (error) {
      if (!mounted || !_canPresent) return;
      final link = issued;
      if (link == null) {
        if (error is ApiException && error.statusCode == 409) {
          _retrySnapshot = null;
          _retryToken = null;
        }
        showRingError(context, error);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ringText(context, '分享面板未打开', 'Couldn’t open sharing'),
            ),
            action: SnackBarAction(
              label: ringText(context, '复制链接', 'Copy link'),
              onPressed: () {
                if (mounted && _canPresent) ringCopy(context, link.toString());
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
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
      final onPressed = _sharing ? null : () => _share(input);
      final icon = _sharing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share_rounded);

      return widget.compact
          ? IconButton(tooltip: title, onPressed: onPressed, icon: icon)
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(title),
            );
    },
  );
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

  Future<void> _refresh() async {
    final next = _list();
    setState(() => entries = next);
    await next.then<void>((_) {}, onError: (Object _) {});
  }

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
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                  ),
                );
              },
            ),
    ),
  );

  Widget _shareRow(BuildContext context, Map<String, Object?> row) {
    final expires = DateTime.tryParse('${row['expiresAt']}')?.toLocal();
    final expired = expires != null && !expires.isAfter(DateTime.now());
    final replies = ringRows(row['reactions']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (RingSnapshot.fromJson(row['snapshot']) case final snapshot?)
              Text(
                _sharedReportTitle(context, snapshot),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (replies.firstOrNull case final reply?) _ShareReplyTile(reply),
            if (expired) Text(ringText(context, '链接已过期', 'Link expired')),
            if (row['id'] case final String id)
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RingShareRepliesPage(
                      controller: widget.controller,
                      shareId: id,
                    ),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text(ringText(context, '查看回应', 'View replies')),
              ),
          ],
        ),
      ),
    );
  }
}

String _sharedReportTitle(BuildContext context, RingSnapshot snapshot) =>
    '${ringSnapshotTitle(context, snapshot.kind)} · '
    '${MaterialLocalizations.of(context).formatMediumDate(snapshot.date)}';

class _ShareReplyTile extends StatelessWidget {
  const _ShareReplyTile(this.reply);

  final Map<String, Object?> reply;

  @override
  Widget build(BuildContext context) {
    final name = (reply['name'] as String?)?.trim() ?? '';
    final time = DateTime.tryParse('${reply['createdAt'] ?? ''}')?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.favorite_border_rounded),
      title: Text(ringReactionText(context, '${reply['kind']}')),
      subtitle: Text(
        [
          name.isEmpty ? ringText(context, '有位朋友', 'A friend') : name,
          if (time != null)
            '${localizations.formatMediumDate(time)} '
                '${TimeOfDay.fromDateTime(time).format(context)}',
        ].join(' · '),
      ),
    );
  }
}

class RingShareRepliesPage extends StatefulWidget {
  const RingShareRepliesPage({
    required this.controller,
    required this.shareId,
    super.key,
  });

  final AppController controller;
  final String shareId;

  @override
  State<RingShareRepliesPage> createState() => _RingShareRepliesPageState();
}

class _RingShareRepliesPageState extends State<RingShareRepliesPage> {
  late final String _owner = widget.controller.ringExperienceOwner;
  late Future<Map<String, Object?>> _page = _load();
  bool _loadingMore = false;

  bool get _allowed =>
      widget.controller.isAuthenticated &&
      widget.controller.ringExperienceOwner == _owner;

  Future<Map<String, Object?>> _load([String? before]) =>
      widget.controller.ringRequest(
        'GET',
        'shares/${widget.shareId}',
        query: {'before': ?before},
      );

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _page = next);
    await next.then<void>((_) {}, onError: (Object _) {});
  }

  Future<void> _more(String before, List<Map<String, Object?>> replies) async {
    if (_loadingMore || !_allowed) return;
    final current = _page;
    setState(() => _loadingMore = true);
    try {
      final next = await _load(before);
      if (!mounted || !_allowed || current != _page) return;
      setState(() {
        _page = Future.value({
          ...next,
          'reactions': [...replies, ...ringRows(next['reactions'])],
        });
      });
    } catch (error) {
      if (mounted && _allowed) showRingError(context, error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(ringText(context, '分享回应', 'Share replies'))),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => !_allowed
          ? const SizedBox.shrink()
          : FutureBuilder(
              future: _page,
              builder: (context, result) {
                if (result.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = result.data;
                final error = result.error;
                if (data == null) {
                  return Center(
                    child: error is ApiException && error.statusCode == 404
                        ? Text(
                            ringText(
                              context,
                              '这条分享暂不可查看',
                              'This share is unavailable',
                            ),
                          )
                        : TextButton(
                            onPressed: _refresh,
                            child: Text(ringText(context, '重试', 'Try again')),
                          ),
                  );
                }
                final share = data['share'];
                final snapshot = RingSnapshot.fromJson(
                  share is Map ? share['snapshot'] : null,
                );
                final replies = ringRows(data['reactions']);
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (snapshot != null)
                        Text(
                          _sharedReportTitle(context, snapshot),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      if (replies.isEmpty)
                        Text(ringText(context, '还没有好友回应', 'No replies yet')),
                      for (final reply in replies) _ShareReplyTile(reply),
                      if (data['nextBefore'] case final String before)
                        TextButton(
                          onPressed: _loadingMore
                              ? null
                              : () => _more(before, replies),
                          child: Text(
                            ringText(context, '查看更早的回应', 'See older replies'),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    ),
  );
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
