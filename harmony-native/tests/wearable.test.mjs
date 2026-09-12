import { readUiSource } from './support/localized-ui-source.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  activityDistanceKilometers, batteryText, boundedHealthValue, capabilitiesFromFeatureList, cleanDeviceName,
  createWearableDevice,
  healthRecordText, healthValue, isCurrentConnectionGeneration, mergeWearableDevices,
  isOneShotMeasurementMetric, normalizeLegacyDistanceRecord, normalizeMac, retainedMeasurementValues,
  sportDistanceKilometers, wearableIdentifierText,
  wearableModelText, wearableProviderForName, WEARABLE_AUTO_SYNC_DELAY_MS,
  WEARABLE_CONNECT_TIMEOUT_MS, WEARABLE_MEASUREMENT_STOP_TIMEOUT_MS, WEARABLE_SCAN_TIMEOUT_MS,
} from '../entry/src/main/ets/model/WearableContracts.ts';

test('trimmed ring prefixes select one vendor transport and unknown names fail closed', () => {
  for (const name of ['YC Ring', '  yc-r02  ']) assert.equal(wearableProviderForName(name), 'Yuc');
  for (const name of ['V Ring', 'v-health', 'TK Ring', ' tk-r01 ']) assert.equal(wearableProviderForName(name), 'Vep');
  for (const name of ['D Ring', ' d-r03 ']) assert.equal(wearableProviderForName(name), 'Moyoung');
  for (const name of ['W8 8211', 'ET488', 'SD-Watch-W9S', 'AirPods', ''])
    assert.equal(wearableProviderForName(name), '');
});

test('device names remove control bytes and do not allow blank labels', () => {
  assert.equal(cleanDeviceName('  SD\u0000-Watch\n-W9S  '), 'SD-Watch-W9S');
  assert.equal(cleanDeviceName(' \n '), '未知设备');
});

test('missing device model falls back to the final Bluetooth name segment', () => {
  assert.equal(wearableModelText('VP-900', 'SD-Watch-W9S'), 'VP-900');
  assert.equal(wearableModelText('', 'SD-Watch-W9S'), 'W9S');
  assert.equal(wearableModelText(' ', 'SD-Watch-W9'), 'W9');
  assert.equal(wearableModelText('', 'ET488'), '未知');
  assert.equal(wearableModelText('', 'SD-Watch-'), '未知');
});

test('only verified six-byte addresses are presented as MAC', () => {
  assert.equal(normalizeMac('9b-21-62-9f-17-bf'), '9B:21:62:9F:17:BF');
  assert.equal(normalizeMac('36CE3B81-94C2-9B3F-C30F-BE9AB1EB2C7D'), '');
  assert.equal(normalizeMac('00:00:00:00:00:00'), '');
  const virtual = createWearableDevice('Vep', 'V Ring', '36CE3B81-94C2-9B3F-C30F-BE9AB1EB2C7D', '', -42, true);
  assert.match(wearableIdentifierText(virtual), /^设备标识/);
  const real = createWearableDevice('Vep', 'V Ring', 'virtual-id', '9B:21:62:9F:17:BF', -42, true);
  assert.equal(wearableIdentifierText(real), 'MAC · 9B:21:62:9F:17:BF');
});

test('scan results deduplicate and update signal without mixing providers', () => {
  const weak = createWearableDevice('Vep', 'V Ring', 'transport-a', '11:22:33:44:55:66', -90, true);
  const yuc = createWearableDevice('Yuc', 'YC Ring', 'transport-y', '', -60, true);
  const strong = createWearableDevice('Vep', 'V Ring', 'transport-b', '11:22:33:44:55:66', -45, true);
  const merged = mergeWearableDevices([weak, yuc], [strong]);
  assert.equal(merged.length, 2);
  assert.equal(merged[0].provider, 'Vep');
  assert.equal(merged[0].rssi, -45);
  assert.equal(merged[1].provider, 'Yuc');
  assert.equal(merged[1], yuc, 'RSSI refresh must not reorder rows that the user may be tapping');
});

test('capabilities follow the vendor flags including inverted heart-rate support', () => {
  const supported = capabilitiesFromFeatureList({
    dailyDataDays: 3, heartRateFunction: 0, bloodPressure: 1, bloodOxygen: 1,
    bodyTemp: 1, bloodGlucose: 1, hrv: 1, ecgFunction: 1, bodyComposition: 1,
    bloodComposition: 1, sportModeCount: 20, newAlarm: 1, healthReminder: 1,
    messageNotifyPackets: 2, findBand: 1, moreWatchfaceCount: 3, customWatchfaceCount: 1,
    camera: 1, hidFunction: 1, contactsType: 1, weather: 1, worldClock: 1,
    b3AutoMeasure: 1, healthAssessment: 1, screenBrightness: 1,
  });
  for (const value of Object.values(supported)) assert.equal(value, true);
  assert.equal(capabilitiesFromFeatureList({ heartRateFunction: 1 }).heart, false);
  assert.equal(capabilitiesFromFeatureList({ heartRateFunction: 0, b3AutoMeasure: 0 }).healthMonitoring, true,
    'legacy W9/W9S sensor flags must keep the automatic monitoring entry visible');
  const unavailable = capabilitiesFromFeatureList();
  for (const value of Object.values(unavailable)) assert.equal(value, false);
});

test('battery formatting never converts a grade into a guessed percentage', () => {
  assert.equal(batteryText({ available: true, hasPercentage: true, level: 65, levelGrade: 0,
    charging: false, lowBattery: false, updatedAt: 1 }), '65%');
  assert.equal(batteryText({ available: true, hasPercentage: false, level: 0, levelGrade: 3,
    charging: true, lowBattery: false, updatedAt: 1 }), '3 格 · 充电中');
});

test('health records reject non-positive sentinel values and keep named compound values', () => {
  assert.equal(healthValue('心率', 0, 'BPM'), undefined);
  assert.equal(boundedHealthValue('心率', 1, 'BPM', 20, 240), undefined);
  assert.equal(boundedHealthValue('心率', 68, 'BPM', 20, 240)?.value, 68);
  const high = healthValue('收缩压', 128, 'mmHg');
  const low = healthValue('舒张压', 78, 'mmHg');
  assert.equal(healthRecordText({ id: 'x', deviceKey: 'd', metric: 'pressure', timestamp: 1,
    source: 'watch_history', values: [high, low], samples: [], sampleFrequency: 0 }),
  '收缩压 128mmHg · 舒张压 78mmHg');
  assert.equal(healthRecordText({ id: 'e', deviceKey: 'd', metric: 'ecg', timestamp: 1,
    source: 'watch_history', values: [], samples: [1, 2, 3], sampleFrequency: 128 }),
  '真实心电波形 3 点');
});

test('Harmony wearable distance is normalized once from metres to kilometres', () => {
  assert.equal(activityDistanceKilometers(1582, 1892), 1.582);
  assert.equal(activityDistanceKilometers(1.582, 1892), 1.582);
  assert.equal(sportDistanceKilometers(6000), 6);
  assert.equal(sportDistanceKilometers(0), 0);
  const legacy = {
    id: 'activity', deviceKey: 'vep:et488', metric: 'activity', timestamp: 1,
    source: 'watch_history', values: [
      { name: '步数', value: 1892, unit: '步' },
      { name: '距离', value: 1582, unit: 'km' },
    ], samples: [], sampleFrequency: 0,
  };
  const repaired = normalizeLegacyDistanceRecord(legacy);
  assert.equal(repaired.values[1].value, 1.582);
  assert.equal(normalizeLegacyDistanceRecord(repaired), repaired);
});

test('late callbacks cannot update a newer connection generation', () => {
  assert.equal(isCurrentConnectionGeneration(4, 4), true);
  assert.equal(isCurrentConnectionGeneration(3, 4), false);
  assert.equal(isCurrentConnectionGeneration(0, 0), false);
});

test('W9 secondary authentication is not cut off by the former 20 second timeout', () => {
  assert.equal(WEARABLE_CONNECT_TIMEOUT_MS, 45000);
  assert.equal(WEARABLE_AUTO_SYNC_DELAY_MS, 12000);
});

test('one-shot blood oxygen and all manual stop paths have a bounded UI lifetime', () => {
  assert.equal(isOneShotMeasurementMetric('oxygen'), true);
  for (const metric of ['heart', 'pressure', 'temperature', 'glucose', 'bloodComponents',
    'bodyComposition', 'ecg']) assert.equal(isOneShotMeasurementMetric(metric), false);
  assert.equal(WEARABLE_MEASUREMENT_STOP_TIMEOUT_MS, 3500);
  const service = readFileSync(new URL('../entry/src/main/ets/services/VepWearableService.ets', import.meta.url), 'utf8');
  assert.match(service, /this\.withTimeout\(this\.requestMeasurementStop\(metric\), WEARABLE_MEASUREMENT_STOP_TIMEOUT_MS/);
  assert.match(service, /this\.measurement\.status = '本次未收到有效血氧读数，请正确佩戴后重试'/);
  assert.match(service, /if \(this\.measurementStopping\) return/);
});

test('manual stop retains the last valid watch values when the final vendor frame is empty', () => {
  const valid = [{ name: '体温', value: 35.6, unit: '°C' }, { name: '体表温度', value: 29.7, unit: '°C' }];
  assert.deepEqual(retainedMeasurementValues([], valid), valid);
  assert.notEqual(retainedMeasurementValues([], valid), valid);
  const latest = [{ name: '体温', value: 35.8, unit: '°C' }];
  assert.deepEqual(retainedMeasurementValues(latest, valid), latest);
});

test('scan timeout is bounded and stale timeout callbacks cannot stop a newer scan', () => {
  assert.equal(WEARABLE_SCAN_TIMEOUT_MS, 12000);
  const service = readFileSync(new URL('../entry/src/main/ets/services/VepWearableService.ets', import.meta.url), 'utf8');
  const page = readUiSource(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
  assert.match(service, /private scanGeneration: number = 0/);
  assert.match(service, /scanGeneration !== this\.scanGeneration \|\| !this\.scanning/);
  assert.match(service,
    /this\.scanTimer = -1;\s*this\.stopScan\(this\.devices\.length \? '扫描已完成' : '未收到戒指配对信号，请将戒指充电并靠近手机后重试'\)/);
  assert.match(page, /TextTimer\(\{ isCountDown: true, count: WEARABLE_SCAN_TIMEOUT_MS/);
  assert.match(page, /if \(this\.wearablePhase === 'scanning'\)/);
  assert.match(page, /elapsedTime \* 1000 < WEARABLE_SCAN_TIMEOUT_MS/);
  assert.match(page, /Text\(this\.wearablePhase === 'scanning' \? 'searchRingTitle' : 'noRingFound'\)/);
  assert.match(page, /vepWearable\.stopScan\('扫描已完成'\)/);
});

test('automatic post-connect sync waits for JL initialization and excludes advanced commands', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/services/VepWearableService.ets', import.meta.url), 'utf8');
  assert.match(source, /setTimeout\(\(\) => this\.postConnectInitialize\(generation\), WEARABLE_AUTO_SYNC_DELAY_MS\)/);
  assert.match(source, /refreshConnectedDeviceInternal\(generation, descriptor, false\)/);
  assert.match(source, /syncHistoryInternal\(generation, \[HealthQueryDay\.TODAY\], false\)/);
  assert.match(source, /Battery support varies by firmware/);
});

test('a direct device choice supersedes a pending automatic reconnect', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/services/VepWearableService.ets', import.meta.url), 'utf8');
  assert.match(source, /replacesPendingConnection/);
  assert.match(source, /A direct user choice always supersedes a pending automatic reconnect/);
  assert.match(source, /Scanning is also the user's escape hatch from a pending reconnect/);
});

test('wearable records use encrypted indexed range storage without a global save cap', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/services/WearableHealthStore.ets', import.meta.url), 'utf8');
  const schema = readFileSync(new URL('../entry/src/main/ets/model/HealthUpload.ts', import.meta.url), 'utf8');
  assert.match(source, /securityLevel:\s*relationalStore\.SecurityLevel\.S3/);
  assert.match(source, /encrypt:\s*true/);
  assert.match(schema, /idx_owned_health_range.*owner_id, device_key, metric, recorded_at/);
  assert.match(source, /equalTo\('owner_id', owner\)/);
  assert.match(source, /between\('recorded_at'/);
  assert.match(source, /for \(const record of records\)/);
  assert.doesNotMatch(source, /batchInsertWithConflictResolution/);
  assert.doesNotMatch(source, /records\.slice\(0,\s*MAX_LOADED_RECORDS\)/);
});

test('the app depends on the official self-contained Vep HAR only', () => {
  const source = readFileSync(new URL('../entry/oh-package.json5', import.meta.url), 'utf8');
  assert.match(source, /"@veepoo\/vpble-sdk"/);
  assert.match(source, /veepoo-vpble-sdk-1\.0\.0\.har/);
  assert.doesNotMatch(source, /"(?:jl_|bmpconvert|library_par)[^"]*"\s*:/i);
});

test('wearable production service excludes destructive watch operations', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/services/VepWearableService.ets', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /\.otaService\b/);
  assert.doesNotMatch(source, /\.factoryReset\s*\(/);
  assert.doesNotMatch(source, /\.clearData\s*\(/);
  assert.doesNotMatch(source, /\.deleteDial\s*\(/);
  assert.match(source, /WEARABLE_RECONNECT_DELAYS_MS/);
  assert.match(source, /已取消心电测量，未保存未完成波形/);
});
