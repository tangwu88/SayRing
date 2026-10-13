import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    if (!const {
      'sayring-1062-email-password-empty',
      'sayring-1062-real-sleep',
      'sayring-1062-about',
    }.contains(name)) {
      return false;
    }
    await File('.build/$name.png').writeAsBytes(bytes);
    return true;
  },
);
