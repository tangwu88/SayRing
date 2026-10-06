import 'dart:async';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;

import '../l10n/generated/app_localizations.dart';
import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';

enum GlobalLegalDocumentType {
  userAgreement('userAgreement', 'say_ring_user_agreement'),
  privacyPolicy('privacyPolicy', 'say_ring_privacy_policy');

  const GlobalLegalDocumentType(this.capabilityKey, this.documentType);
  final String capabilityKey;
  final String documentType;
}

/// Published legal content only. Loading a page never records consent.
class GlobalLegalPage extends StatefulWidget {
  const GlobalLegalPage({
    super.key,
    required this.controller,
    required this.document,
  });

  final AppController controller;
  final GlobalLegalDocumentType document;

  @override
  State<GlobalLegalPage> createState() => _GlobalLegalPageState();
}

class _GlobalLegalPageState extends State<GlobalLegalPage> {
  String _locale = '';
  int _generation = 0;
  bool _loading = true;
  String? _title;
  String? _text;
  String? _version;
  String? _documentLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_locale == locale) return;
    _locale = locale;
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _title = null;
      _text = null;
      _version = null;
      _documentLanguage = null;
    });
    try {
      final capabilities = await widget.controller.globalAuthCapabilities();
      if (!mounted || generation != _generation) return;
      final version = capabilities.consentVersion;
      final path = capabilities.legal[widget.document.capabilityKey];
      final uri = path == null ? null : Uri.tryParse(path);
      if (version == null ||
          version.trim().isEmpty ||
          uri == null ||
          uri.pathSegments.lastOrNull != widget.document.documentType ||
          uri.queryParametersAll['version']?.length != 1 ||
          uri.queryParameters['version'] != version ||
          uri.queryParametersAll['locale']?.length != 1 ||
          uri.queryParameters['locale']?.isNotEmpty != true) {
        throw const FormatException('Published legal reference required');
      }
      final document = await widget.controller.globalLegalDocument(path!);
      if (!mounted || generation != _generation) return;
      if (document['documentType'] != widget.document.documentType ||
          document['version'] != version ||
          document['locale'] != uri.queryParameters['locale'] ||
          document['reviewed'] != true ||
          document['contentHtml'] is! String) {
        throw const FormatException('Published legal document mismatch');
      }
      final parsed = html.parse(
        (document['contentHtml'] as String).replaceAll(
          RegExp(r'</(?:p|div|li|h[1-6])>|<br\s*/?>', caseSensitive: false),
          '\n\n',
        ),
      );
      for (final node in parsed.querySelectorAll('script, style, noscript')) {
        node.remove();
      }
      final text = parsed.body?.text.trim() ?? '';
      if (text.isEmpty) throw const FormatException('Empty legal document');
      setState(() {
        _title = document['title'] is String
            ? document['title'] as String
            : null;
        _text = text;
        _version = version;
        _documentLanguage = GlobalLocaleController.names[document['locale']];
      });
    } catch (_) {
      // A missing or stale document must not become local fallback terms.
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final title = widget.document == GlobalLegalDocumentType.userAgreement
        ? l.termsOfService
        : l.privacyPolicy;
    return Scaffold(
      key: const Key('global-legal-page'),
      appBar: AppBar(
        title: Text(_title?.trim().isNotEmpty == true ? _title! : title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _text == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.serviceUnavailable, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('global-legal-retry'),
                      onPressed: _load,
                      child: Text(l.retry),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_version · $_documentLanguage',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    _text!,
                    key: const Key('global-legal-body'),
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ),
            ),
    );
  }
}
