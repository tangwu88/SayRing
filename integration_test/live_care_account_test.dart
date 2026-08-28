import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live account care data is readable and renders on device', (
    tester,
  ) async {
    const account = String.fromEnvironment('SAIDIAN_LIVE_ACCOUNT');
    const password = String.fromEnvironment('SAIDIAN_LIVE_PASSWORD');

    final controller = AppController.production();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      controller.dispose();
    });
    await controller.initialize();

    if (account.isEmpty && password.isEmpty) {
      expect(controller.isAuthenticated, isTrue, reason: '设备上没有可复用的登录会话');
      await Future.wait([
        controller.refreshCare(),
        controller.refreshCareInvitations(),
      ]);
      debugPrint('LIVE_CARE_SESSION:RESTORED');
    } else {
      expect(account, isNotEmpty, reason: '缺少 SAIDIAN_LIVE_ACCOUNT');
      expect(password, isNotEmpty, reason: '缺少 SAIDIAN_LIVE_PASSWORD');
      final loggedIn = await controller.login(account, password);
      expect(loggedIn, isTrue, reason: controller.errorMessage);
      debugPrint('LIVE_CARE_LOGIN:OK');
    }
    expect(controller.session, isNotNull);
    expect(controller.careStatus, '已加载');
    debugPrint(
      'LIVE_CARE_SESSION_MEMBER:${_careFingerprint(controller.session!.memberId)}',
    );
    debugPrint('LIVE_CARE_MEMBERS:${controller.careMembers.length}');
    debugPrint(
      'LIVE_CARE_INVITATIONS:${controller.careInvitations.length}:'
      '${controller.careInvitationStatus}',
    );
    final invitationStates = <String, int>{};
    for (final invitation in controller.careInvitations) {
      final state =
          '${invitation['examine_status'] ?? invitation['status'] ?? 'none'}';
      invitationStates.update(state, (count) => count + 1, ifAbsent: () => 1);
      debugPrint(
        'LIVE_CARE_INVITATION:${_careFingerprint(invitation['member_id'])}:'
        'STATE=$state',
      );
    }
    final orderedStates = invitationStates.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    debugPrint(
      'LIVE_CARE_INVITATION_STATES:'
      '${orderedStates.map((entry) => '${entry.key}=${entry.value}').join(',')}',
    );

    if (controller.careMembers.isEmpty) {
      await tester.pumpWidget(SaydianApp(controller: controller));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('远程关爱').first);
      await _pumpUntil(
        tester,
        () => find.byKey(const Key('care-members-empty')).evaluate().isNotEmpty,
        const Duration(seconds: 20),
      );
      expect(find.byKey(const Key('care-members-empty')), findsOneWidget);
      debugPrint('LIVE_CARE_UI:EMPTY');
      return;
    }

    var readyMetricCount = 0;
    for (var index = 0; index < controller.careMembers.length; index++) {
      final relation = controller.careMembers[index];
      final careId = int.tryParse('${relation['id'] ?? ''}');
      final nestedMember = relation['member'];
      final memberId =
          int.tryParse('${relation['to_member_id'] ?? ''}') ??
          (nestedMember is Map
              ? int.tryParse('${nestedMember['id'] ?? ''}')
              : null);
      expect(careId, isNotNull, reason: '第 ${index + 1} 个关爱关系缺少 id');
      expect(memberId, isNotNull, reason: '第 ${index + 1} 个关爱关系缺少成员 id');

      final preview = await controller.loadCareMemberPreview(
        careId!,
        memberId: memberId,
      );
      expect(
        preview['loadError'],
        isNull,
        reason: '第 ${index + 1} 位成员健康数据整体加载失败',
      );
      final daily = _mapList(preview['daily']);
      final activity = _mapList(preview['jrjk']);
      expect(daily, isNotEmpty, reason: '第 ${index + 1} 位成员缺少健康指标状态');
      const healthTitles = {
        '心率',
        '血压',
        '血糖',
        '血氧',
        '体温',
        'HRV',
        '睡眠',
        '心电',
        '身体成分',
        '血液成分',
      };
      expect(
        activity
            .map((item) => '${item['title'] ?? ''}')
            .where(healthTitles.contains),
        isEmpty,
        reason: '聚合活动卡片不应覆盖健康明细',
      );

      debugPrint(
        'LIVE_CARE_MEMBER:${index + 1}:ACTIVITY=${activity.length}:'
        'METRICS=${daily.length}',
      );
      for (final metric in daily) {
        final title = '${metric['title'] ?? ''}';
        final state = '${metric['state'] ?? ''}';
        final records = metric['records'] is List
            ? metric['records'] as List
            : const <Object?>[];
        expect(
          state,
          anyOf('ready', 'empty', 'unavailable'),
          reason: '$title 返回了未识别状态 $state',
        );
        if (state == 'ready') {
          readyMetricCount += 1;
          expect(records, isNotEmpty, reason: '$title 标记有数据但记录为空');
          if (const {
            '心率',
            '血压',
            '血糖',
            '血氧',
            '体温',
            'HRV',
            '睡眠',
          }.contains(title)) {
            expect(metric['latest'], isNotNull, reason: '$title 缺少最新值');
          }
          if (title == '血压') {
            expect('${metric['latest']}', contains('/'));
            expect('${metric['unit']}', 'mmHg');
          }
        } else {
          expect(records, isEmpty, reason: '$title 无数据状态仍包含记录');
        }
        debugPrint(
          'LIVE_CARE_METRIC:${index + 1}:$title:$state:'
          'RECORDS=${records.length}:UNIT=${metric['unit'] ?? ''}',
        );
      }
    }
    debugPrint('LIVE_CARE_READY_METRICS:$readyMetricCount');

    await tester.pumpWidget(SaydianApp(controller: controller));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('远程关爱').first);
    await _pumpUntil(
      tester,
      () => find.text('关爱成员').evaluate().isNotEmpty,
      const Duration(seconds: 20),
    );
    expect(find.byType(ListTile), findsNWidgets(controller.careMembers.length));

    await tester.tap(find.byType(ListTile).first);
    await _pumpUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      const Duration(seconds: 60),
    );
    expect(
      find.text('健康详情').evaluate().isNotEmpty ||
          find.textContaining('当前日期没有').evaluate().isNotEmpty,
      isTrue,
      reason: '成员详情页既没有健康详情，也没有真实空态',
    );
    debugPrint('LIVE_CARE_UI:OK');
  });
}

String _careFingerprint(Object? value) {
  const mask = 0xffffffff;
  var hash = 0x811c9dc5;
  for (final byte in 'saydian-live-care:${value ?? ''}'.codeUnits) {
    hash = ((hash ^ byte) * 0x01000193) & mask;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry('$key', value)))
      .toList(growable: false);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(condition(), isTrue);
}
