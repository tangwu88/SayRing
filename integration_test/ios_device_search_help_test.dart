import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/pages.dart';

import 'ios_calorie_provenance_test.dart' as calorie;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'search help opens and closes without changing the existing binding',
    (tester) async {
      final app = AppController.production();
      addTearDown(app.dispose);
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 60));
      final owner = app.session?.accountKey;
      final target = app.rememberedDevice?.id;
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => DeviceSearchPage(controller: app)),
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
      await tester.tap(find.byKey(const Key('device-search-help')));
      await tester.pump(const Duration(milliseconds: 400));
      final dialog = find.byKey(const Key('device-search-help-dialog'));
      expect(dialog, findsOneWidget);
      final l = AppLocalizations.of(tester.element(dialog))!;
      expect(find.text(l.deviceSearchHelpRebindIos), findsOneWidget);
      expect(find.text(l.deviceSearchHelpRebindAndroid), findsNothing);
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('1141-device-search-help-private');
      await tester.tap(find.byKey(const Key('device-search-help-close')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(dialog, findsNothing);
      expect(find.byType(DeviceSearchPage), findsOneWidget);
      expect(app.session?.accountKey, owner);
      expect(app.rememberedDevice?.id, target);
      navigator.pop();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      binding.reportData = {
        ...?binding.reportData,
        'searchHelp': {
          'openedAndClosed': true,
          'iosGuidance': true,
          'ownerUnchanged': app.session?.accountKey == owner,
          'targetUnchanged': app.rememberedDevice?.id == target,
        },
      };
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  calorie.main();
}
