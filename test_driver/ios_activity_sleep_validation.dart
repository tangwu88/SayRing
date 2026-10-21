import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 10),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final directory = Directory('build/calories-sleep-20261021/live');
    await directory.create(recursive: true);
    final report = Map<String, dynamic>.of(data ?? const {});
    final images = report.remove('screenshots');
    if (images is List) {
      for (final image in images.whereType<Map>()) {
        final name = '${image['screenshotName']}';
        final bytes = image['bytes'];
        if (bytes is List &&
            RegExp(r'^activity-sleep-[a-z]+$').hasMatch(name)) {
          await File(
            '${directory.path}/$name.png',
          ).writeAsBytes(bytes.cast<int>());
        }
      }
    }
    await File(
      '${directory.path}/checks.json',
    ).writeAsString(jsonEncode(report));
  },
);
