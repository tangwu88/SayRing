import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/pages.dart';

class _Api extends Fake implements SaydianApi {}

class _Ring extends Fake implements WearableBridge {}

class _Ui extends Fake implements AppController {
  (int, double, int)? saved;
  @override
  int get stepGoal => 10000;
  @override
  double get distanceGoal => 6;
  @override
  int get calorieGoal => 1234;
  @override
  bool get isBusy => false;
  @override
  Future<bool> saveActivityGoals({
    required int steps,
    required double distance,
    required int calories,
  }) async {
    saved = (steps, distance, calories);
    return true;
  }

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void cancelPendingSportStart(SportMode mode) {}
  @override
  SportMode? get activeSport => SportMode.walking;
  @override
  bool get sportPaused => false;
  @override
  bool get sportConnectionInterrupted => false;
  @override
  bool get isWellnessOnly => false;
  @override
  bool get isSportStarting => false;
  @override
  DeviceInfo? get connectedDevice =>
      const DeviceInfo(id: 'qring:test', name: 'R8');
  @override
  DeviceCapabilities? get capabilities => const DeviceCapabilities(metrics: {});
  @override
  Map<String, num> get liveSportData => {
    'steps': 30,
    'distanceMeters': 25,
    'heartRate': 88,
    'calories': 99,
  };
  @override
  String get distanceUnit => 'km';
}

Widget host(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets(
    'visible goals exclude calories while save retains its existing value',
    (tester) async {
      final app = _Ui();
      await tester.pumpWidget(host(GoalSettingsPage(controller: app)));
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.textContaining('热量'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(app.saved, (10000, 6.0, 1234));
    },
  );
  testWidgets('sport live cards keep genuine metrics and omit calorie text', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(SportSessionPage(controller: _Ui(), mode: SportMode.walking)),
    );
    expect(find.textContaining('热量'), findsNothing);
    expect(find.textContaining('kcal'), findsNothing);
    expect(find.text('88 bpm'), findsOneWidget);
    expect(find.textContaining('30'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('sport details do not expose retained calorie history', (
    tester,
  ) async {
    final record = SportRecord(
      id: 'retained',
      mode: SportMode.walking,
      startedAt: DateTime(2026, 11, 7),
      durationSeconds: 120,
      distanceKm: 1,
      calories: 99,
      steps: 100,
      heartRate: 88,
    );
    await tester.pumpWidget(
      host(SportRecordDetailPage(controller: _Ui(), record: record)),
    );
    expect(find.textContaining('热量'), findsNothing);
    expect(find.textContaining('千卡'), findsNothing);
    expect(record.toMap()['calories'], 99);
  });
  for (final name in ['R7 Ultra', 'SD-RING-R7 Ultra', 'r7 pro', 'R8']) {
    test('HRV availability follows negative R7 model restriction: $name', () {
      final app =
          AppController(
              MemorySessionVault(),
              _Api(),
              MemoryHealthStore(),
              _Ring(),
            )
            ..connectedDevice = DeviceInfo(
              id: '${name == 'R8' ? 'qring' : 'coolwear'}:test',
              name: name,
            )
            ..capabilities = const DeviceCapabilities(
              metrics: {HealthMetric.hrv, HealthMetric.heartRate},
              manualMetrics: {HealthMetric.hrv, HealthMetric.heartRate},
            );
      expect(app.shouldShowHealthMetric(HealthMetric.hrv), name == 'R8');
      expect(app.canMeasureHealthMetric(HealthMetric.hrv), name == 'R8');
      expect(app.shouldShowHealthMetric(HealthMetric.heartRate), isTrue);
      app.dispose();
    });
  }
}
