import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/wearable_routing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS W8 full safe physical-device smoke test', (_) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    await controller.initialize();
    if (!controller.isAuthenticated) controller.enterPreview();

    debugPrint('W8_TEST_STEP:scan');
    await controller.scanDevices();
    final candidates =
        controller.scannedDevices
            .where(
              (device) =>
                  device.sdkSource == WearableSdkSource.yucheng &&
                  YuchengDeviceClassifier.matches(device.name),
            )
            .toList()
          ..sort((a, b) {
            final aConnected = a.rssi == 0 ? 1 : 0;
            final bConnected = b.rssi == 0 ? 1 : 0;
            final connectedOrder = bConnected.compareTo(aConnected);
            if (connectedOrder != 0) return connectedOrder;
            return (b.rssi ?? -999).compareTo(a.rssi ?? -999);
          });
    expect(candidates, isNotEmpty, reason: '没有发现 W8 系列设备');
    final w8 = candidates.first;
    debugPrint(
      'W8_SELECTED:${w8.name}:${w8.hardwareAddress}:${w8.id}:${w8.rssi}',
    );

    debugPrint('W8_TEST_STEP:connect');
    await controller.connectDevice(w8);
    final connected = controller.connectedDevice;
    expect(connected, isNotNull);
    expect(connected?.sdkSource, WearableSdkSource.yucheng);
    expect(
      connected?.identifierLabel,
      anyOf(startsWith('MAC · '), startsWith('iOS 标识 · ')),
    );
    debugPrint('W8_IDENTITY:${connected?.identifierLabel}');
    await _waitUntil(
      () => !controller.isDeviceSyncing,
      const Duration(seconds: 55),
    );
    expect(controller.deviceState, isNot(DeviceConnectionState.disconnected));
    debugPrint('W8_SYNC_STATUS:${controller.syncStatus}');

    final capabilities = controller.capabilities;
    expect(capabilities, isNotNull);
    debugPrint(
      'W8_METRICS:${capabilities!.metrics.map((item) => item.wireName).join(',')}',
    );
    debugPrint(
      'W8_MANUAL:${capabilities.manualMetrics?.map((item) => item.wireName).join(',')}',
    );
    debugPrint(
      'W8_FEATURES:${capabilities.features.map((item) => item.wireName).join(',')}',
    );

    final liveResults = <HealthMetric>{};
    for (final metric in const [
      HealthMetric.heartRate,
      HealthMetric.bloodOxygen,
      HealthMetric.bloodPressure,
      HealthMetric.bodyTemperature,
      HealthMetric.bloodGlucose,
    ].where(capabilities.supportsManualMeasurement)) {
      controller.clearError();
      final startedAt = DateTime.now().toUtc();
      final started = await controller.startMeasurement(metric);
      expect(started, isTrue, reason: '${metric.label}真机测量启动失败');
      final completed = await _waitUntil(
        () => controller.activeMeasurementMetric == null,
        metric == HealthMetric.bloodPressure
            ? const Duration(seconds: 45)
            : const Duration(seconds: 25),
        mustComplete: false,
      );
      final latest = controller.latestByMetric[metric];
      if (completed &&
          latest != null &&
          !latest.measuredAt.isBefore(
            startedAt.subtract(const Duration(seconds: 2)),
          )) {
        liveResults.add(metric);
        debugPrint(
          'W8_MEASUREMENT_RESULT:${metric.wireName}:${latest.displayValue}:${latest.unit}',
        );
      } else {
        if (controller.activeMeasurementMetric == metric) {
          await controller.stopMeasurement(metric);
        }
        debugPrint(
          'W8_MEASUREMENT_COMMAND_ONLY:${metric.wireName}:${controller.measurementErrorMessage ?? controller.errorMessage ?? 'no live result'}',
        );
      }
      expect(
        controller.deviceState,
        isNot(DeviceConnectionState.disconnected),
        reason: '${metric.label}测量后设备断开',
      );
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    debugPrint(
      'W8_LIVE_RESULTS:${liveResults.map((item) => item.wireName).join(',')}',
    );

    if (controller.availabilityFor(DeviceFeature.findWatch).isReady) {
      controller.clearError();
      expect(
        await controller.triggerDeviceAction(DeviceFeature.findWatch),
        isTrue,
      );
      debugPrint('W8_FIND_WATCH_OK');
    }
    if (controller.availabilityFor(DeviceFeature.camera).isReady) {
      controller.clearError();
      expect(
        await controller.triggerDeviceAction(
          DeviceFeature.camera,
          enabled: true,
        ),
        isTrue,
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(
        await controller.triggerDeviceAction(
          DeviceFeature.camera,
          enabled: false,
        ),
        isTrue,
      );
      debugPrint('W8_CAMERA_OK');
    }
    final watchFaceAvailability = controller.availabilityFor(
      DeviceFeature.watchFaces,
    );
    debugPrint(
      'W8_WATCH_FACE_AVAILABILITY:${watchFaceAvailability.status.name}',
    );
    if (watchFaceAvailability.isReady) {
      controller.clearError();
      final watchFaces = await controller.readDeviceFeature(
        DeviceFeature.watchFaces,
      );
      expect(watchFaces, isNotNull, reason: 'W8 表盘查询失败');
      debugPrint(
        'W8_WATCH_FACES:${(watchFaces['items'] as List?)?.length ?? 0}',
      );
    }
  });
}

Future<bool> _waitUntil(
  bool Function() condition,
  Duration timeout, {
  bool mustComplete = true,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  if (mustComplete) expect(condition(), isTrue);
  return condition();
}
