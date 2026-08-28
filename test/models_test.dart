import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';

void main() {
  test('HealthRecord preserves its canonical wire representation', () {
    final record = HealthRecord(
      id: 'bp-1',
      metric: HealthMetric.bloodPressure,
      values: const {'systolic': 120, 'diastolic': 78},
      unit: 'mmHg',
      measuredAt: DateTime.utc(2026, 7, 29, 8, 30),
      timezone: '+08:00',
      deviceId: 'device-1',
      firmwareVersion: '1.2.3',
      quality: 'good',
      source: MeasurementSource.wearable,
      rawVersion: 1,
    );

    final decoded = HealthRecord.fromJson(record.toJson());

    expect(decoded.id, record.id);
    expect(decoded.metric, HealthMetric.bloodPressure);
    expect(decoded.displayValue, '120/78');
    expect(decoded.values, record.values);
    expect(decoded.measuredAt, record.measuredAt);
    expect(decoded.origin, MeasurementOrigin.watchHistory);
  });

  test('CarePermission is private by default', () {
    final permission = CarePermission.privateByDefault('member-1');

    expect(permission.accepted, isFalse);
    expect(permission.metrics, isEmpty);
    expect(permission.canRead(HealthMetric.heartRate), isFalse);
  });

  test('expired care permission never grants access', () {
    final permission = CarePermission(
      memberId: 'member-1',
      metrics: const {HealthMetric.heartRate},
      accepted: true,
      expiresAt: DateTime.utc(2026),
    );

    expect(
      permission.canRead(
        HealthMetric.heartRate,
        now: DateTime.utc(2026, 7, 29),
      ),
      isFalse,
    );
  });

  test('SportRecord maps the native Veepoo payload', () {
    final record = SportRecord.fromMap(const {
      'id': 'sport-1',
      'mode': 'cycling',
      'startedAt': '2026-08-07 08:30:00',
      'durationSeconds': 1800,
      'distanceKm': 12.5,
      'calories': 320.0,
    });

    expect(record.mode, SportMode.cycling);
    expect(record.durationSeconds, 1800);
    expect(record.distanceKm, 12.5);
    expect(record.startedAt, DateTime(2026, 8, 7, 8, 30));
  });

  test('SportRecord normalizes Veepoo GPS meters and calories', () {
    final record = SportRecord.fromMap(const {
      'id': 'gps-sport-1',
      'mode': 'mountaineering',
      'startedAt': '2026-08-28 09:00:00',
      'durationSeconds': 3600,
      'distanceMeters': 12500.0,
      'caloriesCal': 320000.0,
    });

    expect(record.mode, SportMode.mountaineering);
    expect(record.mode.label, '登山');
    expect(record.distanceKm, 12.5);
    expect(record.calories, 320);
  });

  test('WearableEvent unwraps the native event-channel payload', () {
    final event = WearableEvent.fromMap(const {
      'type': 'scanDevice',
      'payload': {'id': 'WATCH:01', 'name': 'Saidian Watch', 'rssi': -42},
    });

    expect(event.type, 'scanDevice');
    expect(event.payload['id'], 'WATCH:01');
    expect(event.payload['name'], 'Saidian Watch');
    expect(event.payload.containsKey('payload'), isFalse);
  });

  test('HealthWarningAlert preserves persisted warning history', () {
    final alert = HealthWarningAlert(
      id: 'warning-1',
      metric: HealthMetric.heartRate,
      title: '心率预警',
      message: '心率 121 bpm 超过上限',
      triggeredAt: DateTime.utc(2026, 8, 25, 8, 30),
      origin: MeasurementOrigin.remoteMember,
    );

    final decoded = HealthWarningAlert.fromJson(alert.toJson());

    expect(decoded.id, alert.id);
    expect(decoded.metric, HealthMetric.heartRate);
    expect(decoded.title, alert.title);
    expect(decoded.message, alert.message);
    expect(decoded.triggeredAt.toUtc(), alert.triggeredAt);
    expect(decoded.origin, MeasurementOrigin.remoteMember);
  });
}
