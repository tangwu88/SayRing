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
import 'package:saydian_app/ui/prototype_pages.dart';
import 'package:saydian_app/ui/widgets/ring_gesture_panel.dart';

class _Api extends Fake implements SaydianApi {
  @override
  Future<List<Map<String, Object?>>> getArticles() async => [];
}

class _Sdk extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}

const ring = DeviceInfo(id: 'coolwear:TEST', name: 'R7Pro');

class _Controller extends AppController {
  _Controller()
    : super(MemorySessionVault(), _Api(), MemoryHealthStore(), _Sdk()) {
    connectedDevice = rememberedDevice = ring;
  }
  bool tainted = true, busy = false, clearOnRecovery = true;
  int recoveries = 0, writes = 0, reads = 0;
  Completer<void>? pending;
  @override
  FeatureAvailability availabilityFor(DeviceFeature feature) =>
      FeatureAvailability(
        connectedDevice == null
            ? FeatureAvailabilityStatus.needsDevice
            : FeatureAvailabilityStatus.ready,
      );
  @override
  bool get isGestureControlRecoveryBusy => busy;
  @override
  bool get canRecoverGestureControlConnection =>
      !busy && connectedDevice == ring && tainted;
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    reads++;
    return {'requiresReconnect': tainted};
  }

  @override
  Future<void> reconnectDevice() async {
    recoveries++;
    connectedDevice = null;
    notifyListeners();
    await pending?.future;
    if (clearOnRecovery) tainted = false;
    connectedDevice = ring;
    notifyListeners();
  }

  @override
  Future<bool> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    writes++;
    return true;
  }
}

Widget _host(_Controller c, {double scale = 1}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: DeviceFeaturePage(controller: c, feature: DeviceFeature.gestureControl),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _Controller controller() {
    final c = _Controller();
    addTearDown(c.dispose);
    return c;
  }

  test(
    'production recovery gate requires verified taint, exact saved target, consent and idle',
    () async {
      final c = AppController(
        MemorySessionVault()..privacyConsentGranted = true,
        _Api(),
        MemoryHealthStore(),
        _Sdk(),
      );
      addTearDown(c.dispose);
      await c.initialize();
      c.connectedDevice = c.rememberedDevice = ring;
      c.capabilities = const DeviceCapabilities(
        metrics: {},
        features: {DeviceFeature.gestureControl},
        integratedFeatures: {DeviceFeature.gestureControl},
      );
      c.deviceCapabilityState = DeviceCapabilityState.ready;
      c.deviceFeatureData = {
        DeviceFeature.gestureControl: {'requiresReconnect': true},
      };
      expect(c.canRecoverGestureControlConnection, isTrue);
      c.isDeviceSyncing = true;
      expect(c.isGestureControlRecoveryBusy, isTrue);
      expect(c.canRecoverGestureControlConnection, isFalse);
      c.isDeviceSyncing = false;
      c.activeSport = SportMode.walking;
      expect(c.canRecoverGestureControlConnection, isFalse);
      c.activeSport = null;
      c.isDeviceSettingsWriting = true;
      expect(c.canRecoverGestureControlConnection, isFalse);
      c.isDeviceSettingsWriting = false;
      c.deviceFeatureBusy = {DeviceFeature.camera};
      expect(c.canRecoverGestureControlConnection, isFalse);
      c.deviceFeatureBusy = {};
      c.rememberedDevice = const DeviceInfo(id: 'coolwear:OTHER', name: 'HR05');
      expect(c.canRecoverGestureControlConnection, isFalse);
      c.rememberedDevice = ring;
      c.deviceFeatureData = {
        DeviceFeature.gestureControl: {'requiresReconnect': false},
      };
      expect(c.canRecoverGestureControlConnection, isFalse);
    },
  );

  testWidgets('normal opening only reads and never reconnects or writes', (
    tester,
  ) async {
    final c = controller()..tainted = false;
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(c.recoveries, 0);
    expect(c.writes, 0);
    expect(c.reads, 1);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'tainted R7P recovers once without replay or claiming mode closed at $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(332, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final c = controller();
        await tester.pumpWidget(_host(c, scale: scale));
        await tester.pumpAndSettle();
        expect(c.recoveries, 0);
        final restore = find.byKey(const ValueKey('gesture-refresh'));
        await Scrollable.ensureVisible(tester.element(restore), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(restore);
        await tester.pumpAndSettle();
        expect(c.recoveries, 1);
        expect(c.writes, 0);
        final panel = tester.widget<RingGesturePanel>(
          find.byType(RingGesturePanel),
        );
        expect(panel.requiresReconnect, isFalse);
        expect(panel.confirmedMode, isNull);
        expect(panel.uncertainControl, isTrue);
        expect(find.text('需要重新连接'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'busy connection is not interrupted and prepares only after idle',
    (tester) async {
      final c = controller()..busy = true;
      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();
      expect(c.recoveries, 0);
      expect(find.text('等待设备空闲'), findsOneWidget);
      c.busy = false;
      c.notifyListeners();
      await tester.pumpAndSettle();
      expect(c.recoveries, 0);
      final restore = find.byKey(const ValueKey('gesture-refresh'));
      await Scrollable.ensureVisible(tester.element(restore), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(c.recoveries, 1);
      expect(c.writes, 0);
    },
  );
  testWidgets(
    'pending reconnect uses preparation view instead of false disconnect prompt',
    (tester) async {
      final c = controller()..pending = Completer<void>();
      await tester.pumpWidget(_host(c));
      await tester.pumpAndSettle();
      final restore = find.byKey(const ValueKey('gesture-refresh'));
      await Scrollable.ensureVisible(tester.element(restore), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(restore);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(c.recoveries, 1);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
      await tester.pump();
      expect(find.text('正在准备手势控制'), findsOneWidget);
      expect(find.text('连接戒指后使用'), findsNothing);
      c.pending!.complete();
      await tester.pumpAndSettle();
      expect(c.writes, 0);
    },
  );
  testWidgets('repeated unconfirmed state cannot create a reconnect loop', (
    tester,
  ) async {
    final c = controller()..clearOnRecovery = false;
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      c.notifyListeners();
      await tester.pumpAndSettle();
    }
    expect(c.recoveries, 0);
    expect(c.writes, 0);
    final retry = find.byKey(const ValueKey('gesture-refresh'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(c.recoveries, 1);
    expect(find.text('控制状态待确认'), findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(c.recoveries, 2);
    expect(c.writes, 0);
  });
  testWidgets('leaving while busy cancels the page recovery intent', (
    tester,
  ) async {
    final c = controller()..busy = true;
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: Text('other page')));
    c.busy = false;
    c.notifyListeners();
    await tester.pumpAndSettle();
    expect(c.recoveries, 0);
    expect(c.writes, 0);
  });
}
