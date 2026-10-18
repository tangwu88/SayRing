import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/global_care.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

Session _account(String id) => Session(
  accessToken: 'synthetic-$id',
  refreshToken: '',
  expiresAt: DateTime.utc(2030),
  memberId: id,
  accountKey: 'global:member:$id',
  displayName: 'Synthetic',
);
http.Response _accepted() => http.Response(
  jsonEncode({
    'code': 200,
    'data': {'invitationSubmitted': true},
  }),
  202,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'member number is explicit and cannot be confused with contact or UUID',
    () {
      expect(CareInvitationTarget.memberId(' 29 ').toJson(), {
        'memberNo': '29',
      });
      expect(CareInvitationTarget.memberId('2147483647').value, '2147483647');
      for (final invalid in [
        '',
        '0',
        '00',
        '029',
        '-1',
        '+29',
        '1.5',
        '2e3',
        '2147483648',
        '13800138000',
        'synthetic-uuid',
      ]) {
        expect(
          () => CareInvitationTarget.memberId(invalid),
          throwsFormatException,
          reason: invalid,
        );
      }
      expect(CareInvitationTarget.contact('sample@example.invalid').toJson(), {
        'identifier': 'sample@example.invalid',
      });
    },
  );

  test(
    'neutral 202 is accepted without interpreting existence or reading health',
    () async {
      final requests = <http.Request>[];
      final vault = MemorySessionVault()..session = _account('one');
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          requests.add(request);
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/global/api/saydian-app/v2/care/invitations',
          );
          expect(jsonDecode(request.body), {'memberNo': '29'});
          expect(request.headers['Authorization'], 'Bearer synthetic-one');
          return _accepted();
        }),
      );
      await api.globalInviteCareByMemberNo('29');
      expect(requests, hasLength(1));
    },
  );

  test(
    'legacy 200 response cannot pretend the member contract is supported',
    () async {
      final vault = MemorySessionVault()..session = _account('one');
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 200,
              'data': {'id': 'synthetic-relation'},
            }),
            200,
          ),
        ),
      );
      await expectLater(
        api.globalInviteCareByMemberNo('29'),
        throwsA(isA<FeatureNotConfiguredException>()),
      );
    },
  );

  test('contacts keep their legacy body and response', () async {
    final vault = MemorySessionVault()..session = _account('one');
    final api = GlobalSaydianApiClient(
      vault,
      client: MockClient((request) async {
        expect(jsonDecode(request.body), {
          'identifier': 'sample@example.invalid',
        });
        return http.Response(
          jsonEncode({
            'code': 200,
            'data': {'id': 'synthetic-relation'},
          }),
          201,
        );
      }),
    );
    await api.globalInviteCare('sample@example.invalid');
  });

  for (final status in [202, 401]) {
    test('late $status is rejected after owner switch without retry', () async {
      final vault = MemorySessionVault()..session = _account('one');
      final begun = Completer<void>(), response = Completer<http.Response>();
      var requests = 0;
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((_) async {
          requests++;
          begun.complete();
          return response.future;
        }),
      );
      final pending = api.globalInviteCareByMemberNo('29');
      await begun.future;
      await vault.writeSession(_account('two'));
      final rejected = expectLater(
        pending,
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'stale owner',
            'STALE_CARE_SESSION',
          ),
        ),
      );
      response.complete(status == 202 ? _accepted() : http.Response('{}', 401));
      await rejected;
      expect(requests, 1);
    });
  }

  test('only explicit memberNo is displayed; UUID is not a member number', () {
    Map<String, Object?> row(Object? memberNo) => {
      'id': 'synthetic-relation',
      'status': 'active',
      'direction': 'sent',
      'recipient': {
        'id': 'synthetic-uuid',
        'nickname': 'Synthetic',
        'memberNo': memberNo,
      },
      'metrics': [],
    };
    expect(GlobalCareRelationship.fromJson(row('29')).memberNo, '29');
    expect(
      GlobalCareRelationship.fromJson(row('synthetic-uuid')).memberNo,
      isNull,
    );
    expect(GlobalCareRelationship.fromJson(row(null)).memberNo, isNull);
  });
}
