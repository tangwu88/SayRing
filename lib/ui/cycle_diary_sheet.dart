import 'package:flutter/material.dart';
import '../domain/cycle_tracking.dart';
import 'cycle_day_widgets.dart';

const cycleFields = [
  ('flow', '经量', Icons.water_drop_outlined),
  ('pain', '疼痛', Icons.bolt_outlined),
  ('mood', '心情', Icons.sentiment_satisfied_alt),
  ('fatigue', '疲劳', Icons.battery_4_bar_rounded),
];

List<String> diarySummary(Map<String, Object?> data) => [
  for (final f in cycleFields)
    if (cycleFeelingChoices[f.$1]?[data[f.$1]] case final String value)
      value == '无' ? '无${f.$2}' : '${f.$2}$value',
  for (final k in (data['symptoms'] as List? ?? const []))
    if (cycleSymptomLabels[k] case final String label) label,
  for (final k in (data['tags'] as List? ?? const []))
    if (cycleTagLabels[k] case final String label) label,
];

class CycleDiarySheet extends StatefulWidget {
  const CycleDiarySheet({required this.date, required this.initial, super.key});
  final String date;
  final Map<String, Object?> initial;
  @override
  State<CycleDiarySheet> createState() => _CycleDiarySheetState();
}

class _CycleDiarySheetState extends State<CycleDiarySheet> {
  late final data = <String, Object?>{...widget.initial, 'date': widget.date};
  // 列表只按需复制；在面板内取消或向下滑关闭不修改保存的记录。
  void multi(String field, String value, bool on) {
    setState(() {
      final selected = List<String>.from(data[field] as List? ?? const []);
      on ? selected.add(value) : selected.remove(value);
      if (selected.isEmpty && !widget.initial.containsKey(field)) {
        data.remove(field);
      } else {
        data[field] = selected;
      }
    });
  }

  Widget group(String title, IconData icon, List<Widget> choices) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: cyclePlum, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 7, runSpacing: 2, children: choices),
      ],
    ),
  );
  Widget multiChip(String field, String key, String label) => FilterChip(
    selected: (data[field] as List? ?? const []).contains(key),
    showCheckmark: true,
    label: Text(label),
    onSelected: (v) => multi(field, key, v),
  );
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${cycleShort(widget.date)} · 记感受',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 21,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '取消',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              children: [
                for (final f in cycleFields)
                  group(f.$2, f.$3, [
                    for (final v in cycleFeelingChoices[f.$1]!.entries)
                      ChoiceChip(
                        key: ValueKey('diary-${f.$1}-${v.key}'),
                        selected: data[f.$1] == v.key,
                        showCheckmark: true,
                        label: Text(v.value),
                        onSelected: (on) => setState(() {
                          if (on) {
                            data[f.$1] = v.key;
                          } else {
                            data.remove(f.$1);
                          }
                        }),
                      ),
                  ]),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('更多感受'),
                  initiallyExpanded:
                      (widget.initial['symptoms'] as List? ?? const [])
                          .isNotEmpty ||
                      (widget.initial['tags'] as List? ?? const []).isNotEmpty,
                  leading: const Icon(
                    Icons.add_circle_outline,
                    color: cyclePlum,
                  ),
                  children: [
                    group('身体感受', Icons.spa_outlined, [
                      for (final e in cycleSymptomLabels.entries)
                        multiChip('symptoms', e.key, e.value),
                    ]),
                    group('生活标记', Icons.bookmark_outline, [
                      for (final e in cycleTagLabels.entries)
                        multiChip('tags', e.key, e.value),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: FilledButton.icon(
              key: const Key('diary-save'),
              onPressed: () => Navigator.pop(context, data),
              icon: const Icon(Icons.check),
              label: const Text('保存'),
            ),
          ),
        ],
      ),
    ),
  );
}
