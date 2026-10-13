part of '../pages.dart';

class HealthPage extends StatelessWidget {
  const HealthPage({required this.controller, super.key});

  final AppController controller;

  static const coreMetrics = [
    HealthMetric.heartRate,
    HealthMetric.bloodOxygen,
    HealthMetric.bloodPressure,
    HealthMetric.bloodGlucose,
    HealthMetric.bodyTemperature,
    HealthMetric.ecg,
    HealthMetric.hrv,
    HealthMetric.stress,
    HealthMetric.bodyComposition,
    HealthMetric.bloodComposition,
    HealthMetric.sleep,
  ];

  @override
  Widget build(BuildContext context) {
    final latest = controller.latestByMetric;
    final releaseMetrics = [
      if (controller.isWellnessOnly) ...[
        HealthMetric.steps,
        HealthMetric.distance,
        HealthMetric.calories,
      ],
      ...coreMetrics,
    ];
    final visibleMetrics = releaseMetrics
        .where(controller.shouldShowHealthMetric)
        .toList(growable: false);
    final calibrationMetrics = <HealthMetric>[
      if (controller.canMeasureHealthMetric(HealthMetric.bloodPressure))
        HealthMetric.bloodPressure,
      if (controller.canMeasureHealthMetric(HealthMetric.bloodGlucose))
        HealthMetric.bloodGlucose,
    ];
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          controller.synchronizeCloud(),
          controller.refreshSportRecords(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SaydianColors.ink,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '健康数据总览',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '点击指标查看详情与历史趋势',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.monitor_heart_outlined,
                    color: SaydianColors.green,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (visibleMetrics.isEmpty) ...[
            InlineNotice(
              message: controller.connectedDevice == null
                  ? '连接戒指后可查看支持的健康数据'
                  : '暂无可显示的健康数据',
              icon: Icons.watch_outlined,
              color: SaydianColors.blue,
              compact: true,
            ),
            const SizedBox(height: 10),
          ],
          for (final metric in visibleMetrics) ...[
            _HealthRow(
              controller: controller,
              metric: metric,
              record: latest[metric],
              supported: controller.capabilities?.supports(metric),
              connected: controller.connectedDevice != null,
            ),
            const SizedBox(height: 10),
          ],
          if (calibrationMetrics.isNotEmpty) ...[
            const SizedBox(height: 4),
            Card(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < calibrationMetrics.length;
                    index++
                  ) ...[
                    if (index > 0) const Divider(indent: 56),
                    ListTile(
                      onTap: () {
                        final metric = calibrationMetrics[index];
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            settings: RouteSettings(
                              name: metric == HealthMetric.bloodPressure
                                  ? 'bp-calibration'
                                  : 'glucose-calibration',
                            ),
                            builder: (_) => HealthCalibrationPage(
                              controller: controller,
                              metric: metric,
                            ),
                          ),
                        );
                      },
                      leading: const Icon(Icons.tune_rounded),
                      title: Text(
                        '${calibrationMetrics[index] == HealthMetric.bloodPressure ? '血压' : '血糖'}校准',
                      ),
                      subtitle: Text(context.l10n.calibrateOnWatchHint),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AllHealthDataPage extends StatelessWidget {
  const AllHealthDataPage({
    required this.controller,
    this.title = '全部健康数据',
    super.key,
  });

  final AppController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => HealthPage(controller: controller),
      ),
    );
  }
}

Future<void> _showHealthMeasurementDialog(
  BuildContext context,
  AppController controller,
  HealthMetric metric,
) => !controller.isMetricAvailableInRelease(metric)
    ? Future.value()
    : showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _HealthMeasurementDialog(controller: controller, metric: metric),
      );

class _HealthMeasurementDialog extends StatefulWidget {
  const _HealthMeasurementDialog({
    required this.controller,
    required this.metric,
  });

  final AppController controller;
  final HealthMetric metric;

  @override
  State<_HealthMeasurementDialog> createState() =>
      _HealthMeasurementDialogState();
}

class _HealthMeasurementDialogState extends State<_HealthMeasurementDialog> {
  // Capture this when the dialog opens, even before the first record exists.
  // A late initializer behind `record != null && ...` would only run after
  // the vendor result arrives and incorrectly classify it as an old record.
  final DateTime _startedAt = DateTime.now();
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.startMeasurement(widget.metric));
  }

  Future<void> _finish() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    final record = widget.controller.latestByMetric[widget.metric];
    final completed = record != null && record.measuredAt.isAfter(_startedAt);
    if (completed) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // A few vendor firmwares do not acknowledge a stop command promptly.
    // Close the dialog first so the user never gets trapped on a spinner;
    // AppController still performs the bounded stop in the background.
    if (mounted) Navigator.of(context).pop();
    await widget.controller.stopMeasurement(widget.metric);
  }

  Future<void> _retry() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    await widget.controller.stopMeasurement(widget.metric);
    if (!mounted) return;
    setState(() => _stopping = false);
    await widget.controller.startMeasurement(widget.metric);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isMetricAvailableInRelease(widget.metric)) {
      return const AlertDialog(content: Text('此版本提供活动和睡眠记录。'));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_finish());
      },
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final record = widget.controller.latestByMetric[widget.metric];
          final isNew = record != null && record.measuredAt.isAfter(_startedAt);
          final failure = widget.controller.measurementErrorMessage;
          final failed = !isNew && failure != null;
          final waitingMessage = !widget.controller.measurementWearConfirmed
              ? switch (widget.metric) {
                  HealthMetric.ecg => '未检测到电极接触，请正确佩戴戒指并将手指持续贴在心电电极上',
                  HealthMetric.bodyComposition ||
                  HealthMetric.bloodComposition =>
                    '未检测到正确接触，请确认戒指贴合手指并按页面指引调整接触位置',
                  _ => '未检测到正确佩戴，请将戒指贴合手指后继续测量',
                }
              : switch (widget.metric) {
                  HealthMetric.bloodPressure => '正在测量血压，请保持戒指贴合手指、手臂静止并等待结果',
                  HealthMetric.ecg => '请正确佩戴戒指，并将手指持续贴在心电电极上',
                  HealthMetric.hrv => '请将戒指贴合手指并保持静止，等待 HRV 测量结果',
                  HealthMetric.stress => '请将戒指贴合手指并保持静止，等待压力测量结果',
                  HealthMetric.bodyComposition ||
                  HealthMetric.bloodComposition => '请保持戒指正确贴合，测量完成前不要移动',
                  _ => '请戴好戒指并保持静止\n等待戒指返回测量结果',
                };
          return AlertDialog(
            title: Text(
              context.l10n.metricMeasurement(
                context.l10n.metricName(widget.metric),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isNew
                      ? Icons.check_circle_rounded
                      : failed
                      ? Icons.error_outline_rounded
                      : Icons.monitor_heart_rounded,
                  color: isNew
                      ? SaydianColors.green
                      : failed
                      ? SaydianColors.danger
                      : SaydianColors.pink,
                  size: 54,
                ),
                const SizedBox(height: 14),
                Text(
                  isNew
                      ? '${_healthDisplayValue(record, widget.controller)} ${_healthDisplayUnit(widget.metric, record, widget.controller)}'
                      : failed
                      ? failure
                      : waitingMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isNew ? 24 : 16,
                    fontWeight: isNew ? FontWeight.w900 : FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                if (isNew) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final interpretation = interpretHealthRecord(record);
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SaydianColors.brandRedSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              interpretation.title,
                              style: const TextStyle(
                                color: SaydianColors.brandRedDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              interpretation.detail,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                if (!isNew &&
                    !failed &&
                    widget.metric == HealthMetric.ecg &&
                    widget.controller.measurementSamples.length > 1) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 160,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF08090B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      painter: _LiveEcgPainter(
                        widget.controller.measurementSamples,
                        sampleFrequency:
                            widget.controller.measurementSampleFrequency,
                      ),
                    ),
                  ),
                ],
                if (!isNew && !failed) ...[
                  if (widget.metric == HealthMetric.bloodPressure) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SaydianColors.brandGoldSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        context.l10n.spotCheckCuffHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, height: 1.45),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: widget.controller.measurementProgress > 0
                        ? widget.controller.measurementProgress / 100
                        : null,
                  ),
                  if (widget.controller.measurementProgress > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '测量进度 ${widget.controller.measurementProgress}%',
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ],
            ),
            actions: [
              if (failed)
                FilledButton(
                  onPressed: _stopping ? null : _retry,
                  child: Text(context.l10n.measureAgain),
                ),
              TextButton(
                onPressed: _stopping ? null : _finish,
                child: Text(
                  _stopping
                      ? '正在停止'
                      : isNew
                      ? '完成'
                      : failed
                      ? '关闭'
                      : '结束测量',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _healthDisplayValue(HealthRecord? record, AppController controller) {
  if (record == null) return '--';
  final value =
      record.values['value'] ??
      (record.values.isEmpty ? null : record.values.values.first);
  if (value == null) return record.displayValue;
  if (record.metric == HealthMetric.distance &&
      controller.distanceUnit == '英里') {
    return (value * 0.621371).toStringAsFixed(2);
  }
  if (record.metric == HealthMetric.bodyTemperature &&
      controller.temperatureUnit == '华氏度（℉）') {
    return (value * 9 / 5 + 32).toStringAsFixed(1);
  }
  return record.displayValue;
}

String _healthDisplayUnit(
  HealthMetric metric,
  HealthRecord? record,
  AppController controller,
) {
  if (metric == HealthMetric.distance && controller.distanceUnit == '英里') {
    return 'mi';
  }
  if (metric == HealthMetric.bodyTemperature &&
      controller.temperatureUnit == '华氏度（℉）') {
    return '℉';
  }
  return record?.unit ?? metric.defaultUnit;
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.controller,
    required this.metric,
    required this.record,
    required this.supported,
    required this.connected,
  });

  final AppController controller;
  final HealthMetric metric;
  final HealthRecord? record;
  final bool? supported;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final status = record != null
        ? '最近 ${DateFormat('MM-dd HH:mm').format(record!.measuredAt.toLocal())}'
        : !connected
        ? '连接戒指后使用'
        : supported == false
        ? '当前戒指暂不支持在 App 中测量'
        : '暂无测量记录';
    final icon = switch (metric) {
      HealthMetric.heartRate => Icons.favorite_rounded,
      HealthMetric.bloodOxygen => Icons.water_drop_rounded,
      HealthMetric.bloodPressure => Icons.speed_rounded,
      HealthMetric.bloodGlucose => Icons.water_drop_outlined,
      HealthMetric.bodyTemperature => Icons.thermostat_rounded,
      HealthMetric.ecg => Icons.monitor_heart_outlined,
      HealthMetric.hrv => Icons.show_chart_rounded,
      HealthMetric.stress => Icons.spa_rounded,
      HealthMetric.bodyComposition => Icons.accessibility_new_rounded,
      HealthMetric.bloodComposition => Icons.bloodtype_outlined,
      HealthMetric.steps => Icons.directions_walk_rounded,
      HealthMetric.distance => Icons.location_on_rounded,
      HealthMetric.calories => Icons.local_fire_department_rounded,
      HealthMetric.sleep => Icons.bedtime_rounded,
    };
    final color = switch (metric) {
      HealthMetric.heartRate => SaydianColors.pink,
      HealthMetric.bloodOxygen => SaydianColors.blue,
      HealthMetric.bloodPressure => SaydianColors.orange,
      HealthMetric.bloodGlucose => SaydianColors.green,
      HealthMetric.bodyTemperature => SaydianColors.cyan,
      HealthMetric.ecg => const Color(0xFF6E8DF5),
      HealthMetric.hrv => const Color(0xFF8C7CF0),
      HealthMetric.stress => const Color(0xFF5E9B78),
      HealthMetric.bodyComposition => SaydianColors.cyan,
      HealthMetric.bloodComposition => SaydianColors.pink,
      HealthMetric.sleep => const Color(0xFF8C7CF0),
      _ => SaydianColors.green,
    };
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                HealthHistoryPage(controller: controller, metric: metric),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.metricName(metric),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      maxLines: 2,
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _healthDisplayValue(record, controller),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _healthDisplayUnit(metric, record, controller),
                    style: const TextStyle(
                      color: SaydianColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class HealthHistoryPage extends StatelessWidget {
  const HealthHistoryPage({
    required this.controller,
    required this.metric,
    super.key,
  });

  final AppController controller;
  final HealthMetric metric;

  @override
  Widget build(BuildContext context) {
    final canMeasure = controller.canMeasureHealthMetric(metric);
    return HealthTrendPage(
      controller: controller,
      metric: metric,
      onMeasure: canMeasure
          ? (trendContext) =>
                _showHealthMeasurementDialog(trendContext, controller, metric)
          : null,
    );
  }
}

class _LiveEcgPainter extends CustomPainter {
  const _LiveEcgPainter(this.samples, {required this.sampleFrequency});

  final List<num> samples;
  final int sampleFrequency;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF08090B),
    );
    // Match the watch's black-grid live view while retaining medical-paper
    // timing (25 mm/s) and voltage (10 mm/mV). This path intentionally uses
    // the calibrated ADC samples directly: history denoising would deform a
    // short, still-growing live window.
    // Match HBandSDK's EcgHeartRealthView: 16 major vertical squares, each
    // split into five minor squares. The previous 32-row grid magnified the
    // same calibrated mV samples by 2.5x and clipped W9S traces to the rails.
    final smallGrid = liveEcgMinorGridSize(size.height);
    final thinGrid = Paint()
      ..color = const Color(0x334B1B22)
      ..strokeWidth = .7;
    final boldGrid = Paint()
      ..color = const Color(0x665F202A)
      ..strokeWidth = 1;
    for (var index = 0, x = 0.0; x <= size.width; index++, x += smallGrid) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        index % 5 == 0 ? boldGrid : thinGrid,
      );
    }
    for (var index = 0, y = 0.0; y <= size.height; index++, y += smallGrid) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        index % 5 == 0 ? boldGrid : thinGrid,
      );
    }
    final frequency = sampleFrequency.clamp(50, 1000);
    final xStep = smallGrid * 25 / frequency;
    final capacity = math.max(2, (size.width / xStep).ceil() + 1);
    final visible = samples.length > capacity
        ? samples.sublist(samples.length - capacity)
        : samples;
    if (visible.length < 2) return;
    final displaySamples = prepareLiveEcgTrace(
      visible,
      sampleFrequency: frequency,
    );
    final baseline = size.height * .58;
    final path = Path();
    final firstX = size.width - (displaySamples.length - 1) * xStep;
    var drawing = false;
    for (var index = 0; index < displaySamples.length; index++) {
      final sample = displaySamples[index];
      if (sample == null) {
        drawing = false;
        continue;
      }
      final x = firstX + index * xStep;
      final y = baseline - sample * 10 * smallGrid;
      if (drawing) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        drawing = true;
      }
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      path,
      Paint()
        ..color = SaydianColors.techViolet
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiveEcgPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.sampleFrequency != sampleFrequency;
}
