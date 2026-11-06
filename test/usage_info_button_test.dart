import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/ui/widgets/usage_info_button.dart';

void main() {
  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets('explanation scrolls and closes at double text size: $locale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final message = List.filled(
        18,
        '测量说明 · Measurement information',
      ).join('\n');
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('健康问答'),
              actions: [UsageInfoButton(message: message, iconOnly: true)],
            ),
            body: const Text('原页面'),
          ),
        ),
      );
      expect(find.text(message), findsNothing);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      final close = find.text(locale.languageCode == 'zh' ? '关闭' : 'Close');
      await tester.ensureVisible(close);
      await tester.pumpAndSettle();
      expect(close.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
      expect(find.text('原页面'), findsOneWidget);
    });
  }
}
