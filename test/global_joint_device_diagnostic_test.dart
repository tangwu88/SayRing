import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/device_state_machine.dart';
import 'package:saydian_app/debug/global_joint_device_diagnostic.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/app_controller.dart';

const _target = 'veepoo:private-test-target-not-for-output';
const _fast = GlobalJointQaTiming(
  operation: Duration(milliseconds: 80),
  sync: Duration(milliseconds: 80),
  poll: Duration(milliseconds: 1),
  betweenConnections: Duration.zero,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QA environment only permits exact new-domain isolated route', () {
    expect(
      isApprovedGlobalJointQaEnvironment(
        Uri.parse('https://app.saydian.cn'),
        '/global/api/saydian-app/v2',
      ),
      isTrue,
    );
    for (final origin in [
      'http://127.0.0.1:8082',
      'https://app.saidian.cc',
      'https://app.saydian.cn:8443',
      'https://user@app.saydian.cn',
    ]) {
      expect(
        isApprovedGlobalJointQaEnvironment(
          Uri.parse(origin),
          '/global/api/saydian-app/v2',
        ),
        isFalse,
      );
    }
    expect(
      isApprovedGlobalJointQaEnvironment(
        Uri.parse('https://app.saydian.cn'),
        '/api/saydian-app/v2',
      ),
      isFalse,
    );
    expect(
      File('lib/main.dart').readAsStringSync(),
      isNot(contains('global_joint')),
    );
    expect(
      File('lib/main_global_joint_qa.dart').readAsStringSync(),
      contains('allowAutomaticWearableRestore: false'),
    );
  });

  test(
    'private config requires scoped exact ID and refuses ambiguous authorization',
    () {
      for (final values in <Map<String, Object?>>[
        {'targetDeviceId': 'same-model-name'},
        {'targetDeviceId': _target, 'username': 'qa@example.test'},
        {'targetDeviceId': _target, 'deviceOnly': 'true'},
        {
          'targetDeviceId': _target,
          'deviceOnly': true,
          'username': 'qa@example.test',
          'password': 'secret',
        },
        {'targetDeviceId': _target, 'resetWatch': true},
      ]) {
        expect(
          () => GlobalJointQaConfig.fromJson(values),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'without private config no scan, login, preview or device mutation occurs',
    () async {
      final controller = _FakeController();
      final logs = <Map<String, Object?>>[];
      await runGlobalJointDeviceDiagnostic(
        controller,
        readConfig: () async => null,
        log: logs.add,
        timing: _fast,
      );
      expect(
        controller.scanCount +
            controller.loginCount +
            controller.previewCount +
            controller.connectCount,
        0,
      );
      expect(logs.single['reason'], 'private_config_missing');
    },
  );

  test(
    'device-only guest completes three exact cycles and remains on target',
    () async {
      final controller = _FakeController();
      final logs = await _run(controller, deviceOnly: true);
      expect(controller.scanCount, 3);
      expect(controller.connectCount, 3);
      expect(controller.disconnectCount, 2);
      expect(controller.syncCount, 3);
      expect(controller.featureReads, [DeviceFeature.watchFaces]);
      expect(
        controller.actionCount + controller.loginCount + controller.cloudCount,
        0,
      );
      expect(controller.connectedDevice?.id, _target);
      expect(logs.last['completedRounds'], 3);
      expect(logs.last['cloudAccepted'], isFalse);
      expect(logs.last['status'], 'partial');
      expect(jsonEncode(logs), isNot(contains(_target)));
      expect(
        jsonEncode(logs),
        isNot(contains('fixture-private-health-record')),
      );
    },
  );

  test('device-only refuses to log out or reuse an existing account', () async {
    final controller = _FakeController()..session = _session('existing-user');
    final logs = await _run(controller, deviceOnly: true);
    expect(
      controller.scanCount + controller.loginCount + controller.previewCount,
      0,
    );
    expect(controller.session?.memberId, 'existing-user');
    expect(
      logs.any((row) => row['reason'] == 'device_only_requires_signed_out'),
      isTrue,
    );
  });

  test(
    'global realm rejection blocks credentials and all watch commands',
    () async {
      final controller = _FakeController()..rejectRealm = true;
      final logs = await _run(controller);
      expect(controller.capabilitiesCalls, 1);
      expect(controller.loginCount + controller.scanCount, 0);
      expect(logs.last['status'], 'failed');
      expect(jsonEncode(logs), isNot(contains('never-record-test-password')));
      expect(jsonEncode(logs), isNot(contains('qa@example.test')));
    },
  );

  test(
    'dedicated account requires real login and still leaves server readback unverified',
    () async {
      final controller = _FakeController();
      final logs = await _run(controller);
      expect(controller.callOrder.take(2), ['capabilities', 'login']);
      expect(controller.loginCount, 1);
      expect(controller.cloudCount, 1);
      expect(logs.last['completedRounds'], 3);
      expect(logs.last['cloudAccepted'], isFalse);
      expect(
        logs.any(
          (row) =>
              row['case'] == 'pending_upload_count' &&
              row['status'] == 'not_verified',
        ),
        isTrue,
      );
      expect(jsonEncode(logs), isNot(contains('never-record-test-password')));
    },
  );

  test('similar device names never authorize a different target', () async {
    final controller = _FakeController()
      ..available = const [
        DeviceInfo(id: 'veepoo:another-private-id', name: 'Same model'),
      ];
    final logs = await _run(controller, deviceOnly: true);
    expect(controller.connectCount, 0);
    expect(logs.last['completedRounds'], 0);
    expect(jsonEncode(logs), isNot(contains('another-private-id')));
  });

  test(
    'sync timeout aborts rather than enqueueing a disconnect or next connection',
    () async {
      final blocked = Completer<void>();
      final controller = _FakeController()..pendingSync = blocked.future;
      final logs = await _run(controller, deviceOnly: true);
      expect(controller.connectCount, 1);
      expect(controller.disconnectCount, 0);
      expect(logs.last['status'], 'failed');
      expect(logs.any((row) => row['reason'] == 'TimeoutException'), isTrue);
      blocked.complete();
    },
  );

  test(
    'account change during a device operation stops further QA actions',
    () async {
      final controller = _FakeController();
      controller.onSync = () =>
          controller.session = _session('another-account');
      final logs = await _run(controller, deviceOnly: true);
      expect(controller.connectCount, 1);
      expect(controller.disconnectCount, 0);
      expect(logs.any((row) => row['reason'] == 'account_changed'), isTrue);
    },
  );

  test(
    'settle timeout terminates polling instead of leaving an endless waiter',
    () async {
      final controller = _FakeController()..busySync = true;
      final logs = await _run(controller, deviceOnly: true);
      expect(controller.scanCount, 0);
      expect(logs.last['status'], 'failed');
      final readsAfterTimeout = controller.syncStateReads;
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(controller.syncStateReads, readsAfterTimeout);
    },
  );
}

Future<List<Map<String, Object?>>> _run(
  _FakeController controller, {
  bool deviceOnly = false,
}) async {
  final logs = <Map<String, Object?>>[];
  final config = GlobalJointQaConfig.fromJson({
    'targetDeviceId': _target,
    'deviceOnly': deviceOnly,
    if (!deviceOnly) 'username': 'qa@example.test',
    if (!deviceOnly) 'password': 'never-record-test-password',
  });
  await runGlobalJointDeviceDiagnostic(
    controller,
    readConfig: () async => config,
    log: logs.add,
    timing: _fast,
  );
  return logs;
}

Session _session(String account) => Session(
  accessToken: 'fixture-token',
  refreshToken: 'fixture-refresh',
  expiresAt: DateTime.utc(2030),
  memberId: account,
  displayName: 'Fixture',
);

class _FakeController extends Fake implements AppController {
  @override
  final DeviceStateMachine deviceMachine = DeviceStateMachine();
  int scanCount = 0;
  int loginCount = 0;
  int previewCount = 0;
  int connectCount = 0;
  int disconnectCount = 0;
  int syncCount = 0;
  int cloudCount = 0;
  int capabilitiesCalls = 0;
  int actionCount = 0;
  bool rejectRealm = false;
  bool busySync = false;
  int syncStateReads = 0;
  Future<void>? pendingSync;
  void Function()? onSync;
  final callOrder = <String>[];
  final featureReads = <DeviceFeature>[];
  List<DeviceInfo> available = const [
    DeviceInfo(id: _target, name: 'Same model'),
  ];
  @override
  Session? session;
  @override
  DeviceInfo? connectedDevice;
  @override
  List<DeviceInfo> scannedDevices = [];
  @override
  String? errorMessage;
  @override
  List<HealthRecord> healthRecords = [];
  @override
  bool get isAuthenticated => session != null;
  @override
  bool get isBusy => false;
  @override
  bool get isDeviceSyncing {
    syncStateReads++;
    return busySync;
  }

  @override
  bool get isDeviceSettingsLoading => false;
  @override
  Set<DeviceFeature> get deviceFeatureBusy => {};
  @override
  HealthMetric? get activeMeasurementMetric => null;
  @override
  SportMode? get activeSport => null;
  @override
  DeviceConnectionState get deviceState => connectedDevice == null
      ? DeviceConnectionState.disconnected
      : DeviceConnectionState.ready;
  @override
  DeviceCapabilityState get deviceCapabilityState =>
      DeviceCapabilityState.ready;
  @override
  DeviceCapabilities get capabilities => const DeviceCapabilities(
    metrics: {HealthMetric.heartRate},
    features: {DeviceFeature.watchFaces},
    integratedFeatures: {DeviceFeature.watchFaces},
  );
  @override
  Set<DeviceFeature> get visibleDeviceFeatures => capabilities.features;
  @override
  void clearError() {
    errorMessage = null;
  }

  @override
  void selectTab(int index) {}
  @override
  void enterPreview() {
    previewCount++;
  }

  @override
  Future<GlobalAuthCapabilities> globalAuthCapabilities() async {
    capabilitiesCalls++;
    callOrder.add('capabilities');
    return GlobalAuthCapabilities.fromJson({
      'realm': rejectRealm ? 'domestic' : 'global',
      'registration': {'email': true, 'sms': false},
    });
  }

  @override
  Future<bool> login(
    String username,
    String password, {
    bool privacyConsentGranted = false,
  }) async {
    loginCount++;
    callOrder.add('login');
    session = _session('dedicated-test-account');
    return true;
  }

  @override
  Future<void> scanDevices() async {
    scanCount++;
    deviceMachine.transition(DeviceConnectionState.scanning);
    scannedDevices = available;
  }

  @override
  Future<void> connectDevice(DeviceInfo device) async {
    connectCount++;
    deviceMachine.transition(DeviceConnectionState.connecting);
    deviceMachine.transition(DeviceConnectionState.authenticating);
    deviceMachine.transition(DeviceConnectionState.syncing);
    deviceMachine.transition(DeviceConnectionState.ready);
    connectedDevice = device;
  }

  @override
  Future<void> disconnectDevice() async {
    disconnectCount++;
    deviceMachine.transition(DeviceConnectionState.disconnected);
    connectedDevice = null;
  }

  @override
  Future<bool> refreshConnectedDeviceDetails() async => true;
  @override
  Future<void> syncDeviceData() async {
    syncCount++;
    await pendingSync;
    onSync?.call();
    healthRecords = [
      HealthRecord(
        id: 'fixture-private-health-record',
        metric: HealthMetric.heartRate,
        values: const {'value': 72},
        unit: 'bpm',
        measuredAt: DateTime.utc(2026, 9, 9),
        timezone: '+00:00',
        deviceId: 'private-watch-id',
        firmwareVersion: 'fixture',
        quality: 'good',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      ),
    ];
  }

  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async {
    featureReads.add(feature);
    return {'items': []};
  }

  @override
  Future<bool> triggerDeviceAction(
    DeviceFeature feature, {
    bool enabled = true,
  }) async {
    actionCount++;
    return true;
  }

  @override
  Future<void> synchronizeCloud() async {
    cloudCount++;
  }
}
