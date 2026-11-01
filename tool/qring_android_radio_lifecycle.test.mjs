import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';

const read = p => readFileSync(new URL('../' + p, import.meta.url), 'utf8');

test('production Android adapter transitions retire stale sessions and restore only the armed permitted target', () => {
  const source = read('android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java');
  assert.match(source, /bluetoothStates\.addAction\(BluetoothAdapter\.ACTION_STATE_CHANGED\)/);
  assert.match(source, /main\.post\(\(\) -> onBluetoothState\(state\)\)/);
  const required = ['finishDisconnectedSession', 'resetDeviceDetails', 'isCurrentConnection',
    'scheduleRecoveryRetry', 'startAutomaticRecovery', 'resolved', 'isBluetoothEnabled', 'onBondState',
    'onBluetoothState', 'currentBluetoothState', 'emitRecoveryState'];
  const methods = required.map(name => {
    const match = new RegExp('\\n    private [^\\n]+ ' + name + '\\(').exec(source);
    assert.ok(match, 'Missing production method: ' + name);
    const start = match.index;
    let end = source.indexOf('{', start), depth = 0;
    for (; end < source.length; end++) {
      if (source[end] === '{') depth++;
      else if (source[end] === '}' && --depth === 0) return source.slice(start, end + 1);
    }
    throw new Error('Unclosed production method: ' + name);
  }).join('\n');
  const folder = mkdtempSync(join(tmpdir(), 'sayring-radio-lifecycle-'));
  let javaHome = process.env.JAVA_HOME;
  if (!javaHome && process.platform === 'darwin') javaHome = execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding:'utf8'}).trim();
  const java = tool => javaHome ? join(javaHome,'bin',tool) : tool;
  try {
    const src = join(folder,'QRingRadioLifecycleHarness.java');
    const run = body => {
      writeFileSync(src,read('tool/fixtures/QRingRadioLifecycleHarness.java').replace('// PRODUCTION_METHODS',body));
      execFileSync(java('javac'),['-Xlint:all','-Werror','-d',folder,src],{stdio:'pipe'});
      return spawnSync(java('java'),['-cp',folder,'cc.saidian.saydian_app.QRingRadioLifecycleHarness'],{encoding:'utf8'});
    };
    const result = run(methods);
    assert.equal(result.status,0,result.stderr);
    process.stdout.write(result.stdout);
    for (const regression of [
      methods.replace('if (bluetoothPowerUnavailable) return;', 'if (false) return;'),
      methods.replace('if (state == BluetoothAdapter.STATE_ON && actual == BluetoothAdapter.STATE_ON)', 'if (state == BluetoothAdapter.STATE_ON)'),
    ]) {
      assert.notEqual(regression,methods);
      const bad=run(regression);assert.equal(bad.status,1);assert.match(bad.stderr,/Radio lifecycle assertion failed/);
    }
  } finally { rmSync(folder,{recursive:true,force:true}); }
});
