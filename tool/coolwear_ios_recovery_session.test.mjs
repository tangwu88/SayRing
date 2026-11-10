import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {after, before, test} from 'node:test';

// 编译真实桥接方法，避免只检查文案或在测试里重写恢复逻辑。
const source = readFileSync(process.env.SAY_RING_RECOVERY_SOURCE ?? 'ios/Runner/CoolWearWearableBridge.m', 'utf8');
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
const binaries = [];
before(() => {
  if (process.platform !== 'darwin') return;
  folder = mkdtempSync(join(tmpdir(), 'sayring-ios-recovery-'));
  const methods = ['disableVendorRecovery', 'receiveStatus:', 'attemptRecovery:', 'failConnection:', 'checkCancellation']
    .map(name => method(`- (void)${name}`)).join('\n');
  const harness = readFileSync('test/native_coolwear_recovery_session_test.m', 'utf8')
    .replace('// PRODUCTION_RECOVERY_METHODS', methods);
  const input = join(folder, 'recovery-session.m');
  writeFileSync(input, harness);
  for (const debug of [1, 0]) {
    const binary = join(folder, `recovery-${debug}`);
    execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror', `-DDEBUG=${debug}`,
      '-I', resolve('.'), '-framework', 'Foundation', input, '-o', binary], {stdio: 'pipe'});
    binaries.push(binary);
  }
});
after(() => { if (folder) rmSync(folder, {recursive: true, force: true}); });

for (const [scenario, title] of [
  ['legacy-cache', 'clearing SDK recovery cannot lazily revive an installation-wide old target'],
  ['none-disconnected', 'a real disconnected peripheral with SDK none status leaves recovery unblocked'],
  ['none-connected', 'SDK none alone cannot cancel a live peripheral'],
  ['none-connecting', 'SDK none alone cannot cancel an in-flight physical connection'],
  ['lost-status', 'recovery retires a physically closed target when its status notification was lost'],
  ['handshake-pending', 'recovery does not interrupt an outstanding handshake'],
  ['cancellation-barrier', 'a still-live SDK peripheral keeps cancellation closed'],
  ['settled-cancellation', 'recovery rechecks a late physical close after bounded cancellation polling ends'],
  ['generation', 'a stale recovery timer cannot retire the current target'],
  ['unconfigured', 'a revoked recovery target cannot start another search'],
  ['healthy', 'a healthy connection neither cancels nor searches'],
  ['stale-ended-status', 'a delayed disconnected or power-off notice cannot cancel the verified live link'],
  ['sdk-ended-live-peripheral', 'a current SDK disconnect still cancels even before the peripheral closes'],
  ['radio-off-live-peripheral', 'real Bluetooth power off is not hidden by a stale completed SDK snapshot'],
  ['ordinary-disconnect', 'ordinary SDK disconnect and Bluetooth power off still recover'],
]) {
  test(title, {skip: process.platform !== 'darwin'}, () => {
    for (const binary of binaries) {
      const result = spawnSync(binary, [scenario], {encoding: 'utf8'});
      assert.equal(result.status, 0, result.stderr || result.stdout);
      assert.match(result.stdout, /PASS/);
      assert.equal(result.stderr, '');
    }
  });
}
