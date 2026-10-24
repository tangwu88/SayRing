import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const native = readFileSync(new URL('../android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java', import.meta.url), 'utf8');
test('history reception never rewrites SDK installation-wide device configuration', () => {
  const sync = native.slice(native.indexOf('private void startSync('), native.indexOf('private void failPendingSync('));
  assert.match(sync, /helper\.setEnableGsDataTrans\(true\)/);
  assert.match(sync, /getSendDataManager\(\)\.sendAsynInfo\(\)/);
  assert.doesNotMatch(sync, /helper\.synDevData\(\)|\.success\(|sendClear|unbindDevice/);
  assert.doesNotMatch(native, /main\.post\(this::completeSync\)/);
});
test('sport reader joins health stream and the deadline follows valid packets', () => {
  assert.match(native, /sportOnly && pendingHealthSync != null && pendingSportSync == null/);
  assert.match(native, /pendingSportSync == null && pendingHealthSync == null/);
  assert.match(native, /syncWindow\.received\(SystemClock\.elapsedRealtime\(\)\)/);
  assert.match(native, /syncDeadline != this \|\| syncWindow == null/);
  assert.match(native, /"COOLWEAR_SYNC_TIMEOUT"\.equals\(code\) \? partialHealth : null/);
});
