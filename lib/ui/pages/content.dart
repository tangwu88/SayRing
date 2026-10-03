import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/app_controller.dart';
import '../../l10n/global_locale_controller.dart';
import 'package:intl/intl.dart';
import '../widgets/safe_network_image.dart';
import '../html_text.dart';
import '../media_url.dart';

/// International content uses opaque string IDs and the global content service.
/// Language changes reload content instead of displaying the previous language
/// as if the server had supplied a translation.
class GlobalArticleLibraryPage extends StatefulWidget {
  const GlobalArticleLibraryPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<GlobalArticleLibraryPage> createState() =>
      _GlobalArticleLibraryPageState();
}

class _GlobalArticleLibraryPageState extends State<GlobalArticleLibraryPage> {
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _moreFailed = false;
  List<Map<String, Object?>> _categories = const [];
  List<Map<String, Object?>> _articles = const [];
  String? _selectedCategory;
  String? _contentLocale;
  int _generation = 0;
  bool _loading = true;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contentLocale != context.l10n.localeName) {
      _contentLocale = context.l10n.localeName;
      _selectedCategory = null;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      // Optional categories must not hide articles that loaded successfully.
      final categoriesFuture = widget.controller
          .loadGlobalArticleCategories()
          .catchError((Object _) => <Map<String, Object?>>[]);
      final articles = await widget.controller.loadGlobalArticles(
        categoryId: _selectedCategory,
      );
      final categories = await categoriesFuture;
      if (!mounted || generation != _generation) return;
      setState(() {
        _categories = categories
            .where((item) => '${item['id'] ?? ''}'.trim().isNotEmpty)
            .toList();
        _articles = articles
            .where((item) => '${item['id'] ?? ''}'.trim().isNotEmpty)
            .toList();
        _loading = false;
        _page = 1;
        _hasMore = articles.length == 30;
        _loadingMore = false;
        _moreFailed = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final rows = await widget.controller.loadGlobalArticles(
        categoryId: _selectedCategory,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final byId = <String, Map<String, Object?>>{
          for (final row in _articles) '${row['id']}': row,
        };
        for (final row in rows) {
          final id = '${row['id'] ?? ''}'.trim();
          if (id.isNotEmpty) byId[id] = row;
        }
        _articles = byId.values.toList();
        _page++;
        _hasMore = rows.length == 30;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  void _select(String? category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-article-library'),
    appBar: AppBar(title: Text(context.l10n.healthLibrary)),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? _ArticleLoadFailure(onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (_categories.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const Key('global-article-category-all'),
                        label: Text(context.l10n.all),
                        selected: _selectedCategory == null,
                        onSelected: (_) => _select(null),
                      ),
                      for (final category in _categories)
                        ChoiceChip(
                          key: ValueKey(
                            'global-article-category-${category['id']}',
                          ),
                          label: Text(
                            '${category['title'] ?? category['name'] ?? context.l10n.healthLibrary}',
                          ),
                          selected: _selectedCategory == '${category['id']}',
                          onSelected: (_) => _select('${category['id']}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_articles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: Text(context.l10n.articlesEmpty)),
                  )
                else
                  for (final article in _articles) ...[
                    Card(
                      key: ValueKey('global-article-${article['id']}'),
                      child: ArticleTile(
                        article: article,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ArticleDetailPage(
                              controller: widget.controller,
                              article: article,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                if (_hasMore)
                  TextButton(
                    key: const Key('global-article-load-more'),
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(
                      _loadingMore
                          ? '加载中'
                          : _moreFailed
                          ? '加载失败，重试'
                          : '加载更多',
                    ),
                  ),
              ],
            ),
          ),
  );
}

class ArticleCategoryPage extends StatefulWidget {
  const ArticleCategoryPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<ArticleCategoryPage> createState() => _ArticleCategoryPageState();
}

class _ArticleCategoryPageState extends State<ArticleCategoryPage> {
  List<Map<String, Object?>> _categories = const [];
  List<Map<String, Object?>> _articles = const [];
  int? _selectedCategoryId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (!widget.controller.isGlobalEdition) unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final categories = await widget.controller.loadArticleCategories();
    final articles = await widget.controller.loadArticlesByCategory(
      categoryId: _selectedCategoryId,
    );
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _articles = articles;
      _loading = false;
    });
  }

  Future<void> _selectCategory(int? categoryId) async {
    if (_selectedCategoryId == categoryId && !_loading) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _loading = true;
    });
    final articles = await widget.controller.loadArticlesByCategory(
      categoryId: categoryId,
    );
    if (!mounted) return;
    setState(() {
      _articles = articles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isGlobalEdition) {
      return GlobalArticleLibraryPage(controller: widget.controller);
    }
    final error = widget.controller.articleCategoryLoadError;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.healthLibrary)),
      body: Column(
        key: const Key('article-category-page'),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0x11000000))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '健康分类',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        key: const Key('article-category-all'),
                        label: Text(context.l10n.all),
                        selected: _selectedCategoryId == null,
                        onSelected: (_) => _selectCategory(null),
                      ),
                      for (final category in _categories) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            '${category['title'] ?? category['name'] ?? '健康知识'}',
                          ),
                          selected:
                              _selectedCategoryId ==
                              int.tryParse('${category['id'] ?? ''}'),
                          onSelected: (_) => _selectCategory(
                            int.tryParse('${category['id'] ?? ''}'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : error != null ||
                      widget.controller.articleListLoadError != null
                ? _ArticleLoadFailure(onRetry: _load)
                : _articles.isEmpty
                ? RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('该分类暂无百科内容')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: _articles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final article = _articles[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ArticleTile(
                            article: article,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ArticleDetailPage(
                                  controller: widget.controller,
                                  article: article,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ArticleListPage extends StatefulWidget {
  const ArticleListPage({
    required this.controller,
    this.title = '健康百科',
    this.categoryId,
    super.key,
  });

  final AppController controller;
  final String title;
  final int? categoryId;

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  List<Map<String, Object?>> _articles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (!widget.controller.isGlobalEdition) unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final articles = await widget.controller.loadArticlesByCategory(
      categoryId: widget.categoryId,
    );
    if (!mounted) return;
    setState(() {
      _articles = articles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isGlobalEdition) {
      return GlobalArticleLibraryPage(controller: widget.controller);
    }
    final error = widget.controller.articleListLoadError;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _ArticleLoadFailure(onRetry: _load)
          : _articles.isEmpty
          ? const Center(child: Text('该分类暂无百科内容'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _articles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final article = _articles[index];
                  return Card(
                    child: ArticleTile(
                      article: article,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ArticleDetailPage(
                            controller: widget.controller,
                            article: article,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ArticleLoadFailure extends StatelessWidget {
  const _ArticleLoadFailure({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 12),
            Text(context.l10n.articlesUnavailable),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('article-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.reload),
            ),
          ],
        ),
      ),
    );
  }
}

String _articleDateText(Object? value) {
  DateTime? date;
  if (value is DateTime) {
    date = value;
  } else {
    final text = value is String ? value.trim() : null;
    final timestamp = value is num ? value : num.tryParse(text ?? '');
    if (timestamp != null) {
      // Legacy content uses epoch seconds; newer responses may use milliseconds.
      if (!timestamp.isFinite || timestamp <= 0) return '';
      final milliseconds = timestamp >= 100000000000
          ? timestamp
          : timestamp * 1000;
      if (!milliseconds.isFinite || milliseconds > 8640000000000000) {
        return '';
      }
      date = DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt());
    } else if (text != null && text.isNotEmpty) {
      date = DateTime.tryParse(text);
    }
  }
  return date == null ? '' : DateFormat('yyyy-MM-dd').format(date.toLocal());
}

class ArticleTile extends StatelessWidget {
  const ArticleTile({required this.article, required this.onTap, super.key});

  final Map<String, Object?> article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = '${article['title'] ?? context.l10n.healthLibrary}';
    final created =
        article['publishedAt'] ?? article['createdAt'] ?? article['created_at'];
    final date = _articleDateText(created);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE8F7ED),
        foregroundColor: Color(0xFF258A4A),
        child: Icon(Icons.menu_book_rounded),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: date.isEmpty ? null : Text(date),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({
    required this.controller,
    required this.article,
    this.singleArticle = false,
    super.key,
  });

  final AppController controller;
  final Map<String, Object?> article;
  final bool singleArticle;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late Map<String, Object?> _article;
  String? _articleId;
  bool _loading = false;
  bool _globalLoadFailed = false;
  int _loadGeneration = 0;
  String? _contentLocale;

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    final id = '${widget.article['id'] ?? ''}'.trim();
    _articleId = id.isEmpty ? null : id;
    if (!widget.controller.isGlobalEdition && _articleId != null) {
      unawaited(_load());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.controller.isGlobalEdition &&
        _contentLocale != context.l10n.localeName) {
      _contentLocale = context.l10n.localeName;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final id = _articleId;
    if (id == null) return;
    if (widget.controller.isGlobalEdition) {
      final generation = ++_loadGeneration;
      setState(() {
        _loading = true;
        _globalLoadFailed = false;
      });
      try {
        final article = await widget.controller.loadGlobalArticle(id);
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _article = article;
          _loading = false;
        });
      } catch (error, stack) {
        debugPrint('Global article load failed: $error\n$stack');
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _loading = false;
          _globalLoadFailed = true;
        });
      }
      return;
    }
    final legacyId = int.tryParse(id);
    if (legacyId == null) return;
    if (mounted) setState(() => _loading = true);
    final article = widget.singleArticle
        ? await widget.controller.loadSingleArticle(legacyId)
        : await widget.controller.loadArticle(legacyId);
    if (!mounted) return;
    setState(() {
      if (article.isNotEmpty) _article = article;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = '${_article['title'] ?? context.l10n.healthLibrary}';
    final raw =
        '${_article['contentHtml'] ?? _article['content'] ?? _article['description'] ?? ''}';
    final hasError = widget.controller.isGlobalEdition
        ? _globalLoadFailed
        : widget.controller.articleDetailLoadError != null;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : hasError
          ? _ArticleLoadFailure(onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                if (raw.trim().isEmpty)
                  Text(
                    context.l10n.articleContentUnavailable,
                    style: const TextStyle(fontSize: 15, height: 1.75),
                  )
                else
                  ..._articleContentWidgets(context, raw),
              ],
            ),
    );
  }
}

List<Widget> _articleContentWidgets(BuildContext context, String raw) {
  final imagePattern = RegExp(
    r'''<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>''',
    caseSensitive: false,
  );
  final widgets = <Widget>[];
  var cursor = 0;
  var imageIndex = 0;
  for (final match in imagePattern.allMatches(raw)) {
    final text = plainTextFromHtml(raw.substring(cursor, match.start));
    if (text.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.75)),
        ),
      );
    }
    final source = normalizeArticleImageUrl(match.group(1) ?? '');
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SafeNetworkImage(
            source,
            key: ValueKey('article-content-image-${imageIndex++}'),
            fit: BoxFit.fitWidth,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, _, _) => Container(
              height: 120,
              alignment: Alignment.center,
              color: const Color(0xFFF0F6FF),
              child: Text(context.l10n.imageUnavailable),
            ),
          ),
        ),
      ),
    );
    cursor = match.end;
  }
  final tail = plainTextFromHtml(raw.substring(cursor));
  if (tail.isNotEmpty) {
    widgets.add(Text(tail, style: const TextStyle(fontSize: 15, height: 1.75)));
  }
  return widgets;
}
