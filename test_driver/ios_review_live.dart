import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final config =
      jsonDecode(
            await File(
              '.build/review-1060-auth-defines-private.json',
            ).readAsString(),
          )
          as Map;
  final driver = await FlutterDriver.connect(
    printCommunication: false,
    logCommunicationToFile: false,
  );
  try {
    await driver.runUnsynchronized(() async {
      final capability =
          jsonDecode(await driver.requestData('capability')) as Map;
      stdout.writeln(jsonEncode(capability));
      if (capability['loaded'] != true) {
        throw StateError('The real iPhone capability request did not pass.');
      }
      await driver.waitFor(find.byValueKey('global-code-login-page'));
      await driver.waitFor(find.byValueKey('code-login-register'));
      await driver.tap(find.text('邮箱'));
      await driver.waitFor(find.byValueKey('email-login-password'));
      // Native/network work runs on the normal app clock in this target.
      await Future<void>.delayed(const Duration(seconds: 3));
      await File(
        '.build/sayring-1062-login-live.png',
      ).writeAsBytes(await driver.screenshot());
      await driver.tap(find.byValueKey('code-login-contact'));
      await driver.enterText(config['SAYRING_QA_REVIEW_EMAIL'] as String);
      await driver.tap(find.byValueKey('email-login-password'));
      await driver.enterText(config['SAYRING_QA_REVIEW_PASSWORD'] as String);
      for (final key in [
        'code-login-minimum-age',
        'code-login-consent',
        'code-login-submit',
      ]) {
        await driver.scrollIntoView(find.byValueKey(key));
        await driver.tap(find.byValueKey(key));
      }
      Map state = const {};
      for (var attempt = 0; attempt < 40; attempt++) {
        state = jsonDecode(await driver.requestData('status')) as Map;
        if (state['authenticated'] == true && state['profilePresent'] == true) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      stdout.writeln(jsonEncode(state));
      if (state['authenticated'] != true ||
          state['profilePresent'] != true ||
          state['wellnessOnly'] != true ||
          state['restrictedVisible'] != false) {
        throw StateError('The real iPhone review login did not pass.');
      }
      await driver.tap(find.text('我的'));
      await driver.scrollIntoView(find.text('关于 Say Ring'));
      await driver.tap(find.text('关于 Say Ring'));
      await Future<void>.delayed(const Duration(seconds: 1));
      await File(
        '.build/sayring-1062-about-live.png',
      ).writeAsBytes(await driver.screenshot());
      await driver.requestData('finish');
      stdout.writeln('Real iPhone review login and reduced scope passed.');
    });
  } finally {
    await driver.close();
  }
}
