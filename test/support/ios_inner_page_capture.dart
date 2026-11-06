// Opt-in visual reference capture. Renders unchanged production Flutter pages
// with empty, offline fixtures; never connects to an account, watch or payment.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import '../health_reminder_layout_test.dart' show LayoutController;
import 'cycle_diary_fixture.dart' as cycle_fixture;
import 'package:saydian_app/domain/cycle_tracking.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart' hide AfterSalesPage;
import 'package:saydian_app/ui/shop_pages.dart' as shop;

import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/ui/global_auth_page.dart';
import 'package:saydian_app/ui/global_code_login_page.dart';
import 'package:saydian_app/ui/global_care_page.dart';
import 'package:saydian_app/ui/global_shop_account_pages.dart';
import 'package:saydian_app/ui/global_shop_cart_pages.dart';
import 'package:saydian_app/ui/global_shop_pages.dart';
import 'package:saydian_app/ui/home_health_cards_page.dart';
import 'package:saydian_app/ui/health_reports_page.dart';
import 'package:saydian_app/ui/health_trend_page.dart';
import 'package:saydian_app/ui/sleep_ai_report_page.dart';
import 'package:saydian_app/ui/wellness_release.dart';
import 'package:saydian_app/ui/global_legal_page.dart';
import 'package:saydian_app/ui/watch_face_market_page.dart';
import 'package:saydian_app/services/device_watch_face_market_service.dart';
import 'package:saydian_app/ui/article_reader.dart';
import 'package:saydian_app/domain/health_report_models.dart';
import 'package:saydian_app/ui/health_reminder_center.dart';
import 'package:saydian_app/ui/cycle_tracking_page.dart';
import 'package:saydian_app/ui/review_demo_page.dart';
import 'package:saydian_app/domain/global_commerce.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/ui/global_shop_payment_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const output = String.fromEnvironment('IOS_REFERENCE_OUTPUT');
  testWidgets(
    'capture iOS inner-page references without production writes',
    (tester) async {
      if (output.isEmpty) return;
      const captureImages = bool.fromEnvironment(
        'IOS_REFERENCE_CAPTURE',
        defaultValue: true,
      );
      const interactions = bool.fromEnvironment('IOS_REFERENCE_INTERACTIONS');
      const pageFilter = String.fromEnvironment('IOS_REFERENCE_PAGE');
      const fontScale = String.fromEnvironment(
        'IOS_REFERENCE_TEXT_SCALE',
        defaultValue: '1',
      );
      const publicImages = bool.fromEnvironment('IOS_REFERENCE_PUBLIC_IMAGES');
      if (publicImages) {
        // Opt-in public product image capture only. API/account calls remain offline.
        final previous = HttpOverrides.current;
        HttpOverrides.global = null;
        addTearDown(() => HttpOverrides.global = previous);
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.runAsync(() async {
        // System font is loaded for this local capture, not copied into the repo.
        const font = String.fromEnvironment(
          'IOS_REFERENCE_FONT',
          defaultValue: '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
        );
        final bytes = await File(font).readAsBytes();
        for (final family in [
          'Reference Chinese',
          'Ahem',
          'Roboto',
          'PingFang SC',
          '.SF UI Text',
          '.SF UI Display',
        ]) {
          final loader = FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes)));
          await loader.load();
        }
        final packagesFile = File('.dart_tool/package_config.json');
        final packages =
            jsonDecode(await packagesFile.readAsString())
                as Map<String, dynamic>;
        final flutterPackage = (packages['packages'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['name'] == 'flutter');
        final flutterRoot = Directory.fromUri(
          packagesFile.absolute.uri.resolve(
            flutterPackage['rootUri'] as String,
          ),
        ).parent.parent;
        final icons = await File(
          '${flutterRoot.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons)))).load();
        await Directory(output).create(recursive: true);
        await rootBundle.loadString('assets/china_regions.json');
      });
      const width = String.fromEnvironment(
        'IOS_REFERENCE_WIDTH',
        defaultValue: '411',
      );
      const height = String.fromEnvironment(
        'IOS_REFERENCE_HEIGHT',
        defaultValue: '858',
      );
      const ratio = String.fromEnvironment(
        'IOS_REFERENCE_SCALE',
        defaultValue: '2',
      );
      await tester.binding.setSurfaceSize(
        Size(double.parse(width), double.parse(height)),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(
        double.parse(width),
        double.parse(height),
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller =
          AppController(
              MemorySessionVault(),
              _OfflineApi(),
              MemoryHealthStore(),
              _OfflineWatch(),
            )
            ..isBooting = false
            ..session = Session(
              accessToken: 'visual-fixture',
              refreshToken: '',
              expiresAt: DateTime(2030),
              memberId: 'visual-fixture',
              displayName: 'Say Ring 用户',
            );
      addTearDown(controller.dispose);
      final auth = AppController(
        MemorySessionVault(),
        _OfflineLoginApi(),
        MemoryHealthStore(),
        _OfflineWatch(),
      )..isBooting = false;
      addTearDown(auth.dispose);
      HealthRecord example(
        HealthMetric metric,
        Map<String, num> values,
        String unit,
      ) => HealthRecord(
        id: 'visual-${metric.name}',
        metric: metric,
        values: values,
        unit: unit,
        measuredAt: DateTime(2026, 9, 6, 9),
        timezone: '+08:00',
        deviceId: 'layout',
        firmwareVersion: '',
        quality: 'example',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      );
      final pages = <String, Widget>{
        'home': Scaffold(body: DashboardPage(controller: controller)),
        'devices': Scaffold(body: DevicePage(controller: controller)),
        'my': Scaffold(body: SettingsPage(controller: controller)),
        'home-cards': HomeHealthCardsPage(controller: controller),
        'sleep': SleepOverviewPage(controller: controller),
        'health-profile': HealthProfilePage(controller: controller),
        'symptoms': HealthReminderSymptomsPage(controller: controller),
        'urgent-help': const EmergencyHelpPage(),
        'cycle': CycleTrackingPage(controller: controller),
        'goals': GoalSettingsPage(controller: controller),
        'security': SecurityCenterPage(controller: controller),
        'search': DeviceSearchPage(controller: controller),
        'device-info': DeviceInfoPage(controller: controller),
        'firmware': DeviceFirmwarePage(controller: controller),
        'login-main': GlobalCodeLoginPage(controller: auth),
        'login-create': GlobalAuthPage(controller: auth, createAccount: true),
        'login-reset': GlobalAuthPage(controller: auth, resetPassword: true),
        'review-demo': ReviewDemoPage(onExit: () {}),
        'library': GlobalArticleLibraryPage(controller: controller),
        'articles-list': ArticleListPage(controller: controller),
        'article-detail': ArticleDetailPage(
          controller: controller,
          article: const {'title': '如何阅读戒指记录', 'content': '在健康首页可按日期查看自己的记录。'},
        ),
        'care-current': GlobalCarePage(controller: controller),
        'care-ai': Scaffold(body: AiPage(controller: controller)),
        'sport': Scaffold(body: SportOverviewPage(controller: controller)),
        'sport-modes': SportModeSelectionPage(controller: controller),
        'sport-sample': SportRecordDetailPage(
          controller: controller,
          record: SportRecord(
            id: 'fixture',
            mode: SportMode.values.first,
            startedAt: DateTime(2026, 9, 1, 12),
            durationSeconds: 600,
            distanceKm: 0.5,
            calories: 20,
            steps: 600,
          ),
        ),
        'shop-current': GlobalShopHomePage(controller: controller),
        'product-current': GlobalShopProductPage(
          controller: controller,
          productId: 'fixture',
        ),
        'shop-my': GlobalShopAccountPage(
          controller: controller,
          openProduct: (_, _) {},
        ),
        'shop-help': const GlobalShopHelpPage(),
        'shop-coupons': GlobalShopCouponsPage(controller: controller),
        'shop-points': GlobalShopPointsPage(controller: controller),
        'shop-favorites': GlobalShopFavoritesPage(
          controller: controller,
          openProduct: (_, _) {},
        ),
        'orders-current': GlobalShopOrdersPage(
          controller: controller,
          openProduct: (_, _) {},
        ),
        'logistics-current': GlobalShopLogisticsPage(
          controller: controller,
          orderId: 'fixture',
        ),
        'cart-current': GlobalShopCartPage(controller: controller),
        'addresses-current': GlobalShopAddressesPage(controller: controller),
        'address-edit-current': GlobalShopAddressEditPage(
          controller: controller,
          capabilities: GlobalCommerceCapabilities.unavailable,
        ),
        'checkout-current': GlobalShopCheckoutPage(
          controller: controller,
          items: const [],
          capabilities: GlobalCommerceCapabilities.unavailable,
        ),
        'order-detail-current': GlobalShopOrderDetailPage(
          controller: controller,
          orderId: 'fixture',
          openProduct: (_, _) {},
          capabilities: GlobalCommerceCapabilities.unavailable,
        ),
        'after-sale-current': GlobalShopAfterSalePage(
          controller: controller,
          orderId: 'fixture',
          eligibleItems: const [],
          orderItems: const [],
          capabilities: GlobalCommerceCapabilities.unavailable,
        ),
        'payment-current': GlobalShopPaymentPage(
          controller: controller,
          orderId: 'fixture',
        ),
        'legacy-login': LoginPage(controller: controller),
        'health-permissions': PermissionManagementPage(
          controller: controller,
          healthOnly: true,
        ),
        'monitoring': DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.healthMonitoring,
        ),
        'gestures': DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.gestureControl,
        ),
        'alarm-settings': DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.alarms,
        ),
        'address-account': AddressPage(controller: controller),
        'health-legacy': Scaffold(body: HealthPage(controller: controller)),
        'health-calibration': HealthCalibrationPage(
          controller: controller,
          metric: HealthMetric.bloodPressure,
        ),
        'health-record-detail': HealthRecordDetailPage(
          controller: controller,
          record: example(HealthMetric.heartRate, {'value': 72}, 'bpm'),
          readOnly: true,
        ),
        'reminders-center': HealthReminderCenterPage(controller: controller),
        'reminder-detail': HealthReminderDetailPage(
          controller: controller,
          eventId: 'visual',
        ),
        'report-detail': HealthReportDetailPage(
          controller: controller,
          report: HealthReportSummary.fromMap({
            'id': 'visual',
            'status': 'ready',
          }),
        ),
        'trend-steps': HealthTrendPage(
          controller: controller,
          metric: HealthMetric.steps,
        ),
        'message-detail': NotificationDetailPage(
          controller: controller,
          id: 1,
          initial: const {
            '_localNotification': true,
            'title': '版式示例',
            'content': '这是一条示例消息。',
          },
        ),
        'camera-unconnected': QRingCameraPage(controller: controller),
        'payment-status': shop.ShopPaymentStatusPage(
          controller: controller,
          orderId: 1,
        ),
        'sleep-report': SleepAiReportPage(
          controller: controller,
          record: example(HealthMetric.sleep, {'durationMinutes': 360}, 'min'),
        ),
        'sport-prepare': SportSessionPage(
          controller: controller,
          mode: SportMode.values.first,
        ),
        'wellness-unavailable': const WellnessReleaseUnavailablePage(),
        'privacy-document': GlobalLegalPage(
          controller: auth,
          document: GlobalLegalDocumentType.privacyPolicy,
        ),
        'wechat-phone': GlobalWechatPhoneBindingPage(
          controller: auth,
          binding: const GlobalWechatPhoneBinding(
            ticket: 'visual',
            expiresIn: 60,
            profileProof: 'visual',
          ),
          capabilities: await _OfflineLoginApi().getAuthCapabilities(),
          consentVersion: 'visual',
          locale: 'zh',
          ageConfirmed: false,
        ),
        'account': AccountSettingsPage(controller: controller),
        'profile': ProfileEditPage(controller: controller),
        'units': UnitSettingsPage(controller: controller),
        'about': AboutSaydianPage(controller: controller),
        'contact': const CustomerServicePage(),
        'help': FeedbackPage(controller: controller),
        'permissions': PermissionManagementPage(controller: controller),
        'care': CarePage(controller: controller),
        'care-invitations': CareInvitationsPage(controller: controller),
        'care-sharing': SharingManagementPage(controller: controller),
        'care-member': CareMemberPage(
          controller: controller,
          careId: 7,
          member: const {'nickname': '关爱成员', 'to_member_id': 8},
        ),
        'care-settings': CareShareSettingsPage(
          controller: controller,
          memberId: 8,
          member: const {'nickname': '关爱成员'},
        ),
        'care-metric': CareMetricDetailPage(
          item: const {'title': '心率', 'records': [], 'state': 'empty'},
          day: DateTime(2026, 9, 6),
        ),
        'addresses': shop.ShopAddressBookPage(controller: controller),
        'address-edit': shop.ShopAddressEditPage(controller: controller),
        'messages': NotificationsPage(controller: controller),
        'health-alerts': HealthWarningPage(controller: controller),
        'health-all': AllHealthDataPage(controller: controller),
        'heart': HealthHistoryPage(
          controller: controller,
          metric: HealthMetric.heartRate,
        ),
        'ecg': HealthHistoryPage(
          controller: controller,
          metric: HealthMetric.ecg,
        ),
        'sport-records': SportRecordsPage(controller: controller),
        'orders': OrdersPage(controller: controller, initialStatus: null),
        'shop': shop.ShopHomePage(controller: controller),
        'shop-product': shop.ShopProductPage(
          controller: controller,
          productId: 1,
        ),
        'shop-cart': shop.ShoppingCartPage(controller: controller),
        'shop-checkout': shop.ShopCheckoutPage(
          controller: controller,
          items: const [
            {
              'sku_id': 11,
              'quantity': 1,
              'product_name': '版式验证商品',
              'price': '100.00',
            },
          ],
        ),
        'order-detail': OrderDetailPage(controller: controller, id: 1),
        'order-express': shop.ShopExpressPage(
          controller: controller,
          orderId: 1,
        ),
        'after-sales': AfterSalesPage(
          controller: controller,
          order: const {
            'id': 1,
            'order_sn': 'REFERENCE-ONLY',
            'order_status': 1,
            'product': [
              {
                'id': 11,
                'product_name': '版式验证商品',
                'sku_name': '默认规格',
                'product_money': '100.00',
                'num': 1,
              },
            ],
          },
        ),
        'ai-chat': AiChatPage(controller: controller, app: 1),
        'articles': ArticleCategoryPage(controller: controller),
        'registration': RegistrationPage(controller: controller),
        'password': PasswordRecoveryPage(controller: controller),
        'watchfaces': DeviceFeaturePage(
          controller: controller,
          feature: DeviceFeature.watchFaces,
        ),
      };
      // 从真实入口进入这些二级页；仅点击查看，不接受协议或提交售后。
      pages.addAll({
        'connection-help': pages['devices']!,
        'about-privacy': pages['about']!,
        'after-sale-form': pages['after-sales']!,
        'demo-device': pages['review-demo']!,
        'demo-profile': pages['review-demo']!,
        'article-image': ArticleReader(
          controller: controller,
          title: '图片示例',
          contentHtml:
              '<p>图片阅读</p><img src="/global/media/qa-fixture/illustration.png" alt="示例配图" />',
          publishedDate: '',
        ),
        'display-market-disconnected': DeviceWatchFaceMarketPage(
          controller: controller,
          profile: const DeviceWatchFaceMarketProfile(
            provider: 'fixture',
            deviceId: 'not-connected',
            deviceLabel: 'fixture',
            dialShape: 1,
            binProtocol: 1,
            maxFileLength: 2000,
            deviceNumber: 1,
            firmwareVersion: 'example',
            screenWidth: 128,
            screenHeight: 128,
            slotCount: 1,
            profileFingerprint: 'fixture',
          ),
        ),
        'ecg-detail': HealthRecordDetailPage(
          controller: controller,
          record: example(HealthMetric.ecg, {'heartRate': 72}, 'bpm'),
          readOnly: true,
        ),
      });
      // 不为截图越过当前发行范围；无心电能力时只核对真实的不可用页。
      if (controller.isMetricAvailableInRelease(HealthMetric.ecg)) {
        pages['ecg-report'] = pages['ecg-detail']!;
      }
      const nestedActions = {
        'connection-help': '连接说明',
        'home-explanation': '健康数据说明',
        'about-privacy': '隐私政策',
        'article-image': '查看大图',
        'after-sale-form': '申请售后',
        'demo-device': '设备',
        'demo-profile': '我的',
        'ecg-report': '查看完整报告',
      };
      // 补充已启用的合成状态，避免把未登录/无能力截图当作完整功能验收。
      final reminders = LayoutController();
      addTearDown(reminders.dispose);
      final cycle = cycle_fixture.Controller();
      addTearDown(cycle.dispose);
      await tester.runAsync(() async {
        await cycle.cycles.load();
        await cycle.cycles.saveSettings(
          const CycleSettings(
            enabled: true,
            adultConfirmed: true,
            purposeAccepted: true,
            recordOnly: true,
          ),
        );
        await cycle.cycles.save(
          CycleEntry(
            id: 'copy-fixture-period',
            kind: 'period',
            data: {'start': shiftCycleDate(cycle.cycles.today, -2)},
          ),
        );
      });
      pages.addAll({
        'home-explanation': pages['home']!,
        'reminders-ready': HealthReminderCenterPage(controller: reminders),
        'cycle-recorded': CycleTrackingPage(controller: cycle),
      });
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        permissions,
        (call) async => call.method == 'requestPermissions' ? <int, int>{} : 0,
      );
      final layoutFailures = <String>[];
      for (final page in pages.entries) {
        if (pageFilter.isNotEmpty && page.key != pageFilter) continue;
        final previousDevice = controller.connectedDevice;
        final previousFeatures = controller.capabilities;
        if (page.key == 'watchfaces') {
          // Explicit offline installed-dial fixture, no live transport or pictures.
          controller.connectedDevice = const DeviceInfo(
            id: 'visual-watch',
            name: 'SD-WATCH-W9S',
          );
          controller.capabilities = const DeviceCapabilities(
            metrics: {},
            features: {DeviceFeature.watchFaces},
            integratedFeatures: {DeviceFeature.watchFaces},
          );
        }
        final key = GlobalKey();
        final theme = buildSaydianTheme();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(double.parse(fontScale)),
                ),
                child: child!,
              ),
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamily: 'Reference Chinese',
                ),
              ),
              initialRoute: '/reference',
              routes: {
                '/': (_) => const SizedBox.shrink(),
                '/reference': (_) => page.key == 'care'
                    ? Scaffold(
                        appBar: AppBar(title: const Text('远程关爱')),
                        body: page.value,
                      )
                    : page.value,
              },
            ),
          ),
        );
        await tester.pump();
        if (page.key == 'address-edit' ||
            (page.key == 'shop-product' && publicImages)) {
          await tester.runAsync(
            () => Future<void>.delayed(
              Duration(milliseconds: publicImages ? 1200 : 250),
            ),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(seconds: 1));
        final caption = nestedActions[page.key];
        if (caption != null) {
          final link = find.text(caption);
          if (link.evaluate().isEmpty &&
              find.byType(Scrollable).evaluate().isNotEmpty) {
            final scroll = find.byType(Scrollable).first;
            for (var i = 0; i < 8 && link.evaluate().isEmpty; i++) {
              await tester.drag(scroll, const Offset(0, -480));
              await tester.pump(const Duration(milliseconds: 100));
            }
          }
          if (link.evaluate().isNotEmpty) {
            await tester.ensureVisible(link.last);
            await tester.tap(link.last);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            if (page.key == 'article-image') {
              expect(
                find.byKey(const Key('article-image-viewer')),
                findsOneWidget,
              );
            }
          } else {
            layoutFailures.add('${page.key}: navigation not available');
          }
        }
        final layoutError = tester.takeException();
        if (layoutError != null) {
          layoutFailures.add('${page.key}: $layoutError');
        }
        // Widget tests force unthemed text to Ahem. Change only the capture's
        // render font fallback; keep every production weight/size/line height.
        for (final element in find.byType(RichText).evaluate()) {
          final paragraph = element.renderObject;
          if (paragraph is RenderParagraph) {
            paragraph.text = _captureFont(paragraph.text);
          }
        }
        await tester.pump();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        if (captureImages) {
          await tester.runAsync(() async {
            final screenshot = await boundary.toImage(
              pixelRatio: double.parse(ratio),
            );
            final data = await screenshot.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$output/${page.key}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            screenshot.dispose();
          });
        }
        if (interactions && page.key == 'shop-product') {
          // Open the existing selector only; never confirm purchase or create an order.
          await tester.tap(find.text('立即购买').last);
          await tester.pump(const Duration(milliseconds: 500));
          final error = tester.takeException();
          if (error != null) {
            layoutFailures.add('shop-product-selector: $error');
          }
          expect(find.text('请选择规格'), findsOneWidget);
        }
        if (interactions && page.key == 'ai-chat') {
          tester.view.viewInsets = const FakeViewPadding(bottom: 220);
          await tester.tap(find.byKey(const Key('ai-message-input')));
          await tester.enterText(
            find.byKey(const Key('ai-message-input')),
            '版式验证\n仅输入，不发送\n第三行\n第四行',
          );
          await tester.pump();
          final error = tester.takeException();
          if (error != null) layoutFailures.add('ai-chat-keyboard: $error');
          expect(find.byIcon(Icons.send_rounded).hitTestable(), findsOneWidget);
          tester.view.resetViewInsets();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        // 仅此关卡使用带屏设备，避免下一页误用上一页的戒指身份。
        if (page.key == 'watchfaces') {
          controller.connectedDevice = previousDevice;
          controller.capabilities = previousFeatures;
        }
      }
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        permissions,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
      expect(layoutFailures, isEmpty, reason: layoutFailures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

InlineSpan _captureFont(InlineSpan span) {
  if (span is! TextSpan) return span;
  final icon =
      span.style?.fontFamily == 'MaterialIcons' ||
      (span.style?.fontFamily?.contains('CupertinoIcons') ?? false);
  return TextSpan(
    text: span.text,
    style: icon
        ? span.style
        : (span.style ?? const TextStyle()).copyWith(
            fontFamily: 'Reference Chinese',
          ),
    children: span.children?.map(_captureFont).toList(),
  );
}

class _OfflineWatch extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
  @override
  Future<List<SportRecord>> readSportRecords() async => [];
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      {
        'onlineMarketSupported': false,
        'items': List.generate(
          9,
          (index) => {
            'id': index,
            'name': '表盘 ${index + 1}',
            'isCurrent': index == 2,
            'status': '已安装',
          },
        ),
      };
}

class _OfflineApi extends Fake
    implements
        SaydianApi,
        SaydianArticleApi,
        SaydianShopApi,
        SaydianShopCartApi,
        GlobalContentApi,
        GlobalCommerceApi {
  @override
  Future<List<Map<String, Object?>>> getGlobalArticleCategories() async => [];
  @override
  Future<List<Map<String, Object?>>> getGlobalArticles({
    String? categoryId,
    int page = 1,
  }) async => [];
  @override
  Future<Map<String, Object?>> getGlobalArticle(String id) async => {};
  @override
  Future<Map<String, Object?>> getGlobalCommerceCapabilities() async => {
    'maintenance': {'readOnly': true},
  };
  @override
  Future<Map<String, Object?>> getGlobalShopProducts({
    String? keyword,
    String? categoryId,
    int page = 1,
  }) async => {'items': []};
  @override
  Future<Map<String, Object?>> getGlobalShopProduct(String id) async => {
    'id': id,
    'name': '版式验证商品',
    'skus': [],
  };
  @override
  Future<Map<String, Object?>> getGlobalShopCart() async => {'items': []};
  @override
  Future<List<Map<String, Object?>>> getGlobalShopAddresses() async => [];
  @override
  Future<Map<String, Object?>> getGlobalShopOrder(String id) async => {
    'id': id,
    'orderNo': 'REFERENCE-ONLY',
    'readOnly': true,
    'status': 'COMPLETED',
    'items': [],
  };
  @override
  Future<List<Map<String, Object?>>> getGlobalShopOrderLogistics(
    String id,
  ) async => [];
  @override
  Future<List<Map<String, Object?>>> getGlobalShopOrders({
    String? status,
    String? group,
  }) async => [];
  @override
  Future<Map<String, Object?>> getGlobalShopAvailableCoupons({
    int page = 1,
  }) async => {'items': []};
  @override
  Future<List<Map<String, Object?>>> getGlobalShopFavorites() async => [];
  @override
  Future<List<Map<String, Object?>>> getGlobalShopCoupons() async => [];
  @override
  Future<Map<String, Object?>> getGlobalShopPoints({int page = 1}) async => {
    'items': [],
  };

  @override
  Future<Map<String, Object?>> getShopProduct(int id) async {
    const source = String.fromEnvironment('IOS_REFERENCE_PRODUCT');
    if (source.isNotEmpty) {
      return (jsonDecode(File(source).readAsStringSync())
              as Map<String, dynamic>)['data']
          as Map<String, dynamic>;
    }
    return {
      'id': 1,
      'name': '版式验证商品',
      'price': '100.00',
      'sales': 0,
      'sku': [
        {'id': 11, 'name': '默认规格', 'price': '100.00', 'stock': 2},
      ],
      'intro': '仅用于离线界面核对',
    };
  }

  @override
  Future<List<Map<String, Object?>>> getShopCartItems() async => [];
  @override
  Future<Map<String, Object?>> previewShopOrder({
    required List<Map<String, int>> items,
  }) async => {
    'preview': {'product_money': '100.00', 'shipping_money': '0.00'},
    'account': {'money1': '0.00'},
    'products': [
      {
        'product_name': '版式验证商品',
        'sku_name': '默认规格',
        'product_money': '100.00',
        'num': 1,
      },
    ],
  };
  @override
  Future<Map<String, Object?>> getOrderDetail(int id) async => {
    'id': 1,
    'order_sn': 'REFERENCE-ONLY',
    'order_status': 0,
    'order_money': '100.00',
    'pay_money': '100.00',
    'created_at': '2026-09-06 00:00',
    'product': [
      {
        'id': 11,
        'product_name': '版式验证商品',
        'sku_name': '默认规格',
        'product_money': '100.00',
        'num': 1,
      },
    ],
  };
  @override
  Future<List<Map<String, Object?>>> getOrderExpress(int orderId) async => [];
  @override
  Future<Map<String, Object?>> getShopHome() async => {
    'items': [
      {
        'type': 'tabs',
        'value': [
          {
            'id': 1,
            'name': '合成分类',
            'list': [
              {'id': 1, 'name': '合成商品（仅供版式验证）', 'price': '100.00', 'stock': 1},
              {'id': 2, 'name': '合成商品二', 'price': '200.00', 'stock': 1},
            ],
          },
          {'id': 2, 'name': '第二分类', 'list': <Object>[]},
        ],
      },
    ],
  };
  @override
  Future<Map<String, Object?>> getCareMemberPreview({
    required int id,
    required String day,
    int? memberId,
  }) async => {};
  @override
  Future<List<Map<String, Object?>>> getArticleCategories({
    int parentId = 3,
  }) async => [];
  @override
  Future<List<Map<String, Object?>>> getArticlesByCategory({
    int? categoryId,
    int page = 1,
  }) async => [];
  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => [];
  @override
  Future<Map<String, Object?>> getMemberProfile() async => {};
  @override
  Future<Map<String, Object?>> getSingleArticle(int id) async => {};
  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      [];
  @override
  Future<List<Map<String, Object?>>> getAiMessages({
    required int app,
    int page = 1,
  }) async => [];
  @override
  Future<List<Map<String, Object?>>> getOrders({int? status}) async => [];
  @override
  Future<List<Map<String, Object?>>> getAddresses() async => [];
}

class _OfflineLoginApi extends _OfflineApi implements GlobalAccountApi {
  @override
  Future<GlobalAuthCapabilities> getAuthCapabilities() async =>
      const GlobalAuthCapabilities(
        email: true,
        sms: true,
        smsCountries: {'CN'},
        supportedLocales: ['zh'],
        loginSms: true,
        loginEmail: true,
        recoveryEmail: true,
        recoverySms: true,
        consentVersion: 'fixture',
      );
}
