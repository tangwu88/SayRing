import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const base = 'android/app/src/main/java/cc/saidian/saydian_app/';

test('Android Photo UI confirms the real session and rejects cancelled, stale and cross-target callbacks', () => {
  const source = read(base + 'QRingBridge.java');
  const signatures = ['canOpenRemoteCamera', 'registerRemoteCameraCallbacks', 'resetRemoteCamera',
    'stopRemoteCamera', 'waitToStopCamera', 'scheduleCameraKeepAlive', 'remoteCameraCommand',
    'finishCamera', 'currentCamera'];
  const methods = signatures.map(name => {
    const match = new RegExp('\\n    private [^\\n]+ ' + name + '\\(').exec(source);
    assert.ok(match, name);
    const start = match.index;
    const next = /\n    (?:private|public|protected) /.exec(source.slice(start + 1));
    return source.slice(start, next ? start + 1 + next.index : source.length);
  }).join('\n');
  const folder = mkdtempSync(join(tmpdir(), 'sayring-android-photo-'));
  let javaHome = process.env.JAVA_HOME;
  if (!javaHome && process.platform === 'darwin') {
    javaHome = execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding: 'utf8'}).trim();
  }
  const java = tool => javaHome ? join(javaHome, 'bin', tool) : tool;
  try {
    const src = join(folder, 'QRingPhotoSessionHarness.java');
    const channel = join(folder, 'QRingControlChannelState.java');
    writeFileSync(channel, read(base + 'QRingControlChannelState.java'));
    const run = body => {
      writeFileSync(src, read('tool/fixtures/QRingPhotoSessionHarness.java').replace('// PRODUCTION_METHODS', body));
      execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-d', folder, src, channel], {stdio: 'pipe'});
      return spawnSync(java('java'), ['-cp', folder, 'cc.saidian.saydian_app.QRingPhotoSessionHarness'], {encoding: 'utf8'});
    };
    const result = run(methods);
    assert.equal(result.status, 0, result.stderr);
    process.stdout.write(result.stdout);
    const regression = methods.replace('if (entering && epoch != remoteCameraEpoch)', 'if (false && entering && epoch != remoteCameraEpoch)');
    assert.notEqual(regression, methods);
    const bad = run(regression);
    assert.equal(bad.status, 1);
    assert.match(bad.stderr, /Photo session assertion failed/);
  } finally {
    rmSync(folder, {recursive: true, force: true});
  }
});
