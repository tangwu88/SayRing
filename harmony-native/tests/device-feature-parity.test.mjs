import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { emptyCapabilities } from '../entry/src/main/ets/model/WearableContracts.ts';
import { WATCH_DEVICE_FEATURES, assessmentLabel, autoMeasureLabel, nextWatchItemId,
  normalizedTime, visibleWatchDeviceFeatures, watchContactError } from '../entry/src/main/ets/model/DeviceFeatureContracts.ts';

test('Harmony exposes every Android device feature that has an SDK capability gate', () => {
  assert.deepEqual(WATCH_DEVICE_FEATURES.map(item => item.key), [
    'photoDial', 'camera', 'phoneCalls', 'contacts', 'notifications', 'weather', 'worldClock',
    'healthReminders', 'healthMonitoring', 'healthAssessment', 'screenDisplay'
  ]);
  const capabilities = { ...emptyCapabilities(), photoDial: true, camera: true, phoneCalls: true,
    contacts: true, notification: true, weather: true, worldClock: true, healthReminder: true,
    healthMonitoring: true, healthAssessment: true, screenDisplay: true };
  assert.deepEqual(visibleWatchDeviceFeatures(capabilities).map(item => item.key),
    WATCH_DEVICE_FEATURES.map(item => item.key));
  capabilities.weather = false;
  assert.equal(visibleWatchDeviceFeatures(capabilities).some(item => item.key === 'weather'), false);
});

test('contact and time validation fail closed before a watch write', () => {
  assert.match(watchContactError({ id: 0, name: '', phone: '13800138000', sos: false }), /姓名/);
  assert.match(watchContactError({ id: 0, name: '家人', phone: '123', sos: false }), /电话/);
  assert.equal(watchContactError({ id: 0, name: '家人', phone: '+8613800138000', sos: false }), '');
  assert.equal(normalizedTime('7:05', '08:00'), '07:05');
  assert.equal(normalizedTime('24:00', '08:00'), '08:00');
  assert.equal(nextWatchItemId([1, 3, 4]), 2);
  assert.throws(() => nextWatchItemId([1, 2], 2), /上限/);
});

test('health monitoring and assessment labels remain user-facing', () => {
  assert.equal(autoMeasureLabel(0), '心率自动检测');
  assert.equal(autoMeasureLabel(5), '体温自动检测');
  assert.equal(autoMeasureLabel(8), '血液成分自动检测');
  assert.equal(assessmentLabel(0), '血糖趋势评估');
  assert.match(assessmentLabel(99), /辅助评估/);
});

test('device page routes supported entries to the real SDK adapter and verifies writes', () => {
  const page = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
  const adapter = readFileSync(new URL('../entry/src/main/ets/services/VepDeviceFeatureAdapter.ets', import.meta.url), 'utf8');
  assert.match(page, /visibleWatchDeviceFeatures\(this\.wearableSnapshot\.capabilities\)/);
  assert.match(page, /this\.openDeviceFeature\(feature\.key\)/);
  for (const method of ['readContacts', 'readNotifications', 'readWeather', 'readWorldClocks',
    'readReminders', 'readAutoMeasure', 'readAssessments', 'readScreen']) {
    assert.match(page, new RegExp(`vepDeviceFeatures\\.${method}\\(`), method);
  }
  for (const readback of ['联系人保存后读取失败', '消息通知保存后读取失败', '天气设置保存后读取失败',
    '世界时钟添加后读取失败', '健康监测设置保存失败', '辅助评估保存后读取失败']) {
    assert.match(adapter, new RegExp(readback), readback);
  }
  assert.match(adapter, /手表尚未确认新的 SOS 联系人/);
  assert.match(adapter, /transferZKPhotoDial/);
});

test('W8 adapter does not falsely expose Vep-only feature transactions', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/model/YucWearableContracts.ts', import.meta.url), 'utf8');
  const adapter = readFileSync(new URL('../entry/src/main/ets/services/YucWearableAdapter.ets', import.meta.url), 'utf8');
  for (const key of ['photoDial', 'camera', 'phoneCalls', 'contacts', 'weather', 'worldClock',
    'healthReminder', 'healthMonitoring', 'healthAssessment', 'screenDisplay']) {
    assert.match(source, new RegExp(`${key}: false`), key);
  }
  assert.match(adapter, /YCBTClient\.init\(context, false, false\)/,
    'the W8 SDK must not auto-reconnect a Vep-series watch from its vendor cache');
});
