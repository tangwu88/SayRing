import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PackageInfo package(String version, String build) => PackageInfo(
    appName: '赛电健康',
    packageName: 'cc.saidian.app',
    version: version,
    buildNumber: build,
  );

  String manifest({
    String platform = 'ios',
    int latestBuild = 25,
    int minimumBuild = 20,
    String destinationType = 'app_store',
    String destinationUrl = 'https://apps.apple.com/app/id1234567890',
    String? sha256,
  }) =>
      '''
    {
      "schema_version": 1,
      "platform": "$platform",
      "channel": "production",
      "latest_version": "0.2.0",
      "latest_build": $latestBuild,
      "minimum_supported_build": $minimumBuild,
      "release_notes": "Stability update",
      "published_at": "2026-08-29T01:00:00+08:00",
      "destination": {
        "type": "$destinationType",
        "url": "$destinationUrl"
      }${sha256 == null ? '' : ',"sha256":"$sha256"'}
    }
  ''';

  String backendRelease({
    int code = 200,
    int version = 1002,
    String versionCode = '1.0.02',
    int androidType = 1,
    String android = 'downloads/Saydian.apk',
    String ios = 'https://apps.apple.com/app/id1234567890',
    int force = 1,
    int lowwer = 20,
    int status = 1,
  }) => jsonEncode({
    'code': code,
    'message': code == 200 ? 'OK' : '版本服务异常',
    'data': {
      'id': 16,
      'title': '赛电健康新版',
      'version': version,
      'version_code': versionCode,
      'description': '<p>修复内容</p><p>优化体验</p>',
      'android_type': androidType,
      'android': android,
      'ios': ios,
      'force': force,
      'lowwer': lowwer,
      'status': status,
      'created_at': 1788513945,
      'updated_at': 1788513991,
    },
    'timestamp': 1788515506,
  });

  http.Response jsonResponse(String body, [int statusCode = 200]) =>
      http.Response.bytes(
        utf8.encode(body),
        statusCode,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );

  test(
    'backend API sends the current build and parses the server contract',
    () async {
      late Uri requestedUri;
      final service = AppUpdateService(
        endpointUri: Uri.parse('https://app.saidian.cc/api/v1/site/version'),
        targetPlatform: TargetPlatform.android,
        packageInfoLoader: () async => package('0.1.19', '23'),
        client: MockClient((request) async {
          requestedUri = request.url;
          return jsonResponse(backendRelease());
        }),
      );

      final info = await service.check();

      expect(requestedUri.path, '/api/v1/site/version');
      expect(requestedUri.queryParameters['v'], '23');
      expect(requestedUri.queryParameters['platform'], 'android');
      expect(info.title, '赛电健康新版');
      expect(info.latestVersion, '1.0.02');
      expect(info.latestBuild, 1002);
      expect(info.minimumSupportedBuild, 20);
      expect(info.forceUpdate, isTrue);
      expect(info.releaseNotes, '修复内容\n优化体验');
      expect(info.destinationType, AppUpdateDestinationType.androidApk);
      expect(
        info.destinationUri,
        Uri.parse('https://app.saidian.cc/downloads/Saydian.apk'),
      );
      expect(info.sha256, isNull);
      expect(
        info.publishedAt,
        DateTime.fromMillisecondsSinceEpoch(1788513991000, isUtc: true),
      );
    },
  );

  test('backend data null means the installed build is current', () async {
    final service = AppUpdateService(
      endpointUri: Uri.parse('https://app.saidian.cc/api/v1/site/version'),
      targetPlatform: TargetPlatform.android,
      packageInfoLoader: () async => package('1.0.02', '1002'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'code': 200, 'message': 'OK', 'data': null}),
          200,
        ),
      ),
    );

    final info = await service.check();

    expect(info.hasUpdate, isFalse);
    expect(info.forceUpdate, isFalse);
    expect(info.latestVersion, '1.0.02');
    expect(info.latestBuild, 1002);
  });

  test(
    'backend external Android updates open the configured destination',
    () async {
      final service = AppUpdateService(
        endpointUri: Uri.parse('https://app.saidian.cc/api/v1/site/version'),
        targetPlatform: TargetPlatform.android,
        packageInfoLoader: () async => package('0.1.19', '23'),
        client: MockClient(
          (_) async => jsonResponse(
            backendRelease(
              androidType: 0,
              android: 'https://app.saydian.cn/down',
              force: 0,
              lowwer: 0,
            ),
          ),
        ),
      );

      final info = await service.check();

      expect(info.destinationType, AppUpdateDestinationType.androidStore);
      expect(info.destinationUri, Uri.parse('https://app.saydian.cn/down'));
      expect(info.forceUpdate, isFalse);
    },
  );

  test(
    'backend external Android updates still reject non-HTTPS URLs',
    () async {
      final service = AppUpdateService(
        endpointUri: Uri.parse('https://app.saidian.cc/api/v1/site/version'),
        targetPlatform: TargetPlatform.android,
        packageInfoLoader: () async => package('0.1.19', '23'),
        client: MockClient(
          (_) async => jsonResponse(
            backendRelease(
              androidType: 0,
              android: 'http://app.saydian.cn/down',
              force: 0,
              lowwer: 0,
            ),
          ),
        ),
      );

      await expectLater(
        service.check(),
        throwsA(
          isA<AppUpdateException>().having(
            (error) => error.message,
            'message',
            '更新地址必须使用 HTTPS',
          ),
        ),
      );
    },
  );

  test('backend APK downloads remain restricted to trusted hosts', () async {
    final service = AppUpdateService(
      endpointUri: Uri.parse('https://app.saidian.cc/api/v1/site/version'),
      targetPlatform: TargetPlatform.android,
      packageInfoLoader: () async => package('0.1.19', '23'),
      client: MockClient(
        (_) async => jsonResponse(
          backendRelease(
            androidType: 1,
            android: 'https://downloads.invalid/Saydian.apk',
          ),
        ),
      ),
    );

    await expectLater(
      service.check(),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.message,
          'message',
          '更新地址不在允许的安全域名内',
        ),
      ),
    );
  });

  test(
    'backend business errors are surfaced without creating an update',
    () async {
      final service = AppUpdateService(
        endpointUri: Uri.parse('https://app.saidian.cc/api/v1/site/version'),
        targetPlatform: TargetPlatform.android,
        packageInfoLoader: () async => package('0.1.19', '23'),
        client: MockClient(
          (_) async => jsonResponse(backendRelease(code: 500)),
        ),
      );

      await expectLater(
        service.check(),
        throwsA(
          isA<AppUpdateException>().having(
            (error) => error.message,
            'message',
            '版本服务异常',
          ),
        ),
      );
    },
  );

  test(
    'iOS production manifest accepts only an App Store destination',
    () async {
      final service = AppUpdateService(
        manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
        targetPlatform: TargetPlatform.iOS,
        packageInfoLoader: () async => package('0.1.19', '23'),
        client: MockClient((_) async => http.Response(manifest(), 200)),
      );

      final info = await service.check();

      expect(info.hasUpdate, isTrue);
      expect(info.forceUpdate, isFalse);
      expect(info.latestBuild, 25);
      expect(info.minimumSupportedBuild, 20);
      expect(info.destinationType, AppUpdateDestinationType.appStore);
    },
  );

  test('minimum supported build alone controls mandatory updates', () async {
    final service = AppUpdateService(
      manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
      targetPlatform: TargetPlatform.iOS,
      packageInfoLoader: () async => package('0.1.19', '19'),
      client: MockClient(
        (_) async =>
            http.Response(manifest(latestBuild: 25, minimumBuild: 20), 200),
      ),
    );

    expect((await service.check()).forceUpdate, isTrue);
  });

  test('same build and version is current', () async {
    final service = AppUpdateService(
      manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
      targetPlatform: TargetPlatform.iOS,
      packageInfoLoader: () async => package('0.2.0', '25'),
      client: MockClient(
        (_) async =>
            http.Response(manifest(latestBuild: 25, minimumBuild: 20), 200),
      ),
    );

    expect((await service.check()).hasUpdate, isFalse);
  });

  test('Android APK requires a valid SHA-256 and allowed HTTPS host', () async {
    const hash =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    final service = AppUpdateService(
      manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
      targetPlatform: TargetPlatform.android,
      packageInfoLoader: () async => package('0.1.19', '23'),
      client: MockClient(
        (_) async => http.Response(
          manifest(
            platform: 'android',
            destinationType: 'android_apk',
            destinationUrl: 'https://app.saidian.cc/Saydian.apk',
            sha256: hash,
          ),
          200,
        ),
      ),
    );

    final info = await service.check();
    expect(info.destinationType, AppUpdateDestinationType.androidApk);
    expect(info.sha256, hash);
  });

  test('Android store destination is accepted without an APK hash', () async {
    final service = AppUpdateService(
      manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
      targetPlatform: TargetPlatform.android,
      packageInfoLoader: () async => package('0.1.19', '23'),
      allowedDestinationHosts: const {'store.example.com'},
      client: MockClient(
        (_) async => http.Response(
          manifest(
            platform: 'android',
            destinationType: 'android_store',
            destinationUrl: 'https://store.example.com/saydian',
          ),
          200,
        ),
      ),
    );

    final info = await service.check();
    expect(info.destinationType, AppUpdateDestinationType.androidStore);
    expect(info.sha256, isNull);
  });

  test(
    'rejects missing APK hashes, wrong platforms and unsafe destinations',
    () async {
      Future<void> rejects(String value, TargetPlatform platform) async {
        final service = AppUpdateService(
          manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
          targetPlatform: platform,
          packageInfoLoader: () async => package('0.1.19', '23'),
          client: MockClient((_) async => http.Response(value, 200)),
        );
        await expectLater(service.check(), throwsA(isA<AppUpdateException>()));
      }

      await rejects(
        manifest(
          platform: 'android',
          destinationType: 'android_apk',
          destinationUrl: 'https://app.saidian.cc/Saydian.apk',
        ),
        TargetPlatform.android,
      );
      await rejects(manifest(platform: 'android'), TargetPlatform.iOS);
      await rejects(
        manifest(destinationUrl: 'https://example.invalid/app/id123'),
        TargetPlatform.iOS,
      );
      await rejects(
        manifest(destinationUrl: 'https://apps.apple.com/'),
        TargetPlatform.iOS,
      );
    },
  );

  test(
    '404, timeout and malformed JSON never create an update result',
    () async {
      AppUpdateService serviceWith(http.Client client) => AppUpdateService(
        manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
        targetPlatform: TargetPlatform.iOS,
        packageInfoLoader: () async => package('0.1.19', '23'),
        client: client,
        requestTimeout: const Duration(milliseconds: 5),
      );

      await expectLater(
        serviceWith(MockClient((_) async => http.Response('', 404))).check(),
        throwsA(isA<AppUpdateException>()),
      );
      await expectLater(
        serviceWith(
          MockClient((_) => Completer<http.Response>().future),
        ).check(),
        throwsA(isA<AppUpdateException>()),
      );
      await expectLater(
        serviceWith(
          MockClient((_) async => http.Response('not-json', 200)),
        ).check(),
        throwsA(isA<AppUpdateException>()),
      );
    },
  );

  test('automatic checks run once per successful 24 hour window', () async {
    final store = _MemoryUpdateCheckStore();
    var calls = 0;
    final service = AppUpdateService(
      manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
      targetPlatform: TargetPlatform.iOS,
      packageInfoLoader: () async => package('0.1.19', '23'),
      client: MockClient((_) async {
        calls++;
        return http.Response(manifest(), 200);
      }),
    );
    final coordinator = AppUpdateCoordinator(
      service,
      store: store,
      now: () => DateTime.utc(2026, 8, 29, 8),
    );

    expect(await coordinator.checkIfDue(), isNotNull);
    expect(await coordinator.checkIfDue(), isNull);
    expect(calls, 1);
  });

  test('failed automatic checks do not consume the 24 hour window', () async {
    final store = _MemoryUpdateCheckStore();
    final service = AppUpdateService(
      manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
      targetPlatform: TargetPlatform.iOS,
      packageInfoLoader: () async => package('0.1.19', '23'),
      client: MockClient((_) async => http.Response('', 503)),
    );
    final coordinator = AppUpdateCoordinator(service, store: store);

    await expectLater(
      coordinator.checkIfDue(),
      throwsA(isA<AppUpdateException>()),
    );
    expect(store.value, isNull);
  });

  test(
    'failed mandatory gate persistence does not consume the throttle window',
    () async {
      final store = _MemoryUpdateCheckStore()..failRequiredWrite = true;
      final service = AppUpdateService(
        manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
        targetPlatform: TargetPlatform.iOS,
        packageInfoLoader: () async => package('0.1.19', '19'),
        client: MockClient(
          (_) async =>
              http.Response(manifest(latestBuild: 25, minimumBuild: 20), 200),
        ),
      );

      await expectLater(
        AppUpdateCoordinator(service, store: store).checkIfDue(),
        throwsA(
          isA<AppUpdatePersistenceException>().having(
            (error) => error.info.forceUpdate,
            'mandatory info',
            isTrue,
          ),
        ),
      );
      expect(store.value, isNull);
    },
  );

  test('manual mandatory check exposes info when persistence fails', () async {
    final store = _MemoryUpdateCheckStore()..failRequiredWrite = true;
    final service = AppUpdateService(
      manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
      targetPlatform: TargetPlatform.iOS,
      packageInfoLoader: () async => package('0.1.19', '19'),
      client: MockClient(
        (_) async =>
            http.Response(manifest(latestBuild: 25, minimumBuild: 20), 200),
      ),
    );

    await expectLater(
      AppUpdateCoordinator(service, store: store).checkNow(),
      throwsA(isA<AppUpdatePersistenceException>()),
    );
  });

  test(
    'known mandatory update refreshes despite throttle and survives relaunch',
    () async {
      final store = _MemoryUpdateCheckStore();
      var calls = 0;
      AppUpdateService serviceForBuild(String build) => AppUpdateService(
        manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
        targetPlatform: TargetPlatform.iOS,
        packageInfoLoader: () async => package('0.1.19', build),
        client: MockClient((_) async {
          calls++;
          return http.Response(
            manifest(latestBuild: 25, minimumBuild: 24),
            200,
          );
        }),
      );
      final first = AppUpdateCoordinator(
        serviceForBuild('23'),
        store: store,
        now: () => DateTime.utc(2026, 8, 29, 8),
      );
      expect((await first.checkIfDue())?.forceUpdate, isTrue);
      expect(calls, 1);

      final relaunched = AppUpdateCoordinator(
        serviceForBuild('23'),
        store: store,
        now: () => DateTime.utc(2026, 8, 29, 9),
      );
      expect((await relaunched.checkIfDue())?.forceUpdate, isTrue);
      expect(
        calls,
        2,
        reason: 'a persisted gate must bypass throttling and revalidate online',
      );
    },
  );

  test('corrected manifest can clear a cached mandatory update', () async {
    final store = _MemoryUpdateCheckStore()
      ..value = DateTime.utc(2026, 8, 29, 8)
      ..required = AppUpdateInfo(
        currentVersion: '0.1.19',
        currentBuild: 23,
        latestVersion: '0.2.0',
        latestBuild: 25,
        minimumSupportedBuild: 24,
        destinationType: AppUpdateDestinationType.appStore,
        destinationUri: Uri.parse(
          'https://apps.apple.com/cn/app/saydian/id1234567890',
        ),
        releaseNotes: 'incorrect gate',
        publishedAt: DateTime.utc(2026, 8, 29),
      );
    var calls = 0;
    final service = AppUpdateService(
      manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
      targetPlatform: TargetPlatform.iOS,
      packageInfoLoader: () async => package('0.1.19', '23'),
      client: MockClient((_) async {
        calls++;
        return http.Response(manifest(latestBuild: 26, minimumBuild: 20), 200);
      }),
    );

    final result = await AppUpdateCoordinator(
      service,
      store: store,
      now: () => DateTime.utc(2026, 8, 29, 9),
    ).checkIfDue();

    expect(calls, 1);
    expect(result?.forceUpdate, isFalse);
    expect(store.required, isNull);
  });

  test(
    'known mandatory update fails closed when package metadata is unavailable',
    () async {
      final store = _MemoryUpdateCheckStore()
        ..required = AppUpdateInfo(
          currentVersion: '0.1.19',
          currentBuild: 19,
          latestVersion: '0.2.0',
          latestBuild: 25,
          minimumSupportedBuild: 20,
          destinationType: AppUpdateDestinationType.appStore,
          destinationUri: Uri.parse(
            'https://apps.apple.com/cn/app/saydian/id1234567890',
          ),
          releaseNotes: 'mandatory',
          publishedAt: DateTime.utc(2026, 8, 29),
        );
      final service = AppUpdateService(
        manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
        targetPlatform: TargetPlatform.iOS,
        packageInfoLoader: () =>
            Future<PackageInfo>.error(StateError('package plugin unavailable')),
      );

      final restored = await AppUpdateCoordinator(
        service,
        store: store,
      ).restoreRequiredUpdate();

      expect(restored?.forceUpdate, isTrue);
      expect(store.required, isNotNull);
    },
  );

  test(
    'persisted mandatory update clears after the installed build catches up',
    () async {
      final store = _MemoryUpdateCheckStore();
      final oldService = AppUpdateService(
        manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
        targetPlatform: TargetPlatform.iOS,
        packageInfoLoader: () async => package('0.1.19', '23'),
        client: MockClient(
          (_) async =>
              http.Response(manifest(latestBuild: 25, minimumBuild: 24), 200),
        ),
      );
      await AppUpdateCoordinator(oldService, store: store).checkIfDue();
      expect(store.required, isNotNull);

      final updatedService = AppUpdateService(
        manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
        targetPlatform: TargetPlatform.iOS,
        packageInfoLoader: () async => package('0.2.0', '25'),
        client: MockClient((_) async => http.Response(manifest(), 200)),
      );
      final relaunched = AppUpdateCoordinator(updatedService, store: store);
      expect(await relaunched.restoreRequiredUpdate(), isNull);
      expect(store.required, isNull);
    },
  );

  test(
    'persisted mandatory update is revalidated against platform and allowlist',
    () async {
      final store = _MemoryUpdateCheckStore()
        ..required = AppUpdateInfo(
          currentVersion: '0.1.19',
          currentBuild: 19,
          latestVersion: '0.2.0',
          latestBuild: 25,
          minimumSupportedBuild: 20,
          destinationType: AppUpdateDestinationType.appStore,
          destinationUri: Uri.parse('https://updates.invalid/app/id1234567890'),
          releaseNotes: 'unsafe cached value',
          publishedAt: DateTime.utc(2026, 8, 29),
        );
      final service = AppUpdateService(
        manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
        targetPlatform: TargetPlatform.iOS,
        packageInfoLoader: () async => package('0.1.19', '19'),
        client: MockClient((_) async => http.Response(manifest(), 200)),
      );

      expect(
        await AppUpdateCoordinator(
          service,
          store: store,
        ).restoreRequiredUpdate(),
        isNull,
      );
      expect(store.required, isNull);
    },
  );

  test('manifest rejects HTTPS downgrade and cross-origin redirects', () async {
    Future<void> rejects(Uri finalUri) async {
      final response = http.Response(
        manifest(),
        200,
        request: http.Request('GET', finalUri),
      );
      final service = AppUpdateService(
        manifestUri: Uri.parse('https://app.saidian.cc/app-update.json'),
        targetPlatform: TargetPlatform.iOS,
        packageInfoLoader: () async => package('0.1.19', '23'),
        client: MockClient((_) async => response),
      );
      await expectLater(service.check(), throwsA(isA<AppUpdateException>()));
    }

    await rejects(Uri.parse('http://app.saidian.cc/app-update.json'));
    await rejects(Uri.parse('https://cdn.invalid/app-update.json'));
  });

  test(
    'Android installer verifies the APK then invokes the system installer',
    () async {
      final bytes = List<int>.generate(256, (index) => index);
      final directory = await Directory.systemTemp.createTemp('saidian-apk-');
      addTearDown(() => directory.delete(recursive: true));
      const channel = MethodChannel('cc.saidian/update-test-success');
      MethodCall? invoked;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            invoked = call;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final installer = AndroidApkUpdateInstaller(
        isAndroid: true,
        channel: channel,
        temporaryDirectory: () async => directory,
        client: MockClient((_) async => http.Response.bytes(bytes, 200)),
      );
      final progress = <double>[];

      await installer.downloadAndInstall(
        _apkInfo(hash: sha256.convert(bytes).toString()),
        onProgress: progress.add,
      );

      expect(invoked?.method, 'installApk');
      final arguments = Map<Object?, Object?>.from(invoked?.arguments as Map);
      expect(File('${arguments['filePath']}').existsSync(), isTrue);
      expect(progress.last, 1);
    },
  );

  test('backend APK updates can install when the API omits SHA-256', () async {
    final bytes = List<int>.generate(64, (index) => index);
    final directory = await Directory.systemTemp.createTemp('saidian-api-apk-');
    addTearDown(() => directory.delete(recursive: true));
    const channel = MethodChannel('cc.saidian/update-test-no-hash');
    MethodCall? invoked;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          invoked = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final installer = AndroidApkUpdateInstaller(
      isAndroid: true,
      channel: channel,
      temporaryDirectory: () async => directory,
      client: MockClient((_) async => http.Response.bytes(bytes, 200)),
    );

    await installer.downloadAndInstall(_apkInfo());

    expect(invoked?.method, 'installApk');
  });

  test(
    'Android installer deletes corrupt, empty, and interrupted files',
    () async {
      Future<void> rejectsAndDeletes(http.Client client, String hash) async {
        final directory = await Directory.systemTemp.createTemp(
          'saidian-bad-apk-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final installer = AndroidApkUpdateInstaller(
          isAndroid: true,
          temporaryDirectory: () async => directory,
          client: client,
        );
        await expectLater(
          installer.downloadAndInstall(_apkInfo(hash: hash)),
          throwsA(isA<AppUpdateException>()),
        );
        final updateDirectory = Directory('${directory.path}/saidian_updates');
        final files = await updateDirectory.exists()
            ? await updateDirectory
                  .list()
                  .where((entry) => entry is File)
                  .toList()
            : const <FileSystemEntity>[];
        expect(files, isEmpty);
      }

      await rejectsAndDeletes(
        MockClient((_) async => http.Response.bytes([1, 2, 3], 200)),
        List.filled(64, '0').join(),
      );
      await rejectsAndDeletes(
        MockClient((_) async => http.Response.bytes(const <int>[], 200)),
        sha256.convert(const <int>[]).toString(),
      );
      await rejectsAndDeletes(
        _InterruptingClient(),
        sha256.convert([1, 2, 3]).toString(),
      );
    },
  );

  test('Android installer rejects unsafe final redirect URLs', () async {
    final bytes = [1, 2, 3];
    Future<void> rejects(Uri finalUri) async {
      final directory = await Directory.systemTemp.createTemp(
        'saidian-redirect-apk-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final installer = AndroidApkUpdateInstaller(
        isAndroid: true,
        temporaryDirectory: () async => directory,
        client: _FinalUrlClient(bytes, finalUri),
      );
      await expectLater(
        installer.downloadAndInstall(
          _apkInfo(hash: sha256.convert(bytes).toString()),
        ),
        throwsA(isA<AppUpdateException>()),
      );
    }

    await rejects(Uri.parse('http://app.saidian.cc/Saydian.apk'));
    await rejects(Uri.parse('https://cdn.invalid/Saydian.apk'));
  });

  test(
    'unknown-source denial is actionable and settings can be opened',
    () async {
      final bytes = [7, 8, 9];
      final directory = await Directory.systemTemp.createTemp(
        'saidian-source-',
      );
      addTearDown(() => directory.delete(recursive: true));
      const channel = MethodChannel('cc.saidian/update-test-permission');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'installApk') {
              throw PlatformException(code: 'UNKNOWN_SOURCES_DISABLED');
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final installer = AndroidApkUpdateInstaller(
        isAndroid: true,
        channel: channel,
        temporaryDirectory: () async => directory,
        client: MockClient((_) async => http.Response.bytes(bytes, 200)),
      );

      await expectLater(
        installer.downloadAndInstall(
          _apkInfo(hash: sha256.convert(bytes).toString()),
        ),
        throwsA(
          isA<AppUpdateException>().having(
            (error) => error.message,
            'message',
            contains('未知来源'),
          ),
        ),
      );
      await installer.openUnknownSourcesSettings();
      expect(calls, ['installApk', 'openUnknownSourcesSettings']);
    },
  );

  test('the production default checks the backend version API', () async {
    late Uri requestedUri;
    final service = AppUpdateService(
      targetPlatform: TargetPlatform.android,
      packageInfoLoader: () async => package('1.0.02', '1002'),
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({'code': 200, 'message': 'OK', 'data': null}),
          200,
        );
      }),
    );

    expect(service.isConfigured, isTrue);
    expect((await service.check()).hasUpdate, isFalse);
    expect(requestedUri.origin, 'https://app.saydian.cn');
    expect(requestedUri.path, '/api/v1/site/version');
  });
}

AppUpdateInfo _apkInfo({String? hash}) => AppUpdateInfo(
  currentVersion: '0.1.19',
  currentBuild: 23,
  latestVersion: '0.2.0',
  latestBuild: 25,
  minimumSupportedBuild: 20,
  destinationType: AppUpdateDestinationType.androidApk,
  destinationUri: Uri.parse('https://app.saidian.cc/Saydian.apk'),
  releaseNotes: 'test',
  publishedAt: DateTime.utc(2026, 8, 29),
  sha256: hash,
);

class _InterruptingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.error(StateError('interrupted')),
        200,
        contentLength: 3,
      );
}

class _FinalUrlClient extends http.BaseClient {
  _FinalUrlClient(this.bytes, this.finalUri);

  final List<int> bytes;
  final Uri finalUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.value(bytes),
        200,
        contentLength: bytes.length,
        request: http.Request('GET', finalUri),
      );
}

class _MemoryUpdateCheckStore implements AppUpdateCheckStore {
  DateTime? value;
  AppUpdateInfo? required;
  bool failRequiredWrite = false;

  @override
  Future<DateTime?> readLastSuccessfulCheck() async => value;

  @override
  Future<void> writeLastSuccessfulCheck(DateTime value) async {
    this.value = value;
  }

  @override
  Future<AppUpdateInfo?> readRequiredUpdate() async => required;

  @override
  Future<void> writeRequiredUpdate(AppUpdateInfo? value) async {
    if (failRequiredWrite) throw StateError('secure storage unavailable');
    required = value;
  }
}
