import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/sync_diagnostics.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/sync_diagnostics_service.dart';

Session owner(String id) => Session(
  accessToken: 'synthetic-$id',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  displayName: 'Synthetic',
  accountKey: 'global:$id',
);
Map<String, Object?> snapshot({String model = 'R7Pro'}) =>
    diagnosticDeviceSnapshot(
      platform: 'android',
      sdk: 'coolwear',
      model: model,
      firmware: '819.0.1.0.0',
      connectionState: 'ready',
      initializationState: 'ready',
      capabilityState: 'ready',
      metrics: ['heart_rate'],
    );

class Remote extends Fake
    implements SaydianApi, SyncDiagnosticsApi, FirstConnectionDiagnosticsApi {
  final reports = <Map<String, Object?>>[],
      starts = <String>[],
      owners = <String>[];
  bool eligible = true,
      offline = false,
      beginOffline = false,
      needsProof = false,
      wrongReceipt = false;
  Completer<void>? beginGate;
  @override
  Future<bool> supportsSyncDiagnostics(Session s) async => true;
  @override
  Future<Map<String, Object?>> beginFirstConnectionDiagnostics(
    Session s,
    String id, {
    String? firstBindingOperationId,
  }) async {
    starts.add(id);
    if (beginGate != null) await beginGate!.future;
    if (beginOffline) throw const ApiException('Synthetic offline');
    final accepted =
        eligible && (!needsProof || firstBindingOperationId != null);
    return {
      'connectionId': id,
      'accepted': accepted,
      if (!accepted) 'reason': 'has_binding_history',
    };
  }

  @override
  Future<Map<String, Object?>> submitSyncDiagnostics(
    Session s,
    Map<String, Object?> report,
  ) async {
    reports.add(jsonDecode(jsonEncode(report)) as Map<String, Object?>);
    owners.add(s.memberId);
    if (offline) throw const ApiException('Synthetic offline');
    return {
      'accepted': true,
      'reportId': wrongReceipt ? 'wrong' : report['reportId'],
    };
  }
}

class V2Remote extends Remote implements SyncDiagnosticsVersionsApi {
  @override
  Future<int> syncDiagnosticSchema(Session expectedSession) async => 2;
}

Future<void> settle() async {
  for (var i = 0; i < 160; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemorySessionVault vault;
  late Remote remote;
  late SyncDiagnosticsService service;
  late Session? current;
  late DateTime now;
  late bool consent;
  late String model;
  SyncDiagnosticsService create({Map<String, Object?>? details}) =>
      SyncDiagnosticsService(
        vault: vault,
        api: remote,
        session: () => current,
        allowed: () => consent,
        snapshot: () => snapshot(model: model),
        onChanged: () {},
        locale: () => 'en',
        clock: () => now,
        metadata: () async =>
            details ??
            {
              'appVersion': '1.0.14',
              'buildNumber': 1310,
              'osMajor': 12,
              'osVersion': '12.0',
            },
      );
  void start([String target = 'PRIVATE-NATIVE-ID']) => service.begin(
    'global:${current!.memberId}',
    target,
    connectionAttempt: true,
  );
  void healthy() {
    service.record(SyncDiagnosticStage.connect, SyncDiagnosticState.ok);
    service.record(
      SyncDiagnosticStage.read,
      SyncDiagnosticState.ok,
      received: 7,
    );
    service.record(
      SyncDiagnosticStage.persist,
      SyncDiagnosticState.ok,
      saved: 7,
    );
    service.record(
      SyncDiagnosticStage.upload,
      SyncDiagnosticState.ok,
      uploaded: 7,
    );
    service.completeInitialSync(service.connectionGeneration);
  }

  setUp(() {
    vault = MemorySessionVault();
    remote = Remote();
    current = owner('a');
    now = DateTime.utc(2026, 11, 16);
    consent = true;
    model = 'R7Pro';
    service = create();
  });
  tearDown(() => service.dispose());

  test('Bluetooth off remains a V2 reason with a compatible V1 payload', () {
    final stage = SyncDiagnosticEvent(
      SyncDiagnosticStage.connect,
      SyncDiagnosticState.failed,
      connectionDiagnosticCode('BLUETOOTH_DISABLED'),
      430,
    ).toJson();
    final downlevel = syncDiagnosticForV1({
      'schemaVersion': 2,
      'phone': {'modelId': 'PPA-LX3'},
      'stages': [stage],
    });
    expect(stage['code'], 'bluetooth_off');
    expect(downlevel.containsKey('phone'), isFalse);
    expect((downlevel['stages'] as List).single['code'], 'connect_failed');
  });

  for (final version in [1, 2]) {
    for (final code in [
      SyncDiagnosticCode.bluetoothOff,
      SyncDiagnosticCode.bluetoothPermission,
      SyncDiagnosticCode.connectionTimeout,
      SyncDiagnosticCode.handshakeFailed,
    ]) {
      test(
        'first $code failure remains deliverable on schema $version',
        () async {
          service.dispose();
          remote = version == 2 ? V2Remote() : Remote();
          service = create();
          start();
          await settle();
          service.record(
            SyncDiagnosticStage.connect,
            SyncDiagnosticState.failed,
            code: code,
          );
          await settle();
          expect(remote.reports, hasLength(1));
          final report = remote.reports.single;
          expect(report['schemaVersion'], version);
          expect(report['mode'], 'first_connection');
          expect(
            (report['stages'] as List).single['code'],
            version == 2 ? code.wireName : 'connect_failed',
          );
          expect(isBoundedDiagnosticReport(report), isTrue);
        },
      );
    }
    test('first summary retains phone data only on schema $version', () async {
      service.dispose();
      remote = version == 2 ? V2Remote() : Remote();
      service = create(
        details: {
          'appVersion': '1.0.15',
          'buildNumber': 1315,
          'osMajor': 12,
          'osVersion': '12.0',
          'phone': {
            'brand': 'HUAWEI',
            'modelId': 'PPA-LX3',
            'apiLevel': 31,
            'name': 'Private phone name',
          },
        },
      );
      start();
      healthy();
      await settle();
      expect(remote.reports, hasLength(1));
      final report = remote.reports.single;
      expect(report['schemaVersion'], version);
      expect(report['mode'], 'first_connection');
      expect(isBoundedDiagnosticReport(report), isTrue);
      if (version == 2) {
        expect(report['phone'], {
          'brand': 'HUAWEI',
          'modelId': 'PPA-LX3',
          'apiLevel': 31,
          'locale': 'en',
        });
      } else {
        expect(report.containsKey('phone'), isFalse);
      }
      start('another-device');
      healthy();
      await settle();
      expect(remote.reports, hasLength(1));
    });
  }

  test(
    'guest context stays local until requested for its support session',
    () async {
      service.dispose();
      current = null;
      var metadataReads = 0;
      service = SyncDiagnosticsService(
        vault: vault,
        api: remote,
        session: () => current,
        allowed: () => false,
        snapshot: snapshot,
        onChanged: () {},
        metadata: () async {
          metadataReads++;
          return {
            'appVersion': '1.0.15',
            'buildNumber': 1315,
            'phone': {'brand': 'HUAWEI', 'modelId': 'PPA-LX3'},
          };
        },
      );
      service.begin('anonymous', 'PRIVATE-NATIVE-ID', connectionKind: 'first');
      service.record(SyncDiagnosticStage.connect, SyncDiagnosticState.ok);
      await settle();
      expect(metadataReads, 0);
      expect(remote.starts, isEmpty);
      expect(remote.reports, isEmpty);
      final context = await service.guestConnection('en');
      expect(context, isNotNull);
      expect(isBoundedDiagnosticReport(context!), isTrue);
      expect((context['phone'] as Map)['modelId'], 'PPA-LX3');
      expect(jsonEncode(context), isNot(contains('PRIVATE-NATIVE-ID')));
      expect(remote.reports, isEmpty);
      current = owner('b');
      expect(await service.guestConnection('en'), isNull);
    },
  );
  test(
    'healthy first sync automatically reports system/app, connection, read, save and upload',
    () async {
      start();
      await settle();
      service.record(SyncDiagnosticStage.connect, SyncDiagnosticState.ok);
      await settle();
      expect(remote.reports, isEmpty);
      healthy();
      await settle();
      expect(remote.reports, hasLength(1));
      final r = remote.reports.single;
      expect(r['mode'], 'first_connection');
      expect(r['osVersion'], '12.0');
      expect(r['buildNumber'], 1310);
      expect((r['stages'] as List).map((e) => e['stage']), [
        'connect',
        'read',
        'persist',
        'upload',
      ]);
      expect(isBoundedDiagnosticReport(r), isTrue);
      expect(jsonEncode(r), isNot(contains('PRIVATE-NATIVE-ID')));
      expect(jsonEncode(r), isNot(contains('synthetic-a')));
      expect((await vault.readSyncDiagnostics('global:a'))!['pending'], isNull);
    },
  );
  test(
    'later reconnects, failures, repeated completions and manual entry never upload new data',
    () async {
      start();
      healthy();
      await settle();
      start();
      service.record(SyncDiagnosticStage.read, SyncDiagnosticState.failed);
      healthy();
      await service.send();
      await service.send(mode: 'automatic');
      service.flushPending();
      await settle();
      expect(remote.starts, hasLength(1));
      expect(remote.reports, hasLength(1));
      service.dispose();
      service = create();
      start();
      healthy();
      await settle();
      expect(remote.starts, hasLength(1));
      expect(remote.reports, hasLength(1));
    },
  );
  test(
    'existing-account refusal is persisted and is not retried on later connections',
    () async {
      remote.eligible = false;
      start();
      await settle();
      healthy();
      await settle();
      expect(remote.reports, isEmpty);
      expect(remote.starts, hasLength(1));
      service.dispose();
      service = create();
      start();
      healthy();
      service.flushPending();
      await settle();
      expect(remote.starts, hasLength(1));
      expect(remote.reports, isEmpty);
    },
  );
  test(
    'a failed first connection reports once and is not replaced by a later healthy connection',
    () async {
      start();
      service.record(
        SyncDiagnosticStage.connect,
        SyncDiagnosticState.failed,
        code: SyncDiagnosticCode.connectFailed,
      );
      await settle();
      expect(remote.reports, hasLength(1));
      final first = remote.reports.single;
      start();
      healthy();
      await settle();
      expect(remote.reports, hasLength(1));
      expect((first['stages'] as List).single['state'], 'failed');
    },
  );
  testWidgets(
    'the watchdog reports pending initialization without fabricating a failure or reading',
    (tester) async {
      service.dispose();
      service = create();
      start();
      await tester.pump();
      service.record(
        SyncDiagnosticStage.initialization,
        SyncDiagnosticState.blocked,
        code: SyncDiagnosticCode.initializationPending,
      );
      await tester.pump();
      expect(remote.reports, isEmpty);
      await tester.pump(const Duration(minutes: 3));
      await tester.pumpAndSettle();
      expect(remote.reports, hasLength(1));
      expect(
        (remote.reports.single['stages'] as List).single['state'],
        'blocked',
      );
      service.dispose();
    },
  );
  test(
    'offline delivery retries the identical frozen first report after a restart and another target',
    () async {
      remote.offline = true;
      start();
      healthy();
      await settle();
      final first = Map<String, Object?>.from(remote.reports.single);
      service.dispose();
      service = create();
      model = 'R8';
      now = now.add(const Duration(minutes: 16));
      remote.offline = false;
      start('ANOTHER-PRIVATE-ID');
      healthy();
      await settle();
      expect(remote.reports, hasLength(2));
      expect(remote.reports.last, first);
      expect(remote.reports.last['model'], 'R7Pro');
      expect(remote.starts, hasLength(1));
    },
  );
  test(
    'a reservation response lost to network is retried with its original ID only',
    () async {
      remote.beginOffline = true;
      start();
      healthy();
      await settle();
      expect(remote.reports, isEmpty);
      final id = remote.starts.single;
      remote.beginOffline = false;
      now = now.add(const Duration(minutes: 16));
      service.flushPending();
      await settle();
      expect(remote.starts, [id, id]);
      expect(remote.reports, hasLength(1));
      start();
      healthy();
      await settle();
      expect(remote.reports, hasLength(1));
    },
  );
  test(
    'a genuine first-binding receipt repairs only the reservation race',
    () async {
      remote.needsProof = true;
      start();
      await settle();
      expect(remote.reports, isEmpty);
      service.authorizeFirstBinding(
        'WRONG-TARGET',
        '11111111-1111-4111-8111-111111111111',
      );
      await settle();
      expect(remote.starts, hasLength(1));
      service.authorizeFirstBinding(
        'PRIVATE-NATIVE-ID',
        '11111111-1111-4111-8111-111111111111',
      );
      await settle();
      healthy();
      await settle();
      expect(remote.reports, hasLength(1));
      expect(remote.starts, hasLength(2));
      expect(
        remote.reports.single.containsKey('firstBindingOperationId'),
        isFalse,
      );
    },
  );
  test(
    'account change rejects late authorization and cannot send old stages under the new account',
    () async {
      remote.beginGate = Completer();
      start();
      service.record(SyncDiagnosticStage.connect, SyncDiagnosticState.pending);
      await settle();
      current = owner('b');
      start('TARGET-B');
      remote.beginGate!.complete();
      await settle();
      healthy();
      await settle();
      expect(remote.owners, ['b']);
      expect(await vault.readSyncDiagnostics('global:b'), isNotNull);
    },
  );
  test(
    'guest and missing privacy consent prevent reservations and private writes',
    () async {
      consent = false;
      start();
      healthy();
      await settle();
      expect(remote.starts, isEmpty);
      expect(await vault.readSyncDiagnostics('global:a'), isNull);
      current = null;
      service.flushPending();
      await settle();
      expect(remote.reports, isEmpty);
    },
  );
  test(
    'a changed target freezes the previous target snapshot, not the new device',
    () async {
      start();
      service.record(SyncDiagnosticStage.connect, SyncDiagnosticState.ok);
      await settle();
      model = 'R8';
      start('TARGET-B');
      await settle();
      expect(remote.reports, hasLength(1));
      expect(remote.reports.single['model'], 'R7Pro');
      expect(
        (remote.reports.single['stages'] as List).last['code'],
        'cancelled',
      );
    },
  );
  test(
    'a crashed first draft keeps its original app version and is not replaced on upgrade',
    () async {
      start();
      service.record(SyncDiagnosticStage.connect, SyncDiagnosticState.ok);
      await settle();
      service.dispose();
      service = SyncDiagnosticsService(
        vault: vault,
        api: remote,
        session: () => current,
        allowed: () => consent,
        snapshot: () => snapshot(model: 'R8'),
        onChanged: () {},
        clock: () => now,
        metadata: () async => {'appVersion': '1.0.15', 'buildNumber': 1400},
      );
      start('OTHER-TARGET');
      healthy();
      await settle();
      expect(remote.reports, hasLength(1));
      expect(remote.reports.single['buildNumber'], 1310);
      expect(remote.reports.single['model'], 'R7Pro');
      expect(
        (remote.reports.single['stages'] as List).any(
          (e) => e['stage'] == 'read',
        ),
        isFalse,
      );
    },
  );
  test(
    'background progress without an explicit first attempt never reserves or sends',
    () async {
      service.begin('global:a', null);
      service.record(SyncDiagnosticStage.upload, SyncDiagnosticState.failed);
      await service.send();
      await settle();
      expect(remote.starts, isEmpty);
      expect(remote.reports, isEmpty);
    },
  );
  test(
    'wrong receipts retain the immutable first report and do not claim completion',
    () async {
      remote.wrongReceipt = true;
      start();
      healthy();
      await settle();
      expect(service.lastReportId, isNull);
      final stored = (await vault.readSyncDiagnostics('global:a'))!['pending'];
      expect(stored, remote.reports.single);
    },
  );
  test(
    'report validation rejects identifiers and non-numeric system version',
    () async {
      start();
      healthy();
      await settle();
      final first = remote.reports.single;
      expect(
        isBoundedDiagnosticReport({
          ...first,
          'osVersion': 'private-build-name',
        }),
        isFalse,
      );
      expect(
        isBoundedDiagnosticReport({...first, 'deviceId': 'PRIVATE'}),
        isFalse,
      );
    },
  );
}
