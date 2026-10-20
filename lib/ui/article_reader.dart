import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/module_visibility.dart';
import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';
import '../services/article_reading_preferences.dart';
import 'app_theme.dart';
import 'module_content_gate.dart';
import 'widgets/article_body.dart';
import 'widgets/safe_network_image.dart';

class ArticleReader extends StatefulWidget {
  const ArticleReader({
    required this.controller,
    required this.title,
    required this.contentHtml,
    required this.publishedDate,
    this.preferences,
    super.key,
  });

  final AppController controller;
  final String title;
  final String contentHtml;
  final String publishedDate;
  final ArticleReadingPreferences? preferences;

  @override
  State<ArticleReader> createState() => _ArticleReaderState();
}

class _ArticleReaderState extends State<ArticleReader> {
  late final _preferences =
      widget.preferences ?? ArticleReadingPreferences.instance;
  final _scroll = ScrollController(keepScrollOffset: false);
  int _fontRevision = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_preferences.load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _sizeLabel(ArticleTextSize size) => switch (size) {
    ArticleTextSize.standard => context.l10n.articleTextStandard,
    ArticleTextSize.large => context.l10n.articleTextLarge,
    ArticleTextSize.extraLarge => context.l10n.articleTextExtraLarge,
  };

  Future<void> _selectSize(ArticleTextSize size) async {
    final revision = ++_fontRevision;
    final fraction = _scroll.hasClients && _scroll.position.maxScrollExtent > 0
        ? _scroll.offset / _scroll.position.maxScrollExtent
        : 0.0;
    final saved = _preferences.select(size);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || revision != _fontRevision) return;
      _scroll.jumpTo(
        (fraction * _scroll.position.maxScrollExtent).clamp(
          0,
          _scroll.position.maxScrollExtent,
        ),
      );
    });
    if (!await saved && mounted && revision == _fontRevision) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.articleFontSaveFailed)),
      );
    }
  }

  Future<void> _chooseSize() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.articleReadingSettings,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.articleReadingPreview,
                style: const TextStyle(fontSize: 17, height: 1.6),
              ),
              const SizedBox(height: 16),
              RadioGroup<ArticleTextSize>(
                groupValue: _preferences.size,
                onChanged: (size) {
                  if (size == null) return;
                  Navigator.of(sheetContext).pop();
                  unawaited(_selectSize(size));
                },
                child: Column(
                  children: [
                    for (final size in ArticleTextSize.values)
                      RadioListTile<ArticleTextSize>(
                        key: ValueKey('article-size-${size.name}'),
                        value: size,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        title: Text(
                          '${_sizeLabel(size)} · ${size.points.toInt()}',
                          style: TextStyle(
                            fontSize: size.points,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _viewImage(String source, String? description) {
    if (!widget.controller.healthLibraryVisible) return;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _ArticleImagePage(
            controller: widget.controller,
            source: source,
            description: description,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) {
      final size = _preferences.size;
      return Scaffold(
        key: const Key('article-reader'),
        appBar: AppBar(title: Text(context.l10n.healthLibrary)),
        body: ColoredBox(
          color: Colors.white,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SelectionArea(
                child: ListView(
                  key: const Key('article-reader-scroll'),
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        key: const Key('article-reader-title'),
                        style: TextStyle(
                          fontSize: size.points + 8,
                          height: 1.45,
                          fontWeight: FontWeight.w800,
                          color: SaydianColors.ink,
                        ),
                      ),
                    ),
                    if (widget.publishedDate.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        widget.publishedDate,
                        style: TextStyle(
                          fontSize: size.points - 3,
                          color: SaydianColors.muted,
                          height: 1.6,
                        ),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1, color: SaydianColors.line),
                    ),
                    if (widget.contentHtml.trim().isEmpty)
                      Text(
                        context.l10n.articleContentUnavailable,
                        style: TextStyle(fontSize: size.points, height: 1.8),
                      )
                    else
                      ArticleBody(
                        htmlContent: widget.contentHtml,
                        fontSize: size.points,
                        onViewImage: _viewImage,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: SaydianColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('article-font-size'),
                    onPressed: _chooseSize,
                    icon: const Icon(Icons.text_fields_rounded),
                    label: Text(
                      '${context.l10n.articleFontSize} · ${_sizeLabel(size)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('article-back-to-top'),
                    onPressed: () {
                      if (_scroll.hasClients) {
                        unawaited(
                          _scroll.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.vertical_align_top_rounded),
                    label: Text(context.l10n.articleBackToTop),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ArticleImagePage extends StatelessWidget {
  const _ArticleImagePage({
    required this.controller,
    required this.source,
    required this.description,
  });
  final AppController controller;
  final String source;
  final String? description;

  @override
  Widget build(BuildContext context) => ModuleContentGate(
    controller: controller,
    module: SayRingModule.healthLibrary,
    onClosed: () {
      if (ModalRoute.of(context)?.isCurrent == true) {
        unawaited(Navigator.of(context).maybePop());
      }
    },
    builder: (context) => Scaffold(
      key: const Key('article-image-viewer'),
      appBar: AppBar(title: Text(context.l10n.articleViewImage)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.l10n.articleImageZoomHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, height: 1.6),
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: SafeNetworkImage(
                  source,
                  semanticLabel: description,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(context.l10n.imageUnavailable),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
