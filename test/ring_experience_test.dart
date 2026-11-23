import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/ring_experience.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/notification_models.dart';
import 'package:saydian_app/services/notification_route_service.dart';
import 'package:saydian_app/services/ring_firmware.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/cardiovascular_trends_page.dart';

class _OfflineRingApi extends Fake implements SaydianApi, GlobalAccountApi {}

class _DisconnectedRing extends Fake implements WearableBridge {}

void main() {
  for (final (language, saveLabel) in [
    ('zh', '保存到本机'),
    ('en', 'Save on this phone'),
  ]) {
    testWidgets('reference reading works offline at 2x text ($language)', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final controller = AppController(
        MemorySessionVault(),
        _OfflineRingApi(),
        MemoryHealthStore(),
        _DisconnectedRing(),
        wellnessOnly: true,
      );
      addTearDown(controller.dispose);
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CardiovascularTrendsPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record-pressure-reference')));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      expect(tester.widget<TextField>(fields.first).controller?.text, isEmpty);
      expect(tester.widget<TextField>(fields.last).controller?.text, isEmpty);
      await tester.enterText(fields.first, '121');
      await tester.enterText(fields.last, '79');
      await tester.tap(find.text(saveLabel));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final now = DateTime.now();
      final local = await controller.loadPressureTrend(
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      );
      expect(local.map((row) => (row.systolic, row.diastolic)), [(121, 79)]);
      await tester.pumpAndSettle();
      final chart = find.byType(LineChart);
      if (chart.evaluate().isEmpty) {
        final labels = tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data);
        fail('Missing trend chart after saving a valid reading. $labels');
      }
      final graph = tester.widget<LineChart>(chart);
      expect(graph.data.lineBarsData.map((line) => line.spots.length), [1, 1]);
      expect(graph.data.lineBarsData.map((line) => line.spots.single.y), [
        121,
        79,
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('the first-party host and exact routes are required for care links', () {
    final invite = RingLink.parse(
      Uri.parse(
        'https://app.saydian.cn/global/say-ring/invite#ABCDEFGHJKLMNPQRSTUV',
      ),
    );
    expect(invite?.type, RingLinkType.invite);
    expect(invite?.token, 'ABCDEFGHJKLMNPQRSTUV');
    expect(
      RingLink.parse(
        Uri.parse(
          'https://app.saydian.cn.evil.example/global/say-ring/invite#ABCDEFGHJKLMNPQRSTUV',
        ),
      ),
      isNull,
    );
    expect(
      RingLink.parse(
        Uri.parse(
          'https://app.saydian.cn/global/say-ring/share#${newRingShareToken()}',
        ),
      ),
      isNull,
    );
    expect(
      RingLink.parse(
        Uri.parse(
          'https://app.saydian.cn/global/say-ring/invite?code=ABCDEFGHJKLMNPQRSTUV',
        ),
      ),
      isNull,
    );
  });

  test(
    'reference readings require a real pair and three different days per comparison',
    () {
      expect(PressureSample.validPair(75, 81), isFalse);
      expect(PressureSample.validPair(null, 81), isFalse);
      expect(PressureSample.validPair(125, 81), isTrue);
      final start = DateTime(2026, 11, 1);
      PressureSample entry(int offset, int upper) => PressureSample(
        at: ringAddDays(start, offset),
        systolic: upper,
        diastolic: 80,
        source: 'reference',
      );
      final previous = ringAddDays(start, -7);
      final rows = [
        entry(-7, 121),
        entry(-5, 121),
        entry(0, 120),
        entry(0, 140),
        entry(2, 120),
        entry(4, 120),
      ];
      expect(pressureChange(pressureDays(rows), start, previous), isNull);
      final samples = pressureDays([...rows, entry(-3, 121)]);
      final comparison = pressureChange(samples, start, previous);
      expect(comparison?.current, 3);
      expect(comparison?.previous, 3);
      expect(samples.singleWhere((row) => row.date == start).count, 2);
      expect(comparison?.systolic, closeTo(2.33, .02));
    },
  );

  test('ring notification route requires a well-formed identifier', () {
    const router = NotificationRouteService();
    const id = 'bbdd9988-abcd-abcd-abcd-123456789012';
    final now = DateTime(2026, 11, 24);
    final known = NotificationEvent.tryParse({
      'event_id': 'ring-care:$id',
      'event_type': 'system',
      'entity_id': id,
      'created_at': now.toUtc().toIso8601String(),
      'source': 'server',
    })!;
    expect(
      router.resolve(known).target,
      NotificationRouteTarget.ringCareInteraction,
    );
    expect(
      ringCareRelationshipFromLink(
        'https://app.saydian.cn/care/interactions/$id',
      ),
      isNull,
    );
  });

  test(
    'firmware manifest signature, expiry and hardware must all match',
    () async {
      final ed = Ed25519();
      final key = await ed.newKeyPair();
      final pub = await key.extractPublicKey();
      final now = DateTime.utc(2026, 11, 24);
      const device = RingFirmwareIdentity(
        platform: 'ios',
        transport: 'qring',
        model: 'R8',
        hardware: 'labA',
        version: '1.0',
        battery: 90,
      );
      final body = utf8.encode(
        jsonEncode({
          ...device.query(1318),
          'product': 'say-ring',
          'id': '24d0b7d2-0214-4131-953f-c2e389dbd101',
          'version': '1.1',
          'sha256': List.filled(64, '1').join(),
          'bytes': 3,
          'minBattery': 30,
          'minBuild': 1318,
          'expiresAt': now.add(const Duration(minutes: 8)).toIso8601String(),
        }),
      );
      final signature = await ed.sign(body, keyPair: key);
      final envelope = <String, Object?>{
        'available': true,
        'payload': base64Url.encode(body),
        'signature': base64Url.encode(signature.bytes),
      };
      Future<RingFirmwarePackage?> verify(
        RingFirmwareIdentity identity,
        DateTime clock,
      ) => RingFirmwarePackage.verify(
        envelope: envelope,
        device: identity,
        build: 1318,
        encodedPublicKey: base64Url.encode(pub.bytes),
        now: clock,
      );
      expect((await verify(device, now))?.version, '1.1');
      const other = RingFirmwareIdentity(
        platform: 'ios',
        transport: 'qring',
        model: 'R8',
        hardware: 'labB',
        version: '1.0',
        battery: 90,
      );
      await expectLater(verify(other, now), throwsFormatException);
      await expectLater(
        verify(device, now.add(const Duration(minutes: 9))),
        throwsFormatException,
      );
      envelope['signature'] = base64Url.encode(List.filled(64, 0));
      await expectLater(verify(device, now), throwsFormatException);
    },
  );
}
