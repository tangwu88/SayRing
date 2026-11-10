import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/l10n/global_locale_controller.dart';
import 'package:saydian_app/l10n/legacy_ui_copy.dart';

class MemoryLocaleStore implements GlobalLocaleStore {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('test');
    this.value = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final item in <(Locale, String)>[
    (const Locale('en', 'US'), 'en'),
    (const Locale('en', 'GB'), 'en'),
    (const Locale('zh', 'CN'), 'zh-Hans'),
    (const Locale('zh', 'SG'), 'zh-Hans'),
    (const Locale('zh'), 'zh-Hans'),
    (
      const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: 'CN',
      ),
      'zh-Hans',
    ),
    (
      const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
      'en',
    ),
    (const Locale('zh', 'HK'), 'en'),
    (const Locale('fr', 'FR'), 'en'),
    (const Locale('ja'), 'en'),
    (const Locale('xx'), 'en'),
  ]) {
    test(
      'system ${item.$1.toLanguageTag()} resolves to ${item.$2} before storage',
      () async {
        final store = MemoryLocaleStore()..value = 'zh-Hans';
        final c = GlobalLocaleController(
          store: store,
          systemLocale: () => item.$1,
        );
        expect(c.locale.toLanguageTag(), item.$2);
        await c.load();
        expect(c.locale.toLanguageTag(), item.$2);
        expect(store.value, 'zh-Hans');
        c.dispose();
      },
    );
  }
  test(
    'upgraded fixed Chinese preference does not override system and resumes follow changes',
    () async {
      var system = const Locale('en');
      final c = GlobalLocaleController(
        store: MemoryLocaleStore()..value = 'zh-Hans',
        systemLocale: () => system,
      );
      await c.load();
      expect(c.locale, const Locale('en'));
      system = const Locale('zh', 'CN');
      c.refreshSystemLocale();
      expect(c.locale.toLanguageTag(), 'zh-Hans');
      system = const Locale('de');
      c.refreshSystemLocale();
      expect(c.locale, const Locale('en'));
      c.dispose();
    },
  );
  test('two supported catalogues retain matching nonempty ARB keys', () {
    expect(GlobalLocaleController.supportedLocales, hasLength(2));
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final zh =
        jsonDecode(File('lib/l10n/app_zh_Hans.arb').readAsStringSync()) as Map;
    Set keys(Map v) => v.keys.where((k) => !k.startsWith('@')).toSet();
    expect(keys(zh), keys(en));
    for (final value in legacyUiEnglish.values) {
      expect(value.trim(), isNotEmpty);
      expect(
        RegExp(r'[\u4e00-\u9fff]').hasMatch(value),
        isFalse,
        reason: value,
      );
    }
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'English scope renders app copy and keeps parameter text at scale $scale',
      (tester) async {
        final c = GlobalLocaleController(
          initialLocale: const Locale('en'),
          store: MemoryLocaleStore(),
        );
        await tester.pumpWidget(
          GlobalLocaleScope(
            controller: c,
            child: MaterialApp(
              locale: c.locale,
              supportedLocales: GlobalLocaleController.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Column(
                      children: [
                        const GlobalLanguageButton(),
                        Text(uiCopy(context, '生理周期')),
                        Text(
                          uiCopy(
                            context,
                            '已连接 {p0}。{p1}',
                            parameters: ['张{p1}', '原始报告不翻译'],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Cycle tracking'), findsOneWidget);
        expect(find.text('Connected to 张{p1}. 原始报告不翻译'), findsOneWidget);
        expect(find.byIcon(Icons.language), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
}
