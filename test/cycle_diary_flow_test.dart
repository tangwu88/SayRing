import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/cycle_diary_scenario.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('按天记录、取消、月历和未来日期，字号 $scale', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(360, 760);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await exerciseCycleDiary(t, scale);
    });
  }
}
