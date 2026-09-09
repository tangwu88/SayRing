import 'dart:async';
import 'dart:convert';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../domain/global_account.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/global_locale_controller.dart';
import '../services/api_client.dart';
import '../services/app_controller.dart';
import 'brand_assets.dart';
import 'global_legal_page.dart';

enum _AuthMode { signIn, signUp, reset }

class GlobalAuthPage extends StatefulWidget {
  const GlobalAuthPage({
    super.key,
    required this.controller,
    this.resetPassword = false,
  });
  final AppController controller;
  final bool resetPassword;

  @override
  State<GlobalAuthPage> createState() => _GlobalAuthPageState();
}

class _GlobalAuthPageState extends State<GlobalAuthPage> {
  final _form = GlobalKey<FormState>();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _code = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  AccountChannel _channel = AccountChannel.email;
  Country? _country;
  GlobalAuthCapabilities? _capabilities;
  VerificationChallenge? _challenge;
  Timer? _timer;
  DateTime? _resendAt;
  int _remaining = 0;
  int _requestGeneration = 0;
  int _capabilityGeneration = 0;
  String _locale = '';
  String? _error;
  bool _loading = false;
  bool _busy = false;
  bool _accepted = false;
  bool _obscured = true;

  AppLocalizations get l => AppLocalizations.of(context)!;
  bool get _accountSetupMode => _mode != _AuthMode.signIn;
  bool get _codeRequired =>
      _mode == _AuthMode.reset ||
      (_mode == _AuthMode.signUp &&
          (_capabilities?.verificationRequired ?? true));

  @override
  void initState() {
    super.initState();
    if (widget.resetPassword) _mode = _AuthMode.reset;
  }

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
    setState(() {
      _loading = true;
      _error = null;
      _capabilities = null;
      _accepted = false;
    });
    try {
      final value = await widget.controller.globalAuthCapabilities();
      if (!mounted || generation != _capabilityGeneration) return;
      setState(() => _capabilities = value);
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
      : GlobalAccountIdentity.phone(
          _contact.text,
          country: _country?.countryCode,
        );

  void _resetChallenge() {
    _requestGeneration++;
    _challenge = null;
    _code.clear();
    _error = null;
    // A contact edit never bypasses the previous resend cooldown.
  }

  void _setMode(_AuthMode mode) {
    if (_busy) return;
    setState(() {
      _mode = mode;
      _resetChallenge();
      _password.clear();
      _confirmation.clear();
    });
  }

  String _message() => switch (_error) {
    'network' => l.networkUnavailable,
    'consent' => l.consentRequired,
    'invalidEmail' => l.invalidEmail,
    'invalidPhone' => l.invalidPhone,
    'code' => l.invalidCode,
    'expired' => l.codeExpired,
    'rate' => l.tooManyAttempts,
    'login' => l.loginFailed,
    'account' => l.accountAlreadyExists,
    _ => l.serviceUnavailable,
  };

  String _errorFrom(Object error) {
    if (error is FormatException) return error.message;
    if (error is ApiException) {
      if (error.statusCode == 429) return 'rate';
      if (error.code == 'verification_expired') return 'expired';
      if (error.code == 'verification_invalid' ||
          error.code == 'verification_used') {
        return 'code';
      }
      if (error.code == 'invalid_credentials') return 'login';
      if (error.code == 'account_exists') return 'account';
      if (error.statusCode == 401) return _codeRequired ? 'code' : 'login';
      if (error.statusCode == 410) return 'expired';
      if (error.code == 'NETWORK_TIMEOUT' ||
          error.code == 'NETWORK_UNAVAILABLE') {
        return 'network';
      }
    }
    return 'service';
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
    if (_capabilities?.permits(identity, recovery: _mode == _AuthMode.reset) !=
        true) {
      setState(() => _error = 'service');
      return;
    }
    final generation = ++_requestGeneration;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await widget.controller.requestGlobalVerification(
        identity: identity,
        purpose: _mode == _AuthMode.reset ? 'reset_password' : 'register',
        locale: _locale,
      );
      if (!mounted || generation != _requestGeneration) return;
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
        setState(
          () => _remaining =
              (_resendAt!.difference(DateTime.now()).inMilliseconds / 1000)
                  .ceil()
                  .clamp(0, 86400),
        );
        if (_remaining == 0) timer.cancel();
      });
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _error = _errorFrom(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    if (_mode == _AuthMode.signUp && !_accepted) {
      setState(() => _error = 'consent');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final identity = _identity();
      final success = _mode == _AuthMode.signIn
          ? await widget.controller.login(
              identity.identifier,
              _password.text,
              privacyConsentGranted: _accepted,
            )
          : _mode == _AuthMode.signUp && !_codeRequired
          ? await widget.controller.registerGlobalWithoutVerification(
              identity: identity,
              password: _password.text,
              locale: _locale,
              privacyConsentGranted: _accepted,
              consentVersion: _capabilities?.consentVersion,
            )
          : await widget.controller.completeGlobalVerification(
              challenge: _challenge!,
              code: _code.text,
              password: _password.text,
              resetPassword: _mode == _AuthMode.reset,
              locale: _locale,
              privacyConsentGranted: _accepted,
              consentVersion: _capabilities?.consentVersion,
            );
      if (mounted && !success) {
        setState(
          () => _error = _errorFrom(
            widget.controller.lastApiError ?? const ApiException('Unavailable'),
          ),
        );
      } else if (mounted && success && widget.resetPassword) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.passwordReset)));
        await Navigator.of(context).maybePop();
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
    // The published version may change while reading; refresh it and require
    // an explicit agreement again rather than retaining a stale consent tick.
    if (mounted) await _loadCapabilities();
  }

  @override
  void dispose() {
    _requestGeneration++;
    _timer?.cancel();
    _contact.dispose();
    _password.dispose();
    _confirmation.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canRegister = _channel == AccountChannel.email
        ? (_mode == _AuthMode.reset
                  ? _capabilities?.recoveryEmail
                  : _capabilities?.email) ==
              true
        : (_mode == _AuthMode.reset
                  ? _capabilities?.recoverySms
                  : _capabilities?.sms) ==
              true;
    final title = switch (_mode) {
      _AuthMode.signIn => l.signIn,
      _AuthMode.signUp => l.createAccount,
      _AuthMode.reset => l.resetPassword,
    };
    return Scaffold(
      key: const Key('global-auth-page'),
      appBar: AppBar(actions: const [GlobalLanguageButton()]),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Center(child: SaydianBrandLockup()),
                const SizedBox(height: 28),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                if (_loading) const LinearProgressIndicator(),
                if (_capabilities == null && !_loading)
                  TextButton.icon(
                    onPressed: _loadCapabilities,
                    icon: const Icon(Icons.refresh),
                    label: Text(l.retry),
                  ),
                if (_accountSetupMode && !_loading && !canRegister)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(l.registrationUnavailable),
                  ),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(l.email),
                            selected: _channel == AccountChannel.email,
                            onSelected: _busy
                                ? null
                                : (_) => setState(() {
                                    _channel = AccountChannel.email;
                                    _resetChallenge();
                                  }),
                          ),
                          ChoiceChip(
                            label: Text(l.phoneNumber),
                            selected: _channel == AccountChannel.sms,
                            onSelected: _busy
                                ? null
                                : (_) => setState(() {
                                    _channel = AccountChannel.sms;
                                    _resetChallenge();
                                  }),
                          ),
                        ],
                      ),
                      if (_channel == AccountChannel.sms)
                        OutlinedButton(
                          key: const Key('auth-country'),
                          onPressed: _busy
                              ? null
                              : () => showCountryPicker(
                                  context: context,
                                  showPhoneCode: true,
                                  countryFilter:
                                      _codeRequired &&
                                          (_capabilities
                                                  ?.smsCountries
                                                  .isNotEmpty ??
                                              false)
                                      ? _capabilities!.smsCountries.toList()
                                      : null,
                                  onSelect: (value) => setState(() {
                                    _country = value;
                                    _resetChallenge();
                                  }),
                                ),
                          child: Text(
                            _country == null
                                ? l.selectCountry
                                : '${_country!.countryCode} +${_country!.phoneCode}',
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('auth-contact'),
                        controller: _contact,
                        enabled: !_busy,
                        keyboardType: _channel == AccountChannel.email
                            ? TextInputType.emailAddress
                            : TextInputType.phone,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: [
                          _channel == AccountChannel.email
                              ? AutofillHints.email
                              : AutofillHints.telephoneNumber,
                        ],
                        decoration: InputDecoration(
                          labelText: _channel == AccountChannel.email
                              ? l.email
                              : l.phoneNumber,
                        ),
                        onChanged: (_) => setState(_resetChallenge),
                        validator: (_) {
                          try {
                            _identity();
                            return null;
                          } catch (_) {
                            return _channel == AccountChannel.email
                                ? l.invalidEmail
                                : l.invalidPhone;
                          }
                        },
                      ),
                      if (_codeRequired) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('auth-code'),
                          controller: _code,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          decoration: InputDecoration(
                            labelText: l.verificationCode,
                          ),
                          validator: (value) =>
                              _challenge == null ||
                                  !RegExp(
                                    r'^\d{6}$',
                                  ).hasMatch(value?.trim() ?? '')
                              ? l.codeRequired
                              : null,
                        ),
                        TextButton(
                          onPressed: _busy || !canRegister || _remaining > 0
                              ? null
                              : _sendCode,
                          child: Text(
                            _remaining > 0
                                ? l.resendCode(_remaining)
                                : l.sendCode,
                          ),
                        ),
                        if (_challenge != null)
                          Text(
                            l.verificationSentTo(_challenge!.maskedIdentifier),
                          ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('auth-password'),
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscured,
                        autofillHints: [
                          _accountSetupMode
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: l.password,
                          suffixIcon: IconButton(
                            tooltip: _obscured
                                ? l.showPassword
                                : l.hidePassword,
                            onPressed: () =>
                                setState(() => _obscured = !_obscured),
                            icon: Icon(
                              _obscured
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => (value?.isEmpty ?? true)
                            ? l.enterPassword
                            : _accountSetupMode &&
                                  (value!.length < 8 ||
                                      utf8.encode(value).length > 72)
                            ? l.passwordRequirement
                            : null,
                      ),
                      if (_accountSetupMode) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('auth-confirm-password'),
                          controller: _confirmation,
                          enabled: !_busy,
                          obscureText: _obscured,
                          decoration: InputDecoration(
                            labelText: l.confirmPassword,
                          ),
                          validator: (value) => value != _password.text
                              ? l.passwordMismatch
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_mode == _AuthMode.signUp)
                        CheckboxListTile(
                          key: const Key('auth-consent'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _accepted,
                          onChanged:
                              _busy || _capabilities?.consentVersion == null
                              ? null
                              : (value) =>
                                    setState(() => _accepted = value == true),
                          title: Text(
                            l.agreeToTerms,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: () => _openLegal(
                              GlobalLegalDocumentType.userAgreement,
                            ),
                            child: Text(l.termsOfService),
                          ),
                          TextButton(
                            onPressed: () => _openLegal(
                              GlobalLegalDocumentType.privacyPolicy,
                            ),
                            child: Text(l.privacyPolicy),
                          ),
                        ],
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _message(),
                            key: const Key('auth-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      FilledButton(
                        key: const Key('auth-submit'),
                        onPressed: _busy || (_accountSetupMode && !canRegister)
                            ? null
                            : _submit,
                        child: Text(_busy ? l.pleaseWait : title),
                      ),
                    ],
                  ),
                ),
                if (_mode == _AuthMode.signIn)
                  TextButton(
                    onPressed: _busy ? null : () => _setMode(_AuthMode.reset),
                    child: Text(l.forgotPassword),
                  ),
                TextButton(
                  key: const Key('auth-toggle-mode'),
                  onPressed: _busy
                      ? null
                      : () => _setMode(
                          _mode == _AuthMode.signIn
                              ? _AuthMode.signUp
                              : _AuthMode.signIn,
                        ),
                  child: Text(
                    _mode == _AuthMode.signIn ? l.noAccount : l.haveAccount,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
