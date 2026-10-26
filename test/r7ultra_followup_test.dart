import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/pages.dart';

class _Controller extends Fake implements AppController {
  final queries = <(String?, String?)>[];
  final mapRequests = <List<SportRoutePoint>>[];
  bool failMap = false;
  @override
  bool get isGlobalEdition => true;
  @override
  Future<void> loadOrders([int? status]) =>
      throw StateError('V1 orders forbidden');
  @override
  Future<List<Map<String, Object?>>> loadGlobalShopOrders({
    String? status,
    String? group,
  }) async {
    queries.add((status, group));
    return [];
  }

  @override
  Future<Map<String, Object?>> loadGlobalCommerceCapabilities() async => {};
  @override
  Future<Uint8List?> loadSportRouteMap(List<SportRoutePoint> points) async {
    mapRequests.add(points);
    if (failMap) throw StateError('offline');
    return null;
  }
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

SportRoutePoint _point(double offset) => SportRoutePoint(
  latitude: 30 + offset,
  longitude: 120 + offset,
  recordedAt: DateTime.utc(2026, 10, 26),
);

void main() {
  for (final entry in <int?, (String?, String?)>{
    null: (null, null),
    0: ('PENDING_PAYMENT', null),
    1: (null, 'pending_shipment'),
    2: ('SHIPPED', null),
    3: ('COMPLETED', null),
    -1: (null, 'after_sales'),
  }.entries) {
    testWidgets('legacy entry routes global order filter ${entry.key} to V2', (
      tester,
    ) async {
      final controller = _Controller();
      await _pump(
        tester,
        OrdersPage(controller: controller, initialStatus: entry.key),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-shop-orders-page')), findsOneWidget);
      expect(controller.queries, [entry.value]);
      expect(tester.takeException(), isNull);
    });
  }

  test('missing sport metrics stay absent across persistence', () {
    final record = SportRecord.fromMap({
      'id': 'local:test',
      'mode': 'indoor_running',
      'durationSeconds': 40,
    });
    for (final key in ['distanceKm', 'calories', 'steps', 'heartRate']) {
      expect(record.missingMetrics, contains(key));
      expect(record.toMap().containsKey(key), isFalse);
      expect(SportRecord.fromMap(record.toMap()).missingMetrics, contains(key));
    }
    expect(record.paceSecondsPerKm, isNull);
    final realZero = SportRecord.fromMap({
      ...record.toMap(),
      'calories': 0,
      'missingMetrics': [],
    });
    expect(realZero.missingMetrics, isNot(contains('calories')));
    expect(realZero.toMap()['calories'], 0);
  });

  testWidgets('map snapshots mutable route and bounds refresh requests', (
    tester,
  ) async {
    final controller = _Controller();
    final points = [_point(0), _point(.01)];
    Widget view() => SportRoutePreview(
      controller: controller,
      points: points,
      distanceKm: 1,
    );
    await _pump(tester, view());
    await tester.pumpAndSettle();
    expect(controller.mapRequests, hasLength(1));
    expect(find.textContaining('Web 服务 Key'), findsOneWidget);
    points.add(_point(.02));
    await _pump(tester, view());
    expect(controller.mapRequests.first, hasLength(2));
    await tester.pump(const Duration(seconds: 9));
    expect(controller.mapRequests, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(controller.mapRequests, hasLength(2));
    expect(controller.mapRequests.last, hasLength(3));
    controller.failMap = true;
    await tester.tap(find.byKey(const Key('sport-route-map-retry')));
    await tester.pumpAndSettle();
    expect(find.textContaining('地图加载失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
