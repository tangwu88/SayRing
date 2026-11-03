import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';

const path = relative => fileURLToPath(new URL('../' + relative, import.meta.url));
test('actual CoolWear AAR separates real-time 60 from history 61 without replacing other listeners', () => {
  const folder = mkdtempSync(join(tmpdir(), 'sayring-hrv-sdk-'));
  const javaHome = process.env.JAVA_HOME || (process.platform === 'darwin' &&
    execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding: 'utf8'}).trim());
  const java = command => javaHome ? join(javaHome, 'bin', command) : command;
  try {
    execFileSync(java('jar'), ['xf', path('android/app/libs/coolwear_bluesdk-release.aar'), 'classes.jar'], {cwd: folder});
    const sources = [
      path('android/app/src/main/java/cc/saidian/saydian_app/CoolWearHrvListenerRouter.java'),
      path('tool/fixtures/CoolWearHrvSdkTest.java'),
    ];
    execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-cp', 'classes.jar', '-d', folder, ...sources], {cwd: folder});
    const classpath = [folder, join(folder, 'classes.jar')].join(process.platform === 'win32' ? ';' : ':');
    const output = execFileSync(java('java'), ['-ea', '-cp', classpath,
      'cc.saidian.saydian_app.CoolWearHrvSdkTest'], {cwd: folder, encoding: 'utf8'});
    assert.match(output, /Actual bundled AAR PASS/);
    process.stdout.write(output);
  } finally { rmSync(folder, {recursive: true, force: true}); }
});
