import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/ring_experience.dart';
import '../services/app_controller.dart';
import 'ring_share_page.dart';

class CardiovascularTrendsPage extends StatefulWidget {
  const CardiovascularTrendsPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<CardiovascularTrendsPage> createState() =>
      _CardiovascularTrendsPageState();
}

class _CardiovascularTrendsPageState extends State<CardiovascularTrendsPage> {
  late final String owner = widget.controller.ringExperienceOwner;
  int days = 7;
  DateTime end = ringDate(DateTime.now());
  DateTime get start => ringAddDays(end, 1 - days);
  late Future<
    ({
      List<PressureSample> pressure,
      List<HealthRecord> sleep,
      List<HealthRecord> heart,
      List<HealthRecord> activity,
    })
  >
  result = load();

  Future<
    ({
      List<PressureSample> pressure,
      List<HealthRecord> sleep,
      List<HealthRecord> heart,
      List<HealthRecord> activity,
    })
  >
  load() async {
    final from = start;
    final until = ringAddDays(end, 1);
    final reads = await (
      widget.controller.loadPressureTrend(ringAddDays(from, -days), until),
      widget.controller.loadSleepDays(start: from, end: end),
      widget.controller.loadHealthRecords(
        metric: HealthMetric.heartRate,
        start: from,
        end: until,
      ),
      widget.controller.loadHealthRecords(
        metric: HealthMetric.steps,
        start: from,
        end: until,
      ),
    ).wait;
    return (
      pressure: reads.$1,
      sleep: reads.$2,
      heart: reads.$3,
      activity: reads.$4,
    );
  }

  Future<void> addReference() async {
    final row = await showDialog<PressureSample>(
      context: context,
      builder: (_) => const _ReferenceEntry(),
    );
    if (!mounted ||
        row == null ||
        owner != widget.controller.ringExperienceOwner) {
      return;
    }
    try {
      await widget.controller.savePressureReference(row);
      if (mounted) {
        setState(() {
          result = load();
        });
      }
    } catch (error) {
      if (mounted) showRingError(context, error);
    }
  }

  Future<void> pickDate() async {
    final current = DateTime.now();
    final next = await showDatePicker(
      context: context,
      initialDate: end,
      firstDate: DateTime(current.year - 10),
      lastDate: current,
    );
    if (next != null && mounted) {
      setState(() {
        end = next;
        result = load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(ringText(context, '心血管趋势', 'Cardiovascular trends')),
    ),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (owner != widget.controller.ringExperienceOwner) {
          return const SizedBox.shrink();
        }
        return FutureBuilder(
          future: result,
          builder: (context, snapshot) {
            final data = snapshot.connectionState == ConnectionState.done
                ? snapshot.data
                : null;
            final bySource = <String, List<PressureSample>>{};
            for (final row in data?.pressure ?? const <PressureSample>[]) {
              bySource.putIfAbsent(row.source, () => []).add(row);
            }
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  result = load();
                });
                try {
                  await result;
                } catch (_) {}
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final count in [7, 30])
                        ChoiceChip(
                          key: ValueKey('pressure-period-$count'),
                          label: Text(
                            ringText(context, '近 $count 天', '$count days'),
                          ),
                          selected: days == count,
                          onSelected: (_) => setState(() {
                            days = count;
                            result = load();
                          }),
                        ),
                      OutlinedButton.icon(
                        onPressed: pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatCompactDate(end),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const Key('record-pressure-reference'),
                    onPressed: addReference,
                    icon: const Icon(Icons.add),
                    label: Text(
                      ringText(
                        context,
                        '录入上臂血压计参考值',
                        'Add upper-arm monitor reading',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Center(child: CircularProgressIndicator())
                  else if (snapshot.hasError)
                    Text(
                      ringText(
                        context,
                        '暂时无法读取。下拉重试。',
                        'Could not load. Pull down to retry.',
                      ),
                    )
                  else ...[
                    if (bySource.isEmpty)
                      Text(
                        ringText(
                          context,
                          '这段时间暂无血压记录',
                          'No blood pressure readings in this period',
                        ),
                      ),
                    for (final (index, rows) in bySource.values.indexed)
                      _PressureSource(
                        rows: rows,
                        start: start,
                        end: end,
                        deviceNumber: index + 1,
                        canShare: widget.controller.isAuthenticated,
                        controller: widget.controller,
                      ),
                    if (data != null &&
                        (data.sleep.isNotEmpty ||
                            data.heart.isNotEmpty ||
                            data.activity.isNotEmpty))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ringText(context, '同期记录', 'During this period'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              for (final (zh, en, records) in [
                                ('睡眠', 'Sleep', data.sleep),
                                ('心率', 'Heart rate', data.heart),
                                ('活动', 'Activity', data.activity),
                              ])
                                if (records.isNotEmpty)
                                  Text(
                                    ringText(
                                      context,
                                      '$zh · ${_counts(records)} 天有记录',
                                      '$en · ${_counts(records)} days recorded',
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    ),
  );

  int _counts(List<HealthRecord> records) => records
      .map((item) => ringDateText(item.measuredAt.toLocal()))
      .toSet()
      .length;
}

class _PressureSource extends StatelessWidget {
  const _PressureSource({
    required this.rows,
    required this.start,
    required this.end,
    required this.deviceNumber,
    required this.canShare,
    required this.controller,
  });
  final List<PressureSample> rows;
  final DateTime start;
  final DateTime end;
  final int deviceNumber;
  final bool canShare;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final all = pressureDays(rows);
    final current = all.where((row) => !row.date.isBefore(start)).toList();
    if (current.isEmpty) return const SizedBox.shrink();
    final readings = rows.where((row) => !row.at.isBefore(start)).toList();
    final past = ringAddDays(
      start,
      -calendarDistance(start, ringAddDays(end, 1)),
    );
    final delta = pressureChange(all, start, past);
    final source = rows.first.source == 'reference'
        ? ringText(
            context,
            '上臂血压计 · 本人录入',
            'Upper-arm monitor · entered by you',
          )
        : rows.first.label.isNotEmpty
        ? rows.first.label
        : ringText(context, '穿戴设备 $deviceNumber', 'Wearable $deviceNumber');
    final colors = Theme.of(context).colorScheme;
    const upperColor = Color(0xff245c49);
    const lowerColor = Color(0xff4764a7);
    String difference(double value) =>
        '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}';
    final periodLength = calendarDistance(start, end);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(source, style: Theme.of(context).textTheme.titleMedium),
            Text(
              ringText(
                context,
                '${current.length} 天有记录 · ${readings.length} 次',
                '${current.length} days recorded · ${readings.length} readings',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 142,
              child: Semantics(
                label: ringText(
                  context,
                  '收缩压与舒张压图表，单位 mmHg',
                  'Systolic and diastolic chart, mmHg',
                ),
                child: LineChart(
                  duration: Duration.zero,
                  LineChartData(
                    minX: 0,
                    maxX: periodLength.toDouble(),
                    minY:
                        current
                            .map((r) => r.diastolic)
                            .reduce((a, b) => a < b ? a : b) -
                        10,
                    maxY:
                        current
                            .map((r) => r.systolic)
                            .reduce((a, b) => a > b ? a : b) +
                        10,
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: colors.outlineVariant, strokeWidth: 1),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: points(current, (row) => row.systolic),
                        color: upperColor,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: true),
                      ),
                      LineChartBarData(
                        spots: points(current, (row) => row.diastolic),
                        color: lowerColor,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  ringText(context, '● 收缩压', '● Systolic'),
                  style: const TextStyle(color: upperColor),
                ),
                Text(
                  ringText(context, '● 舒张压', '● Diastolic'),
                  style: const TextStyle(color: lowerColor),
                ),
                const Text('mmHg'),
              ],
            ),
            const SizedBox(height: 10),
            if (delta != null)
              Text(
                ringText(
                  context,
                  '与前一段相比，日均收缩压 ${difference(delta.systolic)}、舒张压 ${difference(delta.diastolic)} mmHg。',
                  'Versus the previous period, daily mean systolic pressure changed by ${difference(delta.systolic)} and diastolic by ${difference(delta.diastolic)} mmHg.',
                ),
              )
            else
              Text(
                ringText(
                  context,
                  '最近一次 ${readings.last.systolic}/${readings.last.diastolic} mmHg',
                  'Latest reading ${readings.last.systolic}/${readings.last.diastolic} mmHg',
                ),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(ringText(context, '查看依据', 'View readings')),
              children: [
                if (delta != null)
                  Text(
                    ringText(
                      context,
                      '前一段 ${delta.previous} 天 · 当前 ${delta.current} 天',
                      '${delta.previous} days previously · ${delta.current} days in this period',
                    ),
                  ),
                for (final row in readings.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${row.systolic}/${row.diastolic} mmHg'),
                    subtitle: Text(
                      '${MaterialLocalizations.of(context).formatCompactDate(row.at)} · ${ringClockText(row.at)}',
                    ),
                    trailing: canShare
                        ? RingShareButton(
                            controller: controller,
                            compact: true,
                            snapshot: RingSnapshot('health', row.at, {
                              'systolic': row.systolic,
                              'diastolic': row.diastolic,
                              'measuredTime': ringClockText(row.at),
                            }),
                          )
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> points(
    List<PressureDay> rows,
    double Function(PressureDay) value,
  ) {
    var previous = -1;
    final spots = <FlSpot>[];
    for (final row in rows) {
      final offset = calendarDistance(start, row.date);
      if (previous >= 0 && offset > previous + 1) spots.add(FlSpot.nullSpot);
      spots.add(FlSpot(offset.toDouble(), value(row)));
      previous = offset;
    }
    return spots;
  }
}

int calendarDistance(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

class _ReferenceEntry extends StatefulWidget {
  const _ReferenceEntry();
  @override
  State<_ReferenceEntry> createState() => _ReferenceEntryState();
}

class _ReferenceEntryState extends State<_ReferenceEntry> {
  final upper = TextEditingController();
  final lower = TextEditingController();
  DateTime date = DateTime.now();
  bool invalid = false;

  @override
  void dispose() {
    upper.dispose();
    lower.dispose();
    super.dispose();
  }

  Future<void> selectTime() async {
    final next = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(DateTime.now().year - 10),
      lastDate: DateTime.now(),
    );
    if (next == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
    );
    if (mounted && time != null) {
      setState(() {
        date = DateTime(
          next.year,
          next.month,
          next.day,
          time.hour,
          time.minute,
        );
        invalid = false;
      });
    }
  }

  void save() {
    final systolic = int.tryParse(upper.text.trim());
    final diastolic = int.tryParse(lower.text.trim());
    if (!PressureSample.validPair(systolic, diastolic) ||
        date.isAfter(DateTime.now())) {
      setState(() => invalid = true);
      return;
    }
    Navigator.pop(
      context,
      PressureSample(
        at: date,
        systolic: systolic!,
        diastolic: diastolic!,
        source: 'reference',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(ringText(context, '录入血压参考值', 'Add a reference reading')),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: upper,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: ringText(context, '收缩压 (mmHg)', 'Systolic (mmHg)'),
          ),
        ),
        TextField(
          controller: lower,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: ringText(context, '舒张压 (mmHg)', 'Diastolic (mmHg)'),
          ),
        ),
        TextButton.icon(
          onPressed: selectTime,
          icon: const Icon(Icons.schedule),
          label: Text(
            '${MaterialLocalizations.of(context).formatCompactDate(date)} ${ringClockText(date)}',
          ),
        ),
        if (invalid)
          Text(
            ringText(
              context,
              '请检查收缩压、舒张压和测量时间。',
              'Check the two readings and the measurement time.',
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        onPressed: save,
        child: Text(ringText(context, '保存到本机', 'Save on this phone')),
      ),
    ],
  );
}
