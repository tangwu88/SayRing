import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/cycle_diary_scenario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final proof = Directory(
    '${Directory.systemTemp.path}/sayring-cycle-1247-final',
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'cycle diary, actual phone viewport $scale',
      (t) async {
        final boundary = GlobalKey();
        await exerciseCycleDiary(
          t,
          scale,
          boundary: boundary,
          capture: (name) async {
            await t.runAsync(() async {
              await proof.create(recursive: true);
              final box =
                  boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final im = await box.toImage(pixelRatio: 1.5);
              try {
                final png = (await im.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                await File(
                  '${proof.path}/${scale.toInt()}-$name.png',
                ).writeAsBytes(
                  png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
                  flush: true,
                );
              } finally {
                im.dispose();
              }
            });
          },
        );
        await t.runAsync(
          () => File(
            '${proof.path}/${scale.toInt()}-pass',
          ).writeAsString('synthetic diary flow passed', flush: true),
        );
        debugPrint('CYCLE_DIARY_DEVICE_PASS scale=$scale');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
