import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/feature_models.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/urion_eb1_protocol.dart';
import 'package:saydian_app/services/urion_wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Watch watch;
  setUp(() => watch = _Watch());
  tearDown(() => watch.dispose());

  test(
    'late disconnect from an older generation cannot retire a new session of the same watch',
    () async {
      await watch.connect();
      final old = watch.generation;
      await watch.bridge.disconnect();
      await watch.connect();
      Future<void> disconnect(int generation) async =>
          watch.messenger.handlePlatformMessage(
            _Watch.eventChannel.name,
            const StandardMethodCodec().encodeSuccessEnvelope({
              'type': 'disconnected',
              'payload': {'deviceId': watch.id, 'generation': generation},
            }),
            (_) {},
          );
      await disconnect(old);
      await _flush();
      expect(await watch.bridge.getConnectedDeviceDetails(), isNotNull);
      await disconnect(watch.generation);
      await _flush();
      expect(await watch.bridge.getConnectedDeviceDetails(), isNull);
    },
  );

  test('iOS Urion discovers pulse and monitoring with reads only', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await watch.connectAndReadCapabilities();
      final capabilities = await watch.bridge.getCapabilities();
      expect(
        capabilities.metrics,
        containsAll([
          HealthMetric.bloodPressure,
          HealthMetric.heartRate,
          HealthMetric.bloodOxygen,
        ]),
      );
      expect(capabilities.manualMetrics, contains(HealthMetric.bloodPressure));
      expect(capabilities.features, contains(DeviceFeature.u19Pulse));
      expect(capabilities.features, contains(DeviceFeature.healthMonitoring));
      expect(
        watch.writes
            .map((e) => e.$2.command)
            .where({0x32, 0x35, 0x38, 0x39, 0x3a}.contains),
        isEmpty,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test(
    'iOS applies current-device pressure notices without writing settings',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await watch.connectAndReadCapabilities();
        final writes = watch.writes.length;
        final update = Eb1Frame.request(0x37, [0, 9, 60, 90]);
        await watch.emit(update, device: 'another-watch');
        await watch.emit(update, session: watch.generation - 1);
        await watch.emit(Eb1Frame.request(0x73, [4]));
        await watch.emit(Eb1Frame.request(0x73, [6]));
        await _flush();
        expect(
          watch.events.where((e) => e.type == 'deviceFeatureData'),
          isEmpty,
        );

        expect(watch.events.where((e) => e.type == 'healthDataReady'), isEmpty);

        await watch.emit(update);
        await _flush();
        final event = watch.events.singleWhere(
          (e) => e.type == 'deviceFeatureData',
        );
        expect(
          event.payload['feature'],
          DeviceFeature.healthMonitoring.wireName,
        );
        expect(event.payload['deviceId'], watch.id);
        expect(event.payload['dynamicBloodPressure'], {
          'enabled': false,
          'startHour': 9,
          'dayIntervalMinutes': 60,
          'nightIntervalMinutes': 90,
        });
        expect(watch.writes, hasLength(writes));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test(
    'iOS pulse completion reads the result and retires the active session',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await watch.connectAndReadCapabilities();
        await watch.bridge.writeDeviceFeature(DeviceFeature.u19Pulse, {
          'operation': 'start',
        });
        watch.now = watch.now.add(const Duration(seconds: 30));
        final stamp = watch.now.millisecondsSinceEpoch ~/ 1000;
        watch.pulseHistory = [
          Eb1Frame.request(0x34, [
            for (var i = 0; i < 4; i++) (stamp >> (i * 8)) & 255,
            3,
            6,
            2,
          ]),
        ];
        final reads = watch.writes.where((e) => e.$2.command == 0x34).length;
        final notice = Eb1Frame.request(0x73, [5]);
        await watch.emit(notice, device: 'another-watch');
        await watch.emit(notice, session: watch.generation - 1);
        await _flush();
        expect(
          watch.writes.where((e) => e.$2.command == 0x34),
          hasLength(reads),
        );
        await watch.emit(notice);
        await _until(
          () => watch.events.any((e) => e.type == 'deviceFeatureData'),
        );
        final event = watch.events.lastWhere(
          (e) => e.type == 'deviceFeatureData',
        );
        expect(event.payload['justMeasured'], isTrue);
        expect(event.payload['pulse'], containsPair('qiBlood', 6));
        expect(watch.records, isEmpty);
        await watch.bridge.writeDeviceFeature(DeviceFeature.u19Pulse, {
          'operation': 'start',
        });
        expect(watch.writes.where((e) => e.$2.command == 0x3a), hasLength(2));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test(
    'read-only capability discovery exposes BP and find without starting measurement',
    () async {
      await watch.connect();
      final capabilities = await watch.bridge.getCapabilities();
      expect(capabilities.manualMetrics, {
        HealthMetric.bloodPressure,
        HealthMetric.heartRate,
        HealthMetric.bloodOxygen,
      });
      expect(capabilities.stoppableManualMetrics, isEmpty);
      expect(capabilities.features, contains(DeviceFeature.findWatch));
      expect(capabilities.features, contains(DeviceFeature.u19Pulse));
      expect(capabilities.features, contains(DeviceFeature.healthMonitoring));
      expect(
        watch.writes.map((entry) => entry.$2.command),
        isNot(contains(0x32)),
      );
      expect(
        watch.writes.map((entry) => entry.$2.command),
        isNot(contains(0x50)),
      );
    },
  );

  test(
    'BP ACK and old history are not results; paired notices emit one verified new record',
    () async {
      final old = _bp(watch.now.subtract(const Duration(minutes: 1)));
      watch.history = [old];
      await watch.connectAndReadCapabilities();
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      expect(watch.records, isEmpty);
      await watch.emit(Eb1Frame.request(0x73, [1]));
      await watch.emit(Eb1Frame.request(0x73, [3]));
      await _flush();
      expect(watch.records, isEmpty);
      final beforeRead = watch.bpReads;
      await watch.emit(Eb1Frame.request(0x73, [2]));
      await _until(() => watch.bpReads > beforeRead);
      await _flush();
      expect(watch.records, isEmpty);

      final startedAt = watch.now;
      watch.now = watch.now.add(const Duration(seconds: 45));
      final fresh = _bp(watch.now, systolic: 123);
      watch.history = [fresh, fresh, old];
      final readGate = Completer<void>();
      watch.historyGate = readGate;
      await watch.emit(Eb1Frame.request(0x73, [2]));
      await _until(() => watch.historyGateTaken);
      await watch.emit(Eb1Frame.request(0x33));
      readGate.complete();
      await _until(() => watch.records.isNotEmpty);
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(watch.records, hasLength(1));
      final record = watch.records.single;
      expect(
        record.payload['measurementStartedAt'],
        startedAt.toIso8601String(),
      );
      final parsed = HealthRecord.fromJson(record.payload);
      expect(parsed.origin, MeasurementOrigin.appMeasurement);
      expect(parsed.values['systolic'], 123);
      expect(parsed.measuredAt.toUtc(), watch.now);
      expect(parsed.deviceId, 'urion:watch-a');
      expect(parsed.sourceModel, 'fixture');
      expect(
        watch.events
            .where((event) => event.type == 'healthDataReady')
            .every(
              (event) =>
                  event.payload['source'] == 'watchNotification' &&
                  event.payload['deviceId'] == 'watch-a',
            ),
        isTrue,
      );
    },
  );

  test(
    'watch-started BP notice includes one uniquely timed history record in sync',
    () async {
      final old = _bp(watch.now.subtract(const Duration(minutes: 1)));
      watch.history = [old];
      await watch.connectAndReadCapabilities();
      await watch.bridge.syncHealthData();

      watch.now = watch.now.add(const Duration(seconds: 45));
      final fresh = _bp(watch.now, systolic: 127);
      watch.history = [fresh, old];
      await watch.emit(Eb1Frame.request(0x73, [2]));
      final received = await watch.bridge.syncHealthData();

      final record = received.singleWhere(
        (item) => item.metric == HealthMetric.bloodPressure,
      );
      expect(record.metric, HealthMetric.bloodPressure);
      expect(record.values['systolic'], 127);
      expect(record.measuredAt.toUtc(), watch.now);
      expect(record.origin, MeasurementOrigin.watchHistory);
      expect(record.id, isNotEmpty);

      await watch.emit(Eb1Frame.request(0x73, [2]));
      final duplicate = await watch.bridge.syncHealthData();
      expect(
        duplicate.where((item) => item.metric == HealthMetric.bloodPressure),
        isEmpty,
      );
    },
  );

  test(
    'BP empty primary history falls back to the documented reverse query',
    () async {
      await watch.connectAndReadCapabilities();
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      watch.now = watch.now.add(const Duration(seconds: 40));
      watch.reverseHistory = [_bp(watch.now, systolic: 126)];
      final first = watch.writes.length;
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(watch.records, hasLength(1));
      expect(
        HealthRecord.fromJson(watch.records.single.payload).values['systolic'],
        126,
      );
      expect(
        watch.writes.skip(first).map((e) => e.$2.command),
        everyElement(0x14),
      );
      expect(watch.writes.skip(first).map((e) => e.$2[5]), [0, 1]);
    },
  );

  test(
    'BP completion without a returned result ends with one bounded failure',
    () async {
      await watch.dispose();
      watch = _Watch(completedResultTimeout: const Duration(milliseconds: 45));
      await watch.connectAndReadCapabilities();
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      watch.now = watch.now.add(const Duration(seconds: 40));
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(
        watch.events.where(
          (e) =>
              e.type == 'measurementProgress' &&
              e.payload['deviceState'] == 'READING_RESULT',
        ),
        hasLength(1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 25));
      await watch.emit(Eb1Frame.request(0x33));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final errors = watch.events.where((e) => e.type == 'error');
      expect(errors, hasLength(1));
      expect(errors.single.payload['code'], 'BLOOD_PRESSURE_RESULT_MISSING');
      expect(errors.single.payload['deviceId'], 'urion:watch-a');
      expect(watch.records, isEmpty);
      // 完成通知已证明物理测量结束。失败终态不应让下一轮永久被旧标记挡住。
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      await _flush();
      expect(watch.events.where((e) => e.type == 'error'), hasLength(1));
      expect(watch.writes.where((e) => e.$2.command == 0x32), hasLength(2));
    },
  );

  test(
    'BP wait timeout is reported but does not silently permit reinflation',
    () async {
      await watch.dispose();
      watch = _Watch(resultPollInterval: const Duration(milliseconds: 10));
      await watch.connectAndReadCapabilities();
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      watch.now = watch.now.add(const Duration(seconds: 151));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        watch.events.where(
          (e) =>
              e.type == 'error' && e.payload['code'] == 'MEASUREMENT_TIMEOUT',
        ),
        hasLength(1),
      );
      expect(watch.records, isEmpty);
      await expectLater(
        watch.bridge.startMeasurement(HealthMetric.bloodPressure),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'MEASUREMENT_IN_PROGRESS',
          ),
        ),
      );
      final reads = watch.bpReads;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(watch.bpReads, reads);
      // 迟到的完成通知只释放旧物理测量屏障，不能冒充新的手动结果。
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(watch.records, isEmpty);
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      expect(watch.writes.where((e) => e.$2.command == 0x32), hasLength(2));
    },
  );

  test(
    'clock-mismatched and multiple new BP records cannot become a measurement',
    () async {
      await watch.connectAndReadCapabilities();
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      watch.now = watch.now.add(const Duration(seconds: 40));
      watch.history = [_bp(watch.now.subtract(const Duration(days: 3)))];
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(watch.records, isEmpty);
      watch.history = [_bp(watch.now), _bp(watch.now, systolic: 124)];
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(watch.records, isEmpty);
    },
  );

  test(
    'new start requires confirmation that the prior watch measurement ended',
    () async {
      await watch.connectAndReadCapabilities();
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      watch.now = watch.now.add(const Duration(seconds: 30));
      watch.history = [_bp(watch.now)];
      await expectLater(
        watch.bridge.startMeasurement(HealthMetric.bloodPressure),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'MEASUREMENT_IN_PROGRESS',
          ),
        ),
      );
      await watch.bridge.writeDeviceFeature(DeviceFeature.basicSettings, const {
        'operation': 'confirmMeasurementIdle',
      });
      await watch.bridge.startMeasurement(HealthMetric.bloodPressure);
      final newStart = watch.now;
      await watch.emit(Eb1Frame.request(0x33));
      await _flush();
      expect(watch.records, isEmpty);
      watch.now = watch.now.add(const Duration(seconds: 40));
      watch.history = [_bp(watch.now, systolic: 121), ...watch.history];
      await watch.emit(Eb1Frame.request(0x73, [2]));
      await _until(() => watch.records.isNotEmpty);
      expect(
        watch.records.single.payload['measurementStartedAt'],
        newStart.toIso8601String(),
      );
      expect(
        watch.writes.where((entry) => entry.$2.command == 0x32),
        hasLength(2),
      );
      expect(watch.writes.where((entry) => entry.$2.command == 0x3a), isEmpty);
    },
  );

  test('an enqueued find cannot cross to a newly connected watch', () async {
    await watch.connect();
    final hold = Completer<void>();
    watch.findGate = hold;
    final first = watch.bridge.triggerDeviceAction(DeviceFeature.findWatch);
    final firstCheck = expectLater(first, throwsA(isA<PlatformException>()));
    await _until(() => watch.findGateTaken);
    final second = watch.bridge.triggerDeviceAction(DeviceFeature.findWatch);
    final secondCheck = expectLater(
      second,
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'DEVICE_CHANGED',
        ),
      ),
    );
    await watch.bridge.disconnect();
    final connecting = watch.connect('watch-b');
    hold.complete();
    await Future.wait([firstCheck, secondCheck, connecting]);
    expect(
      watch.writes
          .where((entry) => entry.$2.command == 0x50)
          .map((entry) => entry.$1),
      ['watch-a'],
    );
  });

  test(
    'find waits for ACK and unsupported response withdraws capability',
    () async {
      await watch.connectAndReadCapabilities();
      final hold = Completer<void>();
      watch.findGate = hold;
      var complete = false;
      final finding = watch.bridge
          .triggerDeviceAction(DeviceFeature.findWatch)
          .then((_) => complete = true);
      await _until(() => watch.findGateTaken);
      expect(complete, isFalse);
      hold.complete();
      await finding;
      expect(complete, isTrue);
      watch.findUnsupported = true;
      await expectLater(
        watch.bridge.triggerDeviceAction(DeviceFeature.findWatch),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'UNSUPPORTED_DEVICE',
          ),
        ),
      );
      expect(
        (await watch.bridge.getCapabilities()).features,
        isNot(contains(DeviceFeature.findWatch)),
      );
      expect(
        watch.events.where((event) => event.type == 'capabilitiesUpdated'),
        hasLength(1),
      );
      final count = watch.writes.length;
      await expectLater(
        watch.bridge.triggerDeviceAction(DeviceFeature.findWatch),
        throwsA(isA<PlatformException>()),
      );
      expect(watch.writes.length, count);
    },
  );

  test(
    'setting and battery notices never request health synchronization',
    () async {
      await watch.connect();
      await watch.emit(Eb1Frame.request(0x73, [8]));
      await watch.emit(Eb1Frame.request(0x73, [9]));
      await _flush();
      expect(
        watch.events.where((event) => event.type == 'healthDataReady'),
        isEmpty,
      );
    },
  );

  test('heart-rate start waits for one changed watch slot, not ACK', () async {
    watch.heartValues = List.filled(288, 0);
    await watch.connectAndReadCapabilities();
    await watch.bridge.startMeasurement(HealthMetric.heartRate);
    expect(watch.records, isEmpty);
    watch.now = watch.now.add(const Duration(seconds: 25));
    watch.heartValues![72] = 74;
    await watch.emit(Eb1Frame.request(0x73, [1]));
    await _until(() => watch.records.isNotEmpty);
    final record = HealthRecord.fromJson(watch.records.single.payload);
    expect(record.metric, HealthMetric.heartRate);
    expect(record.values['value'], 74);
    expect(record.origin, MeasurementOrigin.appMeasurement);
    expect(record.sourceModel, 'fixture');
    await watch.emit(Eb1Frame.request(0x73, [1]));
    await _flush();
    expect(watch.records, hasLength(1));
  });

  test('oxygen start accepts a four-packet changed slot only', () async {
    watch.oxygenValues = List.filled(24, 0);
    await watch.connectAndReadCapabilities();
    await watch.bridge.startMeasurement(HealthMetric.bloodOxygen);
    expect(watch.records, isEmpty);
    watch.now = watch.now.add(const Duration(seconds: 20));
    watch.oxygenValues![8] = 98;
    await watch.emit(Eb1Frame.request(0x73, [3]));
    await _until(() => watch.records.isNotEmpty);
    final record = HealthRecord.fromJson(watch.records.single.payload);
    expect(record.metric, HealthMetric.bloodOxygen);
    expect(record.values['value'], 98);
  });

  test('unverified five-packet oxygen never exposes a measurement', () async {
    watch.oxygenValues = List.filled(24, 98);
    watch.oxygenFivePacket = true;
    await watch.connectAndReadCapabilities();
    final capabilities = await watch.bridge.getCapabilities();
    expect(capabilities.metrics, isNot(contains(HealthMetric.bloodOxygen)));
    expect(
      capabilities.manualMetrics,
      isNot(contains(HealthMetric.bloodOxygen)),
    );
    expect(watch.writes.where((entry) => entry.$2.command == 0x39), isEmpty);
  });

  test(
    'dynamic pressure read, guarded write and watch change notice',
    () async {
      await watch.connectAndReadCapabilities();
      final current = await watch.bridge.readDeviceFeature(
        DeviceFeature.healthMonitoring,
      );
      expect((current['dynamicBloodPressure'] as Map)['enabled'], isFalse);
      await expectLater(
        watch.bridge.writeDeviceFeature(DeviceFeature.healthMonitoring, {
          'dynamicBloodPressure': {
            'enabled': true,
            'startHour': 8,
            'dayIntervalMinutes': 9,
            'nightIntervalMinutes': 9,
          },
        }),
        throwsFormatException,
      );
      expect(watch.writes.where((entry) => entry.$2.command == 0x35), isEmpty);
      await watch.bridge.writeDeviceFeature(DeviceFeature.healthMonitoring, {
        'dynamicBloodPressure': {
          'enabled': true,
          'startHour': 8,
          'dayIntervalMinutes': 60,
          'nightIntervalMinutes': 90,
        },
      });
      expect(watch.schedule, [1, 8, 60, 90]);
      await watch.emit(Eb1Frame.request(0x37, [0, 9, 60, 90]));
      await _flush();
      expect(
        watch.events
            .where((event) => event.type == 'deviceFeatureData')
            .last
            .payload['dynamicBloodPressure'],
        containsPair('enabled', false),
      );
    },
  );

  test('pulse history changes are separate from acknowledged start', () async {
    await watch.connectAndReadCapabilities();
    await watch.bridge.writeDeviceFeature(DeviceFeature.u19Pulse, {
      'operation': 'start',
    });
    expect(
      watch.events.where((event) => event.type == 'deviceFeatureData'),
      isEmpty,
    );
    watch.now = watch.now.add(const Duration(seconds: 30));
    watch.pulseHistory = [
      Eb1Frame.request(0x34, [
        for (var index = 0; index < 4; index++)
          ((watch.now.millisecondsSinceEpoch ~/ 1000) >> (index * 8)) & 255,
        3,
        6,
        2,
      ]),
    ];
    await watch.emit(Eb1Frame.request(0x73, [5]));
    await _until(
      () => watch.events.any((event) => event.type == 'deviceFeatureData'),
    );
    final event = watch.events.lastWhere(
      (event) => event.type == 'deviceFeatureData',
    );
    expect(event.payload['justMeasured'], isTrue);
    expect(event.payload['pulse'], containsPair('qiBlood', 6));
  });

  test('unknown automatic-monitoring state is not displayed as off', () async {
    watch.autoMonitorState = 255;
    await watch.connectAndReadCapabilities();
    final value = await watch.bridge.readDeviceFeature(
      DeviceFeature.healthMonitoring,
    );
    expect(value.containsKey('heartRate'), isFalse);
    expect(value.containsKey('bloodOxygen'), isFalse);
    expect(value['dynamicBloodPressure'], isA<Map>());
  });

  test(
    'pulse read requests 50 original samples with device timestamps',
    () async {
      await watch.connectAndReadCapabilities();
      final time = watch.now.subtract(const Duration(days: 2)).toUtc();
      final stamp = time.millisecondsSinceEpoch ~/ 1000;
      final packet = Eb1Frame.request(0x34, [
        for (var i = 0; i < 4; i++) (stamp >> (i * 8)) & 255,
        3,
        6,
        2,
      ]);
      watch.pulseHistory = [packet, packet];
      final value = await watch.bridge.readDeviceFeature(
        DeviceFeature.u19Pulse,
      );
      expect(watch.writes.last.$2[6], 50);
      expect(
        value['pulseHistory'],
        hasLength(2),
      ); // Storage deduplicates; transport preserves packets.
      expect((value['pulse'] as Map)['rawTimestamp'], stamp);
      expect(
        DateTime.parse((value['pulse'] as Map)['measuredAt'] as String),
        time,
      );
      expect(watch.writes.where((r) => r.$2.command == 0x3a), isEmpty);
    },
  );

  test('pulse restart waits for user-confirmed end on the watch', () async {
    await watch.connectAndReadCapabilities();
    await watch.bridge.writeDeviceFeature(DeviceFeature.u19Pulse, {
      'operation': 'start',
    });
    expect(
      (await watch.bridge.readDeviceFeature(
        DeviceFeature.u19Pulse,
      ))['awaitingCompletion'],
      isTrue,
    );
    final startsBefore = watch.writes
        .where((write) => write.$2.command == 0x3a)
        .length;
    await expectLater(
      watch.bridge.writeDeviceFeature(DeviceFeature.u19Pulse, {
        'operation': 'start',
      }),
      throwsA(isA<PlatformException>()),
    );
    expect(
      watch.writes.where((write) => write.$2.command == 0x3a),
      hasLength(startsBefore),
    );
    await watch.bridge.writeDeviceFeature(DeviceFeature.u19Pulse, {
      'operation': 'watchEnded',
    });
    expect(
      (await watch.bridge.readDeviceFeature(
        DeviceFeature.u19Pulse,
      ))['awaitingCompletion'],
      isFalse,
    );
    await watch.bridge.writeDeviceFeature(DeviceFeature.u19Pulse, {
      'operation': 'start',
    });
    expect(
      watch.writes.where((write) => write.$2.command == 0x3a),
      hasLength(startsBefore + 1),
    );
  });

  test(
    'time request carries selected watch language and screen timeout reads back',
    () async {
      await watch.connectAndReadCapabilities();
      await watch.bridge.writeDeviceFeature(DeviceFeature.basicSettings, {
        'syncTime': 'en',
      });
      final english = watch.writes.lastWhere(
        (write) => write.$2.command == 0x01,
      );
      expect(english.$2[7], 1);
      await watch.bridge.writeDeviceFeature(DeviceFeature.basicSettings, {
        'syncTime': 'zh',
      });
      final chinese = watch.writes.lastWhere(
        (write) => write.$2.command == 0x01,
      );
      expect(chinese.$2[7], 0);
      await watch.bridge.writeDeviceFeature(DeviceFeature.screenDisplay, {
        'durationSeconds': 15,
      });
      final screen = await watch.bridge.readDeviceFeature(
        DeviceFeature.screenDisplay,
      );
      expect(screen['durationSeconds'], 15);
    },
  );

  test(
    'data sync remains read-only even when watch language was confirmed',
    () async {
      await watch.connect();
      await watch.bridge.writeDeviceFeature(DeviceFeature.basicSettings, {
        'syncTime': 'en',
      });
      watch.writes.clear();
      await watch.bridge.syncHealthData();
      expect(watch.writes.first.$2.command, 0x07);
      expect(watch.writes.map((w) => w.$2.command), isNot(contains(0x01)));
      await watch.bridge.disconnect();
      await watch.connect();
      watch.writes.clear();
      await watch.bridge.syncHealthData();
      expect(watch.writes.first.$2.command, 0x07);
      expect(watch.writes.map((w) => w.$2.command), isNot(contains(0x01)));
    },
  );

  test(
    'data sync does not guess a watch language before confirmation',
    () async {
      await watch.connect();
      watch.writes.clear();
      await watch.bridge.syncHealthData();
      expect(watch.writes.first.$2.command, 0x07);
      expect(
        watch.writes.map((write) => write.$2.command),
        isNot(contains(0x01)),
      );
    },
  );
}

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 10));

Future<void> _until(bool Function() ready) async {
  for (var attempt = 0; attempt < 100 && !ready(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(ready(), isTrue, reason: 'Expected mock event was not delivered');
}

Eb1Frame _bp(DateTime instant, {int systolic = 120}) {
  final timestamp = instant.millisecondsSinceEpoch ~/ 1000;
  return Eb1Frame.request(0x14, [
    for (var index = 0; index < 4; index++) (timestamp >> (index * 8)) & 255,
    80,
    systolic,
    65,
  ]);
}

class _Watch {
  _Watch({
    Duration resultPollInterval = const Duration(seconds: 6),
    Duration completedResultTimeout = const Duration(seconds: 24),
  }) {
    messenger.setMockMethodCallHandler(methods, _method);
    messenger.setMockMethodCallHandler(
      const MethodChannel('test/u19-session-events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final arguments = Map<Object?, Object?>.from(call.arguments as Map);
        final key = '${arguments['key']}';
        if (call.method == 'read') return secureValues[key];
        if (call.method == 'write') {
          secureValues[key] = '${arguments['value']}';
        }
        return null;
      },
    );
    bridge = UrionWearableBridge(
      methods: methods,
      eventChannel: eventChannel,
      requestTimeout: const Duration(seconds: 1),
      resultPollInterval: resultPollInterval,
      completedResultTimeout: completedResultTimeout,
      now: () => now,
    );
    subscription = bridge.events.listen(events.add);
  }

  static const methods = MethodChannel('test/u19-session-methods');
  static const eventChannel = EventChannel('test/u19-session-events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late final UrionWearableBridge bridge;
  late final StreamSubscription<WearableEvent> subscription;
  DateTime now = DateTime.utc(2026, 9, 28, 6);
  String id = 'watch-a';
  int generation = 0;
  int bpReads = 0;
  List<Eb1Frame> history = [];
  List<Eb1Frame>? reverseHistory;
  List<Eb1Frame> pulseHistory = [];
  List<int>? heartValues;
  List<int>? oxygenValues;
  bool oxygenFivePacket = false;
  List<int> schedule = [0, 8, 60, 60];
  int screenDuration = 10;
  int autoMonitorState = 2;
  final events = <WearableEvent>[];
  final writes = <(String, Eb1Frame)>[];
  final secureValues = <String, String>{};
  Completer<void>? historyGate;
  Completer<void>? findGate;
  bool historyGateTaken = false;
  bool findGateTaken = false;
  bool findUnsupported = false;
  List<WearableEvent> get records =>
      events.where((event) => event.type == 'healthRecord').toList();

  Future<void> connect([String device = 'watch-a']) => bridge.connect(
    device,
    profile: const WearableUserProfile(
      gender: 1,
      heightCm: 170,
      weightKg: 65,
      birthYear: 1990,
      age: 36,
      targetSteps: 6000,
    ),
  );
  Future<void> connectAndReadCapabilities() async {
    await connect();
    await bridge.getCapabilities();
  }

  Future<Object?> _method(MethodCall call) async {
    if (call.method == 'connect') {
      id = (call.arguments as Map)['deviceId'] as String;
      return {'generation': ++generation};
    }
    if (call.method == 'getDeviceDetails') {
      return {
        'id': id,
        'name': 'Protocol fixture',
        'model': 'fixture',
        'firmwareVersion': 'test',
      };
    }
    if (call.method != 'writeFrame') return null;
    final request = Eb1Frame.parse(
      List<int>.from((call.arguments as Map)['bytes']),
    )!;
    final requestId = id;
    final requestGeneration = generation;
    writes.add((id, request));
    final replies = <Eb1Frame>[];
    switch (request.command) {
      case 0x03:
        replies.add(Eb1Frame.request(0x03, [80]));
      case 0x14:
        bpReads++;
        if (historyGate case final gate?) {
          historyGate = null;
          historyGateTaken = true;
          await gate.future;
        }
        final selected = request[5] == 1 ? reverseHistory ?? history : history;
        replies.addAll(selected.take(request[6]));
        if (selected.length < request[6]) {
          replies.add(Eb1Frame.request(0x14, [255, 255, 255, 255]));
        }
      case 0x34:
        replies.addAll(pulseHistory.take(request[6]));
        if (pulseHistory.length < request[6]) {
          replies.add(Eb1Frame.request(0x34, [255, 255, 255, 255]));
        }
      case 0x15 || 0x2d:
        final values = request.command == 0x15 ? heartValues : oxygenValues;
        if (values == null) {
          replies.add(Eb1Frame.request(request.command, [255]));
        } else {
          final total = request.command == 0x15
              ? 24
              : oxygenFivePacket
              ? 5
              : 4;
          final interval = request.command == 0x15 ? 5 : 60;
          replies.add(Eb1Frame.request(request.command, [0, total, interval]));
          final padded = [...values, ...List.filled(295 - values.length, 0)];
          var offset = 0;
          for (var index = 1; index < total; index++) {
            final count = index == 1 ? 9 : 13;
            replies.add(
              Eb1Frame.request(request.command, [
                index,
                if (index == 1) ...[0, 0, 0, 0],
                ...padded.sublist(offset, offset + count),
              ]),
            );
            offset += count;
          }
        }
      case 0x07:
        final today = now.toLocal();
        for (var index = 0; index < 2; index++) {
          replies.add(
            Eb1Frame.request(0x07, [
              index,
              0,
              eb1EncodeBcd(today.year % 100),
              eb1EncodeBcd(today.month),
              eb1EncodeBcd(today.day),
            ]),
          );
        }
      case 0x1f:
        if (request[1] == 2) screenDuration = request[2];
        replies.add(Eb1Frame.request(0x1f, [request[1], screenDuration]));
      case 0x01:
        replies.add(Eb1Frame.request(0x01));
      case 0x16 || 0x2c:
        replies.add(Eb1Frame.request(request.command, [1, autoMonitorState]));
      case 0x0a:
        replies.add(Eb1Frame.request(0x0a, [1, 0, 0, 1, 36, 170, 65]));
      case 0x21:
        replies.add(Eb1Frame.request(0x21, [1, 0x70, 0x17]));
      case 0x32:
        replies.add(Eb1Frame.request(0x32));
      case 0x36:
        replies.add(Eb1Frame.request(0x36, schedule));
      case 0x35:
        schedule = request.bytes.sublist(1, 5);
        replies.add(Eb1Frame.request(0x35));
      case 0x38 || 0x39 || 0x3a:
        replies.add(Eb1Frame.request(request.command));
      case 0x50:
        if (findGate case final gate?) {
          findGate = null;
          findGateTaken = true;
          await gate.future;
        }
        replies.add(
          Eb1Frame.request(
            findUnsupported ? 0xd0 : 0x50,
            findUnsupported ? [0xee] : [],
          ),
        );
      default:
        throw StateError('Unexpected write ${request.command}');
    }
    for (final reply in replies) {
      await emit(reply, device: requestId, session: requestGeneration);
    }
    return null;
  }

  Future<void> emit(Eb1Frame frame, {String? device, int? session}) async {
    await messenger.handlePlatformMessage(
      eventChannel.name,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'type': 'bytes',
        'payload': {
          'deviceId': device ?? id,
          'generation': session ?? generation,
          'bytes': frame.bytes,
        },
      }),
      (_) {},
    );
  }

  Future<void> dispose() async {
    await subscription.cancel();
    await bridge.dispose();
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('test/u19-session-events'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  }
}
