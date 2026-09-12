import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import * as contracts from '../entry/src/main/ets/model/WearableContracts.ts';
import * as ownership from '../entry/src/main/ets/model/HealthUpload.ts';

// Execute the production ArkTS service with only platform/SDK dependencies replaced.
// Delayed native promises and previously captured listeners remain independently controllable.
const serviceURL = new URL('../entry/src/main/ets/services/VepWearableService.ets', import.meta.url).href;
registerHooks({ load(url, context, next) {
  if (url !== serviceURL) return next(url, context);
  const source = readFileSync(new URL(url), 'utf8').replace(/^import[\s\S]*?;\r?\n/gm, '');
  return { format: 'module', shortCircuit: true, source: stripTypeScriptTypes(
    `const { ${Object.keys(globalThis.__wearableTestDependencies).join(',')} } = globalThis.__wearableTestDependencies;\n${source}`) };
} });
const ConnectionState = { UNINITIALIZED: 0, READY: 1, BINDING: 2, CONNECTED: 3, DISCONNECTING: 4, DISCONNECTED: 5 };
let currentSDK;
const saved = [];
globalThis.__wearableTestDependencies = {
  ...contracts, ...ownership, ConnectionState,
  hid: { createHidHostProfile: () => ({ getConnectedDevices: () => [] }) },
  ble: { off() {}, stopBLEScan() {} },
  VPBleSDK: { getInstance: () => currentSDK },
  DiscoveryPacketCache: class { clear() {} },
  HealthUploadService: class { async synchronize() { return { state: 'complete', pending: 0, uploaded: 0 }; } },
  saydianApi: {}, wearableHealthStore: { async saveRecords(owner, records, isCurrent) { if (isCurrent()) saved.push(...records.map(record => ({ owner, record }))); } },
  HeartRateBrightness: { HIGH: 1 }, SDKEventType: { CONNECTION_STATE_CHANGED: 'connection' },
  HealthQueryDay: { TODAY: 0, YESTERDAY: 1, DAY_BEFORE_YESTERDAY: 2 },
  EcgPushEventKind: { INSTRUCTION: 'instruction', WAVEFORM: 'waveform', PROGRESS: 'progress', RESULT: 'result' },
  BodyCompPushEventKind: { PROGRESS: 'progress' }
};
const { VepWearableService } = await import(serviceURL);

function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
function sdk() {
  const result = { state: ConnectionState.CONNECTED, disconnects: 0,
    getState() { return this.state; }, disconnect() { this.disconnects++; this.state = ConnectionState.DISCONNECTED; },
    on() {}, off() {} };
  for (const [name, callback] of [
    ['heartRate', 'HeartRate'], ['bloodPressure', 'BloodPressure'], ['bloodOxygen', 'SpO2'],
    ['bodyTemperature', 'BodyTemp'], ['bloodSugar', 'BloodSugar'], ['bloodComponents', 'BloodComponents'],
    ['bodyComposition', 'BodyComp'], ['ecg', 'Ecg']
  ]) {
    result[`${name}Service`] = {
      async startMeasurement() { return { success: true }; },
      async stopMeasurement() { return { success: true }; },
      [`on${callback}Push`](listener) { this.listener = listener; },
      [`off${callback}Push`](listener) { if (this.listener === listener) this.listener = undefined; }
    };
  }
  return result;
}
function setup() {
  saved.length = 0;
  globalThis.__wearableTestDependencies.wearableHealthStore.loadSportRecords = async () => [];
  currentSDK = sdk();
  const service = new VepWearableService();
  service.accountSession = { ownerId: 'ownerA', generation: 1 };
  connect(service, 'watchA');
  return { service, native: currentSDK };
}
function connect(service, key) {
  service.sdk.state = ConnectionState.CONNECTED;
  service.activeProvider = 'Vep';
  service.connectedKey = key;
  service.connectionGeneration++;
  service.ownershipSince = Date.now() - 1000;
  service.snapshot = { ...contracts.emptyWearableSnapshot(), provider: 'Vep', connected: true, deviceKey: key,
    capabilities: { ...contracts.emptyWearableSnapshot().capabilities, heart: true, oxygen: true, ecg: true } };
}
async function settle() { for (let i = 0; i < 8; i++) await Promise.resolve(); }

test('saved sport history remains readable after disconnect and same-owner cold restart without SDK access', async () => {
  const { service, native } = setup();
  const rows = [{ id: 'sport-old', deviceKey: 'watchOld', metric: 'sport', timestamp: 1,
    source: 'watch_history', values: [{ name: '距离', value: 2, unit: 'km' }], samples: [], sampleFrequency: 0 }];
  const owners = [];
  globalThis.__wearableTestDependencies.wearableHealthStore.loadSportRecords = async owner => { owners.push(owner); return rows; };
  await service.disconnect();
  assert.equal(service.snapshot.connected, false);
  assert.deepEqual(await service.savedSportRecords(), rows);
  const restarted = new VepWearableService();
  restarted.accountSession = { ownerId: 'ownerA', generation: 50 };
  assert.deepEqual(await restarted.savedSportRecords(), rows);
  assert.deepEqual(owners, ['ownerA', 'ownerA']);
  assert.equal(native.disconnects, 1);
});
test('saved sport read refuses account-switch and same-owner relogin late results', async () => {
  for (const ownerId of ['ownerB', 'ownerA']) {
    const { service } = setup();
    const read = deferred();
    globalThis.__wearableTestDependencies.wearableHealthStore.loadSportRecords = () => read.promise;
    const loading = service.savedSportRecords();
    service.accountSession = { ownerId, generation: 2 };
    read.resolve([{ id: 'old-owner-private' }]);
    await assert.rejects(loading, /账号已变化/);
  }
});
test('signed-out sport history never queries the database', async () => {
  const { service } = setup();
  service.accountSession = { ownerId: '', generation: 2 };
  globalThis.__wearableTestDependencies.wearableHealthStore.loadSportRecords = () => { throw new Error('must not query'); };
  assert.deepEqual(await service.savedSportRecords(), []);
});

test('old stop after account switch neither saves A values under B nor releases B operation', async () => {
  const { service, native } = setup();
  await service.startMeasurement('heart');
  native.heartRateService.listener({ heartRate: 73 });
  const stopped = deferred();
  native.heartRateService.stopMeasurement = () => stopped.promise;
  const stop = service.stopMeasurement();
  service.updateAccountSession({ ownerId: 'ownerB', generation: 2 });
  let ready = false;
  const transitioning = service.accountWearableReady().then(value => { ready = value; });
  await settle();
  assert.equal(ready, false);
  assert.equal(await service.startMeasurement('heart'), false);
  stopped.resolve({ success: true });
  await stop; await transitioning;
  assert.equal(ready, true);
  assert.equal(saved.length, 0);
  connect(service, 'watchB');
  assert.equal(await service.startMeasurement('heart'), true);
  assert.equal(service.busyOperation, '手动测量');
  assert.deepEqual(service.currentMeasurement().values, []);
});

test('late old start result cannot complete a newer account measurement', async () => {
  const { service, native } = setup();
  const first = deferred();
  native.bloodOxygenService.startMeasurement = () => first.promise;
  const start = service.startMeasurement('oxygen');
  service.updateAccountSession({ ownerId: 'ownerB', generation: 2 });
  const transition = service.accountWearableReady();
  await settle();
  first.resolve({ success: true, data: { spO2: 99 } });
  assert.equal(await start, false);
  assert.equal(await transition, true);
  assert.equal(saved.length, 0);
  assert.deepEqual(service.currentMeasurement().values, []);
});

test('captured SDK callbacks are scoped to the exact measurement, even with the same metric', async () => {
  const { service, native } = setup();
  await service.startMeasurement('heart');
  const oldListener = native.heartRateService.listener;
  oldListener({ heartRate: 73 });
  await service.stopMeasurement();
  await settle();
  assert.equal(saved.length, 1);
  await service.startMeasurement('heart');
  oldListener({ heartRate: 155 });
  assert.deepEqual(service.currentMeasurement().values, []);
  native.heartRateService.listener({ heartRate: 76 });
  assert.equal(service.currentMeasurement().values[0].value, 76);
});

test('old start rejection after stop and a new command cannot clear the new lock', async () => {
  const { service, native } = setup();
  const first = deferred();
  native.heartRateService.startMeasurement = () => first.promise;
  const start = service.startMeasurement('heart');
  await service.stopMeasurement();
  const command = deferred();
  const operation = service.runDeviceCommand('单位设置', async assertCurrent => { await command.promise; assertCurrent(); return true; });
  first.reject(new Error('old native start failed'));
  assert.equal(await start, false);
  assert.equal(service.busyOperation, '单位设置');
  command.resolve();
  assert.equal(await operation, true);
});

test('cancelled ECG never persists a waveform and disconnect clears the running state', async () => {
  const { service, native } = setup();
  await service.startMeasurement('ecg');
  native.ecgService.listener({ kind: 'waveform', data: { samples: [1, 2, 3] } });
  await service.stopMeasurement(); await settle();
  assert.equal(saved.length, 0);
  assert.deepEqual(service.currentMeasurement().samples, []);
  await service.startMeasurement('heart');
  await service.disconnect();
  assert.equal(service.currentMeasurement().running, false);
  assert.equal(service.currentSnapshot().connected, false);
});

test('device transaction fences write after account change and cannot release another lock', async () => {
  const { service } = setup();
  const read = deferred();
  let writes = 0;
  const operation = service.runDeviceCommand('保存设置', async assertCurrent => {
    await read.promise; assertCurrent(); writes++; return true;
  });
  service.updateAccountSession({ ownerId: 'ownerB', generation: 2 });
  await service.accountWearableReady();
  connect(service, 'watchB');
  await service.startMeasurement('heart');
  read.resolve();
  await assert.rejects(operation, /账号或戒指已变化/);
  assert.equal(writes, 0);
  assert.equal(service.busyOperation, '手动测量');
});

test('firmware version is never used as a device model name', () => {
  const source = readFileSync(new URL(serviceURL), 'utf8');
  assert.match(source, /model: device\.modelName \|\| ''/);
  assert.doesNotMatch(source, /model:.*deviceFullVersion/);
});

test('first login with an uninitialized SDK does not require a nonexistent disconnect', async () => {
  const { service, native } = setup();
  native.state = ConnectionState.UNINITIALIZED;
  native.disconnect = () => { throw new Error('SDK not initialized'); };
  service.snapshot = contracts.emptyWearableSnapshot();
  service.updateAccountSession({ ownerId: 'ownerB', generation: 2 });
  assert.equal(await service.accountWearableReady(), true);
  assert.equal(service.accountTeardownFailed, false);
});

function prepareNextConnection(service, native) {
  let connects = 0;
  // Use a production-routable VEP ring name. Unknown or legacy watch names
  // must not bypass the Say Ring provider classifier during reconnect tests.
  service.devices = [{ key: 'watchB', provider: 'Vep', name: 'V-Ring', mac: '', rssi: -50 }];
  service.vepDevices.set('watchB', { deviceId: 'watchB' });
  native.deviceLabel = 'watchA';
  native.connectDevice = async () => {
    connects++; native.deviceLabel = 'watchB'; native.state = ConnectionState.CONNECTED;
    return { success: true };
  };
  service.refreshConnectedDeviceInternal = async () => {
    service.snapshot = { ...contracts.emptyWearableSnapshot(), connected: true, deviceKey: 'watchB', deviceName: 'V-Ring' };
  };
  service.loadStoredRecords = async () => {};
  service.postConnectInitialize = () => {};
  service.scheduleReconnect = () => {};
  globalThis.__wearableTestDependencies.wearableHealthStore.claimDevice = async () => Date.now();
  return () => connects;
}

// Keep each public operation real. Only its first native promise is delayed;
// calls after that boundary reveal whether stale multi-step work continues.
function legacyCommand(service, native, method, gate) {
  const followups = [];
  service.snapshot.capabilities = { ...service.snapshot.capabilities,
    findDevice: true, dial: true, notification: true, alarm: true, sedentaryReminder: true };
  native.getConnectedDevice = () => ({ deviceName: 'V-Ring', featureList: { heartRateFunction: 1 } });
  native.deviceService = { getBatteryInfo: () => gate.promise };
  native.ecgService.getSavedId = async () => ({ success: false });
  native.deviceControlService = { findDevice: () => gate.promise, syncTimeNow: () => gate.promise };
  native.healthService = { getHealthData: () => gate.promise,
    async getSleepData() { followups.push('sleep'); return { success: false }; } };
  native.configService = { getSwitchConfig: () => gate.promise,
    async getMsgSwitchConfig() { followups.push('messages'); return { success: false }; } };
  native.reminderService = { async getSedentaryReminder() { followups.push('sedentary'); return { success: false }; } };
  native.alarmClockService = { async readAll() { followups.push('alarms'); return { success: false }; } };
  native.dialService = { getDialFileList: () => gate.promise, setUsingDial: () => gate.promise,
    async getCurrentDial() { followups.push('current-dial'); return { success: false }; } };
  service.dialFiles.set('original', { path: 'original', fileName: 'Original' });
  const operation = method === 'setExistingDial' ? service.setExistingDial('original') :
    method === 'postConnectInitialize' ? service.postConnectInitialize(service.connectionGeneration) : service[method]();
  return { operation, followups };
}

const legacyCommands = ['findDevice', 'refresh', 'syncHistory', 'readDeviceConfiguration', 'readDials',
  'syncTime', 'setExistingDial', 'postConnectInitialize'];
for (const method of legacyCommands) {
  test(`${method}: normal same-session completion releases its own lock without nested deadlock`, async () => {
    const { service, native } = setup(), gate = deferred();
    const { operation } = legacyCommand(service, native, method, gate);
    const dial = { path: 'original', fileName: 'Original' };
    native.dialService.getCurrentDial = async () => ({ success: true, dial });
    await settle();
    assert.notEqual(service.deviceCommandInFlight, undefined);
    assert.equal(await service.startMeasurement('heart'), false);
    gate.resolve(method === 'setExistingDial' ? true : method === 'readDials' ? { success: true, list: [dial] } :
      method === 'readDeviceConfiguration' ? { success: true, data: { unitSystem: 1, timeFormat: 1 } } :
      { success: method === 'findDevice' || method === 'syncTime' });
    const completed = await operation;
    assert.equal(completed, method === 'postConnectInitialize' ? undefined : true);
    assert.equal(service.deviceCommandInFlight, undefined);
    assert.equal(service.busyOperation, '');
    assert.equal(service.currentSnapshot().connected, true);
    assert.equal(native.disconnects, 0);
  });
  for (const rejected of [false, true]) {
    test(`${method}: disconnect drains the actual ${rejected ? 'rejected' : 'resolved'} SDK promise before reconnect`, async (t) => {
      t.mock.timers.enable({ apis: ['setTimeout'] });
      const { service, native } = setup(), gate = deferred();
      const { operation, followups } = legacyCommand(service, native, method, gate);
      await settle();
      assert.notEqual(service.deviceCommandInFlight, undefined);
      const count = prepareNextConnection(service, native);
      await service.disconnect();
      assert.equal(service.currentSnapshot().connected, false);
      assert.equal(native.state, ConnectionState.DISCONNECTED);
      const next = service.connect('watchB'); await settle();
      assert.equal(count(), 0);
      assert.notEqual(service.deviceCommandInFlight, undefined);
      if (rejected) gate.reject(new Error('synthetic native failure'));
      else gate.resolve({ success: false });
      await operation;
      assert.equal(await next, true);
      assert.equal(count(), 1);
      assert.deepEqual(followups, []);
      assert.equal(service.currentSnapshot().deviceKey, 'watchB');
      assert.equal(service.deviceCommandInFlight, undefined);
    });
  }
  test(`${method}: account transition cannot reuse the SDK before the old command settles`, async (t) => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const { service, native } = setup(), gate = deferred();
    const { operation, followups } = legacyCommand(service, native, method, gate);
    await settle(); const count = prepareNextConnection(service, native);
    service.updateAccountSession({ ownerId: 'ownerB', generation: 2 });
    const next = service.connect('watchB'); await settle();
    assert.equal(count(), 0);
    assert.equal(service.accountTeardownPending, true);
    gate.resolve({ success: false }); await operation;
    assert.equal(await next, true);
    assert.deepEqual(followups, []);
    assert.equal(saved.length, 0);
  });
}

test('late old find result neither clears a newer lock nor lets measurement overlap a pending command', async () => {
  const { service, native } = setup(), gate = deferred();
  const { operation } = legacyCommand(service, native, 'findDevice', gate);
  await settle(); await service.disconnect();
  connect(service, 'watchB'); // Even a stray connected callback must not bypass the remaining native promise.
  assert.equal(await service.startMeasurement('heart'), false);
  service.busyOperation = 'newer-operation'; ++service.operationGeneration;
  gate.resolve({ success: true }); await operation;
  assert.equal(service.busyOperation, 'newer-operation');
  assert.equal(service.currentSnapshot().deviceKey, 'watchB');
});

test('legacy native timeouts remain pending until actual settlement, not a fabricated disconnect failure', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { service, native } = setup(), gate = deferred();
  const { operation } = legacyCommand(service, native, 'findDevice', gate);
  await settle(); const count = prepareNextConnection(service, native);
  await service.disconnect();
  const timeout = service.withTimeout.bind(service);
  service.withTimeout = (value, ms, message) => message === '旧戒指指令尚未结束' ?
    Promise.reject(new Error(message)) : timeout(value, ms, message);
  assert.equal(await service.connect('watchB'), false);
  assert.equal(await service.connect('watchB'), false);
  assert.equal(count(), 0);
  assert.equal(service.currentSnapshot().connected, false);
  assert.notEqual(service.deviceCommandInFlight, undefined);
  gate.resolve({ success: true }); await operation;
  service.withTimeout = timeout;
  assert.equal(await service.connect('watchB'), true);
});

test('explicit disconnect waits for native DISCONNECTED without waiting forever for an old command', async () => {
  const { service, native } = setup(), gate = deferred(), nativeClosed = deferred();
  const { operation } = legacyCommand(service, native, 'findDevice', gate);
  await settle();
  const phases = []; service.listener = { onPhase: (phase, message) => phases.push([phase, message]) };
  native.disconnect = () => { native.state = ConnectionState.DISCONNECTING; };
  service.delay = () => nativeClosed.promise;
  let completed = false;
  const disconnect = service.disconnect().then(() => { completed = true; });
  await settle();
  assert.equal(completed, false);
  assert.equal(phases.some(([phase, message]) => phase === 'idle' && message === '已断开戒指'), false);
  native.state = ConnectionState.DISCONNECTED; nativeClosed.resolve(); await disconnect;
  assert.equal(completed, true);
  assert.notEqual(service.deviceCommandInFlight, undefined);
  assert.equal(phases.at(-1)[0], 'idle');
  gate.resolve({ success: true }); await operation;
});

test('unconfirmed native disconnect is an error and reconnect stays closed until native teardown succeeds', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { service, native } = setup(); const count = prepareNextConnection(service, native);
  native.disconnect = () => {};
  service.delay = async () => {};
  const phases = []; service.listener = { onPhase: (phase, message) => phases.push([phase, message]) };
  await service.disconnect();
  assert.equal(service.accountTeardownFailed, true);
  assert.equal(phases.at(-1)[0], 'error');
  assert.match(service.currentSnapshot().message, /尚未确认/);
  assert.equal(await service.connect('watchB'), false);
  assert.equal(count(), 0);
  native.disconnect = () => { native.state = ConnectionState.DISCONNECTED; };
  assert.equal(await service.connect('watchB'), true);
  assert.equal(service.accountTeardownFailed, false);
});

test('manual disconnect cannot reconnect while a two-packet native command is still running', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { service, native } = setup(); const count = prepareNextConnection(service, native);
  const firstPacket = deferred(), packetTargets = [];
  const operation = service.runDeviceCommand('保存单位', async () => {
    packetTargets.push(native.deviceLabel);
    await firstPacket.promise;
    packetTargets.push(native.deviceLabel); // SDK-internal await cannot invoke our fence.
    return true;
  });
  await settle(); await service.disconnect();
  let connected = false;
  const next = service.connect('watchB').then(result => { connected = result; return result; });
  await settle();
  assert.equal(count(), 0);
  assert.equal(connected, false);
  assert.equal(service.currentSnapshot().connected, false);
  firstPacket.resolve();
  await assert.rejects(operation, /账号或戒指已变化/);
  assert.equal(await next, true);
  assert.deepEqual(packetTargets, ['watchA', 'watchA']);
  assert.equal(count(), 1);
  assert.equal(service.currentSnapshot().deviceKey, 'watchB');
});

test('account transition drains the SDK command before giving a new account the same singleton', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { service, native } = setup(); const count = prepareNextConnection(service, native);
  const firstPacket = deferred();
  const operation = service.runDeviceCommand('读取完整配置', async () => { await firstPacket.promise; return true; });
  await settle();
  service.updateAccountSession({ ownerId: 'ownerB', generation: 2 });
  const next = service.connect('watchB'); await settle();
  assert.equal(service.accountTeardownPending, true);
  assert.equal(count(), 0);
  firstPacket.resolve();
  await assert.rejects(operation, /账号或戒指已变化/);
  assert.equal(await next, true);
  assert.equal(service.deviceCommandInFlight, undefined);
});

test('repeated drain timeouts never mean cancelled; only actual settlement allows reconnect', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { service, native } = setup(); const count = prepareNextConnection(service, native);
  const firstPacket = deferred();
  const operation = service.runDeviceCommand('保存配置', async () => { await firstPacket.promise; return true; });
  await settle(); await service.disconnect();
  const timeout = service.withTimeout.bind(service);
  service.withTimeout = (value, ms, message) => message === '旧戒指指令尚未结束' ?
    Promise.reject(new Error(message)) : timeout(value, ms, message);
  assert.equal(await service.connect('watchB'), false);
  assert.equal(await service.connect('watchB'), false);
  assert.notEqual(service.deviceCommandInFlight, undefined);
  assert.equal(service.currentSnapshot().connected, false);
  assert.equal(count(), 0);
  firstPacket.resolve();
  await assert.rejects(operation, /账号或戒指已变化/);
  service.withTimeout = timeout;
  assert.equal(await service.connect('watchB'), true);
  assert.equal(count(), 1);
});

test('a failed native command settles without permanently blocking later connections', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const { service, native } = setup(); const count = prepareNextConnection(service, native);
  const firstPacket = deferred();
  const operation = service.runDeviceCommand('保存配置', async () => { await firstPacket.promise; throw new Error('native rejected'); });
  await settle(); await service.disconnect();
  const next = service.connect('watchB'); await settle();
  assert.equal(count(), 0);
  firstPacket.resolve();
  await assert.rejects(operation, /native rejected/);
  assert.equal(await next, true);
  assert.equal(service.deviceCommandInFlight, undefined);
});

test('ECG transport sentinel HRV 255 is neither shown nor persisted', async () => {
  const { service, native } = setup();
  await service.startMeasurement('ecg');
  native.ecgService.listener({ kind: 'progress', data: { wearStatus: 0, progress: 50,
    hrPerMinute: 73, hrv: 255, qtc: 400 } });
  assert.equal(service.currentMeasurement().values.some(value => value.name === 'HRV'), false);
  native.ecgService.listener({ kind: 'waveform', data: { samples: [0.1, 0.3, -0.2] } });
  native.ecgService.listener({ kind: 'result', data: { heartRate: 73, hrv: 255, qtc: 400 } });
  await settle();
  assert.equal(saved.length, 1);
  assert.equal(saved[0].record.values.some(value => value.name === 'HRV'), false);
  assert.equal(saved[0].record.values.find(value => value.name === '心率').value, 73);
  assert.equal(native.disconnects, 0);
});

test('failed ECG electrode wear cancels once, clears incomplete signals, and keeps BLE connected', async () => {
  const { service, native } = setup();
  await service.startMeasurement('ecg');
  const listener = native.ecgService.listener;
  listener({ kind: 'waveform', data: { samples: [0.1, 0.3, -0.2] } });
  const stopping = deferred(); let stopCalls = 0;
  native.ecgService.stopMeasurement = () => { stopCalls++; return stopping.promise; };
  listener({ kind: 'progress', data: { wearStatus: 1, progress: 50, hrPerMinute: 73, hrv: 255, qtc: 400 } });
  listener({ kind: 'progress', data: { wearStatus: 1, progress: 100 } });
  listener({ kind: 'result', data: { heartRate: 73, hrv: 45, qtc: 400 } });
  assert.equal(stopCalls, 1);
  assert.equal(service.busyOperation, '手动测量');
  assert.equal(saved.length, 0);
  stopping.resolve({ success: true }); await settle();
  assert.equal(service.currentMeasurement().running, false);
  assert.deepEqual(service.currentMeasurement().values, []);
  assert.deepEqual(service.currentMeasurement().samples, []);
  assert.match(service.currentMeasurement().status, /调整佩戴.*接触电极/);
  assert.equal(service.busyOperation, '');
  assert.equal(service.currentSnapshot().connected, true);
  assert.equal(native.disconnects, 0);
  assert.equal(saved.length, 0);
});

test('unknown electrode state is not treated as valid wear or a diagnosed failure', async () => {
  const { service, native } = setup();
  await service.startMeasurement('ecg');
  let stopCalls = 0;
  native.ecgService.stopMeasurement = async () => { stopCalls++; return { success: true }; };
  native.ecgService.listener({ kind: 'instruction', data: { samplingFreq: 250, electrodeSwitch: 0 } });
  assert.doesNotMatch(service.currentMeasurement().status, /已连接/);
  native.ecgService.listener({ kind: 'progress', data: { wearStatus: 2, progress: 30,
    hrPerMinute: 73, hrv: 45, qtc: 400 } });
  assert.deepEqual(service.currentMeasurement().values, []);
  assert.equal(service.currentMeasurement().running, true);
  assert.equal(stopCalls, 0);
  native.ecgService.listener({ kind: 'waveform', data: { samples: [0.1, 0.3, -0.2] } });
  native.ecgService.listener({ kind: 'result', data: { heartRate: 73, hrv: 45, qtc: 400 } });
  await settle();
  assert.equal(stopCalls, 1);
  assert.equal(saved.length, 0);
  assert.match(service.currentMeasurement().status, /未确认有效佩戴/);
  assert.equal(native.disconnects, 0);
});

test('valid wear and non-sentinel HRV completes while later measurements must confirm wear again', async () => {
  const { service, native } = setup();
  await service.startMeasurement('ecg');
  native.ecgService.listener({ kind: 'progress', data: { wearStatus: 0, progress: 80,
    hrPerMinute: 73, hrv: 45, qtc: 400 } });
  assert.equal(service.currentMeasurement().values.find(value => value.name === 'HRV').value, 45);
  native.ecgService.listener({ kind: 'result', data: { heartRate: 73, hrv: 45, qtc: 400 } });
  await settle();
  assert.equal(saved.length, 1);
  await service.startMeasurement('ecg');
  native.ecgService.listener({ kind: 'result', data: { heartRate: 73, hrv: 45, qtc: 400 } });
  await settle();
  assert.equal(saved.length, 1);
});

test('late wear-failure cancellation after account switch cannot change a newer measurement', async () => {
  const { service, native } = setup();
  await service.startMeasurement('ecg');
  const stopping = deferred();
  native.ecgService.stopMeasurement = () => stopping.promise;
  native.ecgService.listener({ kind: 'progress', data: { wearStatus: 1, progress: 0, hrv: 255 } });
  service.updateAccountSession({ ownerId: 'ownerB', generation: 2 });
  const ready = service.accountWearableReady();
  stopping.resolve({ success: true }); await ready;
  connect(service, 'watchB');
  await service.startMeasurement('heart'); await settle();
  assert.equal(service.currentMeasurement().metric, 'heart');
  assert.equal(service.currentMeasurement().running, true);
  assert.doesNotMatch(service.currentMeasurement().status, /调整佩戴|未确认/);
  assert.equal(service.busyOperation, '手动测量');
  assert.equal(saved.length, 0);
});
