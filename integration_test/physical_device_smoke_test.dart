import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/ecg_waveform.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('physical device health and ET488 smoke test', (tester) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    await controller.initialize();
    if (!controller.isAuthenticated) controller.enterPreview();

    await tester.pumpWidget(SaydianApp(controller: controller));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('健康数据'), findsOneWidget);

    controller.selectTab(1);
    await tester.pumpAndSettle();
    if (controller.connectedDevice != null &&
        !_isEt488(controller.connectedDevice!)) {
      await controller.disconnectDevice();
      await tester.pump(const Duration(seconds: 2));
    }
    if (controller.connectedDevice == null) {
      var et488 = await _tryScanForDevice(tester, controller, _isEt488);
      if (et488 == null) {
        if (!controller.scannedDevices.any(_isW8)) {
          await _tryScanForDevice(tester, controller, _isW8);
        }
        final seenW8 = controller.scannedDevices.where(_isW8).toList();
        var connectedFallback = false;
        for (final w8 in seenW8) {
          debugPrint('ET488_FALLBACK_W8:${w8.name}:${w8.id}');
          await controller.connectDevice(w8);
          connectedFallback = await _waitForCondition(
            tester,
            () => controller.connectedDevice?.id == w8.id,
            const Duration(seconds: 25),
          );
          if (connectedFallback) {
            debugPrint('ET488_FALLBACK_W8_CONNECTED:${w8.name}:${w8.id}');
            await controller.disconnectDevice();
            await tester.pump(const Duration(seconds: 2));
            break;
          }
          debugPrint(
            'ET488_FALLBACK_W8_UNAVAILABLE:${w8.name}:${controller.errorMessage ?? 'timeout'}',
          );
          await controller.disconnectDevice();
          controller.clearError();
          await tester.pump(const Duration(seconds: 2));
        }
        debugPrint('ET488_FALLBACK_W8_RESULT:$connectedFallback');
        et488 = await _tryScanForDevice(tester, controller, _isEt488);
      }
      expect(et488, isNotNull, reason: 'W8 过渡连接后仍未发现 ET488');
      await controller.connectDevice(et488!);
    }
    await _waitUntil(
      tester,
      () => controller.connectedDevice != null,
      const Duration(seconds: 25),
    );
    expect(controller.connectedDevice?.name.toUpperCase(), contains('ET488'));
    expect(controller.connectedDevice?.sdkSource, WearableSdkSource.veepoo);
    await tester.pumpAndSettle();
    expect(
      find.text(controller.connectedDevice!.name),
      findsOneWidget,
      reason: '设备页未展示当前实际连接的 ET488 名称',
    );

    await controller.readDeviceFeature(DeviceFeature.watchFaces);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('表盘中心'));
    await tester.tap(find.text('表盘中心'));
    await _waitUntil(
      tester,
      () => find.text('手表中的表盘').evaluate().isNotEmpty,
      const Duration(seconds: 20),
    );
    expect(find.text('手表中的表盘'), findsOneWidget);
    await _tapBack(tester);

    await controller.syncDeviceData();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(controller.connectedDevice, isNotNull);
    expect(controller.deviceState, isNot(DeviceConnectionState.disconnected));
    final capabilities = controller.capabilities;
    expect(capabilities, isNotNull);
    debugPrint(
      'ET488_CAPABILITIES:${capabilities!.metrics.map((metric) => metric.wireName).join(',')}',
    );
    final now = DateTime.now();
    final ecgRecords = await controller.loadHealthRecords(
      metric: HealthMetric.ecg,
      start: now.subtract(const Duration(days: 365)),
      end: now.add(const Duration(days: 1)),
    );
    debugPrint('ET488_ECG_RECORDS:${ecgRecords.length}');
    for (final record in ecgRecords.take(5)) {
      final frequency = record.values['sampleFrequency']?.toInt() ?? 250;
      final riskKeys = record.values.keys
          .where((key) => key.toLowerCase().contains('risk'))
          .toList(growable: false);
      debugPrint(
        'ET488_ECG_RECORD:raw=${record.rawVersion} samples=${record.samples.length} '
        'usable=${record.samples.isNotEmpty && hasUsableEcgSignal(record.samples, sampleFrequency: frequency)} '
        'riskKeys=${riskKeys.join(',')}',
      );
      if (record.rawVersion >= 2 && record.samples.isNotEmpty) {
        expect(
          hasUsableEcgSignal(record.samples, sampleFrequency: frequency),
          isTrue,
          reason: '心电历史包含被标记为已校准但不可用的异常波形',
        );
      }
    }

    controller.selectTab(0);
    await tester.pumpAndSettle();
    for (final metric in const [
      HealthMetric.bloodPressure,
      HealthMetric.heartRate,
      HealthMetric.bloodOxygen,
      HealthMetric.bodyTemperature,
      HealthMetric.ecg,
      HealthMetric.hrv,
    ].where(capabilities.supports)) {
      final card = find.byKey(ValueKey('health-metric-${metric.name}'));
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(card, findsOneWidget, reason: '${metric.label} 首页入口缺失');
    }
    controller.selectTab(1);
    await tester.pumpAndSettle();

    const manuallyMeasured = [
      // ECG requires the watch to be idle, so exercise it before the shorter
      // optical measurements and leave a settling gap after every stop.
      HealthMetric.ecg,
      HealthMetric.heartRate,
      HealthMetric.bloodOxygen,
      HealthMetric.bloodPressure,
      HealthMetric.bodyTemperature,
      HealthMetric.bloodGlucose,
      HealthMetric.bodyComposition,
      HealthMetric.bloodComposition,
    ];
    for (final metric in manuallyMeasured.where(capabilities.supports)) {
      controller.clearError();
      await controller.startMeasurement(metric);
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        controller.errorMessage,
        isNull,
        reason: '${metric.label}真机测量启动失败',
      );
      await controller.stopMeasurement(metric);
      await tester.pump(const Duration(seconds: 1));
      expect(
        controller.errorMessage,
        isNull,
        reason: '${metric.label}真机测量停止失败',
      );
      debugPrint('ET488_MEASUREMENT_OK:${metric.wireName}');
    }

    final connectedId = controller.connectedDevice!.id;
    await controller.disconnectDevice();
    expect(controller.connectedDevice, isNull);
    final rediscovered = await _scanForDevice(
      tester,
      controller,
      (device) => device.id == connectedId,
    );
    await controller.connectDevice(rediscovered);
    await _waitUntil(
      tester,
      () => controller.connectedDevice?.id == connectedId,
      const Duration(seconds: 25),
    );
    expect(controller.deviceState, isNot(DeviceConnectionState.disconnected));
    debugPrint('ET488_RECONNECT_OK:$connectedId');

    controller.selectTab(0);
    await tester.pumpAndSettle();
    final sportEntries = find.byKey(const Key('health-sport-entries'));
    await tester.scrollUntilVisible(
      sportEntries,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    for (final sport in const ['跑步', '步行', '骑行', '徒步', '运动记录']) {
      expect(find.text(sport), findsWidgets);
    }
    for (final mode in controller.availableSportModes) {
      controller.clearError();
      expect(
        await controller.startSport(mode),
        isTrue,
        reason: '${mode.label}未能从 App 启动',
      );
      await tester.pump(const Duration(seconds: 2));
      expect(controller.activeSport, mode, reason: '${mode.label}启动后模式不一致');
      await controller.stopSport();
      await tester.pump(const Duration(seconds: 2));
      expect(controller.activeSport, isNull, reason: '${mode.label}未能正常结束');
      expect(controller.errorMessage, isNull, reason: '${mode.label}真机运动测试失败');
      debugPrint('ET488_SPORT_OK:${mode.wireName}');
    }

    controller.selectTab(2);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('联系客服'));
    await tester.tap(find.text('联系客服'));
    await tester.pumpAndSettle();
    expect(find.text('4006386738'), findsOneWidget);
    expect(find.text('公众号'), findsOneWidget);
    expect(find.text('添加客服'), findsOneWidget);
    await _tapBack(tester);
    await tester.ensureVisible(find.text('关于我们'));
    await tester.tap(find.text('关于我们'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('在线更新服务暂未配置'), findsOneWidget);
  });
}

Future<DeviceInfo> _scanForDevice(
  WidgetTester tester,
  AppController controller,
  bool Function(DeviceInfo device) matches,
) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    await controller.scanDevices();
    final matchesNow = controller.scannedDevices.where(matches);
    if (matchesNow.isNotEmpty) return matchesNow.first;
    await tester.pump(const Duration(seconds: 3));
  }
  fail('三轮搜索后仍未重新发现目标手表');
}

Future<DeviceInfo?> _tryScanForDevice(
  WidgetTester tester,
  AppController controller,
  bool Function(DeviceInfo device) matches,
) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    await controller.scanDevices();
    final found = controller.scannedDevices.where(matches);
    if (found.isNotEmpty) return found.first;
    await tester.pump(const Duration(seconds: 2));
  }
  return null;
}

bool _isEt488(DeviceInfo device) => device.name.toUpperCase().contains('ET488');

bool _isW8(DeviceInfo device) => device.name.toUpperCase().contains('W8');

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(condition(), isTrue);
}

Future<bool> _waitForCondition(
  WidgetTester tester,
  bool Function() condition,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  return condition();
}

Future<void> _tapBack(WidgetTester tester) async {
  final back = find.byTooltip('返回');
  expect(back, findsWidgets, reason: '当前页面缺少返回按钮');
  await tester.tap(back.first);
  await tester.pumpAndSettle();
}
