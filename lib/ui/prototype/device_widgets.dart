part of '../prototype_pages.dart';

class _WatchFaceThumbnail extends StatelessWidget {
  const _WatchFaceThumbnail({required this.face});

  final Map<String, Object?> face;

  @override
  Widget build(BuildContext context) {
    final source = _imageSource;
    final fallback = _fallback;
    Widget image = fallback;
    if (source != null) {
      final uri = Uri.tryParse(source);
      if (uri != null && uri.isScheme('https')) {
        image = SafeNetworkImage(
          source,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      } else {
        final file = File(source.replaceFirst('file://', ''));
        if (file.existsSync()) {
          image = Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        }
      }
    }
    return Semantics(
      image: true,
      label: source == null
          ? '${face['name'] ?? '显示样式'}预览暂不可用'
          : '${face['name'] ?? '显示样式'}缩略图',
      child: Container(
        width: 62,
        height: 62,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.black12),
        ),
        child: image,
      ),
    );
  }

  String? get _imageSource {
    return DeviceWatchFaceMarketService.findUsablePreviewReference(face);
  }

  Widget get _fallback {
    return ColoredBox(
      color: const Color(0xFFF1F3F5),
      child: Center(
        child: Text(
          '预览\n暂不可用',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SaydianColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DeviceFeatureHeader extends StatelessWidget {
  const _DeviceFeatureHeader({required this.feature, required this.device});

  final DeviceFeature feature;
  final DeviceInfo? device;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: SaydianColors.blue.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_deviceFeatureIcon(feature), color: SaydianColors.blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.deviceFeatureName(feature),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _deviceFeatureDescription(feature),
                  style: const TextStyle(
                    color: SaydianColors.muted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EcgWaveformCard extends StatelessWidget {
  const _EcgWaveformCard({
    required this.samples,
    required this.sampleFrequency,
    required this.calibrated,
  });

  final List<num> samples;
  final int sampleFrequency;
  final bool calibrated;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('心电波形', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              FeatureStateCard(
                message: '戒指未返回可用心电波形',
                icon: Icons.monitor_heart_outlined,
              ),
            ],
          ),
        ),
      );
    }
    if (!calibrated) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('心电波形', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              FeatureStateCard(
                message: '本次波形无法显示',
                detail: '请重新测量心电。',
                icon: Icons.monitor_heart_outlined,
              ),
            ],
          ),
        ),
      );
    }
    final frequency = sampleFrequency.clamp(50, 1000);
    final usableSamples = selectUsableEcgTail(
      samples,
      sampleFrequency: frequency,
    );
    final displaySamples = usableSamples.isEmpty ? samples : usableSamples;
    final durationSeconds = displaySamples.length / frequency;
    final chartWidth = math.max(640.0, durationSeconds * 72.0);
    final waveform = prepareEcgDisplayWaveform(
      displaySamples,
      maximumPoints: math.max(2, (chartWidth * 2).round()),
      sampleFrequency: frequency,
      removeContactArtifacts: true,
    );
    final spots = waveform.samples
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.ecgWaveformTitle,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '共 ${durationSeconds.toStringAsFixed(1)} 秒 · 左右滑动查看完整记录',
              style: const TextStyle(color: SaydianColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (!waveform.hasVariation)
              FeatureStateCard(
                message: context.l10n.ecgWaveformMissing,
                detail: context.l10n.ecgElectrodeHint,
                icon: Icons.monitor_heart_outlined,
              )
            else
              Semantics(
                label: '设备记录的有效心电波形，共${displaySamples.length}个采样点',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        minY: waveform.minimum,
                        maxY: waveform.maximum,
                        gridData: FlGridData(
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: SaydianColors.pink.withValues(alpha: 0.12),
                            strokeWidth: 1,
                          ),
                          getDrawingVerticalLine: (_) => FlLine(
                            color: SaydianColors.pink.withValues(alpha: 0.08),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            color: SaydianColors.pink,
                            barWidth: 1.8,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FindWatchPanel extends StatelessWidget {
  const _FindWatchPanel({
    required this.finding,
    required this.busy,
    required this.supportsStop,
    this.commandOnly = false,
    required this.onPressed,
  });

  final bool finding;
  final bool busy;
  final bool supportsStop;
  final bool commandOnly;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              finding
                  ? Icons.notifications_active_rounded
                  : Icons.watch_rounded,
              size: 68,
              color: finding ? SaydianColors.orange : SaydianColors.ink,
            ),
            const SizedBox(height: 14),
            Text(
              commandOnly
                  ? (finding ? '查找指令已发送' : '查找已连接的戒指')
                  : (finding
                        ? (supportsStop ? '请留意附近响铃或振动的戒指' : '查找指令已发送，请留意戒指振动')
                        : '让戒指响铃或振动，帮助你快速找到它'),
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy || (finding && !supportsStop)
                    ? null
                    : onPressed,
                child: Text(
                  finding ? (supportsStop ? '停止查找' : '正在查找') : '开始查找',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenSettingsPanel extends StatelessWidget {
  const _ScreenSettingsPanel({
    required this.settings,
    required this.busy,
    required this.onReload,
    required this.onChanged,
    required this.onSave,
  });

  final DeviceScreenSettings? settings;
  final bool busy;
  final VoidCallback onReload;
  final ValueChanged<DeviceScreenSettings> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final value = settings;
    if (value == null) {
      return FeatureStateCard(
        message: busy ? '正在读取戒指设置' : '暂时未读取到屏幕设置',
        detail: '请保持戒指靠近手机后重试。',
        icon: Icons.brightness_6_outlined,
        actionLabel: busy ? null : '重新读取',
        onAction: busy ? null : onReload,
      );
    }
    final maximum = value.maximumBrightness.clamp(1, 10);
    final current = value.brightness.clamp(1, maximum);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (value.brightnessSupported) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.autoBrightness),
                subtitle: Text(context.l10n.screenAutoTimeHint),
                value: value.automaticBrightness,
                onChanged: busy
                    ? null
                    : (enabled) => onChanged(
                        value.copyWith(automaticBrightness: enabled),
                      ),
              ),
              const Divider(),
              const SizedBox(height: 12),
              Text('屏幕亮度  $current / $maximum'),
              Slider(
                value: current.toDouble(),
                min: 1,
                max: maximum.toDouble(),
                divisions: maximum > 1 ? maximum - 1 : 1,
                onChanged: busy
                    ? null
                    : (next) => onChanged(
                        value.copyWith(
                          brightness: next.round(),
                          automaticBrightness: false,
                        ),
                      ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SaydianColors.brandGoldSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '当前戒指无可由 App 调整的显示设置。',
                        style: TextStyle(fontSize: 14, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (value.durationSeconds != null &&
                value.minimumDurationSeconds != null &&
                value.maximumDurationSeconds != null) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text('亮屏时长  ${value.durationSeconds} 秒'),
              Slider(
                value: value.durationSeconds!.toDouble().clamp(
                  value.minimumDurationSeconds!.toDouble(),
                  value.maximumDurationSeconds!.toDouble(),
                ),
                min: value.minimumDurationSeconds!.toDouble(),
                max: value.maximumDurationSeconds!.toDouble(),
                divisions:
                    (value.maximumDurationSeconds! -
                            value.minimumDurationSeconds!) >
                        0
                    ? value.maximumDurationSeconds! -
                          value.minimumDurationSeconds!
                    : 1,
                onChanged: busy
                    ? null
                    : (next) => onChanged(
                        value.copyWith(durationSeconds: next.round()),
                      ),
              ),
            ],
            if (value.raiseToWakeSupported) ...[
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.raiseToWake),
                subtitle: Text(context.l10n.raiseWristScreenHint),
                value: value.raiseToWakeEnabled,
                onChanged: busy
                    ? null
                    : (enabled) => onChanged(
                        value.copyWith(raiseToWakeEnabled: enabled),
                      ),
              ),
              if (value.raiseToWakeCustomTimeSupported) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.activeTime),
                  subtitle: Text(
                    '${_timeLabel(value.raiseToWakeStartMinutes)}–${_timeLabel(value.raiseToWakeEndMinutes)}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: busy
                      ? null
                      : () => _pickRaiseTime(context, value, onChanged),
                ),
                Text('抬腕灵敏度  ${value.raiseToWakeSensitivity} / 10'),
                Slider(
                  value: value.raiseToWakeSensitivity.toDouble().clamp(1, 10),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: busy
                      ? null
                      : (next) => onChanged(
                          value.copyWith(raiseToWakeSensitivity: next.round()),
                        ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onSave,
                child: Text(context.l10n.saveSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRaiseTime(
    BuildContext context,
    DeviceScreenSettings value,
    ValueChanged<DeviceScreenSettings> onChanged,
  ) async {
    final start = await showTimePicker(
      context: context,
      helpText: '选择开始时间',
      initialTime: TimeOfDay(
        hour: value.raiseToWakeStartMinutes ~/ 60,
        minute: value.raiseToWakeStartMinutes % 60,
      ),
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: '选择结束时间',
      initialTime: TimeOfDay(
        hour: value.raiseToWakeEndMinutes ~/ 60,
        minute: value.raiseToWakeEndMinutes % 60,
      ),
    );
    if (end == null) return;
    onChanged(
      value.copyWith(
        raiseToWakeStartMinutes: start.hour * 60 + start.minute,
        raiseToWakeEndMinutes: end.hour * 60 + end.minute,
      ),
    );
  }

  String _timeLabel(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}
