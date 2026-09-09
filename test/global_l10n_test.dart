import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/l10n/global_locale_controller.dart';

class MemoryLocaleStore implements GlobalLocaleStore {
  String? value;
  bool failWrite = false;
  Completer<String?>? pendingRead;
  final writes = <String>[];
  @override
  Future<String?> read() async =>
      pendingRead == null ? value : pendingRead!.future;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('synthetic storage failure');
    writes.add(value);
    this.value = value;
  }
}

Widget localizedHost(GlobalLocaleController controller) => GlobalLocaleScope(
  controller: controller,
  child: ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      locale: controller.locale,
      supportedLocales: GlobalLocaleController.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.language)),
          body: Column(
            children: [const GlobalLanguageButton(), Text(context.l10n.signIn)],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test(
    'all eight declared languages have the complete key set and real translated labels',
    () {
      final base =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final expected = base.keys.where((key) => !key.startsWith('@')).toSet();
      expect(GlobalLocaleController.supportedLocales, hasLength(8));
      final signInTranslations = <String>{};
      for (final locale in GlobalLocaleController.supportedLocales) {
        final suffix = locale.toLanguageTag().replaceAll('-', '_');
        final rawCatalog = File('lib/l10n/app_$suffix.arb').readAsStringSync();
        final topLevelKeys = RegExp(
          r'^  "([^\"]+)":',
          multiLine: true,
        ).allMatches(rawCatalog).map((match) => match.group(1)!).toList();
        expect(
          topLevelKeys.toSet().length,
          topLevelKeys.length,
          reason:
              'Duplicate ARB keys in $suffix must not be silently overwritten.',
        );
        final messages = jsonDecode(rawCatalog) as Map<String, dynamic>;
        expect(
          messages.keys.where((key) => !key.startsWith('@')).toSet(),
          expected,
        );
        expect(
          messages.values.every(
            (value) => value is! String || value.trim().isNotEmpty,
          ),
          isTrue,
        );
        signInTranslations.add(messages['signIn'] as String);
      }
      expect(signInTranslations, hasLength(8));
    },
  );

  test(
    'first launch defaults to English and invalid saved locale cannot change it',
    () async {
      final store = MemoryLocaleStore()..value = 'invalid-locale';
      final controller = GlobalLocaleController(store: store);
      expect(controller.locale, const Locale('en'));
      await controller.load();
      expect(controller.locale, const Locale('en'));
      controller.dispose();
    },
  );

  test('selection persists and is restored by a new controller', () async {
    final store = MemoryLocaleStore();
    final first = GlobalLocaleController(store: store);
    expect(await first.setLocale(const Locale('de')), isTrue);
    expect(store.value, 'de');
    final restored = GlobalLocaleController(store: store);
    await restored.load();
    expect(restored.locale, const Locale('de'));
    first.dispose();
    restored.dispose();
  });

  test('late preference read cannot overwrite a new manual choice', () async {
    final store = MemoryLocaleStore()..pendingRead = Completer<String?>();
    final controller = GlobalLocaleController(store: store);
    final loading = controller.load();
    await controller.setLocale(const Locale('ja'));
    store.pendingRead!.complete('fr');
    await loading;
    expect(controller.locale, const Locale('ja'));
    controller.dispose();
  });

  test(
    'failed write leaves language unchanged and does not claim persistence',
    () async {
      final store = MemoryLocaleStore()..failWrite = true;
      final controller = GlobalLocaleController(store: store);
      expect(await controller.setLocale(const Locale('es')), isFalse);
      expect(controller.locale, const Locale('en'));
      expect(store.value, isNull);
      controller.dispose();
    },
  );

  test('rapid choices serialize and last successful selection wins', () async {
    final store = MemoryLocaleStore();
    final controller = GlobalLocaleController(store: store);
    await Future.wait([
      controller.setLocale(const Locale('fr')),
      controller.setLocale(const Locale('ko')),
    ]);
    expect(store.writes, ['fr', 'ko']);
    expect(controller.locale, const Locale('ko'));
    expect(store.value, 'ko');
    controller.dispose();
  });

  test(
    'Chinese scripts and common locale aliases retain the selected script',
    () {
      expect(
        GlobalLocaleController.normalize('zh-TW')?.toLanguageTag(),
        'zh-Hant',
      );
      expect(
        GlobalLocaleController.normalize('zh-CN')?.toLanguageTag(),
        'zh-Hans',
      );
      expect(GlobalLocaleController.normalize('fr-CA'), const Locale('fr'));
      expect(GlobalLocaleController.normalize('xx'), isNull);
    },
  );

  testWidgets(
    'English first launch ignores phone language and selection updates the visible UI',
    (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('de');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final controller = GlobalLocaleController(store: MemoryLocaleStore());
      await tester.pumpWidget(localizedHost(controller));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      await tester.tap(find.byKey(const Key('global-language-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('global-language-ja')));
      await tester.pumpAndSettle();
      expect(find.text('ログイン'), findsOneWidget);
      expect(controller.locale, const Locale('ja'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets(
      'language picker scrolls without overflow at 390px and text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final controller = GlobalLocaleController(store: MemoryLocaleStore());
        await tester.pumpWidget(localizedHost(controller));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('global-language-button')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('global-language-ko')),
        );
        await tester.tap(find.byKey(const ValueKey('global-language-ko')));
        await tester.pumpAndSettle();
        expect(find.text('로그인'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
