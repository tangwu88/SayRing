import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/wearable_sync_result.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

const _device = DeviceInfo(
  id: 'coolwear:SYNTHETIC-R7P',
  name: 'R7 Pro',
  model: 'R7Pro',
);

class _Api extends Fake implements SaydianApi {
  final uploaded = <String, HealthRecord>{};
  @override
  Future<List<Map<String, Object?>>> getArticles() async => [];
  @override
  Future<BatchUploadResult> uploadHealthBatch(SyncBatch batch) async {
    uploaded.addAll({for (final record in batch.records) record.id: record});
    return BatchUploadResult(
      acceptedIds: batch.records.map((record) => record.id).toSet(),
      rejected: {},
      nextCursor: null,
    );
  }
}

class _Ring extends Fake implements WearableBridge {
  final source = StreamController<WearableEvent>.broadcast();
  bool resolved = false;
  bool retryFails = false;
  bool reportMissingCapabilities = true;
  String target = _device.id;
  int reads = 0;
  Completer<List<HealthRecord>>? initialRead;
  Completer<List<SportRecord>>? sportRead;

  @override
  Stream<WearableEvent> get events => source.stream;
  @override
  Future<void> connect(String id, {WearableUserProfile? profile}) async {
    target = id;
  }

  @override
  Future<void> disconnect() async {}
  @override
  Future<void> stopSport() async {}
  @override
  Future<void> startMeasurement(HealthMetric metric) async {}
  @override
  Future<void> stopMeasurement(HealthMetric metric) async {}
  @override
  Future<List<SportRecord>> readSportRecords() async =>
      sportRead == null ? [] : await sportRead!.future;
  @override
  Future<DeviceCapabilities> getCapabilities() async => DeviceCapabilities(
    metrics: {
      HealthMetric.steps,
      if (resolved) HealthMetric.heartRate,
      if (resolved) HealthMetric.bloodOxygen,
    },
  );

  @override
  Future<List<HealthRecord>> syncHealthData({String? cursor}) async {
    reads++;
    if (reads == 1 && initialRead != null) return initialRead!.future;
    if (!resolved || retryFails) {
      return WearableSyncResult([], {
        if (reportMissingCapabilities) '_capabilities': 'not_received',
        'steps': 'not_received',
      });
    }
    return [
      for (final metric in [HealthMetric.heartRate, HealthMetric.bloodOxygen])
        HealthRecord(
          id: 'synthetic-late-${metric.wireName}',
          metric: metric,
          values: {'value': metric == HealthMetric.heartRate ? 72 : 98},
          unit: metric.defaultUnit,
          measuredAt: DateTime.now(),
          timezone: '+08:00',
          deviceId: target,
          firmwareVersion: 'synthetic',
          quality: 'device_reported',
          source: MeasurementSource.wearable,
          sourceVendor: 'coolwear',
          rawVersion: 2,
        ),
    ];
  }

  Future<void> emitCapabilities({bool resolve = true}) async {
    resolved = resolve;
    source.add(
      WearableEvent(
        type: 'capabilitiesUpdated',
        payload: (await getCapabilities()).toJson(),
      ),
    );
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 60; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _DetailRing extends _Ring implements WearableDeviceDetailsBridge {
  final details = Completer<DeviceInfo?>();
  @override
  Future<DeviceInfo?> getConnectedDeviceDetails() => details.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<(AppController, _Ring, MemoryHealthStore)> setup({
    _Ring? ring,
    _Api? api,
    DeviceInfo device = _device,
    bool signedIn = false,
    bool initializationPending = false,
  }) async {
    ring ??= _Ring();
    final store = MemoryHealthStore();
    final vault = MemorySessionVault()..privacyConsentGranted = true;
    final app = AppController(vault, api ?? _Api(), store, ring);
    addTearDown(app.dispose);
    addTearDown(ring.source.close);
    await app.initialize();
    if (signedIn || initializationPending) {
      app.session = Session(
        accessToken: 'synthetic',
        refreshToken: '',
        expiresAt: DateTime.utc(2099),
        memberId: 'synthetic-owner',
        displayName: 'Synthetic',
        accountKey: 'global:synthetic-owner',
      );
    }
    if (initializationPending) {
      await vault.writeRingInitializationStage(
        app.homeHealthCardOwner,
        device.id,
        RingInitializationStage.resetAttempted,
      );
    }
    await app.connectDevice(device);
    await _settle();
    return (app, ring, store);
  }

  test(
    'late capabilities automatically persist heart and oxygen after initial failure',
    () async {
      final (app, ring, store) = await setup();
      expect(ring.reads, 1);
      expect(app.latestByMetric[HealthMetric.heartRate], isNull);
      await ring.emitCapabilities();
      await _settle();
      expect(ring.reads, 2);
      expect(app.latestByMetric[HealthMetric.heartRate]?.values['value'], 72);
      expect(app.latestByMetric[HealthMetric.bloodOxygen]?.values['value'], 98);
      expect(await store.recent(), hasLength(2));
      expect(app.deviceHistoryNeedsRetry, isFalse);
    },
  );

  test(
    'duplicate capability events and another failed read cannot loop',
    () async {
      final (app, ring, _) = await setup(ring: _Ring()..retryFails = true);
      for (var i = 0; i < 5; i++) {
        await ring.emitCapabilities();
      }
      await _settle();
      expect(ring.reads, 2);
      expect(app.deviceHistoryNeedsRetry, isTrue);
      await ring.emitCapabilities();
      await _settle();
      expect(ring.reads, 2);
      await app.syncDeviceData();
      expect(ring.reads, 3, reason: 'manual retry remains available');
    },
  );

  test(
    'recovered genuine records use the existing cloud upload and ACK path',
    () async {
      final api = _Api();
      final (_, ring, store) = await setup(api: api, signedIn: true);
      await ring.emitCapabilities();
      await _settle();
      expect(api.uploaded.values.map((r) => r.metric).toSet(), {
        HealthMetric.heartRate,
        HealthMetric.bloodOxygen,
      });
      expect(await store.pending(limit: 10), isEmpty);
    },
  );

  test(
    'unconfirmed first-binding initialization still forbids all reads',
    () async {
      final (app, ring, _) = await setup(initializationPending: true);
      expect(app.isRingInitializationPending, isTrue);
      await ring.emitCapabilities();
      await _settle();
      expect(ring.reads, 0);
      expect(app.latestByMetric[HealthMetric.heartRate], isNull);
    },
  );

  test('measurement holds a queued retry until stop completes', () async {
    final (app, ring, _) = await setup();
    // Do not let the late catalogue interrupt a user's manual operation.
    app.capabilities = const DeviceCapabilities(
      metrics: {HealthMetric.heartRate},
    );
    expect(await app.startMeasurement(HealthMetric.heartRate), isTrue);
    await ring.emitCapabilities();
    await _settle();
    expect(ring.reads, 1);
    await app.stopMeasurement(HealthMetric.heartRate);
    await _settle();
    expect(ring.reads, 2);
  });

  test('replacement target cannot consume an old deferred read', () async {
    final (app, ring, _) = await setup();
    app.setAppForeground(false);
    await ring.emitCapabilities();
    await _settle();
    const other = DeviceInfo(id: 'coolwear:SYNTHETIC-OTHER', name: 'R7 Pro');
    await app.disconnectDevice();
    await app.connectDevice(other);
    await _settle();
    expect(ring.reads, 2, reason: 'only the new target initial read');
    app.setAppForeground(true);
    await ring.emitCapabilities();
    await _settle();
    expect(ring.reads, 2);
    expect(app.connectedDevice?.id, other.id);
  });

  test('an active detail read finishes before queued history starts', () async {
    final ring = _DetailRing();
    final (app, _, _) = await setup(ring: ring);
    final readingDetails = app.refreshConnectedDeviceDetails(quiet: true);
    await ring.emitCapabilities();
    await _settle();
    expect(ring.reads, 1);
    ring.details.complete(_device);
    await readingDetails;
    await _settle();
    expect(ring.reads, 2);
    expect(app.connectedDevice?.id, _device.id);
  });

  test('capabilities during active history do not add a second read', () async {
    final read = Completer<List<HealthRecord>>();
    final (app, ring, _) = await setup(ring: _Ring()..initialRead = read);
    await ring.emitCapabilities();
    await _settle();
    expect(ring.reads, 1);
    read.complete(WearableSyncResult([], {'heart_rate': 'no_data'}));
    await _settle();
    expect(ring.reads, 1);
    expect(app.isDeviceHistorySyncing, isFalse);
  });

  test(
    'capabilities during final import are handled after both initial reads finish',
    () async {
      final sport = Completer<List<SportRecord>>();
      final (app, ring, _) = await setup(ring: _Ring()..sportRead = sport);
      expect(app.isDeviceHistorySyncing, isTrue);
      await ring.emitCapabilities();
      await _settle();
      expect(ring.reads, 1);
      sport.complete([]);
      await _settle();
      expect(ring.reads, 2);
      expect(app.latestByMetric[HealthMetric.heartRate], isNotNull);
    },
  );

  test(
    'unknown functionality and unrelated feature events do not retry',
    () async {
      final (_, ring, _) = await setup();
      await ring.emitCapabilities(resolve: false);
      await _settle();
      expect(ring.reads, 1);
    },
  );

  test('ordinary history failures cannot authorize capability retry', () async {
    final (_, ring, _) = await setup(
      ring: _Ring()..reportMissingCapabilities = false,
    );
    await ring.emitCapabilities();
    await _settle();
    expect(ring.reads, 1);
  });

  test(
    'manual synchronization consumes an older pending automatic retry',
    () async {
      final (app, ring, _) = await setup();
      ring.resolved = true;
      await app.syncDeviceData();
      await ring.emitCapabilities();
      await _settle();
      expect(ring.reads, 2);
    },
  );

  test(
    'defer background retry until foreground without a polling loop',
    () async {
      final (app, ring, _) = await setup();
      app.setAppForeground(false);
      await ring.emitCapabilities();
      await _settle();
      expect(ring.reads, 1);
      app.setAppForeground(true);
      await _settle();
      expect(ring.reads, 2);
    },
  );

  test('active sport keeps the retry pending until stopped', () async {
    final (app, ring, _) = await setup();
    app.activeSport = SportMode.walking;
    await ring.emitCapabilities();
    await _settle();
    expect(ring.reads, 1);
    await app.stopSport();
    await _settle();
    expect(ring.reads, 2);
  });

  test(
    'disconnect cancels pending reads and late events cannot restart them',
    () async {
      final (app, ring, _) = await setup();
      app.setAppForeground(false);
      await ring.emitCapabilities();
      await _settle();
      await app.disconnectDevice();
      app.setAppForeground(true);
      await ring.emitCapabilities();
      await _settle();
      expect(ring.reads, 1);
    },
  );

  test('account transition discards the pending owner read', () async {
    final (app, ring, _) = await setup();
    app.setAppForeground(false);
    await ring.emitCapabilities();
    await _settle();
    await app.logout();
    app.setAppForeground(true);
    await ring.emitCapabilities();
    await _settle();
    expect(ring.reads, 1);
  });

  test('iOS and QRing retain their own capability and sync rules', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final (_, ios, _) = await setup();
    await ios.emitCapabilities();
    await _settle();
    expect(ios.reads, 1);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final (_, qring, _) = await setup(
      device: const DeviceInfo(
        id: 'qring:SYNTHETIC',
        name: 'R22',
        model: 'R22',
      ),
    );
    await qring.emitCapabilities();
    await _settle();
    expect(qring.reads, 1);
  });
}
