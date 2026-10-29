import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/app_update_gate_scope.dart';
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/health_reminder_center.dart';

import 'support/dart_library_source.dart';

void main() {
  test('feature availability always has plain user copy', () {
    expect(
      const FeatureAvailability(FeatureAvailabilityStatus.needsDevice).message,
      '连接戒指后使用',
    );
    expect(
      const FeatureAvailability(
        FeatureAvailabilityStatus.needsPermission,
      ).message,
      '允许相关权限后使用',
    );
    expect(
      const FeatureAvailability(
        FeatureAvailabilityStatus.unsupportedDevice,
      ).message,
      '当前戒指不支持此功能',
    );
    expect(
      const FeatureAvailability(
        FeatureAvailabilityStatus.serviceUnavailable,
      ).message,
      '当前戒指暂不支持在 App 中设置',
    );
  });

  test('device capabilities map health and device features independently', () {
    final capabilities = DeviceCapabilities.fromMap(const {
      'metrics': ['heart_rate', 'blood_glucose'],
      'features': ['find_watch', 'screen_display', 'contacts'],
      'integratedFeatures': ['find_watch', 'screen_display'],
    });
    expect(capabilities.supports(HealthMetric.heartRate), isTrue);
    expect(capabilities.supports(HealthMetric.bloodGlucose), isTrue);
    expect(capabilities.supportsFeature(DeviceFeature.contacts), isTrue);
    expect(
      capabilities.integratedFeatures,
      containsAll([DeviceFeature.findWatch, DeviceFeature.screenDisplay]),
    );
  });

  test('screen-only wearable features stay hidden for the screenless ring', () {
    final controller = _controller()
      ..connectedDevice = const DeviceInfo(id: 'ring-1', name: 'HR01')
      ..deviceCapabilityState = DeviceCapabilityState.ready
      ..capabilities = const DeviceCapabilities(
        metrics: {},
        features: {
          DeviceFeature.findWatch,
          DeviceFeature.watchFaces,
          DeviceFeature.photoWatchFace,
          DeviceFeature.screenDisplay,
        },
        integratedFeatures: {
          DeviceFeature.findWatch,
          DeviceFeature.watchFaces,
          DeviceFeature.photoWatchFace,
          DeviceFeature.screenDisplay,
        },
      );
    addTearDown(controller.dispose);

    expect(controller.visibleDeviceFeatures, {DeviceFeature.findWatch});
  });

  testWidgets('disconnected device page shows only connection guidance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicePage(controller: controller)),
      ),
    );

    expect(find.text('添加智能设备'), findsOneWidget);
    expect(find.text('连接说明'), findsOneWidget);
    expect(find.text('显示样式'), findsNothing);
    expect(find.text('查找戒指'), findsNothing);
    expect(find.text('联系人'), findsNothing);
    expect(find.text('健康提醒'), findsNothing);
    expect(find.text('屏幕显示'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'device page shows only hardware and app capability intersection',
    (tester) async {
      final controller = _controller()
        ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'Test Watch')
        ..deviceCapabilityState = DeviceCapabilityState.ready
        ..capabilities = const DeviceCapabilities(
          metrics: {HealthMetric.heartRate},
          features: {
            DeviceFeature.findWatch,
            DeviceFeature.camera,
            DeviceFeature.weather,
          },
          integratedFeatures: {DeviceFeature.findWatch, DeviceFeature.weather},
        );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DevicePage(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.deviceCapabilityState, DeviceCapabilityState.ready);
      expect(
        controller.visibleDeviceFeatures,
        contains(DeviceFeature.findWatch),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();

      expect(find.text('查找戒指'), findsOneWidget);
      expect(find.text('天气'), findsOneWidget);
      expect(find.text('相机遥控'), findsNothing);
      expect(find.text('显示与个性化'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'connected and about-device pages hide technical routing labels',
    (tester) async {
      final controller = _controller()
        ..connectedDevice = const DeviceInfo(
          id: 'veepoo:watch-1',
          name: 'SD-Watch-W9S',
          model: 'W9S',
        );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DevicePage(controller: controller)),
        ),
      );
      await tester.pump();
      expect(find.text('Vep'), findsNothing);
      expect(find.text('Yuc'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(home: DeviceInfoPage(controller: controller)),
      );
      await tester.pump();
      expect(find.text('连接状态'), findsOneWidget);
      expect(find.text('已连接'), findsOneWidget);
      expect(find.textContaining('设备服务'), findsNothing);
    },
  );

  testWidgets('empty device sync reports up to date, not failure', (
    tester,
  ) async {
    final controller =
        AppController(
            MemorySessionVault(),
            _CoverageApi(),
            MemoryHealthStore(),
            _FeatureWearable(),
          )
          ..isBooting = false
          ..connectedDevice = const DeviceInfo(
            id: 'veepoo:watch-1',
            name: 'Test Watch',
          )
          ..deviceCapabilityState = DeviceCapabilityState.ready
          ..capabilities = const DeviceCapabilities(
            metrics: {HealthMetric.heartRate},
            features: {DeviceFeature.findWatch},
            integratedFeatures: {DeviceFeature.findWatch},
          );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DevicePage(controller: controller)),
      ),
    );
    await tester.tap(find.text('Sync data'));
    await tester.pumpAndSettle();

    expect(find.text('Up to date—no new data'), findsOneWidget);
    expect(find.text('Sync failed. Please try again.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'device capability loading and failure never reveal guessed features',
    (tester) async {
      final controller = _controller()
        ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'Test Watch')
        ..deviceCapabilityState = DeviceCapabilityState.loading;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: controller,
            builder: (_, _) =>
                Scaffold(body: DevicePage(controller: controller)),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('device-capabilities-loading')),
        findsOneWidget,
      );
      expect(find.text('查找戒指'), findsNothing);

      controller.deviceCapabilityState = DeviceCapabilityState.unavailable;
      controller.notifyListeners();
      await tester.pump();
      expect(
        find.byKey(const Key('device-capabilities-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('device-capabilities-retry')),
        findsOneWidget,
      );
      expect(find.text('查找戒指'), findsNothing);
    },
  );

  testWidgets(
    'late native capability update refreshes visible device features',
    (tester) async {
      final wearable = _EventCoverageWearable();
      final controller = AppController(
        MemorySessionVault(),
        _CoverageApi(),
        MemoryHealthStore(),
        wearable,
      );
      await controller.initialize();
      addTearDown(() async {
        controller.dispose();
        await wearable.close();
      });
      await controller.connectDevice(
        const DeviceInfo(id: 'watch-1', name: 'Test Watch'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: controller,
            builder: (_, _) =>
                Scaffold(body: DevicePage(controller: controller)),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('device-capabilities-unavailable')),
        findsOneWidget,
      );

      wearable.emit(
        WearableEvent(
          type: 'capabilitiesUpdated',
          payload: const DeviceCapabilities(
            metrics: {HealthMetric.heartRate},
            features: {DeviceFeature.findWatch, DeviceFeature.camera},
            integratedFeatures: {DeviceFeature.findWatch},
          ).toJson(),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.deviceCapabilityState, DeviceCapabilityState.ready);
      expect(
        controller.visibleDeviceFeatures,
        contains(DeviceFeature.findWatch),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();

      expect(find.text('查找戒指'), findsOneWidget);
      expect(find.text('相机遥控'), findsNothing);
      expect(
        find.byKey(const Key('device-capabilities-unavailable')),
        findsNothing,
      );
    },
  );

  testWidgets('app-only device gaps direct the user to the watch', (
    tester,
  ) async {
    final controller = _controller()
      ..connectedDevice = const DeviceInfo(
        id: 'watch-only-1',
        name: 'Test Watch',
      )
      ..capabilities = const DeviceCapabilities(
        metrics: {},
        features: {DeviceFeature.phoneCalls},
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.phoneCalls,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('当前戒指暂不支持在 App 中设置'), findsOneWidget);
    expect(find.text('当前戒指不支持此功能'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected device feature pages render real controls', (
    tester,
  ) async {
    final wearable = _FeatureWearable();
    final controller = AppController(
      MemorySessionVault(),
      _CoverageApi(),
      MemoryHealthStore(),
      wearable,
    )..isBooting = false;
    addTearDown(controller.dispose);
    await controller.connectDevice(
      const DeviceInfo(id: 'veepoo:WATCH:01', name: 'Test Watch', model: 'JL'),
    );
    expect(controller.connectedDevice?.sdkSource, WearableSdkSource.veepoo);

    final cases = <DeviceFeature, String>{
      DeviceFeature.watchFaces: '系统表盘 1',
      DeviceFeature.photoWatchFace: '点击选择照片',
      DeviceFeature.notifications: '还需允许通知使用权',
      DeviceFeature.alarms: '添加闹钟',
      DeviceFeature.contacts: '添加联系人',
      DeviceFeature.weather: '更新当前位置天气',
      DeviceFeature.worldClock: '添加城市',
      DeviceFeature.healthReminders: '久坐提醒',
      DeviceFeature.healthAssessment: '压力评估',
    };
    for (final entry in cases.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceFeaturePage(
            controller: controller,
            feature: entry.key,
            key: ValueKey(entry.key),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key.name);
      expect(find.textContaining('设备服务'), findsNothing);
      if (entry.key == DeviceFeature.notifications) {
        expect(find.text('微信'), findsOneWidget);
        expect(find.text('短信'), findsOneWidget);
        expect(find.text('钉钉'), findsNothing);
        expect(find.text('企业微信'), findsNothing);
        expect(find.text('当前戒指不支持此项'), findsNothing);
      }
      if (entry.key == DeviceFeature.watchFaces) {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == '系统表盘 1预览暂不可用',
          ),
          findsOneWidget,
        );
      }
    }
  });

  for (final interval in [15, 180]) {
    testWidgets(
      'health reminder editor accepts $interval minute device value',
      (tester) async {
        final wearable = _FeatureWearable(healthReminderInterval: interval);
        final controller = AppController(
          MemorySessionVault(),
          _CoverageApi(),
          MemoryHealthStore(),
          wearable,
        )..isBooting = false;
        addTearDown(controller.dispose);
        await controller.connectDevice(
          const DeviceInfo(
            id: 'veepoo:WATCH:01',
            name: 'Test Watch',
            model: 'JL',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DeviceFeaturePage(
              controller: controller,
              feature: DeviceFeature.healthReminders,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('久坐提醒'));
        await tester.pumpAndSettle();

        expect(find.text('$interval 分钟'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'home sedentary entry uses the existing device values and preserves other reminders',
    (tester) async {
      final wearable = _FeatureWearable(includeDrinking: true);
      final controller = AppController(
        MemorySessionVault(),
        _CoverageApi(),
        MemoryHealthStore(),
        wearable,
      )..isBooting = false;
      addTearDown(controller.dispose);
      await controller.connectDevice(
        const DeviceInfo(id: 'veepoo:WATCH:01', name: 'Test Watch'),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HealthReminderCenterPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.byKey(const Key('health-reminder-sedentary'));
      await tester.scrollUntilVisible(
        entry,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(entry.hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ring-reminder-item-sedentary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ring-reminder-item-drinking')),
        findsNothing,
      );
      expect(wearable.reminderWrites, isEmpty);
      await tester.tap(find.byKey(const Key('ring-reminder-item-sedentary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ring-reminder-interval')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('180 分钟').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ring-reminder-save')));
      await tester.pumpAndSettle();
      expect(wearable.reminderWrites, hasLength(1));
      expect(wearable.reminderWrites.single, containsPair('id', 'sedentary'));
      expect(
        wearable.reminderWrites.single,
        containsPair('intervalMinutes', 180),
      );
      expect(wearable.reminderWrites.single, containsPair('startMinutes', 480));
      expect(wearable.reminderWrites.single, containsPair('endMinutes', 1320));
      expect(wearable.reminderWrites.single, containsPair('weekRepeat', 37));
      expect(
        wearable.reminderWrites.single,
        containsPair('snapshotRevision', 'synthetic-reminder-revision'),
      );
      expect(find.textContaining('每 180 分钟'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final other = find.byKey(
        const Key('health-reminder-other-ring-settings'),
      );
      await tester.ensureVisible(other);
      await tester.pumpAndSettle();
      await tester.tap(other.hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ring-reminder-item-sedentary')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('ring-reminder-item-drinking')),
        findsOneWidget,
      );
      expect(find.textContaining('每 90 分钟'), findsOneWidget);
      expect(wearable.reminderWrites, hasLength(1));
    },
  );

  testWidgets('device health reminder shortcut opens the shared home centre', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _CoverageApi(),
      MemoryHealthStore(),
      _FeatureWearable(),
    )..isBooting = false;
    addTearDown(controller.dispose);
    await controller.connectDevice(
      const DeviceInfo(id: 'veepoo:WATCH:01', name: 'Test Watch'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DevicePage(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    final shortcut = find.byKey(const Key('device-feature-health_reminders'));
    await tester.scrollUntilVisible(
      shortcut,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(shortcut), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(shortcut.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(HealthReminderCenterPage), findsOneWidget);
    expect(find.byType(DeviceFeaturePage), findsNothing);
  });

  testWidgets(
    'sedentary editor is scrollable with large text and rejects a changed target',
    (tester) async {
      final wearable = _FeatureWearable(includeDrinking: true);
      final controller = AppController(
        MemorySessionVault(),
        _CoverageApi(),
        MemoryHealthStore(),
        wearable,
      )..isBooting = false;
      addTearDown(controller.dispose);
      await controller.connectDevice(
        const DeviceInfo(id: 'veepoo:WATCH:01', name: 'Test Watch'),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: DeviceFeaturePage(
            controller: controller,
            feature: DeviceFeature.healthReminders,
            reminderView: RingReminderView.sedentary,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ring-reminder-item-sedentary')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('ring-reminder-editor')),
          matching: find.byType(SingleChildScrollView),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      controller.connectedDevice = const DeviceInfo(
        id: 'veepoo:WATCH:02',
        name: 'Other Watch',
      );
      controller.notifyListeners();
      await tester.pump();
      await tester.tap(find.byKey(const Key('ring-reminder-save')));
      await tester.pumpAndSettle();
      expect(wearable.reminderWrites, isEmpty);
      expect(find.text('连接已改变，请重新打开设置'), findsOneWidget);
    },
  );

  testWidgets('ring reminder entries are hidden without a real connection', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HealthReminderCenterPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-reminder-sedentary')), findsNothing);
    expect(
      find.byKey(const Key('health-reminder-other-ring-settings')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('health-reminder-ring-settings')),
      findsNothing,
    );
    expect(find.text('连接戒指后设置'), findsNothing);
    expect(
      find.byKey(const Key('health-reminder-urgent-help')),
      findsOneWidget,
    );
  });

  for (final hasDrinking in [false, true]) {
    testWidgets('hide absent and unknown ring settings; drinking=$hasDrinking', (
      tester,
    ) async {
      final wearable = _FeatureWearable(
        reminderItems: [
          {
            'id': 'sedentary',
            'label': '久坐提醒',
            'enabled': true,
            'supported': false,
          },
          {'id': 'unknown', 'label': '未知提醒', 'stateKnown': false},
          if (hasDrinking)
            {
              'id': 'drinking',
              'label': '饮水提醒',
              'enabled': false,
              'startMinutes': 540,
              'endMinutes': 1260,
              'intervalMinutes': 90,
            },
        ],
      );
      final controller = AppController(
        MemorySessionVault(),
        _CoverageApi(),
        MemoryHealthStore(),
        wearable,
      )..isBooting = false;
      addTearDown(controller.dispose);
      await controller.connectDevice(
        const DeviceInfo(id: 'veepoo:WATCH:01', name: 'Test Watch'),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HealthReminderCenterPage(controller: controller),
        ),
      );
      // Read is deferred until after the first frame; unknown rows stay hidden.
      await tester.pumpAndSettle();
      if (hasDrinking) {
        final other = find.byKey(
          const Key('health-reminder-other-ring-settings'),
        );
        await tester.scrollUntilVisible(
          other,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(other.hitTestable());
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('ring-reminder-item-drinking')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('ring-reminder-item-sedentary')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('ring-reminder-item-unknown')),
          findsNothing,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      } else {
        expect(
          find.byKey(const Key('health-reminder-other-ring-settings')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('health-reminder-ring-settings')),
          findsNothing,
        );
      }
      expect(find.byKey(const Key('health-reminder-sedentary')), findsNothing);
      expect(wearable.reminderWrites, isEmpty);
      final reads = wearable.reminderReads;
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        wearable.reminderReads,
        reads,
        reason: 'No automatic polling or repeated read on rebuild',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('feature page defers device reads until after its first frame', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _CoverageApi(),
      MemoryHealthStore(),
      _FeatureWearable(),
    )..isBooting = false;
    addTearDown(controller.dispose);
    await controller.connectDevice(
      const DeviceInfo(id: 'yucheng:WATCH:01', name: 'Test Watch', model: 'JL'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, _) => DeviceFeaturePage(
            controller: controller,
            feature: DeviceFeature.screenDisplay,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Yucheng find watch is one-shot and never sends a fake stop', (
    tester,
  ) async {
    final wearable = _FeatureWearable();
    final controller = AppController(
      MemorySessionVault(),
      _CoverageApi(),
      MemoryHealthStore(),
      wearable,
    )..isBooting = false;
    addTearDown(controller.dispose);
    await controller.connectDevice(
      const DeviceInfo(id: 'yucheng:WATCH:01', name: 'W8 Plus', model: 'JL'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.findWatch,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '开始查找'));
    await tester.pump();

    expect(wearable.findActionStates, [true]);
    expect(find.widgetWithText(FilledButton, '正在查找'), findsOneWidget);
    expect(find.text('停止查找'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '正在查找'));
    await tester.pump();
    expect(wearable.findActionStates, [true]);

    await tester.pump(const Duration(seconds: 6));
    expect(find.widgetWithText(FilledButton, '开始查找'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Veepoo find watch retains start and stop actions', (
    tester,
  ) async {
    final wearable = _FeatureWearable();
    final controller = AppController(
      MemorySessionVault(),
      _CoverageApi(),
      MemoryHealthStore(),
      wearable,
    )..isBooting = false;
    addTearDown(controller.dispose);
    await controller.connectDevice(
      const DeviceInfo(id: 'veepoo:WATCH:01', name: 'ET488', model: 'JL'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.findWatch,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '开始查找'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '停止查找'));
    await tester.pump();

    expect(wearable.findActionStates, [true, false]);
    expect(find.widgetWithText(FilledButton, '开始查找'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password recovery validates input without claiming success', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: PasswordRecoveryPage(controller: controller)),
    );
    await tester.enterText(
      find.byKey(const Key('password-recovery-mobile')),
      '123',
    );
    await tester.tap(find.byKey(const Key('password-recovery-submit')));
    await tester.pump();
    expect(find.text('请输入正确的中国大陆手机号'), findsOneWidget);
  });

  testWidgets('about, contact and feedback pages follow the prototype flow', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AboutSaydianPage(
          controller: controller,
          packageInfoLoader: () async => PackageInfo(
            appName: '赛电健康',
            packageName: 'com.saydian.app',
            version: '0.1.12',
            buildNumber: '14',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('V0.1.12 (14)'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(
            find.ancestor(
              of: find.text('检查更新'),
              matching: find.byType(ListTile),
            ),
          )
          .onTap,
      isNotNull,
    );

    await tester.pumpWidget(const MaterialApp(home: CustomerServicePage()));
    await tester.pumpAndSettle();
    expect(find.text('4006386738'), findsOneWidget);
    expect(find.text('公众号'), findsOneWidget);
    expect(find.text('赛电'), findsOneWidget);
    expect(find.text('添加客服'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: FeedbackPage()));
    await tester.pumpAndSettle();
    expect(find.text('问题反馈'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('常见问题'), findsOneWidget);
  });

  testWidgets('关于我们手动检查统一交给根级更新门禁', (tester) async {
    final controller = _controller();
    final updateGate = AppUpdateGateController();
    var checks = 0;
    Future<void> checkNow() async => checks++;
    updateGate.attach(checkNow);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AboutSaydianPage(
          controller: controller,
          updateGateController: updateGate,
          packageInfoLoader: () async => PackageInfo(
            appName: '赛电健康',
            packageName: 'cc.saidian.app',
            version: '0.1.19',
            buildNumber: '19',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final updateTile = find.widgetWithText(ListTile, '检查更新');
    await tester.ensureVisible(updateTile);
    await tester.pumpAndSettle();
    await tester.tap(updateTile);
    await tester.pumpAndSettle();

    expect(checks, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('关于我们忽略服务端短占位词', (tester) async {
    final controller = AppController(
      MemorySessionVault(),
      _ShortAboutApi(),
      MemoryHealthStore(),
      _CoverageWearable(),
    )..isBooting = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AboutSaydianPage(
          controller: controller,
          packageInfoLoader: () async => PackageInfo(
            appName: '赛电健康',
            packageName: 'cc.saidian.app',
            version: '0.1.19',
            buildNumber: '23',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('手动阀'), findsNothing);
    expect(find.text('记录日常健康趋势，连接家人与设备，让健康管理更简单。'), findsOneWidget);
  });

  test('release UI source does not contain developer-facing copy', () {
    final source = [
      'lib/app.dart',
      'lib/ui/pages.dart',
      'lib/ui/shop_pages.dart',
      'lib/ui/prototype_pages.dart',
    ].map(readDartLibrarySource).join('\n');
    for (final banned in [
      'BLE',
      '接口未配置',
      '错误码',
      '指令队列',
      '本地预览',
      '内测版',
      '真机验证',
      'openid',
    ]) {
      expect(source, isNot(contains(banned)), reason: 'UI contains $banned');
    }
  });
}

AppController _controller() => AppController(
  MemorySessionVault(),
  _CoverageApi(),
  MemoryHealthStore(),
  _CoverageWearable(),
)..isBooting = false;

class _CoverageApi extends Fake implements SaydianApi {
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];

  @override
  Future<Map<String, Object?>> getSingleArticle(int id) async => {
    'id': id,
    'title': switch (id) {
      2 => '用户协议',
      3 => '隐私政策',
      _ => '关于赛电',
    },
    'content': '<p>赛电健康服务说明</p>',
  };
}

class _ShortAboutApi extends _CoverageApi {
  @override
  Future<Map<String, Object?>> getSingleArticle(int id) async => {
    'id': id,
    'title': '关于赛电',
    'content': '<p>手动阀</p>',
  };
}

class _CoverageWearable extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}

class _FeatureWearable extends Fake implements WearableBridge {
  _FeatureWearable({
    this.healthReminderInterval = 60,
    this.includeDrinking = false,
    this.reminderItems,
  });

  final int healthReminderInterval;
  final bool includeDrinking;
  List<Map<String, Object?>>? reminderItems;
  int reminderReads = 0;
  final reminderWrites = <Map<String, Object?>>[];
  Map<String, Object?>? _sedentary;
  final List<bool> findActionStates = [];

  @override
  Stream<WearableEvent> get events => const Stream.empty();

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}

  @override
  Future<DeviceCapabilities> getCapabilities() async => DeviceCapabilities(
    metrics: const {HealthMetric.heartRate},
    features: DeviceFeature.values.toSet(),
    integratedFeatures: DeviceFeature.values.toSet(),
  );

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    if (feature == DeviceFeature.healthReminders) reminderReads++;
    return switch (feature) {
      DeviceFeature.watchFaces => {
        'items': [
          {
            'id': '/system/1',
            'name': '系统表盘 1',
            'type': 'system',
            'index': 0,
            'isCurrent': true,
          },
        ],
      },
      DeviceFeature.photoWatchFace => const {},
      DeviceFeature.notifications => {
        'notificationAccess': false,
        'supportedKeys': ['wechat', 'sms'],
        'wechat': true,
        'sms': true,
      },
      DeviceFeature.alarms => {'items': <Object?>[]},
      DeviceFeature.contacts => {'items': <Object?>[]},
      DeviceFeature.weather => {'enabled': true, 'useCelsius': true},
      DeviceFeature.worldClock => {'items': <Object?>[]},
      DeviceFeature.healthReminders => {
        'snapshotRevision': 'synthetic-reminder-revision',
        'items':
            reminderItems ??
            [
              _sedentary ??
                  {
                    'id': 'sedentary',
                    'label': '久坐提醒',
                    'enabled': true,
                    'startMinutes': 480,
                    'endMinutes': 1320,
                    'intervalMinutes': healthReminderInterval,
                    'weekRepeat': 37,
                  },
              if (includeDrinking)
                {
                  'id': 'drinking',
                  'label': '饮水提醒',
                  'enabled': true,
                  'startMinutes': 540,
                  'endMinutes': 1260,
                  'intervalMinutes': 90,
                },
            ],
      },
      DeviceFeature.healthAssessment => {
        'items': [
          {'id': 6, 'label': '压力评估', 'enabled': true},
        ],
      },
      _ => const {},
    };
  }

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    if (feature == DeviceFeature.healthReminders) {
      reminderWrites.add(Map.of(values));
      if (values['id'] == 'sedentary') _sedentary = Map.of(values);
    }
  }

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {
    if (feature == DeviceFeature.findWatch) {
      findActionStates.add(enabled);
    }
  }
}

class _EventCoverageWearable extends Fake implements WearableBridge {
  final _events = StreamController<WearableEvent>.broadcast();

  @override
  Stream<WearableEvent> get events => _events.stream;

  void emit(WearableEvent event) => _events.add(event);

  Future<void> close() => _events.close();

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}

  @override
  Future<DeviceCapabilities> getCapabilities() async => throw PlatformException(
    code: 'CAPABILITIES_UNAVAILABLE',
    message: '暂时无法读取此戒指的功能',
  );

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];
}
