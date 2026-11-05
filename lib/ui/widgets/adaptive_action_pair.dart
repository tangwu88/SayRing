import 'package:flutter/material.dart';

/// 文本放大或空间不足时，上下排列输入和操作，避免标签、电话号码被挤成竖排。
class AdaptiveActionPair extends StatelessWidget {
  const AdaptiveActionPair({
    required this.leading,
    required this.action,
    this.equalWidth = false,
    this.minInlineWidth = 300,
    super.key,
  });
  final Widget leading;
  final Widget action;
  final bool equalWidth;
  final double minInlineWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaled = MediaQuery.textScalerOf(context).scale(16) / 16;
      if (box.maxWidth < minInlineWidth * scaled.clamp(1.0, 3.0)) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [leading, const SizedBox(height: 8), action],
        );
      }
      return Row(
        children: [
          Expanded(child: leading),
          const SizedBox(width: 10),
          if (equalWidth) Expanded(child: action) else action,
        ],
      );
    },
  );
}

/// 同意项在大字或窄屏时各占一行，点击区域不因重排而缩小。
class AdaptiveChoiceRow extends StatelessWidget {
  const AdaptiveChoiceRow({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (children.length == 1 ||
          box.maxWidth <
              290 * MediaQuery.textScalerOf(context).scale(14) / 14) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      }
      return Row(
        children: [for (final item in children) Expanded(child: item)],
      );
    },
  );
}
