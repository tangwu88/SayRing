import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'debug/global_joint_device_diagnostic.dart';
import 'services/app_controller.dart';
import 'services/global_environment.dart';

/// Explicit tethered-QA entrypoint; the normal release main never imports it.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode ||
      !isApprovedGlobalJointQaEnvironment(
        GlobalEnvironment.configuredOrigin,
        GlobalEnvironment.apiPrefix,
      )) {
    throw StateError('Joint device QA requires the approved debug environment');
  }
  final controller = AppController.production(
    allowAutomaticWearableRestore: false,
  );
  runApp(SaydianApp(controller: controller));
  unawaited(() async {
    try {
      await controller.initialize().timeout(const Duration(seconds: 90));
      await runGlobalJointDeviceDiagnostic(controller);
    } catch (error) {
      emitGlobalJointQaRecord({
        'case': 'initialization',
        'status': 'failed',
        'reason': error.runtimeType.toString(),
      });
    }
  }());
}
