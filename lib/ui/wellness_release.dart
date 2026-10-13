import 'package:flutter/material.dart';

/// Stable destination for saved routes that are outside this release's scope.
/// Existing records remain stored; the restricted release does not expose them.
class WellnessReleaseUnavailablePage extends StatelessWidget {
  const WellnessReleaseUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('活动与睡眠')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('此版本提供活动和睡眠记录。', textAlign: TextAlign.center),
      ),
    ),
  );
}
