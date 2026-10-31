import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../domain/feature_models.dart';
import '../app_theme.dart';

class RingGestureQuickStart extends StatelessWidget {
  const RingGestureQuickStart({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '三步开始',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 270 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final width = stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final step in const [
                    (Icons.touch_app_outlined, '1 选场景', '点下方卡片'),
                    (Icons.check_circle_outline_rounded, '2 等确认', '确认后再操作'),
                    (Icons.open_in_new_rounded, '3 去使用', '打开对应 App'),
                  ])
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            step.$1,
                            color: SaydianColors.techBlue,
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.$2,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            step.$3,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: SaydianColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            '效果取决于戒指、手机和目标 App，部分手机型号可能不支持。',
            key: ValueKey('gesture-phone-compatibility'),
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: SaydianColors.muted,
            ),
          ),
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 8),
            const Text(
              '若弹出蓝牙配对请求，核对是当前戒指后再确认。',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SaydianColors.muted,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Read-only instructions. Opening this guide never pairs a device, grants a
/// permission or changes its gesture mode. OEM touch mappings vary by firmware.
class RingGestureGuide extends StatelessWidget {
  const RingGestureGuide({super.key});

  static String modeHint(int mode) => switch (mode) {
    0 => '用完后关闭，避免误操作和额外耗电',
    1 => '打开支持的短视频 App，再按戒指说明操作',
    2 => '打开音乐播放器，再按戒指说明操作',
    3 => '打开支持翻页的阅读 App，再按戒指说明操作',
    4 => '尝试控制系统相机；App 内拍照请用“${DeviceFeature.camera.label}”',
    5 => '按戒指说明控制支持的通话，不等于开启来电提醒',
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
      subtitle: const Text('手势怎么做？没有反应怎么办？'),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuideSection('操作方法', [
          '按这枚戒指的说明操作。不同型号的触控次数和动作可能不同。',
          'App 内拍照：到设备页打开“${DeviceFeature.camera.label}”，允许相机与照片保存权限，并保持拍照页在前台。',
          '用完可选择“关闭”，减少误操作。',
        ]),
        _GuideSection('没有反应？', [
          '先确认戒指仍已连接、场景已确认，目标 App 在前台。',
          '在$phone“设置 → 蓝牙”检查配对。App 已连接不代表系统配对已完成；若弹出配对请求，请核对这枚戒指后确认。',
          '若戒指连接了其他手机或戒指 App，先断开那边。',
          '仍无反应时关闭模式再重选。部分手机、固件或 App 不支持手势控制。',
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
