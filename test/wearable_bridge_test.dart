import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/wearable_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('cc.saidian/test_wearable_methods');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, null);
  });

  test('a timed out device command releases the serial queue', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          if (call.method == 'startSport') {
            return Completer<Object?>().future;
          }
          return 1;
        });
    final bridge = MethodChannelWearableBridge(
      methods: methods,
      operationTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      bridge.startSport(SportMode.walking),
      throwsA(isA<TimeoutException>()),
    );
    await expectLater(bridge.stopSport(), completes);
  });

  test('a timed out history sync releases the serial queue', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          if (call.method == 'syncHealthData') {
            return Completer<List<Object?>>().future;
          }
          return <Object?>[];
        });
    final bridge = MethodChannelWearableBridge(
      methods: methods,
      syncTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      bridge.syncHealthData(),
      throwsA(isA<TimeoutException>()),
    );
    await expectLater(bridge.readSportRecords(), completes);
  });

  test('watch-face profile read waits for the serial device queue', () async {
    final sportStarted = Completer<void>();
    final releaseSport = Completer<Object?>();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          calls.add(call.method);
          if (call.method == 'startSport') {
            sportStarted.complete();
            return releaseSport.future;
          }
          if (call.method == 'getWatchFaceProfile') {
            return <Object?, Object?>{'profileVersion': 1};
          }
          return null;
        });
    final bridge = MethodChannelWearableBridge(
      methods: methods,
      operationTimeout: const Duration(seconds: 1),
    );

    final sport = bridge.startSport(SportMode.walking);
    await sportStarted.future;
    final profile = bridge.getWatchFaceProfile();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, ['startSport']);

    releaseSport.complete(null);
    await sport;
    expect(await profile, {'profileVersion': 1});
    expect(calls, ['startSport', 'getWatchFaceProfile']);
  });

  test('native watch-face catalogue is parsed on the serial queue', () async {
    final sportStarted = Completer<void>();
    final releaseSport = Completer<Object?>();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          calls.add(call.method);
          if (call.method == 'startSport') {
            sportStarted.complete();
            return releaseSport.future;
          }
          if (call.method == 'getNativeWatchFaceCatalog') {
            return <Object?>[
              <Object?, Object?>{
                'id': 'native-1',
                'name': '',
                'fileUrl': 'https://vendor.example/WATCH001.bin',
                'previewUrl': 'https://vendor.example/WATCH001.png',
                'crc': 12345,
                'binProtocol': 2,
                'dialShape': 58,
              },
            ];
          }
          return null;
        });
    final bridge = MethodChannelWearableBridge(
      methods: methods,
      operationTimeout: const Duration(seconds: 1),
    );

    final sport = bridge.startSport(SportMode.walking);
    await sportStarted.future;
    final catalogue = bridge.getNativeWatchFaceCatalog();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, ['startSport']);

    releaseSport.complete(null);
    await sport;
    final items = await catalogue;
    expect(items, hasLength(1));
    expect(items.single.id, 'native-1');
    expect(items.single.name, isEmpty);
    expect(items.single.fileUrl.path, '/WATCH001.bin');
    expect(items.single.previewUrl.path, '/WATCH001.png');
    expect(items.single.crc, 12345);
    expect(items.single.binProtocol, 2);
    expect(items.single.dialShape, 58);
    expect(calls, ['startSport', 'getNativeWatchFaceCatalog']);
  });

  test('native watch-face download is parsed and queued', () async {
    final catalogueStarted = Completer<void>();
    final releaseCatalogue = Completer<Object?>();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          calls.add(call.method);
          if (call.method == 'getNativeWatchFaceCatalog') {
            catalogueStarted.complete();
            return releaseCatalogue.future;
          }
          if (call.method == 'downloadNativeWatchFace') {
            expect(call.arguments, {'catalogId': 'native-1'});
            return <Object?, Object?>{
              'catalogId': 'native-1',
              'filePath': '/tmp/WATCH001.bin',
              'fileLength': 602341,
            };
          }
          return null;
        });
    final bridge = MethodChannelWearableBridge(methods: methods);

    final catalogue = bridge.getNativeWatchFaceCatalog();
    await catalogueStarted.future;
    final download = bridge.downloadNativeWatchFace('native-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, ['getNativeWatchFaceCatalog']);

    releaseCatalogue.complete(<Object?>[]);
    await catalogue;
    final artifact = await download;
    expect(artifact.catalogId, 'native-1');
    expect(artifact.filePath, '/tmp/WATCH001.bin');
    expect(artifact.fileLength, 602341);
    expect(calls, ['getNativeWatchFaceCatalog', 'downloadNativeWatchFace']);
  });

  test('timed out native watch-face command releases the queue', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          if (call.method == 'getNativeWatchFaceCatalog') {
            return Completer<List<Object?>>().future;
          }
          return null;
        });
    final bridge = MethodChannelWearableBridge(
      methods: methods,
      watchFaceTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      bridge.getNativeWatchFaceCatalog(),
      throwsA(isA<TimeoutException>()),
    );
    await expectLater(bridge.stopSport(), completes);
  });

  test(
    'decodes a watch-side ECG history record without inventing a waveform',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methods, (call) async {
            if (call.method != 'syncHealthData') return null;
            return <Object?>[
              <Object?, Object?>{
                'id': 'W9S:ecg:2026-08-28T14:30:00.000Z',
                'type': 'ecg',
                'values': <Object?, Object?>{
                  'meanHeartRate': 78,
                  'averageHRV': 62,
                  'averageTimeInterval': 410,
                  'sampleFrequency': 500,
                },
                'unit': '',
                'measuredAt': '2026-08-28T14:30:00.000Z',
                'timezone': '+08:00',
                'deviceId': 'W9S',
                'firmwareVersion': '00.16.06',
                'quality': 'device_reported',
                'source': 'wearable',
                'rawVersion': 1,
              },
            ];
          });
      final bridge = MethodChannelWearableBridge(methods: methods);

      final records = await bridge.syncHealthData();

      expect(records, hasLength(1));
      expect(records.single.metric, HealthMetric.ecg);
      expect(records.single.values['averageTimeInterval'], 410);
      expect(records.single.samples, isEmpty);
      expect(records.single.rawVersion, 1);
    },
  );

  test(
    'pulls connected device details and preserves a null disconnect',
    () async {
      var connected = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methods, (call) async {
            if (call.method != 'getDeviceDetails' || !connected) return null;
            return <Object?, Object?>{
              'id': '38:23:A4:5E:CA:69',
              'name': 'SD-watch-W9S',
              'firmwareVersion': '00.20.01',
            };
          });
      final bridge = MethodChannelWearableBridge(methods: methods);

      final details = await bridge.getConnectedDeviceDetails();
      expect(details?.id, '38:23:A4:5E:CA:69');
      expect(details?.firmwareVersion, '00.20.01');

      connected = false;
      expect(await bridge.getConnectedDeviceDetails(), isNull);
    },
  );

  test('reads and writes the vendor automatic monitoring interval', () async {
    MethodCall? written;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          if (call.method == 'readAutoMeasureIntervals') {
            return <Object?, Object?>{
              'heartRate': <Object?, Object?>{
                'minutes': 10,
                'stepMinutes': 5,
                'canModify': true,
              },
              'bodyTemperature': <Object?, Object?>{
                'minutes': 5,
                'stepMinutes': 5,
                'canModify': false,
              },
            };
          }
          written = call;
          return null;
        });
    final bridge = MethodChannelWearableBridge(methods: methods);

    final settings = await bridge.readAutoMeasureIntervals();
    expect(settings['heartRate']?.minutes, 10);
    expect(settings['heartRate']?.choices, containsAll([5, 10, 30, 60]));
    expect(settings['bodyTemperature']?.minutes, 5);
    expect(settings['bodyTemperature']?.canModify, isFalse);

    await bridge.setAutoMeasureInterval('heartRate', 30);
    expect(written?.method, 'setAutoMeasureInterval');
    expect(written?.arguments, {'type': 'heartRate', 'minutes': 30});
  });

  test(
    'restores the last bound watch with the current member profile',
    () async {
      MethodCall? restoreCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methods, (call) async {
            restoreCall = call;
            return <Object?, Object?>{
              'id': '38:23:A4:5E:CA:69',
              'name': 'SD-watch-W9S',
            };
          });
      final bridge = MethodChannelWearableBridge(methods: methods);
      const profile = WearableUserProfile(
        gender: 1,
        heightCm: 175,
        weightKg: 70,
        birthYear: 1996,
        age: 30,
        targetSteps: 10000,
      );

      final restored = await bridge.restoreConnection(profile: profile);

      expect(restored?.id, '38:23:A4:5E:CA:69');
      expect(restoreCall?.method, 'restoreConnection');
      expect((restoreCall?.arguments as Map)['profile']['targetSteps'], 10000);
    },
  );
}
