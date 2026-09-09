// Explicit host-only AUDIT probes, not passing security acceptance gates.
// The defect assertions document the current successful-200 late-read behavior.
// No runtime method is overridden: only HTTP, storage, and hardware are fakes.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/health_reports_page.dart';

const _prefix = '/global/api/saydian-app/v2/';
const _period = {'from': '2026-09-01', 'to': '2026-09-10'};
const _completeness = {
  'validRecordCount': 0,
  'distinctDays': 0,
  'metricCount': 0,
};
const _dashboardPaths = {
  'health/profile',
  'health/reports/eligibility',
  'billing/entitlements',
  'billing/offers',
  'health/reports',
};

http.Response _ok(Object? data) => http.Response(
  jsonEncode({'code': 200, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _profile(String owner) => {
  'memberId': 'synthetic-owner-$owner',
  'period': _period,
  'dataCompleteness': _completeness,
  'metrics': <Object?>[],
  'devices': <Object?>[],
  'activeWarningCount': 0,
  'analysisConsent': {'granted': false},
};

class _NoHardware extends Fake implements WearableBridge {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Hardware must not be used by this host-only probe.');
  }
}

class _Harness {
  _Harness({this.holdProfile = true}) {
    api = GlobalSaydianApiClient(
      vault,
      baseUri: Uri.parse('https://app.saydian.cn'),
      client: MockClient(_respond),
    );
    controller = AppController(vault, api, MemoryHealthStore(), wearable);
  }

  final bool holdProfile;
  final vault = MemorySessionVault();
  final wearable = _NoHardware();
  late final GlobalSaydianApiClient api;
  late final AppController controller;
  final profileStarted = Completer<void>();
  final profileResponse = Completer<http.Response>();
  final requests = <({String method, String path, String? owner})>[];
  int successfulResponses = 0;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.dispose();
  }

  Future<http.Response> _respond(http.Request request) async {
    expectSync(request.url.origin, 'https://app.saydian.cn');
    expectSync(request.url.path.startsWith(_prefix), isTrue);
    expectSync(request.followRedirects, isFalse);
    final path = request.url.path.substring(_prefix.length);
    final authorization = request.headers['authorization'];
    final owner = switch (authorization) {
      'Bearer synthetic-access-a' => 'a',
      'Bearer synthetic-access-b' => 'b',
      null => null,
      _ => throw StateError('Unexpected synthetic authorization.'),
    };
    requests.add((method: request.method, path: path, owner: owner));

    Object? data;
    if (request.method == 'POST' && path == 'auth/login') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final loginOwner = switch (body['username']) {
        'a@example.invalid' => 'a',
        'b@example.invalid' => 'b',
        _ => throw StateError('Only two synthetic accounts are allowed.'),
      };
      data = {
        'accessToken': 'synthetic-access-$loginOwner',
        'refreshToken': 'synthetic-refresh-$loginOwner',
        'expiresAt': '2099-01-01T00:00:00Z',
        'member': {
          'id': 'synthetic-owner-$loginOwner',
          'nickname': 'Synthetic $loginOwner',
        },
      };
    } else {
      expectSync(
        request.method,
        'GET',
        reason: 'No business writes are allowed.',
      );
      if (path != 'billing/offers') expectSync(owner, isNotNull);
      if (path == 'health/profile' && owner == 'a' && holdProfile) {
        if (!profileStarted.isCompleted) profileStarted.complete();
        final response = await profileResponse.future;
        expectSync(response.statusCode, 200);
        successfulResponses++;
        return response;
      }
      data = switch (path) {
        'care/relationships' || 'health/warning-rules' => <Object?>[],
        'health/warnings' || 'billing/offers' => {'items': <Object?>[]},
        'notifications/unread-count' => {'count': 0},
        'members/me' => {
          'id': 'synthetic-owner-$owner',
          'nickname': 'Synthetic $owner',
        },
        'members/me/goals' => {
          'steps': 10000,
          'caloriesKcal': 800,
          'distanceMeters': 6000,
        },
        'health/profile' => _profile(owner!),
        'health/reports/eligibility' => {
          'eligible': false,
          'period': _period,
          'dataCompleteness': _completeness,
          'minimumDistinctDays': 3,
          'missing': ['Synthetic $owner eligibility marker'],
          'consentRequired': true,
          'availableCredits': 0,
        },
        'billing/entitlements' => {
          'availableReportCredits': 0,
          'activeMembership': null,
        },
        'health/reports' => {
          'items': [
            {
              'id': 'synthetic-report-$owner',
              'status': 'failed',
              'period': _period,
              'dataCompleteness': _completeness,
              'freePreview': {
                'title': 'Synthetic $owner report marker',
                'summary': 'Synthetic audit fixture only',
              },
              'aiGenerated': false,
              'needsPayment': false,
            },
          ],
        },
        _ => throw StateError('Unexpected mock route: $path'),
      };
    }
    successfulResponses++;
    return _ok(data);
  }

  Future<void> login(String owner) async {
    // Use the production controller/API authentication transition, including
    // vault writes and generation advance. Never assign controller.session.
    expect(
      await controller.login('$owner@example.invalid', 'Synthetic-password'),
      isTrue,
    );
    expect(controller.session?.memberId, 'synthetic-owner-$owner');
    expect((await vault.readSession())?.memberId, 'synthetic-owner-$owner');
  }

  void assertRequestsOwnedByA() {
    final reads = requests.where((r) => _dashboardPaths.contains(r.path));
    expect(reads.map((r) => r.path).toSet(), _dashboardPaths);
    expect(reads, hasLength(5));
    expect(reads.every((r) => r.method == 'GET'), isTrue);
    expect(
      reads
          .where((r) => r.path != 'billing/offers')
          .every((r) => r.owner == 'a'),
      isTrue,
    );
  }

  void releaseProfile() => profileResponse.complete(_ok(_profile('a')));

  void assertMockOnlySuccessfulPath() {
    expect(requests.where((r) => r.path == 'auth/refresh'), isEmpty);
    expect(successfulResponses, requests.length);
    expect(wearable.calls, 0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'AUDIT control: unchanged owner receives its dashboard via real client',
    () async {
      final harness = _Harness(holdProfile: false);
      addTearDown(harness.dispose);
      await harness.login('a');
      final dashboard = await harness.controller.loadHealthReportDashboard();
      expect(dashboard.profile.memberId, 'synthetic-owner-a');
      expect(
        dashboard.reports.single.previewTitle,
        'Synthetic a report marker',
      );
      harness.assertRequestsOwnedByA();
      harness.assertMockOnlySuccessfulPath();
    },
  );

  test(
    'AUDIT H02: late successful A dashboard is returned after real B login',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await harness.login('a');
      final pending = harness.controller.loadHealthReportDashboard();
      await harness.profileStarted.future.timeout(const Duration(seconds: 5));
      await harness.login('b');
      harness.assertRequestsOwnedByA();
      harness.releaseProfile();
      final dashboard = await pending.timeout(const Duration(seconds: 5));

      // Intentionally documents the defect, NOT expected secure behavior.
      expect(harness.controller.session?.memberId, 'synthetic-owner-b');
      expect(
        (await harness.vault.readSession())?.memberId,
        'synthetic-owner-b',
      );
      expect(dashboard.profile.memberId, 'synthetic-owner-a');
      expect(
        dashboard.reports.single.previewTitle,
        'Synthetic a report marker',
      );
      final fresh = await harness.controller.loadHealthReportDashboard();
      expect(fresh.profile.memberId, 'synthetic-owner-b');
      expect(fresh.reports.single.previewTitle, 'Synthetic b report marker');
      harness.assertMockOnlySuccessfulPath();
      debugPrint(
        '[SaydianHealthAudit] {"case":"H02-controller",'
        '"reproduced":true,"currentOwnerPreserved":true,'
        '"lateOldOwnerDashboardReturned":true,"freshReadUsesNewOwner":true,'
        '"allResponses200":true}',
      );
    },
  );

  testWidgets(
    'AUDIT H02: retained health page renders A response in B session',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await harness.login('a');
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: HealthProfilePage(controller: harness.controller),
        ),
      );
      await tester.pump();
      expect(harness.profileStarted.isCompleted, isTrue);
      final retainedPage = tester.element(find.byType(HealthProfilePage));

      await harness.login('b');
      harness.assertRequestsOwnedByA();
      harness.releaseProfile();
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(HealthProfilePage)),
        same(retainedPage),
      );
      expect(harness.controller.session?.memberId, 'synthetic-owner-b');
      await tester.scrollUntilVisible(
        find.text('Synthetic a report marker'),
        250,
      );
      expect(
        find.text('Synthetic a report marker').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Synthetic b report marker'), findsNothing);
      harness.assertMockOnlySuccessfulPath();
      debugPrint(
        '[SaydianHealthAudit] {"case":"H02-retained-page",'
        '"reproduced":true,"currentOwnerPreserved":true,'
        '"oldOwnerReportVisible":true,"samePageMounted":true}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
      await tester.pump();
    },
  );
}
