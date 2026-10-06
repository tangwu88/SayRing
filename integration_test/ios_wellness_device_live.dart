import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';

/// Inspects the real account/store without logout, unbind or test data.
/// The ordinary production main must be reinstalled after this driver.
void main() {
  late final AppController controller;
  enableFlutterDriverExtension(
    handler: (_) async => jsonEncode({
      'ready': !controller.isBooting,
      'authenticated': controller.isAuthenticated,
      'localMode': controller.isLocalMode,
      'bindingPresent': controller.rememberedDevice != null,
      'connected': controller.connectedDevice != null,
      'wellnessOnly': controller.isWellnessOnly,
      'sleepAiEnabled': controller.sleepAiEnabled,
      'alertsAvailable': controller.healthAlertsAvailable,
      'restrictedVisible': HealthMetric.values.any(
        (metric) =>
            !controller.isMetricAvailableInRelease(metric) &&
            controller.shouldShowHealthMetric(metric),
      ),
    }),
  );
  controller = AppController.production();
  runApp(SaydianApp(controller: controller));
  unawaited(controller.initialize());
}
