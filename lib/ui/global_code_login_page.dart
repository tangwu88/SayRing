import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/global_account.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/api_client.dart';
import '../services/app_controller.dart';
import 'brand_assets.dart';
import 'global_legal_page.dart';

/// Say Ring shares the global H5 member and one-time-code sign-in contract.
/// Registration/password UI is intentionally absent from this entry point.
class GlobalCodeLoginPage extends StatefulWidget {
  const GlobalCodeLoginPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<GlobalCodeLoginPage> createState() => _GlobalCodeLoginPageState();
}

class _GlobalCodeLoginPageState extends State<GlobalCodeLoginPage> {
  final _contact = TextEditingController();
  final _code = TextEditingController();
  AccountChannel _channel = AccountChannel.sms;
  GlobalAuthCapabilities? _capabilities;
  VerificationChallenge? _challenge;
  Timer? _timer;
  DateTime? _resendAt;
  String _locale = '';
  String? _error;
  bool _loading = false;
  bool _busy = false;
  bool _accepted = false;
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
      unawaited(_loadCapabilities());
    }
  }

  Future<void> _loadCapabilities() async {
    final generation = ++_capabilityGeneration;
    ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _accepted = false;
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

  String _errorFrom(Object error) {
    if (error is FormatException) return error.message;
    if (error is ApiException) {
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
    'wechat' => widget.controller.errorMessage ?? l.serviceUnavailable,
    _ => l.serviceUnavailable,
  };

  Future<void> _wechatLogin() async {
    if (_busy) return;
    final capability = _capabilities?.wechatApp;
    final consentVersion = _capabilities?.consentVersion?.trim() ?? '';
    if (!_accepted) {
      setState(() => _error = 'consent');
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
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (_busy || _remaining > 0) return;
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
    if (_capabilities?.permitsLogin(identity) != true) {
      setState(() => _error = 'service');
      return;
    }
    if (!_accepted) {
      setState(() => _error = 'consent');
      return;
    }
    if (_challenge == null || !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'code');
      return;
    }
    final consentVersion = _capabilities?.consentVersion?.trim();
    if (consentVersion == null || consentVersion.isEmpty) {
      setState(() => _error = 'service');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final success = await widget.controller.loginGlobalWithCode(
        identity: identity,
        challenge: _challenge!,
        code: _code.text,
        locale: _locale,
        consentVersion: consentVersion,
        privacyConsentGranted: true,
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

  Future<void> _openLegal(GlobalLegalDocumentType document) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            GlobalLegalPage(controller: widget.controller, document: document),
      ),
    );
    if (mounted) await _loadCapabilities();
  }

  @override
  void dispose() {
    ++_generation;
    ++_capabilityGeneration;
    _timer?.cancel();
    _contact.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
              Text(l.signIn, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              if (_loading) const LinearProgressIndicator(),
              if (_capabilities == null && !_loading)
                TextButton.icon(
                  onPressed: _loadCapabilities,
                  icon: const Icon(Icons.refresh),
                  label: Text(l.retry),
                ),
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
                            _contact.clear();
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
                            _contact.clear();
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
                  hintText: _channel == AccountChannel.sms ? '请输入11位手机号' : null,
                ),
                onChanged: (_) => setState(_resetChallenge),
              ),
              const SizedBox(height: 12),
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
              if (_challenge != null)
                Text(l.verificationSentTo(_challenge!.maskedIdentifier)),
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('code-login-submit'),
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? l.pleaseWait : l.signIn),
              ),
              if (_capabilities?.wechatApp.enabled == true) ...[
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

class GlobalWechatPhoneBindingPage extends StatefulWidget {
  const GlobalWechatPhoneBindingPage({
    super.key,
    required this.controller,
    required this.binding,
    required this.capabilities,
    required this.consentVersion,
    required this.locale,
  });

  final AppController controller;
  final GlobalWechatPhoneBinding binding;
  final GlobalAuthCapabilities capabilities;
  final String consentVersion;
  final String locale;

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
