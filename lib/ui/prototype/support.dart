part of '../prototype_pages.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({this.controller, super.key});

  final AppController? controller;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _content = TextEditingController();
  final _contact = TextEditingController();
  String _category = '功能建议';
  String? _result;
  bool _submitting = false;

  @override
  void dispose() {
    _content.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_content.text.trim().length < 5) {
      setState(() => _result = '请至少填写 5 个字的问题说明');
      return;
    }
    final controller = widget.controller;
    if (controller == null) {
      setState(() => _result = '此功能暂时无法使用，请稍后再试');
      return;
    }
    setState(() {
      _submitting = true;
      _result = null;
    });
    final success = await controller.submitFeedback(
      category: _category,
      content: _content.text,
      contact: _contact.text,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = success
          ? '反馈已提交，感谢你的建议'
          : controller.errorMessage ?? '反馈提交失败，请稍后重试';
      if (success) _content.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.helpFeedback)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '问题反馈',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(labelText: context.l10n.issueType),
            items: [
              const DropdownMenuItem(value: '功能建议', child: Text('功能建议')),
              const DropdownMenuItem(value: '设备连接', child: Text('设备连接')),
              const DropdownMenuItem(value: '数据问题', child: Text('数据问题')),
              if (widget.controller?.commerceEnabled ?? false)
                const DropdownMenuItem(value: '商城订单', child: Text('商城订单')),
            ],
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('feedback-content'),
            controller: _content,
            minLines: 5,
            maxLines: 8,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: context.l10n.issueDescription,
              hintText: context.l10n.describeIssue,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contact,
            decoration: InputDecoration(
              labelText: context.l10n.contactOptional,
              hintText: context.l10n.phoneOrEmail,
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            FeatureStateCard(message: _result!, icon: Icons.info_outline),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '正在提交…' : '提交反馈'),
          ),
          const SizedBox(height: 28),
          Text(
            '常见问题',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Card(
            child: Column(
              children: [
                ExpansionTile(
                  title: Text('如何连接戒指？'),
                  childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text('打开“设备”页并选择添加设备。搜索前请将戒指充电激活并靠近手机，等待 App 完成连接。'),
                  ],
                ),
                Divider(height: 1),
                ExpansionTile(
                  title: Text('为什么健康数据暂时为空？'),
                  childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text('请确认设备已连接并完成同步。设备不支持的项目不会开放入口；新测量数据同步后才会显示趋势。'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerServicePage extends StatelessWidget {
  const CustomerServicePage({
    this.isGlobalEdition = false,
    this.controller,
    super.key,
  });

  final bool isGlobalEdition;
  final AppController? controller;

  static const _phone = '4006386738';
  static const _officialAccount = '赛电';

  Future<void> _call(BuildContext context, String phone) async {
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开拨号界面，请手动拨打 $phone')));
    }
  }

  Future<void> _copyAccount(BuildContext context, String account) async {
    await Clipboard.setData(ClipboardData(text: account));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('公众号“$account”已复制，可前往微信搜索添加')));
  }

  Future<void> _copyServiceLink(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: SayRingSupport.customerServiceUri.toString()),
    );
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('客服链接已复制，可在微信或浏览器中打开')),
    );
  }

  Future<void> _openWechatService(BuildContext context) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    for (final mode in [
      LaunchMode.externalApplication,
      LaunchMode.inAppBrowserView,
    ]) {
      if (!context.mounted) return;
      try {
        if (await launchUrl(SayRingSupport.customerServiceUri, mode: mode)) {
          return;
        }
      } catch (_) {
        // External launch may be unavailable; try the system browser surface.
        // If it is unavailable too, retain the exact-link copy path below.
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('无法打开微信客服，请复制链接后在微信或浏览器中打开'),
        action: SnackBarAction(
          label: '复制链接',
          onPressed: () => _copyServiceLink(context),
        ),
      ),
    );
  }

  Widget _wechatServiceCard(BuildContext context) => Card(
    key: const Key('say-ring-wechat-service-card'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '微信客服',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('设备连接、使用和售后问题，可通过企业微信客服联系我们。'),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('say-ring-open-wechat-service'),
            onPressed: () => _openWechatService(context),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('联系微信客服'),
          ),
          TextButton.icon(
            key: const Key('say-ring-copy-wechat-service'),
            onPressed: () => _copyServiceLink(context),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制客服链接'),
          ),
        ],
      ),
    ),
  );

  Widget _configuredContact({
    required String title,
    required String value,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onPressed,
  }) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(value),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: onPressed, child: Text(actionLabel)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (isGlobalEdition) {
      return Scaffold(
        key: const Key('global-customer-service'),
        appBar: AppBar(title: Text(context.l10n.customerService)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _wechatServiceCard(context),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, Object?>>(
              future: controller?.loadGlobalSupportConfig(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final config = snapshot.data ?? const <String, Object?>{};
                final configured = config['configured'] == true;
                final phone = configured
                    ? '${config['phone'] ?? ''}'.trim()
                    : '';
                final account = configured
                    ? '${config['officialAccount'] ?? config['wechatOfficialAccount'] ?? ''}'
                          .trim()
                    : '';
                final hours = configured
                    ? '${config['serviceHours'] ?? ''}'.trim()
                    : '';
                final message = configured
                    ? '${config['message'] ?? ''}'.trim()
                    : '';
                final validPhone = RegExp(
                  r'^\+?[0-9][0-9 -]{4,20}$',
                ).hasMatch(phone);
                final chinese =
                    Localizations.localeOf(context).languageCode == 'zh';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot.hasError ||
                        !configured ||
                        (!validPhone && account.isEmpty))
                      FeatureStateCard(
                        message: !chinese
                            ? snapshot.hasError
                                  ? 'Other contact details could not be loaded. WeChat service above remains available.'
                                  : 'Other contact details are not configured. WeChat service above remains available.'
                            : snapshot.hasError
                            ? '电话及公众号信息加载失败，仍可使用上方微信客服'
                            : !configured
                            ? '电话及公众号暂未配置，仍可使用上方微信客服'
                            : '电话及公众号信息不完整，仍可使用上方微信客服',
                        detail: context.l10n.supportPrivacyWarning,
                        icon: Icons.support_agent,
                      )
                    else ...[
                      Card(
                        child: Column(
                          children: [
                            if (validPhone)
                              _configuredContact(
                                icon: Icons.phone_outlined,
                                title: context.l10n.contactPhoneLabel,
                                value: phone,
                                onPressed: () => _call(context, phone),
                                actionLabel: context.l10n.call,
                              ),
                            if (validPhone && account.isNotEmpty)
                              const Divider(
                                indent: 16,
                                endIndent: 16,
                                height: 1,
                              ),
                            if (account.isNotEmpty)
                              _configuredContact(
                                icon: Icons.wechat_rounded,
                                title: context.l10n.wechatOfficialAccount,
                                value: account,
                                onPressed: () async {
                                  await _copyAccount(context, account);
                                },
                                actionLabel: context.l10n.addSupportContact,
                              ),
                          ],
                        ),
                      ),
                      if (hours.isNotEmpty || message.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        FeatureStateCard(
                          message: hours.isEmpty ? message : hours,
                          detail: hours.isEmpty ? null : message,
                          icon: Icons.schedule_outlined,
                        ),
                      ],
                      const SizedBox(height: 16),
                      FeatureStateCard(
                        message: context.l10n.contactPreparationHint,
                        detail: context.l10n.supportPrivacyWarning,
                        icon: Icons.privacy_tip_outlined,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.customerService)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.phone_outlined),
                  ),
                  title: Text(context.l10n.contactPhoneLabel),
                  subtitle: const Text(_phone),
                  trailing: FilledButton.tonal(
                    onPressed: () => _call(context, _phone),
                    child: Text(context.l10n.call),
                  ),
                ),
                const Divider(indent: 72, height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.wechat_rounded),
                  ),
                  title: Text(context.l10n.wechatOfficialAccount),
                  subtitle: const Text(_officialAccount),
                  trailing: FilledButton.tonal(
                    onPressed: () => _copyAccount(context, _officialAccount),
                    child: Text(context.l10n.addSupportContact),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FeatureStateCard(
            message: context.l10n.contactPreparationHint,
            detail: context.l10n.supportPrivacyWarning,
            icon: Icons.privacy_tip_outlined,
          ),
        ],
      ),
    );
  }
}

class AboutSaydianPage extends StatefulWidget {
  const AboutSaydianPage({
    required this.controller,
    this.updateGateController,
    this.packageInfoLoader,
    super.key,
  });

  final AppController controller;
  final AppUpdateGateController? updateGateController;
  final Future<PackageInfo> Function()? packageInfoLoader;

  @override
  State<AboutSaydianPage> createState() => _AboutSaydianPageState();
}

class _AboutSaydianPageState extends State<AboutSaydianPage> {
  String _version = '--';
  String _build = '--';
  String _introduction = '记录日常健康趋势，连接家人与设备，让健康管理更简单。';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final package =
          await (widget.packageInfoLoader ?? PackageInfo.fromPlatform)();
      if (mounted) {
        setState(() {
          _version = package.version;
          _build = package.buildNumber;
        });
      }
    } catch (_) {
      // Version remains explicitly unavailable instead of being hard-coded.
    }
    if (widget.controller.isGlobalEdition) return;
    final article = await widget.controller.loadSingleArticle(14);
    final raw = '${article['content'] ?? article['description'] ?? ''}';
    final plain = plainTextFromHtml(raw);
    if (mounted && _isUsefulAboutIntroduction(plain)) {
      setState(() => _introduction = plain);
    }
  }

  void _openLegal(GlobalLegalDocumentType document, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.controller.isGlobalEdition
            ? GlobalLegalPage(controller: widget.controller, document: document)
            : _SingleArticlePage(
                controller: widget.controller,
                articleId: document == GlobalLegalDocumentType.privacyPolicy
                    ? 3
                    : 2,
                fallbackTitle: title,
              ),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final gate =
          widget.updateGateController ?? AppUpdateGateScope.maybeOf(context);
      if (gate == null) {
        throw StateError('missing root update gate');
      }
      await gate.checkNow();
    } catch (_) {
      if (mounted) _message('暂时无法检查更新，请稍后再试');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutApp)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 38, 24, 24),
        children: [
          const Center(child: SaydianBrandLockup(width: 176)),
          const SizedBox(height: 26),
          if (!widget.controller.isGlobalEdition) ...[
            Text(
              context.l10n.brandHealthTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            _introduction,
            textAlign: TextAlign.center,
            style: TextStyle(color: SaydianColors.muted, height: 1.6),
          ),
          const SizedBox(height: 12),
          Text(
            _build == '--' ? 'V$_version' : 'V$_version ($_build)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: SaydianColors.muted),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(context.l10n.privacyPolicy),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      _openLegal(GlobalLegalDocumentType.privacyPolicy, '隐私政策'),
                ),
                const Divider(indent: 56, height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(context.l10n.termsOfService),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      _openLegal(GlobalLegalDocumentType.userAgreement, '用户协议'),
                ),
                const Divider(indent: 56, height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_alt_rounded),
                  title: Text(context.l10n.checkUpdates),
                  trailing: _checking
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _checking ? null : _checkUpdate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FeatureStateCard(
            message: context.l10n.healthDataExplanation,
            detail: context.l10n.watchMeasurementSafety,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }
}

class _SingleArticlePage extends StatefulWidget {
  const _SingleArticlePage({
    required this.controller,
    required this.articleId,
    required this.fallbackTitle,
  });

  final AppController controller;
  final int articleId;
  final String fallbackTitle;

  @override
  State<_SingleArticlePage> createState() => _SingleArticlePageState();
}

class _SingleArticlePageState extends State<_SingleArticlePage> {
  Map<String, Object?>? _article;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final value = await widget.controller.loadSingleArticle(widget.articleId);
    if (mounted) setState(() => _article = value);
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;
    final title = '${article?['title'] ?? widget.fallbackTitle}';
    final content = plainTextFromHtml(
      '${article?['content'] ?? article?['description'] ?? ''}',
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: article == null
          ? const Center(child: CircularProgressIndicator())
          : content.isEmpty
          ? const Center(child: Text('内容暂时无法加载'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [Text(content, style: const TextStyle(height: 1.75))],
            ),
    );
  }
}

bool _isUsefulAboutIntroduction(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  return compact.runes.length >= 8;
}
