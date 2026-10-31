import 'package:flutter/material.dart';

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
    super.key,
  });

  final Set<int> availableModes;
  final int? confirmedMode;
  final bool ready, busy, requiresReconnect, readbackConfirmed;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback? onReconnect;
  final ValueChanged<int> onSelect;

  static const modes = <(int, String, IconData, String)>[
    (0, '关闭', Icons.power_settings_new_rounded, '暂停手势控制'),
    (1, '短视频', Icons.play_circle_outline_rounded, '打开短视频 App'),
    (2, '音乐', Icons.headphones_rounded, '打开音乐播放器'),
    (3, '阅读', Icons.auto_stories_outlined, '打开阅读 App'),
    (4, '拍照', Icons.camera_alt_outlined, '系统相机控制'),
    (5, '电话', Icons.phone_in_talk_outlined, '支持的通话控制'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = modes.where((m) => m.$1 == confirmedMode).firstOrNull;
    final enabled = ready && !busy && !requiresReconnect;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                        const Text(
                          '当前模式',
                          style: TextStyle(
                            color: Color(0xFFCDD9E3),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          requiresReconnect
                              ? '需要重新连接'
                              : !ready
                              ? '等待读取'
                              : selected?.$2 ??
                                    (confirmedMode == -1 ? '其他模式' : '尚未确认'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          requiresReconnect
                              ? '请重新连接戒指'
                              : busy
                              ? '正在与戒指确认…'
                              : !ready
                              ? '读取后即可选择'
                              : readbackConfirmed
                              ? '已从戒指读取'
                              : selected != null
                              ? '本次连接指令已确认'
                              : '选择一个使用场景',
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
              if (enabled && selected != null && selected.$1 != 0) ...[
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
        const RingGestureQuickStart(),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                '选择场景',
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
              label: Text(requiresReconnect ? '重新连接' : '刷新状态'),
            ),
          ],
        ),
        if (!ready || requiresReconnect)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              error ??
                  (requiresReconnect
                      ? '重新连接后再设置手势'
                      : busy
                      ? '正在读取手势设置'
                      : '暂未读到手势设置，请刷新重试'),
              style: const TextStyle(fontSize: 16),
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
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('选择场景会替换戒指当前的控制模式。'),
          ),
        if (ready && availableModes.length == 1)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('戒指尚未上报可开启的控制模式，目前仅可关闭。'),
          ),
        const SizedBox(height: 12),
        const RingGestureGuide(),
      ],
    );
  }
}
