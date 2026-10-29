import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 30),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final out = Directory(
      Platform.environment['SAYRING_QA_OUTPUT'] ??
          'build/ios-xr-any-ring-1165-20261029/device-round1',
    );
    await out.create(recursive: true);
    await Process.run('chmod', ['700', out.path]);
    final report = Map<String, dynamic>.of(data ?? const {});
    final images = report.remove('screenshots');
    if (images is List) {
      for (final image in images.whereType<Map>()) {
        final name = '${image['screenshotName']}';
        final bytes = image['bytes'];
        if (bytes is List && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name)) {
          final file = File('${out.path}/$name.png');
          await file.writeAsBytes(bytes.cast<int>(), flush: true);
          await Process.run('chmod', ['600', file.path]);
        }
      }
    }
    final file = File('${out.path}/integration-response-private.json');
    await file.writeAsString(jsonEncode(report), flush: true);
    await Process.run('chmod', ['600', file.path]);
  },
);
