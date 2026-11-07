import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saydian_app/services/app_distribution.dart';
import 'package:saydian_app/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Play channel does not change direct Android or iPhone updates', () {
    expect(
      AppDistribution.usesGooglePlay(
        TargetPlatform.android,
        distributionChannel: 'direct',
      ),
      isFalse,
    );
    expect(
      AppDistribution.usesGooglePlay(
        TargetPlatform.iOS,
        distributionChannel: 'google-play',
      ),
      isFalse,
    );
    expect(
      () => AppDistribution.usesGooglePlay(
        TargetPlatform.android,
        distributionChannel: 'unknown',
      ),
      throwsArgumentError,
    );
  });

  test(
    'Play startup drops a prior APK gate without checking its server',
    () async {
      var requests = 0;
      final service = GlobalAppUpdateService(
        distributionChannel: 'google-play',
        targetPlatform: TargetPlatform.android,
        client: MockClient((_) async {
          requests++;
          return http.Response('', 500);
        }),
        packageInfoLoader: () async => _package(),
      );
      final store = _UpdateStore()..required = _oldApkUpdate();
      final coordinator = AppUpdateCoordinator(service, store: store);
      expect(store.required!.forceUpdate, isTrue);
      expect(await coordinator.checkIfDue(), isNull);
      expect(store.required, isNull);
      expect(store.requiredWrites, 1);
      expect(store.successfulCheckWrites, 0);
      expect(service.isConfigured, isFalse);
      expect(requests, 0);
      await expectLater(service.check(), throwsA(isA<AppUpdateException>()));
      expect(requests, 0);
    },
  );

  test(
    'Play manual and legacy destination actions open only this listing',
    () async {
      final launched = <Uri>[];
      final service = GlobalAppUpdateService(
        distributionChannel: 'google-play',
        targetPlatform: TargetPlatform.android,
        packageInfoLoader: () async => _package(),
        storeLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      );
      await service.openStoreManagedUpdates();
      await service.openDestination(_oldApkUpdate());
      expect(
        launched.map((uri) => uri.toString()),
        everyElement(
          'https://play.google.com/store/apps/details?id=cn.saydian.ring',
        ),
      );
      expect(launched, hasLength(2));
      expect(service.validatePersisted(_oldApkUpdate()), isFalse);
    },
  );

  test('Play update rejects another product before launching a page', () async {
    var launches = 0;
    final service = AppUpdateService(
      distributionChannel: 'google-play',
      targetPlatform: TargetPlatform.android,
      packageInfoLoader: () async => _package('cn.saydian.app.global'),
      storeLauncher: (_) async {
        launches++;
        return true;
      },
    );
    await expectLater(
      service.openStoreManagedUpdates(),
      throwsA(isA<AppUpdateException>()),
    );
    expect(launches, 0);
  });

  test(
    'an unavailable Play listing reports failure instead of success',
    () async {
      final service = AppUpdateService(
        distributionChannel: 'google-play',
        targetPlatform: TargetPlatform.android,
        packageInfoLoader: () async => _package(),
        storeLauncher: (_) async => false,
      );
      await expectLater(
        service.openStoreManagedUpdates(),
        throwsA(isA<AppUpdateException>()),
      );
    },
  );

  test(
    'Play APK action stops before network, files, or native installer',
    () async {
      var requests = 0;
      var fileAccesses = 0;
      var nativeCalls = 0;
      const channel = MethodChannel('say-ring/play-update-test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            nativeCalls++;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final installer = AndroidApkUpdateInstaller.global(
        distributionChannel: 'google-play',
        isAndroid: true,
        channel: channel,
        temporaryDirectory: () async {
          fileAccesses++;
          throw StateError('Play must not touch the APK cache');
        },
        client: MockClient((_) async {
          requests++;
          return http.Response('', 500);
        }),
      );
      await expectLater(
        installer.downloadAndInstall(_oldApkUpdate()),
        throwsA(isA<AppUpdateException>()),
      );
      expect([requests, fileAccesses, nativeCalls], [0, 0, 0]);
    },
  );
}

PackageInfo _package([String package = 'cn.saydian.ring']) => PackageInfo(
  appName: 'Say Ring',
  packageName: package,
  version: '1.0.12',
  buildNumber: '1267',
);

AppUpdateInfo _oldApkUpdate() => AppUpdateInfo(
  currentVersion: '1.0.11',
  currentBuild: 1266,
  latestVersion: '9.0.0',
  latestBuild: 9999,
  minimumSupportedBuild: 9999,
  destinationType: AppUpdateDestinationType.androidApk,
  destinationUri: Uri.parse(
    'https://app.saydian.cn/global/down/files/Say-Ring-9999.apk',
  ),
  releaseNotes: '',
  publishedAt: DateTime.utc(2026, 11, 7),
  sha256: List.filled(64, 'a').join(),
);

class _UpdateStore implements AppUpdateCheckStore {
  AppUpdateInfo? required;
  var requiredWrites = 0;
  var successfulCheckWrites = 0;

  @override
  Future<AppUpdateInfo?> readRequiredUpdate() async => required;

  @override
  Future<void> writeRequiredUpdate(AppUpdateInfo? value) async {
    requiredWrites++;
    required = value;
  }

  @override
  Future<DateTime?> readLastSuccessfulCheck() async => null;

  @override
  Future<void> writeLastSuccessfulCheck(DateTime value) async {
    successfulCheckWrites++;
  }
}
