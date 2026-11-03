import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {after, before, test} from 'node:test';

const source = readFileSync('ios/Runner/CoolWearWearableBridge.m', 'utf8');
const method = signature => {
  const start = source.indexOf(signature);
  assert.ok(start >= 0, `Missing production method ${signature}`);
  let depth = 0;
  for (let i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  throw new Error('Unclosed production method');
};
let folder;
let binary;
let releaseBinary;
before(() => {
  if (process.platform !== 'darwin') return;
  folder = mkdtempSync(join(tmpdir(), 'sayring-ios-hrv-'));
  binary = join(folder, 'hrv-session');
  releaseBinary = join(folder, 'hrv-session-release');
  const realHrv = source.slice(source.indexOf('    if (type.integerValue == DATA_TYPE_REAL_HRV_METRICS) {'),
    source.indexOf('    if (![data isKindOfClass:NSDictionary.class]) return;', source.indexOf('    if (type.integerValue == DATA_TYPE_REAL_HRV_METRICS) {')));
  assert.ok(realHrv.length > 200, 'Extract the actual type-60 reception branch');
  const helpers = ['- (void)hrvDiagnostic:', '- (void)publishPendingHrvRecord:']
    .filter(signature => source.includes(signature)).map(method).join('\n');
  const harness = readFileSync('test/native_coolwear_hrv_session_test.m', 'utf8')
    .replace('// PRODUCTION_MEASUREMENT', method('- (void)measurement:'))
    .replace('// PRODUCTION_HRV_RECEIVE', realHrv)
    .replace('// PRODUCTION_HRV_HELPERS', helpers);
  const input = join(folder, 'hrv-session.m');
  writeFileSync(input, harness);
  execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
    '-DDEBUG=1', '-I', resolve('.'), '-framework', 'Foundation', input, '-o', binary], {stdio: 'pipe'});
  execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
    '-DDEBUG=0', '-I', resolve('.'), '-framework', 'Foundation', input, '-o', releaseBinary], {stdio: 'pipe'});
});
after(() => { if (folder) rmSync(folder, {recursive: true, force: true}); });

for (const [scenario, title] of [
  ['early-result', 'iOS HRV waits for the start ACK before publishing a valid result'],
  ['early-failure', 'iOS HRV drops a pre-ACK result when start fails'],
  ['early-timeout', 'iOS HRV drops a pre-ACK result when start times out and ignores its late ACK'],
  ['queued-restart', 'a queued old HRV result cannot complete a later measurement'],
  ['cancel-new-round', 'a cancelled start ACK cannot complete or clear a new HRV round'],
  ['disconnect-result', 'disconnect discards a held HRV result and a late ACK cannot reuse it'],
  ['valid-result', 'fresh type-60 HRV preserves quality validation and emits once after ACK'],
  ['invalid-result', 'invalid or historical HRV cannot masquerade as a completed measurement'],
  ['stop-after-result', 'normal stop after an acknowledged result retains the connection'],
]) {
  test(title, {skip: process.platform !== 'darwin'}, () => {
    const result = spawnSync(binary, [scenario], {encoding: 'utf8'});
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /PASS/);
    assert.doesNotMatch(result.stderr, /sdnn|rmssd|meanRR|bpm|deviceId|UUID/);
  });
}

test('release HRV session has no diagnostic health or transport logs', {skip: process.platform !== 'darwin'}, () => {
  const result = spawnSync(releaseBinary, ['valid-result'], {encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, '');
});

test('real iOS cancellation clears the held result before draining the vendor queue', () => {
  const cancel = method('- (void)beginCancellation:');
  assert.match(cancel, /measurementGeneration\+\+/);
  assert.match(cancel, /measurementAcknowledged = NO/);
  assert.ok(cancel.indexOf('pendingHrvRecord = nil') < cancel.indexOf('[self.product cleanCmdQueue]'));
  const flush = method('- (void)publishPendingHrvRecord:');
  assert.match(flush, /generation != weakSelf.connectionGeneration/);
  assert.match(flush, /measurement != weakSelf.measurementGeneration/);
  assert.match(flush, /!\[weakSelf isResolved\]/);
});
