import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const deviceChannel = MethodChannel('dev.fluttercommunity.plus/device_info');
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const locationChannel = MethodChannel('flutter.baseflow.com/geolocator');
  late _AndroidScanEnvironment environment;

  setUp(() {
    environment = _AndroidScanEnvironment();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(deviceChannel, (
      call,
    ) async {
      if (call.method != 'getDeviceInfo') {
        throw StateError('Unexpected device method ${call.method}');
      }
      return environment.deviceInfo;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      permissionChannel,
      environment.permissionCall,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(locationChannel, (
      call,
    ) async {
      if (call.method != 'openLocationSettings') {
        throw StateError('Unexpected location method ${call.method}');
      }
      environment.locationSettingsOpened++;
      return true;
    });
  });

  tearDown(() {
    for (final channel in [deviceChannel, permissionChannel, locationChannel]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  for (final sdk in [29, 30]) {
    test(
      'Android $sdk blocks both SDKs when location service is off',
      () async {
        environment.sdk = sdk;
        final wearable = _ScanWearable();
        final controller = _controller(wearable);
        addTearDown(controller.dispose);

        await controller.scanDevices();

        expect(environment.requestedPermissions.single, [
          Permission.locationWhenInUse.value,
        ]);
        expect(environment.serviceChecks, 1);
        expect(wearable.scans, 0);
        expect(controller.scannedDevices, isEmpty);
        expect(
          controller.deviceScanIssue,
          DeviceScanIssue.locationServiceDisabled,
        );
        expect(controller.deviceState, DeviceConnectionState.error);
      },
    );
  }

  test(
    'turning location on permits a retry and clears the old issue',
    () async {
      final wearable = _ScanWearable();
      final controller = _controller(wearable);
      addTearDown(controller.dispose);

      await controller.scanDevices();
      environment.locationEnabled = true;
      await controller.scanDevices();

      expect(wearable.scans, 1);
      expect(controller.deviceScanIssue, isNull);
      expect(controller.errorMessage, isNull);
      expect(controller.scannedDevices, [_ScanWearable.watch]);
      expect(controller.deviceState, DeviceConnectionState.disconnected);
    },
  );

  test('Android 12 scans without requiring the location service', () async {
    environment.sdk = 31;
    final wearable = _ScanWearable();
    final controller = _controller(wearable);
    addTearDown(controller.dispose);

    await controller.scanDevices();

    expect(environment.requestedPermissions.single, [
      Permission.bluetoothScan.value,
      Permission.bluetoothConnect.value,
    ]);
    expect(environment.serviceChecks, 0);
    expect(wearable.scans, 1);
    expect(controller.deviceScanIssue, isNull);
    expect(controller.scannedDevices, [_ScanWearable.watch]);
  });

  test(
    'scan keeps first-seen order while refreshing signal strength',
    () async {
      environment.sdk = 31;
      const first = DeviceInfo(id: 'veepoo:FIRST', name: 'First', rssi: -80);
      const second = DeviceInfo(id: 'veepoo:SECOND', name: 'Second', rssi: -40);
      const refreshedFirst = DeviceInfo(
        id: 'veepoo:FIRST',
        name: 'First',
        rssi: -30,
      );
      final wearable = _ScanWearable(
        results: const [first, second, refreshedFirst],
      );
      final controller = _controller(wearable);
      addTearDown(controller.dispose);

      await controller.scanDevices();

      expect(controller.scannedDevices.map((device) => device.id), [
        'veepoo:FIRST',
        'veepoo:SECOND',
      ]);
      expect(controller.scannedDevices.first.rssi, -30);
    },
  );

  for (final fails in [false, true]) {
    test(
      'leaving device search discards a late recovery lookup, fails=$fails',
      () async {
        environment.sdk = 31;
        final wearable = _CachedScanWearable(cached: [])
          ..lookupReply = Completer<List<DeviceInfo>>();
        final controller = _controller(wearable);
        addTearDown(controller.dispose);
        final pending = controller.listBondedDevicesForSelection();
        await wearable.lookupStarted.future;
        await controller.stopDeviceScan();
        await controller.scanDevices();
        if (fails) {
          wearable.lookupReply!.completeError(
            PlatformException(code: 'BLE_PERMISSION_DENIED'),
          );
        } else {
          wearable.lookupReply!.complete([_CachedScanWearable.ring]);
        }
        expect(await pending, 0);
        expect(controller.scannedDevices, [_ScanWearable.watch]);
        expect(controller.deviceScanIssue, isNull);
        expect(controller.errorMessage, isNull);
      },
    );
  }

  for (final lookupFails in [false, true]) {
    testWidgets(
      'late cached lookup fallback cannot scan over a connected ring, '
      'fails=$lookupFails',
      (tester) async {
        environment.sdk = 31;
        final wearable = _ConnectedCachedScanWearable()
          ..lookupReply = Completer<List<DeviceInfo>>();
        final controller = _controller(wearable);
        addTearDown(controller.dispose);
        await _pumpSearch(tester, controller, settle: false);
        await tester.pump();
        expect(wearable.lookups, 1);
        expect(wearable.scans, 0);

        // 用真实控制器连接推进代次，不能直接赋值伪造 ready 状态。
        // 添加页旧缓存查询仍在等待；后台恢复或另一路连接已经成功。
        await controller.connectDevice(_ConnectedCachedScanWearable.r8);
        await tester.pump();
        expect(controller.deviceState, DeviceConnectionState.ready);
        expect(controller.deviceCapabilityState, DeviceCapabilityState.ready);
        final connected = controller.connectedDevice;
        final capabilities = controller.capabilities;
        expect(capabilities?.supportsHistorySync, isTrue);

        if (lookupFails) {
          wearable.lookupReply!.completeError(
            PlatformException(code: 'BLE_PERMISSION_DENIED'),
          );
        } else {
          wearable.lookupReply!.complete(const <DeviceInfo>[]);
        }
        await tester.pumpAndSettle();

        // 被淘汰的查询返回 0 不等于当前搜索确实为空；不得启动新扫描，
        // 更不能把正常连接改成 error/disconnected 后保留一份假连接资料。
        expect(controller.connectedDevice, same(connected));
        expect(controller.capabilities, same(capabilities));
        expect(controller.deviceCapabilityState, DeviceCapabilityState.ready);
        expect(controller.deviceState, DeviceConnectionState.ready);
        expect(controller.errorMessage, isNull);
        expect(wearable.scans, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('explicit scans cannot overwrite an already connected ring', () async {
    environment.sdk = 31;
    final wearable = _ConnectedCachedScanWearable();
    final controller = _controller(wearable);
    addTearDown(controller.dispose);
    await controller.connectDevice(_ConnectedCachedScanWearable.r8);
    expect(controller.deviceState, DeviceConnectionState.ready);
    expect(controller.deviceCapabilityState, DeviceCapabilityState.ready);
    final connected = controller.connectedDevice;
    final capabilities = controller.capabilities;
    expect(capabilities?.supportsHistorySync, isTrue);

    // 连续调用覆盖旧页面回调/重复点击：不能先 ready→error，
    // 再 error→scanning→disconnected，留下 connectedDevice 非空的矛盾状态。
    await controller.scanDevices();
    await controller.scanDevices();

    expect(controller.connectedDevice, same(connected));
    expect(controller.capabilities, same(capabilities));
    expect(controller.deviceCapabilityState, DeviceCapabilityState.ready);
    expect(controller.deviceState, DeviceConnectionState.ready);
    expect(controller.errorMessage, isNull);
    expect(wearable.scans, 0);
  });

  for (final cachedLookup in [false, true]) {
    for (final connectPending in [false, true]) {
      test('late search permission cannot replace a newer connection, '
          'cached=$cachedLookup, connecting=$connectPending', () async {
        environment.sdk = 31;
        environment.permissionReply = Completer<Map<int, int>>();
        final wearable = _ConnectedCachedScanWearable();
        if (connectPending) {
          wearable.connectReply = Completer<void>();
        }
        final controller = _controller(wearable);
        addTearDown(controller.dispose);
        final pendingSearch = cachedLookup
            ? controller.listBondedDevicesForSelection().then<void>((_) {})
            : controller.scanDevices();
        await environment.permissionsRequested.future;

        // 系统权限弹窗未返回时，另一条连接流程已经取得本轮连接槽。
        // 分别覆盖仍在握手和已握手成功，不能只检查 connectedDevice 非空。
        final connecting = controller.connectDevice(
          _ConnectedCachedScanWearable.r8,
        );
        await wearable.connectStarted.future;
        if (!connectPending) await connecting;
        final before = controller.deviceState;
        expect(
          before,
          connectPending
              ? DeviceConnectionState.connecting
              : DeviceConnectionState.ready,
        );
        expect(controller.canSearchForDevice, isFalse);

        environment.permissionReply!.complete({
          for (final permission in environment.requestedPermissions.single)
            permission: 1,
        });
        await pendingSearch;
        expect(controller.deviceState, before);
        expect(controller.deviceScanIssue, isNull);
        expect(wearable.scans, 0);
        expect(wearable.lookups, 0);

        if (connectPending) {
          wearable.connectReply!.complete();
          await connecting;
        }
        expect(controller.deviceState, DeviceConnectionState.ready);
        expect(
          controller.connectedDevice?.id,
          _ConnectedCachedScanWearable.r8.id,
        );
        expect(controller.deviceCapabilityState, DeviceCapabilityState.ready);
        expect(controller.capabilities?.supportsHistorySync, isTrue);
        expect(controller.errorMessage, isNull);
      });
    }
  }

  test(
    'disconnected remembered ring still permits search and recovery lookup',
    () async {
      environment.sdk = 31;
      final wearable = _ConnectedCachedScanWearable(
        cached: const [_ConnectedCachedScanWearable.r8],
      );
      final controller = _controller(wearable);
      addTearDown(controller.dispose);
      await controller.connectDevice(_ConnectedCachedScanWearable.r8);
      expect(controller.deviceState, DeviceConnectionState.ready);
      final remembered = controller.rememberedDevice;
      expect(remembered?.id, _ConnectedCachedScanWearable.r8.id);
      await controller.disconnectDevice();

      // 正常断线只保留恢复目标；新门禁不能要求先解绑或删除记忆目标。
      expect(controller.connectedDevice, isNull);
      expect(controller.rememberedDevice, same(remembered));
      expect(controller.canSearchForDevice, isTrue);
      await controller.scanDevices();
      expect(wearable.scans, 1);
      expect(controller.deviceState, DeviceConnectionState.disconnected);
      expect(controller.scannedDevices, contains(_ScanWearable.watch));
      expect(await controller.listBondedDevicesForSelection(), 1);
      expect(wearable.lookups, 1);
      expect(
        controller.scannedDevices,
        contains(_ConnectedCachedScanWearable.r8),
      );
      expect(controller.rememberedDevice, same(remembered));
      expect(controller.deviceState, DeviceConnectionState.disconnected);
      expect(controller.canSearchForDevice, isTrue);
    },
  );

  test('denied permission stays distinct from disabled location', () async {
    environment.permissionGranted = false;
    final wearable = _ScanWearable();
    final controller = _controller(wearable);
    addTearDown(controller.dispose);

    await controller.scanDevices();

    expect(environment.serviceChecks, 0);
    expect(wearable.scans, 0);
    expect(controller.deviceScanIssue, DeviceScanIssue.permissionsRequired);
  });

  test(
    'native location error after preflight still produces recovery',
    () async {
      environment.locationEnabled = true;
      final wearable = _ScanWearable()
        ..error = PlatformException(code: 'LOCATION_SERVICE_DISABLED');
      final controller = _controller(wearable);
      addTearDown(controller.dispose);

      await controller.scanDevices();

      expect(wearable.scans, 1);
      expect(
        controller.deviceScanIssue,
        DeviceScanIssue.locationServiceDisabled,
      );
      expect(controller.deviceState, DeviceConnectionState.error);
    },
  );

  testWidgets('location settings return retries exactly once', (tester) async {
    final wearable = _ScanWearable();
    final controller = _controller(wearable);
    addTearDown(controller.dispose);
    await _pumpSearch(tester, controller);

    expect(find.text('Turn on location'), findsOneWidget);
    expect(find.text('No devices found'), findsNothing);
    expect(wearable.scans, 0);
    await tester.tap(find.byKey(const Key('device-scan-open-settings')));
    await tester.pumpAndSettle();
    expect(environment.locationSettingsOpened, 1);
    expect(environment.appSettingsOpened, 0);
    expect(find.byType(SnackBar), findsNothing);

    environment.locationEnabled = true;
    expect(
      ModalRoute.of(tester.element(find.byType(DeviceSearchPage)))?.isCurrent,
      isTrue,
    );
    await _resume(tester);
    expect(
      wearable.scans,
      1,
      reason:
          'requests=${environment.requestedPermissions.length}, '
          'serviceChecks=${environment.serviceChecks}, '
          'calls=${environment.permissionCalls}, '
          'issue=${controller.deviceScanIssue}, error=${controller.errorMessage}',
    );
    expect(find.text(_ScanWearable.watch.name), findsOneWidget);
    expect(find.byKey(const Key('device-scan-open-settings')), findsNothing);

    await _resume(tester);
    expect(wearable.scans, 1);
  });

  testWidgets('return with location still off keeps actionable guidance', (
    tester,
  ) async {
    final wearable = _ScanWearable();
    final controller = _controller(wearable);
    addTearDown(controller.dispose);
    await _pumpSearch(tester, controller);

    await tester.tap(find.byKey(const Key('device-scan-open-settings')));
    await tester.pumpAndSettle();
    await _resume(tester);

    expect(environment.serviceChecks, 2);
    expect(wearable.scans, 0);
    expect(find.text('Turn on location'), findsOneWidget);
    expect(find.byKey(const Key('device-scan-open-settings')), findsOneWidget);

    await _resume(tester);
    expect(environment.serviceChecks, 2);
  });

  testWidgets('denied permission opens app settings and remains recoverable', (
    tester,
  ) async {
    environment.permissionGranted = false;
    final wearable = _ScanWearable();
    final controller = _controller(wearable);
    addTearDown(controller.dispose);
    await _pumpSearch(tester, controller);

    expect(find.text('Allow device access'), findsOneWidget);
    expect(find.text('No devices found'), findsNothing);
    await tester.tap(find.byKey(const Key('device-scan-open-settings')));
    await tester.pumpAndSettle();
    expect(environment.appSettingsOpened, 1);
    expect(environment.locationSettingsOpened, 0);

    await _resume(tester);
    expect(wearable.scans, 0);
    expect(find.text('Allow device access'), findsOneWidget);
    expect(environment.requestedPermissions, hasLength(2));
  });

  testWidgets('ordinary app resume does not restart a scan', (tester) async {
    environment.locationEnabled = true;
    final wearable = _ScanWearable();
    final controller = _controller(wearable);
    addTearDown(controller.dispose);
    await _pumpSearch(tester, controller);

    expect(wearable.scans, 1);
    await _resume(tester);
    expect(wearable.scans, 1);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final hasCachedDevice in [false, true]) {
      testWidgets(
        '$platform searches remembered or system devices before scanning; cached=$hasCachedDevice',
        (tester) async {
          environment.sdk = 31;
          final wearable = _CachedScanWearable(
            cached: hasCachedDevice ? [_CachedScanWearable.ring] : [],
          );
          final controller = _controller(wearable);
          addTearDown(controller.dispose);
          await _pumpSearch(tester, controller);

          expect(wearable.lookups, 1);
          expect(wearable.scans, 1);
          expect(controller.connectedDevice, isNull);
          expect(wearable.connects, 0);
          expect(
            find.text(
              hasCachedDevice
                  ? _CachedScanWearable.ring.name
                  : _ScanWearable.watch.name,
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }

    testWidgets(
      '$platform failed cached connection starts a fresh scan without adopting another ring',
      (tester) async {
        environment.sdk = 31;
        final wearable = _CachedScanWearable(
          cached: [_CachedScanWearable.ring],
        );
        final controller = _controller(wearable);
        addTearDown(controller.dispose);
        await _pumpSearch(tester, controller);
        await tester.tap(find.text(_CachedScanWearable.ring.name));
        await tester.pumpAndSettle();

        expect(wearable.connectedIds, [_CachedScanWearable.ring.id]);
        expect(wearable.scans, 2);
        expect(controller.connectedDevice, isNull);
        expect(controller.scannedDevices, [_ScanWearable.watch]);
        expect(find.text(_ScanWearable.watch.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final hasResults in [false, true]) {
      testWidgets(
        'search help stays usable on $platform with results=$hasResults and large text',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(332, 740));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          environment.sdk = 31;
          final wearable = _ScanWearable(
            results: hasResults ? [_ScanWearable.watch] : [],
          );
          final controller = _controller(wearable);
          addTearDown(controller.dispose);
          await _pumpSearch(
            tester,
            controller,
            textScale: 2,
            locale: const Locale('zh'),
          );
          await tester.tap(find.byKey(const Key('device-search-help')));
          await tester.pumpAndSettle();
          final rebind = platform == TargetPlatform.iOS ? '忽略此设备' : '取消配对';
          final guidance = find.textContaining(rebind);
          expect(guidance, findsOneWidget);
          await tester.ensureVisible(guidance);
          await tester.pumpAndSettle();
          expect(find.textContaining('仅在已解绑'), findsOneWidget);
          expect(find.textContaining('首次添加请直接在 App 中搜索'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('device-search-help-close')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('device-search-help-dialog')),
            findsNothing,
          );
          expect(wearable.scans, 1);
          expect(environment.appSettingsOpened, 0);
          expect(controller.connectedDevice, isNull);
          if (hasResults) {
            expect(find.text(_ScanWearable.watch.name), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }

  testWidgets(
    'scan results can arrive while help is open without restarting search',
    (tester) async {
      environment.sdk = 31;
      final pending = Completer<List<DeviceInfo>>();
      final wearable = _ScanWearable()..pending = pending;
      final controller = _controller(wearable);
      addTearDown(controller.dispose);
      await _pumpSearch(tester, controller, settle: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('device-search-help')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('device-search-help-dialog')),
        findsOneWidget,
      );
      pending.complete([_ScanWearable.watch]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('device-search-help-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('device-search-help-close')));
      await tester.pumpAndSettle();
      expect(find.text(_ScanWearable.watch.name), findsOneWidget);
      expect(wearable.scans, 1);
      expect(controller.connectedDevice, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('location recovery remains reachable at text scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _controller(_ScanWearable());
      addTearDown(controller.dispose);
      await _pumpSearch(tester, controller, textScale: scale);

      expect(find.text('Turn on location'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final settings = find.byKey(const Key('device-scan-open-settings'));
      await tester.scrollUntilVisible(
        settings,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(environment.locationSettingsOpened, 1);
      expect(tester.takeException(), isNull);
    });
  }
}

AppController _controller(WearableBridge wearable) => AppController(
  MemorySessionVault(),
  _NoopApi(),
  MemoryHealthStore(),
  wearable,
);

Future<void> _pumpSearch(
  WidgetTester tester,
  AppController controller, {
  double textScale = 1,
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: DeviceSearchPage(controller: controller),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  await tester.pumpAndSettle();
}

class _NoopApi extends Fake implements SaydianApi {}

class _ScanWearable extends Fake implements WearableBridge {
  static const watch = DeviceInfo(id: 'veepoo:TEST-WATCH', name: 'QA Watch');
  _ScanWearable({List<DeviceInfo>? results})
    : results = results ?? const [watch];

  final List<DeviceInfo> results;
  int scans = 0;
  Completer<List<DeviceInfo>>? pending;
  PlatformException? error;

  @override
  Future<List<DeviceInfo>> scanDevices() async {
    scans++;
    if (error != null) throw error!;
    return pending?.future ?? results;
  }

  @override
  Future<void> stopScan() async {}
}

class _CachedScanWearable extends _ScanWearable
    implements WearableBondedDeviceSelectionBridge {
  _CachedScanWearable({required this.cached});

  static const ring = DeviceInfo(id: 'qring:CACHED', name: 'R21 Cached');
  final List<DeviceInfo> cached;
  int lookups = 0;
  final lookupStarted = Completer<void>();
  Completer<List<DeviceInfo>>? lookupReply;
  final connectedIds = <String>[];
  int get connects => connectedIds.length;

  @override
  Future<List<DeviceInfo>> listBondedDevicesForSelection() async {
    lookups++;
    if (!lookupStarted.isCompleted) lookupStarted.complete();
    return lookupReply?.future ?? cached;
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connectedIds.add(deviceId);
    throw PlatformException(code: 'QRING_CONNECT_TIMEOUT');
  }
}

class _ConnectedCachedScanWearable extends _CachedScanWearable {
  _ConnectedCachedScanWearable({super.cached = const []});

  static const r8 = DeviceInfo(id: 'qring:TEST-R8', name: 'SD_RING_R8');
  final connectStarted = Completer<void>();
  Completer<void>? connectReply;

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    connectedIds.add(deviceId);
    if (!connectStarted.isCompleted) connectStarted.complete();
    await connectReply?.future;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(
        metrics: {HealthMetric.steps, HealthMetric.sleep},
      );

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async => [];

  @override
  Future<List<SportRecord>> readSportRecords() async => [];
}

class _AndroidScanEnvironment {
  int sdk = 29;
  bool permissionGranted = true;
  bool locationEnabled = false;
  int serviceChecks = 0;
  int locationSettingsOpened = 0;
  int appSettingsOpened = 0;
  final requestedPermissions = <List<int>>[];
  final permissionCalls = <String>[];
  final permissionsRequested = Completer<void>();
  Completer<Map<int, int>>? permissionReply;

  Future<Object?> permissionCall(MethodCall call) async {
    permissionCalls.add('${call.method}:${call.arguments}');
    switch (call.method) {
      case 'requestPermissions':
        final requested = List<int>.from(call.arguments as List);
        requestedPermissions.add(requested);
        if (!permissionsRequested.isCompleted) permissionsRequested.complete();
        return permissionReply?.future ??
            <int, int>{
              for (final permission in requested)
                permission: permissionGranted ? 1 : 0,
            };
      case 'checkServiceStatus':
        if (call.arguments != Permission.locationWhenInUse.value) {
          throw StateError('Unexpected service permission ${call.arguments}');
        }
        serviceChecks++;
        return locationEnabled ? 1 : 0;
      case 'openAppSettings':
        appSettingsOpened++;
        return true;
      default:
        throw StateError('Unexpected permission method ${call.method}');
    }
  }

  Map<String, Object> get deviceInfo => {
    'version': {
      'sdkInt': sdk,
      'release': sdk <= 30 ? '10' : '12',
      'codename': 'REL',
      'incremental': 'test',
    },
    for (final key in [
      'board',
      'bootloader',
      'brand',
      'device',
      'display',
      'fingerprint',
      'hardware',
      'host',
      'id',
      'manufacturer',
      'model',
      'product',
      'tags',
      'type',
    ])
      key: 'test',
    'isPhysicalDevice': true,
    'freeDiskSize': 1,
    'totalDiskSize': 2,
    'isLowRamDevice': false,
    'physicalRamSize': 2,
    'availableRamSize': 1,
  };
}
