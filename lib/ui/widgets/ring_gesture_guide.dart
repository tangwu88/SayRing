import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Read-only instructions. Opening this guide never pairs a device, grants a
/// permission or changes its gesture mode. OEM touch mappings vary by firmware.
class RingGestureGuide extends StatelessWidget {
  const RingGestureGuide({this.isLuckRing = false, super.key});

  final bool isLuckRing;

  static String modeHint(int mode) => switch (mode) {
    0 => '用完后关闭，避免误操作和额外耗电',
    1 => '滑屏控制：确认模式后打开兼容的短视频 App，滑动方向以戒指固件为准',
    2 => '选择后进入音乐播放页，再操作戒指',
    3 => '选择后打开阅读页；翻页取决于阅读 App 支持',
    4 => '系统相机控制取决于固件；App 内拍照请用“摇一摇拍照”',
    5 => '电话控制取决于固件和系统配对，不等于开启来电提醒',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final phone = defaultTargetPlatform == TargetPlatform.iOS
        ? 'iPhone'
        : '安卓手机';
    return ExpansionTile(
      key: const ValueKey('ring-gesture-guide'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      leading: const Icon(Icons.help_outline_rounded),
      title: const Text('使用说明'),
      subtitle: const Text('配对准备 · 操作方法 · 无反应排查'),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuideSection('使用前', [
          '1. 戒指靠近$phone，先确认设备页显示“已连接”。',
          '2. 若手机弹出蓝牙配对请求，核对是这枚戒指后点“配对”。App 已连接不代表系统配对已完成。',
          '3. 选择下方模式，等指令确认后，再打开对应 App 操作戒指。',
        ]),
        _GuideSection('滑屏控制', [
          '开启“滑屏控制”会切换到短视频模式；读取或指令确认失败时不会标记成功。',
          '触控款佩戴时让内侧传感器贴合皮肤，保持戒指与手机靠近。',
          if (isLuckRing) 'LuckRing 参考页展示向上手势切换下一条视频；该示例不代表所有型号都使用相同动作。',
          '向下或上一条是否可用，需按当前戒指固件及目标 App 实测，不能据此保证任意页面的双向控制。',
          '先完成本页设置，再切换到目标 App（例如兼容的短视频页面）。选择其他模式会退出滑屏模式。',
        ]),
        const _GuideSection('操作方法', [
          '不同型号的触控次数和手势动作不同，请按当前戒指的原厂说明操作；不要把触控款用法套到其他型号。',
          'App 内拍照：返回设备功能，打开“摇一摇拍照”，允许相机与照片保存权限，保持拍照页在前台。',
          '用完后回到这里选择“关闭”。',
        ]),
        _GuideSection('没有反应？', [
          '先确认仍已连接、模式指令已确认，目标 App 正在前台。',
          '在$phone“设置 → 蓝牙”检查戒指配对状态；同时断开其他手机或 LuckRing 等 App 的连接。',
          '仍无反应时关闭模式再重选。效果受戒指固件、手机系统和目标 App 兼容性限制，不支持所有 App。',
        ]),
      ],
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection(this.title, this.steps);
  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        for (final step in steps)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(step)),
      ],
    ),
  );
}
