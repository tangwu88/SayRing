import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/prototype_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'login and registration validation lead into the real app shell',
    (tester) async {
      final api = _QaApi();
      final controller = _controller(api: api)..isBooting = false;
      addTearDown(controller.dispose);
      await _pumpPhone(tester, controller);

      expect(find.text('欢迎使用 Saydian 赛电'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.tap(find.widgetWithText(FilledButton, '登录'));
      await tester.pump();
      expect(find.text('请先阅读并同意用户协议与隐私政策'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '登录'));
      await tester.pump();
      expect(find.text('请输入账号和密码'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '13800138000');
      await tester.enterText(find.byType(TextField).at(1), 'qa-password');
      await tester.tap(find.widgetWithText(FilledButton, '登录'));
      await tester.pumpAndSettle();

      expect(api.lastLogin, ('13800138000', 'qa-password'));
      expect(find.text('赛电商城'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('registration rejects invalid input and accepts valid input', (
    tester,
  ) async {
    final api = _QaApi();
    final controller = _controller(api: api)..isBooting = false;
    addTearDown(controller.dispose);
    await _pumpPhone(tester, controller);

    await tester.tap(find.widgetWithText(TextButton, '注册账户'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('registration-mobile')), '123');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.enterText(find.byType(TextField).at(2), '1');
    await tester.ensureVisible(find.byKey(const Key('registration-submit')));
    await tester.tap(find.byKey(const Key('registration-submit')));
    await tester.pump();
    expect(find.text('请输入正确的中国大陆手机号'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('registration-mobile')),
      '13900139000',
    );
    await tester.enterText(
      find.byKey(const Key('registration-code')),
      '123456',
    );
    await tester.enterText(find.byType(TextField).at(2), '123456');
    await tester.enterText(find.byType(TextField).at(3), '123456');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.byKey(const Key('registration-submit')));
    await tester.tap(find.byKey(const Key('registration-submit')));
    await tester.pumpAndSettle();

    expect(api.lastRegistration, ('13900139000', '123456'));
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('shop search, product, checkout and pending payment flow works', (
    tester,
  ) async {
    final api = _QaApi();
    final controller = _authenticatedController(api: api);
    addTearDown(controller.dispose);
    await _pumpPhone(tester, controller);

    await tester.tap(find.text('赛电商城'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-page')), findsOneWidget);
    expect(find.text('QA 智能手表'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('shop-search')), '不存在');
    await tester.pump();
    expect(find.text('当前分类暂无商品'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('shop-search')), 'QA');
    await tester.pump();
    await tester.tap(find.text('QA 智能手表'));
    await tester.pumpAndSettle();

    expect(find.text('商品详情'), findsWidgets);
    expect(find.text('黑色'), findsOneWidget);
    expect(find.text('用于 QA 的商品详情'), findsOneWidget);
    expect(find.text('加入购物车'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '立即购买'));
    await tester.pumpAndSettle();
    expect(find.text('请选择规格'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '立即购买').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop-checkout')), findsOneWidget);
    expect(find.textContaining('QA 收货人'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '给商家留言'), 'QA留言');
    await tester.tap(find.widgetWithText(FilledButton, '提交订单'));
    await tester.pumpAndSettle();

    expect(api.createdOrder, isTrue);
    expect(find.text('订单提交成功，等待支付'), findsOneWidget);
    expect(find.textContaining('当前请在微信小程序完成支付'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shopping cart persists items and supports quantity changes', (
    tester,
  ) async {
    final controller = _authenticatedController();
    addTearDown(controller.dispose);
    await controller.addToShopCart(
      product: const {'id': 1, 'name': 'QA 智能手表', 'picture': '', 'price': 199},
      sku: const {'id': 11, 'name': '黑色', 'price': 199, 'stock': 5},
      quantity: 1,
    );
    await controller.addToShopCart(
      product: const {'id': 2, 'name': 'QA 体温手表', 'picture': '', 'price': 299},
      sku: const {'id': 22, 'name': '银色', 'price': 299, 'stock': 5},
      quantity: 1,
    );
    await _pumpPhone(tester, controller);

    await tester.tap(find.text('赛电商城'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('购物车'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shopping-cart-page')), findsOneWidget);
    expect(find.text('QA 智能手表'), findsOneWidget);
    expect(find.text('¥199.00'), findsWidgets);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    expect(controller.shopCart.first['quantity'], 2);
    expect(find.textContaining('已选2件'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.textContaining('已选1件'), findsOneWidget);
    expect(find.byKey(const Key('cart-checkout')), findsOneWidget);
  });

  testWidgets('preview mode shows a prominent login prompt on my page', (
    tester,
  ) async {
    final controller = _controller()..isBooting = false;
    controller.enterPreview();
    addTearDown(controller.dispose);
    await _pumpPhone(tester, controller);

    controller.selectTab(2);
    await tester.pump();
    expect(find.byKey(const Key('preview-login-prompt')), findsOneWidget);
    expect(find.text('立即登录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('preview-login-prompt')));
    await tester.pumpAndSettle();
    expect(controller.isPreviewMode, isFalse);
    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
  });

  testWidgets('my page hides add-device entry while a watch is connected', (
    tester,
  ) async {
    final wearable = _QaWearable();
    final controller = _authenticatedController(wearable: wearable)
      ..connectedDevice = wearable.scannedDevice;
    addTearDown(controller.dispose);
    await _pumpPhone(tester, controller);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-add-device')), findsNothing);
    expect(find.text('在线'), findsOneWidget);
  });

  testWidgets('sharing management authorizes accepted incoming caregiver', (
    tester,
  ) async {
    final controller = _authenticatedController()
      ..careInvitations = const [
        {
          'id': 59,
          'inviter_id': 82,
          'to_member_id': 87,
          'examine_status': 1,
          'member': <String, Object?>{},
        },
      ];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SharingManagementPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('关爱邀请人'), findsOneWidget);
    expect(find.textContaining('邀请人账号 ID：82'), findsOneWidget);
    expect(find.text('暂无需要授权的关爱人'), findsNothing);
  });

  testWidgets('device scan and connection uses the wearable flow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final wearable = _QaWearable();
      final controller = _controller(wearable: wearable);
      await controller.initialize();
      controller
        ..session = _session
        ..memberProfile = const {
          'nickname': 'QA 用户',
          'birthday': '1990-01-01',
          'height': 170,
          'weight': 60,
          'gender': 1,
        };
      addTearDown(controller.dispose);
      await _pumpPhone(tester, controller);

      await tester.tap(find.text('设备'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '开始查找'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('添加设备'), findsOneWidget);
      expect(find.text('QA Watch'), findsOneWidget);
      expect(wearable.scanCount, 1);
      expect(find.byKey(const Key('device-shop-entry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('device-shop-entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-page')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pumpAndSettle();

      expect(wearable.stopScanCount, 1);
      expect(wearable.connectedDeviceId, 'QA:WATCH:01');
      expect(find.text('添加设备'), findsNothing);
      expect(find.text('QA Watch'), findsOneWidget);
      expect(find.text('已连接'), findsWidgets);
      expect(controller.connectedDevice?.firmwareVersion, 'QA-FW-1');
      expect(wearable.syncCount, 1);
      expect(wearable.readSportCount, 1);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'cloud upload failure does not overwrite a successful device sync status',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final api = _QaApi(
          uploadError: const FeatureNotConfiguredException('批量健康同步接口未配置'),
        );
        final wearable = _QaWearable(
          syncRecords: [
            HealthRecord(
              id: 'record-1',
              metric: HealthMetric.heartRate,
              values: const {'value': 72},
              unit: 'bpm',
              measuredAt: DateTime.utc(2026, 8, 13),
              timezone: '+08:00',
              deviceId: 'QA:WATCH:01',
              firmwareVersion: 'QA-FW-1',
              quality: 'good',
              source: MeasurementSource.wearable,
              rawVersion: 1,
            ),
          ],
        );
        final controller = _controller(api: api, wearable: wearable);
        await controller.initialize();
        controller
          ..session = _session
          ..memberProfile = const {
            'nickname': 'QA 用户',
            'birthday': '1990-01-01',
            'height': 170,
            'weight': 60,
            'gender': 1,
          };
        addTearDown(controller.dispose);
        await _pumpPhone(tester, controller);

        await tester.tap(find.text('设备'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, '开始查找'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        await tester.tap(find.text('连接'));
        await tester.pumpAndSettle();

        expect(controller.syncStatus, '已同步 1 条');
        expect(controller.cloudSyncStatus, '批量健康同步接口未配置');
        expect(controller.syncStatus, '已同步 1 条');
        expect(find.textContaining('设备同步：'), findsNothing);
        expect(find.textContaining('云端同步：'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('device connection error remains visible beside scan results', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      const errorMessage = '蓝牙连接失败（SDK REQUEST_FAILED，代码 -1），请确认手表未连接其他手机后重试';
      final wearable = _QaWearable(connectError: errorMessage);
      final controller = _controller(wearable: wearable);
      await controller.initialize();
      controller
        ..session = _session
        ..memberProfile = const {
          'nickname': 'QA 用户',
          'birthday': '1990-01-01',
          'height': 170,
          'weight': 60,
          'gender': 1,
        };
      addTearDown(controller.dispose);
      await _pumpPhone(tester, controller);

      await tester.tap(find.text('设备'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '开始查找'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('连接'));
      await tester.pumpAndSettle();

      expect(find.text('添加设备'), findsOneWidget);
      expect(find.text('QA Watch'), findsOneWidget);
      expect(find.text('连接失败，请确认手表未连接其他手机后重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test(
    'transient disconnect during a successful connection keeps the device ready',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final wearable = _QaWearable(transientDisconnectDuringConnect: true);
        final controller = _controller(wearable: wearable);
        await controller.initialize();
        addTearDown(controller.dispose);

        final scan = controller.scanDevices();
        await Future<void>.delayed(Duration.zero);
        await controller.connectDevice(wearable.scannedDevice);
        await scan;
        await Future<void>.delayed(Duration.zero);

        expect(controller.deviceState, DeviceConnectionState.ready);
        expect(controller.connectedDevice?.id, 'QA:WATCH:01');
        expect(controller.errorMessage, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test('automatic reconnect restores the ready device state', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final wearable = _QaWearable();
      final controller = _controller(wearable: wearable);
      await controller.initialize();
      addTearDown(controller.dispose);

      final scan = controller.scanDevices();
      await Future<void>.delayed(Duration.zero);
      await controller.connectDevice(wearable.scannedDevice);
      await scan;
      wearable.emitEvent(
        const WearableEvent(type: 'disconnected', payload: {}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.deviceState, DeviceConnectionState.disconnected);

      wearable.emitEvent(
        const WearableEvent(
          type: 'reconnected',
          payload: {
            'id': 'QA:WATCH:01',
            'name': 'QA Watch',
            'model': 'QA-1',
            'firmwareVersion': 'QA-FW-2',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.connectedDevice?.firmwareVersion, 'QA-FW-2');
      expect(controller.errorMessage, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test(
    'measurement sentinels finish with guidance before a retry succeeds',
    () async {
      final wearable = _QaWearable();
      final store = MemoryHealthStore();
      final controller = _controller(wearable: wearable, store: store);
      await controller.initialize();
      addTearDown(controller.dispose);
      controller.connectedDevice = wearable.scannedDevice;
      controller.capabilities = const DeviceCapabilities(
        metrics: {HealthMetric.heartRate, HealthMetric.bloodOxygen},
        manualMetrics: {HealthMetric.heartRate, HealthMetric.bloodOxygen},
      );
      for (final state in const [
        DeviceConnectionState.scanning,
        DeviceConnectionState.connecting,
        DeviceConnectionState.authenticating,
        DeviceConnectionState.syncing,
        DeviceConnectionState.ready,
      ]) {
        controller.deviceMachine.transition(state);
      }
      expect(await controller.startMeasurement(HealthMetric.heartRate), isTrue);

      wearable.emitMeasurement('invalid-heart', 'heart_rate', 1, 'bpm');
      await Future<void>.delayed(Duration.zero);
      expect(controller.latestByMetric[HealthMetric.heartRate], isNull);
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.measurementErrorMessage, contains('结果无效'));
      expect(await store.pending(), isEmpty);

      expect(await controller.startMeasurement(HealthMetric.heartRate), isTrue);
      wearable.emitMeasurement('valid-heart', 'heart_rate', 78, 'bpm');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.latestByMetric[HealthMetric.heartRate]?.values['value'],
        78,
      );
      expect(controller.deviceState, DeviceConnectionState.ready);

      expect(
        await controller.startMeasurement(HealthMetric.bloodOxygen),
        isTrue,
      );
      wearable.emitMeasurement('invalid-oxygen', 'blood_oxygen', 1, '%');
      await Future<void>.delayed(Duration.zero);
      expect(controller.latestByMetric[HealthMetric.bloodOxygen], isNull);
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.measurementErrorMessage, contains('结果无效'));

      expect(
        await controller.startMeasurement(HealthMetric.bloodOxygen),
        isTrue,
      );
      wearable.emitMeasurement('valid-oxygen', 'blood_oxygen', 97, '%');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.latestByMetric[HealthMetric.bloodOxygen]?.values['value'],
        97,
      );
      expect(controller.deviceState, DeviceConnectionState.ready);
    },
  );

  test(
    'a terminal wearable measurement error restores the ready state',
    () async {
      final wearable = _QaWearable();
      final controller = _controller(wearable: wearable);
      await controller.initialize();
      addTearDown(controller.dispose);
      controller.connectedDevice = wearable.scannedDevice;
      for (final state in const [
        DeviceConnectionState.scanning,
        DeviceConnectionState.connecting,
        DeviceConnectionState.authenticating,
        DeviceConnectionState.syncing,
        DeviceConnectionState.ready,
        DeviceConnectionState.measuring,
      ]) {
        controller.deviceMachine.transition(state);
      }

      wearable.emitEvent(
        const WearableEvent(
          type: 'error',
          payload: {'code': 'HEART_NOT_WORN', 'message': '请正确佩戴手表后重新测量心率'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.errorMessage, contains('正确佩戴'));
    },
  );

  test(
    'an unrelated live health record does not cancel the active measurement',
    () async {
      final wearable = _QaWearable();
      final controller = _controller(wearable: wearable);
      await controller.initialize();
      addTearDown(controller.dispose);
      controller.connectedDevice = wearable.scannedDevice;
      controller.capabilities = const DeviceCapabilities(
        metrics: {HealthMetric.heartRate, HealthMetric.hrv},
        manualMetrics: {HealthMetric.heartRate},
      );
      for (final state in const [
        DeviceConnectionState.scanning,
        DeviceConnectionState.connecting,
        DeviceConnectionState.authenticating,
        DeviceConnectionState.syncing,
        DeviceConnectionState.ready,
      ]) {
        controller.deviceMachine.transition(state);
      }
      expect(await controller.startMeasurement(HealthMetric.heartRate), isTrue);

      wearable.emitMeasurement('live-hrv', 'hrv', 52, 'ms');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.activeMeasurementMetric, HealthMetric.heartRate);
      expect(controller.deviceState, DeviceConnectionState.measuring);
      expect(controller.latestByMetric[HealthMetric.hrv]?.values['value'], 52);

      wearable.emitMeasurement('live-heart', 'heart_rate', 76, 'bpm');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.activeMeasurementMetric, isNull);
      expect(controller.deviceState, DeviceConnectionState.ready);
    },
  );

  test(
    'a non-measurement wearable error does not stop an active sport',
    () async {
      final wearable = _QaWearable();
      final controller = _controller(wearable: wearable);
      await controller.initialize();
      addTearDown(controller.dispose);
      controller.connectedDevice = wearable.scannedDevice;
      for (final state in const [
        DeviceConnectionState.scanning,
        DeviceConnectionState.connecting,
        DeviceConnectionState.authenticating,
        DeviceConnectionState.syncing,
        DeviceConnectionState.ready,
        DeviceConnectionState.measuring,
      ]) {
        controller.deviceMachine.transition(state);
      }
      controller.activeSport = SportMode.running;

      wearable.emitEvent(
        const WearableEvent(
          type: 'error',
          payload: {'code': 'SYNC_FAILED', 'message': '同步暂时失败'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.deviceState, DeviceConnectionState.measuring);
      expect(controller.activeSport, SportMode.running);
      expect(controller.errorMessage, isNotNull);
    },
  );

  testWidgets('initial sync failure keeps the authenticated device ready', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final wearable = _QaWearable(
        syncError: PlatformException(
          code: 'SYNC_FAILED',
          message: '设备睡眠数据读取超时',
        ),
      );
      final controller = _controller(wearable: wearable);
      await controller.initialize();
      controller
        ..session = _session
        ..memberProfile = const {
          'nickname': 'QA 用户',
          'gender': 1,
          'height': 175,
          'weight': 70,
          'birthday': '1990-01-01',
        };
      addTearDown(controller.dispose);
      await _pumpPhone(tester, controller);
      await tester.tap(find.text('设备'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '开始查找'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text('连接'));
      await tester.pumpAndSettle();

      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.connectedDevice?.id, 'QA:WATCH:01');
      expect(controller.errorMessage, isNull);
      expect(find.textContaining('设备已连接'), findsWidgets);
      expect(wearable.readSportCount, 0);
      expect(find.text('添加设备'), findsNothing);

      wearable.syncError = null;
      await tester.tap(find.widgetWithText(FilledButton, '同步数据'));
      await tester.pumpAndSettle();
      expect(wearable.syncCount, 2);
      expect(controller.errorMessage, isNull);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('my summary cards open their related pages', (tester) async {
    final controller = _authenticatedController();
    addTearDown(controller.dispose);
    await _pumpPhone(tester, controller);

    await tester.tap(find.text('我的'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('profile-stat-device')));
    await tester.pump();
    expect(controller.selectedTab, 1);
    expect(find.text('添加智能设备'), findsOneWidget);

    controller.selectTab(2);
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-stat-health-records')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('健康记录')),
      findsOneWidget,
    );
    expect(find.text('健康数据总览'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-stat-care-members')));
    await tester.pumpAndSettle();
    expect(find.text('远程关爱'), findsOneWidget);
    expect(find.text('守护家人健康'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI, my-page entries, orders and logout remain navigable', (
    tester,
  ) async {
    final api = _QaApi();
    final controller = _authenticatedController(api: api)
      ..aiArticles = const [
        {'id': 7, 'title': 'QA 健康百科', 'created_at': 1786000000},
      ];
    addTearDown(controller.dispose);
    await _pumpPhone(tester, controller);

    await tester.tap(find.byKey(const Key('dashboard-ai-ask')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '如何改善睡眠？');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(find.text('如何改善睡眠？'), findsOneWidget);
    expect(api.lastAiMessage, '如何改善睡眠？');
    expect(find.byKey(const Key('ai-message-input')), findsNothing);
    expect(find.byKey(const Key('ai-show-composer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-show-composer')));
    await tester.pump();
    expect(find.byKey(const Key('ai-message-input')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(find.text('我的订单'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '全部'));
    await tester.pumpAndSettle();
    expect(find.text('我的订单'), findsOneWidget);
    expect(find.textContaining('QA-ORDER-100'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('my-add-device')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('my-add-device')));
    await tester.pumpAndSettle();
    expect(find.text('添加设备'), findsOneWidget);
    expect(find.byKey(const Key('device-shop-entry')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('my-ai-question')));
    await tester.tap(find.byKey(const Key('my-ai-question')));
    await tester.pumpAndSettle();
    expect(find.text('AI 健康管家'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('账号设置'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('账号设置'));
    await tester.pumpAndSettle();
    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('收货地址'), findsOneWidget);
    expect(find.text('注销账号'), findsOneWidget);

    await tester.fling(
      find.byType(Scrollable).last,
      const Offset(0, -700),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-logout')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-logout')));
    await tester.pumpAndSettle();
    expect(api.loggedOut, isTrue);
    expect(controller.session, isNull);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'notifications, care, sport and preference pages stay navigable',
    (tester) async {
      final api = _QaApi();
      final controller = _authenticatedController(api: api);
      addTearDown(controller.dispose);
      await _pumpPhone(tester, controller);

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();
      expect(find.text('QA 公告'), findsOneWidget);
      await tester.tap(find.text('QA 公告'));
      await tester.pumpAndSettle();
      expect(find.text('公告正文'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('远程关爱'));
      await tester.pumpAndSettle();
      expect(find.text('守护家人健康'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('健康'));
      await tester.pump();
      await tester.ensureVisible(find.text('全部数据'));
      await tester.tap(find.text('全部数据'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('health-sport-entries')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('health-sport-entries')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跑步'));
      await tester.pumpAndSettle();
      expect(find.textContaining('请先在设备页连接手表'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('运动记录'));
      await tester.pumpAndSettle();
      expect(find.text('请先连接手表后读取运动记录'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('我的'));
      await tester.pump();
      await tester.tap(find.text('单位设置'));
      await tester.pumpAndSettle();
      expect(find.text('公里'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('目标设置'), findsNothing);
      expect(find.byKey(const Key('my-add-device')), findsOneWidget);
      expect(find.byKey(const Key('my-ai-question')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing add care dialog does not use a disposed controller', (
    tester,
  ) async {
    final controller = _authenticatedController();
    addTearDown(controller.dispose);
    await _pumpPhone(tester, controller);

    await tester.tap(find.text('远程关爱'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加关爱'));
    await tester.tap(find.text('添加关爱'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '添加关爱'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('care dialog rejects the signed-in account mobile', (
    tester,
  ) async {
    final controller = _authenticatedController();
    addTearDown(controller.dispose);
    await _pumpPhone(tester, controller);

    await tester.tap(find.text('远程关爱'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加关爱'));
    await tester.tap(find.text('添加关爱'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '13600136000');
    await tester.tap(find.widgetWithText(FilledButton, '发送'));
    await tester.pump();

    expect(find.text('不能添加当前登录账号'), findsOneWidget);
  });

  test(
    'notification history loads every page and removes duplicates',
    () async {
      final api = _RegressionApi();
      final controller = _authenticatedController(api: api);
      addTearDown(controller.dispose);

      await controller.refreshNotificationHistory(allPages: true);

      expect(api.notificationPages, [1, 2, 3]);
      expect(controller.notifications.map((item) => item['id']), [1, 2, 3]);
      expect(controller.notificationStatus, '已加载');
    },
  );

  test('care refresh hides only the signed-in member relation', () async {
    final api = _RegressionApi();
    final controller = _authenticatedController(api: api);
    addTearDown(controller.dispose);

    await controller.refreshCare();

    expect(controller.careMembers, hasLength(1));
    expect(controller.careMembers.single['id'], 49);
    expect(controller.careStatus, '已加载');
  });

  test('AI history normalizes string sender flags', () async {
    final api = _RegressionApi();
    final controller = _authenticatedController(api: api);
    addTearDown(controller.dispose);

    await controller.refreshAiMessages(app: 1);

    expect(controller.aiMessages.map((item) => item['my']), [0, 1]);
    expect(controller.errorMessage, isNull);
  });
}

AppController _controller({
  _QaApi? api,
  _QaWearable? wearable,
  HealthStore? store,
}) => AppController(
  MemorySessionVault(),
  api ?? _QaApi(),
  store ?? MemoryHealthStore(),
  wearable ?? _QaWearable(),
);

AppController _authenticatedController({_QaApi? api, _QaWearable? wearable}) {
  final controller = _controller(api: api, wearable: wearable)
    ..isBooting = false
    ..session = _session
    ..memberProfile = const {
      'nickname': 'QA 用户',
      'mobile': '13600136000',
      'birthday': '1990-01-01',
      'height': 170,
      'weight': 60,
      'gender': 1,
    };
  return controller;
}

Future<void> _pumpPhone(WidgetTester tester, AppController controller) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(SaydianApp(controller: controller));
  await tester.pump();
}

final _session = Session(
  accessToken: 'qa-token',
  refreshToken: 'qa-refresh',
  expiresAt: DateTime(2030),
  memberId: '100',
  displayName: 'QA 用户',
);

class _QaApi extends Fake
    implements SaydianApi, SaydianShopApi, SaydianArticleApi {
  _QaApi({this.uploadError});

  final ApiException? uploadError;
  (String, String)? lastLogin;
  (String, String)? lastRegistration;
  String? lastAiMessage;
  bool createdOrder = false;
  bool loggedOut = false;

  @override
  Future<Session> login(String username, String password) async {
    lastLogin = (username, password);
    return _session;
  }

  @override
  Future<Session> register(String mobile, String password) async {
    lastRegistration = (mobile, password);
    return _session;
  }

  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => const [];

  @override
  Future<Map<String, Object?>> getMemberProfile() async => const {
    'nickname': 'QA 用户',
    'birthday': '1990-01-01',
    'height': 170,
    'weight': 60,
    'gender': 1,
  };

  @override
  Future<Map<String, Object?>> getActivityGoals() async => const {
    'steps': 10000,
    'juli': 6,
    'reliang': 800,
  };

  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [
    {'id': 7, 'title': 'QA 健康百科'},
  ];

  @override
  Future<List<Map<String, Object?>>> getArticleCategories({
    int parentId = 3,
  }) async => const [
    {'id': 31, 'pid': 3, 'title': '心脑健康'},
  ];

  @override
  Future<List<Map<String, Object?>>> getArticlesByCategory({
    int? categoryId,
    int page = 1,
  }) => getArticles();

  @override
  Future<Map<String, Object?>> getArticle(int id) async => {
    'id': id,
    'title': 'QA 健康百科',
    'content': '<p>QA 正文</p>',
  };

  @override
  Future<Map<String, Object?>> getSingleArticle(int id) => getArticle(id);

  @override
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  }) async => const [];

  @override
  Future<Map<String, Object?>> sendAiMessage({
    required int app,
    required String message,
    String? sessionId,
  }) async {
    lastAiMessage = message;
    return const {
      'id': 1,
      'message': 'QA AI 回复',
      'my': 0,
      'session_id': 'qa-chat',
    };
  }

  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      const [
        {'id': 8, 'title': 'QA 公告', 'created_at': '2026-08-10'},
      ];

  @override
  Future<Map<String, Object?>> getNotification(int id) async => {
    'id': id,
    'title': 'QA 公告',
    'content': '公告正文',
  };

  @override
  Future<List<Map<String, Object?>>> getOrders({int? status}) async => const [
    {
      'id': 100,
      'order_sn': 'QA-ORDER-100',
      'order_status': 0,
      'pay_money': 199,
      'created_at': '2026-08-10',
    },
  ];

  @override
  Future<Map<String, Object?>> getOrderDetail(int id) async => {
    'id': id,
    'order_sn': 'QA-ORDER-$id',
    'order_status': 0,
    'pay_money': 199,
  };

  @override
  Future<List<Map<String, Object?>>> getAddresses() async => const [
    {
      'id': 5,
      'realname': 'QA 收货人',
      'mobile': '13800138000',
      'region': '广东省 深圳市 南山区',
      'address_details': '科技园 1 号',
      'is_default': 1,
    },
  ];

  @override
  Future<Map<String, Object?>> getShopHome() async => const {
    'items': [
      {
        'type': 'tabs',
        'value': [
          {
            'name': '智能穿戴',
            'list': [
              {
                'id': 1,
                'name': 'QA 智能手表',
                'picture': '',
                'price': 199,
                'sales': 12,
              },
            ],
          },
        ],
      },
    ],
  };

  @override
  Future<Map<String, Object?>> getShopProduct(int id) async => {
    'id': id,
    'name': 'QA 智能手表',
    'picture': '',
    'price': 199,
    'sales': 12,
    'stock': 5,
    'intro': '<p>用于 QA 的商品详情</p>',
    'sku': const [
      {'id': 11, 'name': '黑色', 'price': 199, 'stock': 5},
    ],
  };

  @override
  Future<Map<String, Object?>> previewShopOrder({
    required List<Map<String, int>> items,
  }) async => {
    'address': const {
      'id': 5,
      'realname': 'QA 收货人',
      'mobile': '13800138000',
      'region': '广东省 深圳市 南山区',
      'address_details': '科技园 1 号',
    },
    'preview': const {'product_money': 199, 'shipping_money': 0},
    'account': const {'money1': 100},
    'products': [
      {
        'product_name': 'QA 智能手表',
        'sku_name': '黑色',
        'product_money': 199,
        'num': items.first['num'] ?? 1,
      },
    ],
  };

  @override
  Future<Map<String, Object?>> createShopOrder({
    required List<Map<String, int>> items,
    required int addressId,
    String buyerMessage = '',
    num point = 0,
  }) async {
    createdOrder = true;
    return const {'id': 100};
  }

  @override
  Future<void> confirmOrderReceipt(int orderId) async {}

  @override
  Future<void> applyOrderRefund({
    required int orderProductId,
    required int refundType,
    required num amount,
    required String reason,
  }) async {}

  @override
  Future<void> saveMemberProfile({
    required String nickname,
    required int gender,
    required String birthday,
    required double height,
    required double weight,
    String? headPortrait,
  }) async {}

  @override
  Future<void> saveActivityGoals({
    required int steps,
    required double distance,
    required int calories,
  }) async {}

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    if (uploadError case final error?) throw error;
    return BatchUploadResult(
      acceptedIds: batch.records.map((record) => record.id).toSet(),
      rejected: const {},
      nextCursor: null,
    );
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  Future<void> deleteAccount() async {}
}

class _RegressionApi extends _QaApi {
  final List<int> notificationPages = [];

  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async {
    notificationPages.add(page);
    return switch (page) {
      1 => const [
        {'id': 1, 'title': '预警 1'},
        {'id': 2, 'title': '预警 2'},
      ],
      2 => const [
        {'id': 2, 'title': '预警 2'},
        {'id': 3, 'title': '预警 3'},
      ],
      _ => const [],
    };
  }

  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => const [
    {
      'id': 57,
      'member': {'id': 100, 'nickname': '当前账号'},
    },
    {
      'id': 49,
      'member': {'id': 85, 'nickname': '家人'},
    },
  ];

  @override
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  }) async => const [
    {'id': 2, 'message': '用户问题', 'my': '1', 'session_id': 'qa'},
    {'id': 3, 'message': 'AI 回复', 'my': '0', 'session_id': 'qa'},
  ];
}

class _QaWearable extends Fake implements WearableBridge {
  _QaWearable({
    this.connectError,
    this.syncError,
    this.syncRecords = const [],
    this.transientDisconnectDuringConnect = false,
    DeviceInfo? scannedDevice,
  }) : scannedDevice = scannedDevice ?? _watch;

  final _events = StreamController<WearableEvent>.broadcast();
  final String? connectError;
  PlatformException? syncError;
  final List<HealthRecord> syncRecords;
  final bool transientDisconnectDuringConnect;
  final DeviceInfo scannedDevice;
  int scanCount = 0;
  int stopScanCount = 0;
  int syncCount = 0;
  int readSportCount = 0;
  String? connectedDeviceId;
  Completer<List<DeviceInfo>>? _scanCompleter;

  static const _watch = DeviceInfo(
    id: 'QA:WATCH:01',
    name: 'QA Watch',
    model: 'QA-1',
    rssi: -40,
  );

  @override
  Stream<WearableEvent> get events => _events.stream;

  void emitEvent(WearableEvent event) => _events.add(event);

  void emitMeasurement(String id, String type, num value, String unit) =>
      _events.add(
        WearableEvent(
          type: 'healthRecord',
          payload: {
            'id': id,
            'type': type,
            'values': {'value': value},
            'unit': unit,
            'measuredAt': DateTime.now().toUtc().toIso8601String(),
            'timezone': '+08:00',
            'deviceId': scannedDevice.id,
            'firmwareVersion': 'test',
            'quality': 'device_reported',
            'source': 'wearable',
            'rawVersion': 1,
          },
        ),
      );

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    scanCount++;
    _scanCompleter = Completer<List<DeviceInfo>>();
    scheduleMicrotask(
      () => _events.add(
        WearableEvent(type: 'scanDevice', payload: scannedDevice.toJson()),
      ),
    );
    return _scanCompleter!.future;
  }

  @override
  Future<void> stopScan() async {
    stopScanCount++;
    if (!(_scanCompleter?.isCompleted ?? true)) {
      _scanCompleter!.complete([scannedDevice]);
    }
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    if (connectError case final message?) {
      throw PlatformException(code: 'CONNECT_FAILED', message: message);
    }
    if (transientDisconnectDuringConnect) {
      _events.add(const WearableEvent(type: 'disconnected', payload: {}));
      await Future<void>.delayed(Duration.zero);
    }
    connectedDeviceId = deviceId;
    scheduleMicrotask(
      () => _events.add(
        const WearableEvent(
          type: 'deviceDetails',
          payload: {
            'id': 'QA:WATCH:01',
            'name': 'QA Watch',
            'model': 'QA-1',
            'firmwareVersion': 'QA-FW-1',
          },
        ),
      ),
    );
  }

  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(
        metrics: {HealthMetric.heartRate, HealthMetric.bloodOxygen},
      );

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    syncCount++;
    if (syncError case final error?) throw error;
    return syncRecords;
  }

  @override
  Future<void> startMeasurement(HealthMetric metric) async {}

  @override
  Future<void> stopMeasurement(HealthMetric metric) async {}

  @override
  Future<List<SportRecord>> readSportRecords() async {
    readSportCount++;
    return const [];
  }

  @override
  Future<void> disconnect() async {}
}
