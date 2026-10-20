import assert from 'node:assert/strict';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const root = fileURLToPath(new URL('../', import.meta.url));

test('silent iOS cancellation requires exact operation and actual disconnected state', () => {
  const central = read('ios/Runner/QCCentralManager.m');
  const reconcile = central.split('- (void)reconcileCancellation:')[1].split('/// Auto-reconnect')[0];
  assert.match(reconcile, /generation != self.operationGeneration/);
  assert.match(reconcile, /self.connectedPeripheral != peripheral/);
  assert.match(reconcile, /QRingCanFinishCancellation/);
  assert.match(reconcile, /peripheral.state == CBPeripheralStateDisconnected/);
  assert.match(reconcile, /attempts - 1/);
  assert.match(central, /reconcileCancellation:peripheral generation:self.operationGeneration/);
  const disconnect = central.split('- (void)disconnect {')[1].split('- (void)reconcileCancellation:')[0];
  assert.match(disconnect, /peripheral.state == CBPeripheralStateDisconnecting/);
  assert.match(reconcile, /attempts > 0 \? NSEC_PER_SEC \/ 4 : NSEC_PER_SEC/);
  for (const callback of ['didFailToConnectPeripheral:', 'didDisconnectPeripheral:']) {
    const body = central.split(callback)[1].split('\n- (')[0];
    assert.match(body, /peripheral.state != CBPeripheralStateDisconnected/);
  }
});

test('manual QRing reconnect refreshes only the remembered UUID without deleting binding', () => {
  const bridge = read('ios/Runner/QRingWearableBridge.m');
  const prepare = bridge.split('- (void)prepareRememberedDevice:')[1].split('- (void)connect:')[0];
  assert.match(prepare, /peripheral.state == CBPeripheralStateConnected/);
  assert.match(prepare, /\[self startScan:/);
  assert.match(prepare, /device\[@"id"\] isEqualToString:identifier/);
  assert.match(prepare, /self.selectionTargetID = identifier/);
  const scan = bridge.split('- (void)didScanPeripherals:')[1].split('- (void)scanPeripheralFinish')[0];
  assert.match(scan, /identifier isEqualToString:self.selectionTargetID/);
  assert.match(scan, /\[self finishScan\]/);
  assert.doesNotMatch(prepare, /removeObjectForKey|\[self.central remove\]/);
});

test('the actual reconnect/remove cancellation path reconciles a missing radio callback', () => {
  const bridge = read('ios/Runner/QRingWearableBridge.m');
  const central = read('ios/Runner/QCCentralManager.m');
  const reconnect = bridge.split('- (void)disconnectWithResult:')[1]
    .split('- (void)configureRecoveryTarget:')[0];
  // This is the route called by the reconnect action, not just the separate
  // timeout/failure disconnect route that already had reconciliation.
  assert.match(reconnect, /\[self.central remove\]/);
  const remove = central.split('- (void)remove {')[1]
    .split('/// Disconnect but keep')[0];
  assert.match(remove, /peripheral.state == CBPeripheralStateDisconnecting/);
  assert.match(remove.replace(/\/\/[^\n]*/g, ''), /self.deviceState = QCStateDisconnecting;\s*\[self reconcileCancellation:peripheral generation:self.operationGeneration attempts:80\]/);
  const reconcile = central.split('- (void)reconcileCancellation:')[1]
    .split('/// Auto-reconnect')[0];
  assert.match(reconcile, /QRingCanFinishCancellation/);
  assert.match(reconcile, /peripheral.state == CBPeripheralStateDisconnected/);
  assert.match(reconcile, /self.deviceState = \[self isBindDevice\] \? QCStateDisconnected : QCStateUnbind/);
  // No timeout-only unlock, arbitrary target, or binding/record reset here.
  assert.doesNotMatch(reconcile, /removeObjectForKey|setObject:|removeAllPeripheral/);
});

test('actual Objective-C cancellation methods reject stale polls and require radio closure', {skip: process.platform !== 'darwin'}, () => {
  const central = read('ios/Runner/QCCentralManager.m');
  const methods = central.slice(central.indexOf('- (void)remove {'), central.indexOf('/// Auto-reconnect when Bluetooth'));
  assert.match(methods, /- \(void\)remove \{/);
  assert.match(methods, /- \(void\)disconnect \{/);
  assert.match(methods, /- \(void\)reconcileCancellation:/);
  const template = read('tool/fixtures/qring_cancellation.m');
  const temporary = mkdtempSync(join(tmpdir(), 'sayring-qring-cancellation-'));
  try {
    const source = join(temporary, 'cancellation.m');
    const executable = join(temporary, 'cancellation');
    writeFileSync(source, template.replace('// ACTUAL_CANCELLATION_METHODS', methods));
    execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror', '-framework', 'Foundation', '-I', join(root, 'ios/Runner'), source, '-o', executable], {stdio: 'pipe'});
    const output = execFileSync(executable, {encoding: 'utf8'});
    assert.match(output, /QRing actual cancellation methods: [1-9]\d* assertions passed/);
    process.stdout.write(output);
    // Negative control: removing only the new reconciliation call from the
    // actual remove method must fail the radio-closure scenario, not just a
    // source-text assertion. The disconnect path remains untouched.
    const regressed = methods.replace('        [self reconcileCancellation:peripheral generation:self.operationGeneration attempts:80];', '');
    assert.notEqual(regressed, methods);
    writeFileSync(source, template.replace('// ACTUAL_CANCELLATION_METHODS', regressed));
    execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror', '-framework', 'Foundation', '-I', join(root, 'ios/Runner'), source, '-o', executable], {stdio: 'pipe'});
    assert.throws(() => execFileSync(executable, {stdio: 'pipe'}), error => error.status === 1 && /Synthetic cancellation assertion failed/.test(error.stderr.toString()));
    process.stdout.write('QRing missing-remove-reconciliation negative control rejected\n');
  } finally {
    rmSync(temporary, {recursive: true, force: true});
  }
});

test('iOS recovery re-arms after actual disconnect without a fixed delay or stale retry', () => {
  const bridge = read('ios/Runner/QRingWearableBridge.m');
  const state = bridge.split('- (void)didState:')[1].split('- (void)didConnectTransport:')[0];
  assert.match(state, /scheduleRecoveryAfterDisconnect/);
  assert.doesNotMatch(state, /2 \* NSEC_PER_SEC/);
  const schedule = bridge.split('- (void)scheduleRecoveryAfterDisconnect')[1].split('- (void)disconnectWithResult:')[0];
  assert.match(schedule, /dispatch_async\(dispatch_get_main_queue\(\), recover\)/);
  assert.match(schedule, /generation == weakSelf.connectionGeneration/);
  assert.match(schedule, /\[weakSelf startAutomaticRecovery\]/);
  assert.match(schedule, /recoveryRetryNotBefore - NSProcessInfo.processInfo.systemUptime/);
  const failure = bridge.split('- (void)failConnect:')[1].split('- (void)startUnbind:')[0];
  assert.match(failure, /recoveryRetryNotBefore = NSProcessInfo.processInfo.systemUptime \+ 2/);
  const recover = bridge.split('- (void)startAutomaticRecovery')[1].split('- (void)disconnectWithResult:')[0];
  for (const guard of ['recoveryTargetID', 'recoveryContext', 'hasPendingRestoredCancellations', 'pendingDisconnect', 'cancellingConnection', 'recoveryConnecting']) {
    assert.ok(recover.includes(guard));
  }
  assert.match(recover, /retrievePeripheralsWithIdentifiers:@\[uuid\]/);
  assert.match(recover, /connect:peripheral timeout:0/);
  // Re-arming from Dart/foreground/Bluetooth callbacks cannot bypass cooldown.
  assert.match(recover, /NSProcessInfo.processInfo.systemUptime < self.recoveryRetryNotBefore/);
});

test('today activity arrives before the remaining seven-day QRing history', () => {
  const bridge = read('ios/Runner/QRingWearableBridge.m');
  const sync = bridge.split('- (void)syncDay:')[1].split('- (void)finishHealthSync')[0];
  const activity = sync.split('case 0:')[1].split('case 1:')[0];
  assert.match(activity, /NSUInteger firstRecord = .*syncRecords.count/);
  assert.match(activity, /if \(day == 0\).*publishCurrentActivityFromIndex:firstRecord/);
  assert.ok(activity.indexOf('publishCurrentActivityFromIndex:firstRecord') < activity.indexOf('syncDay:day phase:1'));
  assert.match(sync, /day >= 7/);
  assert.match(sync, /if \(!current\(\)\).*return/);
  assert.match(bridge, /SRActivitySleepEvent\(type, payload/);
});

test('actual QRing details and early activity methods retain freshness and full history', {skip: process.platform !== 'darwin'}, () => {
  const bridge = read('ios/Runner/QRingWearableBridge.m');
  const method = signature => {
    const start = bridge.indexOf(signature);
    assert.notEqual(start, -1, `missing ${signature}`);
    return bridge.slice(start, bridge.indexOf('\n- (', start + 1));
  };
  const methods = method('- (void)readDeviceDetailsWithCompletion:') + '\n' + method('- (void)publishCurrentActivityFromIndex:') + '\n' + method('- (void)scheduleRecoveryAfterDisconnect');
  const template = read('tool/fixtures/qring_performance.m');
  const temporary = mkdtempSync(join(tmpdir(), 'sayring-qring-performance-'));
  try {
    const source = join(temporary, 'performance.m');
    const executable = join(temporary, 'performance');
    const compile = value => {
      writeFileSync(source, template.replace('// ACTUAL_PERFORMANCE_METHODS', value));
      execFileSync('xcrun', ['clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror', '-framework', 'Foundation', source, '-o', executable], {stdio: 'pipe'});
    };
    compile(methods);
    const output = execFileSync(executable, {encoding: 'utf8'});
    assert.match(output, /QRing actual performance methods: [1-9]\d* assertions passed/);
    process.stdout.write(output);
    const regressed = methods.replace('if (weakSelf.firmware.length > 0)', 'if (NO)');
    assert.notEqual(regressed, methods);
    compile(regressed);
    assert.throws(() => execFileSync(executable, {stdio: 'pipe'}), error => error.status === 1 && /Synthetic performance assertion failed/.test(error.stderr.toString()));
    process.stdout.write('QRing repeated firmware read negative control rejected\n');
  } finally {
    rmSync(temporary, {recursive: true, force: true});
  }
});
