import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_reminder.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/health_reminder_notifications.dart';
import 'package:saydian_app/services/health_reminder_report.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
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

class _Notifications implements HealthReminderNotifications {
  String? owner;
  HealthReminderNotificationOpen? opened;
  final cancelled = <String>[];
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
  Future<bool> show({required String owner, required String eventId}) async =>
      owner == this.owner;
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

Future<AppController> _controller({
  MemoryHealthStore? store,
  _Notifications? notifications,
  bool iosScope = true,
  bool signedIn = true,
}) async {
  final vault = MemorySessionVault()..legacyHealthMigrationHandled = true;
  if (signedIn) vault.session = _session('100');
  final result = AppController(
    vault,
    _Api(),
    store ?? MemoryHealthStore(),
    _Wearable(),
    wellnessOnly: iosScope,
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
      expect(controller.consumePendingNotificationRoute(), isNull);
      notifications.opened = HealthReminderNotificationOpen(
        controller.homeHealthCardOwner,
        event.id,
      );
      await controller.handleAppResumed();
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
