import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';

const ring = DeviceInfo(id: 'coolwear:AA:BB:CC:DD:EE:FF', name: 'R7 Ultra');
SportRecord record({bool native = false}) => SportRecord(
  id: native ? 'cw-83467701-e96c-3add-a3b1-01cdde122da3' : 'local:fixture',
  mode: SportMode.walking,
  startedAt: DateTime.utc(2026, 11, 1, 8),
  durationSeconds: 120,
  steps: 90,
  distanceKm: .09,
  calories: 4,
);

class _Api extends Fake implements SaydianApi {}

class _Ring extends Fake implements WearableBridge {
  int reads = 0;
  Future<List<SportRecord>> Function() read = () async => [];
  @override
  Future<List<SportRecord>> readSportRecords() {
    reads++;
    return read();
  }
}

class _Store extends MemoryHealthStore {
  bool failRead = false;
  @override
  Future<List<SportRecord>> localSportRecords() {
    if (failRead) throw StateError('synthetic local read failure');
    return super.localSportRecords();
  }
}

Future<({AppController app, _Ring sdk, _Store store})> fixture({
  bool saved = true,
}) async {
  final store = _Store(), sdk = _Ring();
  if (saved) await store.saveSportRecord(record());
  final app = AppController(MemorySessionVault(), _Api(), store, sdk)
    ..connectedDevice = ring;
  addTearDown(app.dispose);
  return (app: app, sdk: sdk, store: store);
}

PlatformException timeout([List<SportRecord> rows = const []]) =>
    PlatformException(
      code: 'COOLWEAR_SYNC_TIMEOUT',
      details: rows.map((r) => r.toMap()).toList(),
    );
Widget host(AppController app, {double scale = 1}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: SportRecordsPage(controller: app),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'background timeout is incomplete, preserves records and unrelated global errors',
    () async {
      final f = await fixture();
      f.sdk.read = () async => throw timeout();
      f.app.errorMessage = 'another operation failed';
      await f.app.refreshSportRecords();
      expect(f.app.sportHistoryReadStatus, SportHistoryReadStatus.incomplete);
      expect(f.app.errorMessage, 'another operation failed');
      expect(f.app.sportRecords.single.id, record().id);
      expect((await f.store.localSportRecords()).single.id, record().id);
      f.sdk.read = () async => [];
      await f.app.refreshSportRecords();
      expect(f.sdk.reads, 2);
      expect(f.app.sportHistoryReadStatus, SportHistoryReadStatus.complete);
      expect(f.app.errorMessage, 'another operation failed');
    },
  );

  test(
    'a partial packet is durable without being relabelled complete',
    () async {
      final f = await fixture();
      f.sdk.read = () async => throw timeout([record(native: true)]);
      await f.app.refreshSportRecords();
      expect(f.app.errorMessage, isNull);
      expect(f.app.sportHistoryReadStatus, SportHistoryReadStatus.partial);
      expect(
        f.app.sportRecords.map((r) => r.id),
        containsAll([record().id, record(native: true).id]),
      );
      expect((await f.store.localSportRecords()).length, 2);
    },
  );

  test('SDK failure is local to history and keeps saved workouts', () async {
    final f = await fixture();
    f.sdk.read = () async =>
        throw PlatformException(code: 'COOLWEAR_SYNC_FAILED');
    await f.app.refreshSportRecords();
    expect(f.app.sportHistoryReadStatus, SportHistoryReadStatus.failed);
    expect(f.app.sportRecords.single.id, record().id);
    expect(f.app.errorMessage, isNull);
  });

  test(
    'a failed local read never clears the displayed records or claims completion',
    () async {
      final f = await fixture();
      await f.app.refreshSportRecords(includeDevice: false);
      f.store.failRead = true;
      await f.app.refreshSportRecords();
      expect(f.app.sportHistoryReadStatus, SportHistoryReadStatus.failed);
      expect(f.app.sportRecords.single.id, record().id);
      expect(f.sdk.reads, 0);
      expect(f.app.errorMessage, isNull);
    },
  );

  test(
    'a late old-target timeout cannot replace the current target result',
    () async {
      final f = await fixture();
      final pending = Completer<List<SportRecord>>();
      f.sdk.read = () => pending.future;
      final old = f.app.refreshSportRecords();
      while (f.sdk.reads == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      f.app.connectedDevice = const DeviceInfo(
        id: 'coolwear:OTHER',
        name: 'HR05',
      );
      expect(f.app.sportHistoryReadStatus, SportHistoryReadStatus.idle);
      f.sdk.read = () async => [];
      await f.app.refreshSportRecords();
      pending.completeError(timeout());
      await old;
      expect(f.app.sportHistoryReadStatus, SportHistoryReadStatus.complete);
      expect(f.app.errorMessage, isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'partial refresh remains on page with retry and saved list at scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(332, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final f = await fixture();
        f.sdk.read = () async => throw timeout();
        await tester.pumpWidget(host(f.app, scale: scale));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('sport-history-read-notice')),
          findsOneWidget,
        );
        expect(find.text('步行'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(f.app.errorMessage, isNull);
        expect(tester.takeException(), isNull);
        f.sdk.read = () async => [];
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();
        expect(f.sdk.reads, 2);
        expect(
          find.byKey(const Key('sport-history-read-notice')),
          findsNothing,
        );
        expect(find.text('步行'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty local list and timeout is not a confirmed no-record result',
    (tester) async {
      final f = await fixture(saved: false);
      f.sdk.read = () async => throw timeout();
      await tester.pumpWidget(host(f.app));
      await tester.pumpAndSettle();
      expect(find.text('本次刷新尚未完成，已有运动记录不受影响。'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(f.app.sportHistoryReadStatus, SportHistoryReadStatus.incomplete);
      f.sdk.read = () async => [];
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('本次刷新尚未完成，已有运动记录不受影响。'), findsNothing);
      expect(f.app.sportHistoryReadStatus, SportHistoryReadStatus.complete);
    },
  );

  testWidgets(
    'leaving the records page cannot show a delayed history popup elsewhere',
    (tester) async {
      final f = await fixture();
      final pending = Completer<List<SportRecord>>();
      f.sdk.read = () => pending.future;
      await tester.pumpWidget(host(f.app));
      for (var i = 0; i < 5 && f.sdk.reads == 0; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(f.sdk.reads, 1);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('other page'))),
      );
      pending.completeError(timeout());
      await tester.pumpAndSettle();
      expect(find.text('other page'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(f.app.errorMessage, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
