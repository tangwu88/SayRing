import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/module_visibility.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/article_reading_preferences.dart';
import 'package:saydian_app/ui/app_theme.dart';
import 'package:saydian_app/ui/article_reader.dart';
import 'package:saydian_app/ui/widgets/article_body.dart';

class _Store implements ArticleReadingStore {
  String? value;
  Completer<String?>? delayedRead;
  Completer<void>? delayedWrite;
  bool fail = false;

  @override
  Future<String?> read() => delayedRead?.future ?? Future.value(value);

  @override
  Future<void> write(String next) async {
    if (fail) throw StateError('Synthetic storage failure');
    await delayedWrite?.future;
    value = next;
  }
}

class _Controller extends ChangeNotifier implements AppController {
  bool visible = true;
  @override
  bool get healthLibraryVisible => visible;
  @override
  ModuleVisibilityLease? get moduleVisibility => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester, {
  required _Controller controller,
  required ArticleReadingPreferences preferences,
  String content = '<h2>小节标题</h2><p>可以清楚阅读的正文段落。</p>',
  double width = 390,
  double scale = 1,
  Locale locale = const Locale('zh', 'Hans'),
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSaydianTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ArticleReader(
        controller: controller,
        title: '健康百科阅读展示示例',
        contentHtml: content,
        publishedDate: '2026-10-20',
        preferences: preferences,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('plain text retains its original line breaks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticleBody(
            htmlContent: '第一行\n第二行 &amp; 原文',
            fontSize: 18,
            onViewImage: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.text('第一行\n第二行 & 原文'), findsOneWidget);
  });

  test('a late preference read cannot undo a chosen font size', () async {
    final store = _Store()..delayedRead = Completer<String?>();
    final preferences = ArticleReadingPreferences(store: store);
    addTearDown(preferences.dispose);
    final loading = preferences.load();
    await preferences.select(ArticleTextSize.extraLarge);
    store.delayedRead!.complete('standard');
    await loading;
    expect(preferences.size, ArticleTextSize.extraLarge);
    expect(store.value, 'extraLarge');
  });

  test(
    'fast font selections persist the last choice across a restart',
    () async {
      final store = _Store()..delayedWrite = Completer<void>();
      final preferences = ArticleReadingPreferences(store: store);
      addTearDown(preferences.dispose);
      final first = preferences.select(ArticleTextSize.extraLarge);
      final last = preferences.select(ArticleTextSize.large);
      store.delayedWrite!.complete();
      expect(await first, true);
      expect(await last, true);
      final restored = ArticleReadingPreferences(store: store);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.size, ArticleTextSize.large);
    },
  );

  testWidgets(
    'native article structure retains headings, lists and safe text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArticleBody(
                fontSize: 18,
                onViewImage: (_, _) {},
                htmlContent: '''
        <style>HIDDEN_STYLE</style><script>HIDDEN_SCRIPT</script>
        <h2>清晰的小标题</h2><p>保留<strong>重点</strong>与 &amp; 实体。</p>
        <ol start="3"><li>第一项</li><li>第二项</li></ol>
        <blockquote><p>引用内容</p></blockquote>
        <p>结尾<br>换行文字</p>
      ''',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in [
        '清晰的小标题',
        '保留重点与 & 实体。',
        '第一项',
        '第二项',
        '3.',
        '4.',
        '引用内容',
        '结尾\n换行文字',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.textContaining('HIDDEN'), findsNothing);
      expect(
        tester.widget<Text>(find.text('清晰的小标题')).style!.fontWeight,
        FontWeight.w800,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final sample in [
    (320.0, 1.0, const Locale('zh', 'Hans')),
    (320.0, 2.0, const Locale('zh', 'Hans')),
    (320.0, 2.0, const Locale('de')),
  ]) {
    testWidgets(
      'large font controls fit ${sample.$1} at ${sample.$2}x ${sample.$3}',
      (tester) async {
        final controller = _Controller();
        final store = _Store();
        final preferences = ArticleReadingPreferences(store: store);
        addTearDown(controller.dispose);
        addTearDown(preferences.dispose);
        await _pump(
          tester,
          controller: controller,
          preferences: preferences,
          width: sample.$1,
          scale: sample.$2,
          locale: sample.$3,
        );
        final before = tester
            .widget<Text>(find.text('可以清楚阅读的正文段落。'))
            .style!
            .fontSize!;
        await tester.tap(find.byKey(const Key('article-font-size')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('article-size-extraLarge')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('article-size-extraLarge')));
        await tester.pumpAndSettle();
        expect(preferences.size, ArticleTextSize.extraLarge);
        expect(store.value, 'extraLarge');
        await tester.scrollUntilVisible(
          find.text('可以清楚阅读的正文段落。'),
          160,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('article-reader-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('可以清楚阅读的正文段落。')).style!.fontSize,
          greaterThan(before),
        );
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.byType(ArticleBody)),
          ).scale(10),
          10 * sample.$2,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('font size keeps reading progress and back to top works', (
    tester,
  ) async {
    final controller = _Controller();
    final preferences = ArticleReadingPreferences(store: _Store());
    addTearDown(controller.dispose);
    addTearDown(preferences.dispose);
    await _pump(
      tester,
      controller: controller,
      preferences: preferences,
      content: List.generate(
        36,
        (index) => '<h2>小节 $index</h2><p>这是较长的阅读段落，用于检查改变字号后仍保留阅读位置。</p>',
      ).join(),
    );
    final scroll = tester
        .widget<ListView>(find.byKey(const Key('article-reader-scroll')))
        .controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent * .45);
    await tester.pump();
    await tester.tap(find.byKey(const Key('article-font-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('article-size-large')));
    await tester.pumpAndSettle();
    expect(scroll.offset / scroll.position.maxScrollExtent, closeTo(.45, .02));
    await tester.tap(find.byKey(const Key('article-back-to-top')));
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed preference saving keeps readable text and reports failure',
    (tester) async {
      final controller = _Controller();
      final preferences = ArticleReadingPreferences(
        store: _Store()..fail = true,
      );
      addTearDown(controller.dispose);
      addTearDown(preferences.dispose);
      await _pump(tester, controller: controller, preferences: preferences);
      await tester.tap(find.byKey(const Key('article-font-size')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('article-size-large')));
      await tester.pumpAndSettle();
      expect(preferences.size, ArticleTextSize.large);
      expect(find.text('本次字号已调整，暂时无法记住设置。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a narrow large-font table scrolls without losing its cells', (
    tester,
  ) async {
    final controller = _Controller();
    final preferences = ArticleReadingPreferences(store: _Store());
    addTearDown(controller.dispose);
    addTearDown(preferences.dispose);
    await preferences.select(ArticleTextSize.extraLarge);
    await _pump(
      tester,
      controller: controller,
      preferences: preferences,
      width: 320,
      scale: 2,
      content:
          '<table><caption>原文表格标题</caption><tr><th>第一列</th><th>第二列</th></tr><tr><td>原文甲</td><td>原文乙</td></tr></table>',
    );
    await tester.scrollUntilVisible(
      find.byType(ArticleBody),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('article-reader-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final horizontal = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.right,
    );
    expect(horizontal, findsOneWidget);
    await tester.drag(horizontal, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('原文乙'), findsOneWidget);
    expect(find.text('原文表格标题'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
