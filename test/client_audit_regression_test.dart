import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/app_update_service.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

Session _session(String id) => Session(
  accessToken: 'test-$id',
  refreshToken: 'refresh-$id',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  displayName: 'Test',
  accountKey: 'global:member:$id',
);

http.Response _ok(Object data) =>
    http.Response(jsonEncode({'code': 200, 'data': data}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'late logout cannot clear a newer login or send the newer token',
    () async {
      final vault = MemorySessionVault()..session = _session('a');
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/logout')) {
            expect(request.headers['Authorization'], 'Bearer test-a');
            started.complete();
            return response.future;
          }
          return _ok({
            'accessToken': 'test-b',
            'refreshToken': 'refresh-b',
            'expiresAt': '2099-01-01T00:00:00Z',
            'member': {'id': 'b', 'nickname': 'Test'},
          });
        }),
      );
      final logout = api.logout();
      await started.future;
      await api.login('test-b@example.com', 'test-password');
      response.complete(_ok({}));
      await logout;
      expect((await vault.readSession())?.memberId, 'b');
    },
  );

  test(
    'repeated controller logout is one operation and blocks login',
    () async {
      final vault = MemorySessionVault()..session = _session('a');
      final api = _PendingLogoutApi(vault);
      final controller = AppController(
        vault,
        api,
        MemoryHealthStore(),
        _IdleWearable(),
      )..session = _session('a');
      addTearDown(controller.dispose);
      final first = controller.logout();
      await api.started.future;
      final second = controller.logout();
      expect(api.calls, 1);
      expect(controller.isBusy, isTrue);
      expect(await controller.login('b', 'test-password'), isFalse);
      api.finish.complete();
      await Future.wait([first, second]);
      expect(await controller.login('b', 'test-password'), isTrue);
      expect(vault.session?.memberId, 'b');
    },
  );

  test(
    'missing update manifest remains an error and retains required state',
    () async {
      final required = AppUpdateInfo(
        currentVersion: '1.0',
        currentBuild: 1,
        latestVersion: '2.0',
        latestBuild: 2,
        minimumSupportedBuild: 2,
        destinationType: AppUpdateDestinationType.appStore,
        destinationUri: Uri.parse('https://apps.apple.com/app/id6816549943'),
        releaseNotes: '',
        publishedAt: DateTime.utc(2026),
      );
      final store = _UpdateStore(required);
      final updater = GlobalAppUpdateService(
        client: MockClient((_) async => http.Response('', 404)),
        targetPlatform: TargetPlatform.iOS,
        packageInfoLoader: () async => PackageInfo(
          appName: 'Test',
          packageName: 'cn.saydian.ring',
          version: '1.0',
          buildNumber: '1',
        ),
      );
      final coordinator = AppUpdateCoordinator(updater, store: store);
      expect(await coordinator.restoreRequiredUpdate(), isNotNull);
      await expectLater(
        coordinator.checkNow(),
        throwsA(isA<AppUpdateException>()),
      );
      expect(store.required, same(required));
      expect(store.lastSuccessfulCheck, isNull);
    },
  );
}

class _IdleWearable extends Fake implements WearableBridge {}

class _PendingLogoutApi extends Fake implements SaydianApi {
  _PendingLogoutApi(this.vault);
  final MemorySessionVault vault;
  final started = Completer<void>();
  final finish = Completer<void>();
  int calls = 0;

  @override
  Future<void> logout() {
    calls++;
    started.complete();
    return finish.future;
  }

  @override
  Future<Session> login(String username, String password) async {
    final value = _session(username);
    await vault.writeSession(value);
    return value;
  }

  @override
  Future<List<Map<String, Object?>>> getCareMembers() async => [];
  @override
  Future<Map<String, Object?>> getMemberProfile() async => {};
  @override
  Future<Map<String, Object?>> getActivityGoals() async => {};
  @override
  Future<List<Map<String, Object?>>> getNotifications({int page = 1}) async =>
      [];
}

class _UpdateStore implements AppUpdateCheckStore {
  _UpdateStore(this.required);
  AppUpdateInfo? required;
  DateTime? lastSuccessfulCheck;
  @override
  Future<DateTime?> readLastSuccessfulCheck() async => lastSuccessfulCheck;
  @override
  Future<void> writeLastSuccessfulCheck(DateTime value) async {
    lastSuccessfulCheck = value;
  }

  @override
  Future<AppUpdateInfo?> readRequiredUpdate() async => required;
  @override
  Future<void> writeRequiredUpdate(AppUpdateInfo? value) async {
    required = value;
  }
}
