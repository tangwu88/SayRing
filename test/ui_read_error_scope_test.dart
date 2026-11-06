import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/shop_pages.dart' as shop;

class _Api extends Fake implements SaydianApi, SaydianShopApi {
  final addresses = <Completer<List<Map<String, Object?>>>>[];
  @override
  Future<List<Map<String, Object?>>> getAddresses() {
    final reply = Completer<List<Map<String, Object?>>>();
    addresses.add(reply);
    return reply.future;
  }

  @override
  Future<Map<String, Object?>> getMemberProfile() async => {};
  @override
  Future<List<Map<String, Object?>>> getOrderExpress(int orderId) async => [];
}

class _Ring extends Fake implements WearableBridge {}

Session _owner(String name) => Session(
  accessToken: 'fixture',
  refreshToken: '',
  expiresAt: DateTime(2030),
  memberId: name,
  displayName: 'Fixture',
);
void main() {
  test(
    'late address requests cannot replace the next member or a newer refresh',
    () async {
      final api = _Api();
      final c =
          AppController(MemorySessionVault(), api, MemoryHealthStore(), _Ring())
            ..session = _owner('A')
            ..errorMessage = '示例蓝牙搜索错误';
      addTearDown(c.dispose);
      final a = c.loadAddresses();
      await Future<void>.delayed(Duration.zero);
      c.session = _owner('B');
      final b1 = c.loadAddresses();
      await Future<void>.delayed(Duration.zero);
      final b2 = c.loadAddresses();
      await Future<void>.delayed(Duration.zero);
      expect(api.addresses, hasLength(3));
      api.addresses.last.complete([
        {'id': 'new-B'},
      ]);
      await b2;
      api.addresses[0].complete([
        {'id': 'A'},
      ]);
      api.addresses[1].complete([
        {'id': 'old-B'},
      ]);
      await Future.wait([a, b1]);
      expect(c.addresses.single['id'], 'new-B');
      expect(c.addressLoadError, isNull);
      expect(c.errorMessage, '示例蓝牙搜索错误');
    },
  );
  testWidgets(
    'a failed Bluetooth search does not become a profile or delivery error',
    (tester) async {
      final c =
          AppController(
              MemorySessionVault(),
              _Api(),
              MemoryHealthStore(),
              _Ring(),
            )
            ..isBooting = false
            ..session = _owner('A')
            ..errorMessage = '示例蓝牙搜索错误';
      addTearDown(c.dispose);
      Future<void> open(Widget child) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: child,
          ),
        );
        await tester.pumpAndSettle();
      }

      await open(shop.ShopExpressPage(controller: c, orderId: 1));
      expect(find.text('暂无物流信息'), findsOneWidget);
      expect(find.text('示例蓝牙搜索错误'), findsNothing);
      await open(ProfileEditPage(controller: c));
      expect(find.textContaining('暂未读取到个人资料'), findsOneWidget);
      expect(find.text('示例蓝牙搜索错误'), findsNothing);
    },
  );
}
