import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';
import {fileURLToPath} from 'node:url';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const bridge = read('android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java');

test('CoolWear shutter belongs to the opened camera page and the exact connected ring', () => {
  const start = bridge.indexOf('    private void setRemoteCamera(');
  const end = bridge.indexOf('\n    private void ', start + 1);
  assert.ok(start >= 0 && end > start && bridge.includes('setRemoteCamera(enabled);'));
  const method = bridge.slice(start, end);
  const dir = mkdtempSync(join(tmpdir(), 'sayring-coolwear-photo-'));
  const sdk = fileURLToPath(new URL('../android/app/libs/coolwear_bluesdk-release.aar', import.meta.url));
  const javaHome = process.env.JAVA_HOME || (process.platform === 'darwin' &&
    execFileSync('/usr/libexec/java_home', ['-v','17'], {encoding:'utf8'}).trim());
  const java = tool => javaHome ? join(javaHome, 'bin', tool) : tool;
  try {
    execFileSync(java('jar'), ['xf', sdk, 'classes.jar'], {cwd: dir});
    const src = join(dir, 'CoolWearPhotoTest.java');
    const fixture = read('tool/fixtures/CoolWearPhotoTest.java');
    writeFileSync(src, fixture.replace('// PRODUCTION_METHOD', method));
    execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-cp', 'classes.jar', src], {cwd:dir});
    const classpath = ['.', 'classes.jar'].join(process.platform === 'win32' ? ';' : ':');
    execFileSync(java('java'), ['-ea', '-cp', classpath, 'CoolWearPhotoTest'], {cwd:dir});
  } finally { rmSync(dir, {recursive:true, force:true}); }
});
