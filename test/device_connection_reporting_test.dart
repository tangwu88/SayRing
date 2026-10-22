import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

final _owner = Session(
  accessToken: 'report-test-token',
  refreshToken: 'report-test-refresh',
  expiresAt: DateTime.utc(2099),
  memberId: 'report-owner',
  displayName: 'Test',
  accountKey: 'global:member:report-owner',
);
const _device = DeviceInfo(
  id: 'qring:11111111-2222-4333-8444-555555555555',
  name: 'R21_TEST',
  model: 'R21',
  firmwareVersion: 'test-fw',
  hardwareAddress: 'aabbccddeeff',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unmapped history skips initial and manual reads without false failure',
    () async {
      final api = _Api();
      final ring = _Ring()..supportsHistorySync = false;
      final controller = AppController(
        MemorySessionVault()..privacyConsentGranted = true,
        api,
        MemoryHealthStore(),
        ring,
      );
      addTearDown(controller.dispose);
      addTearDown(ring.source.close);
      await controller.initialize();
      controller.session = _owner;
      await controller.connectDevice(_device);
      await _settle();
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(
        api.reports,
        hasLength(1),
        reason: 'real handshake reporting remains',
      );
      expect(ring.historyReads, 0);
      expect(controller.errorMessage, isNull);
      expect(controller.syncStatus, '设备已连接，此戒指历史同步暂未开放');
      expect(await controller.syncDeviceData(), isFalse);
      expect(ring.historyReads, 0);
      expect(controller.isDeviceSyncing, isFalse);
      expect(controller.errorMessage, isNull);
      expect(
        controller.capabilities?.supportsManualMeasurement(
          HealthMetric.heartRate,
        ),
        isTrue,
      );
    },
  );

  test('every manual handshake and restored handshake reports once', () async {
    final api = _Api();
    final ring = _Ring();
    final controller = AppController(
      MemorySessionVault()..privacyConsentGranted = true,
      api,
      MemoryHealthStore(),
      ring,
    );
    addTearDown(controller.dispose);
    addTearDown(ring.source.close);
    await controller.initialize();
    controller.session = _owner;
    await controller.connectDevice(_device);
    await _settle();
    expect(api.reports, hasLength(1));
    expect(api.reports.single, containsPair('deviceId', _device.id));
    expect(api.reports.single, containsPair('macAddress', 'AA:BB:CC:DD:EE:FF'));
    expect(api.reports.single['capabilities'], contains('metric:heart_rate'));
    await controller.refreshDeviceCapabilities();
    ring.source.add(
      WearableEvent(type: 'deviceDetails', payload: _device.toJson()),
    );
    await _settle();
    expect(
      api.reports,
      hasLength(1),
      reason: 'metadata refresh is not a new connection',
    );

    for (var i = 0; i < 3; i++) {
      ring.source.add(
        WearableEvent(type: 'disconnected', payload: {'deviceId': _device.id}),
      );
      await _settle();
      ring.source.add(
        WearableEvent(type: 'reconnected', payload: _device.toJson()),
      );
      ring.source.add(
        WearableEvent(type: 'reconnected', payload: _device.toJson()),
      );
      await _settle();
      expect(api.reports, hasLength(i + 2));
      expect(controller.deviceState, DeviceConnectionState.ready);
    }
  });

  test(
    'anonymous connection stays local and failed handshake is not reported',
    () async {
      final api = _Api();
      final ring = _Ring();
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        ring,
      );
      addTearDown(controller.dispose);
      addTearDown(ring.source.close);
      await controller.connectDevice(_device);
      expect(api.reports, isEmpty);
      controller.session = _owner;
      ring.failConnect = true;
      await controller.connectDevice(_device);
      expect(api.reports, isEmpty);
    },
  );

  test(
    'report outage never converts a successful ring handshake into failure',
    () async {
      final api = _Api()..failReport = true;
      final ring = _Ring();
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        ring,
      );
      addTearDown(controller.dispose);
      addTearDown(ring.source.close);
      controller.session = _owner;
      await controller.connectDevice(_device);
      await _settle();
      expect(api.reports, hasLength(1));
      expect(controller.deviceState, DeviceConnectionState.ready);
      expect(controller.errorMessage, isNull);
    },
  );

  test(
    'global report uses Health API contract with a captured account',
    () async {
      final vault = MemorySessionVault()..session = _owner;
      final requests = <http.Request>[];
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {'id': 'test-binding'},
            }),
            200,
          );
        }),
      );
      await api.reportDeviceConnection(
        expectedSession: _owner,
        deviceId: _device.id,
        vendor: 'QRing',
        model: 'R21',
        displayName: 'R21_TEST',
        firmware: 'test-fw',
        macAddress: 'aa:bb:cc:dd:ee:ff',
        capabilities: ['metric:heart_rate', 'metric:heart_rate', ' '],
      );
      expect(requests.single.url.path, '/global/api/saydian-app/v2/devices');
      expect(
        requests.single.headers['authorization'],
        'Bearer report-test-token',
      );
      expect(jsonDecode(requests.single.body), {
        'deviceId': _device.id,
        'vendor': 'QRing',
        'model': 'R21',
        'displayName': 'R21_TEST',
        'firmware': 'test-fw',
        'macAddress': 'AA:BB:CC:DD:EE:FF',
        'capabilities': ['metric:heart_rate'],
      });
      vault.session = Session(
        accessToken: 'other-test-token',
        refreshToken: '',
        expiresAt: DateTime.utc(2099),
        memberId: 'other',
        displayName: 'Other',
      );
      await expectLater(
        api.reportDeviceConnection(
          expectedSession: _owner,
          deviceId: _device.id,
          vendor: 'QRing',
          model: 'R21',
          displayName: 'R21_TEST',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(
        requests,
        hasLength(1),
        reason: 'never reassign an old handshake to a new owner',
      );
    },
  );

  test(
    'unknown hardware MAC is omitted; malformed report fails before HTTP',
    () async {
      final requests = <http.Request>[];
      final api = GlobalSaydianApiClient(
        MemorySessionVault()..session = _owner,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"code":200,"data":{}}', 200);
        }),
      );
      await api.reportDeviceConnection(
        expectedSession: _owner,
        deviceId: _device.id,
        vendor: 'QRing',
        model: 'R21',
        displayName: 'R21_TEST',
      );
      expect(jsonDecode(requests.single.body), isNot(contains('macAddress')));
      await expectLater(
        api.reportDeviceConnection(
          expectedSession: _owner,
          deviceId: _device.id,
          vendor: 'QRing',
          model: 'R21',
          displayName: 'R21_TEST',
          macAddress: 'invalid',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(requests, hasLength(1));
    },
  );
  test(
    'late capability completion after logout cannot report the old device',
    () async {
      final api = _Api();
      final ring = _Ring()
        ..delayedCapabilities = Completer<DeviceCapabilities>();
      final controller = AppController(
        MemorySessionVault(),
        api,
        MemoryHealthStore(),
        ring,
      );
      addTearDown(controller.dispose);
      addTearDown(ring.source.close);
      controller.session = _owner;
      final connecting = controller.connectDevice(_device);
      await _settle();
      final logout = controller.logout();
      await _settle();
      ring.delayedCapabilities!.complete(
        const DeviceCapabilities(metrics: {HealthMetric.heartRate}),
      );
      await connecting;
      await logout;
      expect(api.reports, isEmpty);
      expect(controller.connectedDevice, isNull);
    },
  );

  test(
    'native address fallback is display only, not uploaded as hardware MAC',
    () {
      expect(
        const DeviceInfo(
          id: 'qring:AA:BB:CC:DD:EE:FF',
          name: 'R21',
        ).verifiedHardwareMacAddress,
        isNull,
      );
      expect(
        const DeviceInfo(
          id: 'qring:uuid',
          name: 'R21',
          hardwareAddress: 'not-aabbccddeeff',
        ).verifiedHardwareMacAddress,
        isNull,
      );
      expect(_device.verifiedHardwareMacAddress, 'AA:BB:CC:DD:EE:FF');
    },
  );

  test(
    '401 refresh replays the report only for the captured account',
    () async {
      final vault = MemorySessionVault()..session = _owner;
      final paths = <String>[];
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/auth/refresh')) {
            return http.Response(
              jsonEncode({
                'code': 200,
                'data': {
                  'accessToken': 'report-test-refreshed',
                  'refreshToken': 'report-test-next',
                  'expiresAt': '2099-01-01T00:00:00Z',
                  'member': {'id': _owner.memberId, 'nickname': 'Test'},
                },
              }),
              200,
            );
          }
          if (request.headers['authorization'] == 'Bearer report-test-token') {
            return http.Response('{"code":401,"message":"expired"}', 401);
          }
          return http.Response('{"code":200,"data":{}}', 200);
        }),
      );
      await api.reportDeviceConnection(
        expectedSession: _owner,
        deviceId: _device.id,
        vendor: 'QRing',
        model: 'R21',
        displayName: 'R21_TEST',
      );
      expect(paths, [
        '/global/api/saydian-app/v2/devices',
        '/global/api/saydian-app/v2/auth/refresh',
        '/global/api/saydian-app/v2/devices',
      ]);
      expect(vault.session?.memberId, _owner.memberId);
    },
  );

  test('switch during a 401 refresh cannot replay an old connection', () async {
    final vault = MemorySessionVault()..session = _owner;
    final paths = <String>[];
    final api = GlobalSaydianApiClient(
      vault,
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/auth/refresh')) {
          vault.session = Session(
            accessToken: 'other-test-token',
            refreshToken: '',
            expiresAt: DateTime.utc(2099),
            memberId: 'other',
            displayName: 'Other',
          );
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {
                'accessToken': 'report-test-refreshed',
                'refreshToken': 'report-test-next',
                'expiresAt': '2099-01-01T00:00:00Z',
                'member': {'id': _owner.memberId, 'nickname': 'Test'},
              },
            }),
            200,
          );
        }
        return http.Response('{"code":401,"message":"expired"}', 401);
      }),
    );
    await expectLater(
      api.reportDeviceConnection(
        expectedSession: _owner,
        deviceId: _device.id,
        vendor: 'QRing',
        model: 'R21',
        displayName: 'R21_TEST',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(paths, [
      '/global/api/saydian-app/v2/devices',
      '/global/api/saydian-app/v2/auth/refresh',
    ]);
    expect(vault.session?.memberId, 'other');
  });
  group('first member binding history clear', () {
    Future<AppController> setup(
      _FirstApi api,
      _ClearRing ring, {
      bool loggedIn = true,
    }) async {
      final controller = AppController(
        MemorySessionVault()..privacyConsentGranted = true,
        api,
        MemoryHealthStore(),
        ring,
      );
      addTearDown(controller.dispose);
      addTearDown(ring.source.close);
      await controller.initialize();
      if (loggedIn) controller.session = _owner;
      return controller;
    }

    test(
      'server grants once after handshake; hold old samples and automatic sync',
      () async {
        final api = _FirstApi()..decision = Completer<bool>();
        final ring = _ClearRing();
        final c = await setup(api, ring);
        final connecting = c.connectDevice(_device);
        await _settle();
        expect(api.firstReports, 1);
        expect(ring.clears, 0);
        expect(await c.syncDeviceData(), isFalse);
        ring.source.add(WearableEvent(type: 'healthDataReady', payload: {}));
        await _settle();
        expect(ring.historyReads, 0);
        api.decision!.complete(true);
        await connecting;
        await _settle();
        expect(ring.clears, 1);
        expect(ring.clearOwner, c.homeHealthCardOwner);
        expect(ring.historyReads, 0);
        expect(c.firstRingBindingStatus, contains('已确认'));
        expect(c.deviceState, DeviceConnectionState.ready);
        await c.reconnectDevice();
        await _settle();
        expect(ring.clears, 1);
        expect(api.firstReports, 1);
      },
    );
    test(
      'server lifetime history protects a member with no local cache',
      () async {
        final api = _FirstApi()..shouldClear = false;
        final ring = _ClearRing();
        final c = await setup(api, ring);
        await c.connectDevice(_device);
        await _settle();
        expect(api.firstReports, 1);
        expect(ring.clears, 0);
        expect(ring.historyReads, 1);
        expect(c.firstRingBindingStatus, contains('已有绑定记录'));
      },
    );
    test('remembered binding prevents any initialization request', () async {
      final api = _FirstApi();
      final ring = _ClearRing()..saved = _device;
      final c = await setup(api, ring);
      await c.connectDevice(_device);
      await _settle();
      expect(api.firstReports, 0);
      expect(ring.clears, 0);
      expect(api.reports, hasLength(1));
    });
    test('unreadable local binding cannot authorize a clear', () async {
      final api = _FirstApi();
      final ring = _ClearRing()..failRead = true;
      final c = await setup(api, ring);
      await c.connectDevice(_device);
      expect(api.firstReports, 0);
      expect(ring.clears, 0);
    });
    test(
      'unknown server history preserves data and pauses automatic history',
      () async {
        final api = _FirstApi()..failFirst = true;
        final ring = _ClearRing();
        final c = await setup(api, ring);
        await c.connectDevice(_device);
        await _settle();
        expect(ring.clears, 0);
        expect(ring.historyReads, 0);
        expect(c.firstRingBindingStatus, contains('未清空'));
      },
    );
    test('anonymous connection and failed handshake never clear', () async {
      final api = _FirstApi();
      final ring = _ClearRing();
      final c = await setup(api, ring, loggedIn: false);
      await c.connectDevice(_device);
      expect(api.firstReports, 0);
      expect(ring.clears, 0);
      ring.failConnect = true;
      c.session = _owner;
      await c.connectDevice(_device);
      expect(api.firstReports, 0);
      expect(ring.clears, 0);
    });
    test(
      'ambiguous clear result is not retried or called successful',
      () async {
        final api = _FirstApi();
        final ring = _ClearRing()..failClear = true;
        final c = await setup(api, ring);
        await c.connectDevice(_device);
        await _settle();
        expect(ring.clears, 1);
        expect(c.firstRingBindingStatus, contains('未确认'));
        await c.syncDeviceData();
        expect(ring.clears, 1);
        expect(ring.historyReads, 0);
      },
    );
    test(
      'Android dispatch is explicitly pending, not claimed as cleared',
      () async {
        final api = _FirstApi();
        final ring = _ClearRing()..result = RingDataClearResult.requested;
        final c = await setup(api, ring);
        await c.connectDevice(_device);
        expect(c.firstRingBindingStatus, contains('结果待确认'));
        expect(ring.historyReads, 0);
      },
    );
    test(
      'factory grant remains pending until same-owner initialization is confirmed',
      () async {
        final api = _FirstApi();
        final ring = _ClearRing()
          ..result = RingDataClearResult.factoryResetRequested;
        final c = await setup(api, ring);
        await c.connectDevice(_device);
        expect(ring.factoryAllowed, isTrue);
        expect(c.firstRingBindingStatus, contains('待确认'));
        ring.source.add(
          WearableEvent(
            type: 'ringInitialization',
            payload: {
              'deviceId': _device.id,
              'ownerKey': 'other',
              'status': 'complete',
            },
          ),
        );
        await _settle();
        expect(ring.historyReads, 0);
        ring.source.add(
          WearableEvent(
            type: 'ringInitialization',
            payload: {
              'deviceId': _device.id,
              'ownerKey': c.homeHealthCardOwner,
              'status': 'complete',
            },
          ),
        );
        await _settle();
        expect(c.firstRingBindingStatus, contains('已初始化'));
        expect(ring.historyReads, 1);
      },
    );
    test(
      'late first-binding decision after account change cannot clear',
      () async {
        final api = _FirstApi()..decision = Completer<bool>();
        final ring = _ClearRing();
        final c = await setup(api, ring);
        final connecting = c.connectDevice(_device);
        await _settle();
        c.session = null;
        api.decision!.complete(true);
        await connecting;
        expect(ring.clears, 0);
      },
    );
  });

  group('first-binding wire decision', () {
    for (final value in [true, false, null, 'true', 1]) {
      test('requires explicit matching typed decision $value', () async {
        final vault = MemorySessionVault()..session = _owner;
        final api = GlobalSaydianApiClient(
          vault,
          client: MockClient((r) async {
            final body = jsonDecode(r.body);
            expect(body['product'], 'say-ring');
            expect(body['initializeFirstBinding'], isTrue);
            return http.Response(
              jsonEncode({
                'code': 200,
                'data': {
                  'firstBindingInitialization': {
                    'product': 'say-ring',
                    'deviceId': _device.id,
                    'shouldClear': value,
                  },
                },
              }),
              200,
            );
          }),
        );
        final result = api.reportFirstRingBinding(
          expectedSession: _owner,
          deviceId: _device.id,
          vendor: 'QRing',
          model: 'R21',
          displayName: 'R21_TEST',
        );
        if (value is bool) {
          expect(await result, value);
        } else {
          await expectLater(result, throwsA(isA<ApiException>()));
        }
      });
    }
    test(
      'old server missing decision and wrong target never authorize',
      () async {
        for (final data in [
          {},
          {
            'firstBindingInitialization': {
              'product': 'say-ring',
              'deviceId': 'other',
              'shouldClear': true,
            },
          },
        ]) {
          final api = GlobalSaydianApiClient(
            MemorySessionVault()..session = _owner,
            client: MockClient(
              (r) async =>
                  http.Response(jsonEncode({'code': 200, 'data': data}), 200),
            ),
          );
          await expectLater(
            api.reportFirstRingBinding(
              expectedSession: _owner,
              deviceId: _device.id,
              vendor: 'QRing',
              model: 'R21',
              displayName: 'R21_TEST',
            ),
            throwsA(isA<ApiException>()),
          );
        }
      },
    );
  });
}

Future<void> _settle() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Api extends Fake implements SaydianApi, SaydianDeviceBindingApi {
  final reports = <Map<String, Object?>>[];
  bool failReport = false;
  @override
  Future<void> reportDeviceConnection({
    required Session expectedSession,
    required String deviceId,
    required String vendor,
    required String model,
    required String displayName,
    String? firmware,
    String? macAddress,
    List<String> capabilities = const [],
  }) async {
    reports.add({
      'deviceId': deviceId,
      'vendor': vendor,
      'model': model,
      'displayName': displayName,
      'firmware': firmware,
      'macAddress': macAddress,
      'capabilities': capabilities,
    });
    if (failReport) throw const ApiException('Test outage');
  }

  @override
  Future<List<Map<String, Object?>>> getArticles() async => [];
  @override
  Future<void> logout() async {}
}

class _Ring extends Fake implements WearableBridge {
  final source = StreamController<WearableEvent>.broadcast();
  bool failConnect = false;
  bool supportsHistorySync = true;
  int historyReads = 0;
  Completer<DeviceCapabilities>? delayedCapabilities;
  @override
  Stream<WearableEvent> get events => source.stream;
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    if (failConnect) throw StateError('Test handshake failure');
  }

  @override
  Future<void> disconnect() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      delayedCapabilities?.future ??
      Future.value(
        DeviceCapabilities(
          metrics: const {HealthMetric.heartRate},
          supportsHistorySync: supportsHistorySync,
        ),
      );
  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    historyReads++;
    return [];
  }

  @override
  Future<List<SportRecord>> readSportRecords() async => [];
}

class _FirstApi extends _Api implements SayRingFirstBindingApi {
  bool shouldClear = true, failFirst = false;
  int firstReports = 0;
  Completer<bool>? decision;
  @override
  Future<bool> reportFirstRingBinding({
    required Session expectedSession,
    required String deviceId,
    required String vendor,
    required String model,
    required String displayName,
    String? firmware,
    String? macAddress,
    List<String> capabilities = const [],
  }) async {
    firstReports++;
    if (failFirst) throw const ApiException('Test unavailable');
    return decision?.future ?? Future.value(shouldClear);
  }
}

class _ClearRing extends _Ring
    implements WearableRingDataClearBridge, WearableBindingManagementBridge {
  DeviceInfo? saved;
  int clears = 0;
  String? clearOwner;
  bool failClear = false;
  bool failRead = false;
  bool factoryAllowed = false;
  RingDataClearResult result = RingDataClearResult.acknowledged;
  @override
  Future<void> setRecoveryContext({
    required String? ownerKey,
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<DeviceInfo?> readRememberedDevice() async {
    if (failRead) throw StateError('Test storage unavailable');
    return saved;
  }

  @override
  Future<DeviceInfo?> prepareRememberedDevice() async => saved;
  @override
  Future<void> forgetRememberedDevice() async {
    saved = null;
  }

  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {
    await super.connect(deviceId, profile: profile);
    saved = _device;
  }

  @override
  Future<RingDataClearResult> clearRingHistory({
    required String deviceId,
    required String ownerKey,
    bool allowFactoryReset = false,
  }) async {
    clears++;
    factoryAllowed = allowFactoryReset;
    clearOwner = ownerKey;
    if (failClear) throw StateError('Test clear unconfirmed');
    return result;
  }
}
