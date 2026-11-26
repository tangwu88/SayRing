import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/notification_models.dart';
import 'package:saydian_app/services/notification_payload.dart';
import 'package:saydian_app/services/notification_route_service.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/ui/online_support_page.dart';
import 'package:saydian_app/ui/support_faq_page.dart';

const idA = '00000000-0000-4000-8000-000000000001';
const idB = '00000000-0000-4000-8000-000000000002';
const idReply = '00000000-0000-4000-8000-000000000003';

Session testMember(String id) => Session(
  memberId: id,
  accessToken: 'fixture',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  displayName: 'Synthetic',
  accountKey: 'global:$id',
);

class GuestVault implements OnlineSupportVault {
  Map<String, Object?>? value;
  @override
  Future<Map<String, Object?>?> readSupportGuest() async => value;
  @override
  Future<void> writeSupportGuest(Map<String, Object?>? next) async {
    value = next;
  }
}

class TestController extends ChangeNotifier implements AppController {
  TestController([this.session]);
  @override
  Session? session;
  @override
  int supportOwnerGeneration = 1;
  @override
  String get supportOwner => session?.accountKey ?? 'anonymous';
  @override
  final GuestVault onlineSupportVault = GuestVault();
  @override
  OnlineSupportApi? get onlineSupportApi => null;
  void switchOwner(Session next) {
    session = next;
    supportOwnerGeneration++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class TestSupport implements OnlineSupportApi {
  final sends = <String>[], opened = <String>[];
  final channels = <String, StreamController<Map<String, Object?>>>{};
  final Map<String, Completer<Map<String, Object?>>> protectedLoads = {};
  final List<Map<String, Object?>> faqArticles = [];
  bool offline = true;
  String status = 'ai';
  String? selected;
  int guests = 0;
  Map<String, Object?> event(String id, [List<Map<String, Object?>>? rows]) => {
    'conversation': {'id': id, 'state': status},
    'messages': rows ?? [],
    'older': false,
  };

  @override
  Future<Map<String, Object?>> supportRequest(
    String path, {
    Session? member,
    String? guestToken,
    Map<String, String>? query,
    Map<String, Object?>? body,
    Uint8List? photo,
    Future<void>? stop,
  }) async {
    if (path == 'online-config') {
      return {
        'enabled': true,
        'product': 'say-ring',
        'whatsapp': 'https://wa.me/12025550123',
      };
    }
    if (path == 'guest') {
      guests++;
      return {
        'token': 'srguest.${'x' * 40}',
        'expiresAt': '2098-01-01T00:00:00Z',
        'conversation': {'id': idA},
      };
    }
    if (path == 'faq') {
      return {'items': faqArticles, 'locale': 'en', 'nextOffset': null};
    }
    if (path.startsWith('faq/')) {
      return faqArticles.singleWhere(
        (row) => row['id'] == path.split('/').last,
      );
    }
    if (path == 'conversations') {
      return {'id': member?.memberId == 'B' ? idB : idA};
    }
    if (path.endsWith('/read')) return {'read': true};
    if (path.endsWith('/handoff')) {
      status = 'waiting';
      return {'id': selected, 'state': status};
    }
    if (path.endsWith('/messages')) {
      final clientId = body!['clientMessageId'] as String;
      sends.add(clientId);
      if (offline) throw const ApiException('Offline', statusCode: 503);
      return {
        'id': idReply,
        'seq': 1,
        'body': body['body'],
        'sender': 'customer',
        'clientMessageId': clientId,
      };
    }
    final id = path.split('/').last;
    opened.add(id);
    selected = id;
    return protectedLoads[id]?.future ?? event(id);
  }

  @override
  Stream<Map<String, Object?>> supportEvents(
    String conversation,
    int after, {
    Session? member,
    String? guestToken,
    required Future<void> stop,
  }) {
    final channel = StreamController<Map<String, Object?>>();
    channels[conversation] = channel;
    unawaited(stop.then((_) => channel.close()));
    return channel.stream;
  }

  @override
  Future<Uint8List> supportPhoto(
    String conversation,
    String attachment, {
    Session? member,
    String? guestToken,
    required Future<void> stop,
  }) async => Uint8List(0);
}

Future<void> frame(
  WidgetTester tester,
  Widget page, {
  String lang = 'en',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 740);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(lang),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'guest chooses when to start; safe English WhatsApp and human handoff at 2x',
    (tester) async {
      final controller = TestController(), api = TestSupport();
      await frame(
        tester,
        OnlineSupportPage(controller: controller, apiOverride: api),
      );
      expect(api.guests, 0);
      await tester.scrollUntilVisible(find.text('Contact us on WhatsApp'), 140);
      expect(find.text('Contact us on WhatsApp'), findsOneWidget);
      await tester.ensureVisible(find.text('Start a conversation'));
      await tester.tap(find.text('Start a conversation'));
      await tester.pumpAndSettle();
      expect(api.guests, 1);
      expect(find.byKey(const Key('support-handoff')), findsOneWidget);
      await tester.tap(find.byKey(const Key('support-handoff')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Waiting for a person'), findsOneWidget);
      expect(find.byKey(const Key('support-draft')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same-ID retry plus SSE receipt creates only one bubble; owner switch removes prior text',
    (tester) async {
      final controller = TestController(testMember('A')), api = TestSupport();
      await frame(
        tester,
        OnlineSupportPage(
          controller: controller,
          apiOverride: api,
          initialConversation: idA,
        ),
        lang: 'zh',
      );
      await tester.enterText(find.byKey(const Key('support-draft')), '隔离的测试消息');
      await tester.tap(find.byKey(const Key('support-send')));
      await tester.pumpAndSettle();
      expect(api.sends, hasLength(1));
      api.offline = false;
      await tester.tap(find.text('重试发送'));
      await tester.pumpAndSettle();
      expect(api.sends, [api.sends.first, api.sends.first]);
      api.channels[idA]!.add(
        api.event(idA, [
          {
            'id': idReply,
            'seq': 1,
            'sender': 'customer',
            'body': '隔离的测试消息',
            'clientMessageId': api.sends.first,
          },
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('隔离的测试消息'), findsOneWidget);
      controller.switchOwner(testMember('B'));
      await tester.pumpAndSettle();
      expect(find.text('隔离的测试消息'), findsNothing);
      expect(api.opened, [idA, idB]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FAQ empty state still leads to support without making up answers',
    (tester) async {
      final controller = TestController(), api = TestSupport();
      await frame(
        tester,
        SupportFaqPage(controller: controller, apiOverride: api),
      );
      expect(find.text('Contact support'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('English FAQ labels Chinese source material in English', (
    tester,
  ) async {
    final controller = TestController();
    addTearDown(controller.dispose);
    final api = TestSupport()
      ..faqArticles.add({
        'id': idA,
        'locale': 'zh-Hans',
        'title': '如何连接设备',
        'contentHtml': '<p>打开手机蓝牙。</p>',
      });
    await frame(
      tester,
      SupportFaqPage(controller: controller, apiOverride: api),
    );
    final title = tester.renderObject<RenderParagraph>(find.text('FAQ'));
    expect(title.didExceedMaxLines, isFalse);
    expect(find.text('Chinese'), findsOneWidget);
    await tester.tap(find.text('如何连接设备'));
    await tester.pumpAndSettle();
    expect(find.text('Help article'), findsOneWidget);
    expect(find.text('Chinese'), findsOneWidget);
    expect(find.text('如何连接设备'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('support notification routes only its exact conversation path', () {
    Map<String, Object?> wire(String link) =>
        normalizeNotificationBusinessPayload({
          'eventId': 'support-reply:$idReply',
          'type': 'system',
          'deepLink': link,
        }, receivedAt: DateTime.utc(2026, 11, 15)) ??
        {};
    const routes = NotificationRouteService();
    final event = NotificationEvent.tryParse(
      wire('/support/conversations/$idA'),
    )!;
    expect(
      routes.resolve(event).target,
      NotificationRouteTarget.supportConversation,
    );
    expect(routes.resolve(event).entityId, idA);
    expect(
      NotificationEvent.tryParse(
        wire('https://example.invalid/support/conversations/$idA'),
      ),
      isNull,
    );
  });
}
