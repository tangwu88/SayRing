import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/ring_experience.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/ring_share_page.dart';

class _Bridge extends Fake implements WearableBridge {}

class _ResponseApi extends Fake
    implements SaydianApi, GlobalAccountApi, RingExperienceApi {
  final posts = <Map<String, Object?>>[];
  Future<Map<String, Object?>> Function()? response;

  @override
  Future<Map<String, Object?>> requestRing(
    Session expected,
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? data,
  }) async {
    expect(method, 'POST');
    if (path == 'shares/open') {
      return {
        'snapshot': RingSnapshot('sleep', DateTime(2026, 11, 27), {
          'sleepMinutes': 420,
        }).toJson(),
      };
    }
    expect(path, 'shares/member-response');
    posts.add(Map.of(data!));
    return response == null ? {'ok': true} : await response!();
  }
}

const _explanation = '需先与报告发布者在“远程关爱”中建立关联；不勾选则匿名回应。';
const _denied = '显示昵称需要先在“远程关爱”中与对方建立有效关联。你也可以取消勾选后匿名回应。';

Future<AppController> _openResponse(
  WidgetTester tester,
  _ResponseApi api, {
  Locale locale = const Locale('zh'),
  double scale = 1,
}) async {
  final controller =
      AppController(MemorySessionVault(), api, MemoryHealthStore(), _Bridge())
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
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => RingNamedResponsePage(
                  controller: controller,
                  token: 'A' * 43,
                ),
              ),
            ),
            child: const Text('open fixture'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open fixture'));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _tapReaction(WidgetTester tester, {bool english = false}) async {
  final button = find.widgetWithText(
    OutlinedButton,
    english ? 'Happy for you' : '为你开心',
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'anonymous response is the default and requires explicit submit',
    (tester) async {
      final api = _ResponseApi();
      await _openResponse(tester, api);
      expect(find.text(_explanation), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(api.posts, isEmpty);
      await _tapReaction(tester);
      expect(api.posts, [
        {'token': 'A' * 43, 'kind': 'cheer', 'named': false},
      ]);
      expect(find.byType(RingNamedResponsePage), findsNothing);
    },
  );

  for (final english in [false, true]) {
    testWidgets('named denial explains choice without auto retry ($english)', (
      tester,
    ) async {
      final api = _ResponseApi()
        ..response = () =>
            Future.error(const ApiException('请选择匿名回应', statusCode: 403));
      await _openResponse(tester, api, locale: Locale(english ? 'en' : 'zh'));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await _tapReaction(tester, english: english);
      expect(api.posts.single['named'], isTrue);
      expect(find.byType(RingNamedResponsePage), findsOneWidget);
      expect(
        find.text(
          english
              ? 'To show your name, first establish an active connection with the report owner in Remote Care. You can also uncheck the option and respond anonymously.'
              : _denied,
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      final checkbox = find.byType(CheckboxListTile);
      expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
      await tester.pump(const Duration(seconds: 5));
      expect(api.posts.length, 1);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(api.posts.length, 1);
      api.response = null;
      await _tapReaction(tester, english: english);
      expect(api.posts.length, 2);
      expect(api.posts.last['named'], isFalse);
      expect(find.byType(RingNamedResponsePage), findsNothing);
    });
  }

  testWidgets('server-approved named reply preserves the selected identity', (
    tester,
  ) async {
    final api = _ResponseApi();
    await _openResponse(tester, api);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await _tapReaction(tester);
    expect(api.posts.single['named'], isTrue);
    expect(find.byType(RingNamedResponsePage), findsNothing);
  });

  for (final status in [403, 429, 500]) {
    testWidgets('other failures retain their own handling ($status)', (
      tester,
    ) async {
      final api = _ResponseApi()
        ..response = () => Future.error(
          ApiException('fixture-private-detail', statusCode: status),
        );
      await _openResponse(tester, api);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await _tapReaction(tester);
      expect(find.text(_denied), findsNothing);
      expect(find.text('fixture-private-detail'), findsNothing);
      expect(
        find.text(status == 429 ? '发送较频繁，请稍等一分钟再试' : '暂未成功，请稍后重试'),
        findsOneWidget,
      );
      expect(api.posts.length, 1);
    });
  }

  testWidgets(
    'pending response blocks double submit and ignores old-owner error',
    (tester) async {
      final pending = Completer<Map<String, Object?>>();
      final api = _ResponseApi()..response = () => pending.future;
      final controller = await _openResponse(tester, api);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await _tapReaction(tester);
      await _tapReaction(tester);
      expect(api.posts.length, 1);
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      controller.session = null;
      pending.completeError(const ApiException('请选择匿名回应', statusCode: 403));
      await tester.pumpAndSettle();
      expect(find.text(_denied), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('explanation and denial fit a narrow screen at ${scale}x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _ResponseApi()
        ..response = () =>
            Future.error(const ApiException('请选择匿名回应', statusCode: 403));
      await _openResponse(tester, api, scale: scale);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await _tapReaction(tester);
      await tester.ensureVisible(find.text(_denied));
      await tester.pumpAndSettle();
      expect(find.text(_denied), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
