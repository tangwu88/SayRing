part of '../pages.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _accepted = false;
  bool _obscure = true;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_accepted) {
      widget.controller.clearError();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先阅读并同意用户协议与隐私政策')));
      return;
    }
    await widget.controller.login(
      _account.text,
      _password.text,
      privacyConsentGranted: true,
    );
  }

  Future<void> _wechatLogin() async {
    if (widget.controller.isWechatLoginInProgress) {
      widget.controller.cancelWechatLogin();
      return;
    }
    if (!_accepted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先同意用户协议与隐私政策')));
      return;
    }
    FocusScope.of(context).unfocus();
    await widget.controller.loginWithWechat(privacyConsentGranted: true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final media = MediaQuery.of(context);
    final compactLayout =
        media.size.height < 700 || media.viewInsets.bottom > 0;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: saydianSoftGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(26, compactLayout ? 28 : 96, 26, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 375),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    SizedBox(height: compactLayout ? 32 : 64),
                    TextField(
                      controller: _account,
                      enabled: !controller.isBusy,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        hintText: '手机号 / 账号',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.phone_iphone_outlined,
                          color: SaydianColors.muted,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      enabled: !controller.isBusy,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        hintText: '密码',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: SaydianColors.muted,
                          size: 22,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: controller.isBusy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  settings: const RouteSettings(
                                    name: 'password-recovery',
                                  ),
                                  builder: (_) => PasswordRecoveryPage(
                                    controller: controller,
                                  ),
                                ),
                              ),
                        child: Text(context.l10n.forgotPassword),
                      ),
                    ),
                    if (controller.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      InlineNotice(
                        message: controller.errorMessage!,
                        icon: Icons.error_outline,
                        color: SaydianColors.danger,
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(height: compactLayout ? 10 : 20),
                    _AgreementRow(
                      accepted: _accepted,
                      onChanged: (value) =>
                          setState(() => _accepted = value ?? false),
                      onOpenAgreement: _openAgreement,
                    ),
                    SizedBox(height: compactLayout ? 10 : 16),
                    FilledButton(
                      onPressed: controller.isBusy ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:
                          controller.isBusy &&
                              !controller.isWechatLoginInProgress
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.l10n.signIn),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: controller.isBusy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: 'registration',
                                ),
                                builder: (_) =>
                                    RegistrationPage(controller: controller),
                              ),
                            ),
                      style: TextButton.styleFrom(
                        foregroundColor: SaydianColors.ink,
                        minimumSize: const Size.fromHeight(38),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('注册账户'),
                    ),
                    if (!kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.android) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: OutlinedButton(
                            key: const Key('wechat-login'),
                            onPressed:
                                controller.isBusy &&
                                    !controller.canCancelWechatLogin
                                ? null
                                : _wechatLogin,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF07883E),
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.wechat_rounded,
                                  color: Color(0xFF07C160),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    controller.isWechatLoginInProgress
                                        ? controller.canCancelWechatLogin
                                              ? '取消微信登录'
                                              : '正在登录'
                                        : '微信授权登录',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: controller.enterPreview,
                        icon: const CircleAvatar(
                          radius: 14,
                          backgroundColor: SaydianColors.green,
                          child: Icon(
                            Icons.visibility_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        label: const Text('快速体验'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openAgreement({required int id, required String title}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArticleDetailPage(
          controller: widget.controller,
          article: {'id': id, 'title': title},
          singleArticle: true,
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SaydianBrandLockup(width: 190, color: Colors.black),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.accepted,
    required this.onChanged,
    required this.onOpenAgreement,
  });

  final bool accepted;
  final ValueChanged<bool?> onChanged;
  final void Function({required int id, required String title}) onOpenAgreement;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextButton.styleFrom(
      foregroundColor: SaydianColors.blue,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: const TextStyle(fontSize: 14),
    );
    return Row(
      key: const Key('login-agreement'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: accepted, onChanged: onChanged),
        const SizedBox(width: 2),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.l10n.agreeToTerms, style: TextStyle(fontSize: 14)),
              TextButton(
                onPressed: () => onOpenAgreement(id: 2, title: '用户协议'),
                style: linkStyle,
                child: Text(context.l10n.termsOfService),
              ),
              const Text('和', style: TextStyle(fontSize: 14)),
              TextButton(
                onPressed: () => onOpenAgreement(id: 3, title: '隐私政策'),
                style: linkStyle,
                child: Text(context.l10n.privacyPolicy),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
