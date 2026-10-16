import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');

test('iOS monitoring preserves complete firmware configuration and checks a fresh read after ACK', () => {
  const source = read('ios/Runner/QRingWearableBridge.m');
  const operation = source.slice(source.indexOf('- (void)monitoringInterval:'), source.indexOf('- (void)setAutoSetting:'));
  assert.match(operation, /setSchedualHeartRateStatus:expectedEnabled timeInterval:expectedInterval/);
  assert.doesNotMatch(operation, /setSchedualHeartRateStatus:[^\n]+ interval:/);
  assert.doesNotMatch(operation, /setSchedualHeartRateStatus:\w+ interval:\w+ success:/);
  assert.equal((operation.match(/getSchedualHeartRateInfoWithSuccess:/g) ?? []).length, 2);
  assert.match(operation, /savedLow == low && savedHigh == high/);
  assert.match(operation, /savedMinimum == minimum/);
  assert.match(operation, /monitoringPoisonGeneration = connection/);
  assert.match(operation, /if \(done\) return;/);
  const reads = source.slice(source.indexOf('- (void)readAutoSettings:'), source.indexOf('- (void)monitoringInterval:'));
  assert.match(reads, /getSchedualHeartRateInfoWithSuccess:/);
  assert.doesNotMatch(reads, /getSchedualHeartRateStatusWithSuccess:/);
});

test('Android monitoring uses a fresh read and short payload without fabricated alarm thresholds', () => {
  const source = read('android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java');
  const operation = source.slice(source.indexOf('private void monitoringInterval('), source.indexOf('private void setAutoSetting('));
  assert.match(operation, /HeartRateSettingReq.getReadInstance\(\)/);
  assert.match(operation, /HeartRateSettingReq.getWriteInstance\(requestedEnabled, requested\)/);
  assert.match(operation, /isCurrentConnection\(generation, id\)/);
  assert.match(operation, /monitoringPoisonGeneration = generation/);
  assert.doesNotMatch(source, /getWriteInstance\(enabled, 10, 10, 40, 110\)/);
});
