import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../domain/feature_models.dart';
import '../app_theme.dart';

/// 原厂敲击控制在 iPhone 上需要系统指针设置。这里只展示路径，不能读取
/// 系统开关，也不能把模式回读成功当作系统设置或实际手势已经生效。
class RingGestureIosSetup extends StatelessWidget {
  const RingGestureIosSetup({super.key});

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('gesture-ios-setup'),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            uiCopy(context, "iPhone 短视频设置"),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            uiCopy(context, "设置 → 无障碍 → 触控 → 辅助触控"),
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            uiCopy(context, "旧版 iOS 中“无障碍”名为“辅助功能”。"),
            style: TextStyle(fontSize: 13, color: SaydianColors.muted),
          ),
          const SizedBox(height: 8),
          for (final step in [
            (
              Icons.accessibility_new_rounded,
              uiCopy(context, "辅助触控"),
              uiCopy(context, "需开启"),
            ),
            (
              Icons.touch_app_outlined,
              uiCopy(context, "执行触控手势"),
              uiCopy(context, "需开启"),
            ),
            (
              Icons.speed_rounded,
              uiCopy(context, "跟踪灵敏度"),
              uiCopy(context, "调至最高"),
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(step.$1, size: 20, color: SaydianColors.techBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: step.$2),
                          TextSpan(
                            text: ' · ${step.$3}',
                            style: const TextStyle(color: SaydianColors.muted),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          const RingGestureActions(),
          const SizedBox(height: 6),
          Text(
            uiCopy(context, "请在系统中核对以上设置；部分手机、固件或 App 可能不支持。"),
            key: ValueKey('gesture-phone-compatibility'),
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: SaydianColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class RingGestureQuickStart extends StatelessWidget {
  const RingGestureQuickStart({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            uiCopy(context, "三步开始"),
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
                  for (final step in [
                    (
                      Icons.touch_app_outlined,
                      uiCopy(context, "1 选场景"),
                      uiCopy(context, "点下方卡片"),
                    ),
                    (
                      Icons.check_circle_outline_rounded,
                      uiCopy(context, "2 等确认"),
                      uiCopy(context, "确认后再操作"),
                    ),
                    (
                      Icons.open_in_new_rounded,
                      uiCopy(context, "3 去使用"),
                      uiCopy(context, "打开对应 App"),
                    ),
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
          Text(
            uiCopy(context, "效果取决于戒指、手机和目标 App，部分手机型号可能不支持。"),
            key: ValueKey('gesture-phone-compatibility'),
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: SaydianColors.muted,
            ),
          ),
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 8),
            Text(
              uiCopy(context, "若弹出蓝牙配对请求，核对是当前戒指后再确认。"),
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

/// 操作提示只读。不同固件支持的动作可不同，不把动作说明当成能力回包。
class RingGestureActions extends StatelessWidget {
  const RingGestureActions({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final action in [
        (
          Icons.waving_hand_outlined,
          uiCopy(context, "晃动手指"),
          uiCopy(context, "轻晃佩戴戒指的手指"),
        ),
        (
          Icons.touch_app_outlined,
          uiCopy(context, "双击戒指"),
          uiCopy(context, "连续轻敲戒指两下"),
        ),
      ])
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(action.$1, color: SaydianColors.techBlue),
          title: Text(action.$2),
          subtitle: Text(action.$3),
        ),
      Text(
        uiCopy(context, "打开短视频 App，尝试戒指支持的动作。"),
        style: TextStyle(fontSize: 14, height: 1.4),
      ),
    ],
  );
}

/// Read-only instructions. Opening this guide never pairs a device, grants a
/// permission or changes its gesture mode. OEM touch mappings vary by firmware.
class RingGestureGuide extends StatelessWidget {
  const RingGestureGuide({this.tapControl = false, super.key});

  /// 来自当前连接的真实控制类型；不按蓝牙名称推广至其他通道／触摸固件。
  final bool tapControl;

  static String modeHint(int mode) => switch (mode) {
    0 => uiCopy(null, "用完后关闭，避免误操作和额外耗电"),
    1 => uiCopy(null, "打开支持的短视频 App，再按戒指说明操作"),
    2 => uiCopy(null, "打开音乐播放器，再按戒指说明操作"),
    3 => uiCopy(null, "打开支持翻页的阅读 App，再按戒指说明操作"),
    4 => uiCopy(
      null,
      "尝试控制系统相机；App 内拍照请用“{p0}”",
      parameters: [uiCopy(null, DeviceFeature.camera.label)],
    ),
    5 => uiCopy(null, "按戒指说明控制支持的通话，不等于开启来电提醒"),
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
      title: Text(uiCopy(context, "使用说明")),
      subtitle: Text(uiCopy(context, "手势怎么做？没有反应怎么办？")),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuideSection(uiCopy(context, "操作方法"), [
          uiCopy(context, "晃动手指或双击戒指，具体动作以戒指支持为准。"),
          uiCopy(
            context,
            "App 内拍照：到设备页打开“{p0}”，允许相机与照片保存权限，并保持拍照页在前台。",
            parameters: [uiCopy(null, DeviceFeature.camera.label)],
          ),
          uiCopy(context, "用完可选择“关闭”，减少误操作。"),
        ]),
        if (defaultTargetPlatform == TargetPlatform.iOS)
          _GuideSection(uiCopy(context, "iPhone 短视频设置"), [
            uiCopy(
              context,
              "设置 → 无障碍（旧版称“辅助功能”）→ 触控 → 辅助触控。开启“辅助触控”和“执行触控手势”，将“跟踪灵敏度”调至最高。",
            ),
            uiCopy(context, "设置完成后，打开短视频 App 试用。"),
          ]),
        _GuideSection(uiCopy(context, "阅读翻页"), [
          uiCopy(context, "若阅读 App 提供“音量键翻页”，请先开启；部分 App 还需要切换翻页方式。"),
        ]),
        _GuideSection(uiCopy(context, "没有反应？"), [
          uiCopy(context, "先确认戒指仍已连接、场景已确认，目标 App 在前台。"),
          uiCopy(
            context,
            "到{p0}“设置 → 蓝牙”确认配对；出现请求时，选择当前戒指。",
            parameters: [phone],
          ),
          uiCopy(context, "若戒指连接了其他手机或戒指 App，先断开那边。"),
          uiCopy(context, "仍无反应时关闭模式再重选。部分手机、固件或 App 不支持手势控制。"),
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
