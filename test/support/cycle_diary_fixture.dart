import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
