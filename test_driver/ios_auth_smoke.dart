import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    if (!RegExp(r'^sayring-ios-(login|register)-[0-9]+$').hasMatch(name)) {
      return false;
    }
    await File('.build/$name.png').writeAsBytes(bytes);
    return true;
  },
);
