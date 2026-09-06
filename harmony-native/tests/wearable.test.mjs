import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  batteryText, boundedHealthValue, capabilitiesFromFeatureList, cleanDeviceName, createWearableDevice,
  healthRecordText, healthValue, isCurrentConnectionGeneration, mergeWearableDevices,
  normalizeMac, wearableIdentifierText, wearableProviderForName, WEARABLE_AUTO_SYNC_DELAY_MS,
  WEARABLE_CONNECT_TIMEOUT_MS, WEARABLE_SCAN_TIMEOUT_MS,
} from '../entry/src/main/ets/model/WearableContracts.ts';

test('all names containing W8 are classified as Yuc while Vep names remain Vep', () => {
  for (const name of ['W8 8211', 'w8s 4DE9', 'W8-ultra 37FD', 'SD-W8-Pro']) {
    assert.equal(wearableProviderForName(name), 'Yuc');
  }
  for (const name of ['ET488', 'SD-Watch-W9', 'SD-WATCH-W9S']) {
    assert.equal(wearableProviderForName(name), 'Vep');
  }
});

test('device names remove control bytes and do not allow blank labels', () => {
  assert.equal(cleanDeviceName('  SD\u0000-Watch\n-W9S  '), 'SD-Watch-W9S');
  assert.equal(cleanDeviceName(' \n '), '未知设备');
});

test('only verified six-byte addresses are presented as MAC', () => {
  assert.equal(normalizeMac('9b-21-62-9f-17-bf'), '9B:21:62:9F:17:BF');
  assert.equal(normalizeMac('36CE3B81-94C2-9B3F-C30F-BE9AB1EB2C7D'), '');
  assert.equal(normalizeMac('00:00:00:00:00:00'), '');
  const virtual = createWearableDevice('Vep', 'W9S', '36CE3B81-94C2-9B3F-C30F-BE9AB1EB2C7D', '', -42, true);
  assert.match(wearableIdentifierText(virtual), /^设备标识/);
  const real = createWearableDevice('Vep', 'W9S', 'virtual-id', '9B:21:62:9F:17:BF', -42, true);
  assert.equal(wearableIdentifierText(real), 'MAC · 9B:21:62:9F:17:BF');
});

test('scan results deduplicate and update signal without mixing providers', () => {
  const weak = createWearableDevice('Vep', 'ET488', 'transport-a', '11:22:33:44:55:66', -90, true);
  const strong = createWearableDevice('Vep', 'ET488', 'transport-b', '11:22:33:44:55:66', -45, true);
  const yuc = createWearableDevice('Yuc', 'W8 8211', 'transport-y', '', -60, true);
  const merged = mergeWearableDevices([weak], [strong, yuc]);
  assert.equal(merged.length, 2);
  assert.equal(merged[0].provider, 'Vep');
  assert.equal(merged[0].rssi, -45);
  assert.equal(merged[1].provider, 'Yuc');
});

test('capabilities follow the vendor flags including inverted heart-rate support', () => {
  const supported = capabilitiesFromFeatureList({
    dailyDataDays: 3, heartRateFunction: 0, bloodPressure: 1, bloodOxygen: 1,
    bodyTemp: 1, bloodGlucose: 1, hrv: 1, ecgFunction: 1, bodyComposition: 1,
    bloodComposition: 1, sportModeCount: 20, newAlarm: 1, healthReminder: 1,
    messageNotifyPackets: 2, findBand: 1, moreWatchfaceCount: 3,
  });
  for (const value of Object.values(supported)) assert.equal(value, true);
  assert.equal(capabilitiesFromFeatureList({ heartRateFunction: 1 }).heart, false);
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

test('late callbacks cannot update a newer connection generation', () => {
  assert.equal(isCurrentConnectionGeneration(4, 4), true);
  assert.equal(isCurrentConnectionGeneration(3, 4), false);
  assert.equal(isCurrentConnectionGeneration(0, 0), false);
});

test('W9 secondary authentication is not cut off by the former 20 second timeout', () => {
  assert.equal(WEARABLE_CONNECT_TIMEOUT_MS, 45000);
  assert.equal(WEARABLE_AUTO_SYNC_DELAY_MS, 12000);
});

test('scan timeout is bounded and stale timeout callbacks cannot stop a newer scan', () => {
  assert.equal(WEARABLE_SCAN_TIMEOUT_MS, 12000);
  const service = readFileSync(new URL('../entry/src/main/ets/services/VepWearableService.ets', import.meta.url), 'utf8');
  const page = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
  assert.match(service, /private scanGeneration: number = 0/);
  assert.match(service, /scanGeneration !== this\.scanGeneration \|\| !this\.scanning/);
  assert.match(service,
    /this\.scanTimer = -1;\s*this\.stopScan\(this\.devices\.length \? '扫描已完成' : '未收到手表配对信号，请打开手表配对页后重试'\)/);
  assert.match(page, /TextTimer\(\{ isCountDown: true, count: WEARABLE_SCAN_TIMEOUT_MS/);
  assert.match(page, /if \(this\.wearablePhase === 'scanning'\)/);
  assert.match(page, /elapsedTime \* 1000 < WEARABLE_SCAN_TIMEOUT_MS/);
  assert.match(page, /Text\(this\.wearablePhase === 'scanning' \? '正在查找手表' : '暂未发现设备'\)/);
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
  assert.match(source, /securityLevel:\s*relationalStore\.SecurityLevel\.S3/);
  assert.match(source, /encrypt:\s*true/);
  assert.match(source, /idx_wearable_metric_time/);
  assert.match(source, /between\('recorded_at'/);
  assert.match(source, /for \(let offset = 0; offset < records\.length;/);
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
