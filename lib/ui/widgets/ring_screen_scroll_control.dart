import 'package:flutter/material.dart';

/// Vendor control settings, never a global input injector. A sent setting is
/// displayed separately from a device-confirmed setting.
class RingScreenScrollControl extends StatelessWidget {
  const RingScreenScrollControl({
    required this.supported,
    required this.ready,
    required this.busy,
    required this.requiresReconnect,
    required this.confirmedMode,
    required this.onChanged,
    this.onPractice,
    this.sentMode,
    this.modes = const {1: '短视频'},
    this.onModeChanged,
    this.onGuide,
    super.key,
  });

  final bool supported;
  final bool ready;
  final bool busy;
  final bool requiresReconnect;
  final int? confirmedMode;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onPractice;
  final int? sentMode;
  final Map<int, String> modes;
  final ValueChanged<int>? onModeChanged;
  final VoidCallback? onGuide;

  @override
  Widget build(BuildContext context) {
    final selectedMode = confirmedMode ?? sentMode;
    final enabled =
        !requiresReconnect &&
        ready &&
        supported &&
        selectedMode != null &&
        selectedMode > 0;
    final canWrite = !busy && ready && supported && !requiresReconnect;
    final unconfirmed = confirmedMode == null && sentMode != null;
    final status = requiresReconnect
        ? '重新连接后才能设置滑屏控制'
        : busy
        ? '正在设置，请留意系统配对提示，勿重复操作'
        : !ready
        ? '尚未读到手势设置，请刷新后重试'
        : !supported
        ? '当前戒指未上报短视频滑屏控制能力'
        : unconfirmed
        ? '已发送${sentMode == 0 ? '关闭' : '开启'}指令，戒指状态未确认；请实测效果，可再次设置'
        : confirmedMode == null || confirmedMode == -1
        ? '当前模式尚未确认；开启后等待戒指确认'
        : enabled
        ? '控制模式已确认，请到目标 App 验证效果'
        : '滑屏模式未启用；开启将切换当前控制模式';
    return Column(
      key: const ValueKey('ring-screen-scroll-control'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                key: const ValueKey('gesture-scroll-toggle'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                title: const Text(
                  '手势控制',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(status),
                value: enabled,
                onChanged: canWrite ? onChanged : null,
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              for (final entry in modes.entries)
                ListTile(
                  key: ValueKey('gesture-mode-${entry.key}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer,
                    child: Icon(switch (entry.key) {
                      1 => Icons.play_arrow_rounded,
                      2 => Icons.music_note_rounded,
                      3 => Icons.menu_book_rounded,
                      4 => Icons.camera_alt_rounded,
                      _ => Icons.call_rounded,
                    }),
                  ),
                  title: Text(entry.value),
                  trailing: selectedMode == entry.key
                      ? Icon(
                          unconfirmed
                              ? Icons.schedule_rounded
                              : Icons.check_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : const Icon(Icons.radio_button_unchecked_rounded),
                  onTap: canWrite && onModeChanged != null
                      ? () => onModeChanged!(entry.key)
                      : null,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 18),
          child: Text(
            '开启后会增加耗电，并可能占用其他触摸功能。请使用与所选模式对应的 App，避免误操作。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (onGuide != null)
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('gesture-guide-entry'),
              leading: const Icon(Icons.gesture_rounded),
              title: const Text('手势说明'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onGuide,
            ),
          ),
        if (onPractice != null)
          OutlinedButton.icon(
            key: const ValueKey('gesture-scroll-practice'),
            onPressed: enabled && selectedMode == 1 && !busy
                ? onPractice
                : null,
            icon: const Icon(Icons.swipe_vertical_rounded),
            label: const Text('滑屏练习'),
          ),
        const Text(
          '如出现系统配对请求，请核对当前戒指并确认，再打开目标 App。方向和动作取决于戒指固件；不保证所有 App 或双向滑动均可用。',
          style: TextStyle(fontSize: 12, height: 1.6),
        ),
      ],
    );
  }
}

/// Read-only observation surface. No synthetic gestures or automatic verdict.
class RingScreenScrollPracticePage extends StatelessWidget {
  const RingScreenScrollPracticePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('滑屏练习')),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '保持系统蓝牙配对，用戒指操作下方卡片。观察编号是否变化，再分别尝试反方向；无反应不代表已通过。实际目标 App 仍需单独验证。',
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: const ValueKey('gesture-scroll-practice-list'),
            padding: const EdgeInsets.all(16),
            itemCount: 20,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) => Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 48,
                  horizontal: 16,
                ),
                child: Text(
                  '练习卡片 ${index + 1}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
