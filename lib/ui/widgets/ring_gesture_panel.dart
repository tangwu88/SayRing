import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../app_theme.dart';
import 'ring_gesture_guide.dart';

/// Presentation only. Mode support and confirmation come from the connected
/// device; tapping a card still uses the controller's guarded write path.
class RingGesturePanel extends StatelessWidget {
  const RingGesturePanel({
    required this.availableModes,
    required this.confirmedMode,
    required this.ready,
    required this.busy,
    required this.requiresReconnect,
    required this.readbackConfirmed,
    required this.onRefresh,
    required this.onSelect,
    this.onReconnect,
    this.error,
    this.needsStrength = false,
    this.selectedStrength,
    this.onStrengthChanged,
    this.onStop,
    this.uncertainControl = false,
    this.tapControl = false,
    this.preparingControl = false,
    this.waitingForIdle = false,
    this.syncingData = false,
    super.key,
  });

  final Set<int> availableModes;
  final int? confirmedMode;
  final bool ready, busy, requiresReconnect, readbackConfirmed;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback? onReconnect;
  final ValueChanged<int> onSelect;
  final bool needsStrength;
  final int? selectedStrength;
  final ValueChanged<int>? onStrengthChanged;
  final VoidCallback? onStop;
  final bool uncertainControl;
  final bool tapControl;
  final bool preparingControl, waitingForIdle, syncingData;

  static final modes = <(int, String, IconData, String)>[
    (
      0,
      uiCopy(null, "关闭"),
      Icons.power_settings_new_rounded,
      uiCopy(null, "暂停手势控制"),
    ),
    (
      1,
      uiCopy(null, "短视频"),
      Icons.play_circle_outline_rounded,
      uiCopy(null, "打开短视频 App"),
    ),
    (2, uiCopy(null, "音乐"), Icons.headphones_rounded, uiCopy(null, "打开音乐播放器")),
    (
      3,
      uiCopy(null, "阅读"),
      Icons.auto_stories_outlined,
      uiCopy(null, "打开阅读 App"),
    ),
    (4, uiCopy(null, "拍照"), Icons.camera_alt_outlined, uiCopy(null, "系统相机控制")),
    (
      5,
      uiCopy(null, "电话"),
      Icons.phone_in_talk_outlined,
      uiCopy(null, "支持的通话控制"),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = modes.where((m) => m.$1 == confirmedMode).firstOrNull;
    final strengthReady =
        !needsStrength ||
        (selectedStrength != null &&
            selectedStrength! >= 1 &&
            selectedStrength! <= 10);
    final enabled = ready && !busy && !requiresReconnect && strengthReady;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onStop != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              key: const ValueKey('gesture-stop-control'),
              onPressed: busy ? null : onStop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(uiCopy(context, "关闭手势控制")),
            ),
          ),
        if (uncertainControl)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              uiCopy(context, "控制状态待确认，之前开启的控制可能仍在生效。请先关闭，或在系统蓝牙中暂时断开戒指。"),
              style: TextStyle(color: SaydianColors.danger),
            ),
          ),
        Container(
          key: const ValueKey('gesture-current-mode'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SaydianColors.midnight,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected?.$3 ?? Icons.touch_app_outlined,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uiCopy(context, "当前模式"),
                          style: TextStyle(
                            color: Color(0xFFCDD9E3),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preparingControl
                              ? uiCopy(context, "正在准备手势控制")
                              : syncingData
                              ? uiCopy(context, "正在同步戒指数据")
                              : waitingForIdle
                              ? uiCopy(context, "等待设备空闲")
                              : uncertainControl
                              ? uiCopy(context, "控制状态待确认")
                              : requiresReconnect
                              ? uiCopy(context, "控制状态待恢复")
                              : !ready
                              ? uiCopy(context, "等待读取")
                              : selected?.$2 ??
                                    (confirmedMode == -1
                                        ? uiCopy(context, "其他模式")
                                        : uiCopy(context, "尚未确认")),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preparingControl
                              ? uiCopy(context, "正在恢复控制连接，请稍候")
                              : syncingData
                              ? uiCopy(context, "同步完成后即可设置手势")
                              : waitingForIdle
                              ? uiCopy(context, "当前操作结束后会准备控制连接")
                              : requiresReconnect
                              ? uiCopy(context, "手势设置尚未确认")
                              : busy
                              ? uiCopy(context, "正在与戒指确认…")
                              : !ready
                              ? uiCopy(context, "读取后即可选择")
                              : readbackConfirmed
                              ? uiCopy(context, "已从戒指读取")
                              : selected != null
                              ? uiCopy(context, "本次连接指令已确认")
                              : uiCopy(context, "选择一个使用场景"),
                          style: const TextStyle(
                            color: Color(0xFFCDD9E3),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (enabled &&
                  !uncertainControl &&
                  selected != null &&
                  selected.$1 != 0) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0x335F7B8E), height: 1),
                const SizedBox(height: 12),
                Text(
                  RingGestureGuide.modeHint(selected.$1),
                  key: const ValueKey('gesture-next-step'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // iPhone 系统准备适用于两类手势，不按供应商或敲击类型遗漏入口。
        // 仍须当前模式真实确认；说明本身不写系统开关或戒指参数。
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            enabled &&
            !uncertainControl &&
            confirmedMode == 1 &&
            availableModes.contains(1))
          const RingGestureIosSetup()
        else
          const RingGestureQuickStart(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                uiCopy(context, "选择场景"),
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('gesture-refresh'),
              onPressed: busy
                  ? null
                  : requiresReconnect
                  ? onReconnect
                  : onRefresh,
              icon: Icon(
                requiresReconnect
                    ? Icons.bluetooth_connected_rounded
                    : Icons.refresh_rounded,
                size: 20,
              ),
              label: Text(
                requiresReconnect
                    ? uiCopy(context, "恢复控制")
                    : uiCopy(context, "刷新状态"),
              ),
            ),
          ],
        ),
        if (!ready || requiresReconnect)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              syncingData
                  ? uiCopy(context, "数据同步完成后即可设置手势，请保持戒指靠近手机。")
                  : (preparingControl || waitingForIdle)
                  ? uiCopy(context, "请保持戒指靠近手机，准备过程中不需要重新选择场景。")
                  : error ??
                        (requiresReconnect
                            ? uiCopy(context, "恢复控制后再设置手势")
                            : busy
                            ? uiCopy(context, "正在读取手势设置")
                            : uiCopy(context, "暂未读到手势设置，请刷新重试")),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        if (needsStrength)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<int>(
              key: const ValueKey('gesture-strength'),
              initialValue: selectedStrength,
              decoration: InputDecoration(
                labelText: uiCopy(context, "手势力度"),
                helperText: uiCopy(context, "先选力度，再选场景"),
                helperMaxLines: 2,
              ),
              hint: Text(uiCopy(context, "请选择1～10")),
              items: [
                for (var value = 1; value <= 10; value++)
                  DropdownMenuItem(value: value, child: Text('$value')),
              ],
              onChanged: ready && !busy && !requiresReconnect
                  ? (value) {
                      if (value != null) onStrengthChanged?.call(value);
                    }
                  : null,
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns =
                constraints.maxWidth >= 300 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.5;
            final width = twoColumns
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final mode in modes)
                  if (availableModes.contains(mode.$1))
                    SizedBox(
                      width: width,
                      child: Semantics(
                        selected: confirmedMode == mode.$1,
                        button: true,
                        enabled: enabled,
                        child: Material(
                          color: confirmedMode == mode.$1
                              ? SaydianColors.techBlueSoft
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: confirmedMode == mode.$1
                                  ? SaydianColors.techBlue
                                  : SaydianColors.line,
                              width: confirmedMode == mode.$1 ? 1.5 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: ValueKey('gesture-mode-${mode.$1}'),
                            onTap: enabled ? () => onSelect(mode.$1) : null,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        mode.$3,
                                        size: 30,
                                        color: SaydianColors.techBlue,
                                      ),
                                      const Spacer(),
                                      if (confirmedMode == mode.$1)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: SaydianColors.techBlue,
                                          size: 22,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    mode.$2,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode.$4,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: SaydianColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
        if (ready && confirmedMode == -1)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(uiCopy(context, "选择场景会替换戒指当前的控制模式。")),
          ),
        if (ready && availableModes.length == 1)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(uiCopy(context, "暂时只能关闭手势。")),
          ),
        const SizedBox(height: 12),
        RingGestureGuide(tapControl: tapControl),
      ],
    );
  }
}
