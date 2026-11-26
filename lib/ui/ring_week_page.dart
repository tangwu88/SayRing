import 'package:flutter/material.dart';

import '../domain/ring_experience.dart';
import '../domain/models.dart';
import '../services/sleep_health_projection.dart';
import '../services/app_controller.dart';
import 'ring_share_page.dart';

class RingWeekPage extends StatefulWidget {
  const RingWeekPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<RingWeekPage> createState() => _RingWeekPageState();
}

class _RingWeekPageState extends State<RingWeekPage> {
  late final String owner = widget.controller.ringExperienceOwner;
  final note = TextEditingController();
  String _shareNote = '';
  late final DateTime now = ringDate(DateTime.now());
  late final DateTime start = ringAddDays(now, 1 - now.weekday);
  late final Future<RingSnapshot?> summary = _load();

  Future<RingSnapshot?> _load() async {
    final previousStart = ringAddDays(start, -7);
    final previousEnd = ringAddDays(now, -7);
    final result = await (
      widget.controller.loadSleepDays(start: previousStart, end: now),
      widget.controller.readRingWeekNote(ringDateText(start)),
    ).wait;
    if (!mounted || owner != widget.controller.ringExperienceOwner) return null;
    note.text = result.$2;
    final sleep = <String, Map<DateTime, double>>{};
    for (final record in result.$1) {
      final date = DateTime.tryParse(sleepRecordSdkDate(record));
      final minutes = _sleepMinutes(record);
      if (date != null && minutes != null && record.deviceId.isNotEmpty) {
        sleep.putIfAbsent(record.deviceId, () => {})[date] = minutes;
      }
    }
    final comparisons =
        [
          for (final nights in sleep.values)
            (
              current: _sleepPeriod(nights, start, now),
              previous: _sleepPeriod(nights, previousStart, previousEnd),
            ),
        ]..sort(
          (a, b) => (b.current.length + b.previous.length).compareTo(
            a.current.length + a.previous.length,
          ),
        );
    for (final pair in comparisons) {
      if (pair.current.length < 3 || pair.previous.length < 3) continue;
      int average(List<double> values) =>
          (values.reduce((sum, value) => sum + value) / values.length).round();
      return RingSnapshot('week', start, {
        'rangeEnd': ringDateText(now),
        'sleepAverageMinutes': average(pair.current),
        'previousSleepAverageMinutes': average(pair.previous),
        'recordDays': pair.current.length,
      });
    }
    final latest = widget.controller.sportRecords.where((item) {
      final at = item.startedAt?.toLocal();
      return at != null &&
          !at.isAfter(DateTime.now()) &&
          !at.isBefore(previousStart) &&
          item.durationSeconds > 0;
    }).toList()..sort((a, b) => b.startedAt!.compareTo(a.startedAt!));
    final currentWorkout = latest
        .where((item) => !ringDate(item.startedAt!.toLocal()).isBefore(start))
        .toList();
    final previousWorkout = latest
        .where(
          (item) => !ringDate(item.startedAt!.toLocal()).isAfter(previousEnd),
        )
        .toList();
    int workoutDays(List<SportRecord> rows) =>
        rows.map((row) => ringDate(row.startedAt!.toLocal())).toSet().length;
    if (workoutDays(currentWorkout) >= 2 && workoutDays(previousWorkout) >= 2) {
      int minutes(List<SportRecord> rows) =>
          (rows.fold<int>(0, (sum, row) => sum + row.durationSeconds) / 60)
              .round();
      return RingSnapshot('week', start, {
        'rangeEnd': ringDateText(now),
        'sportMinutes': minutes(currentWorkout),
        'previousSportMinutes': minutes(previousWorkout),
        'recordDays': workoutDays(currentWorkout),
      });
    }
    if (currentWorkout.firstOrNull case final workout?) {
      final data = ringWorkoutSnapshot(context, workout);
      if (data != null) {
        return RingSnapshot('week', data.date, {
          for (final entry in data.fields.entries)
            if (entry.key != 'heartRate') entry.key: entry.value,
        });
      }
    }
    for (final row in result.$1.reversed) {
      final minutes = _sleepMinutes(row);
      final date =
          DateTime.tryParse(sleepRecordSdkDate(row)) ??
          row.measuredAt.toLocal();
      if (minutes == null ||
          ringDate(date).isBefore(start) ||
          ringDate(date).isAfter(now)) {
        continue;
      }
      return RingSnapshot('week', date, {'sleepMinutes': minutes.round()});
    }
    return null;
  }

  List<double> _sleepPeriod(
    Map<DateTime, double> nights,
    DateTime first,
    DateTime last,
  ) => [
    for (final row in nights.entries)
      if (!row.key.isBefore(first) && !row.key.isAfter(last)) row.value,
  ];

  double? _sleepMinutes(HealthRecord row) {
    final timeline = row.sleepTimeline;
    final minutes = timeline?.hasSegments == true
        ? timeline!.asleepMinutes
        : (row.values['value']?.toDouble() ?? 0) * 60;
    return minutes.isFinite && minutes > 0 && minutes <= 1440 ? minutes : null;
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(ringText(context, '我的这一周', 'My week'))),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => owner != widget.controller.ringExperienceOwner
          ? const SizedBox.shrink()
          : FutureBuilder(
              future: summary,
              builder: (context, result) {
                if (result.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final display = result.data;
                if (display == null) {
                  return Center(
                    child: Text(
                      ringText(
                        context,
                        '本周暂无可回顾的记录',
                        'Nothing to look back on this week yet',
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    RingSnapshotView(snapshot: display),
                    TextField(
                      maxLength: 140,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) =>
                          setState(() => _shareNote = value.trim()),
                      decoration: InputDecoration(
                        labelText: ringText(
                          context,
                          '给好友的附言（选填）',
                          'A note for your friend (optional)',
                        ),
                      ),
                    ),
                    RingShareButton(
                      controller: widget.controller,
                      snapshot: RingSnapshot(
                        display.kind,
                        display.date,
                        display.fields,
                        note: _shareNote,
                      ),
                    ),
                    ExpansionTile(
                      title: Text(ringText(context, '私人笔记', 'Private note')),
                      children: [
                        TextField(
                          controller: note,
                          maxLength: 140,
                          decoration: InputDecoration(
                            labelText: ringText(
                              context,
                              '留一句话给自己',
                              'Leave a note for yourself',
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final savedLabel = ringText(
                              context,
                              '已保存',
                              'Saved',
                            );
                            await widget.controller.writeRingWeekNote(
                              ringDateText(start),
                              note.text.trim(),
                            );
                            if (mounted &&
                                owner ==
                                    widget.controller.ringExperienceOwner) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(savedLabel)),
                              );
                            }
                          },
                          child: Text(
                            ringText(context, '保存私人卡片', 'Save private card'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    ),
  );
}
