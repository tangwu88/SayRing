import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const native = name => readFileSync(new URL(`../android/app/src/main/java/cc/saidian/saydian_app/${name}.java`, import.meta.url), 'utf8');
test('QRing retires callbacks before OEM stop and stops failed scans before replying', () => {
  const source = native('QRingBridge');
  const finish = source.slice(source.indexOf('private void finishScan()'), source.indexOf('@SuppressWarnings("unchecked")', source.indexOf('private void finishScan()')));
  assert.ok(finish.indexOf('++scanGeneration') < finish.indexOf('.stopScan(activity)'));
  assert.match(finish, /pendingScan = null;\s*finishScan\(\);\s*result.error/);
  assert.match(source, /onBatchScanResults\(List<ScanResult> results\)/);
  assert.match(source, /generation == scanGeneration && pendingScan != null/);
});
test('CoolWear refreshes scan callbacks per round and pairs only its current gesture target', () => {
  const source = native('CoolWearRingBridge');
  assert.match(source, /configureScanCallback\(scan\)/);
  assert.match(source, /generation == scanGeneration/);
  assert.match(source, /RingGestureBondPolicy.accepts\(target, epoch, changed.getAddress\(\)/);
  assert.match(source, /if \(mode != 0 && prepareGestureBond\(mode\)\) return/);
  assert.match(source, /getBondState\(\) == BluetoothDevice.BOND_BONDED/);
  assert.match(source, /activity.unregisterReceiver\(gestureBondReceiver\)/);
  assert.match(source, /sendGestureConfig\(mode\)/);
});
