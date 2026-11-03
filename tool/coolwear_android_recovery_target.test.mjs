import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';
import {fileURLToPath} from 'node:url';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const source = read('android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java');
const javaHome = process.env.JAVA_HOME || (process.platform === 'darwin' &&
  execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding: 'utf8'}).trim());
const java = name => javaHome ? join(javaHome, 'bin', name) : name;
const nativeMethod = name => {
  const start = source.indexOf(`    private void ${name}(`);
  const end = source.indexOf('\n    private ', start + 1);
  assert.ok(start >= 0 && end > start, `${name} production method must exist`);
  return source.slice(start, end);
};

test('原生取消连接真实方法清 SDK 地址而保留业务绑定，失败也先撤销授权', () => {
  const directory = mkdtempSync(join(tmpdir(), 'sayring-coolwear-recovery-'));
  try {
    const start = source.indexOf('    private final CoolWearRecoveryTarget recoveryTarget');
    const end = source.indexOf('    private EventChannel.EventSink', start);
    assert.ok(start >= 0 && end > start);
    const fixture = read('tool/fixtures/CoolWearRecoveryTargetHarness.java');
    const file = join(directory, 'CoolWearRecoveryTargetHarness.java');
    writeFileSync(file, fixture
      .replace('// PRODUCTION_ADAPTER', source.slice(start, end))
      .replace('// PRODUCTION_METHODS', nativeMethod('failConnect') + nativeMethod('pauseSdkRecovery')));
    const policy = fileURLToPath(new URL('../android/app/src/main/java/cc/saidian/saydian_app/CoolWearRecoveryTarget.java', import.meta.url));
    execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-d', directory, file, policy]);
    execFileSync(java('java'), ['-ea', '-cp', directory, 'cc.saidian.saydian_app.CoolWearRecoveryTargetHarness']);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('原 AAR 的公开地址 setter 只触及 RAM 和独立安装缓存', () => {
  const directory = mkdtempSync(join(tmpdir(), 'sayring-coolwear-cache-contract-'));
  try {
    execFileSync(java('jar'), ['xf', fileURLToPath(new URL('../android/app/libs/coolwear_bluesdk-release.aar', import.meta.url)), 'classes.jar'], {cwd: directory});
    const decompile = name => execFileSync(java('javap'), ['-classpath', 'classes.jar', '-c', '-p', name], {cwd: directory, encoding: 'utf8'});
    const proxy = decompile('ce.com.cenewbluesdk.proxy.CEBluetoothProxyBase');
    const setter = proxy.slice(proxy.indexOf('  public void setBlueAddress('), proxy.indexOf('  public android.os.Message createMessage(int, int)'));
    const calls = [...setter.matchAll(/\/\/ Method ([^\n]+)/g)].map(match => match[1]);
    assert.deepEqual(calls, [
      'ce/com/cenewbluesdk/proxy/CEConnectUtilForAndroid5.setBlueAddress:(Ljava/lang/String;)V',
      'ce/com/cenewbluesdk/BleContentProvider/CEBlueSharedPreference.setDevAddress:(Ljava/lang/String;)V',
    ], 'SDK changed: review the public cache setter before permitting it');
    const provider = decompile('ce.com.cenewbluesdk.BleContentProvider.YDBleContentProvider');
    const write = provider.slice(provider.indexOf('  private void u(java.lang.String);'), provider.indexOf('  private java.lang.String s();'));
    assert.match(write, /String KEY_DEVMACADDRESS/);
    assert.match(write, /SharedPreferences\$Editor\.putString/);
    assert.match(write, /SharedPreferences\$Editor\.apply/);
    assert.doesNotMatch(write, /Bluetooth|sendData|removeBond|clearData|delete|\.clear:/);
    assert.match(provider, /String BLE_DATA_INFO_ContentProvider/);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('仅已验证的显式连接授权地址，扫描和旧队列事件不能复活目标', () => {
  const sdkSetup = source.slice(source.indexOf('    private void ensureSdk('), source.indexOf('    private void configureScanCallback('));
  assert.match(sdkSetup, /recoveryTarget\.initializeIdle\(recoverySdk\)/);
  assert.match(sdkSetup, /long generation = recoveryTarget\.generation\(\)/);
  assert.match(sdkSetup, /onConnectionState\(status, generation\)/);
  assert.match(sdkSetup, /!recoveryTarget\.isCurrent\(generation\)/);
  const connect = source.slice(source.indexOf('                case "connect":'), source.indexOf('                case "disconnect":'));
  assert.match(connect, /currentConnectCandidate\(id\)/);
  assert.ok(connect.indexOf('candidate == null') < connect.indexOf('recoveryTarget.activate('));
  assert.ok(connect.indexOf('recoveryTarget.activate(') < connect.indexOf('helper.connectDev('));
  const callback = nativeMethod('onConnectionState');
  assert.match(callback, /recoveryTarget\.acceptCallback\(generation,/);
  assert.doesNotMatch(callback.slice(callback.indexOf('} else if (status == K6_Action.RCVD.BLUE_DISCONNECT)')), /pauseSdkRecovery\(\)/);
  assert.doesNotMatch(source, /\.unbindDevice\(|\.removeBond\(|\.onDestroy\(/);
});
