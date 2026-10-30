import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/health_reminder.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/domain/reading_reminder.dart';
import 'package:saydian_app/ui/reading_reminder_widgets.dart';
import 'package:saydian_app/services/wearable_routing.dart';

final _now = DateTime.utc(2026, 10, 30, 1);
const _device = DeviceInfo(
  id: 'qring:synthetic-ring',
  name: 'Synthetic ring',
  firmwareVersion: 'test-only',
);
const _enabled = ReadingReminderSettings(
  highEnabled: true,
  lowEnabled: true,
  oxygenEnabled: true,
);
HealthRecord _record(
  double value, {
  String id = 'test',
  HealthMetric metric = HealthMetric.heartRate,
  String? unit,
  String device = 'qring:synthetic-ring',
  String quality = 'device_reported',
  DateTime? at,
  MeasurementOrigin origin = MeasurementOrigin.appMeasurement,
  MeasurementSource source = MeasurementSource.wearable,
}) => HealthRecord(
  id: id,
  metric: metric,
  values: {'value': value},
  unit: unit ?? (metric == HealthMetric.bloodOxygen ? '%' : 'bpm'),
  measuredAt: at ?? _now,
  timezone: '+00:00',
  deviceId: device,
  quality: quality,
  firmwareVersion: 'test-only',
  source: source,
  origin: origin,
  rawVersion: 2,
);
ReadingReminderCandidate? _observe(
  ReadingReminderEngine e,
  HealthRecord r, {
  ReadingReminderSettings settings = _enabled,
  bool live = true,
  String owner = 'test-owner',
  DeviceInfo device = _device,
}) => e.observe(
  record: r,
  device: device,
  owner: owner,
  settings: settings,
  now: _now,
  live: live,
);

void main() {
  test(
    'only confirmed vibration families qualify and prefix/conflict routing remains authoritative',
    () {
      for (final name in ['r7 pro', 'R7_Ultra', 'HR05', 'r8-pro']) {
        expect(
          WearableDeviceClassifier.isVibratingReminderCandidate(name),
          isTrue,
          reason: name,
        );
      }
      for (final name in [
        'R7',
        'R7C',
        'R12',
        'R21',
        'R8',
        'R21_R8Pro',
        'R7Pro_R8Pro',
        'HR01',
      ]) {
        expect(
          WearableDeviceClassifier.isVibratingReminderCandidate(name),
          isFalse,
          reason: name,
        );
      }
    },
  );
  test('defaults are off and corrupt persisted configuration stays off', () {
    expect(const ReadingReminderSettings().enabled, isFalse);
    expect(ReadingReminderSettings.parse('{bad'), isNull);
    final json = _enabled.toJson();
    expect(
      ReadingReminderSettings.parse(jsonEncode(json))?.fingerprint,
      _enabled.fingerprint,
    );
    for (final invalid in [
      {...json, 'high': '120'},
      {...json, 'low': 220},
      {...json, 'oxygen': 101},
      {...json, 'oxygenEnabled': 1},
    ]) {
      expect(ReadingReminderSettings.parse(jsonEncode(invalid)), isNull);
    }
  });
  test('heart rate boundaries differ from oxygen inclusive boundary', () {
    final cases = [
      (120.0, HealthMetric.heartRate, null),
      (121.0, HealthMetric.heartRate, HealthReminderKind.highHeartRate),
      (40.0, HealthMetric.heartRate, null),
      (39.0, HealthMetric.heartRate, HealthReminderKind.lowHeartRate),
      (93.0, HealthMetric.bloodOxygen, null),
      (92.0, HealthMetric.bloodOxygen, HealthReminderKind.lowBloodOxygen),
    ];
    for (final c in cases) {
      final result = _observe(
        ReadingReminderEngine(),
        _record(c.$1, metric: c.$2),
      );
      expect(result?.details.kind, c.$3);
      if (result != null) expect(result.metric, c.$2);
    }
  });
  test('phone sound changes keep the same reading deduplicated', () {
    final engine = ReadingReminderEngine();
    final first = _observe(engine, _record(130));
    final muted = _enabled.copyWith(phoneSoundEnabled: false);
    expect(first, isNotNull);
    expect(_observe(engine, _record(130), settings: muted), isNull);
    expect(
      _observe(ReadingReminderEngine(), _record(130), settings: muted)?.id,
      first!.id,
    );
  });
  test('user settings change only their enabled comparison', () {
    const custom = ReadingReminderSettings(
      highEnabled: true,
      high: 150,
      low: 50,
      oxygen: 94,
    );
    expect(
      _observe(ReadingReminderEngine(), _record(140), settings: custom),
      isNull,
    );
    expect(
      _observe(
        ReadingReminderEngine(),
        _record(151),
        settings: custom,
      )?.details.threshold,
      150,
    );
    expect(
      _observe(ReadingReminderEngine(), _record(30), settings: custom),
      isNull,
    );
    expect(
      _observe(
        ReadingReminderEngine(),
        _record(90, metric: HealthMetric.bloodOxygen),
        settings: custom,
      ),
      isNull,
    );
  });
  test(
    'history, invalid source or quality, stale, future, wrong units and device cannot alert',
    () {
      for (final r in [
        _record(130, origin: MeasurementOrigin.watchHistory),
        _record(130, origin: MeasurementOrigin.imported),
        _record(130, quality: 'unknown'),
        _record(130, at: _now.subtract(const Duration(minutes: 2))),
        _record(130, at: _now.add(const Duration(seconds: 1))),
        _record(130, unit: '%'),
        _record(130, device: 'another-device'),
        _record(130, source: MeasurementSource.manual),
        _record(double.nan),
        _record(999),
        _record(0, metric: HealthMetric.bloodOxygen),
      ]) {
        expect(_observe(ReadingReminderEngine(), r), isNull);
      }
      expect(
        _observe(ReadingReminderEngine(), _record(130), live: false),
        isNull,
      );
      expect(
        _observe(ReadingReminderEngine(), _record(130), owner: 'anonymous'),
        isNull,
      );
    },
  );
  test(
    'duplicates are suppressed and owners/settings get different stable event IDs',
    () {
      final e = ReadingReminderEngine();
      final a = _observe(e, _record(130));
      expect(a, isNotNull);
      expect(_observe(e, _record(130)), isNull);
      final b = _observe(e, _record(130), owner: 'another-owner');
      expect(b?.id, isNot(a!.id));
      final c = _observe(
        e,
        _record(130),
        settings: _enabled.copyWith(high: 125),
      );
      expect(c?.id, isNot(a.id));
    },
  );
  test('oxygen details retain metric threshold and JSON precision', () {
    final c = _observe(
      ReadingReminderEngine(),
      _record(91, metric: HealthMetric.bloodOxygen),
    )!;
    final parsed = HealthReminderDetails.tryParse(c.details.toJson())!;
    expect(parsed.kind, HealthReminderKind.lowBloodOxygen);
    expect(parsed.threshold, 92);
    expect(parsed.reading, 91);
    expect(parsed.measuredAt, _now);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'full red preview fits 332dp scale $scale and can close without writes',
      (tester) async {
        tester.view.physicalSize = const Size(332, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var closed = 0;
        var help = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: ReadingReminderAlertView(
                kind: HealthReminderKind.lowBloodOxygen,
                reading: 91,
                preview: true,
                onDismiss: () => closed++,
                onHelp: () => help++,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const Key('reading-reminder-preview-label')),
          findsOneWidget,
        );
        expect(find.text('%'), findsOneWidget);
        expect(find.text('bpm'), findsNothing);
        expect(
          find.byKey(const Key('reading-reminder-close')).hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const Key('dismiss-health-warning')),
        );
        await tester.tap(find.byKey(const Key('dismiss-health-warning')));
        // Finish the button's ink response before checking the stopped pulse.
        await tester.pumpAndSettle();
        expect(closed, 1);
        expect(help, 0);
        expect(tester.takeException(), isNull);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );
  }
  testWidgets('red feedback animates gently and stops for reduced motion', (
    tester,
  ) async {
    Widget page(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: ReadingReminderAlertView(
          kind: HealthReminderKind.highHeartRate,
          reading: 130,
          onDismiss: () {},
          onHelp: () {},
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(page(true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
