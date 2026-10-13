import 'package:flutter/material.dart';

class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    required this.icon,
    required this.color,
    this.compact = false,
    this.legal = false,
    this.centered = false,
    this.onTap,
  });

  final String message;
  final IconData icon;
  final Color color;
  final bool compact;
  final bool legal;
  final bool centered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final padding = legal || compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.all(14);
    final borderRadius = BorderRadius.circular(compact || legal ? 10 : 14);
    final decoration = BoxDecoration(
      color: color.withValues(alpha: legal ? 0.05 : 0.08),
      border: Border.all(color: color.withValues(alpha: legal ? 0.15 : 0.24)),
      borderRadius: borderRadius,
    );
    final text = Text(
      message,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: color,
        fontSize: centered
            ? 15
            : legal
            ? 12
            : compact
            ? 12.5
            : null,
        fontWeight: centered ? FontWeight.w600 : null,
        height: centered
            ? 1.35
            : legal
            ? 1.4
            : compact
            ? 1.3
            : 1.45,
      ),
    );
    final content = Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: compact || legal ? 16 : 20),
        SizedBox(width: compact || legal ? 7 : 10),
        if (centered) Flexible(child: text) else Expanded(child: text),
      ],
    );
    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: decoration,
        child: content,
      );
    }
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Padding(padding: padding, child: content),
          ),
        ),
      ),
    );
  }
}
