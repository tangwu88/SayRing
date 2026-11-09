import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';

const read = p => readFileSync(new URL('../' + p, import.meta.url), 'utf8').replaceAll('\r\n', '\n');
let javaHome = process.env.JAVA_HOME;
if (!javaHome && process.platform === 'darwin') {
  javaHome = execFileSync('/usr/libexec/java_home', ['-v', '17'], {encoding: 'utf8'}).trim();
}
const java = name => javaHome ? join(javaHome, 'bin', name) : name;

function productionMethods(source, names) {
  return names.map(name => {
    const match = new RegExp('\\n    private [^\\n]+ ' + name + '\\(').exec(source);
    assert.ok(match, 'Missing production method: ' + name);
    const start = match.index;
    let end = source.indexOf('{', start), depth = 0;
    for (; end < source.length; end++) {
      if (source[end] === '{') depth++;
      else if (source[end] === '}' && --depth === 0) return source.slice(start, end + 1);
    }
    throw new Error('Unclosed method: ' + name);
  }).join('\n');
}

test('ordinary Android reconnect preserves the bond and waits for actual native closure', () => {
  const source = read('android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java');
  const methods = productionMethods(source, ['disconnectWithResult', 'onSdkBroadcast', 'onConnectionState',
    'verifyNativeCancellation', 'finishDisconnectedSession', 'resetDeviceDetails',
    'isCurrentConnection', 'scheduleRecoveryRetry']);
  const folder = mkdtempSync(join(tmpdir(), 'sayring-disconnect-'));
  try {
    const src = join(folder, 'QRingDisconnectHarness.java');
    const gate = join(folder, 'QRingCancellationGate.java');
    const aar = fileURLToPath(new URL('../android/app/libs/qring_sdk_1.0.0.76.aar', import.meta.url));
    execFileSync(java('jar'), ['xf', aar, 'classes.jar'], {cwd: folder});
    writeFileSync(gate, read('android/app/src/main/java/cc/saidian/saydian_app/QRingCancellationGate.java'));
    const run = body => {
      writeFileSync(src, read('tool/fixtures/QRingDisconnectHarness.java').replace('// PRODUCTION_METHODS', body));
      execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-cp', join(folder, 'classes.jar'),
        '-d', folder, src, gate], {stdio: 'pipe'});
      return spawnSync(java('java'), ['-cp', folder, 'cc.saidian.saydian_app.QRingDisconnectHarness'], {encoding: 'utf8'});
    };
    const result = run(methods);
    assert.equal(result.status, 0, result.stderr);
    process.stdout.write(result.stdout);
    for (const mutation of [
      methods.replace('manager.disconnect();', 'manager.unBindDevice();'),
      methods.replace('if (cancellingConnection) {\n            // The SDK', 'if (false) {\n            // The SDK'),
      methods.replace('manager.clearPendingTasks();', '// mutation: retain queued requests'),
      methods.replace('manager.cancelCurrentTask();', '// mutation: retain active request'),
      methods.replace('id == null || !id.equalsIgnoreCase(connectedId) || cancellingConnection',
        'id == null || cancellingConnection'),
    ]) {
      assert.notEqual(mutation, methods);
      const bad = run(mutation);
      assert.equal(bad.status, 1, bad.stderr);
      assert.match(bad.stderr, /Disconnect assertion failed/);
    }
  } finally { rmSync(folder, {recursive: true, force: true}); }
});

test('bundled SDK disconnect keeps the bond and retires response/task state', () => {
  const folder = mkdtempSync(join(tmpdir(), 'sayring-disconnect-sdk-'));
  try {
    const jar = join(folder, 'classes.jar');
    writeFileSync(jar, execFileSync('unzip', ['-p', fileURLToPath(new URL('../android/app/libs/qring_sdk_1.0.0.76.aar', import.meta.url)),
      'classes.jar'], {maxBuffer: 32 * 1024 * 1024}));
    const manager = execFileSync(java('javap'), ['-c', '-p', '-classpath', jar,
      'com.oudmon.ble.base.bluetooth.BleOperateManager'], {encoding: 'utf8', maxBuffer: 4 * 1024 * 1024});
    const disconnect = manager.split('public void disconnect();')[1].split('public void setNeedConnect')[0];
    assert.match(disconnect, /disconnectDeviceKeepBond/);
    assert.doesNotMatch(disconnect, /unBindDevice|removeBond|setMacNull/);
    const callback = manager.split('public void bleGattDisconnect(')[1].split('public void bleServiceDiscovered(')[0];
    assert.match(callback, /String DEVICE/);
    const noCallback = manager.split('public void bleNoCallback();')[1].split('private void mySendBroadcast(')[0];
    assert.match(noCallback, /String com\.qc\.sdk\.ble\.BLE_NO_CALLBACK/);
    assert.doesNotMatch(noCallback, /putExtra|bleGattDisconnect/);
    for (const cleanup of ['ConcurrentHashMap.clear', 'QCDataParser.clearAllPendingResponses',
      'LargeDataParser.reset', 'BleTaskScheduler.disconnectAll', 'disconnectDirectTasks']) {
      assert.ok(callback.includes(cleanup), 'Missing SDK disconnect cleanup: ' + cleanup);
    }
  } finally { rmSync(folder, {recursive: true, force: true}); }
});

test('approved Android NO_ACK recovery verifies settings without another reset or moving its import boundary', () => {
  const source = read('android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java');
  const methods = productionMethods(source, ['configureRecoveryTarget', 'initializeFactoryTarget']);
  const folder = mkdtempSync(join(tmpdir(), 'sayring-init-ack-'));
  try {
    const src = join(folder, 'QRingInitializationHarness.java');
    const policy = join(folder, 'QRingInitializationPolicy.java');
    writeFileSync(policy, read('android/app/src/main/java/cc/saidian/saydian_app/QRingInitializationPolicy.java'));
    const run = body => {
      writeFileSync(src, read('tool/fixtures/QRingInitializationHarness.java').replace('// PRODUCTION_METHODS', body));
      execFileSync(java('javac'), ['-Xlint:all', '-Werror', '-d', folder, policy, src], {stdio: 'pipe'});
      return spawnSync(java('java'), ['-cp', folder, 'cc.saidian.saydian_app.QRingInitializationHarness'], {encoding: 'utf8'});
    };
    const result = run(methods);
    assert.equal(result.status, 0, result.stderr);
    process.stdout.write(result.stdout);
    for (const mutation of [
      methods.replace('profile.is24() && profile.isMetric()', 'true'),
    ]) {
      assert.notEqual(mutation, methods);
      const bad = run(mutation);
      assert.equal(bad.status, 1, bad.stderr);
      assert.match(bad.stderr, /Initialization assertion failed/);
    }
  } finally { rmSync(folder, {recursive: true, force: true}); }
});
