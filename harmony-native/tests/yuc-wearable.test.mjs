import test from 'node:test';
import assert from 'node:assert/strict';
import {
  emptyYucFeatureFlags, yucCapabilitiesFromFlags, yucDecimalValue,
  yucSportCapabilityFromFlags, yucSportModeFromProtocolValue,
  yucSportModeProtocolValue, yucValidTimestamp,
} from '../entry/src/main/ets/model/YucWearableContracts.ts';

test('W8 sport commands use the vendor 2.1.5 values and never rope skipping', () => {
  assert.deepEqual([
    yucSportModeProtocolValue('running'), yucSportModeProtocolValue('walking'),
    yucSportModeProtocolValue('cycling'), yucSportModeProtocolValue('hiking'),
  ], [0x0F, 0x10, 0x03, 0x1B]);
  assert.equal(yucSportModeFromProtocolValue(0x06), '');
  assert.equal(yucSportModeFromProtocolValue(0x0B), 'hiking');
});

test('W8 capabilities and available sport modes only follow reported feature flags', () => {
  const flags = { ...emptyYucFeatureFlags(), step: true, sleep: true, heart: true,
    pressure: true, oxygen: true, temperature: true, glucose: true, hrv: true,
    ecg: true, sport: true, sportPause: true, outdoorRunning: true,
    outdoorWalking: true, cycling: false, hiking: true, findDevice: true };
  const caps = yucCapabilitiesFromFlags(flags);
  assert.equal(caps.activity, true);
  assert.equal(caps.findDevice, true);
  assert.equal(caps.dial, false);
  assert.equal(caps.bodyComposition, false);
  assert.deepEqual(yucSportCapabilityFromFlags(flags), {
    modes: ['running', 'walking', 'hiking'], supportsPause: true, protocol: 'realtime',
  });
  assert.deepEqual(yucSportCapabilityFromFlags(), { modes: [], supportsPause: false, protocol: 'none' });
});

test('W8 decimals and timestamps normalize once and reject invalid sentinels', () => {
  assert.equal(yucDecimalValue(36, 5), 36.5);
  assert.equal(yucDecimalValue(5, 25, 100), 5.25);
  const milliseconds = Date.UTC(2026, 8, 7, 8, 0, 0);
  assert.equal(yucValidTimestamp(milliseconds), milliseconds);
  assert.equal(yucValidTimestamp(milliseconds / 1000), milliseconds);
  assert.equal(yucValidTimestamp(0), 0);
});
