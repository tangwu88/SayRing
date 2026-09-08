import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/secure_vault.dart';

void main() {
  test(
    'App WeChat follows the deployed identity contract without persisting early',
    () async {
      final vault = MemorySessionVault();
      final api = SaydianApiClient(
        vault,
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/site/app-wechat-login');
          expect(request.method, 'POST');
          expect(request.body, contains('name="openid"\r\n\r\nwechat-open-id'));
          for (final field in ['unionid', 'sex', 'nickname', 'headimgurl']) {
            expect(request.body, contains('name="$field"'));
          }
          expect(request.body, isNot(contains('one-time-code')));
          expect(request.body.toLowerCase(), isNot(contains('secret')));
          return http.Response(
            '{"code":200,"data":{"access_token":"test-token","member":{"id":17}}}',
            200,
          );
        }),
      );
      final session = await api.loginWithWechat(
        code: 'one-time-code',
        state: 'sd_1788569000000_0123456789abcdef',
        openId: 'wechat-open-id',
      );
      expect(session.memberId, '17');
      expect(await vault.readSession(), isNull);
    },
  );

  test(
    'WeChat rejects missing identity, malformed and unavailable backend responses',
    () async {
      for (final response in [
        http.Response('{"code":200,"data":{"access_token":"test-token"}}', 200),
        http.Response(
          '请用微信打开',
          200,
          headers: {'content-type': 'text/plain; charset=utf-8'},
        ),
        http.Response('{"code":404,"message":"not found"}', 404),
      ]) {
        final vault = MemorySessionVault();
        final api = SaydianApiClient(
          vault,
          client: MockClient((_) async => response),
        );
        await expectLater(
          api.loginWithWechat(
            code: 'one-time-code',
            state: 'sd_1788569000000_0123456789abcdef',
            openId: 'wechat-open-id',
          ),
          throwsA(isA<ApiException>()),
        );
        expect(await vault.readSession(), isNull);
      }
    },
  );

  test('care member list uses the mini-program member endpoint', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/member/care/my');
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getCareMembers(), isEmpty);
  });

  test('care member list keeps only safe identity fields', () async {
    final client = MockClient(
      (_) async => http.Response(
        '''{"code":200,"data":[{"id":7,"member_id":1,"to_member_id":2,
        "member":{"id":2,"nickname":"妈妈","mobile":"13800138000",
        "head_portrait":"/a.png","password_hash":"secret"}}]}''',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final member = (await api.getCareMembers()).single;
    expect(member['nickname'], '妈妈');
    expect(member['mobile'], '13800138000');
    expect(member['head_portrait'], 'https://example.invalid/a.png');
    expect(member.toString(), isNot(contains('password_hash')));
  });

  test(
    'care member identity accepts the legacy to_member relation alias',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          '''{"code":200,"data":[{"id":8,"to_member":{"id":3,
        "nickname":"爸爸","mobile":"13900139000","head_portrait":"avatar/b.png"}}]}''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      final member = (await api.getCareMembers()).single;
      expect(member['nickname'], '爸爸');
      expect(member['mobile'], '13900139000');
      expect(member['head_portrait'], 'https://example.invalid/avatar/b.png');
    },
  );

  test(
    'care details keep successful readings and expose per-metric failures',
    () async {
      final requestedPaths = <String>[];
      final requestedTypes = <String>[];
      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path == '/api/v1/member/care/my') {
          return http.Response(
            '{"code":200,"data":[{"id":59,"to_member_id":136,"member":{"id":87,"nickname":"家人"}}]}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/api/v1/member/care/preview') {
          expect(request.url.queryParameters['id'], '59');
          return http.Response(
            '''{"code":200,"data":{"jrjk":[
              {"title":"血压","num":0,"unit":"次/分"},
              {"title":"步数","num":1200,"unit":"步"}
            ],"daily":[]}}''',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(request.url.queryParameters['selectmember'], '136');
        expect(request.url.queryParameters['date'], '1787760000');
        final type = request.url.queryParameters['type'];
        if (type != null) requestedTypes.add(type);
        if (type == null || type == 'BloodPressure') {
          return http.Response(
            '{"code":500,"message":"数据查询失败"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (type == 'BloodGlucose') {
          return http.Response(
            '''{"code":200,"data":[{"time":"08:00",
              "bloodGlucose":7.179999828338623}]}''',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"code":200,"data":[]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      await api.getCareMembers();
      final preview = await api.getCareMemberPreview(id: 59, day: '2026-08-27');

      expect(preview['fallback'], isFalse);
      final today = (preview['jrjk'] as List).cast<Map>();
      expect(today, hasLength(1));
      expect(today.single['title'], '步数');
      final daily = (preview['daily'] as List).cast<Map>();
      expect(daily, hasLength(10));
      final pressure = daily.singleWhere((item) => item['title'] == '血压');
      expect(pressure['state'], 'unavailable');
      expect(pressure['tips'], contains('服务暂不可用'));
      final glucose = daily.singleWhere((item) => item['title'] == '血糖');
      expect(glucose['state'], 'ready');
      expect(glucose['latest'], closeTo(7.18, 0.001));
      expect(glucose['avg'], closeTo(7.18, 0.001));
      expect((glucose['records'] as List), hasLength(1));
      expect(
        requestedTypes,
        containsAll(<String>[
          'pulseReat',
          'BloodPressure',
          'BloodGlucose',
          'bloodOxygen',
          'BodyTemperature',
          'HRV',
          'sleep',
        ]),
      );
      expect(requestedPaths, hasLength(12));
    },
  );

  test(
    'care chart series map to accurate latest values and statistics',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/member/care/preview') {
          return http.Response(
            '{"code":200,"data":{}}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final type = request.url.queryParameters['type'];
        final body = switch (type) {
          'pulseReat' =>
            '''{"code":200,"data":{
          "categories":["20:15","08:10"],
          "series":[{"name":"心率","data":[75,68]}]}}''',
          'BloodPressure' =>
            '''{"code":200,"data":{
          "categories":["21:30","07:30"],
          "series":[
            {"name":"收缩压","data":[128,118]},
            {"name":"舒张压","data":[82,76]}
          ]}}''',
          'BloodGlucose' =>
            '''{"code":200,"data":{
          "categories":["20:00","08:00"],
          "series":[{"name":"血糖","data":[7.2,5.8]}]}}''',
          _ => '{"code":200,"data":[]}',
        };
        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      final preview = await api.getCareMemberPreview(
        id: 59,
        memberId: 87,
        day: '2026-08-27',
      );
      final daily = (preview['daily'] as List).cast<Map>();
      final heartRate = daily.singleWhere((item) => item['title'] == '心率');
      expect(heartRate['state'], 'ready');
      expect(heartRate['latest'], 75);
      expect(heartRate['min'], 68);
      expect(heartRate['max'], 75);
      expect(heartRate['avg'], 71.5);

      final pressure = daily.singleWhere((item) => item['title'] == '血压');
      expect(pressure['state'], 'ready');
      expect(pressure['latest'], '128/82');
      expect(pressure['max'], '128/82');
      expect(pressure['min'], '118/76');
      expect(pressure['avg'], '123/79');
      final pressureRecords = (pressure['records'] as List).cast<Map>();
      expect(pressureRecords.first['bloodPressureHigh'], 128);
      expect(pressureRecords.first['bloodPressureLow'], 82);

      final glucose = daily.singleWhere((item) => item['title'] == '血糖');
      expect(glucose['state'], 'ready');
      expect(glucose['latest'], 7.2);
      expect(glucose['min'], 5.8);
      expect(glucose['max'], 7.2);
      expect(glucose['avg'], 6.5);
    },
  );

  test('care day boundary always uses China UTC+8 epoch seconds', () async {
    final requestedDates = <String>{};
    final client = MockClient((request) async {
      if (request.url.path != '/api/v1/member/care/preview') {
        final date = request.url.queryParameters['date'];
        if (date != null) requestedDates.add(date);
      }
      return http.Response(
        '{"code":200,"data":[]}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.getCareMemberPreview(id: 59, memberId: 87, day: '2026-08-27');

    expect(requestedDates, {'1787760000'});
  });

  test(
    'care metric failures require backend repair instead of raw daily fallback',
    () async {
      var rawDailyRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/member/care/preview') {
          return http.Response(
            '{"code":200,"data":{}}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path != '/api/v1/member/daily-date/preview') {
          return http.Response(
            '{"code":200,"data":[]}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(request.url.queryParameters['selectmember'], '87');
        final type = request.url.queryParameters['type'];
        if (type == null) {
          rawDailyRequests += 1;
          return http.Response(
            '{"code":200,"data":[{"time":"08:00","pulseReat":[68],"HRVData":[51]}]}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (const {
          'pulseReat',
          'BloodPressure',
          'BodyTemperature',
          'HRV',
        }.contains(type)) {
          return http.Response(
            '{"code":500,"message":"Internal Server Error"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"code":200,"data":[]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      final preview = await api.getCareMemberPreview(
        id: 59,
        memberId: 87,
        day: '2026-08-27',
      );
      final daily = (preview['daily'] as List).cast<Map>();

      expect(rawDailyRequests, 0);
      for (final title in const ['心率', '血压', '体温', 'HRV']) {
        final item = daily.singleWhere((item) => item['title'] == title);
        expect(item['state'], 'unavailable', reason: title);
        expect(item['tips'], contains('服务暂不可用'));
      }
      for (final title in const ['血糖', '血氧', '睡眠', '心电', '身体成分', '血液成分']) {
        expect(
          daily.singleWhere((item) => item['title'] == title)['state'],
          'empty',
          reason: title,
        );
      }
      for (final item in daily) {
        expect(item['records'], isEmpty);
        expect(item.containsKey('latest'), isFalse);
      }
    },
  );

  test(
    'care ECG uses the authorized member endpoint and preserves waveform metadata',
    () async {
      var ecgRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/member/e-c-g/preview') {
          ecgRequests += 1;
          expect(request.url.queryParameters['selectmember'], '87');
          expect(request.url.queryParameters['date'], isNotEmpty);
          return http.Response(
            r'''{"code":200,"data":[{"id":19,"date":"2026-08-27 09:30:00","data":"{\"aveHeart\":79,\"aveHrv\":52,\"aveQT\":372,\"frequency\":250,\"rawVersion\":2}","totalArray":"[0.0,0.12,-0.08,0.18,-0.04]"}]}''',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"code":200,"data":[]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      final preview = await api.getCareMemberPreview(
        id: 59,
        memberId: 87,
        day: '2026-08-27',
      );
      final daily = (preview['daily'] as List).cast<Map>();
      final ecg = daily.singleWhere((item) => item['title'] == '心电');
      final record = (ecg['records'] as List).cast<Map>().single;

      expect(ecgRequests, 1);
      expect(ecg['state'], 'ready');
      expect(ecg['latest'], 79);
      expect(record['meanHeartRate'], 79);
      expect(record['averageHRV'], 52);
      expect(record['averageTimeInterval'], 372);
      expect(record['sampleFrequency'], 250);
      expect(record['rawVersion'], 2);
      expect(record['origin'], 'remote_member');
      expect(record['samples'], [0.0, 0.12, -0.08, 0.18, -0.04]);
    },
  );

  test('add care uses the mini-program authenticated JSON contract', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/member/care');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      expect(request.headers['token'], 'test-access-token');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body), {'mobile': '13800138000'});
      return http.Response(
        '{"code":200,"message":"成功","data":{"id":9,"member_id":1,"to_member_id":2}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final result = await api.addCare('13800138000');

    expect(result['id'], 9);
    expect(result['to_member_id'], 2);
  });

  test(
    'push registration and notification state use stable contracts',
    () async {
      var requestIndex = 0;
      final client = MockClient((request) async {
        requestIndex += 1;
        expect(request.headers['authorization'], 'Bearer test-access-token');
        expect(request.headers['token'], 'test-access-token');
        switch (requestIndex) {
          case 1:
            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/member/push-devices');
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data;'),
            );
            expect(request.body, contains('name="installation_id"'));
            expect(request.body, contains('\r\n\r\ninstallation-test\r\n'));
            expect(request.body, contains('name="registration_id"'));
            expect(
              request.body,
              contains('\r\n\r\nredacted-registration-id\r\n'),
            );
            expect(request.body, contains('name="platform"'));
            expect(request.body, contains('\r\n\r\nios\r\n'));
            expect(request.body, contains('name="version"'));
            expect(request.body, contains('\r\n\r\ntest-version\r\n'));
            return http.Response('{"code":200,"data":{}}', 200);
          case 2:
            expect(request.method, 'GET');
            expect(request.url.path, '/api/v1/member/notify/statistics');
            return http.Response(
              '{"code":200,"data":{"announce_count":"2","remind_count":1}}',
              200,
            );
          case 3:
            expect(request.method, 'GET');
            expect(request.url.path, '/api/v1/member/notify/19');
            return http.Response('{"code":200,"data":{"id":19}}', 200);
          case 4:
            expect(request.method, 'GET');
            expect(request.url.path, '/api/v1/member/notify/server-event-19');
            return http.Response(
              '{"code":200,"data":{"id":"server-event-19"}}',
              200,
            );
          case 5:
            expect(request.method, 'DELETE');
            expect(
              request.url.path,
              '/api/v1/member/push-devices/installation-test',
            );
            return http.Response('{"code":200,"data":{}}', 200);
          default:
            fail('unexpected request');
        }
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      expect(
        await api.registerPushDevice(
          installationId: 'installation-test',
          registrationId: 'redacted-registration-id',
          platform: 'ios',
          appVersion: 'test-version',
          buildNumber: 23,
        ),
        isTrue,
      );
      expect(await api.getNotificationUnreadCount(), 1);
      expect(await api.markNotificationRead(id: 19), isTrue);
      expect(
        await api.markNotificationEventRead(eventId: 'server-event-19'),
        isTrue,
      );
      expect(
        await api.unregisterPushDevice(installationId: 'installation-test'),
        isTrue,
      );
      expect(requestIndex, 5);
    },
  );

  test('notification inbox requests type 2 instead of announcements', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/member/notify');
      expect(request.url.queryParameters, {'page': '3', 'type': '2'});
      return http.Response('{"code":200,"data":[{"id":8,"type":2}]}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final notifications = await api.getNotifications(page: 3);
    expect(notifications.single['type'], 2);
  });

  test('optional notification endpoints tolerate 404 and 405', () async {
    var requestIndex = 0;
    final client = MockClient((request) async {
      requestIndex += 1;
      switch (requestIndex) {
        case 1:
          expect(request.url.path, '/api/v1/member/push-devices');
          return http.Response('not found', 404);
        case 2:
          expect(request.url.path, '/api/v1/member/notify/statistics');
          return http.Response(
            '{"code":405,"message":"not available","data":{}}',
            200,
          );
        case 3:
          expect(request.url.path, '/api/v1/member/notify/unread-count');
          return http.Response('', 404);
        case 4:
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/member/notify/19');
          return http.Response('', 405);
        case 5:
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/member/notify/19/read');
          return http.Response(
            '{"code":"404","message":"not available","data":{}}',
            200,
          );
        case 6:
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/member/notify/server-event-19');
          return http.Response('', 404);
        case 7:
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/member/notify/server-event-19/read',
          );
          return http.Response('', 405);
        case 8:
          expect(request.method, 'DELETE');
          expect(
            request.url.path,
            '/api/v1/member/push-devices/installation-test',
          );
          return http.Response('', 404);
        default:
          throw StateError('unexpected request');
      }
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      await api.registerPushDevice(
        installationId: 'installation-test',
        registrationId: 'redacted-registration-id',
        platform: 'android',
      ),
      isFalse,
    );
    expect(await api.getNotificationUnreadCount(), isNull);
    expect(await api.markNotificationRead(id: 19), isFalse);
    expect(
      await api.markNotificationEventRead(eventId: 'server-event-19'),
      isFalse,
    );
    expect(
      await api.unregisterPushDevice(installationId: 'installation-test'),
      isFalse,
    );
    expect(requestIndex, 8);
  });

  test('push registration validates metadata before sending secrets', () async {
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: MockClient((_) async => fail('request should not be sent')),
      baseUri: Uri.parse('https://example.invalid'),
    );

    await expectLater(
      api.registerPushDevice(
        installationId: '../unsafe',
        registrationId: 'redacted-registration-id',
        platform: 'ios',
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('avatar upload follows the mini-program multipart contract', () async {
    final directory = await Directory.systemTemp.createTemp(
      'saydian-avatar-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}${Platform.pathSeparator}avatar.png');
    await image.writeAsBytes(const [0x89, 0x50, 0x4E, 0x47]);

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/file/images');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      expect(request.headers['token'], 'test-access-token');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      final multipartBody = latin1.decode(request.bodyBytes);
      expect(multipartBody, contains('name="file"'));
      expect(multipartBody, contains('filename="avatar.png"'));
      return http.Response(
        '{"code":200,"data":{"url":"/uploads/avatar.png"}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      await api.uploadImage(image.path),
      'https://example.invalid/uploads/avatar.png',
    );
  });

  test('add care rejects malformed mobile before making a request', () async {
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: MockClient((_) async => fail('request should not be sent')),
    );

    expect(() => api.addCare('abc'), throwsA(isA<ApiException>()));
  });

  test(
    'AI chat stays JSON while profile save uses the deployed form contract',
    () async {
      var requestIndex = 0;
      final client = MockClient((request) async {
        requestIndex++;
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer test-access-token');
        expect(request.headers['token'], 'test-access-token');
        if (requestIndex == 1) {
          expect(request.headers['content-type'], contains('application/json'));
          final body = jsonDecode(request.body);
          expect(request.url.path, '/api/rf-article/chat/create');
          expect(body, {'app': 1, 'message': '你好', 'session_id': 'session-1'});
          return http.Response(
            '{"code":200,"data":{"message":"您好","session_id":"session-1"}}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(request.url.path, '/api/v1/member/member/save');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data;'),
        );
        final body = utf8.decode(request.bodyBytes);
        for (final entry in const {
          'nickname': '测试用户',
          'gender': '1',
          'birthday': '1960-01-02',
          'height': '168.5',
          'weight': '62',
          'head_portrait': 'https://app.saidian.cc/avatar.png',
        }.entries) {
          expect(body, contains('name="${entry.key}"'));
          expect(body, contains(entry.value));
        }
        return http.Response('{"code":200,"data":{}}', 200);
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      expect(
        await api.sendAiMessage(app: 1, message: '你好', sessionId: 'session-1'),
        containsPair('message', '您好'),
      );
      await api.saveMemberProfile(
        nickname: '测试用户',
        gender: 1,
        birthday: '1960-01-02',
        height: 168.5,
        weight: 62,
        headPortrait: 'https://app.saidian.cc/avatar.png',
      );
      expect(requestIndex, 2);
    },
  );

  test('profile avatar upload follows the mini-program file contract', () async {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}saidian-avatar-test.jpg',
    );
    await file.writeAsBytes(const [0xFF, 0xD8, 0xFF, 0xD9]);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/file/images');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      expect(request.headers['token'], 'test-access-token');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(latin1.decode(request.bodyBytes), contains('name="file"'));
      return http.Response(
        '{"code":200,"data":{"url":"/attachment/avatar/test.jpg"}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      await api.uploadProfileImage(file.path),
      'https://example.invalid/attachment/avatar/test.jpg',
    );
  });

  test('business error code is preserved when HTTP status is 200', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"code":401,"message":"Unauthorized","data":{}}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await expectLater(
      api.getCareMembers(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.code, 'code', 401),
      ),
    );
  });

  test(
    'health upload uses the mini-program daily route and field shapes',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/member/daily-date');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final daily =
            (body['dailyDate'] as List).single as Map<String, dynamic>;
        expect(daily['pulseReat'], [72]);
        expect(daily['heartReat'], 72);
        expect(daily['bloodPressure'], {
          'bloodPressureHigh': 126,
          'bloodPressureLow': 79,
        });
        expect(daily['bloodOxygen'], {
          'oxygens': [98, 0, 0],
        });
        return http.Response('{"code":200,"data":{}}', 200);
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );
      HealthRecord record(
        String id,
        HealthMetric metric,
        Map<String, num> values,
        String unit,
      ) => HealthRecord(
        id: id,
        metric: metric,
        values: values,
        unit: unit,
        measuredAt: DateTime.utc(2026, 8, 13, 8, 30),
        timezone: '+08:00',
        deviceId: 'W9S',
        firmwareVersion: '1.0.0',
        quality: 'good',
        source: MeasurementSource.wearable,
        rawVersion: 1,
      );
      final records = [
        record('heart', HealthMetric.heartRate, const {'value': 72}, 'bpm'),
        record('pressure', HealthMetric.bloodPressure, const {
          'systolic': 126,
          'diastolic': 79,
        }, 'mmHg'),
        record('oxygen', HealthMetric.bloodOxygen, const {'value': 98}, '%'),
      ];

      final result = await api.uploadHealthBatch(
        SyncBatch(cursor: null, records: records),
      );
      expect(result.acceptedIds, {'heart', 'pressure', 'oxygen'});
      expect(result.rejected, isEmpty);
    },
  );

  test(
    'health upload sends temperature through the deployed daily route',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/member/daily-date');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final daily =
            (body['dailyDate'] as List).single as Map<String, dynamic>;
        expect(daily['bodyTemperature'], {'bodyTemperature': 36.6});
        return http.Response('{"code":200,"message":"ok","data":{}}', 200);
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );
      final result = await api.uploadHealthBatch(
        SyncBatch(
          cursor: null,
          records: [
            HealthRecord(
              id: 'temperature',
              metric: HealthMetric.bodyTemperature,
              values: const {'value': 36.6},
              unit: '℃',
              measuredAt: DateTime.utc(2026, 9, 2, 8),
              timezone: '+08:00',
              deviceId: 'W9S',
              firmwareVersion: '1.0.0',
              quality: 'good',
              source: MeasurementSource.wearable,
              rawVersion: 1,
            ),
          ],
        ),
      );
      expect(result.acceptedIds, {'temperature'});
      expect(result.nextCursor, isNull);
    },
  );

  test(
    'health warning and feedback use deployed mini-program contracts',
    () async {
      var step = 0;
      final client = MockClient((request) async {
        step++;
        expect(request.headers['authorization'], 'Bearer test-access-token');
        switch (step) {
          case 1:
            expect(request.method, 'GET');
            expect(request.url.path, '/api/v1/member/health-warning/preview');
            return http.Response(
              '{"code":200,"message":"ok","data":{"heart_auto":"0","heart_num":"130.00","blood_pressure_auto":1,"blood_glucose_auto":"1","body_temperature_auto":"1"}}',
              200,
            );
          case 2:
            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/member/health-warning');
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data;'),
            );
            expect(request.body, contains('name="heart_auto"'));
            expect(request.body, contains('name="heart_num"'));
            expect(request.body, contains('\r\n\r\n120\r\n'));
            expect(request.body, contains('name="blood_pressure_auto"'));
            expect(request.body, contains('name="blood_glucose_auto"'));
            expect(request.body, contains('name="body_temperature_auto"'));
            return http.Response('{"code":200,"message":"ok","data":{}}', 200);
          default:
            expect(request.url.path, '/api/v1/member/feedback');
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data;'),
            );
            expect(request.body, contains('name="type"'));
            expect(request.body, contains('设备连接'));
            expect(request.body, contains('name="content"'));
            expect(request.body, contains('连接后数据没有更新'));
            return http.Response(
              '{"code":200,"message":"ok","data":{"id":3}}',
              200,
            );
        }
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      final settings = await api.getHealthWarningSettings();
      expect(settings?.heartRateEnabled, isFalse);
      expect(settings?.heartRateUpper, 130);
      expect(settings?.bloodPressureEnabled, isTrue);
      expect(settings?.temperatureEnabled, isTrue);
      expect(settings?.diastolicUpper, 90);
      await api.saveHealthWarningSettings(const HealthWarningSettings());
      final alerts = await api.getHealthWarningAlerts();
      expect(alerts, isEmpty);
      expect(
        await api.submitFeedback(category: '设备连接', content: '连接后数据没有更新'),
        '3',
      );
      expect(step, 3);
    },
  );

  test('health encyclopedia uses the mini-program public endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/rf-article/article/index');
      expect(request.url.queryParameters, isEmpty);
      return http.Response(
        '{"code":200,"data":[{"id":3,"title":"健康百科","cover":"http://sd.cc"}]}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final articles = await api.getArticles();

    expect(articles.single['id'], 3);
    expect(articles.single['cover'], 'https://app.saidian.cc');
  });

  test('article categories use parent id 3 by default', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/rf-article/article-cate/index');
      expect(request.url.queryParameters, {'pid': '3'});
      return http.Response(
        '{"code":200,"data":[{"id":8,"title":"慢病管理"}]}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final categories = await api.getArticleCategories();

    expect(categories.single['id'], 8);
  });

  test('category article list sends category and page parameters', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/rf-article/article/index');
      expect(request.url.queryParameters, {'cate_id': '8', 'page': '2'});
      return http.Response(
        '{"code":200,"data":{"list":[{"id":11,"cover":"http://sd.cc/uploads/cover.png"}]}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final articles = await api.getArticlesByCategory(categoryId: 8, page: 2);

    expect(articles.single['id'], 11);
    expect(
      articles.single['cover'],
      'https://app.saidian.cc/uploads/cover.png',
    );
  });

  test('unfiltered paged article list omits category parameter', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/rf-article/article/index');
      expect(request.url.queryParameters, {'page': '1'});
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getArticlesByCategory(), isEmpty);
  });

  test('network failures are normalized to an offline ApiException', () async {
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: MockClient(
        (request) async =>
            throw http.ClientException('Failed host lookup', request.url),
      ),
      baseUri: Uri.parse('https://example.invalid'),
    );

    await expectLater(
      api.getArticles(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'NETWORK_UNAVAILABLE')
            .having((error) => error.message, 'message', '网络连接失败，请检查网络后重试'),
      ),
    );
  });

  test('privacy agreement uses the single-article endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/rf-article/article-single/view');
      expect(request.url.queryParameters['id'], '3');
      return http.Response(
        '{"code":200,"data":{"id":3,"title":"隐私协议"}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect((await api.getSingleArticle(3))['title'], '隐私协议');
  });

  test('orders send the authenticated synthesize status contract', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/inv-shop/v1/member/order/index');
      expect(request.url.queryParameters['page'], '1');
      expect(request.url.queryParameters['synthesize_status'], '2');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getOrders(status: 2), isEmpty);
  });

  test('all orders omit the synthesize status filter', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
    final client = MockClient((request) async {
      expect(request.url.path, '/api/inv-shop/v1/member/order/index');
      expect(
        request.url.queryParameters.containsKey('synthesize_status'),
        isFalse,
      );
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getOrders(), isEmpty);
  });

  test('shop home uses the public SHOP_HOME page contract', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/pages');
      expect(request.url.queryParameters['code'], 'SHOP_HOME');
      expect(request.headers.containsKey('authorization'), isFalse);
      return http.Response(
        '{"code":200,"data":{"items":[{"type":"tabs"}]}}',
        200,
      );
    });
    final api = SaydianApiClient(
      MemorySessionVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect((await api.getShopHome())['items'], isA<List>());
  });

  test('order preview sends the mini-program buy-now query contract', () async {
    final vault = _authenticatedVault();
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/inv-shop/v1/order/order/preview');
      expect(request.url.queryParameters['type'], 'buy_now');
      expect(request.url.queryParameters['is_channel'], '0');
      expect(jsonDecode(request.url.queryParameters['data']!), {
        'sku_id': 2975,
        'num': 2,
      });
      expect(request.headers['authorization'], 'Bearer test-access-token');
      return http.Response('{"code":200,"data":{"products":[]}}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      await api.previewShopOrder(
        items: const [
          {'sku_id': 2975, 'num': 2},
        ],
      ),
      contains('products'),
    );
  });

  test(
    'shop checkout previews multiple products through the server cart',
    () async {
      var requestCount = 0;
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: MockClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            expect(request.url.path, '/api/inv-shop/v1/member/cart-item/index');
            return http.Response(
              '{"code":200,"data":[{"id":"18","sku_id":"2975","number":"1"},{"id":"19","sku_id":"2976","number":"1"}]}',
              200,
            );
          }
          expect(request.url.path, '/api/inv-shop/v1/order/order/preview');
          expect(request.url.queryParameters, {
            'type': 'cart',
            'data': '18,19',
            'is_channel': '0',
          });
          return http.Response(
            '{"code":200,"data":{"address":{"id":8},"account":{"money1":0},"products":[{"sku_id":2975},{"sku_id":2976}],"preview":{"product_money":30,"shipping_money":4}}}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        baseUri: Uri.parse('https://example.invalid'),
      );

      final preview = await api.previewShopOrder(
        items: const [
          {'sku_id': 2975, 'num': 1},
          {'sku_id': 2976, 'num': 1},
        ],
      );
      expect(requestCount, 2);
      expect((preview['products'] as List), hasLength(2));
      expect((preview['preview'] as Map)['product_money'], 30);
      expect((preview['preview'] as Map)['shipping_money'], 4);
    },
  );

  test('create order sends the confirmed JSON checkout contract', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/inv-shop/v1/order/order/create');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['address_id'], 8);
      expect(body['shipping_type'], 1);
      expect(body['type'], 'buy_now');
      expect(body['buyer_message'], '请尽快发货');
      expect(jsonDecode(body['data'] as String), {'sku_id': 2975, 'num': 2});
      return http.Response('{"code":200,"data":{"id":99}}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final order = await api.createShopOrder(
      items: const [
        {'sku_id': 2975, 'num': 2},
      ],
      addressId: 8,
      buyerMessage: '请尽快发货',
    );
    expect(order['id'], 99);
  });

  test('APP payment sends the backend WeChat and Alipay contracts', () async {
    var requestIndex = 0;
    final client = MockClient((request) async {
      requestIndex++;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/pay');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      final body = request.body;
      expect(body, contains('name="pay_type"'));
      expect(
        body,
        contains(requestIndex == 1 ? '\r\n\r\n1\r\n' : '\r\n\r\n2\r\n'),
      );
      expect(body, contains('name="jump"'));
      expect(body, contains('\r\n\r\n0\r\n'));
      expect(body, contains('name="trade_type"'));
      expect(body, contains('\r\n\r\napp\r\n'));
      expect(body, contains('name="order_group"'));
      expect(body, contains('\r\n\r\norder\r\n'));
      expect(body, contains('name="data"'));
      expect(body, contains('{"order_id":"99","money":"199.00"}'));
      return http.Response(
        requestIndex == 1
            ? '{"code":200,"data":{"payStatus":false,"config":{"appid":"wx-test"}}}'
            : '{"code":200,"data":{"payStatus":false,"config":{"config":"signed-order"}}}',
        200,
      );
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      await api.createShopPayment(provider: 'wechat', orderId: 99, money: 199),
      containsPair('payStatus', false),
    );
    expect(
      await api.createShopPayment(provider: 'alipay', orderId: 99, money: 199),
      containsPair('payStatus', false),
    );
    expect(requestIndex, 2);
  });

  test('multi-select checkout creates one order from server cart ids', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      if (requestCount == 1) {
        expect(request.url.path, '/api/inv-shop/v1/member/cart-item/index');
        return http.Response(
          '{"code":200,"data":[{"id":"18","sku_id":"2975","number":"1"},{"id":"19","sku_id":"2976","number":"2"}]}',
          200,
        );
      }
      expect(request.url.path, '/api/inv-shop/v1/order/order/create');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['point'], 5);
      expect(body['type'], 'cart');
      expect(body['data'], '18,19');
      return http.Response('{"code":200,"data":{"id":101}}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final result = await api.createShopOrder(
      items: const [
        {'sku_id': 2975, 'num': 1},
        {'sku_id': 2976, 'num': 2},
      ],
      addressId: 8,
      buyerMessage: '',
      point: 5,
    );
    expect(requestCount, 2);
    expect(result['id'], 101);
    expect(result['created_sku_ids'], [2975, 2976]);
  });

  test(
    'APP payment preserves a directly returned signed order string',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/pay');
        return http.Response(
          '{"code":200,"data":"app_id=server&sign=server-signature"}',
          200,
        );
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      expect(
        await api.createShopPayment(
          provider: 'alipay',
          orderId: 99,
          money: 199,
        ),
        containsPair('config', 'app_id=server&sign=server-signature'),
      );
    },
  );

  test(
    'multi-select checkout adds missing products before creating cart order',
    () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          expect(request.url.path, '/api/inv-shop/v1/member/cart-item/index');
          return http.Response(
            '{"code":200,"data":[{"id":"18","sku_id":"2975","number":"1"}]}',
            200,
          );
        }
        if (requestCount == 2) {
          expect(request.url.path, '/api/inv-shop/v1/member/cart-item/create');
          expect(request.body, contains('name="sku_id"'));
          expect(request.body, contains('\r\n\r\n2976\r\n'));
          expect(request.body, contains('name="num"'));
          expect(request.body, contains('\r\n\r\n2\r\n'));
          return http.Response(
            '{"code":200,"data":{"cartList":[{"id":"18","sku_id":"2975","number":"1"},{"id":"19","sku_id":"2976","number":"2"}]}}',
            200,
          );
        }
        expect(request.url.path, '/api/inv-shop/v1/order/order/create');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['type'], 'cart');
        expect(body['data'], '18,19');
        return http.Response('{"code":200,"data":{"id":102}}', 200);
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      final result = await api.createShopOrder(
        items: const [
          {'sku_id': 2975, 'num': 1},
          {'sku_id': 2976, 'num': 2},
        ],
        addressId: 8,
        buyerMessage: '',
        point: 5,
      );
      expect(requestCount, 3);
      expect(result['order_ids'], [102]);
    },
  );

  test(
    'confirm receipt and after-sales use authenticated shop routes',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('{"code":200,"data":{}}', 200);
      });
      final api = SaydianApiClient(
        _authenticatedVault(),
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      await api.confirmOrderReceipt(424);
      await api.applyOrderRefund(
        orderProductId: 800,
        refundType: 2,
        amount: 99,
        reason: '商品无法正常使用',
      );

      expect(
        requests[0].url.path,
        '/api/inv-shop/v1/member/order/take-delivery',
      );
      expect(requests[0].body, contains('424'));
      expect(
        requests[1].url.path,
        '/api/inv-shop/v1/member/order-product/refund-apply',
      );
      expect(requests[1].body, contains('商品无法正常使用'));
    },
  );

  test('address create uses authenticated JSON region fields', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/member/address');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['realname'], '张三');
      expect(body['province_id'], 440000);
      expect(body['city_id'], 440300);
      expect(body['area_id'], 440305);
      expect(body['is_default'], 1);
      return http.Response('{"code":200,"data":{"id":8}}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(
      (await api.saveAddress(
        realname: '张三',
        mobile: '13800138000',
        addressDetails: '科技园 1 号',
        isDefault: true,
        region: '广东省 深圳市 南山区',
        provinceId: 440000,
        cityId: 440300,
        areaId: 440305,
      ))['id'],
      8,
    );
  });

  test('activity goals use the confirmed multipart field names', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/member/member-mubiao');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      expect(request.body, contains('name="steps"'));
      expect(request.body, contains('10000'));
      expect(request.body, contains('name="juli"'));
      expect(request.body, contains('6.5'));
      expect(request.body, contains('name="reliang"'));
      expect(request.body, contains('800'));
      return http.Response('{"code":200,"data":{}}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.saveActivityGoals(steps: 10000, distance: 6.5, calories: 800);
  });

  test('care invitation response uses the prototype status contract', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/member/care/save');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body), {'id': 19, 'examine_status': 2});
      return http.Response('{"code":200,"data":{}}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.respondCareInvitation(id: 19, accepted: false);
  });

  test('care invitations never expose the recipient as the inviter', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/member/care');
      return http.Response(
        '{"code":200,"data":{"list":[{"id":59,"member_id":82,"to_member_id":1,"examine_status":0,"member":{"id":1,"nickname":"当前账号","mobile":"13600136000","password_hash":"secret"}},{"id":60,"member_id":1,"to_member_id":90,"examine_status":1,"member":{"id":90,"nickname":"我邀请的人"}}]}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    final invitations = await api.getCareInvitations();
    expect(invitations, hasLength(1));
    final invitation = invitations.single;
    expect(invitation['inviter_id'], 82);
    expect(invitation['member'], isEmpty);
    expect(invitation.containsKey('password_hash'), isFalse);
  });

  test('care share settings decode the server JSON list', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/member/care-setting/preview');
      expect(request.url.queryParameters, {'type': '2', 'to_member_id': '7'});
      return http.Response(
        '{"code":200,"data":{"setting":"[\\"heart_rate\\",\\"sleep\\"]"}}',
        200,
      );
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getCareShareSettings(type: 2, memberId: 7), {
      'heart_rate',
      'sleep',
    });
  });

  test('care share settings save a stable sorted JSON list', () async {
    var reads = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        expect(request.url.path, '/api/v1/member/care-setting/preview');
        expect(request.url.queryParameters, {'type': '2', 'to_member_id': '7'});
        reads++;
        return http.Response(
          '{"code":200,"data":{"setting":["heartReat","HRV"]}}',
          200,
        );
      }
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/member/care-setting');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body), {
        'type': 2,
        'to_member_id': 7,
        'setting': ['HRV', 'heartReat'],
      });
      return http.Response('{"code":200,"data":{}}', 200);
    });
    final api = SaydianApiClient(
      _authenticatedVault(),
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.saveCareShareSettings(
      type: 2,
      memberId: 7,
      settings: {'heartReat', 'HRV'},
    );
    expect(reads, 1);
  });

  test('SMS authentication uses the confirmed RageFrame contracts', () async {
    var requestIndex = 0;
    final client = MockClient((request) async {
      requestIndex++;
      expect(request.method, 'POST');
      if (requestIndex == 1) {
        expect(request.url.path, '/api/v1/site/sms-code');
        expect(request.body, contains('name="mobile"'));
        expect(request.body, contains('13800138000'));
        expect(request.body, contains('name="usage"'));
        expect(request.body, contains('register'));
        return http.Response('{"code":200,"data":{}}', 200);
      }
      if (requestIndex == 2) {
        expect(request.url.path, '/api/v1/site/register');
        for (final field in const [
          'mobile',
          'code',
          'password',
          'password_repetition',
          'nickname',
          'group',
        ]) {
          expect(request.body, contains('name="$field"'));
        }
      } else {
        expect(request.url.path, '/api/v1/site/up-pwd');
        expect(request.body, contains('name="code"'));
        expect(request.body, contains('up-password'));
      }
      return http.Response(
        '{"code":200,"data":{"access_token":"access","refresh_token":"refresh","expiration_time":43200,"member":{"id":7,"nickname":"测试用户"}}}',
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final vault = MemorySessionVault();
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.sendSmsCode(mobile: '13800138000', usage: 'register');
    await api.registerWithSms(
      mobile: '13800138000',
      code: '1234',
      password: 'register-password',
      nickname: '测试用户',
    );
    await api.resetPassword(
      mobile: '13800138000',
      code: '5678',
      password: 'up-password',
    );

    expect(requestIndex, 3);
    expect(vault.session?.accessToken, 'access');
  });

  test('expired access token is refreshed without losing login state', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'expired-access',
        refreshToken: 'long-lived-refresh',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        memberId: '7',
        displayName: '长期登录用户',
      );
    var requestIndex = 0;
    final client = MockClient((request) async {
      requestIndex++;
      if (requestIndex == 1) {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/site/refresh');
        expect(request.body, contains('long-lived-refresh'));
        expect(request.body, contains('name="group"'));
        return http.Response(
          '{"code":200,"data":{"access_token":"fresh-access","refresh_token":"fresh-refresh","expiration_time":43200,"member":{"id":7,"nickname":"长期登录用户"}}}',
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      expect(request.url.path, '/api/v1/member/care/my');
      expect(request.headers['authorization'], 'Bearer fresh-access');
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    await api.getCareMembers();

    expect(requestIndex, 2);
    expect(vault.session?.accessToken, 'fresh-access');
    expect(vault.session?.refreshToken, 'fresh-refresh');
  });

  test('server-revoked access token refreshes once and retries request', () async {
    final vault = MemorySessionVault()
      ..session = Session(
        accessToken: 'revoked-access',
        refreshToken: 'long-lived-refresh',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
        memberId: '7',
        displayName: '长期登录用户',
      );
    var requestIndex = 0;
    final client = MockClient((request) async {
      requestIndex++;
      if (requestIndex == 1) {
        expect(request.url.path, '/api/v1/member/care/my');
        expect(request.headers['authorization'], 'Bearer revoked-access');
        return http.Response(
          '{"code":401,"message":"Your request was made with invalid credentials.","data":{}}',
          200,
        );
      }
      if (requestIndex == 2) {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/site/refresh');
        expect(request.body, contains('long-lived-refresh'));
        return http.Response(
          '{"code":200,"data":{"access_token":"fresh-access","refresh_token":"fresh-refresh","expiration_time":43200,"member":{"id":7,"nickname":"长期登录用户"}}}',
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      expect(request.url.path, '/api/v1/member/care/my');
      expect(request.headers['authorization'], 'Bearer fresh-access');
      return http.Response('{"code":200,"data":[]}', 200);
    });
    final api = SaydianApiClient(
      vault,
      client: client,
      baseUri: Uri.parse('https://example.invalid'),
    );

    expect(await api.getCareMembers(), isEmpty);

    expect(requestIndex, 3);
    expect(vault.session?.accessToken, 'fresh-access');
    expect(vault.session?.refreshToken, 'fresh-refresh');
  });

  test(
    'delayed A refresh cannot overwrite or retry after switching to B',
    () async {
      final accountA = Session(
        accessToken: 'access-a',
        refreshToken: 'refresh-a',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
        memberId: '7',
        displayName: 'A',
      );
      final accountB = Session(
        accessToken: 'access-b',
        refreshToken: 'refresh-b',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
        memberId: '8',
        displayName: 'B',
      );
      final vault = MemorySessionVault()..session = accountA;
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (request.url.path == '/api/v1/member/care/my') {
          expect(request.headers['authorization'], 'Bearer access-a');
          return http.Response(
            '{"code":401,"message":"Unauthorized","data":{}}',
            200,
          );
        }
        expect(request.url.path, '/api/v1/site/refresh');
        if (!refreshStarted.isCompleted) refreshStarted.complete();
        await releaseRefresh.future;
        return http.Response(
          '{"code":200,"data":{"access_token":"fresh-a","refresh_token":"fresh-refresh-a","expiration_time":43200,"member":{"id":7,"nickname":"A"}}}',
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = SaydianApiClient(
        vault,
        client: client,
        baseUri: Uri.parse('https://example.invalid'),
      );

      final oldRequest = api.getCareMembers();
      await refreshStarted.future;
      await vault.writeSession(accountB);
      releaseRefresh.complete();

      await expectLater(
        oldRequest,
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(vault.session?.memberId, '8');
      expect(vault.session?.accessToken, 'access-b');
      expect(requestCount, 2);
    },
  );
}

MemorySessionVault _authenticatedVault() =>
    MemorySessionVault()
      ..session = Session(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        memberId: '1',
        displayName: '测试用户',
      );
