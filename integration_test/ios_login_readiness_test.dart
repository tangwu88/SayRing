import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saydian_app/app.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';

// Real, public configuration only: no credentials, OTP, consent or account edits.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('real iOS public login readiness', (tester) async {
    final report = <String, Object?>{};
    final app = AppController.production();
    try {
      runApp(SaydianApp(controller: app));
      await app.initialize().timeout(const Duration(seconds: 45));
      try {
        final caps = await app.globalAuthCapabilities().timeout(
          const Duration(seconds: 30),
        );
        report.addAll({
          'loaded': true,
          'sms': caps.loginSms,
          'emailOtp': caps.loginEmail,
          'consentVersion': caps.consentVersion,
          'legalCount': caps.legal.length,
        });
      } catch (error) {
        report.addAll({
          'loaded': false,
          'errorType': error.runtimeType.toString(),
        });
        if (error is ApiException) {
          report.addAll({
            'code': error.code,
            'httpStatus': error.statusCode,
            'message': error.message,
          });
        }
      }
      expect(
        report['loaded'],
        isTrue,
        reason: 'Public configuration must load on the actual phone',
      );
    } finally {
      final dir = await getApplicationDocumentsDirectory();
      await File(
        '${dir.path}/login-readiness-private.json',
      ).writeAsString(jsonEncode(report), flush: true);
      binding.reportData = {'publicConfigurationLoaded': report['loaded']};
      app.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
