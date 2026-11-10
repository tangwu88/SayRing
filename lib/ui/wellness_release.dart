import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:flutter/material.dart';

/// Stable destination for saved routes that are outside this release's scope.
/// Existing records remain stored; the restricted release does not expose them.
class WellnessReleaseUnavailablePage extends StatelessWidget {
  const WellnessReleaseUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(uiCopy(context, "功能暂未开放"))),
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          uiCopy(context, "此功能暂未开放，已有记录仍保留。"),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
