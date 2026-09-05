import test from 'node:test';
import assert from 'node:assert/strict';
import { createWearableDevice, mergeWearableDevices } from '../entry/src/main/ets/model/WearableContracts.ts';
import { advertisedName, knownWearableName, mergeAdvertisement, DiscoveryPacketCache }
  from '../entry/src/main/ets/model/WearableDiscovery.ts';

const ad = (type, bytes) => [bytes.length + 1, type, ...bytes];
const name = text => ad(9, [...Buffer.from(text)]);
const packet = (data, extra = {}) => ({ id: 'fixture-a', name: '', rssi: -65, connectable: true, data, ...extra });

test('only known Vep models bypass manufacturer filtering and all W8 remain Yuc', () => {
  for (const value of ['ET488', 'SD-Watch-W9', 'SD-WATCH-W9S', 'W9s', 'W9S A123'])
    assert.equal(knownWearableName(value), 'Vep');
  for (const value of ['w8s 4DE9', 'SD-W8-Pro', 'W8-ultra']) assert.equal(knownWearableName(value), 'Yuc');
  for (const value of ['W90', 'W9 speaker', 'My ET488 phone', '', 'Unknown', 'AirPods'])
    assert.equal(knownWearableName(value), '');
});

test('advertisement names support short/full fields, UTF-8 and malformed bytes', () => {
  assert.equal(advertisedName(name('SD-Watch-W9S')), 'SD-Watch-W9S');
  assert.equal(advertisedName([...ad(8, [...Buffer.from('W9')]), ...name('SD-Watch-W9S')]), 'SD-Watch-W9S');
  assert.equal(advertisedName(name('赛电 W8')), '赛电 W8');
  assert.equal(advertisedName([22, 9, 87]), '');
  assert.equal(advertisedName([2, 9, 255]), '');
});

test('separate advertisement and scan response combine only for the same transport id', () => {
  const cache = new DiscoveryPacketCache();
  const manufacturer = ad(255, [248, 248, 1, 2, 3, 4, 5, 6]);
  cache.observe(packet(manufacturer), 1);
  const merged = cache.observe(packet(name('ET488')), 2);
  assert.equal(merged.name, 'ET488');
  assert.deepEqual(merged.data, [...manufacturer, ...name('ET488')]);
  assert.equal(cache.observe(packet([], { id: 'fixture-b' }), 3).name, '');
  cache.clear();
  assert.equal(cache.observe(packet([]), 4).name, '');
});

test('latest signal/connectability wins and stale names expire', () => {
  const cache = new DiscoveryPacketCache();
  cache.observe(packet(name('W9S')), 1);
  const updated = cache.observe(packet([], { rssi: -92, connectable: false }), 2);
  assert.equal(updated.name, 'W9S');
  assert.equal(updated.rssi, -92);
  assert.equal(updated.connectable, false);
  assert.equal(cache.observe(packet([]), 13000).name, '');
});

test('same field replaces old bytes rather than creating duplicate TLVs', () => {
  assert.deepEqual(mergeAdvertisement(name('W9'), name('W9S')), name('W9S'));
});
test('a verified MAC enriches the same transport row without duplicates or later downgrade', () => {
  const fallback=createWearableDevice('Vep','W9S','transport-1','',-60,true);
  const parsed=createWearableDevice('Vep','W9S','transport-1','11:22:33:44:55:66',-50,true);
  const enriched=mergeWearableDevices([fallback],[parsed]);
  assert.equal(enriched.length,1);assert.equal(enriched[0].mac,'11:22:33:44:55:66');
  const later=mergeWearableDevices(enriched,[{...fallback,rssi:-45}]);
  assert.equal(later.length,1);assert.equal(later[0].mac,parsed.mac);assert.equal(later[0].rssi,-45);
});
