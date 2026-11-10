import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/urion_eb1_protocol.dart';

import '../integration_test/u19_device_acceptance_test.dart' as qa;

HealthRecord _localFixture() => HealthRecord(
  id: 'synthetic-u19-record',
  metric: HealthMetric.bloodPressure,
  values: const {'systolic': 120, 'diastolic': 80, 'pulse': 65},
  unit: 'mmHg',
  measuredAt: DateTime.utc(2026, 11, 10, 7, 1, 2, 123, 789),
  timezone: '+08:00',
  deviceId: 'urion:synthetic-device',
  firmwareVersion: 'fixture-firmware',
  sourceVendor: 'urion',
  sourceDeviceCategory: 'watch',
  sourceModel: 'U19-fixture',
  sourceApp: 'say-ring',
  quality: 'valid',
  source: MeasurementSource.wearable,
  origin: MeasurementOrigin.appMeasurement,
  rawVersion: 1,
);

HealthRecord _remoteFixture({
  String userId = 'synthetic-owner',
  String? deviceId,
  DateTime? time,
  Map<String, num>? values,
  String? unit,
}) {
  final local = _localFixture();
  return HealthRecord(
    id: local.id,
    metric: local.metric,
    values: values ?? {'pulse': 65.0, 'diastolic': 80.0, 'systolic': 120.0},
    unit: unit ?? local.unit,
    measuredAt:
        time ??
        DateTime.fromMillisecondsSinceEpoch(
          local.measuredAt.millisecondsSinceEpoch,
          isUtc: true,
        ),
    timezone: local.timezone,
    deviceId:
        deviceId ??
        'server:${sha256.convert(utf8.encode('$userId:${local.deviceId}'))}',
    firmwareVersion: local.firmwareVersion,
    sourceVendor: local.sourceVendor,
    sourceDeviceCategory: local.sourceDeviceCategory,
    sourceModel: local.sourceModel,
    sourceApp: local.sourceApp,
    quality: local.quality,
    source: local.source,
    origin: local.origin,
    rawVersion: local.rawVersion,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final delegate =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('Cloud evidence follows server identity and millisecond contract', () {
    final checks = qa.u19CloudReadbackChecks(
      local: _localFixture(),
      remote: _remoteFixture(),
      userId: 'synthetic-owner',
    );
    expect(checks.values.every((passed) => passed), true);
  });

  test('Cloud evidence rejects another owner device digest', () {
    final checks = qa.u19CloudReadbackChecks(
      local: _localFixture(),
      remote: _remoteFixture(userId: 'other-owner'),
      userId: 'synthetic-owner',
    );
    expect(checks['deviceIdentity'], false);
  });

  test(
    'Cloud evidence rejects raw identifiers rather than disabling identity checks',
    () {
      final checks = qa.u19CloudReadbackChecks(
        local: _localFixture(),
        remote: _remoteFixture(deviceId: _localFixture().deviceId),
        userId: 'synthetic-owner',
      );
      expect(checks['deviceIdentity'], false);
    },
  );

  test(
    'Cloud evidence still rejects changed values, units or one millisecond',
    () {
      for (final entry in {
        'values': _remoteFixture(
          values: {'systolic': 121, 'diastolic': 80, 'pulse': 65},
        ),
        'unit': _remoteFixture(unit: 'changed-unit'),
        'timeAtApiPrecision': _remoteFixture(
          time: DateTime.fromMillisecondsSinceEpoch(
            _localFixture().measuredAt.millisecondsSinceEpoch + 1,
            isUtc: true,
          ),
        ),
      }.entries) {
        final checks = qa.u19CloudReadbackChecks(
          local: _localFixture(),
          remote: entry.value,
          userId: 'synthetic-owner',
        );
        expect(checks[entry.key], false);
      }
    },
  );

  test('QA observer retains an unrelated channel message and reply', () async {
    final messenger = qa.U19EvidenceMessenger(delegate);
    final data = const StandardMessageCodec().encodeMessage('unchanged');
    final reply = const StandardMessageCodec().encodeMessage('received');
    ByteData? received;
    messenger.setMessageHandler('qa/unrelated', (message) async {
      received = message;
      return reply;
    });
    // This test-only API exercises the same installed engine message handler.
    // ignore: deprecated_member_use
    final actual = await messenger.handlePlatformMessage(
      'qa/unrelated',
      data,
      null,
    );
    expect(identical(received, data), true);
    expect(identical(actual, reply), true);
    messenger.setMessageHandler('qa/unrelated', null);
  });

  test('QA observer cannot consume or rewrite a valid native event', () async {
    final messenger = qa.U19EvidenceMessenger(delegate);
    const codec = StandardMethodCodec();
    final frame = Eb1Frame.request(0x73, [2]).bytes;
    final data = codec.encodeSuccessEnvelope({
      'type': 'bytes',
      'deviceId': 'private-test-device-identifier',
      'generation': 123,
      'bytes': frame,
    });
    ByteData? received;
    var calls = 0;
    messenger.setMessageHandler('cc.saidian/urion_events', (message) async {
      calls++;
      received = message;
      return null;
    });
    // ignore: deprecated_member_use
    await messenger.handlePlatformMessage(
      'cc.saidian/urion_events',
      data,
      null,
    );
    expect(calls, 1);
    expect(identical(received, data), true);
    expect((messenger.diagnostics['completionNotices'] as Map)['2'], 1);
    final evidence = jsonEncode(messenger.diagnostics);
    expect(evidence, isNot(contains('private-test-device-identifier')));
    expect(evidence, isNot(contains('deviceId')));
    expect(evidence, isNot(contains('systolic')));
    messenger.setMessageHandler('cc.saidian/urion_events', null);
  });

  test(
    'Malformed diagnostic decoding still reaches original handler',
    () async {
      final messenger = qa.U19EvidenceMessenger(delegate);
      final before = messenger.diagnostics['observerErrors'] as int;
      final data = ByteData(1)..setUint8(0, 255);
      ByteData? received;
      messenger.setMessageHandler('cc.saidian/urion_events', (message) async {
        received = message;
        return null;
      });
      // ignore: deprecated_member_use
      await messenger.handlePlatformMessage(
        'cc.saidian/urion_events',
        data,
        null,
      );
      expect(identical(received, data), true);
      expect(messenger.diagnostics['observerErrors'], before + 1);
      messenger.setMessageHandler('cc.saidian/urion_events', null);
    },
  );

  test('QA observer sends each original native request exactly once', () async {
    final messenger = qa.U19EvidenceMessenger(delegate);
    const original = MethodChannel('cc.saidian/urion_methods');
    final observed = MethodChannel(
      'cc.saidian/urion_methods',
      const StandardMethodCodec(),
      messenger,
    );
    final bytes = Eb1Frame.request(0x14, [0, 0, 0, 0, 0, 50]).bytes;
    var calls = 0;
    delegate.setMockMethodCallHandler(original, (call) async {
      calls++;
      expect(call.method, 'writeFrame');
      expect((call.arguments as Map)['bytes'], orderedEquals(bytes));
      return null;
    });
    await observed.invokeMethod<void>('writeFrame', {'bytes': bytes});
    expect(calls, 1);
    expect((messenger.diagnostics['sentCommands'] as Map)['14'], 1);
    delegate.setMockMethodCallHandler(original, null);
  });
}
