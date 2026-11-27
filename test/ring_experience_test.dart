import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_care.dart';
import 'package:saydian_app/domain/global_account.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/ring_experience.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/notification_models.dart';
import 'package:saydian_app/services/notification_payload.dart';
import 'package:saydian_app/services/notification_route_service.dart';
import 'package:saydian_app/services/ring_firmware.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/cardiovascular_trends_page.dart';
import 'package:saydian_app/ui/global_care_page.dart';
import 'package:saydian_app/ui/pages.dart';
import 'package:saydian_app/ui/ring_share_page.dart';
import 'package:saydian_app/ui/ring_week_page.dart';
import 'package:saydian_app/ui/ring_care_page.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_update_service.dart';
import 'package:saydian_app/ui/app_theme.dart';

class _OfflineRingApi extends Fake implements SaydianApi, GlobalAccountApi {}

class _ConnectedRingApi extends _OfflineRingApi
    implements RingExperienceApi, GlobalCareApi {
  final availability = Completer<Map<String, Object?>>();
  final sharePosts = <Map<String, Object?>>[];
  Future<Map<String, Object?>> Function()? shareResponse;
  List<Map<String, Object?>> inbox = const [];
  Map<String, Object?> share = const {};
  List<Map<String, Object?>> olderReplies = const [];
  int? repliesStatus;
  Map<String?, Map<String, Object?>> historyPages = const {};
  final historyCursors = <String?>[];
  final readShareIds = <String>[];
  int invitationPosts = 0;
  Completer<GlobalAuthCapabilities>? pendingAuth;
  final openedTokens = <String>[];
  GlobalWechatAppCapability wechat = const GlobalWechatAppCapability(
    enabled: true,
    appId: 'wx12345678fixture',
  );

  @override
  Future<GlobalAuthCapabilities> getAuthCapabilities() async {
    if (pendingAuth case final pending?) return pending.future;
    return GlobalAuthCapabilities(
      email: false,
      sms: false,
      smsCountries: const {},
      supportedLocales: const ['en'],
      wechatApp: wechat,
    );
  }

  @override
  Future<Map<String, Object?>> readRingCapabilities() => availability.future;

  @override
  Future<List<GlobalCareRelationship>> globalCareRelationships() async => [];

  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      inbox;

  @override
  Future<Map<String, Object?>> requestRing(
    Session expected,
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? data,
  }) async {
    if (method == 'POST' && path == 'shares/open') {
      openedTokens.add(data!['token'] as String);
      return {
        'snapshot': RingSnapshot('sleep', DateTime(2026, 11, 27), {
          'sleepMinutes': 420,
        }).toJson(),
      };
    }
    if (method == 'POST' && path == 'shares') {
      sharePosts.add(data!);
      return await (shareResponse?.call() ?? Future.value({'id': 'fixture'}));
    }
    if (method == 'POST' && path == 'care/invitations') {
      invitationPosts++;
      return {'id': 'invitation-fixture', 'code': 'ABCDEFGHJKLMNPQRSTUV'};
    }
    if (method == 'GET' && path == 'shares') {
      historyCursors.add(query?['before']);
      if (historyPages[query?['before']] case final page?) return page;
      return {
        'entries': [share],
      };
    }
    if (method == 'GET' && path.startsWith('shares/')) {
      readShareIds.add(path.substring('shares/'.length));
      if (repliesStatus case final status?) {
        throw ApiException('Missing detail route', statusCode: status);
      }
      return {
        'share': share,
        'reactions': query?['before'] == null
            ? share['reactions']
            : olderReplies,
        'nextBefore': query?['before'] == null ? 'older' : null,
      };
    }
    expect(method, 'GET');
    expect(path, 'care/invitations');
    return {
      'entries': [
        if (invitationPosts > 0)
          {'id': 'invitation-fixture', 'expiresAt': '2026-11-29T00:00:00Z'},
      ],
    };
  }
}

List<MethodCall> _recordNativeShares(WidgetTester tester) {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  const wechat = MethodChannel('cc.saidian/app_auth');
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    calls.add(call);
    return 'dev.fluttercommunity.plus/share/dismissed';
  });
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(wechat, (
    call,
  ) async {
    calls.add(call);
    return true;
  });
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      wechat,
      null,
    );
  });
  return calls;
}

class _DisconnectedRing extends Fake implements WearableBridge {}

class _RingUpdateStore implements AppUpdateCheckStore {
  @override
  Future<AppUpdateInfo?> readRequiredUpdate() async => null;
  @override
  Future<DateTime?> readLastSuccessfulCheck() async => DateTime.now();
  @override
  Future<void> writeLastSuccessfulCheck(DateTime value) async {}
  @override
  Future<void> writeRequiredUpdate(AppUpdateInfo? value) async {}
}

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
  for (final responses in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'share ${responses ? 'responses' : 'history'} layout fits at ${scale}x',
        (tester) async {
          final time = DateTime(2026, 11, 27, 9, 12);
          final api = _ConnectedRingApi();
          final replies = [
            {
              'kind': 'cheer',
              'name': '小林',
              'createdAt': time.toUtc().toIso8601String(),
            },
            {
              'kind': 'hug',
              'createdAt': time
                  .subtract(const Duration(minutes: 9))
                  .toUtc()
                  .toIso8601String(),
            },
            {
              'kind': 'walk',
              'name': '小陈',
              'createdAt': time
                  .subtract(const Duration(minutes: 16))
                  .toUtc()
                  .toIso8601String(),
            },
          ];
          final rows = [
            for (final kind in ['sleep', 'workout', 'week'])
              {
                'id': kind,
                'snapshot': RingSnapshot(kind, time, {
                  'recordDays': 1,
                }).toJson(),
                'expiresAt': DateTime.now()
                    .add(const Duration(days: 2))
                    .toUtc()
                    .toIso8601String(),
                'reactions': kind == 'week' ? <Object?>[] : [replies.first],
              },
          ];
          api.share = {...rows.first, 'reactions': replies};
          api.historyPages = {
            null: {'entries': rows},
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
          final captureDirectory =
              Platform.environment['SAY_RING_UI_CAPTURE_DIR'];
          if (captureDirectory != null) {
            await tester.runAsync(() async {
              final font = FontLoader('SharePreviewCJK')
                ..addFont(
                  File(
                    'C:/Windows/Fonts/msyh.ttc',
                  ).readAsBytes().then(ByteData.sublistView),
                );
              await font.load();
              final icons = FontLoader('MaterialIcons')
                ..addFont(
                  File(
                    'E:/saydian/.toolchains/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
                  ).readAsBytes().then(ByteData.sublistView),
                );
              await icons.load();
            });
          }
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              theme: captureDirectory == null
                  ? buildSaydianTheme()
                  : buildSaydianTheme().copyWith(
                      textTheme: buildSaydianTheme().textTheme.apply(
                        fontFamily: 'SharePreviewCJK',
                      ),
                      primaryTextTheme: buildSaydianTheme().primaryTextTheme
                          .apply(fontFamily: 'SharePreviewCJK'),
                      appBarTheme: buildSaydianTheme().appBarTheme.copyWith(
                        titleTextStyle: buildSaydianTheme().textTheme.titleLarge
                            ?.copyWith(
                              fontFamily: 'SharePreviewCJK',
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(
                            fontFamily: 'SharePreviewCJK',
                          ),
                        ),
                      ),
                    ),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const Key('share-ui-capture'),
                child: responses
                    ? RingShareRepliesPage(
                        controller: controller,
                        shareId: 'sleep',
                      )
                    : RingMySharesPage(controller: controller),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(responses ? '好友回应' : '分享记录'), findsOneWidget);
          expect(find.text('为你开心'), findsWidgets);
          expect(tester.takeException(), isNull);
          final capture = Platform.environment['SAY_RING_UI_CAPTURE_DIR'];
          if (capture != null && scale == 1) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('share-ui-capture')),
            );
            await tester.runAsync(() async {
              final bitmap = await boundary.toImage(pixelRatio: 2);
              final png = await bitmap.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(capture).create(recursive: true);
              await File(
                '$capture/${responses ? 'replies' : 'history'}.png',
              ).writeAsBytes(png!.buffer.asUint8List());
              bitmap.dispose();
            });
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final cold in [true, false]) {
      testWidgets(
        'report response app link opens the target (${cold ? 'cold' : 'warm'}, $platform)',
        (tester) async {
          FlutterSecureStorage.setMockInitialValues({});
          const channel = EventChannel('com.llfbandit.app_links/events');
          MockStreamHandlerEventSink? sink;
          tester.binding.defaultBinaryMessenger.setMockStreamHandler(
            channel,
            MockStreamHandler.inline(
              onListen: (_, events) {
                sink = events;
                if (cold) {
                  events.success(
                    'https://app.saydian.cn/global/say-ring/respond#${'A' * 43}',
                  );
                }
              },
            ),
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger.setMockStreamHandler(
              channel,
              null,
            ),
          );
          final api = _ConnectedRingApi();
          final controller =
              AppController(
                  MemorySessionVault(),
                  api,
                  MemoryHealthStore(),
                  _DisconnectedRing(),
                  wellnessOnly: platform == TargetPlatform.iOS,
                )
                ..isBooting = false
                ..session = Session(
                  accessToken: 'fixture',
                  refreshToken: '',
                  expiresAt: DateTime.utc(2099),
                  memberId: 'fixture',
                  accountKey: 'global:fixture',
                  displayName: 'Fixture',
                );
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            SaydianApp(
              controller: controller,
              updateCheckStore: _RingUpdateStore(),
            ),
          );
          await tester.pumpAndSettle();
          expect(sink, isNotNull);
          if (!cold) {
            expect(find.byType(RingNamedResponsePage), findsNothing);
            sink!.success(
              'https://app.saydian.cn/global/say-ring/respond#${'A' * 43}',
            );
            await tester.pumpAndSettle();
          }
          expect(find.byType(RingNamedResponsePage), findsOneWidget);
          expect(api.openedTokens, ['A' * 43]);
          expect(tester.takeException(), isNull);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }
  for (final leave in [false, true]) {
    testWidgets(
      'pending care share stops after ${leave ? 'leaving' : 'account change'}',
      (tester) async {
        final calls = _recordNativeShares(tester);
        final api = _ConnectedRingApi()
          ..pendingAuth = Completer<GlobalAuthCapabilities>();
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
        api.availability.complete({'care': true});
        await controller.refreshRingCapabilities();
        await tester.pumpWidget(
          MaterialApp(home: RingInvitationsPage(controller: controller)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Share invitation link'));
        await tester.pump();
        expect(api.invitationPosts, 1);
        if (leave) {
          await tester.pumpWidget(const SizedBox.shrink());
        } else {
          controller.session = null;
        }
        api.pendingAuth!.complete(
          const GlobalAuthCapabilities(
            email: false,
            sms: false,
            smsCountries: {},
            supportedLocales: ['en'],
            wechatApp: GlobalWechatAppCapability(
              enabled: true,
              appId: 'wx12345678fixture',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
  for (final compact in [false, true]) {
    testWidgets(
      'one report share entry opens WeChat (compact=$compact)',
      (tester) async {
        final calls = _recordNativeShares(tester);
        final api = _ConnectedRingApi();
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
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RingShareButton(
                controller: controller,
                compact: compact,
                snapshot: RingSnapshot('sleep', DateTime(2026, 11, 25), {
                  'sleepMinutes': 420,
                }),
              ),
            ),
          ),
        );
        final button = compact
            ? find.byTooltip('Share with friends')
            : find.text('Share with friends');
        expect(button, findsOneWidget);
        expect(find.text('Share to WeChat'), findsNothing);
        expect(
          find.byType(compact ? IconButton : OutlinedButton),
          findsOneWidget,
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(calls.single.method, 'shareWechatWebpage');
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'care invite creates a WeChat card and reshares the same invitation',
    (tester) async {
      final calls = _recordNativeShares(tester);
      final api = _ConnectedRingApi();
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
      api.availability.complete({'care': true});
      await controller.refreshRingCapabilities();
      await tester.pumpWidget(
        MaterialApp(home: RingInvitationsPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share invitation link'));
      await tester.pumpAndSettle();
      expect(api.invitationPosts, 1);
      expect(calls.single.method, 'shareWechatWebpage');
      expect(
        calls.single.arguments['url'],
        'https://app.saydian.cn/global/say-ring/invite#ABCDEFGHJKLMNPQRSTUV',
      );
      expect(calls.single.arguments['title'], 'Say Ring · Care invitation');
      expect(find.text('Copy link'), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share invitation'));
      await tester.pumpAndSettle();
      expect(api.invitationPosts, 1);
      expect(calls, hasLength(2));
      expect(calls.last.arguments, calls.first.arguments);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final outcome in ['open', 'missing-app', 'unconfigured']) {
    testWidgets(
      'WeChat webpage sharing preserves token and handles $outcome',
      (tester) async {
        final api = _ConnectedRingApi();
        if (outcome == 'unconfigured') {
          api.wechat = const GlobalWechatAppCapability();
        }
        final calls = <MethodCall>[];
        const channel = MethodChannel('cc.saidian/app_auth');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call);
            if (outcome == 'missing-app') {
              throw PlatformException(code: 'WECHAT_NOT_INSTALLED');
            }
            return true;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
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
        final snapshot = RingSnapshot('sleep', DateTime(2026, 11, 25), {
          'sleepMinutes': 420,
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RingShareButton(controller: controller, snapshot: snapshot),
            ),
          ),
        );
        expect(find.text('Share to WeChat'), findsNothing);
        expect(find.byType(OutlinedButton), findsOneWidget);
        await tester.tap(find.text('Share with friends'));
        await tester.pumpAndSettle();
        expect(api.sharePosts, hasLength(1));
        if (outcome == 'unconfigured') {
          expect(calls, isEmpty);
          expect(
            find.text('WeChat sharing is unavailable. You can copy the link'),
            findsOneWidget,
          );
        } else {
          expect(calls.single.method, 'shareWechatWebpage');
          expect(calls.single.arguments['appId'], 'wx12345678fixture');
          expect(
            calls.single.arguments['url'],
            RingLink.url(
              'share',
              api.sharePosts.single['token'] as String,
            ).toString(),
          );
          expect(calls.single.arguments['title'], 'Say Ring · Sleep report');
          expect(calls.single.arguments['description'], isNot(contains('420')));
        }
        if (outcome == 'missing-app') {
          expect(find.text('Please install WeChat first'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
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
        expect(
          nativeShares.single.method,
          platform == TargetPlatform.android ? 'shareWechatWebpage' : 'share',
        );
        expect(
          nativeShares.single.arguments[platform == TargetPlatform.android
              ? 'url'
              : 'text'],
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
      final weekStore = MemoryHealthStore();
      await weekStore.upsert([
        for (var day = 0; day < (now.weekday > 1 ? 2 : 1); day++)
          HealthRecord(
            id: 'week-sleep-$day',
            metric: HealthMetric.sleep,
            values: {'value': day == 0 ? 7 : 8},
            measuredAt: DateTime(now.year, now.month, now.day - day),
            timezone: '+08:00',
            unit: 'h',
            deviceId: 'synthetic-week-ring',
            sourceModel: 'Fixture',
            firmwareVersion: '',
            quality: 'valid',
            source: MeasurementSource.wearable,
            rawVersion: 2,
          ),
      ]);
      final controller =
          AppController(
              MemorySessionVault(),
              api,
              weekStore,
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
                id: 'second-fixture-walk',
                mode: SportMode.walking,
                startedAt: now.subtract(const Duration(minutes: 20)),
                durationSeconds: 900,
                distanceKm: 1,
                calories: 0,
                steps: 1000,
              ),
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
      await Scrollable.ensureVisible(tester.element(share), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(share);
      await tester.pumpAndSettle();
      final first = api.sharePosts.single['snapshot'] as Map<String, Object?>;
      expect(first['note'], isEmpty);
      expect(
        first['fields'],
        contains(equals({'key': 'steps', 'value': 3980})),
      );
      expect(
        first['fields'],
        contains(equals({'key': 'sportMinutes', 'value': 45})),
      );
      expect(nativeShares, hasLength(1));
      expect(
        first['fields'],
        contains(
          equals({
            'key': 'sleepAverageMinutes',
            'value': now.weekday > 1 ? 450 : 420,
          }),
        ),
      );

      await tester.enterText(find.byType(TextField), 'A note for my friend');
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(share), alignment: 0.5);
      await tester.pumpAndSettle();
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
    'share URLs send a title reference and keep the read token in the fragment',
    () {
      final token = 'A' * 43;
      final url = RingLink.url('share', token);
      expect(url.queryParameters, {
        'title':
            '0f007385b6f9d4b7eeb2748605afe1a984a0a3bfa3f014d09e2a784ce9e5cd1a',
      });
      expect(url.toString().split('#').first, isNot(contains(token)));
      expect(url.fragment, token);
    },
  );

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
    const eventId = 'ring-share:908fea23-2a97-452c-842c-b97733caf001';
    final push = normalizeNotificationBusinessPayload({
      'eventId': eventId,
      'type': 'system',
      'deepLink': '/ring/shares',
      'entityId': id,
    }, receivedAt: now)!;
    final reply = router.resolve(NotificationEvent.tryParse(push)!);
    expect(reply.target, NotificationRouteTarget.ringShares);
    expect(reply.entityId, id);
    expect(ringShareForNotice('ring-share:$id', link: '/ring/shares'), id);
    expect(ringShareForNotice(eventId, link: '/ring/shares/$id'), id);
    expect(
      normalizeNotificationBusinessPayload({
        'eventId': eventId,
        'type': 'system',
        'deepLink': '/ring/shares/invalid',
      }, receivedAt: now),
      isNull,
    );
  });

  testWidgets(
    'share notifications open the right report with reply contents and local time',
    (tester) async {
      const shareId = 'bbdd9988-abcd-abcd-abcd-123456789012';
      final time = DateTime(2026, 11, 25, 19, 12);
      final api = _ConnectedRingApi()
        ..inbox = [
          {
            'event_id': 'ring-share:908fea23-2a97-452c-842c-b97733caf001',
            'deepLink': '/ring/shares/$shareId',
            'created_at': time.toUtc().toIso8601String(),
            'is_read': false,
          },
        ]
        ..share = {
          'id': shareId,
          'snapshot': RingSnapshot('sleep', time, {
            'sleepMinutes': 420,
          }).toJson(),
          'reactions': [
            {
              'kind': 'hug',
              'name': null,
              'createdAt': time.toUtc().toIso8601String(),
            },
          ],
        }
        ..olderReplies = [
          {
            'kind': 'walk',
            'name': 'Fixture friend',
            'createdAt': time.toUtc().toIso8601String(),
          },
        ];
      final controller =
          AppController(
              MemorySessionVault(),
              api,
              MemoryHealthStore(),
              _DisconnectedRing(),
              wellnessOnly: true,
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
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget shell(Widget home) => MaterialApp(
        key: ValueKey(home.runtimeType),
        home: home,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      );
      await tester.pumpWidget(shell(NotificationsPage(controller: controller)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Someone replied to your share'));
      await tester.pumpAndSettle();
      expect(api.readShareIds, [shareId]);
      expect(find.text('Share replies'), findsOneWidget);
      expect(find.text('Sending a hug'), findsOneWidget);
      final replyContext = tester.element(find.text('Sending a hug'));
      final date = MaterialLocalizations.of(
        replyContext,
      ).formatMediumDate(time);
      final clock = TimeOfDay.fromDateTime(time).format(replyContext);
      expect(find.text('A friend'), findsOneWidget);
      expect(find.text('$date $clock'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('See older replies'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('See older replies'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Let’s walk together'), 180);
      await tester.pumpAndSettle();
      expect(find.text('Let’s walk together'), findsOneWidget);
      expect(find.text('Fixture friend'), findsOneWidget);

      await tester.pumpWidget(shell(RingMySharesPage(controller: controller)));
      await tester.pumpAndSettle();
      expect(find.text('View replies'), findsOneWidget);
      expect(find.text('Sending a hug'), findsOneWidget);
      expect(find.text('Revoke link'), findsNothing);

      api.repliesStatus = 404;
      api.historyPages = {
        null: {
          'entries': [
            {
              'id': '2dcf623b-43be-42b2-9fda-d8638b12ec3e',
              'reactions': api.olderReplies,
            },
          ],
          'nextBefore': 'fixture-past-share',
        },
        'fixture-past-share': {
          'entries': [api.share],
        },
      };
      await tester.scrollUntilVisible(find.text('View replies'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View replies'));
      await tester.pumpAndSettle();
      expect(api.historyCursors, [null, null, 'fixture-past-share']);
      expect(find.text('This share is unavailable'), findsNothing);
      expect(find.text('A friend'), findsOneWidget);
      expect(find.text('$date $clock'), findsOneWidget);
      expect(find.text('Fixture friend'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

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
