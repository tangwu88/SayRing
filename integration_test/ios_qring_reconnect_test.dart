import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';

/// Physical QRing only. Use the preserving Profile driver wrapper and back up
/// the existing container first. Software disconnects are not distance tests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('owned QRing reconnect button completes three fresh handshakes', (
    tester,
  ) async {
    final controller = AppController.production();
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.isAuthenticated, isTrue, reason: '需要既有登录会话');
    expect(controller.isLocalMode, isFalse);
    expect(controller.isPreviewMode, isFalse);
    final originalOwner = controller.session!.memberId;
    final originalBinding = controller.rememberedDevice?.id;
    expect(originalBinding != null, isTrue, reason: '需要既有绑定，不自动选择新戒指');
    controller.selectTab(1);
    await tester.pumpWidget(SaydianApp(controller: controller));

    Future<void> waitFor(bool Function() ready, String reason) async {
      for (var attempt = 0; attempt < 240 && !ready(); attempt++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(ready(), isTrue, reason: reason);
    }

    await waitFor(
      () => controller.connectedDevice != null && !controller.isDeviceSyncing,
      '戒指需在旁边，等待真实连接与初次同步结束',
    );
    expect(
      controller.connectedDevice!.sdkSource == WearableSdkSource.qring,
      isTrue,
      reason: '本测试只验 QRing，不将结果推广到其他 SDK',
    );

    for (var round = 1; round <= 3; round++) {
      final beforeBattery = controller.connectedDevice!.battery?.updatedAt;
      expect(beforeBattery != null, isTrue, reason: '需要实际电量确认时间');
      await controller.disconnectDevice();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.connectedDevice == null, isTrue);
      expect(controller.rememberedDevice?.id == originalBinding, isTrue);
      final button = find.byKey(const Key('device-reconnect'));
      await tester.ensureVisible(button);
      expect(tester.widget<OutlinedButton>(button).onPressed != null, isTrue);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 100));
      await waitFor(
        () =>
            !controller.isDeviceReconnecting &&
            controller.connectedDevice?.id == originalBinding &&
            controller.deviceCapabilityState == DeviceCapabilityState.ready &&
            (controller.connectedDevice?.battery?.updatedAt?.isAfter(
                  beforeBattery!,
                ) ??
                false),
        '第 $round 轮页面重连须完成新握手并刷新真实电量',
      );
      expect(controller.session?.memberId == originalOwner, isTrue);
      expect(controller.rememberedDevice?.id == originalBinding, isTrue);
      expect(find.byKey(const Key('device-reconnect')), findsNothing);
      expect(tester.takeException(), isNull);
      // Labels and booleans only; no account, device identifiers or readings.
      // ignore: avoid_print
      print(
        'QRing software disconnect / visible reconnect round $round passed',
      );
      await waitFor(() => !controller.isDeviceSyncing, '等待本轮同步结束');
    }
  });
}
