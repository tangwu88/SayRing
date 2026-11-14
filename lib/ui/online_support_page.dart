import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../l10n/global_locale_controller.dart';
import '../services/api_client.dart';
import '../services/app_controller.dart';
import 'support_faq_page.dart';

String supportCopy(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

final _supportId = RegExp(
  r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
);
bool isSupportId(Object? value) =>
    value is String && _supportId.hasMatch(value);

List<Map<String, Object?>> supportRows(Object? value) => value is List
    ? value.whereType<Map<String, Object?>>().toList(growable: false)
    : const [];

class OnlineSupportPage extends StatefulWidget {
  const OnlineSupportPage({
    required this.controller,
    this.initialConversation,
    this.legacyContacts,
    this.apiOverride,
    super.key,
  });
  final AppController controller;
  final String? initialConversation;
  final WidgetBuilder? legacyContacts;
  final OnlineSupportApi? apiOverride;
  @override
  State<OnlineSupportPage> createState() => _OnlineSupportPageState();
}

class _Draft {
  const _Draft(this.id, this.text, this.photo, this.aiAllowed);
  final String id, text;
  final Uint8List? photo;
  final bool aiAllowed;
}

class _OnlineSupportPageState extends State<OnlineSupportPage>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <int, Map<String, Object?>>{};
  Session? _member;
  SupportGuestSession? _guest;
  late String _owner;
  String? _notificationConversation;
  int _ownerGeneration = 0, _revision = 0, _cursor = 0, _readAt = 0;
  String? _conversation, _status, _error;
  bool _loading = true,
      _enabled = false,
      _older = false,
      _olderLoading = false,
      _busy = false,
      _foreground = true,
      _streamRunning = false;
  bool _guestCreationRequired = false;
  Uri? _whatsapp;
  Uint8List? _photo;
  _Draft? _pending;
  Completer<void> _stop = Completer<void>();
  Completer<void>? _streamStop;
  Timer? _readTimer;
  final Set<String> _attachedDiagnostics = {};
  OnlineSupportApi? get _api =>
      widget.apiOverride ?? widget.controller.onlineSupportApi;
  String tr(String zh, String en) => supportCopy(context, zh, en);
  String get _language =>
      Localizations.localeOf(context).languageCode == 'zh' ? 'zh-Hans' : 'en';
  bool valid(int revision) =>
      mounted &&
      revision == _revision &&
      _owner == widget.controller.supportOwner &&
      _ownerGeneration == widget.controller.supportOwnerGeneration;

  @override
  void initState() {
    super.initState();
    _ownerGeneration = widget.controller.supportOwnerGeneration;
    _owner = widget.controller.supportOwner;
    _notificationConversation = widget.initialConversation;
    _member = widget.controller.session;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onOwner);
    scheduleMicrotask(_open);
  }

  void _onOwner() {
    if (_ownerGeneration == widget.controller.supportOwnerGeneration &&
        _owner == widget.controller.supportOwner) {
      return;
    }
    _ownerGeneration = widget.controller.supportOwnerGeneration;
    _owner = widget.controller.supportOwner;
    _notificationConversation = null;
    _member = widget.controller.session;
    _invalidate();
    setState(() {
      _cursor = 0;
      _readAt = 0;
      _conversation = null;
      _status = null;
      _guest = null;
      _messages.clear();
      _pending = null;
      _photo = null;
      _text.clear();
      _busy = false;
      _olderLoading = false;
      _attachedDiagnostics.clear();
    });
    unawaited(_open());
  }

  void _invalidate() {
    ++_revision;
    if (!_stop.isCompleted) _stop.complete();
    _stop = Completer<void>();
    _pauseStream();
    _readTimer?.cancel();
  }

  void _pauseStream() {
    final stop = _streamStop;
    if (stop != null && !stop.isCompleted) stop.complete();
    _streamStop = null;
    _streamRunning = false;
  }

  @override
  void dispose() {
    _invalidate();
    widget.controller.removeListener(_onOwner);
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _pauseStream();
      _readTimer?.cancel();
    } else {
      _connect();
      _queueRead();
    }
  }

  Future<Map<String, Object?>> _call(
    String route, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    Uint8List? photo,
  }) async => _api!.supportRequest(
    route,
    member: _member,
    guestToken: _guest?.token,
    body: body,
    query: query,
    photo: photo,
    stop: _stop.future,
  );

  Future<void> _open({bool newThread = false}) async {
    if (!mounted) return;
    _invalidate();
    final version = _revision;
    var loadingKnownThread = false;
    setState(() {
      _loading = true;
      _error = null;
      _guestCreationRequired = false;
    });
    try {
      final api = _api;
      if (api == null) return;
      final config = await api.supportRequest(
        'online-config',
        stop: _stop.future,
      );
      if (!valid(version)) return;
      final raw = config['whatsapp'];
      final url =
          _language == 'en' &&
              raw is String &&
              RegExp(r'^https://wa\.me/[1-9][0-9]{6,14}$').hasMatch(raw)
          ? Uri.parse(raw)
          : null;
      setState(() {
        _enabled = config['product'] == 'say-ring' && config['enabled'] == true;
        _whatsapp = url;
      });
      if (!_enabled) return;
      final vault = widget.controller.onlineSupportVault;
      final stored = vault == null ? null : await vault.readSupportGuest();
      if (!valid(version)) return;
      final guest = stored == null
          ? null
          : SupportGuestSession.tryParse(stored);
      _guest = guest?.expired == false ? guest : null;
      if (_member == null && _guest == null) {
        setState(() => _guestCreationRequired = true);
        return;
      }
      // An explicit user selection always wins over the latest open thread.
      final initial = _notificationConversation;
      if (!newThread &&
          _member != null &&
          isSupportId(initial) &&
          _conversation == null) {
        loadingKnownThread = true;
        await _load(initial!, version);
      } else if (!newThread && _conversation != null) {
        loadingKnownThread = true;
        await _load(_conversation!, version);
      } else if (!newThread &&
          _member == null &&
          _guest != null &&
          !_guest!.claimed) {
        loadingKnownThread = true;
        await _load(_guest!.conversation, version);
      } else {
        final result = await _call('conversations', body: const {});
        if (!valid(version)) return;
        final id = result['id'];
        if (!isSupportId(id)) throw const FormatException();
        await _load(id as String, version, saveGuest: true);
      }
    } on ApiException catch (e) {
      if (valid(version) &&
          _member == null &&
          _guest != null &&
          (e.statusCode == 401 ||
              (e.statusCode == 404 && loadingKnownThread))) {
        if (e.statusCode == 401) {
          final existing = _guest;
          final vault = widget.controller.onlineSupportVault;
          final entry = await vault?.readSupportGuest();
          if (valid(version) && entry?['token'] == existing?.token) {
            await vault?.writeSupportGuest(null);
          }
          if (valid(version)) {
            setState(() {
              _guest = null;
              _conversation = null;
              _guestCreationRequired = true;
            });
          }
        } else if (valid(version)) {
          // A signed-in screen may have linked the former guest thread.
          setState(() {
            _conversation = null;
            _messages.clear();
            _error = 'unavailable';
          });
          unawaited(_open(newThread: true));
        }
      } else if (valid(version) && loadingKnownThread && e.statusCode == 404) {
        _notificationConversation = null;
        _conversation = null;
        _messages.clear();
        unawaited(_open(newThread: true));
      } else if (valid(version)) {
        setState(
          () => _error = e.statusCode == 401 ? 'session' : 'unavailable',
        );
      }
    } catch (_) {
      if (valid(version)) setState(() => _error = 'unavailable');
    } finally {
      if (valid(version)) setState(() => _loading = false);
    }
  }

  Future<void> _createGuest() async {
    if (_loading || !_guestCreationRequired || _member != null) return;
    final version = _revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api!.supportRequest(
        'guest',
        body: const {},
        stop: _stop.future,
      );
      if (!valid(version)) return;
      final guest = SupportGuestSession.tryParse(result);
      if (guest == null) throw const FormatException();
      final vault = widget.controller.onlineSupportVault;
      await vault?.writeSupportGuest(guest.toJson());
      if (!valid(version)) return;
      _guest = guest;
      setState(() => _guestCreationRequired = false);
      await _load(guest.conversation, version);
    } catch (_) {
      if (valid(version)) setState(() => _error = 'unavailable');
    } finally {
      if (valid(version)) setState(() => _loading = false);
    }
  }

  Future<void> _load(String id, int version, {bool saveGuest = false}) async {
    final data = await _call('conversations/$id');
    if (!valid(version)) return;
    final header = data['conversation'];
    if (header is! Map || header['id'] != id) throw const FormatException();
    if (_member == null &&
        saveGuest &&
        _guest != null &&
        _guest!.conversation != id) {
      final saved = SupportGuestSession(
        token: _guest!.token,
        conversation: id,
        expiresAt: _guest!.expiresAt,
      );
      await widget.controller.onlineSupportVault?.writeSupportGuest(
        saved.toJson(),
      );
      if (!valid(version)) return;
      _guest = saved;
    }
    final changed = id != _conversation;
    setState(() {
      _conversation = id;
      if (changed) {
        _messages.clear();
        _cursor = 0;
        _readAt = 0;
        _pending = null;
        _photo = null;
        _text.clear();
      }
      _older = data['older'] == true;
      _error = null;
      _merge(data);
    });
    _bottom();
    _connect();
    _queueRead();
  }

  void _merge(Map<String, Object?> event) {
    final row = event['conversation'];
    if (row is! Map || row['id'] != _conversation) return;
    _status = row['state'] as String?;
    final old = _cursor;
    for (final message in supportRows(event['messages'])) {
      final seq = message['seq'];
      if (seq is! int || seq <= 0 || !isSupportId(message['id'])) continue;
      _messages[seq] = message;
      if (seq > _cursor) _cursor = seq;
      if (_pending != null && message['clientMessageId'] == _pending!.id) {
        _pending = null;
        _photo = null;
        _text.clear();
        _error = null;
      }
    }
    if (_cursor > old) {
      _queueRead();
      _bottom(follow: true);
    }
  }

  void _connect() {
    final id = _conversation;
    if (id == null ||
        _api == null ||
        !_foreground ||
        _streamRunning ||
        !mounted) {
      return;
    }
    final version = _revision;
    final stop = Completer<void>();
    _streamStop = stop;
    _streamRunning = true;
    unawaited(() async {
      var delay = 350;
      while (valid(version) &&
          _foreground &&
          !stop.isCompleted &&
          _conversation == id) {
        try {
          await for (final event in _api!.supportEvents(
            id,
            _cursor,
            member: _member,
            guestToken: _guest?.token,
            stop: stop.future,
          )) {
            if (!valid(version) || stop.isCompleted || _conversation != id) {
              break;
            }
            setState(() => _merge(event));
            delay = 350;
          }
        } on ApiException catch (e) {
          if (e.statusCode == 401 ||
              e.statusCode == 403 ||
              e.statusCode == 404) {
            if (valid(version) && !stop.isCompleted) {
              setState(
                () => _error = e.statusCode == 401 ? 'session' : 'unavailable',
              );
            }
            break;
          }
          delay = (delay * 2).clamp(350, 5000);
        } catch (_) {
          delay = (delay * 2).clamp(350, 5000);
        }
        if (!stop.isCompleted) {
          await Future.any([
            Future<void>.delayed(Duration(milliseconds: delay)),
            stop.future,
          ]);
        }
      }
      if (identical(_streamStop, stop)) {
        _streamStop = null;
        _streamRunning = false;
      }
    }());
  }

  void _queueRead() {
    _readTimer?.cancel();
    final id = _conversation, version = _revision;
    if (!_foreground || id == null || _cursor <= _readAt) return;
    _readTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!valid(version) || !_foreground || id != _conversation) return;
      final seq = _cursor;
      try {
        await _call('conversations/$id/read', body: {'seq': seq});
        if (valid(version)) _readAt = seq;
      } catch (_) {
        /* Retry on resume or newer messages. */
      }
    });
  }

  void _bottom({bool follow = false}) {
    final nearEnd = !_scroll.hasClients || _scroll.position.extentAfter < 105;
    if (follow && !nearEnd) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _previous() async {
    final id = _conversation, version = _revision;
    if (id == null || _messages.isEmpty || _olderLoading) return;
    setState(() => _olderLoading = true);
    try {
      final seqs = _messages.keys.toList()..sort();
      final data = await _call(
        'conversations/$id',
        query: {'before': '${seqs.first}'},
      );
      if (!valid(version)) return;
      final offset = _scroll.hasClients ? _scroll.offset : 0.0;
      final size = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
      setState(() {
        for (final m in supportRows(data['messages'])) {
          final seq = m['seq'];
          if (seq is int) _messages[seq] = m;
        }
        _older = data['older'] == true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (valid(version) && _scroll.hasClients) {
          _scroll.jumpTo(
            (offset + _scroll.position.maxScrollExtent - size).clamp(
              0,
              _scroll.position.maxScrollExtent,
            ),
          );
        }
      });
    } catch (_) {
      if (valid(version)) setState(() => _error = 'unavailable');
    } finally {
      if (valid(version)) setState(() => _olderLoading = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_pending != null || _busy) return;
    final version = _revision;
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (selected == null || !valid(version)) return;
      if (await selected.length() > 5 * 1024 * 1024) {
        if (valid(version)) setState(() => _error = 'photo');
        return;
      }
      final bytes = await selected.readAsBytes();
      if (valid(version)) {
        setState(() {
          _photo = bytes;
          _error = null;
        });
      }
    } catch (_) {
      if (valid(version)) setState(() => _error = 'photo');
    }
  }

  Future<void> _send() async {
    final id = _conversation, version = _revision;
    if (id == null || _busy || _status == 'closed') return;
    if (_pending == null && _text.text.trim().isEmpty && _photo == null) return;
    final draft =
        _pending ??
        _Draft(const Uuid().v4(), _text.text.trim(), _photo, _status == 'ai');
    setState(() {
      _pending = draft;
      _busy = true;
      _error = null;
    });
    try {
      final result = await _call(
        'conversations/$id/${draft.photo == null ? 'messages' : 'attachments'}',
        body: {
          'clientMessageId': draft.id,
          'body': draft.text,
          if (draft.photo == null) 'aiAllowed': draft.aiAllowed,
        },
        photo: draft.photo,
      );
      if (!valid(version)) return;
      if (result['clientMessageId'] != draft.id || result['seq'] is! int) {
        throw const FormatException();
      }
      setState(() {
        _messages[result['seq'] as int] = result;
        _pending = null;
        _text.clear();
        _photo = null;
      });
      _bottom();
    } catch (e) {
      if (valid(version) && _pending?.id == draft.id) {
        setState(
          () => _error = e is ApiException && e.statusCode == 422
              ? 'photo'
              : 'send',
        );
      }
    } finally {
      if (valid(version)) setState(() => _busy = false);
    }
  }

  Future<void> _handoff() async {
    final id = _conversation, version = _revision;
    if (id == null || _status != 'ai' || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _call('conversations/$id/handoff', body: const {});
      if (valid(version) && result['id'] == id) {
        setState(() => _status = result['state'] as String?);
      }
    } catch (_) {
      if (valid(version)) setState(() => _error = 'handoff');
    } finally {
      if (valid(version)) setState(() => _busy = false);
    }
  }

  Future<void> _shareDiagnostic() async {
    final id = _conversation, version = _revision;
    if (id == null || _member != null || _guest == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = await widget.controller.supportGuestDiagnostic(_language);
      if (!valid(version)) return;
      if (report == null) {
        setState(() => _error = 'diagnostic');
        return;
      }
      final result = await _call('conversations/$id/diagnostic', body: report);
      if (valid(version) && result['accepted'] == true) {
        setState(() => _attachedDiagnostics.add(id));
      }
    } catch (_) {
      if (valid(version)) setState(() => _error = 'diagnostic');
    } finally {
      if (valid(version)) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    final guest = _guest, version = _revision;
    var activeRevision = version;
    if (guest == null || guest.claimed || _member == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(tr('关联访客会话', 'Link guest conversation')),
        content: Text(
          tr(
            '将这一次访客会话保存到当前登录的账号？',
            'Save this guest conversation to the account you are signed in to?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(tr('关联', 'Link')),
          ),
        ],
      ),
    );
    if (confirmed != true || !valid(version)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _call(
        'conversations/${guest.conversation}/claim',
        body: {'guestToken': guest.token},
      );
      if (!valid(version) || result['id'] != guest.conversation) return;
      final vault = widget.controller.onlineSupportVault;
      final stored = await vault?.readSupportGuest();
      // Keep the visitor credential for any other guest threads on this phone.
      final parsed = stored == null
          ? null
          : SupportGuestSession.tryParse(stored);
      if (valid(version) && parsed?.token == guest.token) {
        await vault?.writeSupportGuest({...guest.toJson(), 'claimed': true});
      }
      if (!valid(version)) return;
      setState(() => _guest = null);
      _invalidate();
      activeRevision = _revision;
      await _load(guest.conversation, activeRevision);
    } catch (_) {
      if (valid(activeRevision)) {
        setState(() => _error = 'unavailable');
      }
    } finally {
      if (valid(activeRevision)) setState(() => _busy = false);
    }
  }

  Future<void> _history() async {
    final version = _revision;
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SupportHistoryPage(
          loader: (before) => _call(
            'conversations',
            query: before == null ? null : {'before': before},
          ),
          listenable: widget.controller,
          permitted: () => valid(version),
        ),
      ),
    );
    if (!valid(version) || selected == null || selected == _conversation) {
      return;
    }
    _invalidate();
    final next = _revision;
    setState(() => _loading = true);
    try {
      await _load(selected, next);
    } catch (_) {
      if (valid(next)) setState(() => _error = 'unavailable');
    } finally {
      if (valid(next)) setState(() => _loading = false);
    }
  }

  Future<void> _openWhatsApp() async {
    final url = _whatsapp;
    if (url == null) return;
    try {
      if (await launchUrl(
        url,
        mode: LaunchMode.externalNonBrowserApplication,
      )) {
        return;
      }
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Offer copying below. */
    }
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: url.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('已复制 WhatsApp 链接', 'WhatsApp link copied'))),
      );
    }
  }

  void _faq() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SupportFaqPage(
        controller: widget.controller,
        apiOverride: widget.apiOverride,
        showContact: false,
      ),
    ),
  );

  void _readArticle(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SupportArticlePage(api: _api!, articleId: id),
    ),
  );

  void _viewPhoto(String attachment) {
    final id = _conversation, version = _revision;
    if (id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SupportPhotoPage(
          permitted: () => valid(version),
          listenable: widget.controller,
          load: () => _api!.supportPhoto(
            id,
            attachment,
            member: _member,
            guestToken: _guest?.token,
            stop: _stop.future,
          ),
        ),
      ),
    );
  }

  String _stateLabel(String? state) => switch (state) {
    'ai' => tr('AI 客服', 'AI assistant'),
    'waiting' => tr('等待人工回复 · 可以先留言', 'Waiting for a person · Leave a message'),
    'human' => tr('人工客服已接入', 'A support agent has joined'),
    'closed' => tr('会话已结束', 'Conversation ended'),
    _ => tr('在线客服', 'Online support'),
  };

  String? _errorLabel() => switch (_error) {
    'session' => tr(
      '会话已失效，请重新打开。',
      'Your session expired. Reopen support to try again.',
    ),
    'photo' => tr(
      '照片无法发送，请换一张。',
      'This photo could not be sent. Choose another one.',
    ),
    'send' => tr('消息未确认，可以重试。', 'Message not confirmed. You can retry.'),
    'handoff' => tr('暂时无法转人工，请重试。', 'Could not request an agent. Try again.'),
    'diagnostic' => tr(
      '暂无可提供的连接信息。',
      'No connection details are available to share.',
    ),
    'unavailable' => tr(
      '暂时无法打开在线客服。',
      'Online support is temporarily unavailable.',
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final id = _conversation;
    final rows = _messages.values.toList()
      ..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
    final error = _errorLabel();
    return Scaffold(
      key: const Key('online-customer-service'),
      appBar: AppBar(
        title: Text(context.l10n.customerService),
        actions: [
          if (_enabled && (_member != null || _guest != null))
            IconButton(
              tooltip: tr('会话记录', 'Conversation history'),
              icon: const Icon(Icons.history_rounded),
              onPressed: _history,
            ),
          PopupMenuButton<String>(
            tooltip: tr('更多帮助', 'More help'),
            onSelected: (value) {
              if (value == 'faq') _faq();
              if (value == 'contacts' && widget.legacyContacts != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: widget.legacyContacts!),
                );
              }
              if (value == 'diagnostic') unawaited(_shareDiagnostic());
              if (value == 'whatsapp') unawaited(_openWhatsApp());
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'faq',
                child: Text(tr('常见问题', 'Frequently asked questions')),
              ),
              if (widget.legacyContacts != null)
                PopupMenuItem(
                  value: 'contacts',
                  child: Text(tr('其他联系方式', 'Other ways to contact us')),
                ),
              if (_whatsapp != null)
                const PopupMenuItem(
                  value: 'whatsapp',
                  child: Text('Contact us on WhatsApp'),
                ),
              if (_member == null &&
                  id != null &&
                  _status != 'closed' &&
                  !_attachedDiagnostics.contains(id))
                PopupMenuItem(
                  value: 'diagnostic',
                  child: Text(
                    tr('提供手机与连接信息', 'Share phone and connection details'),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : id == null || !_enabled
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Icon(
                  Icons.headset_mic_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  error ??
                      (_guestCreationRequired
                          ? tr('以访客身份咨询', 'Ask as a guest')
                          : tr(
                              '在线客服暂未开放',
                              'Online support is currently unavailable',
                            )),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (_guestCreationRequired) ...[
                  const SizedBox(height: 10),
                  Text(
                    tr(
                      '无需登录。AI 先解答产品问题，也可以转人工。',
                      'No sign-in needed. The AI assistant answers product questions, and you can ask for a person.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _createGuest,
                    child: Text(tr('开始咨询', 'Start a conversation')),
                  ),
                ] else if (error != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _open,
                    child: Text(tr('重试', 'Retry')),
                  ),
                ],
                TextButton(
                  onPressed: _faq,
                  child: Text(tr('常见问题', 'Frequently asked questions')),
                ),
                if (widget.legacyContacts != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: widget.legacyContacts!),
                    ),
                    child: Text(tr('其他联系方式', 'Other ways to contact us')),
                  ),
                if (_whatsapp != null)
                  TextButton.icon(
                    onPressed: _openWhatsApp,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Contact us on WhatsApp'),
                  ),
              ],
            )
          : Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _stateLabel(_status),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (_status == 'ai')
                          OutlinedButton.icon(
                            key: const Key('support-handoff'),
                            onPressed: _busy ? null : _handoff,
                            icon: const Icon(Icons.support_agent_outlined),
                            label: Text(tr('转人工', 'Talk to a person')),
                          ),
                        if (_member != null && _guest?.claimed == false)
                          TextButton(
                            onPressed: _busy ? null : _claim,
                            child: Text(
                              tr('关联访客会话', 'Link guest conversation'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    children: [
                      if (_older)
                        TextButton(
                          onPressed: _olderLoading ? null : _previous,
                          child: Text(tr('更早的消息', 'Earlier messages')),
                        ),
                      if (rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            tr(
                              '你好，可以问我设备连接、使用或售后问题。',
                              'Hi! Ask about connecting or using your device, or getting support.',
                            ),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      for (final row in rows) _message(row),
                      if (_pending != null &&
                          !rows.any(
                            (row) => row['clientMessageId'] == _pending!.id,
                          ))
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              _busy
                                  ? tr('正在发送…', 'Sending…')
                                  : tr(
                                      '未发送 · {p0}',
                                      'Not sent · {p0}',
                                    ).replaceFirst(
                                      '{p0}',
                                      _pending!.text.isEmpty
                                          ? tr('照片', 'Photo')
                                          : _pending!.text,
                                    ),
                            ),
                          ),
                        ),
                      if (_attachedDiagnostics.contains(id))
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            tr(
                              '已提供手机与连接信息',
                              'Phone and connection details shared',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        if (_error == 'session' || _error == 'unavailable')
                          TextButton(
                            onPressed: _open,
                            child: Text(tr('重试', 'Retry')),
                          ),
                      ],
                    ),
                  ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                  child: _status == 'closed'
                      ? FilledButton.tonal(
                          onPressed: () => _open(newThread: true),
                          child: Text(tr('开始新会话', 'New conversation')),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_status == 'ai')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  tr(
                                    '发送文字将由 AI 处理，请勿填写密码或验证码。',
                                    'The AI reads your text. Leave out passwords and codes.',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            if (_photo != null)
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(tr('已添加照片', 'Photo attached')),
                                  ),
                                  IconButton(
                                    onPressed: _pending == null
                                        ? () => setState(() => _photo = null)
                                        : null,
                                    tooltip: tr('移除照片', 'Remove photo'),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            if (_pending != null && !_busy)
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _pending = null),
                                    child: Text(tr('继续编辑', 'Edit')),
                                  ),
                                  FilledButton(
                                    onPressed: _send,
                                    child: Text(tr('重试发送', 'Retry send')),
                                  ),
                                ],
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: tr('添加照片', 'Add photo'),
                                    onPressed: _busy ? null : _pickPhoto,
                                    icon: const Icon(Icons.photo_outlined),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      key: const Key('support-draft'),
                                      controller: _text,
                                      enabled: !_busy,
                                      minLines: 1,
                                      maxLines: 3,
                                      maxLength: 2000,
                                      decoration: InputDecoration(
                                        hintText: tr('输入消息', 'Message'),
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                  IconButton.filled(
                                    key: const Key('support-send'),
                                    tooltip: tr('发送', 'Send'),
                                    onPressed: _busy ? null : _send,
                                    icon: const Icon(Icons.send_rounded),
                                  ),
                                ],
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _message(Map<String, Object?> row) {
    final mine = row['sender'] == 'customer';
    final data = row['attachment'];
    final attachment = data is Map ? data['id'] : null;
    final text = row['body'] is String ? row['body'] as String : '';
    final created = DateTime.tryParse('${row['createdAt']}')?.toLocal();
    final time = created == null
        ? ''
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(created),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: .89,
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (!mine)
                    (row['sender'] == 'ai'
                        ? tr('AI 客服', 'AI assistant')
                        : tr('人工客服', 'Support agent')),
                  if (time.isNotEmpty) time,
                ].join(' · '),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: mine
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty)
                      SelectableText(
                        text,
                        style: TextStyle(
                          color: mine
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                    if (isSupportId(attachment))
                      TextButton.icon(
                        onPressed: () => _viewPhoto(attachment as String),
                        icon: const Icon(Icons.photo_outlined),
                        label: Text(tr('查看照片', 'View photo')),
                      ),
                    for (final source in supportRows(row['sources']))
                      if (isSupportId(source['id']))
                        TextButton(
                          onPressed: () => _readArticle(source['id'] as String),
                          child: Text('${source['title']}'),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupportHistoryPage extends StatefulWidget {
  const SupportHistoryPage({
    required this.loader,
    required this.listenable,
    required this.permitted,
    super.key,
  });
  final Future<Map<String, Object?>> Function(String?) loader;
  final Listenable listenable;
  final bool Function() permitted;
  @override
  State<SupportHistoryPage> createState() => _SupportHistoryPageState();
}

class _SupportHistoryPageState extends State<SupportHistoryPage> {
  final _rows = <Map<String, Object?>>[];
  String? _next;
  bool _loading = true, _error = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool more = false}) async {
    if (!widget.permitted()) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final result = await widget.loader(more ? _next : null);
      if (!mounted || !widget.permitted()) return;
      setState(() {
        if (!more) _rows.clear();
        _rows.addAll(supportRows(result['items']));
        _next = result['next'] as String?;
      });
    } catch (_) {
      if (mounted && widget.permitted()) setState(() => _error = true);
    } finally {
      if (mounted && widget.permitted()) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(supportCopy(context, '会话记录', 'Conversation history')),
    ),
    body: ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, _) {
        if (!widget.permitted()) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_rows.isEmpty && _loading)
              const Center(child: CircularProgressIndicator()),
            if (_rows.isEmpty && !_loading && !_error)
              Text(
                supportCopy(context, '暂无会话', 'No conversations yet'),
                textAlign: TextAlign.center,
              ),
            for (final row in _rows)
              if (isSupportId(row['id']))
                ListTile(
                  title: Text(switch (DateTime.tryParse(
                    '${row['updatedAt']}',
                  )) {
                    final DateTime time => MaterialLocalizations.of(
                      context,
                    ).formatFullDate(time.toLocal()),
                    null => supportCopy(
                      context,
                      '客服会话',
                      'Support conversation',
                    ),
                  }),
                  subtitle: Text(
                    row['state'] == 'closed'
                        ? supportCopy(context, '会话已结束', 'Conversation ended')
                        : supportCopy(context, '客服会话', 'Support conversation'),
                  ),
                  trailing: row['unread'] == true
                      ? const Icon(Icons.fiber_manual_record, size: 10)
                      : const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, row['id'] as String),
                ),
            if (_error || _next != null)
              TextButton(
                onPressed: _loading ? null : () => _load(more: _next != null),
                child: Text(
                  supportCopy(
                    context,
                    _error ? '重试' : '查看更多',
                    _error ? 'Retry' : 'Load more',
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _SupportPhotoPage extends StatefulWidget {
  const _SupportPhotoPage({
    required this.load,
    required this.permitted,
    required this.listenable,
  });
  final Future<Uint8List> Function() load;
  final bool Function() permitted;
  final Listenable listenable;
  @override
  State<_SupportPhotoPage> createState() => _SupportPhotoPageState();
}

class _SupportPhotoPageState extends State<_SupportPhotoPage> {
  late Future<Uint8List> _image = widget.load();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(supportCopy(context, '会话照片', 'Conversation photo')),
    ),
    body: ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, _) {
        if (!widget.permitted()) return const SizedBox.shrink();
        return FutureBuilder(
          future: _image,
          builder: (context, snapshot) {
            if (!widget.permitted()) return const SizedBox.shrink();
            if (snapshot.hasData) {
              return Center(
                child: InteractiveViewer(
                  child: Image.memory(
                    snapshot.data!,
                    semanticLabel: supportCopy(
                      context,
                      '会话照片',
                      'Conversation photo',
                    ),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(() => _image = widget.load()),
                  child: Text(
                    supportCopy(context, '重试读取照片', 'Retry loading photo'),
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      },
    ),
  );
}
