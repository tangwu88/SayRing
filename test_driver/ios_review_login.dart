import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    if (name != 'sayring-1061-email-password-empty') return false;
    await File('.build/$name.png').writeAsBytes(bytes);
    return true;
  },
);
