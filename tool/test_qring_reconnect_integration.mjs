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
