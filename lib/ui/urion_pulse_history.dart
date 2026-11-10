import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/urion_pulse_record.dart';

class UrionPulseHistory extends StatefulWidget {
  const UrionPulseHistory({required this.records, super.key});
  final List<UrionPulseRecord> records;

  @override
  State<UrionPulseHistory> createState() => _UrionPulseHistoryState();
}

class _UrionPulseHistoryState extends State<UrionPulseHistory> {
  int? _days;
  int _visible = 20;
  String _copy(String en, String zh) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  // Use only real samples and preserve each series' extrema in large histories.
  List<UrionPulseRecord> _plotSamples(List<UrionPulseRecord> records) {
    if (records.length <= 400) return records;
    final selected = <int>{0, records.length - 1};
    final size = (records.length / 60).ceil();
    for (var start = 0; start < records.length; start += size) {
      final end = (start + size).clamp(0, records.length);
      for (final field in <int Function(UrionPulseRecord)>[
        (r) => r.bloodStasis,
        (r) => r.qiBlood,
        (r) => r.dampness,
      ]) {
        var low = start;
        var high = start;
        for (var index = start + 1; index < end; index++) {
          if (field(records[index]) < field(records[low])) low = index;
          if (field(records[index]) > field(records[high])) high = index;
        }
        selected.addAll([low, high]);
      }
    }
    return (selected.toList()..sort()).map((i) => records[i]).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final cutoff = _days == null ? null : now.subtract(Duration(days: _days!));
    final records = widget.records.where((r) {
      final time = r.displayTime(now: now);
      return cutoff == null || (time != null && !time.isBefore(cutoff));
    }).toList()..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    final timed = records
        .where((r) => r.displayTime(now: now) != null)
        .toList()
        .reversed
        .toList();
    final plot = _plotSamples(timed);
    final labels = [
      _copy('Flow', '血瘀'),
      _copy('Vitality', '气血'),
      _copy('Moisture', '湿气'),
    ];
    const colors = [Color(0xff27607a), Color(0xff39745d), Color(0xffa45f38)];
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
      key: const Key('u19-pulse-history'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _copy('Pulse trends', '脉搏趋势'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final days in <int?>[7, 30, null])
                  ChoiceChip(
                    label: Text(
                      days == null
                          ? _copy('All', '全部')
                          : _copy('$days days', '$days 天'),
                    ),
                    selected: days == _days,
                    onSelected: (_) => setState(() {
                      _days = days;
                      _visible = 20;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (var i = 0; i < labels.length; i++)
                  Text('● ${labels[i]}', style: TextStyle(color: colors[i])),
              ],
            ),
            const SizedBox(height: 16),
            if (plot.isEmpty)
              Text(_copy('No dated readings in this period.', '此时段暂无已确认时间的记录'))
            else ...[
              SizedBox(
                height: 190,
                child: LineChart(
                  key: const Key('u19-pulse-trend-chart'),
                  LineChartData(
                    minY: 0,
                    maxY: 10,
                    minX: plot.length == 1
                        ? plot.first.measuredAt.millisecondsSinceEpoch / 1000 -
                              30
                        : null,
                    maxX: plot.length == 1
                        ? plot.first.measuredAt.millisecondsSinceEpoch / 1000 +
                              30
                        : null,
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: MediaQuery.textScalerOf(
                            context,
                          ).scale(30),
                          interval: 2,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      for (var index = 0; index < 3; index++)
                        LineChartBarData(
                          color: colors[index],
                          isCurved: false,
                          barWidth: 2,
                          dotData: FlDotData(show: plot.length <= 50),
                          spots: [
                            for (final r in plot)
                              FlSpot(
                                r.measuredAt.millisecondsSinceEpoch / 1000,
                                [
                                  r.bloodStasis,
                                  r.qiBlood,
                                  r.dampness,
                                ][index].toDouble(),
                              ),
                          ],
                        ),
                    ],
                  ),
                  duration: Duration.zero,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatter.format(plot.first.measuredAt.toLocal())}'
                ' — ${formatter.format(plot.last.measuredAt.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (plot.length == 1)
                Text(
                  _copy(
                    'One reading. More readings will show a trend.',
                    '当前只有一次记录，更多测量后将显示变化趋势',
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              _copy(
                'Saved readings (${records.length})',
                '已保存记录（${records.length}）',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              _copy(
                'Stored on this phone for this account and device.',
                '记录保存在本机，按当前账号和设备分别管理',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final record in records.take(_visible)) ...[
              const Divider(height: 24),
              Text(
                record.displayTime(now: now) == null
                    ? _copy('Device time needs confirmation', '设备时间待确认')
                    : formatter.format(record.measuredAt.toLocal()),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < 3; i++)
                    Text(
                      '${labels[i]}: ${[record.bloodStasis, record.qiBlood, record.dampness][i]} / 10',
                      style: TextStyle(color: colors[i]),
                    ),
                ],
              ),
            ],
            if (records.length > _visible)
              TextButton(
                onPressed: () => setState(() => _visible += 20),
                child: Text(_copy('Show more', '显示更多')),
              ),
          ],
        ),
      ),
    );
  }
}
