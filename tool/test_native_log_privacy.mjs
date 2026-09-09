import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const activity = source('android/app/src/main/kotlin/cc/saidian/saydian_app/MainActivity.kt');
const stages = source('android/app/src/main/kotlin/cc/saidian/saydian_app/PrivateStageLog.kt');
const yucheng = source('android/yc_product_plugin_android/build.gradle');
const jpush = 'third_party/jpush_flutter/android/src/main/java/com/jiguang/jpush/';

test('Veepoo disables protocol, transport and file logging in every build', () => {
  assert.match(activity, /VPLogger\.setDebug\(false\)/);
  assert.match(activity, /BluetoothLog\.setDebug\(false\)/);
  assert.match(activity, /setOpenWriteLog\(false\)/);
  assert.match(activity, /VPLocalLogger\.stopMonitor\(\)/);
  assert.match(activity, /disableVendorLogs\(\)\s+VPOperateManager\.getInstance\(\)\.init\(appContext\)/);
  assert.match(activity, /manager = VPOperateManager\.getInstance\(\)\s+disableVendorLogs\(\)/);
  const policy = activity.slice(activity.indexOf('private fun disableVendorLogs()'), activity.indexOf('private fun releaseJLWatchFaceSession()'));
  assert.doesNotMatch(policy, /BuildConfig\.DEBUG|isDebug\s*\)/);
});

test('MainActivity goes through closed-stage logging, not direct Android Log', () => {
  assert.match(activity, /import cc\.saidian\.saydian_app\.PrivateStageLog as Log/);
  assert.doesNotMatch(activity, /import android\.util\.Log|android\.util\.Log\.[diew]/);
  assert.match(stages, /fun d\([^\n]+\): Int = 0/);
  const outputs = stages.match(/android\.util\.Log\.[iew]\([^\n]+/g);
  assert.equal(outputs.length, 3);
  for (const output of outputs) {
    assert.match(output, /"SaydianNative", PrivateStageNames\.fromMessage\(message\)\)/);
    assert.doesNotMatch(output, /, error\)|tag,/);
  }
});

test('stage labels are fixed non-sensitive tokens', () => {
  const labels = [...stages.matchAll(/-> "([^"]+)"/g)].map((match) => match[1]);
  assert.equal(labels.length, 13);
  assert(labels.every((label) => /^[a-z_]+$/.test(label)));
  assert.doesNotMatch(stages, /return message|substring|error\.(message|stackTrace|toString)/);
});

test('Yucheng source generation disables flags and intercepts wrapper raw logs', () => {
  assert.match(yucheng, /YCBTClient\.initClient\(context, isReconnectEnable, false\)/);
  assert.match(yucheng, /replace\('import android\.util\.Log;', ''\)/);
  assert.match(yucheng, /replace\('android\.util\.Log\.', 'Log\.'\)/);
  assert.match(yucheng, /Vendor exception text is not logged/);
  assert.match(yucheng, /java\.srcDirs = \[patchedYuchengJavaSource, file\('src\/main\/java'\)\]/);
  assert.match(yucheng, /configureLog\(context, false, false\)/);
});

for (const file of ['JPushPlugin.java', 'JPushHelper.java', 'JPushEventReceiver.java']) {
  test(`JPush ${file} cannot log through Android Log or raw stack traces`, () => {
    const text = source(jpush + file);
    assert.doesNotMatch(text, /import android\.util\.Log|android\.util\.Log\.|\.printStackTrace\(\)/);
    if (file === 'JPushPlugin.java') {
      assert.match(text, /JPushInterface\.setDebugMode\(false\)/);
      assert.doesNotMatch(text, /JPushInterface\.setDebugMode\(debug\)/);
    }
  });
}

test('vendor wrapper logger sinks have no output or persistence calls', () => {
  for (const path of [
    'android/yc_product_plugin_android/src/main/java/com/example/yc_product_plugin/Log.java',
    `${jpush}Log.java`,
  ]) {
    const text = source(path);
    assert.equal((text.match(/return 0;/g) ?? []).length, 4);
    assert.doesNotMatch(text, /android\.util|System\.|File|Writer|printStackTrace/);
  }
});
