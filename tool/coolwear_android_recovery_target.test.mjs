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
      .replace('// PRODUCTION_METHODS', nativeMethod('failConnect') + nativeMethod('pauseSdkRecovery')
        + nativeMethod('clearMeasurementSession') + nativeMethod('releaseLostConnection')));
    const policy = fileURLToPath(new URL('../android/app/src/main/java/cc/saidian/saydian_app/CoolWearRecoveryTarget.java', import.meta.url));
    execFileSync(java('javac'), ['-encoding', 'UTF-8', '-Xlint:all', '-Werror', '-d', directory, file, policy]);
    execFileSync(java('java'), ['-ea', '-cp', directory, 'cc.saidian.saydian_app.CoolWearRecoveryTargetHarness']);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('原 AAR 的公开地址 setter 只触及 RAM 和独立安装缓存', () => {
  const directory = mkdtempSync(join(tmpdir(), 'sayring-coolwear-cache-contract-'));
  try {
    execFileSync(java('jar'), ['xf', fileURLToPath(new URL('../android/app/libs/coolwear_bluesdk-release.aar', import.meta.url)), 'classes.jar'], {cwd: directory});
    const decompile = name => execFileSync(java('javap'), ['-classpath', 'classes.jar', '-c', '-p', name], {cwd: directory, encoding: 'utf8'}).replaceAll('\r\n', '\n');
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
  assert.match(callback.slice(callback.indexOf('} else if (status == K6_Action.RCVD.BLUE_DISCONNECT)')), /releaseLostConnection\(retiredId\)/);
  assert.doesNotMatch(source, /\.unbindDevice\(|\.removeBond\(|\.onDestroy\(/);
});

test('运动恢复仅给当前目标一段固定窗口，过期或取消后不再竞争控制层恢复', () => {
  const directory = mkdtempSync(join(tmpdir(), 'sayring-sport-lease-'));
  try {
    const file = join(directory, 'CoolWearRingBridge.java');
    writeFileSync(file, `package cc.saidian.saydian_app;
import java.util.*;
class CoolWearRingBridge {
  static CoolWearRingBridge activeBridge;
  final CoolWearRecoveryLease sdkRecoveryLease = new CoolWearRecoveryLease();
  final Recovery recoveryTarget = new Recovery();
  final Main main = new Main();
  Runnable sdkRecoveryDeadline;
  boolean recoveringConnection, linkConnected, deviceInfoReceived;
  int notifications, handoffs;
  static class SystemClock { static long elapsedRealtime(){return 1000;} }
  static class Recovery {
    long owner=1; boolean active=true;
    long generation(){return owner;}
    boolean isCurrent(long n){return n==owner;}
    boolean isActive(){return active;}
  }
  static class Main {
    List<Runnable> tasks=new ArrayList<>();
    void removeCallbacks(Runnable r){tasks.remove(r);}
    void postDelayed(Runnable r,long delay){
      if(delay!=15000)throw new AssertionError("unbounded recovery");tasks.add(r);
    }
  }
  void emit(String type,Map<String,Object> event){
    if(!"disconnected".equals(type)||!"native_sdk".equals(event.get("recoveryOwner")))
      throw new AssertionError("wrong ownership event"); notifications++;
  }
  void releaseLostConnection(String target){
    if(linkConnected||deviceInfoReceived)throw new AssertionError("stale transport ready");
    cancelSdkRecoveryLease();recoveryTarget.active=false;handoffs++;
  }
  ${nativeMethod('cancelSdkRecoveryLease')}
  ${nativeMethod('beginSdkSportRecovery')}
  static void check(boolean value){if(!value)throw new AssertionError("lease violated");}
  public static void main(String[] args){
    CoolWearRingBridge s=new CoolWearRingBridge();activeBridge=s;
    s.beginSdkSportRecovery("A");s.beginSdkSportRecovery("A");
    check(s.notifications==1&&s.main.tasks.size()==1);
    Runnable first=s.main.tasks.get(0);s.cancelSdkRecoveryLease();first.run();
    check(s.handoffs==0);
    s.beginSdkSportRecovery("A");Runnable old=s.main.tasks.get(0);
    s.recoveryTarget.owner++;old.run();check(s.handoffs==0);
    s.cancelSdkRecoveryLease();s.beginSdkSportRecovery("A");
    s.main.tasks.get(0).run();check(s.handoffs==1&&!s.recoveryTarget.active);
    s.main.tasks.clear();s.recoveryTarget.active=true;s.beginSdkSportRecovery("A");
    activeBridge=new CoolWearRingBridge();s.main.tasks.get(0).run();check(s.handoffs==1);
  }
}`);
    const policy = fileURLToPath(new URL('../android/app/src/main/java/cc/saidian/saydian_app/CoolWearRecoveryLease.java', import.meta.url));
    execFileSync(java('javac'), ['-encoding', 'UTF-8', '-Xlint:all', '-Werror', '-d', directory, file, policy]);
    execFileSync(java('java'), ['-ea', '-cp', directory, 'cc.saidian.saydian_app.CoolWearRingBridge']);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('离线结束的STOP只在同目标真实握手后发送一次，写入结果不明确也不重放', () => {
  const directory = mkdtempSync(join(tmpdir(), 'sayring-offline-stop-'));
  try {
    const file = join(directory, 'StopHarness.java');
    writeFileSync(file, `
class StopHarness {
  boolean linkConnected,deviceInfoReceived;
  String connectedId="A",pendingSportStopTarget="A",TAG="test";
  Integer pendingSportStopType=7;
  final Helper helper=new Helper();
  static class K6_SEND_APP_SPORT_STRUCT { static final int SPORT_STATUS_STOP=0; }
  static class Log { static void w(String t,String s){} }
  static class Helper {
    int sends;boolean reject;
    Helper getSendBlueData(){return this;}
    void sendAppSport(int type,int state,int time,int distance){
      if(type!=7||state!=0||time!=0||distance!=0)throw new AssertionError("wrong stop");
      sends++;if(reject)throw new IllegalStateException("ambiguous write");
    }
  }
  ${nativeMethod('dispatchPendingSportStop')}
  static void check(boolean v){if(!v)throw new AssertionError("stop replay");}
  public static void main(String[] args){
    StopHarness s=new StopHarness();s.dispatchPendingSportStop();check(s.helper.sends==0);
    s.linkConnected=true;s.dispatchPendingSportStop();check(s.helper.sends==0);
    s.deviceInfoReceived=true;s.connectedId="B";s.dispatchPendingSportStop();check(s.helper.sends==0);
    s.connectedId="a";s.helper.reject=true;s.dispatchPendingSportStop();s.dispatchPendingSportStop();
    check(s.helper.sends==1&&s.pendingSportStopType==null&&s.pendingSportStopTarget==null);
  }
}`);
    execFileSync(java('javac'), ['-encoding', 'UTF-8', '-Xlint:all', '-Werror', '-d', directory, file]);
    execFileSync(java('java'), ['-ea', '-cp', directory, 'StopHarness']);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});
