import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/domain/models.dart';
import 'first_connection_diagnostics_controller_test.dart' as diag;
import 'sync_diagnostics_recovery_test.dart' as fixture;

class AmbientErrorRing extends fixture.Ring {
  void Function()? unrelatedError;
  @override
  Future<DeviceCapabilities> getCapabilities() async {
    unrelatedError?.call();
    return super.getCapabilities();
  }
}

class ConnectFailureRing extends fixture.Ring {
  String? failure;
  @override
  Future<void> connect(String id, {WearableUserProfile? profile}) async {
    connects++;
    if (failure != null) throw PlatformException(code: failure!);
  }
}

class InitializationRetryRing extends fixture.Ring
    implements
        WearableBindingManagementBridge,
        WearableConnectionRecoveryBridge {
  DeviceInfo? saved;
  final recovery = Completer<DeviceInfo?>();
  int restores = 0;
  @override
  Future<void> connect(String id, {WearableUserProfile? profile}) async {
    connects++;
    saved = fixture.device;
    if (connects == 2) throw PlatformException(code: 'CONNECT_TIMEOUT');
  }

  @override
  Future<void> setRecoveryContext({
    required String? ownerKey,
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<DeviceInfo?> readRememberedDevice() async => saved;
  @override
  Future<DeviceInfo?> prepareRememberedDevice() async => saved;
  @override
  Future<void> forgetRememberedDevice() async {
    saved = null;
  }

  @override
  Future<DeviceInfo?> restoreConnection({
    required WearableUserProfile profile,
  }) async {
    if (saved == null) return null;
    restores++;
    return recovery.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<(AppController, diag.EvidenceRemote)> setup(
    fixture.Ring ring, {
    bool clear = false,
  }) async {
    PackageInfo.setMockInitialValues(
      appName: 'Say Ring',
      packageName: 'cn.saydian.ring',
      version: '1.0.15',
      buildNumber: '1322',
      buildSignature: 'synthetic',
    );
    final api = diag.EvidenceRemote()..firstClear = clear;
    final app = AppController(
      MemorySessionVault()..privacyConsentGranted = true,
      api,
      MemoryHealthStore(),
      ring,
    );
    addTearDown(app.dispose);
    addTearDown(ring.source.close);
    await app.initialize();
    app.session = Session(
      accessToken: 'synthetic',
      refreshToken: '',
      expiresAt: DateTime.utc(2099),
      memberId: 'first-outcome',
      displayName: 'Synthetic',
      accountKey: 'global:first-outcome',
    );
    return (app, api);
  }

  test(
    'unrelated UI errors cannot turn a ready connection into a failed first report',
    () async {
      final ring = AmbientErrorRing();
      final (app, api) = await setup(ring);
      ring.unrelatedError = () =>
          app.errorMessage = 'Synthetic unrelated content failure';
      await app.connectDevice(fixture.device);
      await fixture.settle();
      await fixture.settle();
      expect(app.connectedDevice?.id, fixture.device.id);
      expect(app.deviceState, DeviceConnectionState.ready);
      final stages = api.reports.single['stages'] as List;
      expect(
        stages.any((r) => r['stage'] == 'connect' && r['state'] == 'ok'),
        isTrue,
      );
      expect(
        stages.any((r) => r['stage'] == 'connect' && r['state'] == 'failed'),
        isFalse,
      );
      expect(stages.any((r) => r['stage'] == 'read'), isTrue);
      expect(ring.clears, 0);
    },
  );
  test(
    'real connection failure remains immutable after a later explicit success',
    () async {
      final ring = ConnectFailureRing()..failure = 'CONNECT_TIMEOUT';
      final (app, api) = await setup(ring);
      await app.connectDevice(fixture.device);
      await fixture.settle();
      expect(app.deviceState, DeviceConnectionState.error);
      final first = api.reports.single;
      expect(
        (first['stages'] as List).any(
          (r) => r['stage'] == 'connect' && r['state'] == 'failed',
        ),
        isTrue,
      );
      ring.failure = null;
      await app.connectDevice(fixture.device);
      await fixture.settle();
      expect(app.connectedDevice?.id, fixture.device.id);
      expect(api.reports, hasLength(1));
      expect(api.reports.single, first);
      expect(ring.clears, 0);
    },
  );
  test('cancelled connection does not fabricate a failure outcome', () async {
    final ring = ConnectFailureRing()..failure = 'CONNECT_CANCELLED';
    final (app, api) = await setup(ring);
    await app.connectDevice(fixture.device);
    await fixture.settle();
    expect(app.connectedDevice, isNull);
    expect(api.reports, isEmpty);
    expect(
      app.syncDiagnostics.events.any((e) => e.state.name == 'failed'),
      isFalse,
    );
  });
  test(
    'ACK initialization reconnect stays in one first window until sync finishes',
    () async {
      final ring = InitializationRetryRing();
      final (app, api) = await setup(ring, clear: true);
      await app.connectDevice(fixture.device);
      await fixture.settle();
      await fixture.settle();
      expect(ring.connects, 2);
      expect(ring.restores, 1);
      expect(ring.clears, 1);
      expect(
        api.reports,
        isEmpty,
        reason: 'the required initialization reconnect has not finished',
      );
      ring.recovery.complete(fixture.device);
      await fixture.settle();
      await fixture.settle();
      expect(app.connectedDevice?.id, fixture.device.id);
      expect(app.deviceState, DeviceConnectionState.ready);
      final stages = api.reports.single['stages'] as List;
      expect(
        stages.any((r) => r['stage'] == 'connect' && r['state'] == 'ok'),
        isTrue,
      );
      expect(stages.any((r) => r['stage'] == 'read'), isTrue);
      expect(stages.any((r) => r['stage'] == 'persist'), isTrue);
      expect(ring.clears, 1);
      expect(api.firstDecisions, 1);
      expect(api.reservations, 1);
    },
  );
}
