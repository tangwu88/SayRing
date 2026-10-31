import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, readFileSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {test} from 'node:test';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
let executable;

function nativeFixture() {
  if (executable) return executable;
  // A private old header can reproduce the original behavioral failure without
  // replacing the working tree. Both versions compile the actual policy body.
  const header = resolve(process.env.SAY_RING_QRING_CAMERA_POLICY_HEADER ??
    join(root, 'ios/Runner/QRingCameraPolicy.h'));
  const source = readFileSync(header, 'utf8');
  const signature = source.match(/QRingCameraSnapshot\s*\(([^)]*)\)\s*\{/);
  assert.ok(signature, 'camera policy function must exist');
  const parameterCount = signature[1].split(',').length;
  assert.ok(parameterCount === 4 || parameterCount === 5,
    'unexpected camera policy signature');

  const outputRoot = join(root, 'build/qring-camera-policy-regression-20261031');
  mkdirSync(outputRoot, {recursive: true, mode: 0o700});
  const output = mkdtempSync(join(outputRoot, 'native-'));
  executable = join(output, 'qring-camera-policy');
  execFileSync('xcrun', [
    '--sdk', 'macosx', 'clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
    '-framework', 'Foundation', '-I', join(root, 'ios/Runner'),
    `-DSAY_RING_QRING_CAMERA_POLICY_HEADER="${header}"`,
    `-DSAY_RING_QRING_LEGACY_CAMERA_POLICY=${parameterCount === 4 ? 1 : 0}`,
    join(root, 'tool/fixtures/qring_camera_policy.m'), '-o', executable,
  ], {stdio: 'pipe'});
  return executable;
}

for (const [scenario, description] of [
  ['ordinary-touch', 'ordinary touch preserves the SDK reserved zero strength'],
  ['closed-gesture', 'a successful closed gesture read preserves its observed zero strength'],
  ['boundaries', 'screen touch rejects zero while all control types retain their bounds'],
  ['gesture-modes', 'gesture mode mapping keeps unknown modes enabled and unselected'],
  ['gesture-readback', 'gesture readback accepts only first-enable strength initialization'],
  ['snapshot-isolation', 'gesture presentation preserves raw settings without mutating camera state'],
]) {
  test(description, {skip: process.platform !== 'darwin'}, () => {
    const result = spawnSync(nativeFixture(), [scenario], {encoding: 'utf8'});
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /[1-9]\d* assertions passed/);
    process.stdout.write(result.stdout);
  });
}
