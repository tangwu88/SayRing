import 'package:flutter/material.dart';

/// A shortcut to the vendor's short-video mode, not a global input injector.
/// Its value is exclusively supplied by the existing command/readback path.
class RingScreenScrollControl extends StatelessWidget {
  const RingScreenScrollControl({
    required this.supported,
    required this.ready,
    required this.busy,
    required this.requiresReconnect,
    required this.confirmedMode,
    required this.onChanged,
    this.onPractice,
    super.key,
  });

  final bool supported;
  final bool ready;
  final bool busy;
  final bool requiresReconnect;
  final int? confirmedMode;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onPractice;

  @override
  Widget build(BuildContext context) {
    final enabled =
        !requiresReconnect && ready && supported && confirmedMode == 1;
    final status = requiresReconnect
        ? '重新连接后才能设置滑屏控制'
        : busy
        ? '正在设置，请留意系统配对提示，勿重复操作'
        : !ready
        ? '尚未读到手势设置，请刷新后重试'
        : !supported
        ? '当前戒指未上报短视频滑屏控制能力'
        : confirmedMode == null || confirmedMode == -1
        ? '当前模式尚未确认；开启后等待戒指确认'
        : enabled
        ? '短视频模式已确认，请到目标 App 验证滑动效果'
        : '滑屏模式未启用；开启将切换当前控制模式';
    return Column(
      key: const ValueKey('ring-screen-scroll-control'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '屏幕上下滑动',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('使用戒指的短视频模式，在支持的 App 中控制页面滑动。'),
        SwitchListTile.adaptive(
          key: const ValueKey('gesture-scroll-toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('开启滑屏控制'),
          subtitle: Text(status),
          value: enabled,
          onChanged: busy || !ready || !supported || requiresReconnect
              ? null
              : onChanged,
        ),
        if (onPractice != null)
          OutlinedButton.icon(
            key: const ValueKey('gesture-scroll-practice'),
            onPressed: enabled && !busy ? onPractice : null,
            icon: const Icon(Icons.swipe_vertical_rounded),
            label: const Text('滑屏练习'),
          ),
        const Text(
          '如出现系统配对请求，请核对当前戒指并确认，再打开目标 App。方向和动作取决于戒指固件；不保证所有 App 或双向滑动均可用。',
          style: TextStyle(fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 16),
        const Divider(),
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
