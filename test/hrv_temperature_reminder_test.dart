import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_reminder.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/reading_reminder.dart';
import 'package:saydian_app/l10n/generated/app_localizations.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/health_reminder_report.dart';
import 'package:saydian_app/ui/reading_reminder_widgets.dart';

const _device = DeviceInfo(
  id: 'synthetic-ring',
  name: 'Synthetic',
  firmwareVersion: 'test-1',
);
final _now = DateTime.utc(2026, 10, 30, 8);
ReadingReminderSettings _settings() => ReadingReminderSettings(
  highEnabled: true,
  phoneSoundEnabled: false,
  ringVibrationEnabled: false,
  hrvEnabled: true,
  hrvBaselineMs: 60,
  hrvReferenceKey: readingReminderReferenceKey(_device),
  temperatureEnabled: true,
  skinTemperatureBaseline: 34,
  temperatureReferenceKey: readingReminderReferenceKey(_device),
);
HealthRecord _record(
  HealthMetric metric,
  double value, {
  String id = 'synthetic',
  bool skin = true,
  String? unit,
  DateTime? at,
  String device = 'synthetic-ring',
  MeasurementOrigin origin = MeasurementOrigin.appMeasurement,
  String quality = 'device_reported',
  MeasurementSource source = MeasurementSource.wearable,
}) => HealthRecord(
  id: id,
  metric: metric,
  values: {
    'value': value,
    if (metric == HealthMetric.bodyTemperature && skin)
      'skinTemperature': value,
  },
  unit: unit ?? (metric == HealthMetric.hrv ? 'ms' : '℃'),
  measuredAt: at ?? _now,
  timezone: '+00:00',
  deviceId: device,
  firmwareVersion: 'test-1',
  quality: quality,
  source: source,
  origin: origin,
  rawVersion: 2,
);
ReadingReminderCandidate? _observe(
  HealthRecord record, {
  ReadingReminderSettings? settings,
  DeviceInfo device = _device,
  bool live = true,
  ReadingReminderEngine? engine,
}) => (engine ?? ReadingReminderEngine()).observe(
  record: record,
  device: device,
  owner: 'synthetic-owner',
  settings: settings ?? _settings(),
  now: _now,
  live: live,
);

class _Controller extends Fake implements AppController {
  final changes = ChangeNotifier();
  Set<HealthMetric> manual = {HealthMetric.hrv, HealthMetric.bodyTemperature};
  DeviceInfo device = _device;
  int saves = 0;
  @override
  ReadingReminderSettings readingReminderSettings =
      const ReadingReminderSettings(
        highEnabled: true,
        phoneSoundEnabled: false,
        ringVibrationEnabled: false,
      );
  @override
  DeviceInfo get connectedDevice => device;
  @override
  DeviceCapabilities get capabilities => DeviceCapabilities(
    metrics: manual,
    manualMetrics: manual,
    features: const {},
    supportsHistorySync: false,
  );
  @override
  bool canMeasureHealthMetric(HealthMetric metric) => manual.contains(metric);
  @override
  String get homeHealthCardOwner => 'synthetic-owner';
  @override
  bool get canSaveHealthReminder => true;
  @override
  bool get readingReminderSettingsSaving => false;
  @override
  bool get ringReminderVibrationBusy => false;
  @override
  bool get healthReminderRingVibrationAvailable => false;
  @override
  void addListener(VoidCallback listener) => changes.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      changes.removeListener(listener);
  @override
  Future<bool> saveReadingReminderSettings(
    ReadingReminderSettings value, {
    required String expectedOwner,
  }) async {
    if (expectedOwner != homeHealthCardOwner || !value.valid) return false;
    saves++;
    readingReminderSettings = value;
    changes.notifyListeners();
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Controller controller, {
  Locale locale = const Locale('zh'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (_, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ReadingReminderSettingsPanel(
                controller: controller,
                onHelp: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'all five reminder controls fit a compact group at normal phone text size',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _Controller()
        ..manual = {
          HealthMetric.heartRate,
          HealthMetric.bloodOxygen,
          HealthMetric.hrv,
          HealthMetric.bodyTemperature,
        };
      await _pump(tester, controller);
      final group = find.byKey(const Key('reading-reminder-measurement-group'));
      expect(tester.getSize(group).height, lessThanOrEqualTo(520));
      for (final kind in [
        HealthReminderKind.highHeartRate,
        HealthReminderKind.lowHeartRate,
        HealthReminderKind.lowBloodOxygen,
        HealthReminderKind.lowHrv,
        HealthReminderKind.highSkinTemperature,
      ]) {
        expect(
          find.byKey(Key('reading-reminder-${kind.wireName}-enabled')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in [const Locale('zh'), const Locale('en')]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'personal reference cards fit 375px ${locale.languageCode} at scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(375, 812);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pump(tester, _Controller(), locale: locale);
          await tester.ensureVisible(
            find.byKey(
              const Key('reading-reminder-high_skin_temperature-preview'),
            ),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  test(
    'legacy settings retain original preferences and both new comparisons start off',
    () {
      final raw =
          const ReadingReminderSettings(
            highEnabled: true,
            high: 135,
            phoneSoundEnabled: false,
          ).toJson()..removeWhere(
            (key, _) =>
                key.startsWith('hrv') ||
                key.startsWith('temperature') ||
                key == 'skinTemperatureBaseline',
          );
      final migrated = ReadingReminderSettings.parse(jsonEncode(raw))!;
      expect(migrated.high, 135);
      expect(migrated.highEnabled, isTrue);
      expect(migrated.phoneSoundEnabled, isFalse);
      expect(migrated.hrvEnabled, isFalse);
      expect(migrated.temperatureEnabled, isFalse);
      expect(migrated.hrvBaselineMs, isNull);
      expect(migrated.skinTemperatureBaseline, isNull);
      final restored = ReadingReminderSettings.parse(
        jsonEncode(_settings().toJson()),
      )!;
      expect(restored.hrvReadyFor(_device), isTrue);
      expect(restored.temperatureReadyFor(_device), isTrue);
    },
  );
  test('new comparisons require explicit bounded per-device references', () {
    expect(const ReadingReminderSettings(hrvEnabled: true).valid, isFalse);
    expect(
      const ReadingReminderSettings(temperatureEnabled: true).valid,
      isFalse,
    );
    for (final settings in [
      _settings().copyWith(hrvDropPercent: 0),
      _settings().copyWith(temperatureRiseC: double.nan),
      _settings().copyWith(hrvBaselineMs: 301),
      _settings().copyWith(skinTemperatureBaseline: 12),
      _settings().copyWith(hrvReferenceKey: 'a-name'),
    ]) {
      expect(settings.valid, isFalse);
    }
  });
  test(
    'HRV uses a personal percentage and retains reference in history and export',
    () {
      final candidate = _observe(_record(HealthMetric.hrv, 40))!;
      expect(candidate.details.kind, HealthReminderKind.lowHrv);
      expect(candidate.details.baselineValue, 60);
      expect(candidate.details.threshold, 42);
      expect(_observe(_record(HealthMetric.hrv, 50)), isNull);
      final detail = HealthReminderDetails.tryParse(
        candidate.details.copyWith(acknowledgedAt: _now).toJson(),
      )!;
      expect(detail.baselineValue, 60);
      expect(isPersonalReadingReminder(detail), isTrue);
      final csv = buildHealthReminderCsv(
        HealthWarningAlert(
          id: candidate.id,
          metric: HealthMetric.hrv,
          title: detail.kind.label,
          message: 'synthetic',
          triggeredAt: _now,
          reminder: detail,
        ),
      );
      expect(csv, contains('HRV（ms）'));
      expect(csv, contains('个人参考值'));
      expect(csv, isNot(contains('心率（bpm）')));
    },
  );
  test(
    'skin comparison never substitutes an estimated core-temperature value',
    () {
      final core = _record(HealthMetric.bodyTemperature, 39, skin: false);
      expect(_observe(core), isNull);
      final distinct = HealthRecord(
        id: 'distinct',
        metric: HealthMetric.bodyTemperature,
        values: {'value': 39, 'skinTemperature': 34.5},
        unit: '℃',
        measuredAt: _now,
        timezone: '+00:00',
        deviceId: _device.id,
        firmwareVersion: 'test-1',
        quality: 'device_reported',
        source: MeasurementSource.wearable,
        origin: MeasurementOrigin.appMeasurement,
        rawVersion: 2,
      );
      expect(_observe(distinct), isNull);
      final hot = _observe(_record(HealthMetric.bodyTemperature, 35.1))!;
      expect(hot.details.kind, HealthReminderKind.highSkinTemperature);
      expect(hot.details.threshold, closeTo(34.8, 0.0001));
      expect(hot.details.reading, 35.1);
      expect(hot.details.baselineValue, 34);
    },
  );
  for (final metric in [HealthMetric.hrv, HealthMetric.bodyTemperature]) {
    test(
      '${metric.wireName} rejects history, stale, wrong target, units, sentinel and firmware changes',
      () {
        final value = metric == HealthMetric.hrv ? 20.0 : 36.0;
        for (final record in [
          _record(metric, value, origin: MeasurementOrigin.watchHistory),
          _record(
            metric,
            value,
            at: _now.subtract(const Duration(seconds: 91)),
          ),
          _record(metric, value, at: _now.add(const Duration(seconds: 1))),
          _record(metric, value, device: 'other-ring'),
          _record(metric, value, quality: 'unknown'),
          _record(metric, value, unit: 'wrong'),
          _record(metric, 0),
          _record(metric, double.nan),
        ]) {
          expect(_observe(record), isNull);
        }
        expect(_observe(_record(metric, value), live: false), isNull);
        expect(
          _observe(
            _record(metric, value),
            settings: const ReadingReminderSettings(),
          ),
          isNull,
        );
        expect(
          _observe(
            _record(metric, value),
            device: const DeviceInfo(
              id: 'synthetic-ring',
              name: 'Same name',
              firmwareVersion: 'new',
            ),
          ),
          isNull,
        );
        final engine = ReadingReminderEngine();
        final record = _record(metric, value);
        expect(_observe(record, engine: engine), isNotNull);
        expect(
          _observe(
            record,
            engine: engine,
            settings: _settings().copyWith(phoneSoundEnabled: true),
          ),
          isNull,
        );
      },
    );
  }
  testWidgets('only real manual-capability rows appear', (tester) async {
    final controller = _Controller()..manual = {HealthMetric.hrv};
    await _pump(tester, controller);
    expect(
      find.byKey(const Key('reading-reminder-low_hrv-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reading-reminder-high_skin_temperature-card')),
      findsNothing,
    );
    controller.manual = {};
    await _pump(tester, controller);
    expect(
      find.byKey(const Key('reading-reminder-low_hrv-card')),
      findsNothing,
    );
  });
  for (final kind in [
    HealthReminderKind.lowHrv,
    HealthReminderKind.highSkinTemperature,
  ]) {
    testWidgets(
      '${kind.wireName} cannot enable without a reference and preserves unrelated preferences',
      (tester) async {
        final controller = _Controller();
        await _pump(tester, controller);
        final enable = find.byKey(
          Key('reading-reminder-${kind.wireName}-enabled'),
        );
        await tester.ensureVisible(enable);
        await tester.tap(enable);
        await tester.pumpAndSettle();
        final save = find.byKey(
          Key('reading-reminder-${kind.wireName}-save-reference'),
        );
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(controller.saves, 0);
        await tester.enterText(
          find.byKey(Key('reading-reminder-${kind.wireName}-baseline')),
          kind == HealthReminderKind.lowHrv ? '60' : '34,0',
        );
        tester.testTextInput.hide();
        await tester.pump();
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(controller.saves, 1);
        expect(controller.readingReminderSettings.highEnabled, isTrue);
        expect(controller.readingReminderSettings.phoneSoundEnabled, isFalse);
        expect(
          controller.readingReminderSettings.ringVibrationEnabled,
          isFalse,
        );
        expect(
          kind == HealthReminderKind.lowHrv
              ? controller.readingReminderSettings.hrvEnabled
              : controller.readingReminderSettings.temperatureEnabled,
          isTrue,
        );
      },
    );
    testWidgets(
      '${kind.wireName} preview stays a labeled animation without changing preferences',
      (tester) async {
        final controller = _Controller();
        await _pump(tester, controller);
        final preview = find.byKey(
          Key('reading-reminder-${kind.wireName}-preview'),
        );
        await tester.ensureVisible(preview);
        await tester.tap(preview);
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.byKey(const Key('reading-reminder-preview-label')),
          findsOneWidget,
        );
        expect(controller.saves, 0);
        await tester.tap(find.byKey(const Key('reading-reminder-close')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'changing ring while editing cannot save a reference for the replacement',
    (tester) async {
      final controller = _Controller();
      await _pump(tester, controller);
      await tester.tap(
        find.byKey(const Key('reading-reminder-low_hrv-enabled')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reading-reminder-low_hrv-baseline')),
        '60',
      );
      tester.testTextInput.hide();
      controller.device = const DeviceInfo(id: 'other-ring', name: 'Synthetic');
      final save = find.byKey(
        const Key('reading-reminder-low_hrv-save-reference'),
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(controller.saves, 0);
    },
  );
}
