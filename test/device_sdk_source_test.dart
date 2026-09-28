import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';

void main() {
  test('routed device identifiers expose their SDK source and native id', () {
    const veepoo = DeviceInfo(id: 'veepoo:AA:BB', name: 'ET488');
    const yucheng = DeviceInfo(id: 'yucheng:W8-01', name: 'W8');

    expect(veepoo.sdkSource, WearableSdkSource.veepoo);
    expect(veepoo.sdkSource.shortLabel, 'Vep');
    expect(veepoo.nativeId, 'AA:BB');
    expect(yucheng.sdkSource, WearableSdkSource.yucheng);

    const moyoung = DeviceInfo(id: 'moyoung:ring-3', name: 'D Ring');
    expect(moyoung.sdkSource, WearableSdkSource.moyoung);
    expect(yucheng.sdkSource.shortLabel, 'Yuc');
    expect(yucheng.nativeId, 'W8-01');
  });

  test('unrouted identifiers stay explicitly unmarked', () {
    const device = DeviceInfo(id: 'AA:BB', name: 'Legacy');

    expect(device.sdkSource, WearableSdkSource.unknown);
    expect(device.nativeId, 'AA:BB');
  });

  test('only real hardware addresses are labelled as MAC addresses', () {
    const iOSDeviceWithoutAddress = DeviceInfo(
      id: 'veepoo:36CE3B81-94C2-9B3F-C30F-BE9AB1EB2C7D',
      name: 'SD-WATCH-W9S',
    );
    const iOSDeviceWithAddress = DeviceInfo(
      id: 'veepoo:36CE3B81-94C2-9B3F-C30F-BE9AB1EB2C7D',
      name: 'SD-WATCH-W9S',
      hardwareAddress: '67:97:35:81:2f:44',
    );
    const yucDevice = DeviceInfo(
      id: 'yucheng:F88A714C-1FD0-CBD9-126B-E098D1D63483',
      name: 'w8s 4DE9',
      hardwareAddress: '07:43:00:00:4D:E9',
    );
    const compactAddress = DeviceInfo(id: 'veepoo:5c8bbc6f26fc', name: 'ET488');

    expect(iOSDeviceWithoutAddress.macAddress, isNull);
    expect(
      iOSDeviceWithoutAddress.identifierLabel,
      'iOS 连接标识 · 36CE3B81…B1EB2C7D',
    );
    expect(iOSDeviceWithAddress.macAddress, '67:97:35:81:2F:44');
    expect(iOSDeviceWithAddress.identifierLabel, 'MAC · 67:97:35:81:2F:44');
    expect(yucDevice.macAddress, '07:43:00:00:4D:E9');
    expect(yucDevice.identifierLabel, 'MAC · 07:43:00:00:4D:E9');
    expect(compactAddress.macAddress, '5C:8B:BC:6F:26:FC');
  });

  test('normalizes corrupted W9-family scan names', () {
    final w9s = DeviceInfo.fromMap({
      'id': 'UUID-1',
      'name': '  SD-\u0000WATCH-W9S\uFFFD  ',
    });
    final w9 = DeviceInfo.fromMap({'id': 'UUID-2', 'name': 'sd_watch_w9'});

    expect(w9s.name, 'SD-Watch-W9S');
    expect(w9.name, 'SD-Watch-W9');
  });

  test('missing model falls back to the final Bluetooth name segment', () {
    const reported = DeviceInfo(
      id: 'veepoo:1',
      name: 'SD-Watch-W9S',
      model: 'VP-900',
    );
    const inferred = DeviceInfo(id: 'veepoo:2', name: 'SD-Watch-W9S');
    const emptySuffix = DeviceInfo(id: 'veepoo:3', name: 'SD-Watch-');
    const noSeparator = DeviceInfo(id: 'veepoo:4', name: 'ET488');

    expect(reported.displayModel, 'VP-900');
    expect(inferred.displayModel, 'W9S');
    expect(emptySuffix.displayModel, '--');
    expect(noSeparator.displayModel, '--');
  });

  test('manual measurement support is independent from synced metrics', () {
    final capabilities = DeviceCapabilities.fromMap({
      'metrics': ['heart_rate', 'hrv'],
      'manualMetrics': ['heart_rate'],
    });

    expect(capabilities.supports(HealthMetric.hrv), isTrue);
    expect(capabilities.supportsManualMeasurement(HealthMetric.hrv), isFalse);
    expect(
      capabilities.supportsManualMeasurement(HealthMetric.heartRate),
      isTrue,
    );
  });

  test(
    'legacy capabilities keep their existing manual measurement behavior',
    () {
      final capabilities = DeviceCapabilities.fromMap({
        'metrics': ['heart_rate'],
      });

      expect(
        capabilities.supportsManualMeasurement(HealthMetric.heartRate),
        isTrue,
      );
    },
  );

  test('device capabilities expose only app-controlled watch sports', () {
    final capabilities = DeviceCapabilities.fromMap({
      'metrics': <String>[],
      'sportModes': ['running', 'walking', 'unknown'],
      'supportsSportPause': true,
    });

    expect(capabilities.sportModes, {SportMode.running, SportMode.walking});
    expect(
      capabilities.toJson()['sportModes'],
      containsAll(['running', 'walking']),
    );
    expect(capabilities.supportsSportPause, isTrue);
    expect(capabilities.toJson()['supportsSportPause'], isTrue);
  });

  test(
    'CoolWear HRV and stress keep documented and HR01 compatibility paths',
    () {
      final source = File(
        'android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java',
      ).readAsStringSync();

      expect(source, contains('K6_Action.RCVD.RCVD_STRESS_SHOW'));
      expect(source, contains('K6_Action.RCVD.RCVD_SPORT_HRV_FOR_SHOW'));
      expect(source, contains('onStressCompatValues(snapshot)'));
      expect(source, contains('value.getHrvNums()'));
      expect(
        source,
        contains('helper.getSendBlueData().sendStressSwitch(state)'),
      );
      expect(source, contains('System.currentTimeMillis()'));
      expect(source, contains('sendRriHrvCmd(state)'));
      expect(source, contains('sendHRVSwitch(CEBC.OPENSTATUS.OPEN)'));
      expect(source, contains('"hrv".equals(activeMeasurement)'));
      expect(source, contains('emitMeasurement("hrv", time, hrv, "ms")'));
      expect(source, contains('sendHeartAutoSwitch('));
      expect(source, contains('sendFindDevice()'));
      expect(source, contains('sendPhotoSwitch(enabled)'));
      expect(source, contains('value.put("features", features)'));
      expect(
        source,
        contains('value.put("integratedFeatures", new ArrayList<>(features))'),
      );
      expect(source, isNot(contains('java.util.Random')));
    },
  );

  test(
    'Android Veepoo sync serializes origin, manual health and ECG history',
    () {
      final source = File(
        'android/app/src/main/kotlin/cc/saidian/saydian_app/MainActivity.kt',
      ).readAsStringSync();
      final originCompletion = source.indexOf(
        'private fun completeOriginHealthSync',
      );
      final manualReader = source.indexOf(
        'private fun readDeviceManualHealthData',
      );
      final ecgReader = source.indexOf('private fun readEcgHistoryData');
      final finalCompletion = source.indexOf('private fun completeHealthSync');

      expect(originCompletion, greaterThanOrEqualTo(0));
      expect(manualReader, greaterThan(originCompletion));
      expect(ecgReader, greaterThan(manualReader));
      expect(finalCompletion, greaterThan(ecgReader));

      final originBlock = source.substring(originCompletion, manualReader);
      final manualBlock = source.substring(manualReader, ecgReader);
      final ecgBlock = source.substring(ecgReader, finalCompletion);
      expect(originBlock, contains('readDeviceManualHealthData('));
      expect(manualBlock, contains('manager.readDeviceManualData('));
      expect(source, contains('DeviceManualDataType.BLOOD_PRESSURE'));
      expect(manualBlock, contains('listOf(DeviceManualDataType.ALL)'));
      expect(manualBlock, contains('onBloodPressureDataChange'));
      expect(manualBlock, contains('completeManualHealthSync('));
      expect(source, contains('origin.halfHourBps.orEmpty()'));
      expect(source, contains('origin.halfHourRateDatas.orEmpty()'));
      expect(ecgBlock, contains('manager.readECGData('));
      expect(ecgBlock, contains('EEcgDataType.MANUALLY'));
      expect(ecgBlock, contains('TimeData(0, 0, 0, 0, 0, 0)'));
      expect(ecgBlock, contains('IECGReadDataListener'));
      expect(source, contains('set(Calendar.MILLISECOND, 0)'));
      expect(
        source,
        contains('it["rawVersion"] as? Number)?.toInt() ?: 1 == rawVersion'),
      );
    },
  );

  test('ring camera guidance uses shake control instead of a watch button', () {
    final source = File('lib/ui/prototype_pages.dart').readAsStringSync();

    expect(source, contains('摇动戒指触发拍照'));
    expect(source, isNot(contains('按戒指拍照键')));
    expect(source, isNot(contains('戒指弹出确认')));
  });

  test(
    'Android cancels a measurement before the SDK stop callback can save partial data',
    () {
      final source = File(
        'android/app/src/main/kotlin/cc/saidian/saydian_app/MainActivity.kt',
      ).readAsStringSync();
      final stopStart = source.indexOf('fun stopMeasurement(');
      final stopEnd = source.indexOf(
        'private fun startBloodPressureMeasurement',
        stopStart,
      );
      expect(stopStart, greaterThanOrEqualTo(0));
      expect(stopEnd, greaterThan(stopStart));

      final stopBlock = source.substring(stopStart, stopEnd);
      final sessionInvalidation = stopBlock.indexOf(
        'synchronized(this) { activeMetric = null }',
      );
      final sdkDispatch = stopBlock.indexOf('when (metric)');
      expect(sessionInvalidation, greaterThanOrEqualTo(0));
      expect(sdkDispatch, greaterThan(sessionInvalidation));
      expect(
        stopBlock.substring(sdkDispatch),
        isNot(contains('activeMetric = null')),
      );
    },
  );

  test('iOS Veepoo keeps its UUID route and exposes the SDK address', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('device.peripheral.identifier.uuidString'));
    expect(
      source,
      contains('WearablePayloadMapper.hardwareAddress(model.deviceAddress)'),
    );
    expect(source, contains('payload["hardwareAddress"] = hardwareAddress'));
    expect(
      source,
      contains('WearablePayloadMapper.hardwareAddress(device.deviceAddress)'),
    );
    expect(source, contains('details["hardwareAddress"] = hardwareAddress'));
  });

  test(
    'iOS online watch faces use a separate validated transfer operation',
    () {
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(source, contains('case "upload_network":'));
      expect(
        source,
        contains('uploadNetworkWatchFace(values, result: result)'),
      );
      expect(
        source,
        contains('manager.peripheralManage.veepooSDK_dialChannel('),
      );
      expect(source, contains('VPMarketDialManager.share().startTransfer('));
      expect(source, contains('WATCH_FACE_INCOMPATIBLE'));
      expect(source, contains('WATCH_FACE_VERIFY_FAILED'));
      expect(source, contains('"onlineMarketSupported": true'));
    },
  );

  test('iOS ECG converts ADC samples before declaring calibrated waveform', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('VPECGTestDataModel.convertToMv('));
    expect(source, contains('signals: model.filterSignals'));
    expect(
      source,
      contains('guard samples.count > 1, hasConvertedSignal else'),
    );
    expect(source, contains('emit("measurementProgress", progressPayload)'));
    expect(source, contains('case .start, .testing, .notLead:'));
    expect(
      source,
      contains('guard hasPrimaryResult, !waveform.samples.isEmpty'),
    );
    expect(source, contains('deviceTestOffStoreECGDidFinishBlock'));
    expect(source, contains('"origin": "watch_history"'));
  });
}
