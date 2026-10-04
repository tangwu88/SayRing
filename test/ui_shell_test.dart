import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/brand_assets.dart';
import 'package:saydian_app/ui/health_trend_page.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/shop_pages.dart' show ShopHomePage;
import 'package:saydian_app/ui/widgets/safe_network_image.dart';

void main() {
  // Legacy page hosts deliberately retain Chinese copy. DateFormat now uses
  // the explicit page locale rather than a hard-coded numeric pattern.
  setUpAll(() => initializeDateFormatting('zh_Hans'));

  for (final viewport in const [
    (width: 360.0, scale: 1.0),
    (width: 320.0, scale: 1.0),
    (width: 320.0, scale: 1.5),
    (width: 320.0, scale: 2.0),
  ]) {
    testWidgets(
      'health section stays readable at ${viewport.width}px x${viewport.scale}',
      (tester) async {
        tester.view.physicalSize = Size(viewport.width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = AppController(
          MemorySessionVault(),
          _NoopApi(),
          MemoryHealthStore(),
          _NoopWearable(),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSaydianTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
              child: child!,
            ),
            home: AppShell(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.text('健康数据');
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        for (final label in ['健康数据', '近期数据', '全部数据']) {
          expect(find.text(label), findsOneWidget);
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(label))
                .didExceedMaxLines,
            isFalse,
            reason: '$label must not be ellipsized',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('全部数据'));
        await tester.pumpAndSettle();
        expect(find.text('全部健康数据'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'CoolWear RRI detail identifies SDNN and separates auxiliary units',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        _NoopWearable(),
      );
      addTearDown(controller.dispose);
      final record = HealthRecord(
        id: 'synthetic-rri',
        metric: HealthMetric.hrv,
        values: const {
          'value': 42,
          'sdnn': 42,
          'rmssd': 35,
          'rri': 800,
          'pnn': 0,
          'heartRate': 75,
          'validCount': 80,
          'rejectedCount': 0,
          'sdkQuality': 3,
          'sdkFlags': 0,
        },
        unit: 'ms',
        measuredAt: DateTime.utc(2026, 10, 3, 1),
        timezone: '+08:00',
        deviceId: 'coolwear:TEST',
        firmwareVersion: 'test',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        rawVersion: 2,
        sourceVendor: 'coolwear',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: HealthRecordDetailPage(controller: controller, record: record),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('HRV 指标：SDNN'), findsOneWidget);
      expect(find.text('平均 NN 间期'), findsOneWidget);
      expect(find.text('42 ms'), findsOneWidget);
      expect(find.text('0 %'), findsOneWidget);
      expect(find.text('75 bpm'), findsOneWidget);
      expect(find.text('sdkFlags'), findsNothing);
      await tester.scrollUntilVisible(find.text('信号质量（1–3）'), 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test('commerce is hidden in the default release configuration', () {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    expect(controller.commerceEnabled, isFalse);
  });

  testWidgets(
    'home does not suggest sleep sync when history transport is explicitly unavailable',
    (tester) async {
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              _NoopWearable(),
            )
            ..capabilities = const DeviceCapabilities(
              metrics: {HealthMetric.heartRate},
              supportsHistorySync: false,
            );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: Scaffold(body: DashboardPage(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-sleep-overview-entry')), findsNothing);
      expect(find.textContaining('佩戴戒指睡眠后同步'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unmapped iOS history is disabled and manual measurement remains',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              _NoopWearable(),
            )
            ..connectedDevice = const DeviceInfo(
              id: 'coolwear:synthetic',
              name: 'HR01',
            )
            ..capabilities = const DeviceCapabilities(
              metrics: {HealthMetric.heartRate, HealthMetric.bloodOxygen},
              manualMetrics: {HealthMetric.heartRate, HealthMetric.bloodOxygen},
              supportsHistorySync: false,
            );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(body: DevicePage(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('device-sync-data')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('此戒指历史同步暂未开放'), findsOneWidget);
      expect(
        controller.capabilities!.supportsManualMeasurement(
          HealthMetric.heartRate,
        ),
        isTrue,
      );
      expect(
        controller.capabilities!.supportsManualMeasurement(
          HealthMetric.bloodOxygen,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);

      controller.capabilities = const DeviceCapabilities(metrics: {});
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: Scaffold(body: DevicePage(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('device-sync-data')))
            .onPressed,
        isNotNull,
      );
      expect(find.text('同步数据'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home avatar and greeting follow saved personal profile', (
    tester,
  ) async {
    final api = _EditableProfileApi();
    final controller = AppController(
      MemorySessionVault(),
      api,
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    controller.session = Session(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      memberId: 'test-member',
      displayName: '登录名',
    );
    await controller.refreshMemberProfile();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: Scaffold(body: DashboardPage(controller: controller)),
      ),
    );
    expect(find.text('你好，登录名'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboard-profile-avatar')),
        matching: find.byType(SaydianBrandMark),
      ),
      findsOneWidget,
    );

    final saved = await controller.saveMemberProfile(
      nickname: '新昵称',
      gender: 1,
      birthday: '1990-01-01',
      height: 170,
      weight: 65,
      avatarFilePath: '/test/new-avatar.png',
    );
    expect(saved, isTrue);
    await tester.pump();
    expect(find.text('你好，新昵称'), findsOneWidget);
    final homeAvatar = tester.widget<SafeNetworkImage>(
      find.descendant(
        of: find.byKey(const Key('dashboard-profile-avatar')),
        matching: find.byType(SafeNetworkImage),
      ),
    );
    expect(
      (homeAvatar.image as SafeNetworkImageProvider).url,
      _EditableProfileApi.uploadedAvatarUrl,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: Scaffold(body: SettingsPage(controller: controller)),
      ),
    );
    expect(find.text('新昵称'), findsOneWidget);
    final profileAvatar = tester.widget<SafeNetworkImage>(
      find.descendant(
        of: find.byKey(const Key('profile-header-card')),
        matching: find.byType(SafeNetworkImage),
      ),
    );
    expect(
      (profileAvatar.image as SafeNetworkImageProvider).url,
      _EditableProfileApi.uploadedAvatarUrl,
    );

    api.profile = {'nickname': ' ', 'head_portrait': ''};
    await controller.refreshMemberProfile();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: Scaffold(body: DashboardPage(controller: controller)),
      ),
    );
    expect(find.text('你好，登录名'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboard-profile-avatar')),
        matching: find.byType(SaydianBrandMark),
      ),
      findsOneWidget,
    );
  });

  test('Say Ring avatar-only save reads back the new URL', () async {
    final api = _AvatarOnlyGlobalApi();
    final controller = AppController(
      MemorySessionVault(),
      api,
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    controller.session = Session(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      memberId: 'test-member',
      displayName: '测试用户',
    );

    expect(await controller.saveMemberAvatar('/test/avatar.jpg'), isTrue);
    expect(api.savedUrl, _AvatarOnlyGlobalApi.uploadedAvatarUrl);
    expect(
      controller.memberProfile['head_portrait'],
      _AvatarOnlyGlobalApi.uploadedAvatarUrl,
    );

    api.persistAvatar = false;
    expect(await controller.saveMemberAvatar('/test/avatar2.jpg'), isFalse);
    expect(controller.errorMessage, contains('读取不一致'));
  });

  test(
    'Say Ring profile and avatar save also requires avatar readback',
    () async {
      final api = _AvatarOnlyGlobalApi()..persistAvatar = false;
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        _NoopWearable(),
      );
      addTearDown(controller.dispose);
      controller.session = Session(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        memberId: 'test-member',
        displayName: '测试用户',
      );

      expect(
        await controller.saveMemberProfile(
          nickname: '测试用户',
          gender: 1,
          birthday: '1990-01-01',
          height: 170,
          weight: 65,
          avatarFilePath: '/test/avatar.jpg',
        ),
        isFalse,
      );
      expect(controller.errorMessage, contains('读取不一致'));
      api.persistAvatar = true;
      expect(
        await controller.saveMemberProfile(
          nickname: '测试用户',
          gender: 1,
          birthday: '1990-01-01',
          height: 170,
          weight: 65,
          avatarFilePath: '/test/avatar.jpg',
        ),
        isTrue,
      );
    },
  );

  testWidgets('Say Ring care entry has a single title bar', (tester) async {
    final controller = AppController(
      MemorySessionVault(),
      _AvatarOnlyGlobalApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    controller.session = Session(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      memberId: 'test-member',
      displayName: '测试用户',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: Scaffold(body: DashboardPage(controller: controller)),
      ),
    );
    await tester.tap(find.text('远程关爱'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('global-care-page')), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('Say Ring About page does not repeat its brand heading', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _AvatarOnlyGlobalApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: AboutSaydianPage(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Say Ring 健康'), findsNothing);
    expect(find.byType(SaydianBrandLockup), findsOneWidget);
  });

  testWidgets('iOS permissions show only available Say Ring uses', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final controller = AppController(
        MemorySessionVault(),
        _AvatarOnlyGlobalApi(),
        MemoryHealthStore(),
        _NoopWearable(),
      );
      addTearDown(controller.dispose);
      controller.session = Session(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        memberId: 'test-member',
        displayName: '测试用户',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: PermissionManagementPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('蓝牙'), findsOneWidget);
      expect(find.text('位置（户外运动轨迹）'), findsOneWidget);
      expect(find.text('相册（修改头像）'), findsNothing);
      expect(find.text('相机（戒指遥控拍照）'), findsNothing);
      expect(find.text('通知'), findsNothing);
      expect(find.text('未允许'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'iOS permission rows reflect real plugin status, not device names',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        const permissionsChannel = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        final checked = <int>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          permissionsChannel,
          (call) async {
            if (call.method == 'checkPermissionStatus') {
              checked.add(call.arguments as int);
              // Actual channel enum: Bluetooth=21, locationWhenInUse=5.
              return call.arguments == 21 ? 1 : 0;
            }
            throw StateError(
              'Read-only permission test must not request access',
            );
          },
        );
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            permissionsChannel,
            null,
          );
        });
        final controller = AppController(
          MemorySessionVault(),
          _NoopApi(),
          MemoryHealthStore(),
          _NoopWearable(),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSaydianTheme(),
            home: PermissionManagementPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        expect(checked, [21, 5]);
        final bluetooth = find.ancestor(
          of: find.text('蓝牙'),
          matching: find.byType(ListTile),
        );
        final location = find.ancestor(
          of: find.text('位置（户外运动轨迹）'),
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(of: bluetooth, matching: find.text('已允许')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: location, matching: find.text('未允许')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  for (final enabled in [false, true]) {
    testWidgets('commerce visibility $enabled covers all external entry points', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        _NoopWearable(),
        commerceEnabled: enabled,
      )..enterPreview();
      addTearDown(controller.dispose);
      Future<void> show(Widget page) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSaydianTheme(),
            home: Scaffold(body: page),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await show(DashboardPage(controller: controller));
      expect(find.text('Say Ring 商城'), enabled ? findsOneWidget : findsNothing);
      expect(find.text('远程关爱'), findsOneWidget);
      expect(find.text('运动'), findsOneWidget);
      await show(SettingsPage(controller: controller));
      expect(
        find.byKey(const Key('profile-orders-card')),
        enabled ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('登录后可保存健康数据和设备信息'),
        enabled ? findsNothing : findsOneWidget,
      );
      await show(AccountSettingsPage(controller: controller));
      expect(find.text('收货地址'), enabled ? findsOneWidget : findsNothing);
      expect(find.text('个人资料'), findsOneWidget);
      await show(DeviceSearchPage(controller: controller));
      expect(
        find.byKey(const Key('device-shop-entry')),
        enabled ? findsOneWidget : findsNothing,
      );
      await show(FeedbackPage(controller: controller));
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      // Inspect the actual rendered dropdown, not a duplicate flag calculation.
      expect(dropdown, isNotNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('商城订单'), enabled ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('hidden commerce rejects a stale direct shop entry', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ShopHomePage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('commerce-unavailable-page')), findsOneWidget);
    expect(find.byKey(const Key('shop-page')), findsNothing);
    expect(find.byKey(const Key('global-shop-page')), findsNothing);
    expect(controller.errorMessage, isNull);
  });

  test('app theme uses a cool technology palette', () {
    final theme = buildSaydianTheme();

    expect(theme.colorScheme.primary, SaydianColors.techBlue);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF4F7FB));
    expect(SaydianColors.brandRed, SaydianColors.techBlue);
    expect(SaydianColors.brandGold, SaydianColors.techCyan);
    expect(SaydianColors.brandRed, isNot(SaydianColors.danger));
    expect(
      theme.navigationBarTheme.iconTheme?.resolve({
        WidgetState.selected,
      })?.color,
      SaydianColors.techBlue,
    );
    expect(theme.navigationBarTheme.indicatorColor, SaydianColors.techBlueSoft);
    expect(saydianSoftGradient.colors, const [
      Color(0xFFF2F6FF),
      SaydianColors.canvas,
      SaydianColors.techCyanSoft,
    ]);
    expect(saydianPanelGradient.colors, const [
      Colors.white,
      Color(0xFFF0F6FF),
    ]);
  });

  testWidgets('home mini chart does not duplicate its parent empty status', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HealthMetricMiniChart(
          controller: controller,
          metric: HealthMetric.heartRate,
          color: Colors.red,
          showEmptyLabel: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets(
    'commerce-enabled three-tab shell keeps the existing shop flows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        _NoopWearable(),
        commerceEnabled: true,
      )..enterPreview();
      controller.healthRecords = [_historicalHeartRateRecord()];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => AppShell(controller: controller),
          ),
        ),
      );

      expect(find.byKey(const Key('mind-body-readiness-card')), findsNothing);
      expect(find.byKey(const Key('dashboard-ai-assistant')), findsOneWidget);
      final assistantDecoration =
          tester
                  .widget<Container>(
                    find.byKey(const Key('dashboard-ai-assistant')),
                  )
                  .decoration
              as BoxDecoration;
      expect((assistantDecoration.gradient as LinearGradient).colors, const [
        Color(0xFFF5F8FF),
        Color(0xFFE8F4FF),
      ]);
      expect(
        tester.getSize(find.byKey(const Key('dashboard-ai-assistant'))).height,
        lessThanOrEqualTo(170),
      );
      expect(find.byKey(const Key('dashboard-functions')), findsOneWidget);
      final functionDecoration =
          tester
                  .widget<Container>(
                    find.byKey(const Key('dashboard-functions')),
                  )
                  .decoration
              as BoxDecoration;
      expect((functionDecoration.gradient as LinearGradient).colors, const [
        Color(0xFFFFFFFF),
        Color(0xFFEDF5FF),
      ]);
      expect(find.text('远程关爱'), findsOneWidget);
      expect(find.text('健康百科'), findsOneWidget);
      expect(find.text('运动'), findsOneWidget);
      expect(find.text('Say Ring 商城'), findsOneWidget);
      final shopEntryLabel = tester.widget<Text>(find.text('Say Ring 商城'));
      expect(shopEntryLabel.maxLines, 1);
      expect(shopEntryLabel.overflow, isNot(TextOverflow.ellipsis));
      expect(
        find.ancestor(
          of: find.text('Say Ring 商城'),
          matching: find.byType(FittedBox),
        ),
        findsOneWidget,
      );

      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigationBar.destinations, hasLength(3));
      expect(
        navigationBar.destinations.cast<NavigationDestination>().map(
          (destination) => destination.label,
        ),
        ['健康', '设备', '我的'],
      );

      await tester.tap(find.text('健康百科'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('article-category-page')), findsOneWidget);
      expect(find.byKey(const Key('article-category-all')), findsOneWidget);
      expect(find.text('心脑健康'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Say Ring 商城'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-page')), findsOneWidget);
      expect(find.text('此功能暂时无法使用，请稍后再试'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('全部数据'));
      await tester.tap(find.text('全部数据'));
      await tester.pumpAndSettle();
      expect(find.text('全部健康数据'), findsOneWidget);
      expect(find.text('健康数据总览'), findsOneWidget);
      expect(find.byKey(const Key('health-sport-entries')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('跑步'), findsNothing);
      expect(find.text('步行'), findsNothing);
      expect(find.text('骑行'), findsNothing);
      expect(find.text('徒步'), findsNothing);
      expect(find.text('运动记录'), findsNothing);

      expect(
        find.byKey(const ValueKey('health-metric-heartRate')),
        findsOneWidget,
      );
      for (final metric in const [
        'bloodPressure',
        'bloodOxygen',
        'bodyTemperature',
        'ecg',
        'hrv',
      ]) {
        expect(find.byKey(ValueKey('health-metric-$metric')), findsNothing);
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey('health-metric-heartRate')))
            .height,
        greaterThanOrEqualTo(184),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('health-metric-heartRate')))
            .width,
        greaterThanOrEqualTo(350),
      );
      expect(
        find.byKey(const Key('dashboard-health-card-list')),
        findsOneWidget,
      );
      expect(find.text('近期数据'), findsOneWidget);
      final metricSurface = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('health-metric-surface-heartRate')),
      );
      final metricDecoration = metricSurface.decoration as BoxDecoration;
      expect((metricDecoration.gradient as LinearGradient).colors, const [
        Color(0xFFE8EDFF),
        Color(0xFFE3F7FA),
      ]);
      expect(metricDecoration.borderRadius, BorderRadius.circular(28));
      expect(
        tester.getSize(find.byKey(const Key('dashboard-health-notice'))).height,
        lessThanOrEqualTo(60),
      );
      expect(
        find.byKey(const ValueKey('health-metric-bloodGlucose')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('health-metric-heartRate')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('health-metric-heartRate')));
      await tester.pumpAndSettle();
      expect(find.text('心率分析'), findsOneWidget);
      expect(find.byKey(const Key('health-measure-heart_rate')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      controller.selectTab(1);
      await tester.pump();
      expect(find.widgetWithText(FilledButton, '开始查找'), findsOneWidget);
      expect(find.byKey(const Key('device-page')), findsOneWidget);
      final emptyDeviceDecoration =
          tester
                  .widget<Container>(
                    find.byKey(const Key('device-empty-card-surface')),
                  )
                  .decoration
              as BoxDecoration;
      expect(
        (emptyDeviceDecoration.gradient as LinearGradient).colors,
        saydianPanelGradient.colors,
      );

      controller.selectTab(2);
      await tester.pump();
      expect(find.byKey(const Key('my-page')), findsOneWidget);
      expect(find.text('我的订单'), findsOneWidget);
      final profileHeaderDecoration =
          tester
                  .widget<Container>(
                    find.byKey(const Key('profile-header-card')),
                  )
                  .decoration
              as BoxDecoration;
      expect(
        (profileHeaderDecoration.gradient as LinearGradient).colors,
        saydianPanelGradient.colors,
      );
      expect(find.byKey(const Key('profile-orders-card')), findsOneWidget);
      expect(
        find.byKey(const Key('profile-quick-actions-card')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-services-card')),
        260,
        scrollable: find.descendant(
          of: find.byKey(const Key('my-page')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(const Key('profile-services-card')), findsOneWidget);

      for (var tab = 0; tab < 3; tab++) {
        controller.selectTab(tab);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'tab $tab overflowed');
      }
    },
  );

  testWidgets('connected device overview uses the unified technology surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller =
        AppController(
            MemorySessionVault(),
            _NoopApi(),
            MemoryHealthStore(),
            _NoopWearable(),
          )
          ..connectedDevice = const DeviceInfo(id: 'ring-1', name: 'HR01')
          ..deviceCapabilityState = DeviceCapabilityState.ready
          ..capabilities = const DeviceCapabilities(metrics: {});
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: Scaffold(body: DevicePage(controller: controller)),
      ),
    );
    await tester.pump();

    final overviewDecoration =
        tester
                .widget<Container>(
                  find.byKey(const Key('device-overview-card')),
                )
                .decoration
            as BoxDecoration;
    expect(
      (overviewDecoration.gradient as LinearGradient).colors,
      saydianPanelGradient.colors,
    );
    expect(find.text('HR01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core tabs remain overflow-free at 375 x 812', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    )..enterPreview();
    controller.healthRecords = [_historicalHeartRateRecord()];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => AppShell(controller: controller),
        ),
      ),
    );

    for (var tab = 0; tab < 3; tab++) {
      controller.selectTab(tab);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'tab $tab overflowed');
    }
  });

  testWidgets('dashboard exposes every supported health metric including HRV', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller =
        AppController(
            MemorySessionVault(),
            _NoopApi(),
            MemoryHealthStore(),
            _NoopWearable(),
          )
          ..connectedDevice = const DeviceInfo(id: 'et488', name: 'ET488')
          ..deviceCapabilityState = DeviceCapabilityState.ready
          ..capabilities = const DeviceCapabilities(
            metrics: {
              HealthMetric.bloodGlucose,
              HealthMetric.bodyComposition,
              HealthMetric.bloodComposition,
              HealthMetric.sleep,
              HealthMetric.stress,
              HealthMetric.hrv,
            },
          );
    controller.healthRecords = [
      HealthRecord(
        id: 'stored-hrv',
        metric: HealthMetric.hrv,
        values: const {'value': 52},
        unit: 'ms',
        measuredAt: DateTime(2026, 9, 24, 8),
        timezone: '+08:00',
        deviceId: 'et488',
        firmwareVersion: 'test',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        origin: MeasurementOrigin.watchHistory,
        rawVersion: 1,
      ),
    ];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: Scaffold(body: DashboardPage(controller: controller)),
      ),
    );
    await tester.pump();

    for (final metric in const [
      'bloodGlucose',
      'bodyComposition',
      'bloodComposition',
      'sleep',
      'stress',
      'hrv',
    ]) {
      expect(find.byKey(ValueKey('health-metric-$metric')), findsOneWidget);
    }
    expect(controller.latestByMetric[HealthMetric.hrv]?.values['value'], 52);
    expect(find.byKey(const ValueKey('health-metric-heartRate')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home sport entry shows activity and four modes before all sports',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              _NoopWearable(),
            )
            ..connectedDevice = const DeviceInfo(id: 'hr01', name: 'HR01')
            ..deviceCapabilityState = DeviceCapabilityState.ready
            ..capabilities = DeviceCapabilities(
              metrics: const {
                HealthMetric.steps,
                HealthMetric.distance,
                HealthMetric.calories,
                HealthMetric.sleep,
              },
              sportModes: SportMode.values.toSet(),
              supportsSportPause: true,
            );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: Scaffold(body: DashboardPage(controller: controller)),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('health-sport-entries')), findsNothing);
      expect(find.byKey(const Key('dashboard-today-health')), findsNothing);
      await tester.tap(find.text('运动'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sport-overview-page')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-today-health')), findsOneWidget);
      expect(find.byKey(const Key('sport-mode-grid')), findsOneWidget);
      expect(
        tester
            .widget<Wrap>(find.byKey(const Key('sport-mode-grid')))
            .children
            .length,
        4,
      );
      await tester.tap(find.byKey(const Key('sport-mode-more')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('sport-mode-selection-page')),
        findsOneWidget,
      );
      expect(find.text('全部运动'), findsOneWidget);
      final allGrid = tester.widget<SliverGrid>(
        find.byKey(const Key('all-sport-mode-grid')),
      );
      expect(allGrid.delegate.estimatedChildCount, SportMode.values.length);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('all-sport-mode-mountaineering')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('登山'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact screens keep the complete sport page usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller =
        AppController(
            MemorySessionVault(),
            _NoopApi(),
            MemoryHealthStore(),
            _NoopWearable(),
          )
          ..connectedDevice = const DeviceInfo(id: 'hr01', name: 'HR01')
          ..deviceCapabilityState = DeviceCapabilityState.ready
          ..capabilities = DeviceCapabilities(
            metrics: const {},
            sportModes: SportMode.values.toSet(),
          );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: Scaffold(body: DashboardPage(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-sport-entries')), findsNothing);
    await tester.tap(find.text('运动'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sport-overview-page')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-today-health')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sport-mode-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('all-sport-mode-grid')), findsOneWidget);
    expect(find.text('跑步'), findsOneWidget);
    expect(find.text('室内跑'), findsOneWidget);
    expect(find.text('步行'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('all-sport-mode-mountaineering')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('登山'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity overview never labels yesterday values as today', (
    tester,
  ) async {
    final now = DateTime.now();
    HealthRecord steps(String id, DateTime measuredAt, int value) =>
        HealthRecord(
          id: id,
          metric: HealthMetric.steps,
          values: {'value': value},
          unit: '步',
          measuredAt: measuredAt,
          timezone: '+08:00',
          deviceId: 'ring',
          firmwareVersion: 'test',
          quality: 'device_reported',
          source: MeasurementSource.wearable,
          rawVersion: 1,
        );
    final records = [
      steps('old', DateTime(now.year, now.month, now.day - 1, 23), 999),
      steps(
        'legacy',
        DateTime(now.year, now.month, now.day, 10),
        777,
      ).copyWith(sourceVendor: 'qring'),
      steps('today', DateTime(now.year, now.month, now.day, 8), 155),
      steps('today-later', DateTime(now.year, now.month, now.day, 9), 45),
    ];
    final store = MemoryHealthStore();
    await store.initialize();
    await store.upsert(records);
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      store,
      _NoopWearable(),
    )..healthRecords = records;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: SportOverviewPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('200/10000步'), findsOneWidget);
    expect(find.text('999/10000步'), findsNothing);
    expect(find.byKey(const Key('sport-mode-grid')), findsNothing);
    expect(find.byKey(const Key('all-sport-records')), findsNothing);
  });

  testWidgets('activity total reads the full day beyond the recent cache', (
    tester,
  ) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final records = List.generate(
      96,
      (slot) => HealthRecord(
        id: 'slot-$slot',
        metric: HealthMetric.steps,
        values: const {'value': 1},
        unit: '步',
        measuredAt: start.add(Duration(minutes: slot * 15)),
        timezone: '+08:00',
        deviceId: 'qring:test',
        firmwareVersion: 'test',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        sourceVendor: 'qring',
        rawVersion: 2,
      ),
    );
    final store = MemoryHealthStore();
    await store.initialize();
    await store.upsert(records);
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      store,
      _NoopWearable(),
    )..healthRecords = records.take(10).toList();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: SportOverviewPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('96/10000步'), findsOneWidget);
  });

  testWidgets('home sleep entry opens real stages and the same dated trend', (
    tester,
  ) async {
    final now = DateTime.now();
    final recordedAt = DateTime(now.year, now.month, now.day, 7);
    final record = HealthRecord(
      id: 'sleep-home',
      metric: HealthMetric.sleep,
      values: const {'value': 7.5, 'deepHours': 2, 'remHours': 1},
      unit: 'h',
      measuredAt: recordedAt,
      timezone: '+08:00',
      deviceId: 'qring:test',
      firmwareVersion: 'test',
      quality: 'device_reported',
      source: MeasurementSource.wearable,
      rawVersion: 1,
    );
    final store = MemoryHealthStore();
    await store.initialize();
    await store.upsert([record]);
    final controller =
        AppController(MemorySessionVault(), _NoopApi(), store, _NoopWearable())
          ..healthRecords = [
            record.copyWith(values: {'value': 395}),
            record,
          ];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: Scaffold(body: DashboardPage(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('home-sleep-overview-entry'));
    expect(entry, findsOneWidget);
    // The in-memory generic metric intentionally disagrees with persisted
    // sleep. Both the home card and detail must use the same stored day.
    expect(
      find.descendant(of: entry, matching: find.text('7小时30分')),
      findsOneWidget,
    );
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
    expect(find.text('7小时30分'), findsNWidgets(2));
    expect(find.text('快速眼动'), findsOneWidget);
    expect(find.text('1小时0分'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('sleep-open-trend')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('sleep-overview-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('sleep-open-trend')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sleep-open-trend')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-trend-sleep')), findsOneWidget);
    expect(find.byKey(const Key('sleep-structure-card')), findsOneWidget);
  });

  testWidgets(
    'empty health notice is centered, opens device search, and keeps legal copy at bottom',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        _NoopWearable(),
      )..enterPreview();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => AppShell(controller: controller),
          ),
        ),
      );
      await tester.pump();

      final emptyNotice = find.byKey(
        const Key('dashboard-health-empty-notice'),
      );
      final emptyMessage = find.text('连接戒指后可查看支持的健康数据');
      expect(emptyNotice, findsOneWidget);
      expect(emptyMessage, findsOneWidget);
      final emptyText = tester.widget<Text>(emptyMessage);
      expect(emptyText.textAlign, TextAlign.center);
      expect(emptyText.style?.fontSize, 15);
      expect(emptyText.style?.fontWeight, FontWeight.w600);

      final legalNotice = find.byKey(const Key('dashboard-health-notice'));
      final navigationBar = find.byType(NavigationBar);
      await tester.scrollUntilVisible(
        legalNotice,
        300,
        scrollable: find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(legalNotice, findsOneWidget);
      expect(
        tester.getTopLeft(navigationBar).dy -
            tester.getBottomLeft(legalNotice).dy,
        inInclusiveRange(16, 32),
      );

      await tester.tap(emptyNotice);
      await tester.pumpAndSettle();
      expect(find.text('添加设备'), findsOneWidget);
    },
  );

  testWidgets(
    'historical metric remains visible while unsupported actions stay hidden',
    (tester) async {
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              _NoopWearable(),
            )
            ..connectedDevice = const DeviceInfo(
              id: 'watch-1',
              name: 'Test Watch',
            )
            ..deviceCapabilityState = DeviceCapabilityState.ready
            ..capabilities = const DeviceCapabilities(
              metrics: {HealthMetric.heartRate},
              manualMetrics: {HealthMetric.heartRate},
            )
            ..healthRecords = [
              HealthRecord(
                id: 'history-glucose',
                metric: HealthMetric.bloodGlucose,
                values: const {'value': 5.4},
                unit: 'mmol/L',
                measuredAt: DateTime.now().toUtc(),
                timezone: '+08:00',
                deviceId: 'previous-watch',
                firmwareVersion: '1.0',
                quality: 'device_reported',
                source: MeasurementSource.wearable,
                rawVersion: 1,
              ),
            ];
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: HealthPage(controller: controller),
        ),
      );
      await tester.pump();

      expect(find.text('血糖'), findsOneWidget);
      expect(find.text('血糖校准'), findsNothing);
      await tester.tap(find.text('血糖'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('health-measure-blood_glucose')),
        findsNothing,
      );
    },
  );

  testWidgets('P40 Pro viewport and enlarged text remain overflow-free', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(362, 797));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    )..enterPreview();
    controller.healthRecords = [
      _historicalHeartRateRecord(),
      _historicalBloodPressureRecord(),
    ];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => AppShell(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-ai-assistant')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('health-metric-heartRate')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('health-metric-heartRate')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('health-metric-bloodPressure')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('health-metric-bloodPressure')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('three tabs remain usable at 2x system text size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(362, 797));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    )..enterPreview();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => AppShell(controller: controller),
        ),
      ),
    );

    for (var tab = 0; tab < 3; tab++) {
      controller.selectTab(tab);
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '2x text tab $tab overflowed',
      );
    }
  });

  testWidgets('article HTML keeps text and inline images', (tester) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: ArticleDetailPage(
          controller: controller,
          article: const {
            'title': '百科图片测试',
            'content':
                '<p>第一段说明</p><img src="https://example.invalid/one.png"><p>第二段说明</p><img src="/two.png">',
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('第一段说明'), findsOneWidget);
    expect(find.text('第二段说明'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('article-content-image-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('article-content-image-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('article pages distinguish loading failures from empty data', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _FailingArticleApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: ArticleListPage(controller: controller, title: '健康百科'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('健康百科加载失败'), findsOneWidget);
    expect(find.byKey(const Key('article-retry')), findsOneWidget);
    expect(find.text('该分类暂无百科内容'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: ArticleDetailPage(
          controller: controller,
          article: const {'id': 7, 'title': '详情加载测试'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('健康百科加载失败'), findsOneWidget);
    expect(find.byKey(const Key('article-retry')), findsOneWidget);
    expect(find.text('文章详情暂未返回正文内容。'), findsNothing);
  });

  testWidgets('health analysis remains usable at 2x system text size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(362, 797));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: HealthTrendPage(
          controller: controller,
          metric: HealthMetric.heartRate,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('心率分析'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back stops an active watch measurement', (tester) async {
    final wearable = _TrackingMeasurementWearable();
    final controller =
        AppController(
            MemorySessionVault(),
            _NoopApi(),
            MemoryHealthStore(),
            wearable,
          )
          ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'QA Watch')
          ..capabilities = const DeviceCapabilities(
            metrics: {HealthMetric.heartRate},
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
        theme: buildSaydianTheme(),
        home: AllHealthDataPage(controller: controller),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('心率').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-measure-heart_rate')));
    await tester.pump();
    await tester.pump();
    expect(find.text('心率测量'), findsOneWidget);
    expect(wearable.starts, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('心率测量'), findsNothing);
    expect(wearable.stops, 1);
    expect(controller.deviceState, DeviceConnectionState.ready);
  });

  test(
    'measurement startup failure returns false and restores ready state',
    () async {
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              _FailingMeasurementWearable(),
            )
            ..connectedDevice = const DeviceInfo(
              id: 'watch-1',
              name: 'QA Watch',
            )
            ..capabilities = const DeviceCapabilities(
              metrics: {HealthMetric.heartRate},
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

      expect(
        await controller.startMeasurement(HealthMetric.heartRate),
        isFalse,
      );
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.errorMessage, contains('心率测量失败'));
    },
  );

  test(
    'a second manual measurement is blocked until the first one stops',
    () async {
      final wearable = _TrackingMeasurementWearable();
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              wearable,
            )
            ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S')
            ..capabilities = const DeviceCapabilities(
              metrics: {HealthMetric.heartRate, HealthMetric.hrv},
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

      expect(await controller.startMeasurement(HealthMetric.heartRate), isTrue);
      expect(await controller.startMeasurement(HealthMetric.hrv), isFalse);
      expect(wearable.starts, 1);
      expect(controller.errorMessage, contains('另一项戒指测量尚未结束'));

      await controller.stopMeasurement(HealthMetric.heartRate);
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(wearable.stops, 1);
    },
  );

  test(
    'a failed stop still releases the controller for the next measurement',
    () async {
      final wearable = _FailingStopMeasurementWearable();
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              wearable,
            )
            ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S')
            ..capabilities = const DeviceCapabilities(
              metrics: {HealthMetric.ecg, HealthMetric.hrv},
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

      expect(await controller.startMeasurement(HealthMetric.ecg), isTrue);
      await controller.stopMeasurement(HealthMetric.ecg);
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.errorMessage, '停止测量失败');
      expect(await controller.startMeasurement(HealthMetric.hrv), isTrue);
      expect(wearable.starts, 2);
    },
  );

  testWidgets('ECG measurement waits for the full watch cycle', (tester) async {
    final wearable = _TrackingMeasurementWearable();
    final controller =
        AppController(
            MemorySessionVault(),
            _NoopApi(),
            MemoryHealthStore(),
            wearable,
          )
          ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S')
          ..capabilities = const DeviceCapabilities(
            metrics: {HealthMetric.ecg},
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

    expect(await controller.startMeasurement(HealthMetric.ecg), isTrue);
    await tester.pump(const Duration(seconds: 76));
    expect(controller.deviceState, DeviceConnectionState.measuring);
    expect(controller.measurementErrorMessage, isNull);

    await tester.pump(const Duration(seconds: 74));
    expect(controller.deviceState, DeviceConnectionState.measuring);
    expect(controller.measurementErrorMessage, isNull);

    await tester.pump(const Duration(seconds: 11));
    expect(controller.deviceState, DeviceConnectionState.ready);
    expect(controller.measurementErrorMessage, contains('长时间未检测到有效结果'));
    expect(wearable.stops, 1);
  });

  for (final device in const [
    DeviceInfo(id: 'coolwear:hr05-label-fixture', name: 'HR05'),
    DeviceInfo(id: 'qring:r21-label-fixture', name: 'R21'),
  ]) {
    testWidgets('${device.name} metric labels fit narrow large-text pages', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              _NoopWearable(),
            )
            ..connectedDevice = device
            ..deviceCapabilityState = DeviceCapabilityState.ready
            ..capabilities = const DeviceCapabilities(
              metrics: {HealthMetric.hrv, HealthMetric.bodyTemperature},
            );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(body: DashboardPage(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final hrvCard = find.byKey(const ValueKey('health-metric-hrv'));
      await tester.scrollUntilVisible(
        hrvCard,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: hrvCard, matching: find.text('心率变异性（HRV）')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(hrvCard);
      await tester.pumpAndSettle();
      expect(find.byType(HealthTrendPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.textContaining('心率变异性（HRV）'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(HealthTrendPage))).pop();
      await tester.pumpAndSettle();
      final temperatureCard = find.byKey(
        const ValueKey('health-metric-bodyTemperature'),
      );
      await tester.scrollUntilVisible(
        temperatureCard,
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: temperatureCard, matching: find.text('皮肤温度')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(temperatureCard);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.textContaining('皮肤温度'),
        ),
        findsOneWidget,
      );
      expect(find.text('该时间段暂无数据'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('HRV manual measurement does not ask for ECG electrode contact', (
    tester,
  ) async {
    final wearable = _TrackingMeasurementWearable();
    final controller =
        AppController(
            MemorySessionVault(),
            _NoopApi(),
            MemoryHealthStore(),
            wearable,
          )
          ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S')
          ..capabilities = const DeviceCapabilities(
            metrics: {HealthMetric.hrv},
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
        theme: buildSaydianTheme(),
        home: HealthHistoryPage(
          controller: controller,
          metric: HealthMetric.hrv,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-measure-hrv')));
    await tester.pump();

    expect(find.text('心率变异性（HRV）测量'), findsOneWidget);
    expect(find.text('请将戒指贴合手指并保持静止，等待 HRV 测量结果'), findsOneWidget);
    expect(find.textContaining('心电电极'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(wearable.starts, 1);
    expect(wearable.stops, 1);
  });

  test('measurement waits until the device history sync is complete', () async {
    final wearable = _TrackingMeasurementWearable();
    final controller =
        AppController(
            MemorySessionVault(),
            _NoopApi(),
            MemoryHealthStore(),
            wearable,
          )
          ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'QA Watch')
          ..capabilities = const DeviceCapabilities(
            metrics: {HealthMetric.heartRate},
          )
          ..isDeviceSyncing = true;
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

    expect(await controller.startMeasurement(HealthMetric.heartRate), isFalse);
    expect(wearable.starts, 0);
    expect(controller.deviceState, DeviceConnectionState.ready);
    expect(controller.errorMessage, contains('正在同步'));
  });

  test('blood pressure wear failure keeps the native guidance', () async {
    final controller =
        AppController(
            MemorySessionVault(),
            _NoopApi(),
            MemoryHealthStore(),
            _NotWornBloodPressureWearable(),
          )
          ..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'QA Watch')
          ..capabilities = const DeviceCapabilities(
            metrics: {HealthMetric.bloodPressure},
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

    expect(
      await controller.startMeasurement(HealthMetric.bloodPressure),
      isFalse,
    );
    expect(controller.deviceState, DeviceConnectionState.ready);
    expect(controller.errorMessage, contains('贴合手指'));
  });

  testWidgets('health warning settings persist all three alarm switches', (
    tester,
  ) async {
    final vault = MemorySessionVault();
    final controller = AppController(
      vault,
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthWarningPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('warning-heart-rate-switch')));
    await tester.tap(find.byKey(const Key('warning-blood-pressure-switch')));
    await tester.tap(find.byKey(const Key('warning-temperature-switch')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('warning-save')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('warning-save')));
    await tester.pump();

    expect(vault.healthWarningSettings.heartRateEnabled, isTrue);
    expect(vault.healthWarningSettings.bloodPressureEnabled, isTrue);
    expect(vault.healthWarningSettings.temperatureEnabled, isTrue);
    expect(find.text('健康预警设置已保存'), findsOneWidget);
  });

  testWidgets('device health monitoring hides unsupported model features', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _PartialHealthMonitoringWearable(),
    )..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'D9');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: PermissionManagementPage(
          controller: controller,
          healthOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('device-health-auto-heartRate')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('device-health-auto-bloodGlucose')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('device-health-heart-warning')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('device-health-auto-bloodPressure')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('device-health-auto-bodyTemperature')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('device-health-auto-hrv')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('device-health-auto-stress')),
      findsOneWidget,
    );
    expect(find.text('心率变异性（HRV）自动检测'), findsOneWidget);
    expect(find.text('压力自动检测'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('device-health-auto-heartRate24h')),
      findsOneWidget,
    );
    expect(find.text('24 小时心率'), findsOneWidget);
    expect(find.text('当前设备不支持此功能'), findsNothing);
    expect(find.text('查找设备'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('health-monitoring-find-device')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('monitoring find entry uses resolved device capability', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _PartialHealthMonitoringWearable(),
    )..connectedDevice = const DeviceInfo(id: 'ring-test', name: 'R21');
    addTearDown(controller.dispose);
    controller.capabilities = const DeviceCapabilities(
      metrics: {},
      features: {DeviceFeature.findWatch},
      integratedFeatures: {DeviceFeature.findWatch},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PermissionManagementPage(
          controller: controller,
          healthOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('health-monitoring-find-device'));
    expect(tester.widget<TextButton>(action).onPressed, isNotNull);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(DeviceFeaturePage), findsOneWidget);
    expect(
      tester.widget<DeviceFeaturePage>(find.byType(DeviceFeaturePage)).feature,
      DeviceFeature.findWatch,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    controller.connectedDevice = null;
    controller.notifyListeners();
    await tester.pump();
    expect(tester.widget<TextButton>(action).onPressed, isNull);
  });

  testWidgets('permissions page does not expose a ring find action', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: PermissionManagementPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('health-monitoring-find-device')),
      findsNothing,
    );
  });

  testWidgets('CoolWear stale controls cannot overwrite a replaced device', (
    tester,
  ) async {
    final bridge = _DelayedControlWearable();
    final controller =
        AppController(
            MemorySessionVault(),
            _NoopApi(),
            MemoryHealthStore(),
            bridge,
          )
          ..connectedDevice = const DeviceInfo(id: 'coolwear:old', name: 'HR01')
          ..capabilities = const DeviceCapabilities(
            metrics: {},
            features: {DeviceFeature.gestureControl},
            integratedFeatures: {DeviceFeature.gestureControl},
          );
    addTearDown(controller.dispose);
    final read = controller.readDeviceFeature(DeviceFeature.gestureControl);
    final write = controller.writeDeviceFeature(DeviceFeature.gestureControl, {
      'mode': 1,
    });
    final action = controller.triggerDeviceAction(DeviceFeature.gestureControl);
    controller.connectedDevice = const DeviceInfo(
      id: 'coolwear:new',
      name: 'HR05',
    );
    controller.deviceFeatureData = {
      DeviceFeature.gestureControl: {'confirmedMode': 5},
    };
    controller.deviceFeatureBusy = {DeviceFeature.gestureControl};
    bridge.read.complete({'confirmedMode': 1});
    bridge.write.complete();
    bridge.action.complete();
    expect(await read, isEmpty);
    expect(await write, isFalse);
    expect(await action, isFalse);
    expect(controller.deviceFeatureData[DeviceFeature.gestureControl], {
      'confirmedMode': 5,
    });
    expect(
      controller.deviceFeatureBusy,
      contains(DeviceFeature.gestureControl),
    );
  });

  testWidgets(
    'CoolWear gesture selection confirms a command, not a physical action',
    (tester) async {
      final bridge = _ControlTrackingWearable();
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              bridge,
            )
            ..connectedDevice = const DeviceInfo(
              id: 'coolwear:test-device',
              name: 'HR01',
            )
            ..capabilities = const DeviceCapabilities(
              metrics: {},
              features: {DeviceFeature.gestureControl},
              integratedFeatures: {DeviceFeature.gestureControl},
            );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceFeaturePage(
            controller: controller,
            feature: DeviceFeature.gestureControl,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await tester.ensureVisible(find.text('拍照'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();
      expect(bridge.lastWrite, {'mode': 4});
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('手势模式指令已确认'), findsOneWidget);
    },
  );

  testWidgets(
    'gesture timeout removes old confirmation and blocks unsafe retry',
    (tester) async {
      final bridge = _TimeoutControlWearable();
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              bridge,
            )
            ..connectedDevice = const DeviceInfo(
              id: 'coolwear:one',
              name: 'HR01',
            )
            ..capabilities = const DeviceCapabilities(
              metrics: {},
              features: {DeviceFeature.gestureControl},
              integratedFeatures: {DeviceFeature.gestureControl},
            );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceFeaturePage(
            controller: controller,
            feature: DeviceFeature.gestureControl,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.ensureVisible(find.text('拍照'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.text('重新连接后再设置手势'), findsOneWidget);
      final photoTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('拍照'), matching: find.byType(ListTile)),
      );
      expect(photoTile.onTap, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('firmware entry opens without claiming an available upgrade', (
    tester,
  ) async {
    final controller =
        AppController(
            MemorySessionVault(),
            _NoopApi(),
            MemoryHealthStore(),
            _NoopWearable(),
          )
          ..connectedDevice = const DeviceInfo(
            id: 'coolwear:test-device',
            name: 'HR01',
            firmwareVersion: '758.2.1.9.0',
          )
          ..capabilities = const DeviceCapabilities(
            metrics: {},
            supportsOta: true,
          );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: DeviceInfoPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('device-firmware-upgrade')));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceFirmwarePage), findsOneWidget);
    expect(find.text('当前固件：758.2.1.9.0'), findsOneWidget);
    expect(find.text('在线固件升级暂未开放'), findsOneWidget);
    expect(find.textContaining('已是最新'), findsNothing);
    expect(find.text('立即升级'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('firmware page clears disconnected device and refresh failures', (
    tester,
  ) async {
    final bridge = _FirmwareDetailsWearable();
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      bridge,
    )..connectedDevice = const DeviceInfo(id: 'coolwear:one', name: 'HR01');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: DeviceFirmwarePage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前固件：未知'), findsOneWidget);
    await tester.tap(find.byKey(const Key('firmware-refresh-device')));
    await tester.pumpAndSettle();
    expect(find.text('设备信息刷新失败，重试'), findsOneWidget);
    controller.connectedDevice = null;
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('设备信息刷新失败，重试'), findsNothing);
    expect(find.text('未连接设备'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('firmware-refresh-device')),
          )
          .onPressed,
      isNull,
    );
    expect(bridge.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'firmware page shows refreshed version and fits narrow large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = _FirmwareDetailsWearable()
        ..details = const DeviceInfo(
          id: 'coolwear:one',
          name: 'HR01',
          firmwareVersion: '758.2.1.9.0',
        );
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        bridge,
      )..connectedDevice = const DeviceInfo(id: 'coolwear:one', name: 'HR01');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: DeviceFirmwarePage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('firmware-refresh-device')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('firmware-refresh-device')));
      await tester.pumpAndSettle();
      expect(find.text('当前固件：758.2.1.9.0'), findsOneWidget);
      expect(bridge.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('gesture usage guide is shared: $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final bridge = _ControlTrackingWearable();
        final controller =
            AppController(
                MemorySessionVault(),
                _NoopApi(),
                MemoryHealthStore(),
                bridge,
              )
              ..connectedDevice = const DeviceInfo(
                id: 'coolwear:test-device',
                name: 'HR01',
              )
              ..capabilities = const DeviceCapabilities(
                metrics: {},
                features: {DeviceFeature.gestureControl},
                integratedFeatures: {DeviceFeature.gestureControl},
              );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceFeaturePage(
              controller: controller,
              feature: DeviceFeature.gestureControl,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final guide = find.byKey(const ValueKey('ring-gesture-guide'));
        expect(guide, findsOneWidget);
        await tester.ensureVisible(find.text('使用说明'));
        await tester.tap(find.text('使用说明'));
        await tester.pumpAndSettle();
        expect(find.text('使用前'), findsOneWidget);
        expect(find.text('没有反应？'), findsOneWidget);
        expect(
          find.textContaining(
            platform == TargetPlatform.iOS ? '戒指靠近iPhone' : '戒指靠近安卓手机',
          ),
          findsOneWidget,
        );
        expect(bridge.lastWrite, isNull);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets(
    'CoolWear call reminder separates device switch from iOS authorization',
    (tester) async {
      final bridge = _ControlTrackingWearable();
      final controller =
          AppController(
              MemorySessionVault(),
              _NoopApi(),
              MemoryHealthStore(),
              bridge,
            )
            ..connectedDevice = const DeviceInfo(
              id: 'coolwear:test-device',
              name: 'HR01',
            )
            ..capabilities = const DeviceCapabilities(
              metrics: {},
              features: {DeviceFeature.callReminder},
              integratedFeatures: {DeviceFeature.callReminder},
            );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceFeaturePage(
            controller: controller,
            feature: DeviceFeature.callReminder,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('蓝牙通知未授权'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(bridge.lastWrite?['incomingCall'], isTrue);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(find.text('蓝牙通知未授权'), findsOneWidget);
      expect(find.text('手机通知权限已允许'), findsNothing);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('CoolWear find controls match $platform transport', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final bridge = _FindTrackingWearable();
        final controller =
            AppController(
                MemorySessionVault(),
                _NoopApi(),
                MemoryHealthStore(),
                bridge,
              )
              ..connectedDevice = const DeviceInfo(
                id: 'coolwear:test-device',
                name: 'HR01',
              );
        controller.capabilities = const DeviceCapabilities(
          metrics: {},
          features: {DeviceFeature.findWatch},
          integratedFeatures: {DeviceFeature.findWatch},
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceFeaturePage(
              controller: controller,
              feature: DeviceFeature.findWatch,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byType(FilledButton);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(bridge.commands, [true]);
        expect(find.text('戒指正在响铃或振动'), findsNothing);
        if (platform == TargetPlatform.iOS) {
          expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(bridge.commands, [true, false]);
        } else {
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
          await tester.pump(const Duration(seconds: 7));
          await tester.pumpAndSettle();
          expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
          expect(bridge.commands, [true]);
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  for (final errorCode in [
    'HEART_NOT_WORN',
    'MEASUREMENT_NOT_WORN',
    'MEASUREMENT_FAILED',
  ]) {
    testWidgets('$errorCode stops progress and offers retry', (tester) async {
      final wearable = _EventMeasurementWearable();
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        wearable,
      );
      await controller.initialize();
      controller.connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S');
      controller.capabilities = const DeviceCapabilities(
        metrics: {HealthMetric.heartRate},
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
      addTearDown(() async {
        controller.dispose();
        await wearable.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: AllHealthDataPage(controller: controller),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('心率').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health-measure-heart_rate')));
      await tester.pump();
      wearable.emit(
        WearableEvent(
          type: 'error',
          payload: {'code': errorCode, 'message': '请正确佩戴戒指后重新测量心率'},
        ),
      );
      await tester.pump();

      expect(find.text('请正确佩戴戒指后重新测量心率'), findsOneWidget);
      expect(find.text('重新测量'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(controller.deviceState, DeviceConnectionState.ready);
    });
  }

  testWidgets('body composition contact progress shows wearable guidance', (
    tester,
  ) async {
    final wearable = _EventMeasurementWearable();
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      wearable,
    );
    await controller.initialize();
    controller.connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S');
    controller.capabilities = const DeviceCapabilities(
      metrics: {HealthMetric.bodyComposition},
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
    addTearDown(() async {
      controller.dispose();
      await wearable.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthHistoryPage(
          controller: controller,
          metric: HealthMetric.bodyComposition,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-measure-body_composition')));
    await tester.pump();
    wearable.emit(
      const WearableEvent(
        type: 'measurementProgress',
        payload: {
          'metric': 'body_composition',
          'progress': 12,
          'deviceState': 'UNPASS_WEAR',
        },
      ),
    );
    await tester.pump();

    expect(find.text('未检测到正确接触，请确认戒指贴合手指并按页面指引调整接触位置'), findsOneWidget);
    expect(find.text('测量进度 12%'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(wearable.stops, 1);
  });

  testWidgets('ECG wear flag keeps measurement open and asks for contact', (
    tester,
  ) async {
    final wearable = _EventMeasurementWearable();
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      wearable,
    );
    await controller.initialize();
    controller.connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S');
    controller.capabilities = const DeviceCapabilities(
      metrics: {HealthMetric.ecg},
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
    addTearDown(() async {
      controller.dispose();
      await wearable.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthHistoryPage(
          controller: controller,
          metric: HealthMetric.ecg,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-measure-ecg')));
    await tester.pump();
    wearable.emit(
      const WearableEvent(
        type: 'measurementProgress',
        payload: {
          'metric': 'ecg',
          'progress': 2,
          'deviceState': 'FREE',
          'wear': 1,
        },
      ),
    );
    await tester.pump();

    expect(find.text('未检测到电极接触，请正确佩戴戒指并将手指持续贴在心电电极上'), findsOneWidget);
    expect(find.text('测量进度 2%'), findsOneWidget);
    expect(controller.deviceState, DeviceConnectionState.measuring);
    expect(controller.measurementErrorMessage, isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(wearable.stops, 1);
  });

  testWidgets('watch-side ECG metrics do not claim a missing waveform', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final record = HealthRecord(
      id: 'watch-ecg-history-1',
      metric: HealthMetric.ecg,
      values: const {
        'meanHeartRate': 79,
        'averageHRV': 52,
        'averageTimeInterval': 372,
        'sampleFrequency': 500,
      },
      unit: '',
      measuredAt: DateTime.utc(2026, 8, 28, 15, 8, 22),
      timezone: '+08:00',
      deviceId: 'W9S',
      firmwareVersion: '00.16.06',
      quality: 'device_reported',
      source: MeasurementSource.wearable,
      rawVersion: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthRecordDetailPage(controller: controller, record: record),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('戒指未返回可用心电波形'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('health record detail honors the stored measurement timezone', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final record = HealthRecord(
      id: 'timezone-heart-rate',
      metric: HealthMetric.heartRate,
      values: const {'value': 80},
      unit: 'bpm',
      measuredAt: DateTime.utc(2026, 8, 13, 1, 5),
      timezone: '+08:00',
      deviceId: 'watch',
      firmwareVersion: '1.0',
      quality: 'sdk',
      source: MeasurementSource.wearable,
      rawVersion: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthRecordDetailPage(controller: controller, record: record),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-08-13 09:05'), findsOneWidget);
  });

  testWidgets('sleep record detail never labels awake minutes as hours', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryHealthStore();
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      store,
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    final record = HealthRecord(
      id: 'qring-sleep-detail-units',
      metric: HealthMetric.sleep,
      values: const {
        'value': 7,
        'awakeMinutes': 20,
        'deepHours': 2,
        'lightHours': 4,
        'remHours': 1,
        'score': 85,
        'efficiency': 92,
      },
      unit: 'h',
      measuredAt: DateTime.utc(2026, 9, 30),
      timezone: '+08:00',
      deviceId: 'qring:test',
      firmwareVersion: 'test',
      quality: 'device_reported',
      source: MeasurementSource.wearable,
      rawVersion: 1,
    );
    await store.initialize();
    await store.upsert([record]);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthRecordDetailPage(controller: controller, record: record),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('清醒时长'), findsOneWidget);
    expect(find.text('20 分钟'), findsOneWidget);
    expect(find.text('20 h'), findsNothing);
    expect(find.text('awakeMinutes'), findsNothing);
    expect(find.text('深睡'), findsOneWidget);
    expect(find.text('2小时0分'), findsOneWidget);
    expect(find.text('快速眼动'), findsOneWidget);
    expect(find.text('85 分'), findsOneWidget);
    expect(find.text('92 %'), findsOneWidget);
    expect(find.text('建议结合长期趋势观察'), findsNothing);
    expect(find.text('查看长期趋势更有参考价值'), findsNothing);
  });

  test('repeated watch ECG history is shown once after later syncs', () async {
    final store = MemoryHealthStore();
    await store.initialize();
    final measuredAt = DateTime.utc(2026, 8, 28, 15, 8, 22, 100);
    await store.upsert([
      HealthRecord(
        id: 'watch-ecg-first-read',
        metric: HealthMetric.ecg,
        values: const {'meanHeartRate': 79},
        unit: '',
        measuredAt: measuredAt,
        timezone: '+08:00',
        deviceId: 'W9S',
        firmwareVersion: '00.16.06',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      ),
      HealthRecord(
        id: 'watch-ecg-later-read',
        metric: HealthMetric.ecg,
        values: const {'meanHeartRate': 79, 'averageHRV': 52},
        unit: '',
        measuredAt: measuredAt.add(const Duration(milliseconds: 700)),
        timezone: '+08:00',
        deviceId: 'W9S',
        firmwareVersion: '00.16.06',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      ),
    ]);
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      store,
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    final records = await controller.loadHealthRecords(
      metric: HealthMetric.ecg,
      start: DateTime.utc(2026, 8, 28),
      end: DateTime.utc(2026, 8, 29),
    );

    expect(records, hasLength(1));
    expect(records.single.id, 'watch-ecg-later-read');
  });

  test(
    'new threshold-exceeding wearable record raises a global alert',
    () async {
      final wearable = _EventMeasurementWearable();
      final vault = MemorySessionVault()
        ..healthWarningSettings = const HealthWarningSettings(
          heartRateEnabled: true,
          heartRateUpper: 100,
        );
      final controller = AppController(
        vault,
        _NoopApi(),
        MemoryHealthStore(),
        wearable,
      );
      await controller.initialize();
      await controller.connectDevice(const DeviceInfo(id: 'W9S', name: 'W9S'));
      await Future<void>.delayed(Duration.zero);
      addTearDown(() async {
        controller.dispose();
        await wearable.close();
      });

      wearable.emit(
        WearableEvent(
          type: 'healthRecord',
          payload: HealthRecord(
            id: 'warning-heart-1',
            metric: HealthMetric.heartRate,
            values: const {'value': 128},
            unit: 'bpm',
            measuredAt: DateTime.now().toUtc(),
            timezone: '+08:00',
            deviceId: 'W9S',
            firmwareVersion: '00.20.01',
            quality: 'good',
            source: MeasurementSource.wearable,
            rawVersion: 1,
          ).toJson(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.activeHealthWarningAlert?.metric,
        HealthMetric.heartRate,
      );
      expect(controller.activeHealthWarningAlert?.message, contains('128 bpm'));
      expect(controller.healthWarningAlerts, hasLength(1));
    },
  );

  test(
    'valid wearable result is visible before encrypted storage finishes',
    () async {
      final wearable = _EventMeasurementWearable();
      final store = _DelayedUpsertHealthStore();
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        store,
        wearable,
      );
      await controller.initialize();
      controller.connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S');
      controller.capabilities = const DeviceCapabilities(
        metrics: {HealthMetric.bloodOxygen},
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
      await controller.startMeasurement(HealthMetric.bloodOxygen);
      addTearDown(() async {
        if (!store.release.isCompleted) store.release.complete();
        controller.dispose();
        await wearable.close();
      });

      wearable.emit(
        WearableEvent(
          type: 'healthRecord',
          payload: HealthRecord(
            id: 'oxygen-immediate-1',
            metric: HealthMetric.bloodOxygen,
            values: const {'value': 97},
            unit: '%',
            measuredAt: DateTime.now().toUtc(),
            timezone: '+08:00',
            deviceId: 'watch-1',
            firmwareVersion: '00.20.01',
            quality: 'good',
            source: MeasurementSource.wearable,
            rawVersion: 1,
          ).toJson(),
        ),
      );

      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.healthRecords.single.values['value'], 97);
      expect(store.persistedRecords, isEmpty);

      store.release.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(store.persistedRecords.single.values['value'], 97);
    },
  );

  testWidgets(
    'health trend stops spinning while the encrypted refresh is queued',
    (tester) async {
      final store = _DelayedRangeHealthStore();
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        store,
        _NoopWearable(),
      );
      await controller.initialize();
      controller.connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S');
      controller.capabilities = const DeviceCapabilities(
        metrics: {HealthMetric.ecg},
        manualMetrics: {HealthMetric.ecg},
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
      final now = DateTime.now();
      final measuredAt = DateTime(now.year, now.month, now.day, 12);
      await store.upsert([
        for (var index = 0; index < 4; index++)
          HealthRecord(
            id: 'ecg-existing-$index',
            metric: HealthMetric.ecg,
            values: {'meanHeartRate': 77 + index},
            unit: '',
            measuredAt: measuredAt.subtract(Duration(minutes: 20 - index)),
            timezone: '+08:00',
            deviceId: 'W9S',
            firmwareVersion: '00.20.01',
            quality: 'device_reported',
            source: MeasurementSource.wearable,
            rawVersion: 1,
          ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: HealthTrendPage(
            controller: controller,
            metric: HealthMetric.ecg,
            onMeasure: (_) async {
              controller.healthRecords = [
                HealthRecord(
                  id: 'ecg-visible-before-disk',
                  metric: HealthMetric.ecg,
                  values: const {'meanHeartRate': 82},
                  unit: '',
                  measuredAt: measuredAt,
                  timezone: '+08:00',
                  deviceId: 'W9S',
                  firmwareVersion: '00.20.01',
                  quality: 'device_reported',
                  source: MeasurementSource.wearable,
                  rawVersion: 1,
                ),
              ];
              store.blockRanges();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('手动测量'));
      await tester.pump();
      await tester.pump();

      expect(find.text('测量中'), findsNothing);
      expect(find.text('手动测量'), findsOneWidget);
      expect(find.text('82'), findsWidgets);
      expect(find.text('5 条'), findsWidgets);

      store.releaseRanges();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('health trend passes its live context to manual measurement', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    await controller.initialize();
    controller.connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S');
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
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthTrendPage(
          controller: controller,
          metric: HealthMetric.heartRate,
          onMeasure: (pageContext) => showDialog<void>(
            context: pageContext,
            builder: (dialogContext) => AlertDialog(
              title: const Text('测量上下文有效'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动测量'));
    await tester.pump();
    expect(find.text('测量上下文有效'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
  });

  testWidgets('manual button enables when ring reconnects on an open trend', (
    tester,
  ) async {
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthTrendPage(
          controller: controller,
          metric: HealthMetric.heartRate,
          onMeasure: (_) async {
            opens++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('health-measure-heart_rate'));
    expect(button, findsNothing);

    controller.connectedDevice = const DeviceInfo(id: 'ring-1', name: 'HR01');
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
    controller.notifyListeners();
    await tester.pump();
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pump();
    expect(opens, 1);
  });

  testWidgets('manual result arriving after dialog opens replaces spinner', (
    tester,
  ) async {
    final wearable = _EventMeasurementWearable();
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      wearable,
    );
    await controller.initialize();
    controller.connectedDevice = const DeviceInfo(id: 'watch-1', name: 'HR01');
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
    addTearDown(() async {
      controller.dispose();
      await wearable.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: Scaffold(body: HealthPage(controller: controller)),
      ),
    );
    await tester.tap(find.text('心率').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动测量'));
    await tester.pump();
    expect(find.text('请戴好戒指并保持静止\n等待戒指返回测量结果'), findsOneWidget);

    wearable.emit(
      WearableEvent(
        type: 'healthRecord',
        payload: HealthRecord(
          id: 'heart-from-real-ring',
          metric: HealthMetric.heartRate,
          values: const {'value': 72},
          unit: 'bpm',
          measuredAt: DateTime.now().toUtc(),
          timezone: '+08:00',
          deviceId: 'watch-1',
          firmwareVersion: '758.1.1.8.0',
          quality: 'unknown',
          source: MeasurementSource.wearable,
          rawVersion: 1,
        ).toJson(),
      ),
    );
    await tester.pump();
    expect(find.text('72 bpm'), findsWidgets);
    expect(find.text('请戴好戒指并保持静止\n等待戒指返回测量结果'), findsNothing);
    expect(find.text('完成'), findsOneWidget);
  });

  test('a disconnected ring ends an in-flight manual measurement', () async {
    final wearable = _EventMeasurementWearable();
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      MemoryHealthStore(),
      wearable,
    );
    await controller.initialize();
    controller.connectedDevice = const DeviceInfo(id: 'ring-1', name: 'HR01');
    controller.capabilities = const DeviceCapabilities(
      metrics: {HealthMetric.bloodOxygen},
      manualMetrics: {HealthMetric.bloodOxygen},
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
    addTearDown(() async {
      controller.dispose();
      await wearable.close();
    });

    expect(await controller.startMeasurement(HealthMetric.bloodOxygen), isTrue);
    wearable.emit(
      const WearableEvent(
        type: 'disconnected',
        payload: {'deviceId': 'ring-1'},
      ),
    );
    expect(controller.deviceState, DeviceConnectionState.disconnected);
    expect(controller.measurementErrorMessage, contains('连接中断'));
    await controller.stopMeasurement(HealthMetric.bloodOxygen);
    expect(wearable.stops, 0);
  });

  test(
    'rejected ECG record releases measurement with quality guidance',
    () async {
      final wearable = _EventMeasurementWearable();
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        wearable,
      );
      await controller.initialize();
      controller.connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S');
      controller.capabilities = const DeviceCapabilities(
        metrics: {HealthMetric.ecg},
        manualMetrics: {HealthMetric.ecg},
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
      addTearDown(() async {
        controller.dispose();
        await wearable.close();
      });

      expect(await controller.startMeasurement(HealthMetric.ecg), isTrue);
      wearable.emit(
        WearableEvent(
          type: 'healthRecord',
          payload: HealthRecord(
            id: 'invalid-ecg',
            metric: HealthMetric.ecg,
            values: const {'meanHeartRate': 80, 'sampleFrequency': 250},
            unit: '',
            measuredAt: DateTime.now().toUtc(),
            timezone: '+08:00',
            deviceId: 'watch-1',
            firmwareVersion: '00.20.01',
            quality: 'device_reported',
            source: MeasurementSource.wearable,
            rawVersion: 2,
            samples: List<num>.generate(1000, (index) => index.isEven ? -8 : 8),
          ).toJson(),
        ),
      );

      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.measurementErrorMessage, contains('心电信号质量不足'));
      expect(controller.measurementProgress, 0);
      expect(controller.healthRecords, isEmpty);
    },
  );

  test(
    'unsupported health settings finish with a clear device state',
    () async {
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        _NoopWearable(),
      )..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'QA Watch');
      addTearDown(controller.dispose);

      await controller.refreshDeviceSettings();

      expect(controller.autoMeasureSettings, isEmpty);
      expect(controller.heartRateWarningSupported, isFalse);
      expect(controller.deviceSettingsStatus, '当前戒指未提供可设置的健康检测项目');
    },
  );

  test(
    'health settings coalesce duplicate entry reads and retry capability startup',
    () async {
      final wearable = _TransientHealthMonitoringWearable();
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        wearable,
      )..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S');
      addTearDown(controller.dispose);

      final first = controller.refreshDeviceSettings();
      final duplicate = controller.refreshDeviceSettings();

      expect(identical(first, duplicate), isTrue);
      await Future.wait([first, duplicate]);

      expect(wearable.autoMeasureReads, 2);
      expect(controller.isDeviceSettingsLoading, isFalse);
      expect(controller.autoMeasureSettings, const {
        'heartRate': true,
        'bodyTemperature': true,
      });
      expect(controller.heartRateWarning, 145);
      expect(controller.deviceSettingsStatus, '设置已同步');
    },
  );

  testWidgets('temperature chart has unique ticks and contained time labels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryHealthStore();
    await store.initialize();
    await store.upsert([
      HealthRecord(
        id: 'temperature-chart-fixture',
        metric: HealthMetric.bodyTemperature,
        values: const {'value': 36.9},
        unit: '℃',
        measuredAt: DateTime.now(),
        timezone: '+08:00',
        deviceId: 'qring:fixture',
        firmwareVersion: 'test',
        quality: 'unknown',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      ),
    ]);
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      store,
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthTrendPage(
          controller: controller,
          metric: HealthMetric.bodyTemperature,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(LineChart), 250);
    await tester.pumpAndSettle();
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.titlesData.leftTitles.sideTitles.minIncluded, isFalse);
    expect(chart.data.titlesData.leftTitles.sideTitles.maxIncluded, isFalse);
    expect(chart.data.titlesData.bottomTitles.sideTitles.maxIncluded, isTrue);
    final ticks = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(LineChart),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .whereType<String>()
        .where((text) => num.tryParse(text) != null)
        .toList();
    expect(ticks, isNotEmpty);
    expect(ticks.toSet().length, ticks.length);
    final titles = tester.widgetList<SideTitleWidget>(
      find.descendant(
        of: find.byType(LineChart),
        matching: find.byType(SideTitleWidget),
      ),
    );
    expect(titles, isNotEmpty);
    expect(titles.every((title) => title.fitInside.enabled), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('health trend supports period switching and record details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final store = MemoryHealthStore();
    await store.initialize();
    await store.upsert([
      for (var index = 0; index < 3; index++)
        HealthRecord(
          id: 'heart-$index',
          metric: HealthMetric.heartRate,
          values: {'value': 68 + index * 4},
          unit: 'bpm',
          measuredAt: DateTime(now.year, now.month, now.day, 8 + index * 3),
          timezone: '+08:00',
          deviceId: 'ET488',
          firmwareVersion: 'test',
          quality: 'good',
          source: MeasurementSource.wearable,
          rawVersion: 1,
        ),
    ]);
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      store,
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthTrendPage(
          controller: controller,
          metric: HealthMetric.heartRate,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('心率分析'), findsOneWidget);
    expect(find.text('平均值'), findsOneWidget);
    expect(find.text('3 条'), findsWidgets);

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    expect(find.text('选择查看日期'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final recordTiles = find.ancestor(
      of: find.text('72 bpm'),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      recordTiles,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(recordTiles.last);
    await tester.pumpAndSettle();
    expect(find.text('心率详情'), findsOneWidget);
  });

  testWidgets('sleep trend exposes SDK stages without inventing REM', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final store = MemoryHealthStore();
    await store.initialize();
    await store.upsert([
      HealthRecord(
        id: 'sleep-structure',
        metric: HealthMetric.sleep,
        values: const {
          'value': 7,
          'deepHours': 2,
          'lightHours': 4.5,
          'movementMinutes': 30,
          'wakeCount': 2,
        },
        unit: 'h',
        measuredAt: DateTime(now.year, now.month, now.day, 7),
        timezone: '+08:00',
        deviceId: 'HR01',
        firmwareVersion: 'test',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      ),
    ]);
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      store,
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthTrendPage(
          controller: controller,
          metric: HealthMetric.sleep,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-structure-card')), findsOneWidget);
    expect(find.text('2小时0分'), findsOneWidget);
    expect(find.text('4小时30分'), findsOneWidget);
    expect(find.text('--（戒指未返回）'), findsOneWidget);
  });

  testWidgets('QRing sleep stages and score display only returned values', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = MemoryHealthStore();
    await store.initialize();
    await store.upsert([
      HealthRecord(
        id: 'qring-sleep-structure',
        metric: HealthMetric.sleep,
        values: const {
          'value': 7,
          'deepHours': 2,
          'lightHours': 4,
          'remHours': 1,
          'awakeMinutes': 20,
          'score': 85,
          'efficiency': 92,
        },
        unit: 'h',
        measuredAt: DateTime(now.year, now.month, now.day, 7),
        timezone: '+08:00',
        deviceId: 'qring:test',
        firmwareVersion: 'test',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      ),
    ]);
    final controller = AppController(
      MemorySessionVault(),
      _NoopApi(),
      store,
      _NoopWearable(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: HealthTrendPage(
          controller: controller,
          metric: HealthMetric.sleep,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('快速眼动'), findsOneWidget);
    expect(find.text('1小时0分'), findsOneWidget);
    expect(find.text('清醒时长'), findsOneWidget);
    expect(find.text('20 分钟'), findsOneWidget);
    expect(find.text('设备睡眠评分'), findsOneWidget);
    expect(find.text('85 分'), findsOneWidget);
    expect(find.text('睡眠效率'), findsOneWidget);
    expect(find.text('92 %'), findsOneWidget);
    expect(find.text('--（戒指未返回）'), findsNothing);
  });

  testWidgets('care blood composition detail uses readable Chinese fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: CareMetricDetailPage(
          day: DateTime(2026, 8, 26),
          item: const {
            'title': '血液成分',
            'records': [
              {
                'id': '1230',
                'member_id': '87',
                'date': '2026-08-26 17:56:29',
                'uricAcidVal': '206.80000305176',
                'cholesterol': '3.2999999523163',
                'triacylglycerol': '1.039999961853',
                'highDensity': '1.0800000429153',
                'lowDensity': '2.1099998950958',
                'status': '1',
                'created_at': '1787738189',
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('尿酸'), findsOneWidget);
    expect(find.text('206.8 μmol/L'), findsOneWidget);
    expect(find.text('总胆固醇'), findsOneWidget);
    expect(find.text('3.3 mmol/L'), findsOneWidget);
    expect(find.text('uricAcidVal'), findsNothing);
    expect(find.text('created_at'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('care HRV detail hides unrelated raw row fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: CareMetricDetailPage(
          day: DateTime(2026, 8, 29),
          item: const {
            'title': 'HRV',
            'unit': 'ms',
            'records': [
              {
                'time': -1,
                'HRVData': {'hrv': 47},
                'step': 9321,
                'heartReat': 84,
                'bloodPressure': {
                  'bloodPressureHigh': 136,
                  'bloodPressureLow': 81,
                },
                'bodyTemperature': 36.5,
                'englishNestedKey': {'value': 999},
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当日摘要'), findsOneWidget);
    expect(find.text('第 1 条记录'), findsOneWidget);
    expect(find.text('47 ms'), findsWidgets);
    expect(find.text('-1'), findsNothing);
    expect(find.text('step'), findsNothing);
    expect(find.text('heartReat'), findsNothing);
    expect(find.text('bloodPressure'), findsNothing);
    expect(find.text('bodyTemperature'), findsNothing);
    expect(find.text('englishNestedKey'), findsNothing);
    expect(find.text('84 次/分'), findsNothing);
    expect(find.text('136 mmHg'), findsNothing);
    expect(find.text('36.5 ℃'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('care blood pressure splits systolic diastolic and pulse', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: CareMetricDetailPage(
          day: DateTime(2026, 8, 29),
          item: const {
            'title': '血压',
            'unit': 'mmHg',
            'records': [
              {
                'time': 10,
                'bloodPressure': {
                  'bloodPressureHigh': 136,
                  'bloodPressureLow': 81,
                },
                'pulseReat': 84,
                'HRVData': 47,
                'step': 9321,
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('收缩压'), findsOneWidget);
    expect(find.text('136 mmHg'), findsOneWidget);
    expect(find.text('舒张压'), findsOneWidget);
    expect(find.text('81 mmHg'), findsOneWidget);
    expect(find.text('脉搏'), findsOneWidget);
    expect(find.text('84 次/分'), findsOneWidget);
    expect(find.textContaining('136/81 mmHg'), findsWidgets);
    expect(find.text('HRV'), findsNothing);
    expect(find.text('step'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('care temperature detail does not leak glucose or heart rate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: CareMetricDetailPage(
          day: DateTime(2026, 8, 29),
          item: const {
            'title': '体温',
            'unit': '℃',
            'records': [
              {
                'time': 'invalid-time',
                'bodyTemperature': 36.5,
                'bloodGlucose': 5.9,
                'heartReat': 84,
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第 1 条记录'), findsOneWidget);
    expect(find.text('体温'), findsWidgets);
    expect(find.text('36.5 ℃'), findsWidgets);
    expect(find.text('血糖'), findsNothing);
    expect(find.text('5.9 mmol/L'), findsNothing);
    expect(find.text('心率'), findsNothing);
    expect(find.text('84 次/分'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('care body composition keeps only related nested submetrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: CareMetricDetailPage(
          day: DateTime(2026, 8, 29),
          item: const {
            'title': '身体成分',
            'records': [
              {
                'date': '2026-08-29 11:20:00',
                'data': {
                  'BMI': 21.3,
                  'bodyFatRate': 18.2,
                  'muscleMass': 48.1,
                  'bloodGlucose': 5.5,
                  'heartReat': 82,
                },
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BMI'), findsOneWidget);
    expect(find.text('21.3'), findsOneWidget);
    expect(find.text('体脂率'), findsOneWidget);
    expect(find.text('18.2 %'), findsOneWidget);
    expect(find.text('肌肉量'), findsOneWidget);
    expect(find.text('48.1 kg'), findsOneWidget);
    expect(find.text('血糖'), findsNothing);
    expect(find.text('5.5 mmol/L'), findsNothing);
    expect(find.text('心率'), findsNothing);
    expect(find.text('82 次/分'), findsNothing);
    expect(find.text('bodyFatRate'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('care metric detail formats hour categories as clock times', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: CareMetricDetailPage(
          day: DateTime(2026, 8, 26),
          item: const {
            'title': '血氧',
            'records': [
              {'time': '18', 'bloodOxygen': 99},
              {'time': '19:30', 'bloodOxygen': 98},
              {'date': '2026-08-26 20:15:30', 'bloodOxygen': 96},
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('19:30'), findsOneWidget);
    expect(find.text('20:15:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('care metric detail keeps the API-normalized latest reading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: CareMetricDetailPage(
          day: DateTime(2026, 8, 30),
          item: const {
            'title': '心率',
            'latest': 75,
            'records': [
              {'time': '20:15', 'pulseReat': 75},
              {'time': '08:10', 'pulseReat': 68},
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近  75 次/分'), findsOneWidget);
    expect(find.text('最近  68 次/分'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('care pressure detail keeps the normalized latest pair', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: CareMetricDetailPage(
          day: DateTime(2026, 8, 30),
          item: const {
            'title': '血压',
            'latest': '128/82',
            'records': [
              {
                'time': '21:30',
                'bloodPressureHigh': 128,
                'bloodPressureLow': 82,
              },
              {
                'time': '07:30',
                'bloodPressureHigh': 118,
                'bloodPressureLow': 76,
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近  128/82 mmHg'), findsOneWidget);
    expect(find.text('最近  118/76 mmHg'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('care history labels authorized activity as selected-day data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(
      MemorySessionVault(),
      _CarePreviewApi(),
      MemoryHealthStore(),
      _NoopWearable(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: CareMemberPage(
          controller: controller,
          member: const {'nickname': '关爱成员', 'to_member_id': 87},
          careId: 59,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日活动'), findsOneWidget);
    await tester.tap(find.byTooltip('前一天'));
    await tester.pumpAndSettle();
    expect(find.text('当日活动'), findsOneWidget);
    expect(find.text('今日活动'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('care metric detail explains server-unavailable data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaydianTheme(),
        home: CareMetricDetailPage(
          day: DateTime(2026, 8, 27),
          item: const {
            'title': '血压',
            'state': 'unavailable',
            'tips': '血压服务暂不可用，请稍后重试',
            'records': <Object?>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('血压服务暂不可用，请稍后重试'), findsOneWidget);
    expect(find.text('这一天没有可展示的明细记录。'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'remote ECG shows objective fields without dumping raw payload keys',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          home: CareMetricDetailPage(
            day: DateTime(2026, 8, 27),
            item: const {
              'title': '心电',
              'records': [
                {
                  'date': '2026-08-27 09:30:00',
                  'meanHeartRate': 79,
                  'averageHRV': 52,
                  'averageTimeInterval': 372,
                  'sampleFrequency': 250,
                  'rawVersion': 1,
                  'samples': [0, 120, -80, 180],
                  'origin': 'remote_member',
                },
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('远程成员数据'), findsOneWidget);
      expect(find.text('心率'), findsOneWidget);
      expect(find.text('79'), findsOneWidget);
      expect(find.text('QT'), findsOneWidget);
      expect(find.text('372'), findsOneWidget);
      expect(find.text('HRV'), findsOneWidget);
      expect(find.text('52'), findsOneWidget);
      expect(find.text('暂无可用心电波形'), findsOneWidget);
      expect(find.textContaining('服务端'), findsNothing);
      expect(find.byKey(const Key('care-ecg-waveform')), findsNothing);
      expect(find.text('samples'), findsNothing);
      expect(find.text('rawVersion'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ECG detail stays readable on a narrow Android screen and does not invent risks',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = AppController(
        MemorySessionVault(),
        _NoopApi(),
        MemoryHealthStore(),
        _NoopWearable(),
      );
      addTearDown(controller.dispose);
      final record = HealthRecord(
        id: 'narrow-ecg',
        metric: HealthMetric.ecg,
        values: const {
          'meanHeartRate': 83,
          'averageHRV': 24,
          'averageTimeInterval': 380,
          'respiratoryRate': 17,
          'sdnn': 38,
          'rmssd': 31,
        },
        unit: '',
        measuredAt: DateTime(2026, 8, 30, 12, 30),
        timezone: '+08:00',
        deviceId: 'ET488',
        firmwareVersion: 'test',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        origin: MeasurementOrigin.watchHistory,
        rawVersion: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaydianTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: HealthRecordDetailPage(controller: controller, record: record),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('心率变异性（HRV）'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('83 bpm'), findsOneWidget);
      expect(find.text('24 ms'), findsOneWidget);
      expect(find.text('380 ms'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('风险分析').first);
      await tester.pumpAndSettle();
      expect(find.text('本次戒指未返回风险指标'), findsOneWidget);
      expect(find.textContaining('低风险 · 0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'recent watch-history threshold is saved once during device sync',
    () async {
      final record = HealthRecord(
        id: 'watch-sync-warning-1',
        metric: HealthMetric.heartRate,
        values: const {'value': 126},
        unit: 'bpm',
        measuredAt: DateTime.now().toUtc(),
        timezone: '+08:00',
        deviceId: 'W9S',
        firmwareVersion: '00.20.01',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        origin: MeasurementOrigin.watchHistory,
        rawVersion: 1,
      );
      final wearable = _SyncHealthWearable([record]);
      final vault = MemorySessionVault()
        ..healthWarningSettings = const HealthWarningSettings(
          heartRateEnabled: true,
          heartRateUpper: 100,
        );
      final controller = AppController(
        vault,
        _NoopApi(),
        MemoryHealthStore(),
        wearable,
      )..connectedDevice = const DeviceInfo(id: 'watch-1', name: 'W9S');
      await controller.initialize();
      addTearDown(controller.dispose);

      await controller.syncDeviceData();
      await controller.syncDeviceData();

      expect(controller.healthWarningAlerts, hasLength(1));
      expect(controller.activeHealthWarningAlert?.id, record.id);
      expect(
        controller.activeHealthWarningAlert?.origin,
        MeasurementOrigin.watchHistory,
      );
      expect(
        controller.activeHealthWarningAlert?.triggeredAt.toUtc(),
        record.measuredAt,
      );
    },
  );
}

HealthRecord _historicalHeartRateRecord() => HealthRecord(
  id: 'history-heart-rate',
  metric: HealthMetric.heartRate,
  values: const {'value': 75},
  unit: 'bpm',
  measuredAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
  timezone: '+08:00',
  deviceId: 'previous-watch',
  firmwareVersion: '1.0',
  quality: 'device_reported',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);

HealthRecord _historicalBloodPressureRecord() => HealthRecord(
  id: 'history-blood-pressure',
  metric: HealthMetric.bloodPressure,
  values: const {'systolic': 116, 'diastolic': 84},
  unit: 'mmHg',
  measuredAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
  timezone: '+08:00',
  deviceId: 'previous-watch',
  firmwareVersion: '1.0',
  quality: 'device_reported',
  source: MeasurementSource.wearable,
  rawVersion: 1,
);

class _EditableProfileApi extends _NoopApi implements SaydianFileApi {
  static const uploadedAvatarUrl =
      'https://app.saydian.cn/global/media/test-new-avatar.png';
  Map<String, Object?> profile = const {};

  @override
  Future<Map<String, Object?>> getMemberProfile() async => {...profile};

  @override
  Future<String> uploadImage(String filePath) async => uploadedAvatarUrl;

  @override
  Future<void> saveMemberProfile({
    required String nickname,
    required int gender,
    required String birthday,
    required double height,
    required double weight,
    String? headPortrait,
  }) async {
    profile = {...profile, 'nickname': nickname, 'head_portrait': headPortrait};
  }
}

class _AvatarOnlyGlobalApi extends Fake
    implements
        SaydianApi,
        SaydianFileApi,
        SaydianAvatarProfileApi,
        GlobalAccountApi {
  static const uploadedAvatarUrl =
      'https://app.saydian.cn/global/api/saydian-app/v2/files/avatar-test';
  String? savedUrl;
  bool persistAvatar = true;

  @override
  Future<String> uploadImage(String filePath) async => uploadedAvatarUrl;

  @override
  Future<void> saveAvatarUrl(String avatarUrl) async {
    savedUrl = avatarUrl;
  }

  @override
  Future<void> saveMemberProfile({
    required String nickname,
    required int gender,
    required String birthday,
    required double height,
    required double weight,
    String? headPortrait,
  }) async {
    savedUrl = headPortrait;
  }

  @override
  Future<Map<String, Object?>> getMemberProfile() async => {
    'nickname': '测试用户',
    'head_portrait': persistAvatar ? savedUrl : null,
  };
}

class _NoopApi implements SaydianApi, SaydianArticleApi {
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
  }) async => const [
    {'id': 7, 'title': 'QA 健康知识'},
  ];

  @override
  Future<Map<String, Object?>> addCare(String mobile) async => const {};

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => const [];

  @override
  Future<Map<String, Object?>> getCareMemberPreview({
    required int id,
    required String day,
    int? memberId,
  }) async => const {};

  @override
  Future<Map<String, Object?>> getMemberProfile() async => const {};

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
  Future<Map<String, Object?>> getActivityGoals() async => const {};

  @override
  Future<void> saveActivityGoals({
    required int steps,
    required double distance,
    required int calories,
  }) async {}

  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];

  @override
  Future<Map<String, Object?>> getArticle(int id) async => const {};

  @override
  Future<Map<String, Object?>> getSingleArticle(int id) async => const {};

  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      const [];

  @override
  Future<Map<String, Object?>> getNotification(int id) async => const {};

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
  }) async => const {};

  @override
  Future<List<Map<String, Object?>>> getOrders({int? status}) async => const [];

  @override
  Future<Map<String, Object?>> getOrderDetail(int id) async => const {};

  @override
  Future<List<Map<String, Object?>>> getAddresses() async => const [];

  @override
  Future<Session> login(String username, String password) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<Session> register(String mobile, String password) =>
      throw UnimplementedError();

  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) =>
      throw UnimplementedError();
}

class _CarePreviewApi extends _NoopApi {
  @override
  Future<Map<String, Object?>> getCareMemberPreview({
    required int id,
    required String day,
    int? memberId,
  }) async => const {
    'jrjk': [
      {'title': '步数', 'num': 1234, 'unit': '步'},
    ],
    'daily': <Object?>[],
  };
}

class _NoopWearable implements WearableBridge {
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      const {};

  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {}

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {}

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async => const {};

  @override
  Future<int?> readHeartRateWarning() async => null;

  @override
  Future<void> setAutoMeasureSetting(String type, bool enabled) async {}

  @override
  Future<void> setHeartRateWarning(int value) async {}

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<WearableEvent> get events => const Stream.empty();

  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(metrics: {});

  @override
  Future<List<DeviceInfo>> scanDevices() async => const [];

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> startMeasurement(HealthMetric metric) async {}

  @override
  Future<void> stopMeasurement(HealthMetric metric) async {}

  @override
  Future<void> startSport(SportMode mode) async {}

  @override
  Future<void> stopSport() async {}

  @override
  Future<List<SportRecord>> readSportRecords() async => const [];

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => const [];
}

class _FindTrackingWearable extends _NoopWearable {
  final commands = <bool>[];

  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {
    expect(feature, DeviceFeature.findWatch);
    commands.add(enabled);
  }
}

class _ControlTrackingWearable extends _NoopWearable {
  Map<String, Object?>? lastWrite;
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      feature == DeviceFeature.gestureControl
      ? {if (lastWrite?['mode'] != null) 'confirmedMode': lastWrite!['mode']}
      : {
          'incomingCall': lastWrite?['incomingCall'] == true,
          'systemNotificationAuthorized': false,
        };
  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    lastWrite = values;
  }
}

class _FirmwareDetailsWearable extends _NoopWearable
    implements WearableDeviceDetailsBridge {
  int reads = 0;
  DeviceInfo? details;
  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() async {
    reads++;
    if (details == null) throw PlatformException(code: 'READ_FAILED');
    return details;
  }
}

class _TimeoutControlWearable extends _ControlTrackingWearable {
  bool timedOut = false;
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      timedOut ? {'requiresReconnect': true} : {'confirmedMode': 2};
  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    timedOut = true;
    throw PlatformException(code: 'GESTURE_CONFIRMATION_TIMEOUT');
  }
}

class _DelayedControlWearable extends _NoopWearable {
  final read = Completer<Map<String, Object?>>();
  final write = Completer<void>();
  final action = Completer<void>();
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) =>
      read.future;
  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) => write.future;
  @override
  Future<void> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) => action.future;
}

class _PartialHealthMonitoringWearable extends _NoopWearable {
  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async => const {
    'heartRate': false,
    'heartRate24h': true,
    'bloodGlucose': false,
    'hrv': true,
    'stress': true,
  };

  @override
  Future<int?> readHeartRateWarning() async => 140;
}

class _SyncHealthWearable extends _NoopWearable {
  _SyncHealthWearable(this.records);

  final List<HealthRecord> records;

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => records;
}

class _TransientHealthMonitoringWearable extends _NoopWearable {
  int autoMeasureReads = 0;

  @override
  Future<Map<String, bool>> readAutoMeasureSettings() async {
    autoMeasureReads++;
    if (autoMeasureReads == 1) {
      throw PlatformException(
        code: 'AUTO_MEASURE_READ_TIMEOUT',
        message: '能力数据仍在初始化',
      );
    }
    return const {'heartRate': true, 'bodyTemperature': true};
  }

  @override
  Future<int?> readHeartRateWarning() async => 145;
}

class _TrackingMeasurementWearable extends _NoopWearable {
  int starts = 0;
  int stops = 0;

  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    starts++;
  }

  @override
  Future<void> stopMeasurement(HealthMetric metric) async {
    stops++;
  }
}

class _EventMeasurementWearable extends _TrackingMeasurementWearable {
  final _events = StreamController<WearableEvent>.broadcast(sync: true);

  @override
  Stream<WearableEvent> get events => _events.stream;

  void emit(WearableEvent event) => _events.add(event);

  Future<void> close() => _events.close();
}

class _DelayedUpsertHealthStore extends MemoryHealthStore {
  final release = Completer<void>();
  final persistedRecords = <HealthRecord>[];

  @override
  Future<void> upsert(List<HealthRecord> records) async {
    await release.future;
    persistedRecords.addAll(records);
    await super.upsert(records);
  }

  @override
  Future<void> upsertImmediate(HealthRecord record) => upsert([record]);
}

class _DelayedRangeHealthStore extends MemoryHealthStore {
  Completer<void>? _rangeRelease;

  void blockRanges() => _rangeRelease = Completer<void>();

  void releaseRanges() => _rangeRelease?.complete();

  @override
  Future<List<HealthRecord>> range({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) async {
    await _rangeRelease?.future;
    return super.range(metric: metric, start: start, end: end);
  }
}

class _FailingArticleApi extends _NoopApi {
  @override
  Future<List<Map<String, Object?>>> getArticlesByCategory({
    int? categoryId,
    int page = 1,
  }) async {
    throw const ApiException('模拟网络不可用');
  }

  @override
  Future<Map<String, Object?>> getArticle(int id) async {
    throw const ApiException('模拟网络不可用');
  }
}

class _FailingMeasurementWearable extends _NoopWearable {
  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    throw StateError('simulated start failure');
  }
}

class _FailingStopMeasurementWearable extends _TrackingMeasurementWearable {
  @override
  Future<void> stopMeasurement(HealthMetric metric) async {
    stops++;
    throw StateError('simulated stop failure');
  }
}

class _NotWornBloodPressureWearable extends _NoopWearable {
  @override
  Future<void> startMeasurement(HealthMetric metric) async {
    throw PlatformException(
      code: 'BLOOD_PRESSURE_NOT_WORN',
      message: '未检测到有效佩戴状态，请将戒指贴合手指后重新测量血压',
    );
  }
}
