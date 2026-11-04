import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/cycle_tracking.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/cycle_tracking_service.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/cycle_tracking_page.dart';
import 'package:saydian_app/ui/app_theme.dart';

class Api extends Fake implements SaydianApi {}

class Bridge extends Fake implements WearableBridge {}

class Notice extends CycleNotifications {
  @override
  Future<void> owner(String? o) async {}
  @override
  Future<bool> schedule(
    String o,
    List<Map<String, Object?>> p, {
    bool request = false,
  }) async => false;
}

class Controller extends AppController {
  Controller()
    : super(
        MemorySessionVault(),
        Api(),
        MemoryHealthStore(),
        Bridge(),
        cycleNotifications: Notice(),
      ) {
    session = Session(
      accessToken: 'synthetic',
      refreshToken: '',
      expiresAt: DateTime.utc(2099),
      memberId: 'synthetic-a',
      accountKey: 'synthetic-a',
      displayName: 'Test',
    );
    cycles.setOwner('test-owner');
  }
  @override
  Future<void> loadCycleHealth() async {}
}

Widget host(AppController c, double scale) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildSaydianTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: CycleTrackingPage(controller: c),
);
void main() {
  testWidgets(
    'first enable explains cloud use and requires deliberate adult/purpose confirmation',
    (t) async {
      final c = Controller();
      addTearDown(c.dispose);
      await t.pumpWidget(host(c, 1));
      await t.pumpAndSettle();
      expect(find.text('记录周期，提前准备'), findsOneWidget);
      await t.tap(find.byKey(const Key('cycle-enable')));
      await t.pumpAndSettle();
      expect(find.textContaining('随当前账号自动同步'), findsOneWidget);
      expect(c.cycles.settings.enabled, false);
      await t.tap(find.text('保存'));
      await t.pumpAndSettle();
      expect(c.cycles.settings.enabled, false);
      expect(find.text('请先确认成年和数据用途'), findsOneWidget);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'cycle page without ring at $scale text scale shows calendar and never fabricates data',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final c = Controller();
        addTearDown(c.dispose);
        await t.runAsync(() async {
          await c.cycles.load();
          await c.cycles.saveSettings(
            const CycleSettings(
              enabled: true,
              adultConfirmed: true,
              purposeAccepted: true,
              historyComplete: true,
            ),
          );
        });
        await t.pumpWidget(host(c, scale));
        await t.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await t.pumpAndSettle();
        expect(find.byKey(const Key('cycle-record-start')), findsOneWidget);
        expect(find.text('积累中'), findsOneWidget);
        expect(find.text('已结合戒指数据'), findsNothing);
        expect(find.text('已排卵'), findsNothing);
        expect(t.takeException(), isNull);
        await t.drag(find.byType(ListView).first, const Offset(0, -600));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'ongoing cycle uses one primary end action and compact visual overview at $scale',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final c = Controller();
        addTearDown(c.dispose);
        await t.runAsync(() async {
          await c.cycles.load();
          await c.cycles.saveSettings(
            const CycleSettings(
              enabled: true,
              adultConfirmed: true,
              purposeAccepted: true,
              recordOnly: true,
            ),
          );
          await c.cycles.save(
            CycleEntry(
              id: 'ongoing',
              kind: 'period',
              data: {
                'start': cycleDate(
                  DateTime.now().subtract(const Duration(days: 3)),
                ),
              },
            ),
          );
        });
        await t.pumpWidget(host(c, scale));
        await t.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await t.pumpAndSettle();
        expect(find.byKey(const Key('cycle-record-end')), findsOneWidget);
        expect(find.byKey(const Key('cycle-record-start')), findsNothing);
        expect(find.text('补记'), findsOneWidget);
        expect(find.text('经期进行中'), findsOneWidget);
        if (scale == 1.0) {
          expect(
            t.getSize(find.byKey(const Key('cycle-overview'))).height,
            lessThan(230),
          );
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}
