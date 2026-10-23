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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
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
                    (Icons.bluetooth_connected_rounded, '连接戒指', '确认已连接'),
                    (Icons.touch_app_outlined, '选择场景', '等待指令确认'),
                    (Icons.open_in_new_rounded, '打开 App', '按原厂手势操作'),
                  ])
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            step.$1,
                            color: SaydianColors.techBlue,
                            size: 25,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            step.$2,
                            style: const TextStyle(
                              fontSize: 17,
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
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 12),
            const Text(
              '首次开启时如手机弹出蓝牙配对请求，请核对戒指后确认。系统配对完成后仍需等待模式指令确认。',
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
    1 => '选择后打开支持的短视频 App，再操作戒指',
    2 => '选择后进入音乐播放页，再操作戒指',
    3 => '选择后打开阅读页；翻页取决于阅读 App 支持',
    4 => '系统相机控制取决于固件；App 内拍照请用“${DeviceFeature.camera.label}”',
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
      subtitle: const Text('操作细节与无反应排查'),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuideSection('使用前', [
          '1. 戒指靠近$phone，先确认设备页显示“已连接”。',
          '2. 若手机弹出蓝牙配对请求，核对是这枚戒指后点“配对”。App 已连接不代表系统配对已完成。',
          '3. 选择下方模式，等指令确认后，再打开对应 App 操作戒指。',
        ]),
        _GuideSection('操作方法', [
          '不同型号的触控次数和手势动作不同，请按当前戒指的原厂说明操作；不要把触控款用法套到其他型号。',
          'App 内拍照：返回设备功能，打开“${DeviceFeature.camera.label}”，允许相机与照片保存权限，保持拍照页在前台。',
          '用完后回到这里选择“关闭”。',
        ]),
        _GuideSection('没有反应？', [
          '先确认仍已连接、模式指令已确认，目标 App 正在前台。',
          '在$phone“设置 → 蓝牙”检查戒指配对状态；同时断开其他手机或其他戒指 App 的连接。',
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
