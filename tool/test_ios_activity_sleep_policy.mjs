import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';

const root = fileURLToPath(new URL('../', import.meta.url));
test('native release policy filters actual Foundation payloads without mutating sources', {skip: process.platform !== 'darwin'}, () => {
  const temporary = mkdtempSync(join(tmpdir(), 'sayring-activity-sleep-policy-'));
  try {
    const executable = join(temporary, 'policy');
    execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror', '-framework', 'Foundation', '-I', join(root, 'ios/Runner'), join(root, 'tool/fixtures/ios_activity_sleep_policy.m'), '-o', executable], {stdio: 'pipe'});
    const output = execFileSync(executable, {encoding: 'utf8'});
    assert.match(output, /[1-9]\d* assertions passed/);
    process.stdout.write(output);
    execFileSync('xcrun', ['swiftc', '-typecheck', '-import-objc-header', join(root, 'ios/Runner/SayRingActivitySleepPolicy.h'), join(root, 'tool/fixtures/ios_activity_sleep_import.swift')], {stdio: 'pipe'});
  } finally {
    rmSync(temporary, {recursive: true, force: true});
  }
});

test('every first-party iOS command and event channel applies the release policy', () => {
  for (const name of ['QRingWearableBridge.m', 'CoolWearWearableBridge.m', 'AppDelegate.swift']) {
    const source = readFileSync(join(root, 'ios/Runner', name), 'utf8');
    assert.match(source, /SRActivitySleepCommandAllowed\(call.method,/);
    assert.match(source, /SRActivitySleepResult\(call.method,/);
    assert.match(source, /SRActivitySleepEvent\(type,/);
  }
  const qring = readFileSync(join(root, 'ios/Runner/QRingWearableBridge.m'), 'utf8');
  assert.match(qring, /if \(phase >= 2\) \{ \[self syncDay:day \+ 1 phase:0\]; return; \}/);
  const coolwear = readFileSync(join(root, 'ios/Runner/CoolWearWearableBridge.m'), 'utf8');
  assert.match(coolwear, /if \(!SRActivitySleepMetricAllowed\(CoolWearHistoryMetric\(type.integerValue\)\)\) return;/);
});
