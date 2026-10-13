import 'package:phone_numbers_parser/phone_numbers_parser.dart';

enum AccountChannel { email, sms }

class GlobalAccountIdentity {
  const GlobalAccountIdentity._(this.channel, this.identifier, this.country);
  final AccountChannel channel;
  final String identifier;
  final String? country;

  factory GlobalAccountIdentity.email(String input) {
    final value = input.trim().toLowerCase();
    if (value.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      throw const FormatException('invalidEmail');
    }
    return GlobalAccountIdentity._(AccountChannel.email, value, null);
  }

  factory GlobalAccountIdentity.phone(String input, {String? country}) {
    try {
      final value = input.trim();
      // Do not silently extract a number from prose, extensions or service codes.
      if (value.length > 32 || !RegExp(r'^\+?[0-9 ()\-\.]+$').hasMatch(value)) {
        throw const FormatException('invalidPhone');
      }
      final region = country == null
          ? null
          : IsoCode.values.byName(country.toUpperCase());
      if (!input.trim().startsWith('+') && region == null) {
        throw const FormatException('invalidPhone');
      }
      final phone = PhoneNumber.parse(value, destinationCountry: region);
      if (!phone.isValid() ||
          !RegExp(r'^\+[1-9][0-9]{1,14}$').hasMatch(phone.international)) {
        throw const FormatException('invalidPhone');
      }
      return GlobalAccountIdentity._(
        AccountChannel.sms,
        phone.international,
        phone.isoCode.name,
      );
    } catch (_) {
      throw const FormatException('invalidPhone');
    }
  }

  factory GlobalAccountIdentity.parse(String input) {
    final value = input.trim();
    if (value.contains('@')) return GlobalAccountIdentity.email(value);
    return GlobalAccountIdentity.phone(
      value,
      country: value.startsWith('+') ? null : 'CN',
    );
  }

  Map<String, Object?> toJson() => {
    'channel': channel.name,
    'identifier': identifier,
  };
}

class GlobalAuthCapabilities {
  const GlobalAuthCapabilities({
    required this.email,
    required this.sms,
    required this.smsCountries,
    required this.supportedLocales,
    this.verificationRequired = true,
    this.consentVersion,
    this.legal = const {},
    this.recoveryEmail = false,
    this.recoverySms = false,
    this.loginEmail = false,
    this.loginSms = false,
    this.wechatApp = const GlobalWechatAppCapability(),
  });
  final bool email;
  final bool sms;
  final Set<String> smsCountries;
  final List<String> supportedLocales;
  final bool verificationRequired;
  final String? consentVersion;
  final Map<String, String> legal;
  final bool recoveryEmail;
  final bool recoverySms;
  final bool loginEmail;
  final bool loginSms;
  final GlobalWechatAppCapability wechatApp;

  factory GlobalAuthCapabilities.fromJson(Map<String, Object?> data) {
    if (data['realm'] != 'global') {
      throw const FormatException('Unexpected account environment');
    }
    if (data['product'] != 'say-ring') {
      throw const FormatException('Unexpected legal product');
    }
    final methods = data['registration'];
    if (methods is! Map) throw const FormatException('Missing capabilities');
    return GlobalAuthCapabilities(
      email: methods['email'] == true,
      sms: methods['sms'] == true,
      verificationRequired: methods['verificationRequired'] != false,
      recoveryEmail:
          data['recovery'] is Map && (data['recovery'] as Map)['email'] == true,
      recoverySms:
          data['recovery'] is Map && (data['recovery'] as Map)['sms'] == true,
      loginEmail:
          data['login'] is Map && (data['login'] as Map)['email'] == true,
      loginSms: data['login'] is Map && (data['login'] as Map)['sms'] == true,
      wechatApp: GlobalWechatAppCapability.fromJson(
        data['login'] is Map ? (data['login'] as Map)['wechatApp'] : null,
      ),
      smsCountries: (data['smsCountries'] as List? ?? const [])
          .whereType<String>()
          .map((value) => value.toUpperCase())
          .toSet(),
      supportedLocales: (data['supportedLocales'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      consentVersion: data['consentVersion'] as String?,
      legal: {
        if (data['legal'] case final Map entries)
          for (final key in ['userAgreement', 'privacyPolicy'])
            if (entries[key] case {'path': final String path}) key: path,
      },
    );
  }

  bool permits(GlobalAccountIdentity identity, {bool recovery = false}) =>
      switch (identity.channel) {
        AccountChannel.email => recovery ? recoveryEmail : email,
        AccountChannel.sms =>
          (recovery ? recoverySms : sms) &&
              (!recovery && !verificationRequired ||
                  smsCountries.contains(identity.country)),
      };

  bool permitsLogin(GlobalAccountIdentity identity) =>
      switch (identity.channel) {
        AccountChannel.email => loginEmail,
        AccountChannel.sms =>
          loginSms && smsCountries.contains(identity.country),
      };
}

class GlobalWechatAppCapability {
  const GlobalWechatAppCapability({
    this.enabled = false,
    this.appId,
    this.phoneBindingAvailable = false,
  });

  final bool enabled;
  final String? appId;
  final bool phoneBindingAvailable;

  factory GlobalWechatAppCapability.fromJson(Object? value) {
    if (value is! Map) return const GlobalWechatAppCapability();
    final appId = '${value['appId'] ?? ''}'.trim();
    final validAppId = RegExp(r'^wx[A-Za-z0-9]{8,64}$').hasMatch(appId);
    final enabled = value['enabled'] == true && validAppId;
    return GlobalWechatAppCapability(
      enabled: enabled,
      appId: enabled ? appId : null,
      phoneBindingAvailable: enabled && value['phoneBindingAvailable'] == true,
    );
  }
}

class GlobalWechatPhoneBinding {
  const GlobalWechatPhoneBinding({
    required this.ticket,
    required this.expiresIn,
    required this.profileProof,
  });

  final String ticket;
  final int expiresIn;
  final String profileProof;

  factory GlobalWechatPhoneBinding.fromJson(Map<String, Object?> data) {
    final ticket = data['bindTicket'];
    final expiresIn = data['expiresIn'];
    final profileProof = data['wechatProfileProof'];
    if (data['requiresPhoneBinding'] != true ||
        ticket is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(ticket) ||
        expiresIn is! int ||
        expiresIn <= 0 ||
        profileProof is! String ||
        profileProof.isEmpty ||
        profileProof.length > 4096) {
      throw const FormatException('Invalid WeChat binding response');
    }
    return GlobalWechatPhoneBinding(
      ticket: ticket,
      expiresIn: expiresIn,
      profileProof: profileProof,
    );
  }
}

class VerificationChallenge {
  const VerificationChallenge({
    required this.id,
    required this.expiresIn,
    required this.retryAfter,
    required this.maskedIdentifier,
  });
  final String id;
  final int expiresIn;
  final int retryAfter;
  final String maskedIdentifier;

  factory VerificationChallenge.fromJson(Map<String, Object?> data) {
    final id = data['challengeId'];
    final expires = data['expiresIn'];
    final retry = data['retryAfter'];
    if (id is! String ||
        id.isEmpty ||
        expires is! int ||
        expires <= 0 ||
        retry is! int ||
        retry < 0) {
      throw const FormatException('Invalid verification response');
    }
    return VerificationChallenge(
      id: id,
      expiresIn: expires,
      retryAfter: retry,
      maskedIdentifier: '${data['maskedIdentifier'] ?? ''}',
    );
  }
}
