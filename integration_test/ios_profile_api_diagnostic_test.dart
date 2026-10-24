import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

class _StatusOnlyClient extends http.BaseClient {
  final _inner = http.Client();
  final events = <Map<String, Object?>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final bytes = await response.stream.toBytes();
    Object? code;
    String? errorKey;
    try {
      final body = jsonDecode(utf8.decode(bytes));
      if (body is Map) {
        final rawCode = body['code'];
        if (rawCode is int ||
            (rawCode is String && RegExp(r'^\d{1,6}$').hasMatch(rawCode))) {
          code = rawCode;
        }
        final key = body['errorKey'];
        if (key is String && RegExp(r'^[A-Z][A-Z0-9_]{0,90}$').hasMatch(key)) {
          errorKey = key;
        }
      }
    } on FormatException {
      // No response bodies, credentials, identifiers or personal values logged.
    }
    events.add({
      'path': request.url.path,
      'status': response.statusCode,
      'businessCode': code,
      'errorKey': errorKey,
    });
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: response.request,
    );
  }

  @override
  void close() => _inner.close();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('existing session profile API status only', (tester) async {
    runApp(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
    final vault = SecureSessionVault.global();
    final before = await vault.readSession();
    expect(before, isNotNull);
    final client = _StatusOnlyClient();
    addTearDown(client.close);
    final api = GlobalSaydianApiClient(
      vault,
      client: client,
      locale: () => 'zh',
    );
    int? errorStatus;
    String? errorCode;
    var profileLoaded = false;
    try {
      profileLoaded = (await api.getMemberProfile()).isNotEmpty;
    } on ApiException catch (error) {
      errorStatus = error.statusCode;
      final code = error.code;
      if (code is String && RegExp(r'^[A-Z0-9_]{1,90}$').hasMatch(code)) {
        errorCode = code;
      } else if (code is int) {
        errorCode = '$code';
      }
    }
    final after = await vault.readSession();
    final result = <String, Object?>{
      'profileLoaded': profileLoaded,
      'sessionOwnerUnchanged': before!.accountKey == after?.accountKey,
      'accessExpired': before.expiresAt.isBefore(DateTime.now().toUtc()),
      'errorStatus': errorStatus,
      'errorCode': errorCode,
      'requests': client.events,
    };
    binding.reportData = {'profileApiProbe': result};
    // Status metadata only. No OTP, sign-in, profile write or session clearing.
    // ignore: avoid_print
    print('iOS profile API probe: ${jsonEncode(result)}');
    expect(result['sessionOwnerUnchanged'], isTrue);
    expect(profileLoaded, isTrue);
  });
}
