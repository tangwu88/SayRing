import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/global_account.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/api_client.dart';
import '../services/app_controller.dart';
import 'brand_assets.dart';
import 'global_legal_page.dart';

/// Say Ring shares the global member account. Phone sign-in uses a one-time
/// code; an existing email account may also sign in with its password.
class GlobalCodeLoginPage extends StatefulWidget {
  const GlobalCodeLoginPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<GlobalCodeLoginPage> createState() => _GlobalCodeLoginPageState();
}

class _GlobalCodeLoginPageState extends State<GlobalCodeLoginPage> {
  final _contact = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  AccountChannel _channel = AccountChannel.sms;
  bool _emailPasswordMode = false;
  GlobalAuthCapabilities? _capabilities;
  VerificationChallenge? _challenge;
  Timer? _timer;
  DateTime? _resendAt;
  String _locale = '';
  String? _error;
  bool _loading = false;
  bool _busy = false;
  bool _accepted = false;
  bool _ageConfirmed = false;
  int _generation = 0;
  int _capabilityGeneration = 0;
  int _remaining = 0;

  AppLocalizations get l => AppLocalizations.of(context)!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (locale != _locale) {
      _locale = locale;
      // The iPhone release is deliberately account-free. Do not contact the
      // account service merely to show its local companion entry point.
      if (!widget.controller.supportsLocalOnlyUse) {
        unawaited(_loadCapabilities());
      }
    }
  }

  Future<void> _loadCapabilities() async {
    final generation = ++_capabilityGeneration;
    ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _accepted = false;
      _ageConfirmed = false;
      _capabilities = null;
      _challenge = null;
      _code.clear();
    });
    try {
      final value = await widget.controller.globalAuthCapabilities();
      if (mounted && generation == _capabilityGeneration) {
        setState(() => _capabilities = value);
      }
    } catch (error) {
      if (mounted && generation == _capabilityGeneration) {
        setState(() => _error = _errorFrom(error));
      }
    } finally {
      if (mounted && generation == _capabilityGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  GlobalAccountIdentity _identity() => _channel == AccountChannel.email
      ? GlobalAccountIdentity.email(_contact.text)
      : GlobalAccountIdentity.phone(_contact.text, country: 'CN');

  void _resetChallenge() {
    ++_generation;
    _challenge = null;
    _code.clear();
    _error = null;
    // Editing a contact never resets the server's resend cooldown.
  }

  bool get _passwordMode =>
      _channel == AccountChannel.email && _emailPasswordMode;

  String _errorFrom(Object error) {
    if (error is FormatException) return error.message;
    if (error is ApiException) {
      if (error.code == 'minimum_age_confirmation_required') return 'age';
      if (error.statusCode == 429) return 'rate';
      if (error.code == 'verification_invalid' ||
          error.code == 'verification_used') {
        return 'code';
      }
      if (error.code == 'verification_expired' || error.statusCode == 410) {
        return 'expired';
      }
      if (error.code == 'NETWORK_TIMEOUT' ||
          error.code == 'NETWORK_UNAVAILABLE') {
        return 'network';
      }
      if (error.code == 'invalid_credentials' || error.statusCode == 401) {
        return 'login';
      }
    }
    return 'service';
  }

  String _errorText() => switch (_error) {
    'invalidEmail' => l.invalidEmail,
    'invalidPhone' => l.invalidPhone,
    'code' => l.invalidCode,
    'expired' => l.codeExpired,
    'rate' => l.tooManyAttempts,
    'network' => l.networkUnavailable,
    'consent' => l.consentRequired,
    'password' => l.enterPassword,
    'login' => l.loginFailed,
    'age' =>
      Localizations.localeOf(context).languageCode == 'zh'
          ? '请确认已满14周岁后继续'
          : 'Confirm that you are at least 14 years old to continue.',
    'wechat' => widget.controller.errorMessage ?? l.serviceUnavailable,
    _ => l.serviceUnavailable,
  };

  Future<void> _wechatLogin() async {
    if (_busy || (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)) {
      return;
    }
    final capability = _capabilities?.wechatApp;
    final consentVersion = _capabilities?.consentVersion?.trim() ?? '';
    if (!_accepted) {
      setState(() => _error = 'consent');
      return;
    }
    if (!_ageConfirmed) {
      setState(() => _error = 'age');
      return;
    }
    if (capability?.enabled != true ||
        capability?.appId == null ||
        consentVersion.isEmpty) {
      setState(() => _error = 'service');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final success = await widget.controller.loginWithWechat(
        privacyConsentGranted: true,
        appId: capability!.appId,
        consentVersion: consentVersion,
        locale: _locale,
        ageConfirmed: true,
      );
      if (!mounted || success) return;
      final binding = widget.controller.pendingGlobalWechatBinding;
      if (binding == null) {
        setState(() => _error = 'wechat');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GlobalWechatPhoneBindingPage(
            controller: widget.controller,
            binding: binding,
            capabilities: _capabilities!,
            consentVersion: consentVersion,
            locale: _locale,
            ageConfirmed: true,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (_busy || _remaining > 0) return;
    if (!_ageConfirmed) {
      setState(() => _error = 'age');
      return;
    }
    GlobalAccountIdentity identity;
    try {
      identity = _identity();
    } catch (error) {
      setState(() => _error = _errorFrom(error));
      return;
    }
    if (_capabilities?.permitsLogin(identity) != true) {
      setState(() => _error = 'service');
      return;
    }
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await widget.controller.requestGlobalLoginCode(
        identity: identity,
        locale: _locale,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _challenge = challenge;
        _resendAt = DateTime.now().add(Duration(seconds: challenge.retryAfter));
        _remaining = challenge.retryAfter;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _remaining =
              (_resendAt!.difference(DateTime.now()).inMilliseconds / 1000)
                  .ceil()
                  .clamp(0, 86400);
        });
        if (_remaining == 0) timer.cancel();
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = _errorFrom(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    GlobalAccountIdentity identity;
    try {
      identity = _identity();
    } catch (error) {
      setState(() => _error = _errorFrom(error));
      return;
    }
    if (_passwordMode
        ? _capabilities == null
        : _capabilities?.permitsLogin(identity) != true) {
      setState(() => _error = 'service');
      return;
    }
    if (!_accepted) {
      setState(() => _error = 'consent');
      return;
    }
    if (!_ageConfirmed) {
      setState(() => _error = 'age');
      return;
    }
    final consentVersion = _capabilities?.consentVersion?.trim();
    if (consentVersion == null || consentVersion.isEmpty) {
      setState(() => _error = 'service');
      return;
    }
    if (_passwordMode) {
      if (_password.text.isEmpty) {
        setState(() => _error = 'password');
        return;
      }
    } else if (_challenge == null ||
        !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final success = _passwordMode
          ? await widget.controller.loginGlobalWithEmailPassword(
              identity: identity,
              password: _password.text,
              consentVersion: consentVersion,
              locale: _locale,
              privacyConsentGranted: true,
            )
          : await widget.controller.loginGlobalWithCode(
              identity: identity,
              challenge: _challenge!,
              code: _code.text,
              locale: _locale,
              consentVersion: consentVersion,
              privacyConsentGranted: true,
              ageConfirmed: true,
            );
      if (mounted && !success) {
        setState(
          () => _error = _errorFrom(
            widget.controller.lastApiError ?? const ApiException('Unavailable'),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorFrom(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterLocalMode() async {
    if (_busy) return;
    if (!_ageConfirmed) {
      setState(() => _error = 'age');
      return;
    }
    if (!_accepted) {
      setState(() => _error = 'consent');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.enterLocalMode();
    } catch (_) {
      if (mounted) setState(() => _error = 'service');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLegal(GlobalLegalDocumentType document) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            GlobalLegalPage(controller: widget.controller, document: document),
      ),
    );
    if (mounted) await _loadCapabilities();
  }

  Future<void> _openLocalLegal(String path) async {
    final opened = await launchUrl(
      Uri.parse('https://app.saydian.cn$path'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(() => _error = 'service');
    }
  }

  Widget _localAgreementCheckbox({
    required Key key,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
  }) => CheckboxListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: value,
    onChanged: _busy ? null : onChanged,
    title: Text(title, style: const TextStyle(fontSize: 13, height: 1.4)),
  );

  Widget _buildLocalOnlyUse(BuildContext context) => Scaffold(
    key: const Key('global-code-login-page'),
    appBar: AppBar(),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: SaydianBrandLockup(color: Colors.black)),
              const SizedBox(height: 28),
              const Text(
                '连接智能戒指，查看本机数据',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                '无需注册或登录。健康、活动和睡眠记录仅保存在这台 iPhone，不上传到云端。',
                style: TextStyle(fontSize: 15, height: 1.55),
              ),
              const SizedBox(height: 24),
              _localAgreementCheckbox(
                key: const Key('local-ring-minimum-age'),
                value: _ageConfirmed,
                onChanged: (value) =>
                    setState(() => _ageConfirmed = value == true),
                title: '我确认已满14周岁',
              ),
              _localAgreementCheckbox(
                key: const Key('local-ring-consent'),
                value: _accepted,
                onChanged: (value) => setState(() => _accepted = value == true),
                title: '我已阅读并同意《用户协议》和《隐私政策》',
              ),
              Wrap(
                children: [
                  TextButton(
                    key: const Key('local-ring-terms'),
                    onPressed: _busy
                        ? null
                        : () => _openLocalLegal('/say-ring/terms'),
                    child: const Text('用户协议'),
                  ),
                  TextButton(
                    key: const Key('local-ring-privacy'),
                    onPressed: _busy
                        ? null
                        : () => _openLocalLegal('/say-ring/privacy'),
                    child: const Text('隐私政策'),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorText(),
                    key: const Key('local-ring-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('local-ring-use-entry'),
                onPressed: _busy ? null : _enterLocalMode,
                icon: const Icon(Icons.watch_outlined),
                label: Text(_busy ? l.pleaseWait : '开始连接戒指'),
              ),
              const SizedBox(height: 14),
              const Text(
                '健康数据仅供个人健康管理参考，不用于医疗诊断或治疗。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    ++_generation;
    ++_capabilityGeneration;
    _timer?.cancel();
    _contact.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.supportsLocalOnlyUse) {
      return _buildLocalOnlyUse(context);
    }
    return Scaffold(
      key: const Key('global-code-login-page'),
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Center(child: SaydianBrandLockup(color: Colors.black)),
                const SizedBox(height: 28),
                Text(
                  l.signIn,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                if (_loading) const LinearProgressIndicator(),
                if (_capabilities == null && !_loading)
                  TextButton.icon(
                    onPressed: _loadCapabilities,
                    icon: const Icon(Icons.refresh),
                    label: Text(l.retry),
                  ),
                if (widget.controller.supportsLocalOnlyUse) ...[
                  Card(
                    key: const Key('local-ring-use-card'),
                    color: const Color(0xFFF3F7FF),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '无需账号，先连接戒指',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '健康和睡眠数据仅保存在本机。登录仅用于后续同步与账号服务。',
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const Key('local-ring-use-entry'),
                            onPressed: _busy ? null : _enterLocalMode,
                            icon: const Icon(Icons.watch_outlined),
                            label: Text(_busy ? l.pleaseWait : '开始本机使用'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '已有账号可登录同步',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l.phoneNumber),
                      selected: _channel == AccountChannel.sms,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() {
                              _channel = AccountChannel.sms;
                              _emailPasswordMode = false;
                              _contact.clear();
                              _password.clear();
                              _resetChallenge();
                            }),
                    ),
                    ChoiceChip(
                      label: Text(l.email),
                      selected: _channel == AccountChannel.email,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() {
                              _channel = AccountChannel.email;
                              _emailPasswordMode = true;
                              _contact.clear();
                              _password.clear();
                              _resetChallenge();
                            }),
                    ),
                  ],
                ),
                TextField(
                  key: const Key('code-login-contact'),
                  controller: _contact,
                  enabled: !_busy,
                  keyboardType: _channel == AccountChannel.sms
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  autofillHints: [
                    _channel == AccountChannel.sms
                        ? AutofillHints.telephoneNumber
                        : AutofillHints.email,
                  ],
                  inputFormatters: _channel == AccountChannel.sms
                      ? [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ]
                      : null,
                  decoration: InputDecoration(
                    labelText: _channel == AccountChannel.sms
                        ? l.phoneNumber
                        : l.email,
                    hintText: _channel == AccountChannel.sms
                        ? '请输入11位手机号'
                        : null,
                  ),
                  onChanged: (_) => setState(_resetChallenge),
                ),
                if (_channel == AccountChannel.email &&
                    (_capabilities?.loginEmail == true || !_passwordMode))
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('email-login-mode'),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _emailPasswordMode = !_emailPasswordMode;
                              _password.clear();
                              _resetChallenge();
                            }),
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'zh'
                            ? (_passwordMode ? '使用邮箱验证码登录' : '使用邮箱密码登录')
                            : (_passwordMode
                                  ? 'Use an email code instead'
                                  : 'Use an email password instead'),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_passwordMode)
                  TextField(
                    key: const Key('email-login-password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(labelText: l.password),
                  )
                else ...[
                  TextField(
                    key: const Key('code-login-code'),
                    controller: _code,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: InputDecoration(labelText: l.verificationCode),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('code-login-send'),
                      onPressed: _busy || _remaining > 0 ? null : _sendCode,
                      child: Text(
                        _remaining > 0 ? l.resendCode(_remaining) : l.sendCode,
                      ),
                    ),
                  ),
                ],
                if (!_passwordMode && _challenge != null)
                  Text(l.verificationSentTo(_challenge!.maskedIdentifier)),
                CheckboxListTile(
                  key: const Key('code-login-minimum-age'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _ageConfirmed,
                  onChanged: _busy
                      ? null
                      : (value) =>
                            setState(() => _ageConfirmed = value == true),
                  title: Text(
                    Localizations.localeOf(context).languageCode == 'zh'
                        ? '我确认已满14周岁'
                        : 'I confirm that I am at least 14 years old.',
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
                CheckboxListTile(
                  key: const Key('code-login-consent'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _accepted,
                  onChanged:
                      _busy ||
                          !(_capabilities?.consentVersion?.trim().isNotEmpty ??
                              false)
                      ? null
                      : (value) => setState(() => _accepted = value == true),
                  title: Text(
                    l.agreeToTerms,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () =>
                          _openLegal(GlobalLegalDocumentType.userAgreement),
                      child: Text(l.termsOfService),
                    ),
                    TextButton(
                      onPressed: () =>
                          _openLegal(GlobalLegalDocumentType.privacyPolicy),
                      child: Text(l.privacyPolicy),
                    ),
                  ],
                ),
                if (_error != null)
                  Text(
                    _errorText(),
                    key: const Key('code-login-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('code-login-submit'),
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? l.pleaseWait : l.signIn),
                ),
                if (!widget.controller.supportsLocalOnlyUse) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('review-demo-entry'),
                    onPressed: _busy ? null : widget.controller.enterPreview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('无需手机号，查看只读演示'),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '演示内容均为本机示例数据，不会连接戒指或保存资料。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                if (_capabilities?.wechatApp.enabled == true &&
                    (kIsWeb ||
                        defaultTargetPlatform != TargetPlatform.iOS)) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('global-wechat-login'),
                    onPressed: _busy ? null : _wechatLogin,
                    icon: const Icon(
                      Icons.wechat_rounded,
                      color: Color(0xFF07C160),
                    ),
                    label: const Text('微信授权登录'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlobalWechatPhoneBindingPage extends StatefulWidget {
  const GlobalWechatPhoneBindingPage({
    super.key,
    required this.controller,
    required this.binding,
    required this.capabilities,
    required this.consentVersion,
    required this.locale,
    required this.ageConfirmed,
  });

  final AppController controller;
  final GlobalWechatPhoneBinding binding;
  final GlobalAuthCapabilities capabilities;
  final String consentVersion;
  final String locale;
  final bool ageConfirmed;

  @override
  State<GlobalWechatPhoneBindingPage> createState() =>
      _GlobalWechatPhoneBindingPageState();
}

class _GlobalWechatPhoneBindingPageState
    extends State<GlobalWechatPhoneBindingPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  VerificationChallenge? _challenge;
  Timer? _timer;
  int _remaining = 0;
  bool _busy = false;
  String? _error;

  AppLocalizations get l => AppLocalizations.of(context)!;

  GlobalAccountIdentity _identity() =>
      GlobalAccountIdentity.phone(_phone.text, country: 'CN');

  Future<void> _send() async {
    if (_busy || _remaining > 0) return;
    GlobalAccountIdentity identity;
    try {
      identity = _identity();
    } catch (_) {
      setState(() => _error = l.invalidPhone);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await widget.controller.requestGlobalWechatPhoneCode(
        binding: widget.binding,
        identity: identity,
        consentVersion: widget.consentVersion,
        locale: widget.locale,
      );
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _challenge = challenge;
        _remaining = challenge.retryAfter;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _remaining <= 1) {
          timer.cancel();
          if (mounted) setState(() => _remaining = 0);
        } else {
          setState(() => _remaining--);
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = l.serviceUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bind() async {
    final challenge = _challenge;
    if (_busy ||
        challenge == null ||
        !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = l.invalidCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final success = await widget.controller.bindGlobalWechatPhone(
      binding: widget.binding,
      challenge: challenge,
      code: _code.text,
      consentVersion: widget.consentVersion,
      locale: widget.locale,
      ageConfirmed: widget.ageConfirmed,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _busy = false;
        _error = widget.controller.errorMessage ?? l.serviceUnavailable;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('global-wechat-phone-binding-page'),
    appBar: AppBar(title: const Text('绑定手机号')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.phone_android, size: 52),
              const SizedBox(height: 16),
              const Text(
                '首次使用微信登录需要验证并绑定手机号，绑定后再次微信授权可直接进入。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                key: const Key('wechat-bind-phone'),
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: InputDecoration(
                  labelText: l.phoneNumber,
                  hintText: '请输入11位手机号',
                ),
                onChanged: (_) => setState(() {
                  _challenge = null;
                  _code.clear();
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('wechat-bind-code'),
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: InputDecoration(labelText: l.verificationCode),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('wechat-bind-send'),
                  onPressed:
                      _busy ||
                          _remaining > 0 ||
                          !widget.capabilities.wechatApp.phoneBindingAvailable
                      ? null
                      : _send,
                  child: Text(
                    _remaining > 0 ? l.resendCode(_remaining) : l.sendCode,
                  ),
                ),
              ),
              if (_challenge != null)
                Text(l.verificationSentTo(_challenge!.maskedIdentifier)),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('wechat-bind-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('wechat-bind-submit'),
                onPressed: _busy ? null : _bind,
                child: Text(_busy ? l.pleaseWait : '绑定并登录'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
