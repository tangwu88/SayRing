import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/widgets/ring_gesture_panel.dart';

class _Api extends Fake implements SaydianApi {
  @override
  Future<List<Map<String, Object?>>> getArticles() async => [];
}

const _caps = DeviceCapabilities(
  metrics: {HealthMetric.steps},
  features: {DeviceFeature.gestureControl},
  integratedFeatures: {DeviceFeature.gestureControl},
);

class _Sdk extends Fake implements WearableBridge {
  final source = StreamController<WearableEvent>.broadcast();
  final health = Completer<List<HealthRecord>>();
  final sport = Completer<List<SportRecord>>();
  int healthReads = 0, sportReads = 0, writes = 0;
  @override
  Stream<WearableEvent> get events => source.stream;
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async => _caps;
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) {
    healthReads++;
    return health.future;
  }

  @override
  Future<List<SportRecord>> readSportRecords() {
    sportReads++;
    return sport.future;
  }

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      {'requiresReconnect': false};
  @override
  Future<void> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    writes++;
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Widget _host(AppController c, Widget Function() page) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ListenableBuilder(listenable: c, builder: (_, _) => page()),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppController controller(_Sdk sdk) {
    final c = AppController(
      MemorySessionVault()..privacyConsentGranted = true,
      _Api(),
      MemoryHealthStore(),
      sdk,
    );
    addTearDown(c.dispose);
    addTearDown(sdk.source.close);
    return c;
  }

  for (final model in ['R7Pro', 'R7 Ultra']) {
    test(
      '$model initial transfer stays busy across health-to-sport handoff',
      () async {
        final sdk = _Sdk();
        final app = controller(sdk);
        await app.initialize();
        final ring = DeviceInfo(id: 'coolwear:TEST', name: model);
        final states = <bool>[];
        app.addListener(() => states.add(app.isDeviceHistorySyncing));
        await app.connectDevice(ring);
        await _settle();
        expect(sdk.healthReads, 1);
        expect(
          sdk.sportReads,
          1,
          reason:
              'sport joins the pending health transfer, not a second later sync',
        );
        expect(app.isDeviceHistorySyncing, isTrue);
        states.clear();
        sdk.health.complete([]);
        await _settle();
        expect(sdk.sportReads, 1);
        expect(app.isDeviceSyncing, isFalse);
        expect(app.isDeviceHistorySyncing, isTrue);
        expect(states, isNotEmpty);
        expect(
          states,
          everyElement(isTrue),
          reason: 'no idle flash between SDK stages',
        );
        expect(await app.syncDeviceData(), isFalse);
        expect(
          await app.writeDeviceFeature(DeviceFeature.gestureControl, {
            'mode': 1,
          }),
          isFalse,
        );
        expect(sdk.writes, 0);
        expect(
          app.deviceFeatureData[DeviceFeature
              .gestureControl]?['requiresReconnect'],
          isNot(true),
        );
        sdk.source.add(
          WearableEvent(
            type: 'healthDataReady',
            payload: {'deviceId': ring.id},
          ),
        );
        await _settle();
        expect(
          sdk.healthReads,
          1,
          reason: 'no second history request during sport transfer',
        );
        sdk.sport.complete([]);
        await _settle();
        expect(app.isDeviceHistorySyncing, isFalse);
        expect(states.last, isFalse);
        expect(app.sportHistoryReadStatus, SportHistoryReadStatus.complete);
      },
    );
  }

  test(
    'disconnect retires the initial transfer and late completion cannot keep it busy',
    () async {
      final sdk = _Sdk();
      final c = controller(sdk);
      await c.initialize();
      await c.connectDevice(
        const DeviceInfo(id: 'coolwear:TEST', name: 'R7Pro'),
      );
      sdk.health.complete([]);
      await _settle();
      expect(sdk.sportReads, 1);
      await c.disconnectDevice();
      expect(c.isDeviceHistorySyncing, isFalse);
      sdk.sport.complete([]);
      await _settle();
      expect(c.connectedDevice, isNull);
      expect(c.isDeviceHistorySyncing, isFalse);
      expect(c.sportHistoryReadStatus, SportHistoryReadStatus.idle);
    },
  );

  for (final gesture in [false, true]) {
    testWidgets(
      '${gesture ? 'gesture scenes' : 'device sync button'} stay disabled until sport transfer settles',
      (tester) async {
        final sdk = _Sdk();
        final c = controller(sdk)
          ..connectedDevice = const DeviceInfo(
            id: 'coolwear:TEST',
            name: 'R7Pro',
          )
          ..capabilities = _caps
          ..deviceCapabilityState = DeviceCapabilityState.ready;
        final pending = c.refreshSportRecords();
        await tester.pumpWidget(
          _host(
            c,
            () => gesture
                ? DeviceFeaturePage(
                    controller: c,
                    feature: DeviceFeature.gestureControl,
                  )
                : DevicePage(controller: c),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(sdk.sportReads, 1);
        expect(find.text('正在同步戒指数据'), findsOneWidget);
        if (gesture) {
          expect(
            tester.widget<RingGesturePanel>(find.byType(RingGesturePanel)).busy,
            isTrue,
          );
          expect(
            tester
                .widget<RingGesturePanel>(find.byType(RingGesturePanel))
                .syncingData,
            isTrue,
          );
        } else {
          expect(
            tester
                .widget<FilledButton>(find.byKey(const Key('device-sync-data')))
                .onPressed,
            isNull,
          );
        }
        sdk.sport.complete([]);
        await pending;
        await tester.pumpAndSettle();
        expect(find.text('正在同步戒指数据'), findsNothing);
        if (gesture) {
          expect(
            tester.widget<RingGesturePanel>(find.byType(RingGesturePanel)).busy,
            isFalse,
          );
        } else {
          expect(
            tester
                .widget<FilledButton>(find.byKey(const Key('device-sync-data')))
                .onPressed,
            isNotNull,
          );
        }
        expect(sdk.writes, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
