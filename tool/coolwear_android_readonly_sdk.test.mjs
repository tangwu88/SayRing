import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {existsSync, mkdtempSync, readFileSync, readdirSync, rmSync} from 'node:fs';
import {homedir, tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';

const path = relative => fileURLToPath(new URL('../' + relative, import.meta.url));
test('ordinary CoolWear reads never call mixed-setting write entry points', () => {
  const bridge = readFileSync(path('android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java'), 'utf8');
  // 这些名称看似同步/读取，原 AAR 实际会发送 110 混合设置并夹带提醒、目标和绑定写入。
  assert.doesNotMatch(bridge, /\.\s*(?:sendAsynInfo|sendAynInfoDetail|sendGetMixInfo|synDevData|startPairSynData)\s*\(/);
});

test('actual CoolWear SDK encodes all production read requests without setting bodies', () => {
  const folder = mkdtempSync(join(tmpdir(), 'sayring-readonly-sdk-'));
  const javaHome = process.env.JAVA_HOME || (process.platform === 'darwin' &&
    execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding: 'utf8'}).trim());
  const java = command => javaHome ? join(javaHome, 'bin', command) : command;
  try {
    const sdk = [process.env.ANDROID_HOME, process.env.ANDROID_SDK_ROOT,
      join(homedir(), 'Library', 'Android', 'sdk'), join(homedir(), 'Android', 'Sdk')]
      .find(value => value && existsSync(join(value, 'platforms')));
    assert.ok(sdk, 'The original SDK clock model requires the installed Android API types');
    const platform = readdirSync(join(sdk, 'platforms'))
      .filter(value => /^android-\d+$/.test(value) && existsSync(join(sdk, 'platforms', value, 'android.jar')))
      .sort((a, b) => Number(b.slice(8)) - Number(a.slice(8)))[0];
    assert.ok(platform, 'Missing Android platform API jar');
    const api = join(sdk, 'platforms', platform, 'android.jar');
    execFileSync(java('jar'), ['xf', path('android/app/libs/coolwear_bluesdk-release.aar'), 'classes.jar'], {cwd: folder});
    const sources = [
      path('android/app/src/main/java/cc/saidian/saydian_app/CoolWearReadRequests.java'),
      path('tool/fixtures/CoolWearReadRequestsSdkTest.java'),
    ];
    const separator = process.platform === 'win32' ? ';' : ':';
    execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-cp',
      ['classes.jar', api].join(separator), '-d', folder, ...sources], {cwd: folder});
    const output = execFileSync(java('java'), ['-ea', '-cp',
      [folder, join(folder, 'classes.jar'), api].join(separator),
      'cc.saidian.saydian_app.CoolWearReadRequestsSdkTest'], {cwd: folder, encoding: 'utf8'});
    assert.match(output, /Actual SDK read frames PASS/);
    process.stdout.write(output);
  } finally { rmSync(folder, {recursive: true, force: true}); }
});
