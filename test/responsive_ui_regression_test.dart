import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/shop_pages.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('product and selector remain readable at $width and 200% text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _largeText(ShopProductPage(controller: controller, productId: 1)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FittedBox), findsNothing);
      expect(find.text('立即购买').hitTestable(), findsOneWidget);
      expect(find.text('首页').hitTestable(), findsOneWidget);
      expect(find.text('客服').hitTestable(), findsOneWidget);
      await tester.tap(find.text('立即购买'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('请选择规格'), findsOneWidget);
      // Deliberately do not confirm the selector: no order or payment is created.
    });

    testWidgets(
      'AI empty state and multiline keyboard remain usable at $width and 200% text',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final controller = _controller();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _largeText(AiChatPage(controller: controller, app: 1)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsWidgets);
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        await tester.tap(find.byKey(const Key('ai-message-input')));
        await tester.enterText(
          find.byKey(const Key('ai-message-input')),
          '离线验证\n不发送\n第三行\n第四行',
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.send_rounded).hitTestable(), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('ai-message-input')))
              .controller!
              .text,
          contains('第四行'),
        );
      },
    );
  }
}

Widget _largeText(Widget page) => MaterialApp(
  theme: buildSaydianTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2)),
    child: child!,
  ),
  home: page,
);

AppController _controller() => AppController(
  MemorySessionVault(),
  _PageApi(),
  MemoryHealthStore(),
  _PageWatch(),
);

class _PageApi extends Fake implements SaydianApi, SaydianShopApi {
  @override
  Future<Map<String, Object?>> getShopProduct(int id) async => {
    'id': id,
    'name': '离线版式验证商品',
    'price': '100.00',
    'sales': 0,
    'sku': [
      {'id': 11, 'name': '默认规格', 'price': '100.00', 'stock': 2},
    ],
    'intro': '仅供界面回归',
  };
}

class _PageWatch extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}
