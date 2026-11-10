import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const android = source('android/app/src/main/kotlin/cc/saidian/saydian_app/UrionGattTransport.kt');
const ios = source('ios/Runner/UrionGattTransport.swift');

test('iOS cached connection retries full service discovery once without weakening protocol identity', () => {
  const block = ios.slice(ios.indexOf('func peripheral(_ peripheral: CBPeripheral, didDiscoverServices'), ios.indexOf('func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor'));
  assert.match(block, /guard peripheral === active else/);
  assert.match(block, /first\(where: \{ \$0\.uuid == serviceID \}\)/);
  assert.match(block, /if !retriedFullServiceDiscovery[\s\S]*retriedFullServiceDiscovery = true[\s\S]*peripheral\.discoverServices\(nil\)/);
  assert.match(block, /else[\s\S]*protocolServiceMissing[\s\S]*failConnection\(\)/);
  assert.match(ios.slice(ios.indexOf('private func closeConnection()'), ios.indexOf('private func whenRetired')), /retriedFullServiceDiscovery = false/);
});

test('Android disconnect completes through the actual GATT drain', () => {
  const block = android.slice(android.indexOf('if (call.method == "disconnect")'), android.indexOf('if (!hasPermission())'));
  assert.match(block, /closeConnection\(\)[\s\S]*connectionDrain\.whenDrained[\s\S]*if \(closed\) result\.success/);
  assert.match(block, /else result\.error\("DISCONNECT_FAILED"/);
});

test('Android connect waits for drain and rejects a cancelled connection request', () => {
  const block = android.slice(android.indexOf('private fun connect('), android.indexOf('private fun details('));
  assert.match(block, /pendingConnect = result[\s\S]*connectionDrain\.whenDrained[\s\S]*pendingConnect !== result \|\| generation != requestGeneration/);
  assert.match(block, /if \(!closed\)[\s\S]*return@whenDrained[\s\S]*device\.connectGatt/);
  assert.match(android, /if \(connection !== gatt\)[\s\S]*STATE_DISCONNECTED[\s\S]*connectionDrain\.didDisconnect\(connection\)/);
});

test('iOS waits for peripheral cancellation and never treats timeout as drained', () => {
  const connect = ios.slice(ios.indexOf('case "connect":'), ios.indexOf('case "disconnect":'));
  assert.match(connect, /whenRetired[\s\S]*self\.generation == requestGeneration[\s\S]*guard closed else[\s\S]*self\.central\.connect/);
  const disconnect = ios.slice(ios.indexOf('case "disconnect":'), ios.indexOf('case "getDeviceDetails":'));
  assert.match(disconnect, /whenRetired[\s\S]*result\(closed \? nil : FlutterError/);
  const timeout = ios.slice(ios.indexOf('retirementTimer = Timer.scheduledTimer'), ios.indexOf('@discardableResult'));
  assert.match(timeout, /waiters\.forEach \{ \$0\(false\) \}/);
  assert.doesNotMatch(timeout, /retiring\.remove|completion\(true\)/);
  assert.equal((ios.match(/if finishRetirement\(peripheral\) \{ return \}/g) ?? []).length, 2);
});
