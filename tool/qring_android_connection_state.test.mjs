import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');

test('Android production recovery state rejects retired targets and resets session metadata', () => {
  const source = read('android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java');
  const methods = ['onBondState', 'emitRecoveryState', 'resetDeviceDetails', 'deviceDetails', 'isCurrentConnection'].map(name => {
    const match = new RegExp('\\n    private [^\\n]+ ' + name + '\\(').exec(source);
    assert.ok(match, name);
    const start = match.index;
    const next = /\n    (?:private|public|protected) /.exec(source.slice(start + 1));
    return source.slice(start, next ? start + 1 + next.index : source.length);
  }).join('\n');
  const folder = mkdtempSync(join(tmpdir(), 'sayring-android-connection-'));
  let javaHome = process.env.JAVA_HOME;
  if (!javaHome && process.platform === 'darwin') javaHome = execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding: 'utf8'}).trim();
  const java = tool => javaHome ? join(javaHome, 'bin', tool) : tool;
  try {
    const src = join(folder, 'QRingConnectionStateHarness.java');
    const run = body => {
      writeFileSync(src, read('tool/fixtures/QRingConnectionStateHarness.java').replace('// PRODUCTION_METHODS', body));
      execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-d', folder, src], {stdio: 'pipe'});
      return spawnSync(java('java'), ['-cp', folder, 'cc.saidian.saydian_app.QRingConnectionStateHarness'], {encoding: 'utf8'});
    };
    const result = run(methods);
    assert.equal(result.status, 0, result.stderr);
    process.stdout.write(result.stdout);
    for (const regression of [
      methods.replace('generation == connectionGeneration && ', ''),
      methods.replace('firmwareVersion = "";', ''),
    ]) {
      assert.notEqual(regression, methods);
      const bad = run(regression);
      assert.equal(bad.status, 1);
      assert.match(bad.stderr, /Connection state assertion failed/);
    }
  } finally {
    rmSync(folder, {recursive: true, force: true});
  }
});
