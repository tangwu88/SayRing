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
Map<String, Object?> snapshot() => diagnosticDeviceSnapshot(
  platform: 'android',
  sdk: 'coolwear',
  model: 'R7Pro',
  firmware: '819.0.1.0.0',
  connectionState: 'ready',
  initializationState: 'ready',
  capabilityState: 'ready',
  metrics: ['heart_rate'],
);

class Remote extends Fake implements SaydianApi, SyncDiagnosticsApi {
  final reports = <Map<String, Object?>>[];
  final owners = <String>[];
  bool supported = true, offline = false, limited = false, wrongReceipt = false;
  int configReads = 0;
  Completer<bool>? config;
  @override
  Future<bool> supportsSyncDiagnostics(Session expectedSession) async {
    configReads++;
    return config == null ? supported : await config!.future;
  }

  @override
  Future<Map<String, Object?>> submitSyncDiagnostics(
    Session expectedSession,
    Map<String, Object?> report,
  ) async {
    reports.add(jsonDecode(jsonEncode(report)) as Map<String, Object?>);
    owners.add(expectedSession.memberId);
    if (offline) {
      throw const ApiException('Synthetic transport error', statusCode: 503);
    }
    return {
      'accepted': !limited,
      'reportId': wrongReceipt ? 'wrong' : report['reportId'],
      if (limited) 'retryAfterSeconds': 900,
    };
  }
}

Future<void> settle() async {
  for (var i = 0; i < 60; i++) {
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
  setUp(() {
    vault = MemorySessionVault();
    remote = Remote();
    current = owner('a');
    consent = true;
    now = DateTime.utc(2026, 11, 14);
    service = SyncDiagnosticsService(
      vault: vault,
      api: remote,
      session: () => current,
      allowed: () => consent,
      snapshot: snapshot,
      onChanged: () {},
      clock: () => now,
      metadata: () async => {'appVersion': '1.0.14', 'buildNumber': 1307},
    );
    service.begin('global:a', 'PRIVATE-NATIVE-IDENTIFIER');
  });
  tearDown(() => service.dispose());

  test(
    'automatic failure summary contains only fixed metadata, enums and counts',
    () async {
      service.record(SyncDiagnosticStage.connect, SyncDiagnosticState.ok);
      service.record(
        SyncDiagnosticStage.read,
        SyncDiagnosticState.failed,
        code: SyncDiagnosticCode.readTimeout,
        received: 0,
      );
      await settle();
      expect(remote.reports, hasLength(1));
      final report = remote.reports.single;
      expect(isBoundedDiagnosticReport(report), isTrue);
      final text = jsonEncode(report);
      expect(text, isNot(contains('PRIVATE-NATIVE-IDENTIFIER')));
      expect(text, isNot(contains('synthetic-a')));
      expect(text, isNot(contains('global:a')));
      expect(report['mode'], 'automatic');
      expect(report['buildNumber'], 1307);
      expect((await vault.readSyncDiagnostics('global:a'))!['pending'], isNull);
      expect(service.lastReportId, report['reportId']);
    },
  );

  test(
    'empty reads report no-data evidence without claiming a sensor failure',
    () async {
      service.record(
        SyncDiagnosticStage.read,
        SyncDiagnosticState.empty,
        code: SyncDiagnosticCode.noData,
        received: 0,
      );
      await settle();
      expect(remote.reports, hasLength(1));
      expect(
        (remote.reports.single['stages'] as List).last,
        containsPair('state', 'empty'),
      );
      service.record(
        SyncDiagnosticStage.read,
        SyncDiagnosticState.empty,
        code: SyncDiagnosticCode.noData,
        received: 0,
      );
      await settle();
      expect(remote.reports, hasLength(1));
    },
  );

  test('healthy progress never sends automatic traffic', () async {
    service.record(
      SyncDiagnosticStage.read,
      SyncDiagnosticState.ok,
      received: 3,
    );
    await settle();
    expect(remote.configReads, 0);
    expect(remote.reports, isEmpty);
  });

  test(
    'guest, preview/privacy gate prevents requests and outbox writes',
    () async {
      consent = false;
      service.record(SyncDiagnosticStage.read, SyncDiagnosticState.failed);
      await service.send();
      await settle();
      expect(remote.configReads, 0);
      expect(await vault.readSyncDiagnostics('global:a'), isNull);
      consent = true;
      current = null;
      await service.send();
      expect(remote.reports, isEmpty);
    },
  );

  test('automatic summaries are spaced by fifteen minutes per owner', () async {
    service.record(SyncDiagnosticStage.read, SyncDiagnosticState.failed);
    await settle();
    service.record(SyncDiagnosticStage.upload, SyncDiagnosticState.failed);
    await settle();
    expect(remote.reports, hasLength(1));
    now = now.add(const Duration(minutes: 16));
    service.record(SyncDiagnosticStage.upload, SyncDiagnosticState.failed);
    await settle();
    expect(remote.reports, hasLength(2));
  });

  test('manual upload remains available during automatic cooldown', () async {
    service.record(SyncDiagnosticStage.read, SyncDiagnosticState.failed);
    await settle();
    await service.send();
    expect(remote.reports.map((r) => r['mode']), ['automatic', 'manual']);
  });

  test('single flight prevents repeated taps from posting twice', () async {
    remote.config = Completer();
    final first = service.send(), second = service.send();
    expect(identical(first, second), isTrue);
    remote.config!.complete(true);
    await first;
    expect(remote.reports, hasLength(1));
  });

  test(
    'network failure retains exact report ID and retries after backoff',
    () async {
      remote.offline = true;
      await service.send();
      final first = remote.reports.single;
      expect((await vault.readSyncDiagnostics('global:a'))!['pending'], first);
      service.flushPending();
      await settle();
      expect(remote.reports, hasLength(1));
      now = now.add(const Duration(minutes: 16));
      remote.offline = false;
      service.flushPending();
      await settle();
      expect(remote.reports, hasLength(2));
      expect(remote.reports.last['reportId'], first['reportId']);
      expect((await vault.readSyncDiagnostics('global:a'))!['pending'], isNull);
    },
  );

  test(
    'old server leaves a pending summary and manual can retry after server update',
    () async {
      remote.supported = false;
      expect(await service.send(), contains('后台'));
      expect(remote.reports, isEmpty);
      expect(
        (await vault.readSyncDiagnostics('global:a'))!['pending'],
        isNotNull,
      );
      service.record(SyncDiagnosticStage.read, SyncDiagnosticState.failed);
      await settle();
      expect(remote.configReads, 1);
      remote.supported = true;
      await service.send();
      expect(remote.reports, hasLength(1));
    },
  );

  test(
    'rate-limited or mismatching receipt never drops pending report',
    () async {
      remote.limited = true;
      await service.send();
      expect(
        (await vault.readSyncDiagnostics('global:a'))!['pending'],
        isNotNull,
      );
      now = now.add(const Duration(minutes: 16));
      remote.limited = false;
      remote.wrongReceipt = true;
      service.flushPending();
      await settle();
      expect(service.lastReportId, isNull);
      expect(
        (await vault.readSyncDiagnostics('global:a'))!['pending'],
        isNotNull,
      );
    },
  );

  test(
    'account switch during configuration cannot send under the new account',
    () async {
      remote.config = Completer();
      final sending = service.send();
      await settle();
      current = owner('b');
      service.begin('global:b', 'OTHER-PRIVATE-ID');
      remote.config!.complete(true);
      await sending;
      expect(remote.reports, isEmpty);
      expect(await vault.readSyncDiagnostics('global:b'), isNull);
      remote.config = null;
      await service.send();
      expect(remote.owners, ['b']);
    },
  );

  test(
    'corrupted outbox cannot upload arbitrary fields or raw values',
    () async {
      await vault.writeSyncDiagnostics('global:a', {
        'pending': {
          'product': 'say-ring',
          'healthValues': [72],
          'accessToken': 'synthetic-private',
        },
      });
      service.flushPending();
      await settle();
      expect(remote.reports, isEmpty);
    },
  );

  test(
    'bounded history and metadata drop unsupported model/metric/error data',
    () async {
      final safe = diagnosticDeviceSnapshot(
        platform: 'android',
        sdk: 'private',
        model: 'customer@example.com',
        firmware: 'private-secret',
        connectionState: 'raw-error',
        initializationState: 'raw-error',
        capabilityState: 'raw-error',
        metrics: ['heart_rate', 'private-record'],
      );
      expect(safe['sdk'], 'unknown');
      expect(safe['model'], 'other');
      expect(safe['metrics'], ['heart_rate']);
      expect(safe.containsKey('firmware'), isFalse);
      for (var i = 0; i < 100; i++) {
        service.record(
          i.isEven ? SyncDiagnosticStage.read : SyncDiagnosticStage.persist,
          SyncDiagnosticState.ok,
          saved: 2000000,
        );
      }
      expect(service.events, hasLength(16));
      await service.send();
      expect(isBoundedDiagnosticReport(remote.reports.single), isTrue);
      expect((remote.reports.single['stages'] as List).last['saved'], 1000000);
    },
  );
}
