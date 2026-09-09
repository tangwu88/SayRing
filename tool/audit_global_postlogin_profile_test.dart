// Read-only host audit probes, not acceptance/regression gates. These assertions
// deliberately document current defects; run explicitly, never against a server.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';

const prefix = '/global/api/saydian-app/v2';
const profile = <String, Object?>{
  'id': 'synthetic-a',
  'nickname': 'Synthetic old profile',
  'gender': 'male',
  'birthday': '1990-01-01',
  'heightCm': 170,
  'weightKg': 65,
};
Session owner(String id) => Session(
  accessToken: 'synthetic-$id',
  refreshToken: '',
  expiresAt: DateTime.utc(2099),
  memberId: id,
  displayName: 'Synthetic',
  accountKey: 'global:member:$id',
);
http.Response response(Object? data, {int status = 200}) => http.Response(
  jsonEncode({'code': status, 'data': data}),
  status,
  headers: {'content-type': 'application/json'},
);

class NoWearable extends Fake implements WearableBridge {}

AppController controllerFor(MemorySessionVault vault, SaydianApi api) =>
    AppController(vault, api, MemoryHealthStore(), NoWearable())
      ..session = owner('a');
Future<bool> save(AppController controller, {String? avatar}) =>
    controller.saveMemberProfile(
      nickname: 'Synthetic old profile',
      gender: 1,
      birthday: '1990-01-01',
      height: 170,
      weight: 65,
      avatarFilePath: avatar,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'AUDIT P1: successful PUT plus failed GET still returns saved=true',
    () async {
      final vault = MemorySessionVault();
      await vault.writeSession(owner('a'));
      final requests = <String>[];
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          requests.add(request.method);
          expect(request.url.path, '$prefix/members/me');
          return request.method == 'PUT'
              ? response(profile)
              : response(null, status: 500);
        }),
      );
      final controller = controllerFor(vault, api);
      addTearDown(controller.dispose);
      final saved = await save(controller);
      expect(requests, ['PUT', 'GET']);
      expect(
        saved,
        isTrue,
        reason: 'Observed defect: readback failure is swallowed.',
      );
      expect(controller.errorMessage, isNotNull);
      expect(controller.memberProfile, isEmpty);
    },
  );

  test(
    'AUDIT P1: late avatar upload writes old profile using new account token',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'saydian-profile-audit-',
      );
      final avatar = File(
        '${directory.path}${Platform.pathSeparator}synthetic.png',
      );
      await avatar.writeAsBytes([137, 80, 78, 71]);
      addTearDown(() async {
        expect(
          directory.parent.absolute.path,
          Directory.systemTemp.absolute.path,
        );
        expect(
          directory.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('saydian-profile-audit-'),
          isTrue,
        );
        await directory.delete(recursive: true);
      });
      final vault = MemorySessionVault();
      await vault.writeSession(owner('a'));
      final started = Completer<void>();
      final upload = Completer<http.Response>();
      String? putBearer;
      String? putNickname;
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          if (request.url.path == '$prefix/files') {
            started.complete();
            return upload.future;
          }
          if (request.url.path == '$prefix/auth/logout') {
            return response({'loggedOut': true});
          }
          expect(request.url.path, '$prefix/members/me');
          if (request.method == 'PUT') {
            putBearer = request.headers['authorization'];
            putNickname =
                (jsonDecode(request.body) as Map)['nickname'] as String;
          }
          return response({...profile, 'id': 'b'});
        }),
      );
      final controller = controllerFor(vault, api);
      addTearDown(controller.dispose);
      final saving = save(controller, avatar: avatar.path);
      await started.future;
      await controller.logout();
      await vault.writeSession(owner('b'));
      controller.session = owner('b');
      upload.complete(
        response({
          'url': 'https://app.saydian.cn$prefix/files/synthetic-avatar',
        }),
      );
      expect(await saving, isTrue);
      expect(
        putBearer == 'Bearer synthetic-b',
        isTrue,
        reason:
            'Observed defect: the next protected request re-reads the new vault session.',
      );
      expect(putNickname == profile['nickname'], isTrue);
    },
  );

  testWidgets(
    'AUDIT P2: profile form accepts height 275 before server maximum 250 rejects it',
    (tester) async {
      final vault = MemorySessionVault();
      await vault.writeSession(owner('a'));
      num? submittedHeight;
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((request) async {
          expect(request.url.path, '$prefix/members/me');
          if (request.method == 'PUT') {
            submittedHeight =
                (jsonDecode(request.body) as Map)['heightCm'] as num;
            return response(null, status: 400);
          }
          return response(profile);
        }),
      );
      final controller = controllerFor(vault, api);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ProfileEditPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('profile-height')), '275');
      tester.testTextInput.hide();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-save')),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('profile-save')),
        warnIfMissed: true,
      );
      await tester.pumpAndSettle();
      expect(
        submittedHeight,
        275,
        reason:
            'Observed mismatch: client allows up to 300, server rejects over 250.',
      );
      expect(controller.errorMessage, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'AUDIT P2: unit selection is not persisted across controllers using the same vault',
    () async {
      final vault = MemorySessionVault();
      final api = GlobalSaydianApiClient(
        vault,
        client: MockClient((_) async => response(null)),
      );
      final first = controllerFor(vault, api);
      addTearDown(first.dispose);
      first.setUnits(distance: '英里', temperature: '华氏度（℉）');
      final restarted = controllerFor(vault, api);
      addTearDown(restarted.dispose);
      expect(first.distanceUnit, '英里');
      expect(restarted.distanceUnit == first.distanceUnit, isFalse);
      expect(restarted.temperatureUnit == first.temperatureUnit, isFalse);
    },
  );
}
