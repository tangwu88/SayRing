import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

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
