import 'dart:async';

import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/app_controller.dart';
import 'online_support_page.dart';
import 'widgets/article_body.dart';
import 'widgets/safe_network_image.dart';

class SupportFaqPage extends StatefulWidget {
  const SupportFaqPage({
    required this.controller,
    this.apiOverride,
    this.showContact = true,
    super.key,
  });
  final AppController controller;
  final OnlineSupportApi? apiOverride;
  final bool showContact;
  @override
  State<SupportFaqPage> createState() => _SupportFaqPageState();
}

class _SupportFaqPageState extends State<SupportFaqPage> {
  final _search = TextEditingController();
  final _articles = <Map<String, Object?>>[];
  Timer? _debounce;
  int _generation = 0;
  int? _next;
  String? _language, _displayLanguage;
  bool _loading = true, _failed = false;
  Completer<void> _stop = Completer<void>();
  OnlineSupportApi? get _api =>
      widget.apiOverride ?? widget.controller.onlineSupportApi;
  String tr(String zh, String en) => supportCopy(context, zh, en);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode == 'zh'
        ? 'zh-Hans'
        : 'en';
    if (_language != lang) {
      _language = lang;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    ++_generation;
    _stop.complete();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) {
      _stop.complete();
      _stop = Completer<void>();
    }
    final version = ++_generation;
    final q = _search.text.trim();
    setState(() {
      _loading = true;
      _failed = false;
      if (!more) {
        _articles.clear();
        _next = null;
        _displayLanguage = null;
      }
    });
    try {
      final api = _api;
      if (api == null) return;
      final data = await api.supportRequest(
        'faq',
        query: {
          if (q.isNotEmpty) 'q': q,
          'language': (more ? _displayLanguage : null) ?? _language ?? 'en',
          if (more && _next != null) 'offset': '$_next',
        },
        stop: _stop.future,
      );
      if (!mounted || version != _generation) return;
      setState(() {
        _articles.addAll(supportRows(data['items']));
        _next = data['nextOffset'] is int ? data['nextOffset'] as int : null;
        _displayLanguage = data['locale'] as String?;
      });
    } on ApiException catch (e) {
      if (mounted && version == _generation && e.statusCode != 404) {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted && version == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && version == _generation) setState(() => _loading = false);
    }
  }

  void _changed(String value) {
    _debounce?.cancel();
    ++_generation;
    _stop.complete();
    _stop = Completer<void>();
    setState(() {
      _articles.clear();
      _next = null;
      _loading = true;
      _failed = false;
    });
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_load()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('support-faq'),
    appBar: AppBar(title: Text(tr('常见问题', 'Frequently asked questions'))),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          TextField(
            key: const Key('support-faq-search'),
            controller: _search,
            maxLength: 80,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _debounce?.cancel();
              unawaited(_load());
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: tr('搜索常见问题', 'Search questions'),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          if (_articles.isEmpty && !_loading && !_failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _search.text.trim().isEmpty
                    ? tr('暂无已发布的常见问题', 'No questions have been published yet')
                    : tr('没有找到相关问题', 'No matching questions'),
                textAlign: TextAlign.center,
              ),
            ),
          for (final row in _articles)
            if (isSupportId(row['id']))
              Card(
                child: ListTile(
                  title: Text('${row['title'] ?? ''}'),
                  subtitle: _language == 'en' && row['locale'] == 'zh-Hans'
                      ? const Text('中文')
                      : null,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SupportArticlePage(
                        api: _api!,
                        articleId: row['id'] as String,
                      ),
                    ),
                  ),
                ),
              ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loading && (_failed || _next != null))
            TextButton(
              onPressed: () => _load(more: _next != null),
              child: Text(
                _failed ? tr('重试', 'Retry') : tr('查看更多', 'Load more'),
              ),
            ),
          if (widget.showContact)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OnlineSupportPage(
                    controller: widget.controller,
                    apiOverride: widget.apiOverride,
                  ),
                ),
              ),
              icon: const Icon(Icons.support_agent_rounded),
              label: Text(tr('联系客服', 'Contact support')),
            ),
        ],
      ),
    ),
  );
}

class SupportArticlePage extends StatefulWidget {
  const SupportArticlePage({
    required this.api,
    required this.articleId,
    super.key,
  });
  final OnlineSupportApi api;
  final String articleId;
  @override
  State<SupportArticlePage> createState() => _SupportArticlePageState();
}

class _SupportArticlePageState extends State<SupportArticlePage> {
  final _stop = Completer<void>();
  late Future<Map<String, Object?>> _result = _load();
  Future<Map<String, Object?>> _load() =>
      widget.api.supportRequest('faq/${widget.articleId}', stop: _stop.future);
  @override
  void dispose() {
    _stop.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(supportCopy(context, '帮助文章', 'Help article'))),
    body: FutureBuilder(
      future: _result,
      builder: (context, result) {
        if (result.hasData) {
          final data = result.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Text(
                '${data['title'] ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (Localizations.localeOf(context).languageCode != 'zh' &&
                  data['locale'] == 'zh-Hans')
                const Text('中文'),
              const SizedBox(height: 14),
              ArticleBody(
                htmlContent: '${data['contentHtml'] ?? ''}',
                fontSize: 16,
                onViewImage: (src, alt) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(),
                      body: Center(
                        child: InteractiveViewer(
                          child: SafeNetworkImage(src, semanticLabel: alt),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        if (result.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  supportCopy(context, '文章暂时无法查看', 'Article is unavailable'),
                ),
                TextButton(
                  onPressed: () => setState(() => _result = _load()),
                  child: Text(supportCopy(context, '重试', 'Retry')),
                ),
              ],
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    ),
  );
}
