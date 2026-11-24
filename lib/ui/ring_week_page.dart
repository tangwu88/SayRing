import 'package:flutter/material.dart';

import '../domain/ring_experience.dart';
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
  late final DateTime now = ringDate(DateTime.now());
  late final DateTime start = ringAddDays(now, 1 - now.weekday);
  late final Future<RingSnapshot?> summary = _load();

  Future<RingSnapshot?> _load() async {
    final result = await (
      widget.controller.loadSleepDays(start: start, end: now),
      widget.controller.readRingWeekNote(ringDateText(start)),
    ).wait;
    if (!mounted || owner != widget.controller.ringExperienceOwner) return null;
    note.text = result.$2;
    final latest = widget.controller.sportRecords.where((item) {
      final at = item.startedAt?.toLocal();
      return at != null &&
          !at.isBefore(start) &&
          !at.isAfter(DateTime.now()) &&
          item.durationSeconds > 0;
    }).toList()..sort((a, b) => b.startedAt!.compareTo(a.startedAt!));
    if (latest.firstOrNull case final workout?) {
      final data = ringWorkoutSnapshot(context, workout);
      if (data != null) {
        return RingSnapshot('week', data.date, {
          for (final entry in data.fields.entries)
            if (entry.key != 'heartRate') entry.key: entry.value,
        });
      }
    }
    final sleep = result.$1.reversed;
    for (final row in sleep) {
      final timeline = row.sleepTimeline;
      final minutes = timeline?.hasSegments == true
          ? timeline!.asleepMinutes
          : (row.values['value'] ?? 0) * 60;
      if (!minutes.isFinite || minutes <= 0 || minutes > 1440) continue;
      final date =
          DateTime.tryParse(sleepRecordSdkDate(row)) ??
          row.measuredAt.toLocal();
      return RingSnapshot('week', date, {'sleepMinutes': minutes.round()});
    }
    return null;
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
                      controller: note,
                      maxLength: 140,
                      onChanged: (_) => setState(() {}),
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
                        final savedLabel = ringText(context, '已保存', 'Saved');
                        await widget.controller.writeRingWeekNote(
                          ringDateText(start),
                          note.text.trim(),
                        );
                        if (mounted &&
                            owner == widget.controller.ringExperienceOwner) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(savedLabel)),
                          );
                        }
                      },
                      child: Text(
                        ringText(context, '保存私人卡片', 'Save private card'),
                      ),
                    ),
                    RingShareButton(
                      controller: widget.controller,
                      snapshot: RingSnapshot(
                        display.kind,
                        display.date,
                        display.fields,
                        note: note.text.trim(),
                      ),
                    ),
                  ],
                );
              },
            ),
    ),
  );
}
