import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { emptyWatchUnits, supportedWatchUnit, watchUnitChoiceLabel } from '../entry/src/main/ets/model/DeviceSettingsTransactions.ts';

const source = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
const start = source.indexOf('  private async setWatchUnit(');
const method = source.slice(start, source.indexOf('\n  private ', start + 1));
function setup() {
  const calls = [];
  const adapter = { async setUnit(field, value, expected) {
    calls.push({ field, value, expected });
    return { ...page.watchUnits, [field]: value };
  } };
  const Page = new Function('vepDeviceSettings', 'supportedWatchUnit',
    `return ${stripTypeScriptTypes(`class Page {${method}}`)}`)(adapter, supportedWatchUnit);
  const page = new Page();
  Object.assign(page, { watchUnits: { ...emptyWatchUnits(), unitSystem: 1, tempUnit: 1, timeFormat: 2 },
    deviceEditorBusy: false, deviceEditorLoaded: true, deviceEditorGeneration: 1, deviceSettingsWriting: false,
    deviceEditorMessage: '' });
  return { page, adapter, calls };
}
test('production time-format action uses the time-format baseline, not the temperature baseline', async () => {
  const { page, calls } = setup();
  await page.setWatchUnit('timeFormat', 1);
  assert.deepEqual(calls, [{ field: 'timeFormat', value: 1, expected: 2 }]);
  assert.equal(page.watchUnits.timeFormat, 1);
  assert.equal(page.watchUnits.tempUnit, 1);
  assert.equal(page.deviceSettingsWriting, false);
});
test('late page results do not replace a new device editor', async () => {
  const { page, adapter } = setup();
  let resolve; adapter.setUnit = () => new Promise(done => { resolve = done; });
  const operation = page.setWatchUnit('timeFormat', 1);
  page.deviceEditorGeneration++;
  const current = { ...page.watchUnits, timeFormat: 2, tempUnit: 2 };
  page.watchUnits = current;
  resolve({ ...emptyWatchUnits(), timeFormat: 1 }); await operation;
  assert.equal(page.watchUnits, current);
});
test('time labels match locked SDK enums and the page includes the supported time-format card', () => {
  assert.equal(watchUnitChoiceLabel('timeFormat', 1), '24 小时');
  assert.equal(watchUnitChoiceLabel('timeFormat', 2), '12 小时');
  assert.equal(watchUnitChoiceLabel('unitSystem', 1), '公制（千米）');
  assert.equal(watchUnitChoiceLabel('tempUnit', 2), '华氏度（℉）');
  assert.match(source, /this\.WatchUnitCard\(\{ title: '时间格式', field: 'timeFormat', value: this\.watchUnits\.timeFormat \}\)/);
});
