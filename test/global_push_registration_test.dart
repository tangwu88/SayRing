import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

void main() {
  test(
    'Say Ring push registration carries the isolated product identity',
    () async {
      final vault = MemorySessionVault()
        ..session = Session(
          accessToken: 'test-access-token',
          refreshToken: 'test-refresh-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          memberId: 'member-1',
          displayName: 'Test member',
        );
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/global/api/saydian-app/v2/notifications/push-installations',
          );
          expect(request.headers['authorization'], 'Bearer test-access-token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['product'], 'say-ring');
          expect(body['installationId'], 'installation-test');
          expect(body['registrationId'], 'registration-test');
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {'registered': true},
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        await api.registerPushDevice(
          installationId: 'installation-test',
          registrationId: 'registration-test',
          platform: 'android',
          appVersion: '0.1.21',
          buildNumber: 1004,
        ),
        isTrue,
      );
    },
  );
}
