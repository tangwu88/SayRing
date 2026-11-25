import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_care.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/ring_experience.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/notification_models.dart';
import 'package:saydian_app/services/notification_route_service.dart';
import 'package:saydian_app/services/ring_firmware.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/cardiovascular_trends_page.dart';
import 'package:saydian_app/ui/global_care_page.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/ring_share_page.dart';
import 'package:saydian_app/ui/ring_week_page.dart';

class _OfflineRingApi extends Fake implements SaydianApi, GlobalAccountApi {}

class _ConnectedRingApi extends _OfflineRingApi
    implements RingExperienceApi, GlobalCareApi {
  final availability = Completer<Map<String, Object?>>();
  final sharePosts = <Map<String, Object?>>[];
  Future<Map<String, Object?>> Function()? shareResponse;

  @override
  Future<Map<String, Object?>> readRingCapabilities() => availability.future;

  @override
  Future<List<GlobalCareRelationship>> globalCareRelationships() async => [];

  @override
  Future<Map<String, Object?>> requestRing(
    Session expected,
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? data,
  }) async {
    if (method == 'POST' && path == 'shares') {
      sharePosts.add(data!);
      return await (shareResponse?.call() ?? Future.value({'id': 'fixture'}));
    }
    expect(method, 'GET');
    expect(path, 'care/invitations');
    return {'items': []};
  }
}

List<MethodCall> _recordNativeShares(WidgetTester tester) {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    calls.add(call);
    return 'dev.fluttercommunity.plus/share/dismissed';
  });
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });
  return calls;
}

class _DisconnectedRing extends Fake implements WearableBridge {}

class _MissingStepsStore extends MemoryHealthStore {
  @override
  Future<List<HealthRecord>> range({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) {
    if (metric == HealthMetric.steps) {
      return Future.error(StateError('Fixture: activity read unavailable'));
    }
    return super.range(metric: metric, start: start, end: end);
  }
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'share and invitations appear in open pages when the server enables them ($platform)',
      (tester) async {
        final nativeShares = _recordNativeShares(tester);
        final api = _ConnectedRingApi();
        final snapshot = RingSnapshot('sleep', DateTime(2026, 11, 25), {
          'sleepMinutes': 420,
          'deepMinutes': 75,
          'awakeMinutes': 0,
        }, note: 'A fixture note');
        final controller =
            AppController(
                MemorySessionVault(),
                api,
                MemoryHealthStore(),
                _DisconnectedRing(),
                wellnessOnly: platform == TargetPlatform.iOS,
              )
              ..session = Session(
                accessToken: 'fixture',
                refreshToken: '',
                expiresAt: DateTime.utc(2099),
                memberId: 'fixture',
                accountKey: 'global:fixture',
                displayName: 'Fixture',
              );
        addTearDown(controller.dispose);
        final refreshing = controller.refreshRingCapabilities();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    RingShareButton(controller: controller, snapshot: snapshot),
                    TextButton(
                      child: const Text('Open care'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              GlobalCarePage(controller: controller),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.text('Share with friends'), findsNothing);
        await tester.tap(find.text('Open care'));
        await tester.pumpAndSettle();
        final invite = find.byKey(const Key('care-empty-invite-link'));
        expect(invite, findsNothing);

        api.availability.complete({'sharing': true, 'care': true});
        await refreshing;
        await tester.pumpAndSettle();
        expect(invite, findsOneWidget);
        await tester.tap(invite);
        await tester.pumpAndSettle();
        expect(find.text('Invite a friend'), findsOneWidget);
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Share with friends'));
        await tester.pumpAndSettle();
        final posted = api.sharePosts.single;
        expect(posted['confirmed'], isTrue);
        expect(posted['snapshot'], snapshot.toJson());
        expect(nativeShares.single.method, 'share');
        expect(
          nativeShares.single.arguments['text'],
          RingLink.url('share', posted['token'] as String).toString(),
        );
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final (platform, language, title, saveLabel) in [
    (TargetPlatform.android, 'zh', '心血管趋势', '保存到本机'),
    (
      TargetPlatform.android,
      'en',
      'Cardiovascular trends',
      'Save on this phone',
    ),
    (TargetPlatform.iOS, 'zh', '心血管趋势', '保存到本机'),
    (TargetPlatform.iOS, 'en', 'Cardiovascular trends', 'Save on this phone'),
  ]) {
    testWidgets(
      'health opens the offline pressure trend at 2x text ($language)',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        final controller = AppController(
          MemorySessionVault(),
          _OfflineRingApi(),
          MemoryHealthStore(),
          _DisconnectedRing(),
          wellnessOnly: platform == TargetPlatform.iOS,
        );
        addTearDown(controller.dispose);
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(body: DashboardPage(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(title), findsNothing);
        final catalog = find.text(language == 'zh' ? '全部数据' : 'All data');
        await tester.scrollUntilVisible(catalog.hitTestable(), 230);
        await tester.pumpAndSettle();
        await tester.tap(catalog);
        await tester.pumpAndSettle();
        expect(find.byType(AllHealthDataPage), findsOneWidget);
        final entry = find.byKey(const Key('all-health-cardiovascular-trends'));
        await tester.scrollUntilVisible(entry.hitTestable(), 230);
        await tester.pumpAndSettle();
        expect(entry.hitTestable(), findsOneWidget);
        expect(
          find.descendant(of: entry, matching: find.text(title)),
          findsOneWidget,
        );
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(CardiovascularTrendsPage), findsOneWidget);
        final add = find.byKey(const Key('record-pressure-reference'));
        await tester.scrollUntilVisible(add.hitTestable(), 160);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(2));
        expect(
          tester.widget<TextField>(fields.first).controller?.text,
          isEmpty,
        );
        expect(tester.widget<TextField>(fields.last).controller?.text, isEmpty);
        await tester.enterText(fields.first, '121');
        await tester.enterText(fields.last, '79');
        await tester.tap(find.text(saveLabel));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        final now = DateTime.now();
        final local = await controller.loadPressureTrend(
          now.subtract(const Duration(days: 1)),
          now.add(const Duration(days: 1)),
        );
        expect(local.map((row) => (row.systolic, row.diastolic)), [(121, 79)]);
        await tester.pumpAndSettle();
        final chart = find.byType(LineChart);
        await tester.scrollUntilVisible(chart, 200);
        if (chart.evaluate().isEmpty) {
          final labels = tester
              .widgetList<Text>(find.byType(Text))
              .map((widget) => widget.data);
          fail('Missing trend chart after saving a valid reading. $labels');
        }
        final graph = tester.widget<LineChart>(chart);
        expect(graph.data.lineBarsData.map((line) => line.spots.length), [
          1,
          1,
        ]);
        expect(graph.data.lineBarsData.map((line) => line.spots.single.y), [
          121,
          79,
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
    'health trends render matched readings and evidence when one optional metric fails',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = _MissingStepsStore();
      final c = AppController(
        MemorySessionVault(),
        _OfflineRingApi(),
        store,
        _DisconnectedRing(),
      );
      addTearDown(c.dispose);
      final now = DateTime.now();
      DateTime at(int daysAgo) =>
          DateTime(now.year, now.month, now.day - daysAgo, 12);
      await store.upsert([
        HealthRecord(
          id: 'sample-hr',
          metric: HealthMetric.heartRate,
          values: const {'value': 64},
          measuredAt: at(1),
          timezone: '+00:00',
          unit: 'bpm',
          deviceId: 'test-wearable',
          sourceModel: 'Fixture watch',
          firmwareVersion: '',
          quality: 'valid',
          source: MeasurementSource.wearable,
          rawVersion: 2,
        ),
      ]);
      for (final (n, upper) in [(4, 115), (1, 123)]) {
        await c.savePressureReference(
          PressureSample(
            at: at(n),
            systolic: upper,
            diastolic: 79,
            source: 'reference',
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CardiovascularTrendsPage(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      final chart = find.descendant(
        of: find.byKey(const Key('cardio-pressure-plot')),
        matching: find.byType(LineChart),
      );
      expect(chart, findsOneWidget);
      expect(
        tester.widget<LineChart>(chart).data.lineBarsData.first.spots[1],
        FlSpot.nullSpot,
      );
      expect(find.text('多记录几天血压，再看趋势解读。'), findsOneWidget);
      expect(find.textContaining('123/79 mmHg，心率为64 bpm'), findsNothing);
      final evidence = find.byKey(const Key('cardio-evidence'));
      await tester.scrollUntilVisible(evidence.hitTestable(), 180);
      await tester.tap(evidence);
      await tester.pumpAndSettle();
      expect(find.text('血压来源 · 上臂血压计'), findsOneWidget);
      expect(find.text('心率 · Fixture watch'), findsOneWidget);
      expect(find.textContaining('123/79 mmHg，心率为64 bpm'), findsOneWidget);
      expect(find.textContaining('123/79 mmHg · 1 次'), findsOneWidget);
      final retry = find.text('部分记录读取失败，重试');
      await tester.scrollUntilVisible(retry.hitTestable(), 180);
      expect(retry.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a local reference reading can be edited and deleted in the trends page',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final controller = AppController(
        MemorySessionVault(),
        _OfflineRingApi(),
        MemoryHealthStore(),
        _DisconnectedRing(),
      );
      addTearDown(controller.dispose);
      final at = DateTime.now().subtract(const Duration(hours: 2));
      await controller.savePressureReference(
        PressureSample(
          at: at,
          systolic: 121,
          diastolic: 79,
          source: 'reference',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: CardiovascularTrendsPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      Future<void> openRecord() async {
        final evidence = find.byKey(const Key('cardio-evidence'));
        final showRows = find.text('View individual readings');
        if (showRows.evaluate().isEmpty) {
          await tester.scrollUntilVisible(evidence.hitTestable(), 150);
          await tester.tap(evidence);
          await tester.pumpAndSettle();
        }
        await tester.scrollUntilVisible(showRows.hitTestable(), 150);
        await tester.tap(showRows);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Manage reference reading'));
        await tester.pumpAndSettle();
      }

      await openRecord();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '121',
      );
      await tester.enterText(find.byType(TextField).first, '124');
      await tester.tap(find.text('Save on this phone'));
      await tester.pumpAndSettle();
      expect(
        (await controller.loadPressureTrend(
          at.subtract(const Duration(days: 1)),
          DateTime.now(),
        )).single.systolic,
        124,
      );
      await openRecord();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(
        await controller.loadPressureTrend(
          at.subtract(const Duration(days: 1)),
          DateTime.now(),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'a stored invitation is same-account scoped and expires even across app restarts',
    () {
      final now = DateTime.utc(2026, 11, 25, 11, 55);
      final link = RingLink.parse(
        Uri.parse(
          'https://links.saydian.cn/global/say-ring/invite#ABCDEFGHJKLMNPQRSTUV',
        ),
      )!;
      final consumed = PendingRingLink(
        link,
        now,
        null,
      ).withOwner('member-test');
      final restored = PendingRingLink.fromJson(
        jsonDecode(jsonEncode(consumed.toJson())),
      )!;
      expect(restored.owner, 'member-test');
      expect(restored.link.token, link.token);
      expect(restored.isRecent(now.add(const Duration(hours: 47))), isTrue);
      expect(restored.isRecent(now.add(const Duration(hours: 48))), isFalse);
      expect(
        restored.isRecent(now.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    },
  );

  testWidgets(
    'weekly share sends the optional friend note and keeps the saved note private',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final nativeShares = _recordNativeShares(tester);
      final api = _ConnectedRingApi();
      final now = DateTime.now();
      final controller =
          AppController(
              MemorySessionVault(),
              api,
              MemoryHealthStore(),
              _DisconnectedRing(),
            )
            ..session = Session(
              accessToken: 'fixture',
              refreshToken: '',
              expiresAt: DateTime.utc(2099),
              memberId: 'fixture',
              accountKey: 'global:fixture',
              displayName: 'Fixture',
            )
            ..sportRecords = [
              SportRecord(
                id: 'fixture-walk',
                mode: SportMode.walking,
                startedAt: now,
                durationSeconds: 1800,
                distanceKm: 2.3,
                calories: 0,
                steps: 2980,
              ),
            ];
      addTearDown(controller.dispose);
      api.availability.complete({'sharing': true});
      await controller.refreshRingCapabilities();
      final week = ringDateText(ringAddDays(ringDate(now), 1 - now.weekday));
      await controller.writeRingWeekNote(week, 'Private fixture note');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RingWeekPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      final share = find.text('Share with friends');
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.pumpAndSettle();
      final first = api.sharePosts.single['snapshot'] as Map<String, Object?>;
      expect(first['note'], isEmpty);
      expect(
        first['fields'],
        contains(equals({'key': 'steps', 'value': 2980})),
      );
      expect(nativeShares, hasLength(1));

      await tester.enterText(find.byType(TextField), 'A note for my friend');
      await tester.pumpAndSettle();
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(api.sharePosts, hasLength(2));
      final second = api.sharePosts.last['snapshot'] as Map<String, Object?>;
      expect(second['note'], 'A note for my friend');
      expect(second['fields'], first['fields']);
      expect(await controller.readRingWeekNote(week), 'Private fixture note');
      expect(nativeShares, hasLength(2));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'quick share retries a single request for the same report',
    (tester) async {
      final nativeShares = _recordNativeShares(tester);
      final api = _ConnectedRingApi();
      final firstResponse = Completer<Map<String, Object?>>();
      api.shareResponse = () => switch (api.sharePosts.length) {
        1 => firstResponse.future,
        2 => Future.error(const ApiException('Expired', statusCode: 409)),
        _ => Future.value({'id': 'fixture'}),
      };
      final controller =
          AppController(
              MemorySessionVault(),
              api,
              MemoryHealthStore(),
              _DisconnectedRing(),
            )
            ..session = Session(
              accessToken: 'fixture',
              refreshToken: '',
              expiresAt: DateTime.utc(2099),
              memberId: 'fixture',
              accountKey: 'global:fixture',
              displayName: 'Fixture',
            );
      addTearDown(controller.dispose);
      api.availability.complete({'sharing': true});
      await controller.refreshRingCapabilities();
      final snapshot = RingSnapshot('health', DateTime(2026, 11, 25), {
        'systolic': 122.5,
        'diastolic': 81,
        'pulse': 67,
        'measuredTime': '13:15',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RingShareButton(controller: controller, snapshot: snapshot),
          ),
        ),
      );

      final shareButton = find.widgetWithText(
        OutlinedButton,
        'Share with friends',
      );
      final press = tester.widget<OutlinedButton>(shareButton).onPressed!;
      press();
      press();
      await tester.pump();
      expect(api.sharePosts, hasLength(1));
      expect(nativeShares, isEmpty);

      firstResponse.completeError(StateError('Fixture: interrupted request'));
      await tester.pumpAndSettle();
      await tester.tap(shareButton);
      await tester.pumpAndSettle();
      expect(api.sharePosts, hasLength(2));
      expect(api.sharePosts.first, api.sharePosts.last);
      expect(nativeShares, isEmpty);

      await tester.tap(shareButton);
      await tester.pumpAndSettle();
      expect(api.sharePosts, hasLength(3));
      expect(
        api.sharePosts.first['token'],
        isNot(api.sharePosts.last['token']),
      );
      expect(api.sharePosts.last['snapshot'], snapshot.toJson());
      expect(nativeShares, hasLength(1));
      expect(find.byType(CheckboxListTile), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  test('the first-party host and exact routes are required for care links', () {
    final invite = RingLink.parse(
      Uri.parse(
        'https://app.saydian.cn/global/say-ring/invite#ABCDEFGHJKLMNPQRSTUV',
      ),
    );
    expect(invite?.type, RingLinkType.invite);
    expect(invite?.token, 'ABCDEFGHJKLMNPQRSTUV');
    expect(
      RingLink.parse(
        Uri.parse(
          'https://app.saydian.cn.evil.example/global/say-ring/invite#ABCDEFGHJKLMNPQRSTUV',
        ),
      ),
      isNull,
    );
    expect(
      RingLink.parse(
        Uri.parse(
          'https://app.saydian.cn/global/say-ring/share#${newRingShareToken()}',
        ),
      ),
      isNull,
    );
    expect(
      RingLink.parse(
        Uri.parse(
          'https://app.saydian.cn/global/say-ring/invite?code=ABCDEFGHJKLMNPQRSTUV',
        ),
      ),
      isNull,
    );
  });

  test(
    'reference readings require a real pair and three different days per comparison',
    () {
      expect(PressureSample.validPair(75, 81), isFalse);
      expect(PressureSample.validPair(null, 81), isFalse);
      expect(PressureSample.validPair(125, 81), isTrue);
      final start = DateTime(2026, 11, 1);
      PressureSample entry(int offset, int upper) => PressureSample(
        at: ringAddDays(start, offset),
        systolic: upper,
        diastolic: 80,
        source: 'reference',
      );
      final previous = ringAddDays(start, -7);
      final rows = [
        entry(-7, 121),
        entry(-5, 121),
        entry(0, 120),
        entry(0, 140),
        entry(2, 120),
        entry(4, 120),
      ];
      expect(pressureChange(pressureDays(rows), start, previous), isNull);
      final samples = pressureDays([...rows, entry(-3, 121)]);
      final comparison = pressureChange(samples, start, previous);
      expect(comparison?.current, 3);
      expect(comparison?.previous, 3);
      expect(samples.singleWhere((row) => row.date == start).count, 2);
      expect(comparison?.systolic, closeTo(2.33, .02));
    },
  );

  test('ring notification route requires a well-formed identifier', () {
    const router = NotificationRouteService();
    const id = 'bbdd9988-abcd-abcd-abcd-123456789012';
    final now = DateTime(2026, 11, 24);
    final known = NotificationEvent.tryParse({
      'event_id': 'ring-care:$id',
      'event_type': 'system',
      'entity_id': id,
      'created_at': now.toUtc().toIso8601String(),
      'source': 'server',
    })!;
    expect(
      router.resolve(known).target,
      NotificationRouteTarget.ringCareInteraction,
    );
    expect(
      ringCareRelationshipFromLink(
        'https://app.saydian.cn/care/interactions/$id',
      ),
      isNull,
    );
  });

  test('firmware package families are limited to the six product models', () {
    const expected = {
      ('qring', 'R8'): 'R21',
      ('qring', 'R21'): 'R21',
      ('coolwear', 'R7 Pro'): 'HR05',
      ('coolwear', 'R7u'): 'HR05',
      ('coolwear', 'R7'): 'HR01',
      ('coolwear', 'R7y'): 'HR01',
      ('qring', 'R8 Pro'): null,
      ('qring', 'R22'): null,
      ('qring', 'R7C'): null,
      ('qring', 'R8-R21'): null,
      ('coolwear', 'HR05'): null,
      ('coolwear', 'HR01'): null,
      ('coolwear', 'R21'): null,
      ('urion', 'U19M'): null,
    };
    for (final MapEntry(key: (transport, model), value: family)
        in expected.entries) {
      final device = RingFirmwareIdentity(
        platform: 'ios',
        transport: transport,
        model: model,
        hardware: 'labA',
        version: '1.0',
        battery: 90,
      );
      expect(device.query(1318)['packageModel'], family, reason: model);
    }
    expect(qringIosFirmwareModel(' SD_RING_R8 '), 'R8');
    expect(qringIosFirmwareModel('r21_D47C'), 'R21');
    for (final name in [
      'R8_Pro',
      'R21_R8Pro',
      'R22_C493',
      'R7C-R8',
      'R8-R21',
      'R21_HR05',
      'R21_Plus',
      'r210',
      'U19M',
    ]) {
      expect(qringIosFirmwareModel(name), isNull, reason: name);
    }
  });

  test(
    'firmware manifest signature, expiry, package and hardware must all match',
    () async {
      final ed = Ed25519();
      final key = await ed.newKeyPair();
      final pub = await key.extractPublicKey();
      final now = DateTime.utc(2026, 11, 24);
      const device = RingFirmwareIdentity(
        platform: 'ios',
        transport: 'qring',
        model: 'R8',
        hardware: 'labA',
        version: '1.0',
        battery: 90,
      );
      final manifest = <String, Object?>{
        ...device.query(1318),
        'product': 'say-ring',
        'id': '24d0b7d2-0214-4131-953f-c2e389dbd101',
        'version': '1.1',
        'sha256': List.filled(64, '1').join(),
        'bytes': 3,
        'minBattery': 30,
        'minBuild': 1318,
        'expiresAt': now.add(const Duration(minutes: 8)).toIso8601String(),
      };
      Future<Map<String, Object?>> signed(Map<String, Object?> payload) async {
        final body = utf8.encode(jsonEncode(payload));
        final signature = await ed.sign(body, keyPair: key);
        return {
          'available': true,
          'payload': base64Url.encode(body),
          'signature': base64Url.encode(signature.bytes),
        };
      }

      final envelope = await signed(manifest);
      Future<RingFirmwarePackage?> verify(
        RingFirmwareIdentity identity,
        DateTime clock, {
        Map<String, Object?>? offer,
      }) => RingFirmwarePackage.verify(
        envelope: offer ?? envelope,
        device: identity,
        build: 1318,
        encodedPublicKey: base64Url.encode(pub.bytes),
        now: clock,
      );
      expect((await verify(device, now))?.version, '1.1');
      for (final invalid in [
        {...manifest, 'packageModel': 'HR05'},
        {...manifest}..remove('packageModel'),
        {...manifest, 'model': 'R21'},
      ]) {
        final offer = await signed(invalid);
        await expectLater(
          verify(device, now, offer: offer),
          throwsFormatException,
        );
      }
      const other = RingFirmwareIdentity(
        platform: 'ios',
        transport: 'qring',
        model: 'R8',
        hardware: 'labB',
        version: '1.0',
        battery: 90,
      );
      await expectLater(verify(other, now), throwsFormatException);
      await expectLater(
        verify(device, now.add(const Duration(minutes: 9))),
        throwsFormatException,
      );
      envelope['signature'] = base64Url.encode(List.filled(64, 0));
      await expectLater(verify(device, now), throwsFormatException);
    },
  );
}
