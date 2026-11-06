import 'package:flutter/material.dart';

/// 常驻页面只保留入口；完整用途说明按需打开，不影响原有同意和能力判断。
class UsageInfoButton extends StatelessWidget {
  const UsageInfoButton({
    super.key,
    required this.message,
    this.title,
    this.iconOnly = false,
  });

  final String message;
  final String? title;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final label = title ?? (zh ? '健康数据说明' : 'About health data');
    void open() => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(height: 1.55)),
              const SizedBox(height: 20),
              OutlinedButton(
                key: const Key('usage-info-close'),
                onPressed: () => Navigator.pop(sheet),
                child: Text(zh ? '关闭' : 'Close'),
              ),
            ],
          ),
        ),
      ),
    );
    if (iconOnly) {
      return IconButton(
        tooltip: label,
        icon: const Icon(Icons.info_outline_rounded),
        onPressed: open,
      );
    }
    return TextButton.icon(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      icon: const Icon(Icons.info_outline_rounded, size: 18),
      label: Text(label, textAlign: TextAlign.center),
      onPressed: open,
    );
  }
}
