import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_reminder.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/reading_reminder.dart';
import 'package:saydian_app/domain/read_only_health_features.dart';
import 'package:saydian_app/domain/wellness_release_policy.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/health_reminder_notifications.dart';
import 'package:saydian_app/services/health_reminder_report.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/services/notification_models.dart';
import 'package:saydian_app/ui/pages/notifications.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/health_reminder_center.dart';

Session _session(String member) => Session(
  accessToken: 'synthetic-$member',
  refreshToken: 'synthetic-refresh',
  expiresAt: DateTime.utc(2035),
  memberId: member,
  displayName: 'Synthetic',
);

class _Api extends Fake implements SaydianApi {
  @override
  Future<Session> login(String username, String password) async =>
      _session(username);
  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => const [];
  @override
  Future<Map<String, Object?>> getMemberProfile() async => const {};
  @override
  Future<Map<String, Object?>> getActivityGoals() async => const {};
  @override
  Future<List<Map<String, Object?>>> getArticles() async => const [];
  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      const [];
}

class _Wearable extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}

class _LiveWearable extends _Wearable
    implements WearableHealthReminderHapticsBridge {
  int pulses = 0;
  @override
  Future<RingReminderHapticResult> pulseHealthReminder({
    required String expectedDeviceId,
  }) async {
    expect(expectedDeviceId, device.id);
    pulses++;
    return const RingReminderHapticResult(accepted: true, acknowledged: true);
  }

  static const device = DeviceInfo(
    id: 'coolwear:synthetic-ring',
    name: 'R7 Pro',
    firmwareVersion: 'test-only',
  );
  final records = StreamController<WearableEvent>.broadcast();
  @override
  Stream<WearableEvent> get events => records.stream;
  @override
  Future<void> connect(
    String deviceId, {
    required WearableUserProfile profile,
  }) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<DeviceCapabilities> getCapabilities() async =>
      const DeviceCapabilities(
        metrics: {HealthMetric.heartRate, HealthMetric.bloodOxygen},
        manualMetrics: {HealthMetric.heartRate, HealthMetric.bloodOxygen},
        supportsHistorySync: false,
        features: {DeviceFeature.findWatch},
        integratedFeatures: {DeviceFeature.findWatch},
      );
  @override
  Future<void> startMeasurement(HealthMetric metric) async {}
  @override
  Future<void> stopMeasurement(HealthMetric metric) async {}
  @override
  Future<List<SportRecord>> readSportRecords() async => const [];
}

Future<void> _settleEvents() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<
  ({
    AppController app,
    _LiveWearable ring,
    _Notifications notifications,
    MemoryHealthStore store,
  })
>
_readingFixture({bool notificationsAllowed = true}) async {
  const metrics = {HealthMetric.heartRate, HealthMetric.bloodOxygen};
  final ring = _LiveWearable();
  final notifications = _Notifications()..allowed = notificationsAllowed;
  final store = MemoryHealthStore();
  final app = await _controller(
    store: store,
    wearable: ring,
    notifications: notifications,
    policy: WellnessReleasePolicy(
      enabled: true,
      readOnlyFeatures: ReadOnlyHealthFeatures()
        ..replace(metrics, const Duration(minutes: 5)),
      manualFeatures: ManualHealthFeatures()
        ..replace(metrics, const Duration(minutes: 5)),
    ),
  );
  await app.connectDevice(_LiveWearable.device);
  await _settleEvents();
  await app.saveReadingReminderSettings(
    const ReadingReminderSettings(highEnabled: true),
    expectedOwner: app.homeHealthCardOwner,
  );
  return (app: app, ring: ring, notifications: notifications, store: store);
}

void _emitHighReading(_LiveWearable ring, String id) => ring.records.add(
  WearableEvent(
    type: 'healthRecord',
    payload: HealthRecord(
      id: id,
      metric: HealthMetric.heartRate,
      values: const {'value': 140},
      unit: 'bpm',
      measuredAt: DateTime.now().toUtc(),
      timezone: '+00:00',
      deviceId: _LiveWearable.device.id,
      firmwareVersion: 'test-only',
      quality: 'device_reported',
      source: MeasurementSource.wearable,
      origin: MeasurementOrigin.appMeasurement,
      rawVersion: 2,
    ).toJson(),
  ),
);

class _Notifications implements HealthReminderNotifications {
  bool allowed = true;
  String? owner;
  HealthReminderNotificationOpen? opened;
  final cancelled = <String>[];
  final shown = <String>[];
  @override
  Future<void> setOwner(String? owner) async {
    this.owner = owner;
  }

  @override
  Future<ReminderNotificationPermission> permission({
    bool request = false,
  }) async => request
      ? ReminderNotificationPermission.granted
      : ReminderNotificationPermission.denied;
  @override
  Future<bool> show({required String owner, required String eventId}) async {
    if (owner != this.owner || !allowed) return false;
    shown.add(eventId);
    return true;
  }

  @override
  Future<void> cancel(String eventId) async {
    cancelled.add(eventId);
  }

  @override
  Future<HealthReminderNotificationOpen?> consumeOpen() async {
    final result = opened;
    opened = null;
    return result;
  }
}

class _DelayedAlertStore extends MemoryHealthStore {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> saveHealthWarningAlert(HealthWarningAlert alert) async {
    final saved = super.saveHealthWarningAlert(alert);
    if (alert.reminder?.ruleVersion == 'personal-reading-v1') {
      if (!started.isCompleted) started.complete();
      await release.future;
    }
    await saved;
  }
}

Future<AppController> _controller({
  MemoryHealthStore? store,
  _Notifications? notifications,
  bool iosScope = true,
  bool signedIn = true,
  WearableBridge? wearable,
  WellnessReleasePolicy? policy,
}) async {
  final vault = MemorySessionVault()..legacyHealthMigrationHandled = true;
  if (signedIn) vault.session = _session('100');
  final result = AppController(
    vault,
    _Api(),
    store ?? MemoryHealthStore(),
    wearable ?? _Wearable(),
    wellnessOnly: iosScope,
    healthReadPolicy: policy,
    healthReminderNotifications: notifications,
  );
  await result.initialize();
  return result;
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSaydianTheme(),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: widget,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'in-app reminder survives denied system notifications, deduplicates and persists across restart',
    () async {
      final f = await _readingFixture(notificationsAllowed: false);
      addTearDown(f.ring.records.close);
      await f.app.startMeasurement(HealthMetric.heartRate);
      _emitHighReading(f.ring, 'inbox-denied');
      await _settleEvents();
      expect(f.app.notificationUnreadCount, 1);
      final inbox = f.app.notificationInboxEvents.single;
      final event = f.app.healthReminderEvents.single;
      expect(inbox.source, NotificationEventSource.device);
      expect(inbox.eventId, f.app.healthWarningEventId(event));
      expect(inbox.entityId, event.id);
      expect(f.notifications.shown, isEmpty);
      expect(f.ring.pulses, 1);
      expect(event.reminder?.ringVibrationAcknowledgedAt, isNotNull);
      _emitHighReading(f.ring, 'inbox-denied');
      await _settleEvents();
      expect(f.app.notificationInboxEvents, hasLength(1));
      expect(f.ring.pulses, 1);
      f.app.dispose();
      final restored = await _controller(store: f.store);
      addTearDown(restored.dispose);
      expect(restored.notificationInboxEvents.single.eventId, inbox.eventId);
      expect(restored.notificationUnreadCount, 1);
      expect(await restored.login('200', 'synthetic-test-only'), isTrue);
      expect(restored.notificationInboxEvents, isEmpty);
      expect(restored.notificationUnreadCount, 0);
      expect(await restored.login('100', 'synthetic-test-only'), isTrue);
      expect(restored.notificationUnreadCount, 1);
      await restored.markAllHealthWarningsRead();
      expect(restored.notificationUnreadCount, 0);
    },
  );

  test(
    'ring vibration can be disabled independently and test pulse creates no health event',
    () async {
      final f = await _readingFixture();
      addTearDown(f.app.dispose);
      addTearDown(f.ring.records.close);
      final owner = f.app.homeHealthCardOwner;
      expect(
        (await f.app.testHealthReminderRingVibration(
          expectedOwner: 'old-owner',
        )).accepted,
        isFalse,
      );
      expect(
        (await f.app.testHealthReminderRingVibration(
          expectedOwner: owner,
        )).acknowledged,
        isTrue,
      );
      expect(f.app.healthReminderEvents, isEmpty);
      expect(f.app.notificationInboxEvents, isEmpty);
      expect(f.ring.pulses, 1);
      await f.app.saveReadingReminderSettings(
        f.app.readingReminderSettings.copyWith(ringVibrationEnabled: false),
        expectedOwner: owner,
      );
      await f.app.startMeasurement(HealthMetric.heartRate);
      _emitHighReading(f.ring, 'vibration-disabled');
      await _settleEvents();
      expect(f.ring.pulses, 1);
      expect(f.app.notificationUnreadCount, 1);
      expect(f.notifications.shown, hasLength(1));
      expect(
        f.app.healthReminderEvents.single.reminder?.ringVibrationRequestedAt,
        isNull,
      );
    },
  );

  testWidgets(
    'app message opens its actual reminder and marks only that message read',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const connectivityEvents = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      const connectivity = MethodChannel(
        'dev.fluttercommunity.plus/connectivity',
      );
      messenger.setMockMethodCallHandler(connectivityEvents, (_) async => null);
      messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
      addTearDown(
        () => messenger.setMockMethodCallHandler(connectivityEvents, null),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(connectivity, null));
      final f = (await tester.runAsync(_readingFixture))!;
      addTearDown(f.app.dispose);
      addTearDown(f.ring.records.close);
      await tester.runAsync(
        () => f.app.startMeasurement(HealthMetric.heartRate),
      );
      _emitHighReading(f.ring, 'message-navigation');
      await tester.runAsync(_settleEvents);
      await _pump(tester, NotificationsPage(controller: f.app));
      expect(f.app.notificationUnreadCount, 1);
      await tester.tap(find.text('心率偏高提醒'));
      await tester.runAsync(_settleEvents);
      await tester.pumpAndSettle();
      expect(find.byType(HealthReminderDetailPage), findsOneWidget);
      expect(f.app.notificationUnreadCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in ['settings', 'lease', 'target']) {
    test(
      'slow local writes cannot present a stale reminder after $scenario changes',
      () async {
        final store = _DelayedAlertStore();
        final ring = _LiveWearable();
        final notifications = _Notifications();
        const metrics = {HealthMetric.heartRate, HealthMetric.bloodOxygen};
        final read = ReadOnlyHealthFeatures()
          ..replace(metrics, const Duration(minutes: 5));
        final manual = ManualHealthFeatures()
          ..replace(metrics, const Duration(minutes: 5));
        final controller = await _controller(
          store: store,
          wearable: ring,
          notifications: notifications,
          policy: WellnessReleasePolicy(
            enabled: true,
            readOnlyFeatures: read,
            manualFeatures: manual,
          ),
        );
        addTearDown(controller.dispose);
        addTearDown(ring.records.close);
        await controller.connectDevice(_LiveWearable.device);
        await _settleEvents();
        final owner = controller.homeHealthCardOwner;
        const enabled = ReadingReminderSettings(highEnabled: true);
        expect(
          await controller.saveReadingReminderSettings(
            enabled,
            expectedOwner: owner,
          ),
          isTrue,
        );
        expect(
          await controller.startMeasurement(HealthMetric.heartRate),
          isTrue,
        );
        ring.records.add(
          WearableEvent(
            type: 'healthRecord',
            payload: HealthRecord(
              id: 'slow-storage',
              metric: HealthMetric.heartRate,
              values: const {'value': 140},
              unit: 'bpm',
              measuredAt: DateTime.now().toUtc(),
              timezone: '+00:00',
              deviceId: _LiveWearable.device.id,
              firmwareVersion: 'test-only',
              quality: 'device_reported',
              source: MeasurementSource.wearable,
              origin: MeasurementOrigin.appMeasurement,
              rawVersion: 2,
            ).toJson(),
          ),
        );
        await store.started.future;
        if (scenario == 'settings') {
          // Changing off and back on must still invalidate the pending observation.
          expect(
            await controller.saveReadingReminderSettings(
              const ReadingReminderSettings(),
              expectedOwner: owner,
            ),
            isTrue,
          );
          expect(
            await controller.saveReadingReminderSettings(
              enabled,
              expectedOwner: owner,
            ),
            isTrue,
          );
        } else if (scenario == 'lease') {
          manual.replace({}, const Duration(minutes: 5));
        } else {
          await controller.disconnectDevice();
        }
        store.release.complete();
        await _settleEvents();
        expect(controller.activeHealthWarningAlert, isNull);
        expect(notifications.shown, isEmpty);
        expect(controller.healthReminderEvents.single.reminder?.reading, 140);
      },
    );
  }

  test(
    'personal settings persist per owner and stale page cannot alter the next account',
    () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final owner = controller.homeHealthCardOwner;
      const settings = ReadingReminderSettings(
        highEnabled: true,
        lowEnabled: true,
        oxygenEnabled: true,
        high: 130,
        low: 45,
        oxygen: 94,
      );
      expect(
        await controller.saveReadingReminderSettings(
          settings,
          expectedOwner: owner,
        ),
        isTrue,
      );
      expect(controller.healthAlertsAvailable, isFalse);
      expect(controller.automaticHealthRemindersAvailable, isFalse);
      expect(await controller.login('200', 'synthetic-test-only'), isTrue);
      expect(controller.readingReminderSettings.enabled, isFalse);
      expect(
        await controller.saveReadingReminderSettings(
          settings,
          expectedOwner: owner,
        ),
        isFalse,
      );
      expect(await controller.login('100', 'synthetic-test-only'), isTrue);
      expect(
        controller.readingReminderSettings.fingerprint,
        settings.fingerprint,
      );
    },
  );

  test(
    'fresh completed measurement creates personal alert; history, revocation and account changes do not',
    () async {
      const metrics = {HealthMetric.heartRate, HealthMetric.bloodOxygen};
      final read = ReadOnlyHealthFeatures()
        ..replace(metrics, const Duration(minutes: 5));
      final manual = ManualHealthFeatures()
        ..replace(metrics, const Duration(minutes: 5));
      final ring = _LiveWearable();
      final notifications = _Notifications();
      final controller = await _controller(
        wearable: ring,
        notifications: notifications,
        policy: WellnessReleasePolicy(
          enabled: true,
          readOnlyFeatures: read,
          manualFeatures: manual,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(ring.records.close);
      await controller.connectDevice(_LiveWearable.device);
      await _settleEvents();
      expect(controller.connectedDevice?.id, _LiveWearable.device.id);
      expect(
        await controller.saveReadingReminderSettings(
          const ReadingReminderSettings(highEnabled: true, oxygenEnabled: true),
          expectedOwner: controller.homeHealthCardOwner,
        ),
        isTrue,
      );
      void emit(
        String id,
        HealthMetric metric,
        double value,
        MeasurementOrigin origin,
      ) {
        ring.records.add(
          WearableEvent(
            type: 'healthRecord',
            payload: HealthRecord(
              id: id,
              metric: metric,
              values: {'value': value},
              unit: metric == HealthMetric.bloodOxygen ? '%' : 'bpm',
              measuredAt: DateTime.now().toUtc(),
              timezone: '+00:00',
              deviceId: _LiveWearable.device.id,
              firmwareVersion: 'test-only',
              quality: 'device_reported',
              source: MeasurementSource.wearable,
              origin: origin,
              rawVersion: 2,
            ).toJson(),
          ),
        );
      }

      emit(
        'history',
        HealthMetric.heartRate,
        140,
        MeasurementOrigin.watchHistory,
      );
      await _settleEvents();
      expect(controller.activeHealthWarningAlert, isNull);
      expect(controller.healthReminderEvents, isEmpty);
      expect(await controller.startMeasurement(HealthMetric.heartRate), isTrue);
      emit(
        'completed-high',
        HealthMetric.heartRate,
        140,
        MeasurementOrigin.appMeasurement,
      );
      await _settleEvents();
      expect(
        controller.activeHealthWarningAlert?.reminder?.kind,
        HealthReminderKind.highHeartRate,
      );
      expect(controller.healthReminderEvents.single.reminder?.threshold, 120);
      controller.dismissHealthWarningAlert();
      expect(
        await controller.startMeasurement(HealthMetric.bloodOxygen),
        isTrue,
      );
      emit(
        'completed-oxygen',
        HealthMetric.bloodOxygen,
        91,
        MeasurementOrigin.appMeasurement,
      );
      await _settleEvents();
      final event = controller.activeHealthWarningAlert!;
      expect(event.metric, HealthMetric.bloodOxygen);
      expect(event.reminder?.kind, HealthReminderKind.lowBloodOxygen);
      final csv = controller.healthReminderCsv(
        event.id,
        expectedOwner: controller.homeHealthCardOwner,
      )!;
      expect(csv, contains('血氧（%）'));
      expect(csv, isNot(contains('心率（bpm）')));
      controller.dismissHealthWarningAlert();
      manual.replace({}, const Duration(minutes: 5));
      expect(
        await controller.startMeasurement(HealthMetric.heartRate),
        isFalse,
      );
      emit(
        'revoked',
        HealthMetric.heartRate,
        140,
        MeasurementOrigin.appMeasurement,
      );
      await _settleEvents();
      expect(controller.activeHealthWarningAlert, isNull);
      expect(controller.healthReminderEvents, hasLength(2));
      expect(await controller.login('200', 'synthetic-test-only'), isTrue);
      emit(
        'old-owner-late',
        HealthMetric.heartRate,
        140,
        MeasurementOrigin.appMeasurement,
      );
      await _settleEvents();
      expect(controller.healthReminderEvents, isEmpty);
      expect(controller.activeHealthWarningAlert, isNull);
    },
  );

  test('new metadata round-trips without modifying a legacy record', () {
    final legacy = HealthWarningAlert(
      id: 'legacy',
      metric: HealthMetric.heartRate,
      title: 'legacy',
      message: 'value',
      triggeredAt: DateTime.utc(2026),
    );
    expect(legacy.toJson().containsKey('reminder'), isFalse);
    expect(HealthWarningAlert.fromJson(legacy.toJson()).reminder, isNull);
    final details = HealthReminderDetails(
      kind: HealthReminderKind.symptoms,
      recordedAt: DateTime.utc(2026),
      symptoms: {HealthReminderSymptom.chestDiscomfort},
    );
    final restored = HealthWarningAlert.fromJson(
      legacy.withReminder(details).toJson(),
    );
    expect(restored.reminder!.symptoms, {
      HealthReminderSymptom.chestDiscomfort,
    });
    expect(restored.reminder!.acknowledgedAt, isNull);
    expect(restored.reminder!.reading, isNull);
    expect(restored.message, legacy.message);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'numeric controls, custom value and preview preserve records at 332dp scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(332, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final controller = (await tester.runAsync(_controller))!;
        addTearDown(controller.dispose);
        await _pump(tester, HealthReminderCenterPage(controller: controller));
        final enabled = find.byKey(
          const Key('reading-reminder-high_heart_rate-enabled'),
        );
        await tester.ensureVisible(enabled);
        await tester.tap(enabled);
        await tester.pumpAndSettle();
        expect(controller.readingReminderSettings.highEnabled, isTrue);
        final limit = find.byKey(
          const Key('reading-reminder-high_heart_rate-limit'),
        );
        await tester.ensureVisible(limit);
        await tester.tap(limit);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('提高阈值'));
        await tester.pumpAndSettle();
        final save = find.byKey(const Key('reading-limit-save'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(controller.readingReminderSettings.high, 121);
        final preview = find.byKey(const Key('reading-reminder-preview'));
        await tester.ensureVisible(preview);
        await tester.pumpAndSettle();
        await tester.tap(preview);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byKey(const Key('reading-reminder-preview-label')),
          findsOneWidget,
        );
        expect(controller.healthReminderEvents, isEmpty);
        expect(controller.activeHealthWarningAlert, isNull);
        final close = find.byKey(const Key('dismiss-health-warning'));
        await tester.ensureVisible(close);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('global-reading-reminder')), findsNothing);
        expect(controller.healthReminderEvents, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('malformed metadata is not silently promoted into an event', () {
    expect(
      HealthReminderDetails.tryParse({
        'schemaVersion': 1,
        'kind': 'unknown',
        'recordedAt': '2026-01-01',
      }),
      isNull,
    );
    expect(
      HealthReminderDetails.tryParse({
        'schemaVersion': 1,
        'kind': 'symptoms',
        'recordedAt': 'invalid',
      }),
      isNull,
    );
    final parsed = HealthReminderDetails.tryParse({
      'schemaVersion': 1,
      'kind': 'symptoms',
      'recordedAt': '2026-01-01',
      'deviceName': 1,
      'ruleVersion': true,
    });
    expect(parsed?.deviceName, isNull);
    expect(parsed?.ruleVersion, isNull);
  });

  test(
    'iOS can save user-reported symptoms while physiological alerts stay closed',
    () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final event = await controller.recordHealthReminderSymptoms({
        HealthReminderSymptom.chestDiscomfort,
      });
      expect(controller.healthAlertsAvailable, isFalse);
      expect(controller.automaticHealthRemindersAvailable, isFalse);
      expect(event?.reminder?.kind, HealthReminderKind.symptoms);
      expect(event?.reminder?.reading, isNull);
      expect(controller.healthReminderEvents.single.id, event?.id);
      expect(controller.activeHealthWarningAlert, isNull);
    },
  );

  test('empty symptom selection and anonymous storage are rejected', () async {
    final controller = await _controller(signedIn: false);
    addTearDown(controller.dispose);
    expect(
      await controller.recordHealthReminderSymptoms({
        HealthReminderSymptom.chestDiscomfort,
      }),
      isNull,
    );
    expect(await controller.recordHealthReminderSymptoms({}), isNull);
    expect(controller.healthReminderEvents, isEmpty);
  });

  test(
    'concurrent acknowledgement and dialler action preserve both facts',
    () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final event = (await controller.recordHealthReminderSymptoms({
        HealthReminderSymptom.breathlessness,
      }))!;
      final owner = controller.homeHealthCardOwner;
      expect(
        await Future.wait([
          controller.updateHealthReminderAction(
            event.id,
            expectedOwner: owner,
            acknowledged: true,
          ),
          controller.updateHealthReminderAction(
            event.id,
            expectedOwner: owner,
            dialRequested: true,
          ),
        ]),
        [true, true],
      );
      final details = controller.healthReminderEvents.single.reminder!;
      expect(details.acknowledgedAt, isNotNull);
      expect(details.dialRequestedAt, isNotNull);
      expect(details.notificationRequestedAt, isNull);
      final json = details.toJson().toString();
      expect(json, isNot(contains('recovered')));
      expect(json, isNot(contains('rescued')));
    },
  );

  test(
    'account change hides old events and rejects old action/export context',
    () async {
      final notifications = _Notifications();
      final controller = await _controller(notifications: notifications);
      addTearDown(controller.dispose);
      final event = (await controller.recordHealthReminderSymptoms({
        HealthReminderSymptom.faintness,
      }))!;
      final oldOwner = controller.homeHealthCardOwner;
      expect(await controller.login('200', 'synthetic-test-only'), isTrue);
      expect(controller.healthReminderEvents, isEmpty);
      expect(
        await controller.updateHealthReminderAction(
          event.id,
          expectedOwner: oldOwner,
          acknowledged: true,
        ),
        isFalse,
      );
      expect(
        controller.healthReminderCsv(event.id, expectedOwner: oldOwner),
        isNull,
      );
      expect(await controller.login('100', 'synthetic-test-only'), isTrue);
      expect(controller.healthReminderEvents.single.id, event.id);
      expect(
        controller.healthReminderEvents.single.reminder!.acknowledgedAt,
        isNull,
      );
      expect(notifications.owner, oldOwner);
    },
  );

  test(
    'current-owner notification opens only an existing local event',
    () async {
      final notifications = _Notifications();
      final controller = await _controller(notifications: notifications);
      addTearDown(controller.dispose);
      final event = (await controller.recordHealthReminderSymptoms({
        HealthReminderSymptom.faintness,
      }))!;
      notifications.opened = HealthReminderNotificationOpen(
        'other-owner',
        event.id,
      );
      await controller.handleAppResumed();
      await _settleEvents();
      expect(controller.consumePendingNotificationRoute(), isNull);
      notifications.opened = HealthReminderNotificationOpen(
        controller.homeHealthCardOwner,
        event.id,
      );
      await controller.handleAppResumed();
      await _settleEvents();
      expect(controller.consumePendingNotificationRoute()?.entityId, event.id);
    },
  );

  test(
    'deleting one local event preserves another and cancels its notification',
    () async {
      final notifications = _Notifications();
      final store = MemoryHealthStore();
      final controller = await _controller(
        store: store,
        notifications: notifications,
      );
      addTearDown(controller.dispose);
      final first = (await controller.recordHealthReminderSymptoms({
        HealthReminderSymptom.faintness,
      }))!;
      final second = (await controller.recordHealthReminderSymptoms({
        HealthReminderSymptom.chestDiscomfort,
      }))!;
      expect(
        await controller.deleteHealthReminder(
          first.id,
          expectedOwner: controller.homeHealthCardOwner,
        ),
        isTrue,
      );
      expect(controller.healthReminderEvents.single.id, second.id);
      expect((await store.healthWarningAlerts()).single.id, second.id);
      expect(notifications.cancelled, [first.id]);
    },
  );

  test(
    'selected export preserves unknown symptoms and defuses spreadsheet formulae',
    () {
      final event = HealthWarningAlert(
        id: 'synthetic',
        metric: HealthMetric.heartRate,
        title: 'synthetic',
        message: '=HYPERLINK("x")',
        triggeredAt: DateTime.utc(2026),
        reminder: HealthReminderDetails(
          kind: HealthReminderKind.highHeartRate,
          recordedAt: DateTime.utc(2026),
        ),
      );
      final csv = buildHealthReminderCsv(event);
      expect(csv, contains("'=HYPERLINK"));
      expect(csv, contains('未记录'));
      expect(csv, contains('不代表已接通'));
      expect(csv, isNot(contains('无症状')));
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'urgent help is usable offline at 320px and scale $scale without calling automatically',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 780));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final calls = <Uri>[];
        var recorded = 0;
        await _pump(
          tester,
          EmergencyHelpPage(
            dialler: (uri) async {
              calls.add(uri);
              return true;
            },
            onDiallerOpened: () async {
              recorded++;
            },
          ),
        );
        expect(calls, isEmpty);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('emergency-dial')))
              .onPressed,
          isNull,
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('emergency-region')),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('emergency-region')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('中国大陆 · 120').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('emergency-dial')));
        await tester.tap(find.byKey(const Key('emergency-dial')));
        await tester.pumpAndSettle();
        expect(calls.single, Uri(scheme: 'tel', path: '120'));
        expect(recorded, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'detail re-renders on account change without exposing the previous record',
    (tester) async {
      final controller = (await tester.runAsync(_controller))!;
      addTearDown(controller.dispose);
      final event = (await controller.recordHealthReminderSymptoms({
        HealthReminderSymptom.chestDiscomfort,
      }))!;
      await _pump(
        tester,
        HealthReminderDetailPage(controller: controller, eventId: event.id),
      );
      expect(find.text('不适记录'), findsOneWidget);
      await tester.runAsync(
        () => controller.login('200', 'synthetic-test-only'),
      );
      await tester.pumpAndSettle();
      expect(find.text('记录暂不可用'), findsOneWidget);
      expect(find.text('不适记录'), findsNothing);
    },
  );

  testWidgets(
    'symptom page has no preselected no-symptoms claim or medical threshold editor',
    (tester) async {
      final controller = (await tester.runAsync(_controller))!;
      addTearDown(controller.dispose);
      await _pump(tester, HealthReminderSymptomsPage(controller: controller));
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .every((tile) => tile.value == false),
        isTrue,
      );
      expect(find.byType(TextField), findsNothing);
      expect(
        find.byKey(const Key('health-reminder-urgent-help')),
        findsOneWidget,
      );
    },
  );
}
