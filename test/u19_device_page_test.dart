import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/ui/u19_device_page.dart';

class _Controller extends ChangeNotifier implements AppController {
  int writes = 0;
  @override
  DeviceInfo? connectedDevice = const DeviceInfo(
    id: 'urion:test-watch',
    name: 'U19S',
  );
  @override
  String get homeHealthCardOwner => 'synthetic-owner';
  @override
  Map<DeviceFeature, Map<String, Object?>> get deviceFeatureData => {};
  @override
  FeatureAvailability availabilityFor(DeviceFeature feature) =>
      const FeatureAvailability(FeatureAvailabilityStatus.ready);
  @override
  Future<Map<String, Object?>> readDeviceFeature(DeviceFeature feature) async =>
      {
        if (feature == DeviceFeature.healthMonitoring) ...{
          'heartRate': false,
          'bloodOxygen': true,
          'dynamicBloodPressure': {
            'enabled': false,
            'startHour': 8,
            'dayIntervalMinutes': 60,
            'nightIntervalMinutes': 60,
          },
        },
        if (feature == DeviceFeature.basicSettings) ...{
          'is24Hour': true,
          'age': 36,
          'heightCm': 170,
          'weightKg': 65,
          'stepGoal': 6000,
          'gender': 0,
        },
        if (feature == DeviceFeature.screenDisplay) 'durationSeconds': 8,
        if (feature == DeviceFeature.u19Pulse)
          'pulse': {'bloodStasis': 3, 'qiBlood': 4, 'dampness': 5},
      };
  @override
  Future<bool> writeDeviceFeature(
    DeviceFeature feature,
    Map<String, Object?> values,
  ) async {
    writes++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final locale in [const Locale('en'), const Locale('zh', 'Hans')]) {
    for (final feature in [
      DeviceFeature.basicSettings,
      DeviceFeature.healthMonitoring,
      DeviceFeature.screenDisplay,
      DeviceFeature.u19Pulse,
      DeviceFeature.findWatch,
    ]) {
      testWidgets(
        'U19 ${feature.wireName} is read-only on open and readable at 2x/${locale.languageCode}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = _Controller();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: U19DevicePage(controller: controller, feature: feature),
            ),
          );
          await tester.pumpAndSettle();
          expect(controller.writes, 0);
          expect(tester.takeException(), isNull);
          if (locale.languageCode == 'en') {
            final text = tester
                .widgetList<Text>(find.byType(Text))
                .map((t) => t.data ?? '')
                .join();
            expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(text), false);
          }
          if (feature == DeviceFeature.basicSettings) {
            final findTime = find.text(
              locale.languageCode == 'en'
                  ? 'Watch language and time'
                  : '手表语言与校时',
            );
            await tester.scrollUntilVisible(findTime, 180);
            await tester.tap(findTime);
            await tester.pumpAndSettle();
            expect(controller.writes, 0);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
