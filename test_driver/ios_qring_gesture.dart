import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 9),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final directory = Directory('build/qring-gesture-20261017');
    await directory.create(recursive: true);
    final report = Map<String, dynamic>.of(data ?? const {});
    final screenshots = report.remove('screenshots');
    if (screenshots is List) {
      for (final item in screenshots.whereType<Map>()) {
        final bytes = item['bytes'];
        final name = '${item['screenshotName']}';
        if (bytes is List &&
            RegExp(r'^qring-gesture-[a-z-]+$').hasMatch(name)) {
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
