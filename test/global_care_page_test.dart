import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/global_care.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/global_care_page.dart';

class _Controller extends Fake implements AppController {
  @override
  Session? session = Session(
    accessToken: 'synthetic',
    refreshToken: '',
    expiresAt: DateTime.utc(2030),
    memberId: 'synthetic-owner',
    accountKey: 'global:synthetic-owner',
    displayName: 'Synthetic',
  );
  final listeners = <VoidCallback>[];
  final invitations = <CareInvitationTarget>[];
  List<GlobalCareRelationship> rows = const [
    GlobalCareRelationship(
      id: 'synthetic-following',
      status: 'active',
      received: false,
      name: '合成关爱成员',
      memberNo: '29',
      metrics: {'sleep'},
    ),
    GlobalCareRelationship(
      id: 'synthetic-follower',
      status: 'active',
      received: true,
      name: '合成关注者',
      memberNo: '30',
      metrics: {},
    ),
  ];
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  @override
  Future<List<GlobalCareRelationship>> globalCareRelationships() async => rows;
  @override
  Future<void> globalInviteCareTarget(CareInvitationTarget target) async =>
      invitations.add(target);
  @override
  Future<void> refreshCare() async {}
  @override
  Future<void> refreshCareInvitations() async {}
  void expireSession() {
    session = null;
    for (final listener in List.of(listeners)) {
      listener();
    }
  }
}

Widget _app(_Controller controller, {double scale = 1}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: GlobalCarePage(controller: controller),
);

void main() {
  testWidgets(
    'owner change closes an unsubmitted invitation without sending it',
    (tester) async {
      final controller = _Controller();
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('global-care-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('care-invite-memberId')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('global-care-member-no')),
        '29',
      );
      controller.expireSession();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.invitations, isEmpty);
      expect(find.text('ID 29'), findsNothing);
    },
  );
  testWidgets('care directions separate members and read-only actions', (
    tester,
  ) async {
    final controller = _Controller();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    expect(find.text('合成关爱成员'), findsOneWidget);
    expect(find.text('ID 29'), findsOneWidget);
    expect(find.text('合成关注者'), findsNothing);
    expect(
      find.byKey(const Key('care-view-synthetic-following')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('care-direction-followers')));
    await tester.pumpAndSettle();
    expect(find.text('合成关注者'), findsOneWidget);
    expect(find.text('合成关爱成员'), findsNothing);
    expect(find.byKey(const Key('care-view-synthetic-follower')), findsNothing);
    expect(find.text('手动测量'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'member ID invitation validates and uses neutral submission copy',
    (tester) async {
      final controller = _Controller();
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('global-care-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('care-invite-memberId')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('global-care-member-no')),
        '029',
      );
      await tester.tap(find.text('发送'));
      await tester.pumpAndSettle();
      expect(find.text('请输入有效会员 ID'), findsOneWidget);
      expect(controller.invitations, isEmpty);
      await tester.enterText(
        find.byKey(const Key('global-care-member-no')),
        '29',
      );
      await tester.tap(find.text('发送'));
      await tester.pumpAndSettle();
      expect(controller.invitations.single.toJson(), {'memberNo': '29'});
      expect(find.text('请求已提交，等待对方确认'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'care stays readable at 320 width and 2x font; logout clears members',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _Controller();
      await tester.pumpWidget(_app(controller, scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('global-care-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('care-invite-memberId')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      controller.expireSession();
      await tester.pumpAndSettle();
      expect(find.text('合成关爱成员'), findsNothing);
      expect(find.text('ID 29'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
