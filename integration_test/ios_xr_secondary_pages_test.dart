import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/ui/global_shop_account_pages.dart';
import 'package:saydian_app/services/article_reading_preferences.dart';
import 'package:saydian_app/ui/global_code_login_page.dart';
import 'package:saydian_app/ui/pages.dart';

import 'ios_profile_api_diagnostic_test.dart' as profile;

// Real owner and the ring selected in the authorized first round only.
// No mock data, account switch, unbind, reset, payment, OTP or AI upload.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  profile.main();
  testWidgets(
    'XR secondary pages with existing real connection',
    (tester) async {
      final app = AppController.production();
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      await app.refreshReadOnlyHealthFeatures().timeout(
        const Duration(seconds: 45),
      );
      await app.refreshModuleVisibility().timeout(const Duration(seconds: 45));
      final owner = app.session?.accountKey;
      final target = app.rememberedDevice?.id;
      expect(owner, isNotNull);
      expect(target, isNotNull);
      final visited = <String>[];
      final unavailable = <String>[];
      final proof = <String, Object?>{};
      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/xr-secondary-20261025',
      );
      await dir.create(recursive: true);
      Future<void> settle() async {
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await tester.pump().timeout(const Duration(seconds: 15));
        }
      }

      Future<void> checkpoint() async {
        final result = {
          'visited': visited,
          'unavailable': unavailable,
          ...proof,
        };
        binding.reportData = {...?binding.reportData, 'secondary': result};
        await File('${dir.path}/proof.json').writeAsString(jsonEncode(result));
      }

      Future<void> record(String label) async {
        expect(tester.takeException(), isNull, reason: label);
        visited.add(label);
        await checkpoint();
        final bytes = await binding.takeScreenshot(
          'xr-secondary-${visited.length}',
        );
        await File(
          '${dir.path}/page-${visited.length}.png',
        ).writeAsBytes(bytes);
        // Labels only; health values, account identifiers and screenshots stay private.
        // ignore: avoid_print
        print('XR secondary visited: $label');
      }

      Future<void> pop() async {
        await tester.binding.handlePopRoute();
        await settle();
      }

      Future<void> home() async {
        app.selectTab(0);
        await settle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await settle();
      }

      Future<void> tapVisible(Finder finder) async {
        if (finder.hitTestable().evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            220,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await Scrollable.ensureVisible(
          tester.element(finder.last),
          alignment: .5,
        );
        await settle();
        await tester.tap(finder.last.hitTestable());
        await settle();
      }

      await settle();
      await home();
      await tapVisible(find.widgetWithText(TextButton, '目标'));
      expect(find.byType(GoalSettingsPage), findsOneWidget);
      await record('活动目标（只读）');
      await pop();
      for (final metric in [
        HealthMetric.steps,
        HealthMetric.distance,
        HealthMetric.calories,
      ]) {
        await home();
        final panel = find.byKey(const Key('dashboard-today-health'));
        final title = find.descendant(
          of: panel,
          matching: find.text(metric.label),
        );
        await tapVisible(title);
        expect(
          find.byKey(Key('health-trend-${metric.wireName}')),
          findsOneWidget,
        );
        for (final period in ['周', '月', '日']) {
          await tapVisible(find.text(period));
        }
        await record('${metric.label}日周月趋势');
        await pop();
      }
      await home();
      await tapVisible(find.byKey(const Key('home-sleep-overview-entry')));
      expect(find.byKey(const Key('sleep-overview-page')), findsOneWidget);
      await tapVisible(find.byKey(const Key('sleep-previous-day')));
      await tapVisible(find.byKey(const Key('sleep-next-day')));
      await record('睡眠前后日期切换');
      await pop();

      await home();
      await tapVisible(find.text('健康百科'));
      for (
        var i = 0;
        i < 15 && find.byType(ArticleTile).evaluate().isEmpty;
        i++
      ) {
        await settle();
      }
      proof['healthLibraryVisible'] = app.healthLibraryVisible;
      if (find.byType(ArticleTile).evaluate().isNotEmpty) {
        await tapVisible(find.byType(ArticleTile).first);
        for (
          var i = 0;
          i < 15 && find.byKey(const Key('article-reader')).evaluate().isEmpty;
          i++
        ) {
          await settle();
        }
        expect(find.byKey(const Key('article-reader')), findsOneWidget);
        await record('百科文章详情');
        final preferences = ArticleReadingPreferences.instance;
        await preferences.load();
        final original = preferences.size;
        try {
          await tapVisible(find.byKey(const Key('article-font-size')));
          await tapVisible(find.byKey(const Key('article-size-extraLarge')));
          expect(preferences.size, ArticleTextSize.extraLarge);
          await record('百科特大字号');
          await tapVisible(find.byKey(const Key('article-font-size')));
          await tapVisible(find.byKey(Key('article-size-${original.name}')));
          expect(preferences.size, original);
        } finally {
          if (preferences.size != original) await preferences.select(original);
        }
        await pop();
      } else {
        unavailable.add('百科文章详情（未返回可打开文章）');
      }
      await pop();

      app.selectTab(1);
      await settle();
      for (final label in ['关于设备', '连接说明']) {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await settle();
        await tapVisible(find.text(label));
        await record(label);
        await pop();
      }
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => DeviceSearchPage(controller: app)),
      );
      await settle();
      await tapVisible(find.byKey(const Key('device-search-help')));
      expect(
        find.byKey(const Key('device-search-help-dialog')),
        findsOneWidget,
      );
      await record('添加设备搜索帮助');
      await tapVisible(find.byKey(const Key('device-search-help-close')));
      await pop();

      navigator.push<void>(
        MaterialPageRoute(builder: (_) => GlobalCodeLoginPage(controller: app)),
      );
      await settle();
      await tapVisible(find.widgetWithText(ChoiceChip, '邮箱'));
      expect(find.byKey(const Key('code-login-password')), findsOneWidget);
      await tapVisible(find.byKey(const Key('code-login-mode')));
      expect(find.byKey(const Key('code-login-code')), findsOneWidget);
      await tapVisible(find.byKey(const Key('code-login-mode')));
      expect(find.byKey(const Key('code-login-password')), findsOneWidget);
      await record('邮箱密码和验证码入口');
      await pop();
      proof['commerceEnabled'] = app.commerceEnabled;
      if (app.commerceEnabled && app.isGlobalEdition) {
        await home();
        final l = AppLocalizations.of(
          tester.element(find.byType(NavigationBar)),
        )!;
        await tapVisible(find.text(l.shop));
        expect(find.byKey(const Key('global-shop-page')), findsOneWidget);
        await record('商城首页');
        await tapVisible(find.byKey(const Key('global-shop-cart-action')));
        expect(find.byKey(const Key('global-shop-cart-page')), findsOneWidget);
        await record('购物车（不改商品、不结算）');
        await pop();
        await tapVisible(find.byKey(const Key('global-shop-account-action')));
        expect(
          find.byKey(const Key('global-shop-account-page')),
          findsOneWidget,
        );
        await record('商城账户');
        for (final entry in [
          (l.myOrders, 'global-shop-orders-page'),
          (l.deliveryAddresses, 'global-shop-addresses-page'),
          (l.favorites, 'global-shop-favorites-page'),
          (l.coupons, 'global-shop-coupons-page'),
          (l.points, 'global-shop-points-page'),
        ]) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await settle();
          await tapVisible(find.text(entry.$1));
          expect(find.byKey(Key(entry.$2)), findsOneWidget);
          await record('${entry.$1}（只读）');
          await pop();
        }
        await tapVisible(find.text(l.helpCenter));
        expect(find.byType(GlobalShopHelpPage), findsOneWidget);
        await record('商城帮助中心');
        await pop();
        await pop();
        await pop();
      }

      proof['ownerUnchanged'] = app.session?.accountKey == owner;
      proof['targetUnchanged'] = app.rememberedDevice?.id == target;
      if (!app.commerceEnabled) unavailable.add('商城（公开配置未开放）');
      await home();
      await app.refreshConnectedDeviceDetails().timeout(
        const Duration(seconds: 25),
      );
      await settle();
      proof['connectedAtEnd'] = app.connectedDevice?.id == target;
      proof['batteryRead'] = app.connectedDevice?.battery?.updatedAt != null;
      proof['syncIdle'] = !app.isDeviceSyncing;
      await checkpoint();
      expect(proof['ownerUnchanged'], isTrue);
      expect(proof['targetUnchanged'], isTrue);
      expect(proof['connectedAtEnd'], isTrue);
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
