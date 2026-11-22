import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/domain/models.dart';
import 'sync_diagnostics_recovery_test.dart' as fixture;

class Remote extends fixture.Remote
    implements SyncDiagnosticsApi, FirstConnectionDiagnosticsApi {
  final reports = <Map<String, Object?>>[];
  int reservations = 0;
  Completer<void>? gate;
  @override
  Future<bool> supportsSyncDiagnostics(Session s) async => true;
  @override
  Future<Map<String, Object?>> beginFirstConnectionDiagnostics(
    Session s,
    String id, {
    String? firstBindingOperationId,
  }) async {
    reservations++;
    if (gate != null) await gate!.future;
    return {'accepted': true, 'connectionId': id};
  }

  @override
  Future<Map<String, Object?>> submitSyncDiagnostics(
    Session s,
    Map<String, Object?> report,
  ) async {
    reports.add(report);
    return {'accepted': true, 'reportId': report['reportId']};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'first connection reports genuine empty read/save/upload outcomes; diagnostic slowness never blocks BLE or another sync',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'Say Ring',
        packageName: 'cn.saydian.ring',
        version: '1.0.14',
        buildNumber: '1310',
        buildSignature: 'synthetic',
      );
      final api = Remote()..gate = Completer(), ring = fixture.Ring();
      final vault = MemorySessionVault()..privacyConsentGranted = true;
      final app = AppController(vault, api, MemoryHealthStore(), ring);
      addTearDown(app.dispose);
      addTearDown(ring.source.close);
      await app.initialize();
      app.session = Session(
        accessToken: 'synthetic',
        refreshToken: '',
        expiresAt: DateTime.utc(2099),
        memberId: 'member-a',
        displayName: 'Synthetic',
        accountKey: 'global:member-a',
      );
      await app.connectDevice(fixture.device);
      await fixture.settle();
      expect(app.connectedDevice?.id, fixture.device.id);
      expect(app.isDeviceSyncing, isFalse);
      expect(ring.reads, greaterThan(0));
      expect(api.reports, isEmpty);
      api.gate!.complete();
      await fixture.settle();
      await fixture.settle();
      expect(api.reports, hasLength(1));
      final stages = api.reports.single['stages'] as List;
      expect(
        stages.any((e) => e['stage'] == 'connect' && e['state'] == 'ok'),
        isTrue,
      );
      expect(
        stages.any((e) => e['stage'] == 'read' && e['state'] == 'empty'),
        isTrue,
      );
      expect(
        stages.any((e) => e['stage'] == 'persist' && e['state'] == 'ok'),
        isTrue,
      );
      expect(
        stages.any((e) => e['stage'] == 'upload' && e['state'] == 'empty'),
        isTrue,
      );
      await app.connectDevice(fixture.device);
      await fixture.settle();
      expect(api.reports, hasLength(1));
      expect(api.reservations, 1);
      expect(ring.clears, 0);
    },
  );
}
