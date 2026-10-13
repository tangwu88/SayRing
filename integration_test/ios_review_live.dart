import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bootstrap.dart';

/// Real-time device driver. Test credentials stay in the host-only private
/// configuration; the app uses isolated in-memory account and health stores.
void main() {
  late final AppController controller;
  // This extension creates the binding; initializing WidgetsBinding first
  // registers service extensions twice on a physical Profile build.
  enableFlutterDriverExtension(
    handler: (message) async {
      if (message == 'capability') {
        try {
          final capabilities = await controller.globalAuthCapabilities();
          return jsonEncode({
            'loaded': true,
            'consentPresent': capabilities.consentVersion?.isNotEmpty == true,
          });
        } on ApiException catch (error) {
          return jsonEncode({
            'loaded': false,
            'status': error.statusCode,
            'code': '${error.code}',
          });
        } on FormatException catch (error) {
          return jsonEncode({'loaded': false, 'format': error.message});
        } catch (error) {
          return jsonEncode({'loaded': false, 'type': '${error.runtimeType}'});
        }
      }
      if (message == 'finish') {
        if (controller.isAuthenticated) await controller.logout();
        return 'finished';
      }
      return jsonEncode({
        'authenticated': controller.isAuthenticated,
        'profilePresent': controller.memberProfile.isNotEmpty,
        'wellnessOnly': controller.isWellnessOnly,
        'sleepAiEnabled': controller.sleepAiEnabled,
        'alertsAvailable': controller.healthAlertsAvailable,
        'restrictedVisible': HealthMetric.values.any(
          (metric) =>
              !controller.isMetricAvailableInRelease(metric) &&
              controller.shouldShowHealthMetric(metric),
        ),
        'apiStatus': controller.lastApiError?.statusCode,
      });
    },
  );
  final vault = MemorySessionVault();
  final api = GlobalSaydianApiClient(
    vault,
    locale: () => 'zh-Hans',
    healthReleasePolicy: const WellnessReleasePolicy(enabled: true),
  );
  controller = AppController(
    vault,
    api,
    MemoryHealthStore(),
    createProductionWearableBridge(),
    wellnessOnly: true,
    generalAiEnabled: false,
    allowAutomaticWearableRestore: false,
  );
  runApp(SaydianApp(controller: controller));
  unawaited(controller.initialize());
}
