import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, mkdirSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

test('production gesture flow enables/ACKs before pairing and confirms cancellation cleanup', () => {
  const dir = mkdtempSync(join(tmpdir(), 'sayring-gesture-pairing-'));
  const java = name => process.env.JAVA_HOME ? join(process.env.JAVA_HOME, 'bin', name) : name;
  const source = readFileSync('android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java', 'utf8');
  const method = name => {
    const match = new RegExp('\\n    private [^\\n]+ ' + name + '\\(').exec(source);
    assert.ok(match, 'Missing production method ' + name);
    let i = source.indexOf('{', match.index), depth = 0;
    for (; i < source.length; i++) {
      if (source[i] === '{') depth++;
      else if (source[i] === '}' && --depth === 0) return source.slice(match.index, i + 1);
    }
    throw Error('Unclosed production method ' + name);
  };
  try {
    const methods = ['clearGestureWaiters', 'finishGesture', 'resetGesture', 'onGestureMode',
      'rollbackGesturePairing', 'writeGesture', 'sendGestureMode'].map(method).join('\n');
    const harness = join(dir, 'CoolWearGesturePairingHarness.java');
    writeFileSync(harness, readFileSync('tool/fixtures/CoolWearGesturePairingHarness.java', 'utf8')
      .replace('// PRODUCTION_METHODS', methods));
    mkdirSync(join(dir, 'android', 'os'), {recursive: true});
    const clock = join(dir, 'android', 'os', 'SystemClock.java');
    writeFileSync(clock, 'package android.os; public final class SystemClock { public static long elapsedRealtime() { return 0L; } }');
    execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-d', dir, harness, clock,
      resolve('android/app/src/main/java/cc/saidian/saydian_app/CoolWearGestureState.java')]);
    const output = execFileSync(java('java'), ['-ea', '-cp', dir,
      'cc.saidian.saydian_app.CoolWearGesturePairingHarness'], {encoding: 'utf8'});
    assert.match(output, /Production gesture pairing PASS/);
    // The real Android broadcast branch must retain exact-target/epoch guards
    // and complete the same request; it must not replay the enabled scene.
    const bonded = method('prepareGestureBond').split('if (state == BluetoothDevice.BOND_BONDED)')[1]
      .split('else if (state == BluetoothDevice.BOND_NONE)')[0];
    assert.match(bonded, /finishGesture\(null, null\)/);
    assert.doesNotMatch(bonded, /sendGestureMode/);
    assert.match(method('prepareGestureBond'), /RingGestureBondPolicy\.accepts/);
  } finally { rmSync(dir, {recursive: true, force: true}); }
});
