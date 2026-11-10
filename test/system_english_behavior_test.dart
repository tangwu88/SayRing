import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/pages.dart';

class _Units extends Fake implements AppController {
  @override
  String get distanceUnit => '公里';
  @override
  String get temperatureUnit => '摄氏度（℃）';
  String? distance;
  String? temperature;
  @override
  Future<void> setUnits({String? distance, String? temperature}) async {
    this.distance = distance ?? this.distance;
    this.temperature = temperature ?? this.temperature;
  }
}

void main() {
  testWidgets(
    'English copy preserves four-level battery units and phone identity',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Column(
              children: [
                Text(uiCopy(context, '{p0}/{p1} 格', parameters: [3, 4])),
                Text(uiCopy(context, '安卓手机')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('3/4 bars'), findsOneWidget);
      expect(find.text('Android phone'), findsOneWidget);
    },
  );
  testWidgets(
    'English unit selection retains stored tokens and changes labels only',
    (tester) async {
      final c = _Units();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: UnitSettingsPage(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      final options = tester
          .widgetList<RadioListTile<String>>(find.byType(RadioListTile<String>))
          .toList();
      expect(options.map((o) => o.value), ['公里', '英里', '摄氏度（℃）', '华氏度（℉）']);
      await tester.tap(find.byType(RadioListTile<String>).at(1));
      await tester.pump();
      expect(c.distance, '英里');
      await tester.tap(find.byType(RadioListTile<String>).at(3));
      await tester.pump();
      expect(c.temperature, '华氏度（℉）');
      expect(tester.takeException(), isNull);
    },
  );
}
