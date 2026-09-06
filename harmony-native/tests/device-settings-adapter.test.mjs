import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import * as model from '../entry/src/main/ets/model/DeviceSettingsTransactions.ts';

// Execute the production adapter. The legacy SDK setter deliberately reproduces
// the locked HAR's phone-clock override; the full-config setter does not.
let native, currentGeneration = 0;
const sourceURL = new URL('../entry/src/main/ets/services/VepDeviceSettingsAdapter.ets', import.meta.url).href;
globalThis.__unitSafetyDependencies = {
  ...model,
  AlarmClockControl: { SET: 1 },
  VPBleSDK: { getInstance: () => native },
  vepWearable: {
    currentSnapshot: () => ({ capabilities: { alarm: true } }),
    async runDeviceCommand(_name, operation) {
      const generation = currentGeneration;
      const current = () => { if (generation !== currentGeneration) throw new Error('账号或手表已变化'); };
      current(); const result = await operation(current); current(); return result;
    }
  }
};
registerHooks({ load(url, context, next) {
  if (url !== sourceURL) return next(url, context);
  const source = readFileSync(new URL(url), 'utf8').replace(/^import[\s\S]*?;\n/gm, '');
  return { format: 'module', shortCircuit: true, source: stripTypeScriptTypes(
    `const { ${Object.keys(globalThis.__unitSafetyDependencies).join(',')} } = globalThis.__unitSafetyDependencies;\n${source}`) };
} });
const { VepDeviceSettingsAdapter } = await import(sourceURL);
function setup() {
  currentGeneration++;
  const config = { ...model.emptyWatchUnits(), unitSystem: 1, tempUnit: 1, timeFormat: 1,
    heartRateAutoDetect: 2, bloodPressureAutoDetect: 1, ledLevel: 2, bloodGlucoseUnit: 1 };
  const calls = [];
  native = { configService: {
    config: { ...config },
    async getSwitchConfig() { calls.push('read'); return { success: true, data: { ...this.config } }; },
    async setUnitValue(field, value) {
      calls.push('unsafe-setter'); this.config = { ...this.config, [field]: value, timeFormat: 2 };
      return { success: true };
    },
    async setSwitchConfig(value) { calls.push('full-write'); this.config = { ...value }; return { success: true }; }
  } };
  return { adapter: new VepDeviceSettingsAdapter(), sdk: native.configService, config, calls };
}
function deferred() { let resolve; const promise = new Promise(done => { resolve = done; }); return { promise, resolve }; }
async function settle() { for (let i = 0; i < 8; i++) await Promise.resolve(); }

test('actual adapter avoids SDK setUnitValue phone-clock side effect and preserves all fields', async () => {
  const { adapter, sdk, config, calls } = setup();
  await sdk.setUnitValue('unitSystem', 2);
  assert.equal(sdk.config.timeFormat, 2, 'reproduces the SDK behavior with a 12-hour phone');
  sdk.config = { ...config }; calls.length = 0;
  assert.deepEqual(await adapter.setUnit('unitSystem', 2, 1), { ...config, unitSystem: 2 });
  assert.deepEqual(calls, ['read', 'full-write', 'read']);
  assert.equal(sdk.config.timeFormat, 1);
  assert.deepEqual(await adapter.setUnit('tempUnit', 2, 1), { ...config, unitSystem: 2, tempUnit: 2 });
  assert.equal(calls.includes('unsafe-setter'), false);
});
test('actual adapter restores 24-hour mode from a complete fresh snapshot', async () => {
  const { adapter, sdk, config } = setup(); sdk.config.timeFormat = 2;
  assert.deepEqual(await adapter.setUnit('timeFormat', 1, 2), config);
});
test('SDK ACK or mutation of the write argument cannot conceal collateral changes', async () => {
  const { adapter, sdk } = setup();
  sdk.setSwitchConfig = async value => {
    value.timeFormat = 2; sdk.config = { ...value }; return { success: true, data: value };
  };
  await assert.rejects(adapter.setUnit('unitSystem', 2, 1), /其他设置/);
});
test('missing full SDK fields prevent a write even if the two unit fields exist', async () => {
  const { adapter, sdk, calls } = setup();
  sdk.getSwitchConfig = async () => ({ success: true, data: { unitSystem: 1, tempUnit: 1 } });
  await assert.rejects(adapter.setUnit('unitSystem', 2, 1), /不完整/);
  assert.equal(calls.includes('full-write'), false);
});
test('delayed pre-read from an old account cannot write to the next device', async () => {
  const { adapter, sdk, config, calls } = setup(); const reading = deferred();
  sdk.getSwitchConfig = () => reading.promise;
  const result = adapter.setUnit('unitSystem', 2, 1); await settle();
  currentGeneration++;
  reading.resolve({ success: true, data: config });
  await assert.rejects(result, /账号或手表已变化/);
  assert.equal(calls.includes('full-write'), false);
});
test('delayed write ACK after a session change neither reads nor reports success for the new device', async () => {
  const { adapter, sdk, calls } = setup(); const writing = deferred();
  sdk.setSwitchConfig = () => { calls.push('full-write'); return writing.promise; };
  const result = adapter.setUnit('unitSystem', 2, 1); await settle();
  currentGeneration++;
  writing.resolve({ success: true });
  await assert.rejects(result, /账号或手表已变化/);
  assert.deepEqual(calls, ['read', 'full-write']);
});
test('delayed verification read cannot replace the next account settings', async () => {
  const { adapter, sdk, config } = setup(); const reading = deferred(); let count = 0;
  sdk.getSwitchConfig = () => ++count === 1 ? Promise.resolve({ success: true, data: config }) : reading.promise;
  const result = adapter.setUnit('unitSystem', 2, 1); await settle();
  currentGeneration++;
  reading.resolve({ success: true, data: { ...config, unitSystem: 2 } });
  await assert.rejects(result, /账号或手表已变化/);
});
