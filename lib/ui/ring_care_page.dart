import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/ring_experience.dart';
import '../services/api_client.dart';
import '../services/app_controller.dart';
import 'ring_share_page.dart';

class RingInvitationsPage extends StatefulWidget {
  const RingInvitationsPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<RingInvitationsPage> createState() => _RingInvitationsPageState();
}

class _RingInvitationsPageState extends State<RingInvitationsPage> {
  late final String owner = widget.controller.ringExperienceOwner;
  final _code = TextEditingController();
  late Future<Map<String, Object?>> invitations = widget.controller.ringRequest(
    'GET',
    'care/invitations',
  );
  final links = <String, Uri>{};
  bool busy = false;

  bool get _canPresent =>
      mounted &&
      widget.controller.isAuthenticated &&
      owner == widget.controller.ringExperienceOwner &&
      ModalRoute.isCurrentOf(context) != false;

  Future<void> _shareInvitation(Uri link) async {
    try {
      await ringShareLink(
        context,
        widget.controller,
        link,
        title: ringText(
          context,
          'Say Ring · 远程关爱邀请',
          'Say Ring · Care invitation',
        ),
        description: ringText(
          context,
          '邀请你加入远程关爱，由你选择共享内容',
          'Join remote care and choose what you share',
        ),
        canPresent: () => _canPresent,
      );
    } catch (error) {
      if (mounted && _canPresent) {
        showRingShareError(context, error, link, canPresent: () => _canPresent);
      }
    }
  }

  Future<void> _reshare(String id) async {
    final link = links[id];
    if (busy || !_canPresent || link == null) return;
    setState(() => busy = true);
    try {
      await _shareInvitation(link);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (busy || !_canPresent) return;
    setState(() => busy = true);
    try {
      final entry = await widget.controller.ringRequest(
        'POST',
        'care/invitations',
      );
      final code = RingLink.invitationCode('${entry['code']}');
      if (!mounted ||
          code == null ||
          owner != widget.controller.ringExperienceOwner) {
        return;
      }
      final link = RingLink.url('invite', code);
      setState(() {
        links['${entry['id']}'] = link;
        invitations = widget.controller.ringRequest('GET', 'care/invitations');
      });
      await _shareInvitation(link);
    } catch (error) {
      if (mounted && _canPresent) showRingError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancel(String id) async {
    try {
      await widget.controller.ringRequest('DELETE', 'care/invitations/$id');
      if (mounted && owner == widget.controller.ringExperienceOwner) {
        setState(() {
          links.remove(id);
          invitations = widget.controller.ringRequest(
            'GET',
            'care/invitations',
          );
        });
      }
    } catch (error) {
      if (mounted) showRingError(context, error);
    }
  }

  void _openCode() {
    final code = RingLink.invitationCode(_code.text);
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ringText(context, '请检查邀请码', 'Check the invitation code'),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RingAcceptInvitePage(controller: widget.controller, code: code),
      ),
    );
  }

  String _expiry(BuildContext context, Object? raw) {
    final date = DateTime.tryParse('$raw');
    return date == null
        ? ''
        : MaterialLocalizations.of(context).formatShortDate(date.toLocal());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(ringText(context, '邀请亲友', 'Invite a friend'))),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => owner != widget.controller.ringExperienceOwner
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  ringText(context, '我想关心对方', 'I want to check in on someone'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  ringText(
                    context,
                    '邀请可使用一次，48 小时有效。对方可以选择共享哪些指标。',
                    'The link works once and expires after 48 hours. Your friend chooses what to share.',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : _create,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(
                    ringText(context, '分享邀请链接', 'Share invitation link'),
                  ),
                ),
                FutureBuilder(
                  future: invitations,
                  builder: (context, result) => Column(
                    children: [
                      if (result.hasError)
                        TextButton(
                          onPressed: () => setState(() {
                            invitations = widget.controller.ringRequest(
                              'GET',
                              'care/invitations',
                            );
                          }),
                          child: Text(
                            ringText(context, '重新加载邀请', 'Reload invitations'),
                          ),
                        ),
                      for (final row in ringRows(result.data?['entries']))
                        ListTile(
                          title: Text(
                            ringText(
                              context,
                              '等待好友接受',
                              'Waiting for your friend',
                            ),
                          ),
                          subtitle: Text(_expiry(context, row['expiresAt'])),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'share') {
                                unawaited(_reshare('${row['id']}'));
                              }
                              if (action == 'cancel') {
                                unawaited(_cancel('${row['id']}'));
                              }
                            },
                            itemBuilder: (_) => [
                              if (links.containsKey(row['id']))
                                PopupMenuItem(
                                  value: 'share',
                                  enabled: !busy,
                                  child: Text(
                                    ringText(
                                      context,
                                      '分享邀请',
                                      'Share invitation',
                                    ),
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'cancel',
                                child: Text(
                                  ringText(
                                    context,
                                    '撤销邀请',
                                    'Cancel invitation',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 36),
                TextField(
                  controller: _code,
                  maxLength: 28,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _openCode(),
                  decoration: InputDecoration(
                    labelText: ringText(
                      context,
                      '已有邀请码',
                      'Enter an invitation code',
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _openCode,
                  child: Text(ringText(context, '查看邀请', 'Review invitation')),
                ),
              ],
            ),
    ),
  );
}

class RingAcceptInvitePage extends StatefulWidget {
  const RingAcceptInvitePage({
    required this.controller,
    required this.code,
    super.key,
  });
  final AppController controller;
  final String code;
  @override
  State<RingAcceptInvitePage> createState() => _RingAcceptInvitePageState();
}

class _RingAcceptInvitePageState extends State<RingAcceptInvitePage> {
  late final String owner = widget.controller.ringExperienceOwner;
  late Future<Map<String, Object?>> preview = _loadPreview();
  Future<Map<String, Object?>> _loadPreview() => widget.controller.ringRequest(
    'POST',
    'care/invitations/preview',
    data: {'code': widget.code},
  );
  final selected = <String>{};
  bool busy = false;

  Future<void> accept() async {
    if (busy || owner != widget.controller.ringExperienceOwner) return;
    setState(() => busy = true);
    try {
      final result = await widget.controller.ringRequest(
        'POST',
        'care/invitations/accept',
        data: {
          'code': widget.code,
          'confirmed': true,
          'metrics': selected.toList(),
        },
      );
      if (!mounted || owner != widget.controller.ringExperienceOwner) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RingCareThreadPage(
            controller: widget.controller,
            relationshipId: '${result['relationshipId']}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) showRingError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(ringText(context, '远程爱邀请', 'Care invitation'))),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (owner != widget.controller.ringExperienceOwner) {
          return const SizedBox.shrink();
        }
        return FutureBuilder(
          future: preview,
          builder: (context, result) {
            if (result.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (result.hasError) {
              final error = result.error;
              if (error is! ApiException || error.statusCode != 404) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      preview = _loadPreview();
                    }),
                    child: Text(
                      ringText(context, '重新读取邀请', 'Retry invitation'),
                    ),
                  ),
                );
              }
              return Center(
                child: Text(
                  ringText(
                    context,
                    '邀请已失效',
                    'Invitation expired or unavailable',
                  ),
                ),
              );
            }
            final name =
                result.data?['inviterName'] ??
                ringText(context, '一位亲友', 'A friend');
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  ringText(
                    context,
                    '$name 想关心你',
                    '$name wants to check in on you',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  ringText(
                    context,
                    '可以先互相问候。愿意分享的健康指标由你选择。',
                    'You can start by saying hello. You choose which health metrics to share.',
                  ),
                ),
                const SizedBox(height: 12),
                for (final (metric, zh, en) in const [
                  (HealthMetric.steps, '步数', 'Steps'),
                  (HealthMetric.sleep, '睡眠', 'Sleep'),
                  (HealthMetric.distance, '距离', 'Distance'),
                  (HealthMetric.heartRate, '心率', 'Heart rate'),
                  (HealthMetric.bloodOxygen, '血氧', 'Blood oxygen'),
                  (HealthMetric.bloodPressure, '血压', 'Blood pressure'),
                  (HealthMetric.hrv, '心率变异性', 'HRV'),
                  (HealthMetric.bodyTemperature, '皮肤温度', 'Skin temperature'),
                ])
                  if (widget.controller.isMetricAvailableInRelease(metric))
                    CheckboxListTile(
                      title: Text(ringText(context, zh, en)),
                      value: selected.contains(metric.wireName),
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                selected.add(metric.wireName);
                              } else {
                                selected.remove(metric.wireName);
                              }
                            }),
                    ),
                FilledButton(
                  onPressed: busy ? null : accept,
                  child: Text(ringText(context, '接受邀请', 'Accept invitation')),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class RingCareThreadPage extends StatefulWidget {
  const RingCareThreadPage({
    required this.controller,
    required this.relationshipId,
    this.name,
    super.key,
  });
  final AppController controller;
  final String relationshipId;
  final String? name;

  @override
  State<RingCareThreadPage> createState() => _RingCareThreadPageState();
}

class _RingCareThreadPageState extends State<RingCareThreadPage>
    with WidgetsBindingObserver {
  late final String owner = widget.controller.ringExperienceOwner;
  String get path => 'care/${widget.relationshipId}';
  final player = AudioPlayer();
  Timer? poll;
  Map<String, Object?>? thread;
  Map<String, Object?>? goal;
  List<Map<String, Object?>> older = [];
  bool failed = false;
  bool loading = false;
  bool fetchingOlder = false;
  bool sending = false;
  final Set<String> _reporting = {};
  final Set<String> _reported = {};
  bool quiet = false;
  bool haptic = false;
  bool lastPage = false;
  String? playing;
  Map<String, Object?>? _pendingSend;
  StreamSubscription<void>? _playback;

  bool get current => mounted && owner == widget.controller.ringExperienceOwner;
  bool get blocked => thread?['blocked'] == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_changedAccount);
    _playback = player.onPlayerComplete.listen((_) {
      if (current) setState(() => playing = null);
    });
    unawaited(_reload());
    unawaited(
      widget.controller
          .ringHapticPreference()
          .then<void>((value) {
            if (current) setState(() => haptic = value);
          })
          .catchError((Object _) {}),
    );
    _startPolling();
  }

  void _changedAccount() {
    if (!current) {
      poll?.cancel();
      unawaited(player.stop());
    }
    if (mounted) setState(() {});
  }

  void _startPolling() {
    poll?.cancel();
    poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (current && ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_reload());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && current) {
      _startPolling();
      unawaited(_reload());
    } else if (state != AppLifecycleState.resumed) {
      poll?.cancel();
      unawaited(player.stop());
      if (current) setState(() => playing = null);
    }
  }

  @override
  void dispose() {
    poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_changedAccount);
    unawaited(_playback?.cancel());
    unawaited(player.dispose());
    super.dispose();
  }

  Future<void> _reload() async {
    if (!current || loading) return;
    loading = true;
    try {
      final messages = await widget.controller.ringRequest(
        'GET',
        '$path/messages',
      );
      if (!current) return;
      Map<String, Object?>? plan;
      if (messages['blocked'] != true) {
        try {
          plan = await widget.controller.ringRequest('GET', '$path/goals');
        } catch (_) {}
      }
      if (!current) return;
      final ids = ringRows(
        messages['messages'],
      ).map((row) => row['id']).toSet();
      if (messages['blocked'] == true) unawaited(player.stop());
      setState(() {
        failed = false;
        thread = messages;
        goal = plan;
        older.removeWhere((row) => ids.contains(row['id']));
        if (blocked) {
          older.clear();
          playing = null;
        }
      });
    } catch (_) {
      if (current) {
        unawaited(player.stop());
        setState(() {
          failed = true;
          thread = null;
          goal = null;
          older.clear();
          playing = null;
        });
      }
    } finally {
      loading = false;
    }
  }

  Future<void> _loadOlder(String before) async {
    if (!current || fetchingOlder) return;
    setState(() => fetchingOlder = true);
    try {
      final result = await widget.controller.ringRequest(
        'GET',
        '$path/messages',
        query: {'before': before},
      );
      if (!current) return;
      final rows = ringRows(result['messages']);
      setState(() {
        older.addAll(rows);
        lastPage = rows.length < 40;
      });
    } catch (error) {
      if (mounted && current) showRingError(context, error);
    } finally {
      if (current) setState(() => fetchingOlder = false);
    }
  }

  Future<void> _send(String kind, {String? audio, RingSnapshot? attachment}) =>
      _post({
        'messageId': const Uuid().v4(),
        'kind': kind,
        'keepQuiet': quiet,
        'audio': ?audio,
        if (attachment != null) 'attachment': attachment.toJson(),
      });

  Future<void> _post(Map<String, Object?> data) async {
    if (!current || sending || blocked) return;
    setState(() => sending = true);
    try {
      final first = await widget.controller.ringRequest(
        'POST',
        '$path/messages',
        data: data,
      );
      if (!current) return;
      setState(() {
        _pendingSend = null;
        thread = {
          ...?thread,
          'messages': [
            first,
            ...ringRows(
              thread?['messages'],
            ).where((row) => row['id'] != first['id']),
          ],
        };
      });
      await _reload();
    } catch (error) {
      if (mounted && current) {
        setState(() => _pendingSend = data);
        showRingError(context, error);
      }
    } finally {
      if (current) setState(() => sending = false);
    }
  }

  Future<void> _voice() async {
    final bytes = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _VoiceDialog(),
    );
    if (current && bytes != null) await _send('voice', audio: bytes);
  }

  Future<void> _play(String id) async {
    if (!current || blocked) return;
    try {
      if (playing == id) {
        await player.stop();
        if (current) setState(() => playing = null);
        return;
      }
      final bytes = await widget.controller.ringFile(
        '$path/messages/$id/audio',
        960044,
      );
      if (!mounted ||
          !current ||
          blocked ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
      if (current) setState(() => playing = id);
    } catch (error) {
      if (mounted && current) showRingError(context, error);
    }
  }

  Future<void> _modify(
    String method,
    String suffix, {
    Map<String, Object?>? data,
  }) async {
    if (!current) return;
    try {
      await widget.controller.ringRequest(method, '$path/$suffix', data: data);
      if (current) {
        older.clear();
        await _reload();
      }
    } catch (error) {
      if (mounted && current) showRingError(context, error);
    }
  }

  Future<void> _report(String id) async {
    if (!current || _reporting.contains(id) || _reported.contains(id)) return;
    setState(() => _reporting.add(id));
    try {
      await widget.controller.ringRequest('POST', '$path/messages/$id/report');
      if (!mounted || !current) return;
      setState(() => _reported.add(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ringText(context, '举报已提交，我们会尽快处理', 'Report submitted for review'),
          ),
        ),
      );
    } catch (error) {
      if (mounted && current) showRingError(context, error);
    } finally {
      if (current) setState(() => _reporting.remove(id));
    }
  }

  Future<void> _walked() async {
    final today = ringDateText(DateTime.now());
    final known = widget.controller.sportRecords
        .where(
          (row) =>
              row.mode == SportMode.walking &&
              row.startedAt != null &&
              ringDateText(row.startedAt!.toLocal()) == today &&
              row.durationSeconds > 0,
        )
        .firstOrNull;
    if (known == null) {
      await _send('walked');
      return;
    }
    final attachment = ringWorkoutSnapshot(context, known);
    final include = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(ringText(dialog, '附上本次散步记录？', 'Include this walk?')),
        content: attachment == null
            ? null
            : RingSnapshotView(snapshot: attachment),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(ringText(dialog, '只报近况', 'Just check in')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(ringText(dialog, '附上记录', 'Include walk')),
          ),
        ],
      ),
    );
    if (include != null && current) {
      await _send('walked', attachment: include ? attachment : null);
    }
  }

  Future<void> _setTarget() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(
          ringText(
            dialog,
            '这周想散步几天？',
            'How many days would you like to walk this week?',
          ),
        ),
        children: [
          for (var count = 1; count <= 7; count++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, count),
              child: Text(ringText(dialog, '$count 天', '$count days')),
            ),
        ],
      ),
    );
    if (selected != null && current) {
      await _modify(
        'PUT',
        'goals',
        data: {'week': goal?['week'], 'target': selected},
      );
    }
  }

  Widget _goal(BuildContext context) {
    final members = ringRows(goal?['members']);
    final mine = members.where((row) => row['mine'] == true).firstOrNull;
    final other = members.where((row) => row['mine'] != true).firstOrNull;
    final today = goal?['today'];
    final mayUseWorkout = goal?['activityAvailable'] == true;
    return Card(
      child: ExpansionTile(
        title: Text(ringText(context, '我们的小约定', 'Our walking plan')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (mine != null)
            Text(
              ringText(
                context,
                '我 · ${mine['completed']}/${mine['target']} 天',
                'Me · ${mine['completed']}/${mine['target']} days',
              ),
            ),
          if (other != null)
            Text(
              ringText(
                context,
                '亲友 · ${other['completed']}/${other['target']} 天',
                'Friend · ${other['completed']}/${other['target']} days',
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _setTarget,
                child: Text(ringText(context, '选择目标', 'Choose goal')),
              ),
              if (mine != null)
                OutlinedButton(
                  onPressed: () => _modify(
                    'PUT',
                    'goals',
                    data: {
                      'week': goal?['week'],
                      'paused': mine['paused'] != true,
                    },
                  ),
                  child: Text(
                    mine['paused'] == true
                        ? ringText(context, '继续', 'Resume')
                        : ringText(context, '暂停', 'Pause'),
                  ),
                ),
              if (mine != null &&
                  mine['paused'] != true &&
                  mine['checkedToday'] != true)
                FilledButton(
                  onPressed: () => _modify(
                    'PUT',
                    'goals',
                    data: {
                      'week': goal?['week'],
                      'day': today,
                      'source': 'manual',
                    },
                  ),
                  child: Text(ringText(context, '今天已散步', 'I walked today')),
                ),
              if (mine != null &&
                  mine['paused'] != true &&
                  mine['checkedToday'] != true &&
                  mayUseWorkout)
                OutlinedButton(
                  onPressed: () => _modify(
                    'PUT',
                    'goals',
                    data: {
                      'week': goal?['week'],
                      'day': today,
                      'source': 'workout',
                    },
                  ),
                  child: Text(
                    ringText(
                      context,
                      '用今天已同步的活动打卡',
                      'Use today’s synced activity',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _messageLabel(BuildContext context, String kind) => switch (kind) {
    'thinkingBack' => ringText(context, '我也想你', 'Thinking of you too'),
    'walked' => ringText(context, '刚散完步', 'Just finished a walk'),
    'resting' => ringText(context, '今天想歇歇', 'Taking it easy today'),
    'call' => ringText(context, '有空给我打电话', 'Call me when you have time'),
    'voice' => ringText(context, '语音祝福', 'Voice greeting'),
    _ => ringText(context, '想你了', 'Thinking of you'),
  };

  @override
  Widget build(BuildContext context) {
    final muted = thread?['muted'] == true;
    final rows = [...ringRows(thread?['messages']), ...older];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name ?? ringText(context, '远程爱', 'Care')),
        actions: [
          if (current && thread != null)
            PopupMenuButton<String>(
              onSelected: (choice) async {
                if (choice == 'mute') {
                  await _modify('PUT', 'settings', data: {'muted': !muted});
                }
                if (choice == 'block') {
                  await _modify('PUT', 'settings', data: {'blocked': !blocked});
                }
              },
              itemBuilder: (_) => [
                if (!blocked)
                  PopupMenuItem(
                    value: 'mute',
                    child: Text(
                      muted
                          ? ringText(context, '取消静音', 'Unmute')
                          : ringText(context, '静音', 'Mute'),
                    ),
                  ),
                PopupMenuItem(
                  value: 'block',
                  child: Text(
                    blocked
                        ? ringText(context, '解除屏蔽', 'Unblock')
                        : ringText(context, '屏蔽此亲友', 'Block this person'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: !current
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (failed)
                    TextButton(
                      onPressed: _reload,
                      child: Text(ringText(context, '重新加载', 'Try again')),
                    )
                  else if (thread == null)
                    const Center(child: CircularProgressIndicator())
                  else if (blocked)
                    Text(
                      ringText(context, '已屏蔽此亲友。', 'This person is blocked.'),
                    )
                  else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final kind in [
                          'thinking',
                          'thinkingBack',
                          'resting',
                          'call',
                          'voice',
                        ])
                          OutlinedButton(
                            onPressed: sending
                                ? null
                                : (kind == 'voice'
                                      ? _voice
                                      : () => _send(kind)),
                            child: Text(_messageLabel(context, kind)),
                          ),
                        OutlinedButton(
                          onPressed: sending ? null : _walked,
                          child: Text(_messageLabel(context, 'walked')),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: quiet,
                      onChanged: sending
                          ? null
                          : (value) => setState(() => quiet = value == true),
                      title: Text(
                        ringText(context, '不用特意回', 'No need to reply'),
                      ),
                    ),
                    if (_pendingSend != null)
                      TextButton(
                        onPressed: sending ? null : () => _post(_pendingSend!),
                        child: Text(ringText(context, '重试发送', 'Retry sending')),
                      ),
                    if (widget.controller.ringCanReceiveHaptic || haptic)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ringText(context, '戒指轻振', 'Ring haptic')),
                        subtitle: Text(
                          ringText(
                            context,
                            '夜间 22:00–08:00 仅收消息',
                            'Inbox only from 10 PM to 8 AM',
                          ),
                        ),
                        value: haptic,
                        onChanged:
                            widget.controller.ringCanReceiveHaptic || haptic
                            ? (value) async {
                                await widget.controller
                                    .saveRingHapticPreference(value);
                                if (current) setState(() => haptic = value);
                              }
                            : null,
                      ),
                    if (goal != null) _goal(context),
                    for (final row in rows)
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                row['mine'] == true
                                    ? Icons.north_east
                                    : Icons.favorite_border,
                              ),
                              title: Text(
                                _messageLabel(context, '${row['kind']}'),
                              ),
                              subtitle: Text(
                                [
                                  if (row['mine'] == true)
                                    ringText(context, '我', 'Me')
                                  else
                                    (widget.name ??
                                        ringText(context, '亲友', 'Friend')),
                                  if (DateTime.tryParse('${row['createdAt']}')
                                      case final date?)
                                    '${MaterialLocalizations.of(context).formatShortDate(date.toLocal())} ${ringClockText(date.toLocal())}',
                                  if (row['keepQuiet'] == true)
                                    ringText(
                                      context,
                                      '不用特意回',
                                      'No need to reply',
                                    ),
                                ].join(' · '),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) => action == 'report'
                                    ? _report('${row['id']}')
                                    : _modify(
                                        'DELETE',
                                        'messages/${row['id']}',
                                      ),
                                itemBuilder: (_) => row['mine'] == true
                                    ? [
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            ringText(context, '删除', 'Delete'),
                                          ),
                                        ),
                                      ]
                                    : [
                                        PopupMenuItem(
                                          value: 'report',
                                          enabled:
                                              !_reporting.contains(
                                                '${row['id']}',
                                              ) &&
                                              !_reported.contains(
                                                '${row['id']}',
                                              ),
                                          child: Text(
                                            _reported.contains('${row['id']}')
                                                ? ringText(
                                                    context,
                                                    '已举报',
                                                    'Reported',
                                                  )
                                                : ringText(
                                                    context,
                                                    '举报',
                                                    'Report',
                                                  ),
                                          ),
                                        ),
                                      ],
                              ),
                            ),
                            if (row['kind'] == 'voice')
                              TextButton.icon(
                                onPressed: () => _play('${row['id']}'),
                                icon: Icon(
                                  playing == row['id']
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                ),
                                label: Text(
                                  playing == row['id']
                                      ? ringText(context, '停止', 'Stop')
                                      : ringText(context, '播放', 'Play'),
                                ),
                              ),
                            if (RingSnapshot.fromJson(row['attachment'])
                                case final attachment?)
                              RingSnapshotView(snapshot: attachment),
                          ],
                        ),
                      ),
                    if (!lastPage && rows.length >= 40)
                      TextButton(
                        onPressed: fetchingOlder
                            ? null
                            : () => _loadOlder('${rows.last['id']}'),
                        child: Text(
                          ringText(context, '更早的消息', 'Earlier messages'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _VoiceDialog extends StatefulWidget {
  const _VoiceDialog();
  @override
  State<_VoiceDialog> createState() => _VoiceDialogState();
}

class _VoiceDialogState extends State<_VoiceDialog>
    with WidgetsBindingObserver {
  final recorder = AudioRecorder();
  Timer? limit;
  String? path;
  String? clip;
  bool recording = false;
  bool pending = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && recording) unawaited(_stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    limit?.cancel();
    unawaited(_disposeRecorder());
    super.dispose();
  }

  Future<void> _disposeRecorder() async {
    try {
      await recorder.dispose();
    } catch (_) {}
    if (path case final temp?) {
      try {
        await File(temp).delete();
      } catch (_) {}
    }
  }

  Future<void> _start() async {
    setState(() {
      pending = true;
      failed = false;
      clip = null;
    });
    try {
      if (!await recorder.hasPermission()) {
        if (mounted) setState(() => failed = true);
        return;
      }
      if (!mounted) return;
      final dir = await getTemporaryDirectory();
      if (!mounted) return;
      path = '${dir.path}/ring-voice-${const Uuid().v4()}.wav';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path!,
      );
      if (!mounted) return;
      setState(() => recording = true);
      limit = Timer(
        const Duration(milliseconds: 9500),
        () => unawaited(_stop()),
      );
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  Future<void> _stop() async {
    if (!recording || pending) return;
    limit?.cancel();
    setState(() {
      pending = true;
      recording = false;
    });
    try {
      final source = await recorder.stop();
      if (source != null) {
        final file = File(source);
        try {
          final length = await file.length();
          if (length > 44 && length <= 960044) {
            final value = base64Encode(await file.readAsBytes());
            if (mounted) setState(() => clip = value);
          }
        } finally {
          await file.delete();
        }
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) {
        setState(() {
          pending = false;
          failed = clip == null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !pending,
    child: AlertDialog(
      title: Text(ringText(context, '语音祝福', 'Voice greeting')),
      content: Text(
        failed
            ? ringText(
                context,
                '录音失败，请检查麦克风权限。',
                'Could not record. Check microphone access.',
              )
            : recording
            ? ringText(context, '录音中，最多 10 秒', 'Recording, up to 10 seconds')
            : clip != null
            ? ringText(
                context,
                '录音完成，可发送给亲友。',
                'Your recording is ready to send.',
              )
            : ringText(
                context,
                '录一句想对亲友说的话。',
                'Record a short message for your friend.',
              ),
      ),
      actions: [
        TextButton(
          onPressed: pending ? null : () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        if (clip == null)
          FilledButton(
            onPressed: pending ? null : (recording ? _stop : _start),
            child: Text(
              recording
                  ? ringText(context, '结束录音', 'Finish recording')
                  : ringText(context, '开始录音', 'Record'),
            ),
          ),
        if (clip != null)
          FilledButton(
            onPressed: () => Navigator.pop(context, clip),
            child: Text(ringText(context, '发送', 'Send')),
          ),
      ],
    ),
  );
}
