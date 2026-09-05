// Opt-in visual reference capture. Renders unchanged production Flutter pages
// with empty, offline fixtures; never connects to an account, watch or payment.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart' hide AfterSalesPage;
import 'package:saydian_app/ui/shop_pages.dart' as shop;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const output = String.fromEnvironment('IOS_REFERENCE_OUTPUT');
  testWidgets(
    'capture iOS inner-page references without production writes',
    (tester) async {
      if (output.isEmpty) return;
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
              displayName: '赛电用户',
            );
      addTearDown(controller.dispose);
      final pages = <String, Widget>{
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
      };
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        permissions,
        (call) async => call.method == 'requestPermissions' ? <int, int>{} : 0,
      );
      for (final page in pages.entries) {
        final key = GlobalKey();
        final theme = buildSaydianTheme();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
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
        expect(tester.takeException(), isNull, reason: page.key);
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
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        permissions,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
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
}

class _OfflineApi extends Fake
    implements
        SaydianApi,
        SaydianArticleApi,
        SaydianShopApi,
        SaydianShopCartApi {
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
