import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'app_theme.dart';

class DeviceSdkBadge extends StatelessWidget {
  const DeviceSdkBadge({required this.source, this.compact = false, super.key});

  final WearableSdkSource source;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (source) {
      WearableSdkSource.veepoo => SaydianColors.blue,
      WearableSdkSource.yucheng => SaydianColors.green,
      WearableSdkSource.unknown => SaydianColors.muted,
    };
    final label = switch (source) {
      WearableSdkSource.veepoo => compact ? 'Vep' : 'Vep 设备服务',
      WearableSdkSource.yucheng => compact ? 'Yuc' : 'Yuc 设备服务',
      WearableSdkSource.unknown => compact ? '设备' : '通用设备服务',
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 9,
            vertical: compact ? 3 : 4,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
