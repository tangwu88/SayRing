import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, mkdirSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

test('production connection clock defers without consuming, expires and isolates each session', () => {
  const dir = mkdtempSync(join(tmpdir(), 'sayring-clock-session-'));
  const java = name => process.env.JAVA_HOME ? join(process.env.JAVA_HOME, 'bin', name) : name;
  const source = readFileSync('android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java', 'utf8');
  const method = name => {
    const match = new RegExp('\n    (?:private|public) [^\n]+ ' + name + '\\(').exec(source);
    assert.ok(match, 'Missing production method ' + name);
    let i = source.indexOf('{', match.index), depth = 0;
    for (; i < source.length; i++) {
      if (source[i] === '{') depth++;
      else if (source[i] === '}' && --depth === 0) return source.slice(match.index, i + 1);
    }
    throw Error('Unclosed production method ' + name);
  };
  try {
    const harness = join(dir, 'CoolWearClockHarness.java');
    writeFileSync(harness, readFileSync('tool/fixtures/CoolWearClockHarness.java', 'utf8')
      .replace('// PRODUCTION_METHODS', ['synchronizeConnectionClock', 'cancelConnectionClock',
        'flushConnectionClock', 'startMeasurementSession'].map(method).join('\n')));
    mkdirSync(join(dir, 'android', 'os'), {recursive: true});
    const clock = join(dir, 'android', 'os', 'SystemClock.java');
    writeFileSync(clock, 'package android.os; public final class SystemClock { public static long now; public static long elapsedRealtime() { return now; } }');
    execFileSync(java('javac'), ['-encoding', 'UTF-8', '-Xlint:all', '-Werror', '-d', dir, harness, clock,
      resolve('android/app/src/main/java/cc/saidian/saydian_app/CoolWearClockSync.java')]);
    const output = execFileSync(java('java'), ['-ea', '-cp', dir,
      'cc.saidian.saydian_app.CoolWearClockHarness'], {encoding: 'utf8'});
    assert.match(output, /Production clock sessions PASS/);
    process.stdout.write(output);
    // Listener retains a genuine format that precedes info without weakening
    // the generic manual/history packet barrier.
    const listener = source.split('K6_Action.RCVD.RCVD_TIME_TYPE,')[1]
      .split('K6_Action.RCVD.RCVD_DATA_TYPE_FUNCTION_CONTROL,')[0];
    assert.match(listener, /recoveryTarget\.isCurrent\(owner\)/);
    assert.match(listener, /epoch != connectionEpoch/);
    assert.match(listener, /target\.equals\(connectedId\)/);
    assert.doesNotMatch(listener, /postCurrentPacket/);
    for (const name of ['failConnect', 'dispose']) {
      assert.match(method(name), /cancelConnectionClock\(\)/);
    }
    const disconnected = source.split('case "disconnect":')[1].split('case "getDeviceDetails":')[0];
    assert.match(disconnected, /cancelConnectionClock\(\)/);
    // Ordinary history reads never gain an embedded clock/setting write.
    assert.doesNotMatch(method('startSync'), /flushConnectionClock|connectionClockUpdate/);
  } finally { rmSync(dir, {recursive: true, force: true}); }
});
