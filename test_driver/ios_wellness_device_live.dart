import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';

Future<void> capture(FlutterDriver driver, String name) async {
  await Future<void>.delayed(const Duration(seconds: 2));
  await File('.build/$name.png').writeAsBytes(await driver.screenshot());
}

Future<void> main() async {
  final driver = await FlutterDriver.connect(
    printCommunication: false,
    logCommunicationToFile: false,
  );
  try {
    // Loading indicators and reconnecting devices legitimately animate.
    await driver.runUnsynchronized(() async {
      Map state = const {};
      for (var attempt = 0; attempt < 60; attempt++) {
        state = jsonDecode(await driver.requestData('status')) as Map;
        if (state['ready'] == true) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      stdout.writeln(jsonEncode(state));
      if (state['authenticated'] != true ||
          state['wellnessOnly'] != true ||
          state['restrictedVisible'] != false ||
          state['sleepAiEnabled'] != false ||
          state['alertsAvailable'] != false) {
        throw StateError('The existing production account/scope did not pass.');
      }
      await driver.waitFor(find.byValueKey('home-sleep-overview-entry'));
      await driver.tap(find.byValueKey('home-sleep-overview-entry'));
      await driver.waitFor(find.byValueKey('sleep-overview-page'));
      await capture(driver, 'sayring-1062-real-sleep');
      await driver.tap(find.byType('BackButton'));
      await driver.tap(find.text('设备'));
      await capture(driver, 'sayring-1062-device-private');
      await driver.tap(find.text('我的'));
      await driver.scrollIntoView(find.text('关于 Say Ring'));
      await driver.tap(find.text('关于 Say Ring'));
      await capture(driver, 'sayring-1062-about-production');
      stdout.writeln('Real account, sleep, device and About pages inspected.');
    });
  } finally {
    await driver.close();
  }
}
