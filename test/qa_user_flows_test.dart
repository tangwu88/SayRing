import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_payment_bridge.dart';
import 'package:saydian_app/services/app_update_service.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';
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
    await tester.enterText(
      find.byKey(const Key('shop-checkout-points')),
      '200',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, '提交订单'));
    await tester.tap(find.widgetWithText(FilledButton, '提交订单'));
    await tester.pump();
    expect(find.text('使用积分不能超过订单金额 199.00'), findsOneWidget);
    expect(api.createdOrder, isFalse);

    await tester.enterText(find.byKey(const Key('shop-checkout-points')), '20');
    await tester.tap(find.widgetWithText(FilledButton, '提交订单'));
    await tester.pumpAndSettle();

    expect(api.createdOrder, isTrue);
    expect(find.text('支付收银台'), findsOneWidget);
    expect(find.text('订单号'), findsOneWidget);
    expect(find.text('使用积分数量'), findsOneWidget);
    expect(find.text('20.00'), findsOneWidget);
    expect(find.text('订单总额'), findsOneWidget);
    expect(find.text('微信支付'), findsOneWidget);
    expect(find.text('支付宝支付'), findsOneWidget);
    expect(find.byKey(const Key('shop-pay-submit')), findsOneWidget);
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

  testWidgets('shop product and cart remain usable on a 320px Android screen', (
    tester,
  ) async {
    final controller = _authenticatedController();
    addTearDown(controller.dispose);
    await controller.addToShopCart(
      product: const {
        'id': 1,
        'name': '华为6A数据线加长版',
        'picture': '',
        'price': 500,
      },
      sku: const {'id': 11, 'name': '800ml/瓶', 'price': 500, 'stock': 5},
      quantity: 1,
    );
    await _pumpPhone(tester, controller);
    await tester.binding.setSurfaceSize(const Size(320, 568));
    await tester.pumpAndSettle();

    await tester.tap(find.text('赛电商城'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QA 智能手表'));
    await tester.pumpAndSettle();
    expect(find.text('品质保障'), findsOneWidget);
    expect(find.text('配送到家'), findsOneWidget);
    expect(find.text('售后服务'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _popRoute(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('购物车'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shopping-cart-page')), findsOneWidget);
    expect(find.text('¥500.00'), findsWidgets);
    expect(find.byKey(const Key('cart-checkout')), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets(
    'care pending count and list ignore accepted or rejected invitations',
    (tester) async {
      final controller = _authenticatedController(
        api: _MixedCareInvitationApi(),
      );
      addTearDown(controller.dispose);
      await controller.refreshCareInvitations();

      expect(controller.careInvitations, hasLength(3));
      expect(controller.pendingCareInvitations, hasLength(1));

      await tester.pumpWidget(
        MaterialApp(home: CarePage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 条待处理'), findsOneWidget);
      await tester.tap(find.text('关爱邀请'));
      await tester.pumpAndSettle();
      expect(find.text('待处理成员'), findsOneWidget);
      expect(find.text('已接受成员'), findsNothing);
      expect(find.text('已拒绝成员'), findsNothing);
      expect(find.widgetWithText(FilledButton, '同意'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '拒绝'), findsOneWidget);
    },
  );

  testWidgets('device scan and connection uses the wearable flow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final wearable = _QaWearable(
        scannedDevice: const DeviceInfo(
          id: 'veepoo:QA:WATCH:01',
          name: 'QA Watch',
          model: 'QA-1',
          rssi: -40,
        ),
      );
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
      expect(find.text('Vep'), findsOneWidget);
      expect(wearable.scanCount, 1);
      expect(find.byKey(const Key('device-shop-entry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('device-shop-entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-page')), findsOneWidget);
      await _popRoute(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pumpAndSettle();

      expect(wearable.stopScanCount, 1);
      expect(wearable.connectedDeviceId, 'veepoo:QA:WATCH:01');
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
    'a delayed disconnect from an old watch keeps the current watch ready',
    () async {
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
          const WearableEvent(
            type: 'disconnected',
            payload: {'deviceId': 'QA:WATCH:OLD'},
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(controller.deviceState, DeviceConnectionState.ready);
        expect(controller.connectedDevice?.id, 'QA:WATCH:01');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

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
      controller.capabilities = const DeviceCapabilities(
        metrics: {HealthMetric.heartRate},
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
      wearable.emitEvent(
        const WearableEvent(
          type: 'measurementProgress',
          payload: {
            'metric': 'heart_rate',
            'progress': 42,
            'samples': [1, 2, 3],
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      wearable.emitEvent(
        const WearableEvent(
          type: 'error',
          payload: {'code': 'HEART_NOT_WORN', 'message': '请正确佩戴手表后重新测量心率'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.errorMessage, contains('正确佩戴'));
      expect(controller.activeMeasurementMetric, isNull);
      expect(controller.measurementProgress, 0);
      expect(controller.measurementSamples, isEmpty);
      expect(controller.measurementWearConfirmed, isFalse);
      expect(await controller.startMeasurement(HealthMetric.heartRate), isTrue);
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

  testWidgets(
    'sport session shows watch values and pauses only when reported',
    (tester) async {
      final wearable = _QaSportWearable();
      final controller = _controller(wearable: wearable)
        ..isBooting = false
        ..connectedDevice = wearable.scannedDevice
        ..capabilities = const DeviceCapabilities(
          metrics: {},
          sportModes: {SportMode.running},
          supportsSportPause: true,
        )
        ..activeSport = SportMode.running
        ..liveSportData = const {
          'distanceMeters': 1280,
          'steps': 2048,
          'heartRate': 96,
          'calories': 75,
        };
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: SportSessionPage(
            controller: controller,
            mode: SportMode.running,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1.28 km'), findsOneWidget);
      expect(find.text('2048 步'), findsOneWidget);
      expect(find.text('96 bpm'), findsOneWidget);
      expect(find.text('75.0 kcal'), findsOneWidget);
      expect(find.byKey(const Key('sport-session-pause')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sport-session-pause')));
      await tester.pump();
      expect(wearable.pauseCount, 1);
      expect(controller.sportPaused, isTrue);
      expect(find.text('继续运动'), findsOneWidget);
    },
  );

  testWidgets('watch-side stop finalizes the active sport only once', (
    tester,
  ) async {
    const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (_) async => false);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geolocatorChannel, null),
    );

    final store = MemoryHealthStore();
    final wearable = _QaSportWearable();
    final controller = _controller(wearable: wearable, store: store);
    await controller.initialize();
    controller
      ..connectedDevice = wearable.scannedDevice
      ..capabilities = const DeviceCapabilities(
        metrics: {},
        sportModes: {SportMode.cycling},
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
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SportSessionPage(controller: controller, mode: SportMode.cycling),
      ),
    );
    await tester.tap(find.byKey(const Key('sport-session-toggle')));
    await tester.pump(const Duration(seconds: 1));
    wearable.emitEvent(
      const WearableEvent(
        type: 'sportData',
        payload: {
          'durationSeconds': 2,
          'distanceMeters': 120,
          'steps': 18,
          'heartRate': 88,
          'calories': 4,
        },
      ),
    );
    wearable.emitEvent(
      const WearableEvent(
        type: 'sportState',
        payload: {'value': 'stopped', 'mode': 'cycling'},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final records = await store.localSportRecords();
    expect(records, hasLength(1));
    expect(records.single.durationSeconds, 2);
    expect(records.single.distanceKm, closeTo(0.12, 0.001));
    expect(records.single.steps, 18);
    expect(records.single.heartRate, 88);
    expect(wearable.stopCount, 0);
    expect(find.textContaining('手表已结束本次运动，记录已保存'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:00:02'), findsOneWidget);
    expect(await store.localSportRecords(), hasLength(1));
  });

  testWidgets('app-side stop replaces the active tracking status', (
    tester,
  ) async {
    const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (_) async => false);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geolocatorChannel, null),
    );

    final store = MemoryHealthStore();
    final wearable = _QaSportWearable();
    final controller = _controller(wearable: wearable, store: store);
    await controller.initialize();
    controller
      ..connectedDevice = wearable.scannedDevice
      ..capabilities = const DeviceCapabilities(
        metrics: {},
        sportModes: {SportMode.walking},
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
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SportSessionPage(controller: controller, mode: SportMode.walking),
      ),
    );
    await tester.tap(find.byKey(const Key('sport-session-toggle')));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.activeSport, SportMode.walking);

    await tester.tap(find.byKey(const Key('sport-session-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.activeSport, isNull);
    expect(find.text('开始步行'), findsOneWidget);
    expect(find.textContaining('本次运动已结束，记录已保存'), findsOneWidget);
    expect(find.textContaining('正在记录前台户外轨迹'), findsNothing);
    expect(wearable.startCount, 1);
    expect(wearable.stopCount, 1);
    expect(await store.localSportRecords(), hasLength(1));
  });

  testWidgets('sport stop disables restart while the watch is still saving', (
    tester,
  ) async {
    const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (_) async => false);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geolocatorChannel, null),
    );

    final stopCompleter = Completer<void>();
    final wearable = _QaSportWearable(stopCompleter: stopCompleter);
    final controller = _controller(wearable: wearable);
    await controller.initialize();
    controller
      ..connectedDevice = wearable.scannedDevice
      ..capabilities = const DeviceCapabilities(
        metrics: {},
        sportModes: {SportMode.walking},
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
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SportSessionPage(controller: controller, mode: SportMode.walking),
      ),
    );
    await tester.tap(find.byKey(const Key('sport-session-toggle')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('sport-session-toggle')));
    await tester.pump();

    expect(find.textContaining('正在结束运动并保存记录'), findsOneWidget);
    expect(find.text('正在保存'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '正在保存'))
          .onPressed,
      isNull,
    );

    stopCompleter.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('本次运动已结束，记录已保存'), findsOneWidget);
    expect(find.text('开始步行'), findsOneWidget);
  });

  testWidgets('short sport records display seconds instead of zero minutes', (
    tester,
  ) async {
    final store = MemoryHealthStore();
    await store.saveSportRecord(
      SportRecord(
        id: 'short-sport',
        mode: SportMode.cycling,
        startedAt: DateTime(2026, 8, 30, 20),
        durationSeconds: 2,
        distanceKm: 0,
        calories: 0,
        routePoints: const [],
      ),
    );
    final controller = _controller(store: store)..isBooting = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SportRecordsPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2秒'), findsOneWidget);
    expect(find.textContaining('0分钟'), findsNothing);
  });

  test('watch sport events update state and preserve real values', () async {
    final wearable = _QaWearable();
    final controller = _controller(wearable: wearable);
    await controller.initialize();
    addTearDown(controller.dispose);
    controller
      ..connectedDevice = wearable.scannedDevice
      ..capabilities = const DeviceCapabilities(
        metrics: {},
        sportModes: {SportMode.hiking},
        supportsSportPause: true,
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

    wearable.emitEvent(
      const WearableEvent(
        type: 'sportState',
        payload: {'value': 'running', 'mode': 'hiking'},
      ),
    );
    wearable.emitEvent(
      const WearableEvent(
        type: 'sportData',
        payload: {
          'durationSeconds': 90,
          'distanceMeters': 680,
          'steps': 921,
          'heartRate': 101,
          'calories': 32,
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.activeSport, SportMode.hiking);
    expect(controller.deviceState, DeviceConnectionState.measuring);
    expect(controller.liveSportData['distanceMeters'], 680);

    wearable.emitEvent(
      const WearableEvent(
        type: 'sportState',
        payload: {'value': 'paused', 'mode': 'hiking'},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.sportPaused, isTrue);

    wearable.emitEvent(
      const WearableEvent(
        type: 'sportState',
        payload: {'value': 'stopped', 'mode': 'hiking'},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.activeSport, isNull);
    expect(controller.sportPaused, isFalse);
    expect(controller.deviceState, DeviceConnectionState.ready);
    expect(controller.liveSportData['steps'], 921);
  });

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
    await _popRoute(tester);
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
    expect(find.byKey(const Key('ai-message-input')), findsOneWidget);
    expect(find.byKey(const Key('ai-show-composer')), findsNothing);
    await _popRoute(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(find.text('我的订单'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '全部'));
    await tester.pumpAndSettle();
    expect(find.text('我的订单'), findsOneWidget);
    expect(find.textContaining('QA-ORDER-100'), findsOneWidget);
    await _popRoute(tester);
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
    await _popRoute(tester);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('my-ai-question')));
    await tester.tap(find.byKey(const Key('my-ai-question')));
    await tester.pumpAndSettle();
    expect(find.text('AI 健康管家'), findsOneWidget);
    await _popRoute(tester);
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
      await _popRoute(tester);
      await tester.pumpAndSettle();
      await _popRoute(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('远程关爱'));
      await tester.pumpAndSettle();
      expect(find.text('守护家人健康'), findsOneWidget);
      await _popRoute(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('健康'));
      await tester.pump();
      await tester.ensureVisible(find.text('全部数据'));
      await tester.tap(find.text('全部数据'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('health-sport-entries')), findsNothing);
      await _popRoute(tester);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('health-sport-entries')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(find.text('跑步'), findsNothing);
      expect(find.text('步行'), findsNothing);
      expect(find.text('骑行'), findsNothing);
      expect(find.text('徒步'), findsNothing);
      await tester.tap(find.text('运动记录'));
      await tester.pumpAndSettle();
      expect(find.text('请先连接手表后读取运动记录'), findsOneWidget);
      await _popRoute(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('我的'));
      await tester.pump();
      await tester.tap(find.text('单位设置'));
      await tester.pumpAndSettle();
      expect(find.text('公里'), findsOneWidget);
      await _popRoute(tester);
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

  testWidgets('care page distinguishes an API failure from an empty list', (
    tester,
  ) async {
    final api = _CareFailureApi();
    final controller = _authenticatedController(api: api);
    addTearDown(controller.dispose);
    await _pumpPhone(tester, controller);

    await tester.tap(find.text('远程关爱'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('care-members-error')), findsOneWidget);
    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('暂无关爱成员'), findsNothing);
    expect(find.text('重新加载'), findsOneWidget);
    expect(controller.careErrorMessage, '数据查询失败');

    expect(api.memberRequests, 1);
    expect(api.invitationRequests, 1);
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(api.memberRequests, 2);
    expect(api.invitationRequests, 2);
  });

  test('care member detail preserves a visible load failure state', () async {
    final controller = _authenticatedController(api: _CarePreviewFailureApi());
    addTearDown(controller.dispose);

    final result = await controller.loadCareMemberPreview(59, memberId: 87);

    expect(result['loadError'], '成员健康数据查询失败');
    expect(controller.errorMessage, '成员健康数据查询失败');
  });

  test('AI history normalizes string sender flags', () async {
    final api = _RegressionApi();
    final controller = _authenticatedController(api: api);
    addTearDown(controller.dispose);

    await controller.refreshAiMessages(app: 1);

    expect(controller.aiMessages.map((item) => item['my']), [0, 1]);
    expect(controller.errorMessage, isNull);
  });

  test(
    'payment errors replace server internals with actionable messages',
    () async {
      final unavailable = _authenticatedController(
        api: _PaymentFailureApi(
          const ApiException('Internal Server Error', statusCode: 500),
        ),
      );
      addTearDown(unavailable.dispose);

      await unavailable.startShopPayment(
        provider: AppPaymentProvider.alipay,
        orderId: 99,
        money: 199,
      );

      expect(unavailable.errorMessage, '支付服务暂不可用，请稍后重试');

      final misconfigured = _authenticatedController(
        api: _PaymentFailureApi(const ApiException('微信授权有误')),
      );
      addTearDown(misconfigured.dispose);

      await misconfigured.startShopPayment(
        provider: AppPaymentProvider.wechat,
        orderId: 99,
        money: 199,
      );

      expect(misconfigured.errorMessage, '支付服务配置异常，请稍后重试');
    },
  );

  test(
    'payment flow accepts nested provider payloads and forwards signatures',
    () async {
      final bridge = _RecordingPaymentBridge();
      final api = _PaymentPayloadApi();
      final controller = _authenticatedController(
        api: api,
        paymentBridge: bridge,
      );
      addTearDown(controller.dispose);

      await controller.startShopPayment(
        provider: AppPaymentProvider.wechat,
        orderId: 99,
        money: 100,
      );
      expect(bridge.wechatParameters?['appid'], 'wx-production');
      expect(controller.errorMessage, isNull);

      final result = await controller.startShopPayment(
        provider: AppPaymentProvider.alipay,
        orderId: 99,
        money: 100,
      );
      expect(bridge.alipayOrder, 'app_id=server&sign=server-signature');
      expect(result?.isCancelled, isTrue);
      expect(controller.errorMessage, isNull);
    },
  );
}

AppController _controller({
  _QaApi? api,
  _QaWearable? wearable,
  HealthStore? store,
  AppPaymentBridge? paymentBridge,
}) => AppController(
  MemorySessionVault(),
  api ?? _QaApi(),
  store ?? MemoryHealthStore(),
  wearable ?? _QaWearable(),
  paymentBridge: paymentBridge,
);

AppController _authenticatedController({
  _QaApi? api,
  _QaWearable? wearable,
  AppPaymentBridge? paymentBridge,
}) {
  final controller =
      _controller(api: api, wearable: wearable, paymentBridge: paymentBridge)
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
  await tester.pumpWidget(
    SaydianApp(controller: controller, updateCheckStore: _QaUpdateStore()),
  );
  await tester.pump();
  // The app resolves the persisted mandatory-update gate asynchronously
  // before exposing any authenticated route.
  await tester.pump(const Duration(milliseconds: 20));
}

class _QaUpdateStore implements AppUpdateCheckStore {
  @override
  Future<DateTime?> readLastSuccessfulCheck() async => null;

  @override
  Future<AppUpdateInfo?> readRequiredUpdate() async => null;

  @override
  Future<void> writeLastSuccessfulCheck(DateTime value) async {}

  @override
  Future<void> writeRequiredUpdate(AppUpdateInfo? value) async {}
}

Future<void> _popRoute(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
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
  num lastOrderPoint = 0;
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
    'point': lastOrderPoint,
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
    'account': const {'money1': 500},
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
    lastOrderPoint = point;
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

class _PaymentFailureApi extends _QaApi {
  _PaymentFailureApi(this.error);

  final ApiException error;

  @override
  Future<Map<String, Object?>> createShopPayment({
    required String provider,
    required int orderId,
    required num money,
  }) async {
    throw error;
  }
}

class _PaymentPayloadApi extends _QaApi {
  @override
  Future<Map<String, Object?>> createShopPayment({
    required String provider,
    required int orderId,
    required num money,
  }) async => provider == 'wechat'
      ? const {
          'payment': {
            'params': {
              'appid': 'wx-production',
              'partnerid': 'merchant-1',
              'prepayid': 'prepay-1',
              'noncestr': 'nonce-1',
              'timestamp': '1788000000',
              'sign': 'server-signature',
            },
          },
        }
      : const {
          'data': {'orderString': 'app_id=server&sign=server-signature'},
        };
}

class _RecordingPaymentBridge implements AppPaymentBridge {
  Map<String, Object?>? wechatParameters;
  String? alipayOrder;

  @override
  Future<void> startWechat(Map<String, Object?> signedParameters) async {
    wechatParameters = signedParameters;
  }

  @override
  Future<AppPaymentResult?> takeWechatResult() async => null;

  @override
  Future<AppPaymentResult> startAlipay(String signedOrder) async {
    alipayOrder = signedOrder;
    return const AppPaymentResult(code: '6001', message: 'cancelled', raw: {});
  }
}

class _CareFailureApi extends _QaApi implements SaydianCareApi {
  int memberRequests = 0;
  int invitationRequests = 0;

  @override
  Future<List<Map<String, Object?>>> getCareMembers() async {
    memberRequests += 1;
    throw const ApiException('数据查询失败', statusCode: 500);
  }

  @override
  Future<List<Map<String, Object?>>> getCareInvitations() async {
    invitationRequests += 1;
    throw const ApiException('邀请查询失败', statusCode: 500);
  }
}

class _MixedCareInvitationApi extends _QaApi implements SaydianCareApi {
  @override
  Future<List<Map<String, Object?>>> getCareInvitations() async => const [
    {
      'id': 11,
      'examine_status': 0,
      'inviter_id': 81,
      'member': {'nickname': '待处理成员'},
    },
    {
      'id': 12,
      'examine_status': 1,
      'inviter_id': 82,
      'member': {'nickname': '已接受成员'},
    },
    {
      'id': 13,
      'examine_status': 2,
      'inviter_id': 83,
      'member': {'nickname': '已拒绝成员'},
    },
  ];

  @override
  Future<void> respondCareInvitation({
    required int id,
    required bool accepted,
  }) async {}
}

class _CarePreviewFailureApi extends _QaApi {
  @override
  Future<Map<String, Object?>> getCareMemberPreview({
    required int id,
    required String day,
    int? memberId,
  }) async {
    throw const ApiException('成员健康数据查询失败', statusCode: 500);
  }
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
        WearableEvent(
          type: 'deviceDetails',
          payload: {
            'id': scannedDevice.id,
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

class _QaSportWearable extends _QaWearable implements WearableSportPauseBridge {
  _QaSportWearable({this.stopCompleter});

  final Completer<void>? stopCompleter;
  int pauseCount = 0;
  int resumeCount = 0;
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> startSport(SportMode mode) async {
    startCount++;
  }

  @override
  Future<void> stopSport() async {
    stopCount++;
    await stopCompleter?.future;
  }

  @override
  Future<void> pauseSport() async {
    pauseCount++;
  }

  @override
  Future<void> resumeSport() async {
    resumeCount++;
  }
}
