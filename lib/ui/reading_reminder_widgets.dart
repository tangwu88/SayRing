import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/health_reminder.dart';
import '../domain/models.dart';
import '../domain/reading_reminder.dart';
import '../services/app_controller.dart';
import '../services/health_reminder_sound.dart';
import '../services/wearable_bridge.dart';
import 'app_theme.dart';

String _copy(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

IconData _icon(HealthReminderKind kind) =>
    kind == HealthReminderKind.lowBloodOxygen
    ? Icons.water_drop_outlined
    : Icons.favorite_rounded;
String _label(BuildContext context, HealthReminderKind kind) => switch (kind) {
  HealthReminderKind.highHeartRate => _copy(context, '心率过高', 'High heart rate'),
  HealthReminderKind.lowHeartRate => _copy(context, '心率过低', 'Low heart rate'),
  HealthReminderKind.lowBloodOxygen => _copy(context, '血氧偏低', 'Low oxygen'),
  HealthReminderKind.symptoms => _copy(context, '健康提醒', 'Health reminder'),
};
String _unit(HealthReminderKind kind) =>
    kind == HealthReminderKind.lowBloodOxygen ? '%' : 'bpm';
int _reference(HealthReminderKind kind) => switch (kind) {
  HealthReminderKind.highHeartRate => 120,
  HealthReminderKind.lowHeartRate => 40,
  _ => 92,
};

/// Full-window foreground feedback. Acknowledging it never means recovery.
class ReadingReminderAlertView extends StatefulWidget {
  const ReadingReminderAlertView({
    super.key,
    required this.kind,
    required this.reading,
    required this.onDismiss,
    required this.onHelp,
    this.onDetails,
    this.preview = false,
    this.measuredAt,
    this.previewVibration,
    this.soundEnabled = true,
    this.sound = const MethodChannelHealthReminderSound(),
  });
  final HealthReminderKind kind;
  final double reading;
  final VoidCallback onDismiss;
  final VoidCallback onHelp;
  final VoidCallback? onDetails;
  final bool preview;
  final DateTime? measuredAt;
  final Future<RingReminderHapticResult>? previewVibration;
  final bool soundEnabled;
  final HealthReminderSound sound;
  @override
  State<ReadingReminderAlertView> createState() =>
      _ReadingReminderAlertViewState();
}

class _ReadingReminderAlertViewState extends State<ReadingReminderAlertView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static int _soundSequence = 0;
  late final String _soundToken =
      'reading-${DateTime.now().microsecondsSinceEpoch}-${++_soundSequence}';
  bool _soundAttempted = false;
  bool _silenced = false;
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _foreground =>
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      TickerMode.valuesOf(context).enabled;

  void _stopSound() {
    if (_soundAttempted) unawaited(widget.sound.stop(_soundToken));
  }

  void _updateFeedback() {
    if (!_foreground || MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
    if (!_foreground || !widget.soundEnabled) {
      _stopSound();
      return;
    }
    if (_soundAttempted || _silenced) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !_foreground ||
          !widget.soundEnabled ||
          _soundAttempted ||
          _silenced) {
        return;
      }
      _soundAttempted = true;
      await widget.sound.play(_soundToken);
      if (!mounted || !_foreground || !widget.soundEnabled || _silenced) {
        unawaited(widget.sound.stop(_soundToken));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateFeedback();
  }

  @override
  void didUpdateWidget(covariant ReadingReminderAlertView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateFeedback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) _updateFeedback();
  }

  void _finish(VoidCallback action) {
    _silenced = true;
    _stopSound();
    action();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSound();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: BlockSemantics(
      child: Material(
        key: const Key('global-reading-reminder'),
        color: const Color(0xFF981F32),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.preview) ...[
                          Container(
                            key: const Key('reading-reminder-preview-label'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _copy(
                                context,
                                '效果预览 · 不会生成健康记录',
                                'Preview · No health record is saved',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: SaydianColors.ink,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (widget.previewVibration != null) ...[
                            const SizedBox(height: 8),
                            FutureBuilder<RingReminderHapticResult>(
                              key: const Key(
                                'reading-preview-vibration-status',
                              ),
                              future: widget.previewVibration,
                              builder: (context, snapshot) => Text(
                                snapshot.connectionState != ConnectionState.done
                                    ? _copy(
                                        context,
                                        '正在提醒戒指',
                                        'Sending ring reminder',
                                      )
                                    : snapshot.data?.accepted == true
                                    ? _copy(
                                        context,
                                        '请留意戒指振动',
                                        'Check your ring for a vibration',
                                      )
                                    : _copy(
                                        context,
                                        '戒指振动未确认',
                                        'Ring vibration not confirmed',
                                      ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, _) {
                            final phase = _pulse.value;
                            final moving = _pulse.isAnimating;
                            final beat =
                                1 +
                                0.2 *
                                    math.exp(
                                      -math.pow((phase - .14) / .065, 2),
                                    ) +
                                0.12 *
                                    math.exp(
                                      -math.pow((phase - .34) / .065, 2),
                                    );
                            return SizedBox(
                              key: const Key('reading-reminder-motion'),
                              width: 168,
                              height: 168,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  for (var i = 0; i < 2; i++)
                                    if (moving)
                                      Transform.scale(
                                        key: ValueKey(
                                          'reading-reminder-wave-$i',
                                        ),
                                        scale: 1 + ((phase + i / 2) % 1) * .6,
                                        child: Container(
                                          width: 104,
                                          height: 104,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              width: 2,
                                              color: Colors.white.withValues(
                                                alpha:
                                                    (1 -
                                                        ((phase + i / 2) % 1)) *
                                                    .4,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  Transform.scale(
                                    key: const Key(
                                      'reading-reminder-heartbeat',
                                    ),
                                    scale: moving ? beat : 1,
                                    child: Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        _icon(widget.kind),
                                        color: Colors.white,
                                        size: 54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        Semantics(
                          liveRegion: true,
                          header: true,
                          child: Text(
                            _label(context, widget.kind),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.measuredAt != null)
                          Text(
                            '${_copy(context, '测量于', 'Measured')} ${DateFormat('MM-dd HH:mm').format(widget.measuredAt!.toLocal())}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              widget.reading.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 64,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _unit(widget.kind),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _copy(
                            context,
                            '读数超出设定范围，请静坐并复测。',
                            'Outside your set range. Sit quietly and measure again.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _copy(
                            context,
                            '胸部不适、明显气短或晕厥时，立即求助。',
                            'Chest discomfort, severe breathlessness or fainting? Seek urgent help.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (widget.soundEnabled)
                          TextButton.icon(
                            key: const Key('reading-reminder-silence'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _silenced
                                ? null
                                : () {
                                    setState(() => _silenced = true);
                                    _stopSound();
                                  },
                            icon: Icon(
                              _silenced
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                            ),
                            label: Text(
                              _silenced
                                  ? _copy(context, '本次已静音', 'Silenced')
                                  : _copy(context, '停止提示音', 'Silence sound'),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('reading-reminder-urgent-help'),
                            onPressed: () => _finish(widget.onHelp),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF981F32),
                              minimumSize: const Size.fromHeight(52),
                            ),
                            icon: const Icon(Icons.phone_in_talk_outlined),
                            label: Text(_copy(context, '急症求助', 'Urgent help')),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            key: const Key('dismiss-health-warning'),
                            onPressed: () => _finish(widget.onDismiss),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: Text(
                              widget.preview
                                  ? _copy(context, '结束预览', 'Close preview')
                                  : _copy(context, '我已知晓', 'Acknowledge'),
                            ),
                          ),
                        ),
                        if (widget.onDetails != null)
                          TextButton(
                            onPressed: () => _finish(widget.onDetails!),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: Text(_copy(context, '查看记录', 'View record')),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 4,
                child: IconButton(
                  key: const Key('reading-reminder-close'),
                  onPressed: () => _finish(widget.onDismiss),
                  tooltip: _copy(context, '关闭提醒', 'Close reminder'),
                  color: Colors.white,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showReadingReminderPreview(
  BuildContext context,
  HealthReminderKind kind, {
  required VoidCallback onHelp,
  Future<RingReminderHapticResult> Function()? vibrate,
  AppController? controller,
  bool soundEnabled = true,
}) {
  // Start once per explicit preview. Rebuilds and animation frames must never
  // repeat a physical command. Native cleanup also survives closing the route.
  final vibration = vibrate == null
      ? null
      : Future<RingReminderHapticResult>.sync(vibrate);
  final owner = controller?.homeHealthCardOwner;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialog, _, _) {
      Widget view() => ReadingReminderAlertView(
        kind: kind,
        reading:
            (_reference(kind) +
                    (kind == HealthReminderKind.highHeartRate ? 5 : -1))
                .toDouble(),
        preview: true,
        previewVibration: vibration,
        soundEnabled: controller == null
            ? soundEnabled
            : controller.homeHealthCardOwner == owner &&
                  controller.readingReminderSettings.phoneSoundEnabled,
        onDismiss: () => Navigator.of(dialog).pop(),
        onHelp: () {
          Navigator.of(dialog).pop();
          onHelp();
        },
      );
      return controller == null
          ? view()
          : ListenableBuilder(
              listenable: controller,
              builder: (_, _) => view(),
            );
    },
  );
}

class ReadingReminderSettingsPanel extends StatelessWidget {
  const ReadingReminderSettingsPanel({
    super.key,
    required this.controller,
    required this.onHelp,
  });
  final AppController controller;
  final VoidCallback onHelp;

  ReadingReminderSettings _change(
    HealthReminderKind kind, {
    int? value,
    bool? enabled,
  }) {
    final s = controller.readingReminderSettings;
    return switch (kind) {
      HealthReminderKind.highHeartRate => s.copyWith(
        high: value,
        highEnabled: enabled,
      ),
      HealthReminderKind.lowHeartRate => s.copyWith(
        low: value,
        lowEnabled: enabled,
      ),
      _ => s.copyWith(oxygen: value, oxygenEnabled: enabled),
    };
  }

  Future<void> _save(
    BuildContext context,
    ReadingReminderSettings s,
    String owner,
  ) async {
    final saved = await controller.saveReadingReminderSettings(
      s,
      expectedOwner: owner,
    );
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置未保存，请稍后重试')));
    }
  }

  Future<void> _edit(
    BuildContext context,
    HealthReminderKind kind,
    int current,
    String owner,
  ) async {
    var value = current;
    var saving = false;
    final min = kind == HealthReminderKind.highHeartRate
        ? 80
        : kind == HealthReminderKind.lowHeartRate
        ? 30
        : 80;
    final max = kind == HealthReminderKind.highHeartRate
        ? 200
        : kind == HealthReminderKind.lowHeartRate
        ? 80
        : 95;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _copy(
                  context,
                  '${_label(context, kind)}阈值',
                  '${_label(context, kind)} limit',
                ),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: value > min ? () => update(() => value--) : null,
                    tooltip: _copy(context, '降低阈值', 'Lower limit'),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Flexible(
                    child: Text(
                      '$value ${_unit(kind)}',
                      key: const Key('reading-limit-editor-value'),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: value < max ? () => update(() => value++) : null,
                    tooltip: _copy(context, '提高阈值', 'Raise limit'),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                label: '$value ${_unit(kind)}',
                onChanged: (v) => update(() => value = v.round()),
              ),
              TextButton(
                onPressed: () => update(() => value = _reference(kind)),
                child: Text(
                  '${_copy(context, '参考', 'Reference')} ${_reference(kind)} ${_unit(kind)}',
                ),
              ),
              Text(
                _copy(
                  context,
                  '成人起始参考，按个人情况或医嘱调整。',
                  'Adult starting reference. Adjust for your needs or clinical advice.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('reading-limit-save'),
                  onPressed: saving || controller.readingReminderSettingsSaving
                      ? null
                      : () async {
                          if (owner != controller.homeHealthCardOwner) {
                            Navigator.of(sheet).pop();
                            return;
                          }
                          update(() => saving = true);
                          final result = await controller
                              .saveReadingReminderSettings(
                                _change(kind, value: value),
                                expectedOwner: owner,
                              );
                          if (sheet.mounted && result) {
                            Navigator.of(sheet).pop();
                          } else if (sheet.mounted) {
                            update(() => saving = false);
                            ScaffoldMessenger.of(sheet).showSnackBar(
                              const SnackBar(content: Text('设置未保存，请重试')),
                            );
                          }
                        },
                  child: Text(_copy(context, '保存', 'Save')),
                ),
              ),
              SizedBox(height: MediaQuery.viewInsetsOf(sheet).bottom),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = controller.readingReminderSettings;
    final owner = controller.homeHealthCardOwner;
    final canEdit =
        controller.canSaveHealthReminder &&
        !controller.readingReminderSettingsSaving;
    bool supports(HealthMetric metric) =>
        controller.capabilities?.manualMetrics?.contains(metric) == true &&
        controller.canMeasureHealthMetric(metric);
    final heartRate = supports(HealthMetric.heartRate);
    final oxygen = supports(HealthMetric.bloodOxygen);
    final kinds = [
      if (heartRate) ...[
        HealthReminderKind.highHeartRate,
        HealthReminderKind.lowHeartRate,
      ],
      if (oxygen) HealthReminderKind.lowBloodOxygen,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kinds.isNotEmpty) ...[
          for (final kind in kinds)
            Builder(
              builder: (context) {
                final oxygen = kind == HealthReminderKind.lowBloodOxygen;
                final high = kind == HealthReminderKind.highHeartRate;
                final value = oxygen
                    ? s.oxygen
                    : high
                    ? s.high
                    : s.low;
                final enabled = oxygen
                    ? s.oxygenEnabled
                    : high
                    ? s.highEnabled
                    : s.lowEnabled;
                final color = oxygen
                    ? SaydianColors.techCyanDark
                    : high
                    ? SaydianColors.danger
                    : SaydianColors.techViolet;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(_icon(kind), color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _label(context, kind),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Semantics(
                              label: _copy(
                                context,
                                '${_label(context, kind)}提醒',
                                '${_label(context, kind)} reminder',
                              ),
                              child: Switch(
                                key: Key(
                                  'reading-reminder-${kind.wireName}-enabled',
                                ),
                                value: enabled,
                                onChanged: canEdit
                                    ? (v) => _save(
                                        context,
                                        _change(kind, enabled: v),
                                        owner,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          key: Key('reading-reminder-${kind.wireName}-limit'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: canEdit
                              ? () => _edit(context, kind, value, owner)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Text(
                                  oxygen
                                      ? '≤'
                                      : high
                                      ? '>'
                                      : '<',
                                  style: TextStyle(color: color, fontSize: 22),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '$value',
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        _unit(kind),
                                        style: const TextStyle(
                                          color: SaydianColors.muted,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.tune_rounded,
                                  color: SaydianColors.outline,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
        if (controller.healthReminderRingVibrationAvailable) ...[
          const SizedBox(height: 2),
          Card(
            child: SwitchListTile(
              key: const Key('reading-reminder-ring-vibration'),
              secondary: const Icon(
                Icons.vibration_rounded,
                color: SaydianColors.techViolet,
              ),
              title: Text(_copy(context, '戒指振动', 'Ring vibration')),
              value: s.ringVibrationEnabled,
              onChanged: canEdit
                  ? (value) => _save(
                      context,
                      s.copyWith(ringVibrationEnabled: value),
                      owner,
                    )
                  : null,
            ),
          ),
        ],
        if (kinds.isNotEmpty)
          Card(
            child: SwitchListTile(
              key: const Key('reading-reminder-phone-sound'),
              secondary: const Icon(
                Icons.volume_up_rounded,
                color: SaydianColors.techBlue,
              ),
              title: Text(_copy(context, '手机提示音', 'Phone alert sound')),
              subtitle: Text(
                _copy(context, '跟随手机静音和音量', 'Uses the phone’s sound settings'),
              ),
              value: s.phoneSoundEnabled,
              onChanged: canEdit
                  ? (value) => _save(
                      context,
                      s.copyWith(phoneSoundEnabled: value),
                      owner,
                    )
                  : null,
            ),
          ),
        if (kinds.isNotEmpty) ...[
          Text(
            _copy(
              context,
              '完成心率或血氧测量后提醒，不代表持续监测。',
              'Reminds after a completed heart-rate or oxygen reading. Not continuous monitoring.',
            ),
            style: const TextStyle(
              color: SaydianColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          Text(
            _copy(
              context,
              '戒指读数仅供参考；不适时及时求助。',
              'Ring readings are for reference. Seek help if you feel unwell.',
            ),
            style: const TextStyle(
              color: SaydianColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('reading-reminder-preview'),
            onPressed: controller.ringReminderVibrationBusy
                ? null
                : () => showReadingReminderPreview(
                    context,
                    kinds.isEmpty
                        ? HealthReminderKind.highHeartRate
                        : kinds.first,
                    onHelp: onHelp,
                    controller: controller,
                    vibrate:
                        controller.healthReminderRingVibrationAvailable &&
                            s.ringVibrationEnabled
                        ? () => controller.testHealthReminderRingVibration(
                            expectedOwner: owner,
                          )
                        : null,
                  ),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: Text(_copy(context, '预览提醒效果', 'Preview reminder')),
          ),
        ),
        if (kinds.isNotEmpty)
          ExpansionTile(
            title: Text(_copy(context, '参考值说明', 'About the references')),
            leading: const Icon(Icons.info_outline, size: 19),
            tilePadding: EdgeInsets.zero,
            children: [
              Text(
                _copy(
                  context,
                  [
                    if (heartRate) '120/40 bpm 为可穿戴提醒的起始参考，并非正常范围或诊断线。',
                    if (oxygen)
                      '血氧 92% 参考指夹式血氧仪居家说明，戒指异常读数请用合格指夹式血氧仪复核；严重不适立即求助。',
                  ].join('\n'),
                  [
                    if (heartRate)
                      '120/40 bpm are wearable reminder starting references, not normal ranges or diagnostic cutoffs.',
                    if (oxygen)
                      'The 92% oxygen reference comes from home finger-oximeter guidance. Confirm an unusual ring reading with a suitable finger oximeter; seek urgent help for serious symptoms.',
                  ].join('\n'),
                ),
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              Text(
                _copy(
                  context,
                  '未成年人、特殊健康状况或高海拔环境，请先咨询专业人员。',
                  'For minors, specific health conditions or high altitude, seek professional advice.',
                ),
                style: const TextStyle(
                  color: SaydianColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              Wrap(
                children: [
                  for (final source in [
                    if (heartRate)
                      (
                        '心率参考',
                        'Heart rate',
                        'https://support.apple.com/en-us/120276',
                      ),
                    if (oxygen)
                      (
                        '血氧参考',
                        'Oxygen',
                        'https://medlineplus.gov/lab-tests/pulse-oximetry/',
                      ),
                    if (oxygen)
                      (
                        '测量局限',
                        'Limitations',
                        'https://www.fda.gov/consumers/consumer-updates/pulse-oximeter-basics',
                      ),
                  ])
                    TextButton(
                      onPressed: () async {
                        try {
                          await launchUrl(
                            Uri.parse(source.$3),
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (_) {
                          /* Keep local settings usable offline. */
                        }
                      },
                      child: Text(_copy(context, source.$1, source.$2)),
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
