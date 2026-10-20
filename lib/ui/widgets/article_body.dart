import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../../l10n/global_locale_controller.dart';
import '../app_theme.dart';
import '../media_url.dart';
import 'safe_network_image.dart';

/// Render editorial structure using native text, ignoring scripts and page CSS.
class ArticleBody extends StatelessWidget {
  const ArticleBody({
    required this.htmlContent,
    required this.fontSize,
    required this.onViewImage,
    super.key,
  });

  final String htmlContent;
  final double fontSize;
  final void Function(String source, String? description) onViewImage;

  @override
  Widget build(BuildContext context) {
    final renderer = _ArticleRenderer(context, fontSize, onViewImage);
    if (!RegExp(r'<[a-zA-Z!/][^>]*>').hasMatch(htmlContent)) {
      return Text(
        html.parseFragment(htmlContent).text ?? '',
        style: renderer._body,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: renderer.blocks(html.parseFragment(htmlContent).nodes),
    );
  }
}

class _ArticleRenderer {
  _ArticleRenderer(this.context, this.fontSize, this.onViewImage);
  final BuildContext context;
  final double fontSize;
  final void Function(String source, String? description) onViewImage;
  int _imageIndex = 0;
  static const _ignored = {
    'script',
    'style',
    'noscript',
    'iframe',
    'object',
    'embed',
    'template',
    'form',
    'input',
    'button',
    'select',
    'textarea',
  };
  static const _containers = {
    'p',
    'div',
    'section',
    'article',
    'main',
    'figure',
    'figcaption',
    'header',
    'footer',
    'ul',
    'ol',
    'li',
    'blockquote',
    'table',
    'hr',
    'pre',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  };

  TextStyle get _body =>
      TextStyle(fontSize: fontSize, height: 1.8, color: SaydianColors.ink);

  List<Widget> blocks(Iterable<dom.Node> nodes) {
    final result = <Widget>[];
    final inline = <dom.Node>[];
    void flush() {
      final span = _inline(inline);
      if (span.toPlainText().trim().isNotEmpty) {
        result.add(_paragraph(span));
      }
      inline.clear();
    }

    for (final node in nodes) {
      final tag = node is dom.Element ? node.localName : null;
      if (_ignored.contains(tag)) continue;
      // Inline wrappers can contain an image or block-level editorial content.
      final containsBlocks =
          node is dom.Element &&
          node.querySelector('img,p,div,h1,h2,h3,h4,h5,h6,ul,ol,table') != null;
      if (node is! dom.Element ||
          (!_containers.contains(tag) && tag != 'img' && !containsBlocks)) {
        inline.add(node);
        continue;
      }
      flush();
      if (tag == 'img') {
        result.add(_image(node));
      } else if (RegExp(r'^h[1-6]$').hasMatch(tag ?? '')) {
        result.add(
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 12),
              child: Text.rich(
                _inline(node.nodes),
                style: _body.copyWith(
                  fontSize: fontSize + (tag == 'h1' ? 6 : 3),
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
            ),
          ),
        );
      } else if (tag == 'ul' || tag == 'ol') {
        result.addAll(_list(node, ordered: tag == 'ol'));
      } else if (tag == 'blockquote') {
        result.add(
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
            decoration: const BoxDecoration(
              color: SaydianColors.techBlueSoft,
              border: Border(
                left: BorderSide(color: SaydianColors.techBlue, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: blocks(node.nodes),
            ),
          ),
        );
      } else if (tag == 'pre') {
        result.add(_paragraph(TextSpan(text: node.text)));
      } else if (tag == 'table') {
        result.add(_table(node));
      } else if (tag == 'hr') {
        result.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
        );
      } else {
        result.addAll(blocks(node.nodes));
      }
    }
    flush();
    return result;
  }

  Widget _paragraph(InlineSpan span) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Text.rich(span, style: _body),
  );

  TextSpan _inline(Iterable<dom.Node> nodes) => TextSpan(
    children: [
      for (final node in nodes)
        if (node is dom.Text)
          TextSpan(text: node.data.replaceAll(RegExp(r'[\t\r\n ]+'), ' '))
        else if (node is dom.Element && !_ignored.contains(node.localName))
          if (node.localName == 'br')
            const TextSpan(text: '\n')
          else
            TextSpan(
              style: TextStyle(
                fontWeight: {'b', 'strong'}.contains(node.localName)
                    ? FontWeight.w700
                    : null,
                fontStyle: {'i', 'em'}.contains(node.localName)
                    ? FontStyle.italic
                    : null,
              ),
              children: [_inline(node.nodes)],
            ),
    ],
  );

  List<Widget> _list(dom.Element list, {required bool ordered}) {
    var number = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    return [
      for (final item in list.children.where((item) => item.localName == 'li'))
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Text(ordered ? '${number++}.' : '•', style: _body),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: blocks(item.nodes),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _table(dom.Element table) {
    final rows = table.querySelectorAll('tr');
    final columns = rows.fold<int>(
      0,
      (count, row) => count > row.children.length ? count : row.children.length,
    );
    if (columns == 0) return const SizedBox.shrink();
    // A visible horizontal scrollbar keeps large-font tables readable rather
    // than shrinking their text or clipping columns on a narrow phone.
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final caption in table.children.where(
            (item) => item.localName == 'caption',
          ))
            _paragraph(_inline(caption.nodes)),
          Text(
            context.l10n.articleTableHint,
            style: _body.copyWith(color: SaydianColors.muted),
          ),
          const SizedBox(height: 8),
          _ArticleTableScroll(
            child: SizedBox(
              width: columns * (fontSize * 8 + 24),
              child: Table(
                border: TableBorder.all(color: SaydianColors.line),
                defaultVerticalAlignment: TableCellVerticalAlignment.top,
                children: [
                  for (final row in rows)
                    TableRow(
                      children: [
                        for (var index = 0; index < columns; index++)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: index < row.children.length
                                ? DefaultTextStyle.merge(
                                    style: _body.copyWith(
                                      fontWeight:
                                          row.children[index].localName == 'th'
                                          ? FontWeight.w700
                                          : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: blocks(
                                        row.children[index].nodes,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image(dom.Element image) {
    final key = ValueKey('article-content-image-${_imageIndex++}');
    final source = normalizeArticleImageUrl(image.attributes['src'] ?? '');
    final description = image.attributes['alt']?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SafeNetworkImage(
              source,
              key: key,
              semanticLabel: description,
              fit: BoxFit.fitWidth,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (_, _, _) => Container(
                height: 120,
                alignment: Alignment.center,
                color: SaydianColors.canvas,
                child: Text(context.l10n.imageUnavailable),
              ),
            ),
          ),
          if (source.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => onViewImage(source, description),
                icon: const Icon(Icons.zoom_in_rounded),
                label: Text(context.l10n.articleViewImage),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArticleTableScroll extends StatefulWidget {
  const _ArticleTableScroll({required this.child});
  final Widget child;

  @override
  State<_ArticleTableScroll> createState() => _ArticleTableScrollState();
}

class _ArticleTableScrollState extends State<_ArticleTableScroll> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _scroll,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 16),
      child: widget.child,
    ),
  );
}
