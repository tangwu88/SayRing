import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'debug/et488_device_diagnostic.dart';
import 'services/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController.production();
  runApp(SaydianApp(controller: controller));
  final initialization = controller.initialize();
  unawaited(initialization);
  if (kDebugMode && const bool.fromEnvironment('SAYDIAN_ET488_QA_AUTORUN')) {
    unawaited(initialization.then((_) => runEt488DeviceDiagnostic(controller)));
  }
}
