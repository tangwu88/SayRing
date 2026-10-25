import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/pages.dart';

import 'ios_profile_api_diagnostic_test.dart' as profile;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  profile.main();
  testWidgets(
    'XR reauthenticated profile and inbox render real API results',
    (tester) async {
      final app = AppController.production();
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      final owner = app.session?.accountKey;
      final target = app.rememberedDevice?.id;
      expect(owner, isNotNull);
      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/xr-account-20261025',
      );
      await dir.create(recursive: true);
      final proof = <String, Object?>{};
      Future<void> settle() async {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump().timeout(const Duration(seconds: 15));
      }

      Future<void> save(String name) async {
        final bytes = await binding.takeScreenshot('xr-account-$name');
        await File('${dir.path}/$name.png').writeAsBytes(bytes);
        await File('${dir.path}/proof.json').writeAsString(jsonEncode(proof));
        binding.reportData = {...?binding.reportData, 'accountPages': proof};
      }

      await app.refreshMemberProfile().timeout(const Duration(seconds: 30));
      expect(app.memberProfile, isNotEmpty);
      proof['memberProfileLoaded'] = true;
      app.selectTab(2);
      await settle();
      await tester.tap(find.byKey(const Key('profile-header-card')));
      await settle();
      expect(find.byType(ProfileEditPage), findsOneWidget);
      for (
        var i = 0;
        i < 30 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await settle();
      }
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final field = tester.widget<TextField>(
        find.byKey(const Key('profile-nickname')),
      );
      expect(field.controller?.text, '${app.memberProfile['nickname'] ?? ''}');
      expect(find.textContaining('This action could not'), findsNothing);
      expect(tester.takeException(), isNull);
      proof['profilePageLoaded'] = true;
      await save('profile-private');
      await tester.binding.handlePopRoute();
      await settle();
      app.selectTab(0);
      await settle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await settle();
      await tester.tap(
        find.byIcon(Icons.notifications_none_rounded).hitTestable(),
      );
      await settle();
      expect(find.byType(NotificationsPage), findsOneWidget);
      await app.refreshNotifications().timeout(const Duration(seconds: 30));
      await settle();
      expect(app.notificationStatus, anyOf('暂无消息', '已加载'));
      expect(find.textContaining('This action could not'), findsNothing);
      expect(tester.takeException(), isNull);
      proof['inboxLoaded'] = true;
      await save('inbox-private');
      await tester.binding.handlePopRoute();
      await settle();
      for (var i = 0; i < 30 && app.connectedDevice == null; i++) {
        await settle();
      }
      proof['connectedAtEnd'] =
          target != null && app.connectedDevice?.id == target;
      proof['ownerUnchanged'] = app.session?.accountKey == owner;
      proof['targetUnchanged'] = app.rememberedDevice?.id == target;
      await save('home-private');
      expect(proof['ownerUnchanged'], isTrue);
      expect(proof['targetUnchanged'], isTrue);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
