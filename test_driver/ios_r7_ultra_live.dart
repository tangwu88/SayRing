import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 15),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final directory = Directory('build/ios-r7-ultra-live-20261016');
    await directory.create(recursive: true);
    final report = Map<String, dynamic>.of(data ?? const {});
    final screenshots = report.remove('screenshots');
    if (screenshots is List) {
      for (final image in screenshots.whereType<Map>()) {
        final bytes = image['bytes'];
        final name = '${image['screenshotName'] ?? ''}';
        if (bytes is List && RegExp(r'^r7-[a-z-]+$').hasMatch(name)) {
          await File(
            '${directory.path}/$name.png',
          ).writeAsBytes(bytes.cast<int>());
        }
      }
    }
    await File(
      '${directory.path}/live-report-private.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  },
);
