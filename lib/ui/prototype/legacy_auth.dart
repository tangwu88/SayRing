part of '../prototype_pages.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _distributor = TextEditingController();
  bool _accepted = false;
  bool _obscure = true;
  bool _sendingCode = false;
  int _codeCountdown = 0;
  Timer? _codeTimer;

  @override
  void dispose() {
    _mobile.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    _distributor.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final mobile = _mobile.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      _message('请输入正确的中国大陆手机号');
      return;
    }
    setState(() => _sendingCode = true);
    final success = await widget.controller.sendSmsCode(
      mobile: mobile,
      usage: 'register',
    );
    if (!mounted) return;
    setState(() => _sendingCode = false);
    if (!success) {
      _message(widget.controller.errorMessage ?? '验证码发送失败，请稍后重试');
      return;
    }
    _message('验证码已发送，请注意查收');
    _codeTimer?.cancel();
    setState(() => _codeCountdown = 60);
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _codeCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _codeCountdown = 0);
      } else {
        setState(() => _codeCountdown--);
      }
    });
  }

  Future<void> _submit() async {
    final mobile = _mobile.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      _message('请输入正确的中国大陆手机号');
      return;
    }
    if (_password.text.length < 6) {
      _message('密码至少需要 6 位');
      return;
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(_code.text.trim())) {
      _message('请输入收到的短信验证码');
      return;
    }
    if (_password.text != _confirmation.text) {
      _message('两次输入的密码不一致');
      return;
    }
    if (!_accepted) {
      _message('请先阅读并同意用户协议与隐私政策');
      return;
    }
    final success = await widget.controller.register(
      mobile,
      _password.text,
      code: _code.text,
      privacyConsentGranted: true,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _message(widget.controller.errorMessage ?? '注册失败，请稍后重试');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.signUp)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            const Center(child: SaydianBrandLockup(width: 154)),
            const SizedBox(height: 28),
            TextField(
              key: const Key('registration-mobile'),
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: context.l10n.phoneNumber),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('registration-code'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: context.l10n.smsCode,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    key: const Key('registration-send-code'),
                    onPressed:
                        _sendingCode ||
                            _codeCountdown > 0 ||
                            widget.controller.isBusy
                        ? null
                        : _sendCode,
                    child: Text(
                      _sendingCode
                          ? '发送中'
                          : _codeCountdown > 0
                          ? '${_codeCountdown}s'
                          : '获取验证码',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: '设置密码',
                helperText: '至少 6 位',
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
            const SizedBox(height: 12),
            TextField(
              controller: _confirmation,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: context.l10n.confirmPassword,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _distributor,
              decoration: const InputDecoration(
                labelText: '经销商编号（选填）',
                helperText: '没有可不填',
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('我已阅读并同意用户协议与隐私政策'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('registration-submit'),
              onPressed: widget.controller.isBusy ? null : _submit,
              child: widget.controller.isBusy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.l10n.signUp),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({this.controller, super.key});

  final AppController? controller;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _message;
  bool _obscure = true;
  bool _sendingCode = false;
  int _codeCountdown = 0;
  Timer? _codeTimer;

  @override
  void dispose() {
    _mobile.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final controller = widget.controller;
    if (controller == null) {
      setState(() => _message = '短信服务暂时无法使用，请稍后再试');
      return;
    }
    final mobile = _mobile.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      setState(() => _message = '请输入正确的中国大陆手机号');
      return;
    }
    setState(() {
      _sendingCode = true;
      _message = null;
    });
    final success = await controller.sendSmsCode(
      mobile: mobile,
      usage: 'up-pwd',
    );
    if (!mounted) return;
    setState(() {
      _sendingCode = false;
      _message = success
          ? '验证码已发送，请注意查收'
          : controller.errorMessage ?? '验证码发送失败，请稍后重试';
    });
    if (!success) return;
    _codeTimer?.cancel();
    setState(() => _codeCountdown = 60);
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _codeCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _codeCountdown = 0);
      } else {
        setState(() => _codeCountdown--);
      }
    });
  }

  Future<void> _submit() async {
    final controller = widget.controller;
    if (controller == null) {
      setState(() => _message = '找回密码服务暂时无法使用，请稍后再试');
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _message = '两次输入的新密码不一致');
      return;
    }
    final success = await controller.resetPassword(
      mobile: _mobile.text,
      code: _code.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码已重置，并已自动登录')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _message = controller.errorMessage ?? '密码重置失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('找回密码')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.lock_reset_rounded,
            size: 72,
            color: SaydianColors.blue,
          ),
          const SizedBox(height: 20),
          const Text(
            '验证手机号',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '输入注册手机号，验证通过后可重新设置密码。',
            textAlign: TextAlign.center,
            style: TextStyle(color: SaydianColors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          TextField(
            key: const Key('password-recovery-mobile'),
            controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: context.l10n.phoneNumber),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('password-recovery-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: context.l10n.smsCode,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  key: const Key('password-recovery-send-code'),
                  onPressed:
                      _sendingCode ||
                          _codeCountdown > 0 ||
                          (widget.controller?.isBusy ?? false)
                      ? null
                      : _sendCode,
                  child: Text(
                    _sendingCode
                        ? '发送中'
                        : _codeCountdown > 0
                        ? '${_codeCountdown}s'
                        : '获取验证码',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('password-recovery-password'),
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: '新密码',
              helperText: '至少 6 位',
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
          const SizedBox(height: 12),
          TextField(
            key: const Key('password-recovery-confirmation'),
            controller: _confirmation,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: '确认新密码'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 14),
            FeatureStateCard(
              message: _message!,
              icon: Icons.info_outline_rounded,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('password-recovery-submit'),
            onPressed: widget.controller?.isBusy == true ? null : _submit,
            child: Text(context.l10n.resetPassword),
          ),
        ],
      ),
    );
  }
}
