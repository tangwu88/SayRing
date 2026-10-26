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

test('passive records are not discarded outside explicit sync or promoted to manual', () => {
  const collect = native.slice(native.indexOf('private void collectHealth('), native.indexOf('private void collectSport('));
  assert.doesNotMatch(collect, /if \(pendingHealthSync == null/);
  assert.match(collect, /record.put\("rawVersion", 2\)/);
  assert.match(collect, /emit\("healthRecord", record\)/);
  const post = native.slice(native.indexOf('private void postCurrentPacket('), native.indexOf('private void collectHealth('));
  assert.match(post, /epoch != connectionEpoch/);
  assert.match(post, /!target.equals\(connectedId\)/);
});

test('sport HR uses real SDK stream and cannot start across active history sync', () => {
  assert.match(native, /!requiresActive && \(pendingHealthSync != null \|\| pendingSportSync != null\)/);
  assert.match(native, /updateSportHeartStream\(status == K6_SEND_APP_SPORT_STRUCT.SPORT_STATUS_START/);
  assert.match(native, /functionControl.isHr_measure_button\(\)/);
  assert.match(native, /canStart \? CEBC.OPENSTATUS.OPEN : CEBC.OPENSTATUS.CLOSE/);
});
