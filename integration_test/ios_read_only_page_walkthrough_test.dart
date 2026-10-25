import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/health_reports_page.dart';
import 'package:saydian_app/ui/prototype_pages.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'iOS read-only walkthrough of reachable product pages',
    (tester) async {
      final controller = AppController.production();
      addTearDown(controller.dispose);
      runApp(SaydianApp(controller: controller));
      await controller.initialize().timeout(const Duration(seconds: 60));
      Future<void> settle() async {
        // Continuous BLE/progress animations need bounded frames, not global idle.
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await tester.pump().timeout(const Duration(seconds: 15));
        }
      }

      // Start from a defined tab without changing the account or device binding.
      // An in-place upgrade may retain the user's previous Device/My selection.
      controller.selectTab(0);
      final originalOwner = controller.session?.accountKey;
      final hasAppShell = controller.isAuthenticated || controller.isLocalMode;
      const mode = String.fromEnvironment(
        'SAYRING_QA_WALKTHROUGH_MODE',
        defaultValue: 'existing',
      );
      if (!hasAppShell && mode == 'demo') controller.enterPreview();
      final visited = <String>[];
      final unavailable = <String>[];
      final proof = <String, Object?>{};
      final privateDir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/xr-walkthrough-20261025',
      );
      await privateDir.create(recursive: true);
      Future<void> checkpoint() async {
        binding.reportData = {
          ...?binding.reportData,
          'walkthrough': {
            'visited': visited,
            'unavailable': unavailable,
            ...proof,
          },
        };
        await File('${privateDir.path}/proof.json').writeAsString(
          jsonEncode({
            'visited': visited,
            'unavailable': unavailable,
            ...proof,
          }),
          flush: true,
        );
      }

      Future<void> record(String name) async {
        visited.add(name);
        // Page labels only, never profile or health values.
        // ignore: avoid_print
        print('iOS walkthrough visited: $name');
        await checkpoint();
        if (const bool.fromEnvironment('SAYRING_QA_EXTENDED')) {
          final bytes = await binding.takeScreenshot(
            'xr-page-${visited.length}',
          );
          await File(
            '${privateDir.path}/page-${visited.length}.png',
          ).writeAsBytes(bytes, flush: true);
        }
      }

      await settle();
      await settle();

      if (!hasAppShell && mode == 'local') {
        expect(find.byKey(const Key('global-code-login-page')), findsOneWidget);
        final scrollable = find.byType(Scrollable).first;
        for (final key in ['code-login-minimum-age', 'code-login-consent']) {
          final checkbox = find.byKey(Key(key));
          await tester.scrollUntilVisible(
            checkbox,
            240,
            scrollable: scrollable,
          );
          await tester.tap(checkbox);
          await settle();
        }
        final entry = find.byKey(const Key('local-ring-use-entry'));
        await tester.scrollUntilVisible(entry, 240, scrollable: scrollable);
        await tester.tap(entry);
        await settle();
        expect(controller.isLocalMode, isTrue);
        expect(controller.isPreviewMode, isFalse);
        await record('登录页经明确同意进入真实本机模式');
      }

      if (controller.isPreviewMode) {
        expect(find.byKey(const Key('review-demo-page')), findsOneWidget);
        await tester.tap(find.byKey(const Key('review-demo-sleep')));
        await settle();
        expect(find.byKey(const Key('sleep-timeline-card')), findsOneWidget);
        expect(find.text('夜间睡眠'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await settle();

        for (final key in const ['heart', 'oxygen', 'steps']) {
          await tester.tap(find.byKey(Key('review-demo-metric-$key')));
          await settle();
          expect(find.textContaining('演示数值'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await settle();
        }

        await tester.tap(find.text('设备').last);
        await settle();
        expect(find.byKey(const Key('review-demo-device')), findsOneWidget);
        await tester.tap(find.byKey(const Key('review-demo-device-guide')));
        await settle();
        expect(find.textContaining('不代表已完成任何真实连接'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await settle();

        await tester.tap(find.text('我的').last);
        await settle();
        expect(find.byKey(const Key('review-demo-profile')), findsOneWidget);
        expect(find.text('演示用户'), findsOneWidget);

        await tester.tap(find.byKey(const Key('review-demo-exit')));
        await settle();
        expect(find.byKey(const Key('global-code-login-page')), findsOneWidget);
        expect(find.byKey(const Key('code-login-contact')), findsOneWidget);
        expect(find.byKey(const Key('code-login-submit')), findsOneWidget);
        expect(find.byKey(const Key('local-ring-use-entry')), findsOneWidget);
        expect(find.byKey(const Key('review-demo-entry')), findsNothing);
        expect(find.text('Say Ring 商城'), findsNothing);
        await tester.ensureVisible(
          find.byKey(const Key('local-ring-use-entry')),
        );
        await tester.tap(find.byKey(const Key('local-ring-use-entry')));
        await settle();
        expect(find.byKey(const Key('code-login-error')), findsOneWidget);
        expect(find.byKey(const Key('global-code-login-page')), findsOneWidget);

        final emailChip = find.text('邮箱').last;
        await tester.ensureVisible(emailChip);
        await tester.tap(emailChip);
        await settle();
        final emailField = tester.widget<TextField>(
          find.byKey(const Key('code-login-contact')),
        );
        expect(emailField.keyboardType, TextInputType.emailAddress);
        if (find.byKey(const Key('email-login-mode')).evaluate().isNotEmpty) {
          expect(find.byKey(const Key('email-login-password')), findsOneWidget);
          await tester.tap(find.byKey(const Key('email-login-mode')));
          await settle();
          expect(find.byKey(const Key('code-login-code')), findsOneWidget);
          await tester.tap(find.byKey(const Key('email-login-mode')));
          await settle();
          expect(find.byKey(const Key('email-login-password')), findsOneWidget);
        }
        visited.addAll(const ['只读睡眠/指标/设备/我的', '登录首页与单一本机入口']);
        expect(tester.takeException(), isNull);
        // Labels only; never print account, profile, or health values into the log.
        // ignore: avoid_print
        print('iOS read-only walkthrough pages: ${visited.join('、')}');
        return;
      }

      expect(
        controller.isAuthenticated || controller.isLocalMode,
        isTrue,
        reason: '没有真实账号或本机会话；不得自动改用演示页并计为产品验收',
      );

      if (const bool.fromEnvironment('SAYRING_QA_CONNECT_ANY')) {
        // This run is explicitly authorized to select another scanned ring.
        // Require an existing binding so QA cannot trigger first-member reset.
        expect(controller.rememberedDevice, isNotNull);
        bool ready() =>
            controller.connectedDevice != null &&
            controller.deviceCapabilityState == DeviceCapabilityState.ready;
        final attempts = <Map<String, Object?>>[];
        if (!ready()) {
          try {
            await controller.reconnectDevice().timeout(
              const Duration(seconds: 35),
            );
            for (var i = 0; i < 20 && !ready(); i++) {
              await settle();
            }
          } catch (_) {
            proof['originalRecoveryIncomplete'] = true;
          }
        }
        if (!ready()) {
          await controller.scanDevices().timeout(const Duration(seconds: 45));
          final candidates = controller.scannedDevices
              .where(
                (d) => {
                  WearableSdkSource.qring,
                  WearableSdkSource.coolwear,
                }.contains(d.sdkSource),
              )
              .toList();
          proof['scanRingCount'] = candidates.length;
          await controller.stopDeviceScan();
          for (final device in candidates.take(3)) {
            if (controller.session?.accountKey != originalOwner) break;
            try {
              await controller
                  .connectDevice(device)
                  .timeout(const Duration(seconds: 60));
              for (var i = 0; i < 15 && !ready(); i++) {
                await settle();
              }
              attempts.add({'sdk': device.sdkSource.name, 'ready': ready()});
            } catch (_) {
              attempts.add({'sdk': device.sdkSource.name, 'ready': false});
            }
            if (ready()) break;
          }
        }
        proof['connectionAttempts'] = attempts;
        proof['connected'] = ready();
        proof['connectedSdk'] = controller.connectedDevice?.sdkSource.name;
        proof['ownerUnchanged'] =
            controller.session?.accountKey == originalOwner;
        proof['batteryRead'] =
            controller.connectedDevice?.battery?.updatedAt != null;
        await checkpoint();
        await record('真实连接检查');
        for (var i = 0; i < 90 && controller.isDeviceSyncing; i++) {
          await settle();
        }
        proof['backgroundSyncFinished'] = !controller.isDeviceSyncing;
        await checkpoint();
      }

      Future<void> open(
        String name,
        Finder tapTarget,
        Finder pageMarker,
      ) async {
        // These are required dashboard entries. Lazy SliverList children may
        // not exist until scrolling; absence at the current offset is not a skip.
        await tester.scrollUntilVisible(
          tapTarget,
          -280,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(tapTarget.last),
          alignment: .5,
        );
        await settle();
        expect(tapTarget.last.hitTestable(), findsOneWidget);
        await tester.tap(tapTarget.last.hitTestable());
        await settle();
        expect(pageMarker, findsOneWidget, reason: '$name 页面未打开');
        expect(tester.takeException(), isNull, reason: '$name 页面发生异常');
        await record(name);
        await tester.binding.handlePopRoute();
        await settle();
      }

      expect(find.byKey(const Key('dashboard-functions')), findsOneWidget);
      expect(find.text('Say Ring 商城'), findsNothing);
      await record('健康首页');

      for (final metric in HealthPage.coreMetrics) {
        if (!controller.shouldShowHealthMetric(metric)) {
          unavailable.add('${metric.label}详情（能力/数据门禁隐藏）');
          continue;
        }
        final card = find.byKey(ValueKey('health-metric-${metric.name}'));
        await tester.scrollUntilVisible(
          card,
          280,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(card), alignment: .5);
        await settle();
        expect(card.hitTestable(), findsOneWidget);
        await tester.tap(card.hitTestable());
        await settle();
        expect(
          find.byKey(Key('health-trend-${metric.wireName}')),
          findsOneWidget,
          reason: '${metric.label}详情没有显示标题/指标',
        );
        expect(tester.takeException(), isNull, reason: '${metric.label}详情发生异常');
        await record('${metric.label}详情');
        await tester.binding.handlePopRoute();
        await settle();
      }

      // Rerun only the affected metric navigation after a larger page walk.
      // This is a test-only scope selector; production never reads this value.
      if (const bool.fromEnvironment('SAYRING_QA_METRICS_ONLY')) {
        expect(tester.takeException(), isNull);
        expect(controller.session?.accountKey, originalOwner);
        // ignore: avoid_print
        print('iOS verified metric pages: ${visited.join('、')}');
        return;
      }

      await open(
        '睡眠概览',
        find.byKey(const Key('home-sleep-overview-entry')),
        find.byKey(const Key('sleep-overview-page')),
      );
      await open('全部健康数据', find.text('全部数据'), find.text('全部健康数据'));
      await open('远程关爱', find.text('远程关爱'), find.byType(CarePage));
      await open('健康百科', find.text('健康百科'), find.byType(ArticleCategoryPage));
      await open(
        '运动总览',
        find.text('运动'),
        find.byKey(const Key('sport-overview-page')),
      );

      // The notification entry belongs to the health dashboard, not DevicePage.
      // A partially visible header child can satisfy ensureVisible while its
      // center is still behind the status bar. Reset before hit-testing the tap.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await settle();
      await tester.tap(
        find.byIcon(Icons.notifications_none_rounded).hitTestable(),
      );
      await settle();
      expect(find.text('消息'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await record('消息通知');
      await tester.binding.handlePopRoute();
      await settle();

      controller.selectTab(1);
      await settle();
      expect(find.byKey(const Key('device-page')), findsOneWidget);
      expect(find.byKey(const Key('first-ring-binding-status')), findsNothing);
      for (final internalText in ['首次绑定记录', '清空指令', '恢复出厂指令']) {
        expect(find.textContaining(internalText), findsNothing);
      }
      expect(
        find.byKey(const Key('device-empty-card')).evaluate().isNotEmpty ||
            find.byKey(const Key('device-overview-card')).evaluate().isNotEmpty,
        isTrue,
        reason: '设备页既没有空状态，也没有已绑定设备状态',
      );
      await record('设备');
      await binding.takeScreenshot('device-overview-private');
      // ignore: avoid_print
      print(
        'iOS device connected: ${controller.connectedDevice != null}; '
        'capability state: ${controller.deviceCapabilityState.name}',
      );
      if (controller.connectedDevice != null) {
        expect(find.byKey(const Key('device-reconnect')), findsNothing);
        for (final feature in const [
          DeviceFeature.camera,
          DeviceFeature.gestureControl,
          DeviceFeature.callReminder,
        ]) {
          if (!controller.availabilityFor(feature).isReady) {
            expect(controller.visibleDeviceFeatures, isNot(contains(feature)));
            unavailable.add('${feature.label}（真实能力门禁隐藏）');
          }
        }
        if (controller
            .availabilityFor(DeviceFeature.healthMonitoring)
            .isReady) {
          // Read the existing ring settings only. No switch, camera permission,
          // gesture mode, call reminder or find action is changed in this test.
          for (
            var attempt = 0;
            controller.isDeviceSyncing && attempt < 120;
            attempt++
          ) {
            await tester.pump(const Duration(milliseconds: 500));
          }
          expect(controller.isDeviceSyncing, isFalse);
          final healthMonitoring = find.text('健康监测');
          await tester.ensureVisible(healthMonitoring);
          await tester.tap(healthMonitoring);
          await settle();
          await controller.refreshDeviceSettings();
          await settle();
          expect(controller.autoMeasureSettings, isNotEmpty);
          expect(controller.deviceSettingsStatus, '设置已同步');
          expect(tester.takeException(), isNull);
          await record('健康监测（真实设置只读）');
          await tester.binding.handlePopRoute();
          await settle();
        }
      }

      if (const bool.fromEnvironment('SAYRING_QA_SCAN')) {
        final search = find.byIcon(Icons.radar_rounded);
        if (search.evaluate().isNotEmpty) {
          await tester.ensureVisible(search);
          await tester.tap(search);
          await settle();
          expect(find.byType(DeviceSearchPage), findsOneWidget);
          expect(tester.takeException(), isNull);
          await record('真实蓝牙搜索页面（不自动选择或更换戒指）');
          // Counts only: scanning is not evidence of SDK handshake or data read.
          // ignore: avoid_print
          print(
            'iOS scan supported device count: ${controller.scannedDevices.length}',
          );
          await tester.binding.handlePopRoute();
          await settle();
        } else {
          unavailable.add('蓝牙搜索（已有绑定卡，无空态搜索入口）');
        }
      }

      if (const bool.fromEnvironment('SAYRING_QA_EXTENDED')) {
        for (final feature in [
          DeviceFeature.findWatch,
          DeviceFeature.gestureControl,
          DeviceFeature.callReminder,
          DeviceFeature.notifications,
          DeviceFeature.alarms,
          DeviceFeature.healthReminders,
          DeviceFeature.camera,
        ]) {
          if (!controller.visibleDeviceFeatures.contains(feature) ||
              !controller.availabilityFor(feature).isReady) {
            unavailable.add('${feature.label}（当前真实设备不支持或不可用）');
            continue;
          }
          final tile = find.byKey(Key('device-feature-${feature.wireName}'));
          final scrollable = find
              .descendant(
                of: find.byKey(const Key('device-page')),
                matching: find.byType(Scrollable),
              )
              .first;
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await settle();
          await tester.scrollUntilVisible(tile, 230, scrollable: scrollable);
          await Scrollable.ensureVisible(tester.element(tile), alignment: .5);
          await settle();
          await tester.tap(tile.hitTestable());
          await settle();
          expect(find.byType(DeviceFeaturePage), findsOneWidget);
          expect(tester.takeException(), isNull);
          await record('${feature.label}设置页（不改原设置）');
          await tester.binding.handlePopRoute();
          await settle();
        }
      }

      controller.selectTab(2);
      await settle();
      expect(find.byKey(const Key('my-page')), findsOneWidget);
      await record('我的');

      if (!controller.isLocalMode) {
        await tester.tap(find.byKey(const Key('profile-header-card')));
        await settle();
        expect(find.byKey(const Key('profile-nickname')), findsOneWidget);
        expect(find.byKey(const Key('profile-save')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await record('个人资料（只读）');
        await tester.binding.handlePopRoute();
        await settle();
      }

      final myPageScroll = find
          .descendant(
            of: find.byKey(const Key('my-page')),
            matching: find.byType(Scrollable),
          )
          .first;
      Future<void> openMyEntry(String label, Finder marker) async {
        final entry = find.text(label);
        // Start at a defined position, because previous pages preserve the list
        // offset and UnitSettings is above the services grid.
        tester.state<ScrollableState>(myPageScroll).position.jumpTo(0);
        await settle();
        await tester.scrollUntilVisible(entry, 280, scrollable: myPageScroll);
        await tester.tap(entry.last);
        await settle();
        expect(marker, findsOneWidget, reason: '$label 页面未打开');
        expect(tester.takeException(), isNull, reason: '$label 页面发生异常');
        await record(label);
        await tester.binding.handlePopRoute();
        await settle();
      }

      if (controller.isLocalMode) {
        await openMyEntry('账号设置', find.byKey(const Key('local-mode-sign-in')));
      }
      await openMyEntry('单位设置', find.byType(UnitSettingsPage));
      if (!controller.isLocalMode) {
        if (!controller.hideAiContent) {
          await openMyEntry('健康档案', find.byType(HealthProfilePage));
        } else {
          unavailable.add('健康档案（首版隐藏）');
        }
        await openMyEntry('账号设置', find.byType(AccountSettingsPage));
      }
      await openMyEntry('权限管理', find.byType(PermissionManagementPage));
      await openMyEntry('帮助反馈', find.byType(FeedbackPage));
      await openMyEntry('联系客服', find.byType(CustomerServicePage));
      await openMyEntry('关于 Say Ring', find.byType(AboutSaydianPage));

      expect(tester.takeException(), isNull);
      expect(controller.session?.accountKey, originalOwner);
      // Labels only; never print account, profile, or health values into the log.
      // ignore: avoid_print
      print('iOS read-only walkthrough pages: ${visited.join('、')}');
      // ignore: avoid_print
      print('iOS walkthrough unavailable entries: ${unavailable.join('、')}');
      await checkpoint();
      if (const bool.fromEnvironment('SAYRING_QA_CONNECT_ANY')) {
        expect(
          proof['connected'],
          isTrue,
          reason: 'A real ring handshake is required',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
