import test from 'node:test';
import assert from 'node:assert/strict';
import { dialRenderKey, deviceRenderKey } from '../entry/src/main/ets/model/DeviceRenderKeys.ts';

// Exercise keyed-child reconciliation using the production key functions.
// Reusing an immutable DTO's identity-only key deliberately reproduces the bug.
function reconcile(previous, items, keyOf, render) {
  const next = new Map();
  items.forEach((item, index) => {
    const key = keyOf(item, index);
    next.set(key, previous.get(key) ?? render(item, index));
  });
  return next;
}
const dial = (key, selected) => ({ key, selected });
const drawDial = (item, index) => ({ label: `表盘 ${index + 1}`, current: item.selected, selectable: !item.selected });

test('switch readback moves the current marker and disables the new dial using fresh DTOs', () => {
  const initial = [dial('one', false), dial('two', false), dial('three', true)];
  const after = initial.map(item => ({ ...item, selected: item.key === 'one' }));
  const old = reconcile(new Map(), initial, item => item.key, drawDial);
  assert.equal([...reconcile(old, after, item => item.key, drawDial).values()][0].current, false);
  const before = reconcile(new Map(), initial, dialRenderKey, drawDial);
  const visible = [...reconcile(before, after, dialRenderKey, drawDial).values()];
  assert.deepEqual(visible.map(item => item.current), [true, false, false]);
  assert.deepEqual(visible.map(item => item.selectable), [false, true, true]);
  assert.equal(visible[1], before.get(dialRenderKey(initial[1], 1)), 'unchanged row can still be reused');
  const restored = [...reconcile(reconcile(before, after, dialRenderKey, drawDial), initial, dialRenderKey, drawDial).values()];
  assert.deepEqual(restored.map(item => item.current), [false, false, true]);
});

test('reordering dials refreshes position labels and row actions', () => {
  const before = [dial('one', true), dial('two', false)];
  const rendered = reconcile(new Map(), before, dialRenderKey, drawDial);
  const after = [...reconcile(rendered, before.slice().reverse(), dialRenderKey, drawDial).values()];
  assert.deepEqual(after.map(item => item.label), ['表盘 1', '表盘 2']);
  assert.deepEqual(after.map(item => item.current), [false, true]);
});

test('same scan identity updates RSSI, name, real MAC and provider instead of keeping the first packet', () => {
  const first = { key: 'stable', name: 'W9S', provider: 'Vep', mac: '', rssi: -90, connectable: true };
  const second = { ...first, name: 'SD-Watch-W9S', mac: 'AA:BB:CC:DD:EE:FF', rssi: -42 };
  const draw = item => ({ name: item.name, mac: item.mac, rssi: item.rssi, provider: item.provider });
  const rendered = reconcile(new Map(), [first], deviceRenderKey, draw);
  assert.deepEqual([...reconcile(rendered, [second], deviceRenderKey, draw).values()][0], draw(second));
  assert.notEqual(deviceRenderKey(second), deviceRenderKey({ ...second, provider: 'Yuc', connectable: false }));
  assert.equal(first.rssi, -90, 'snapshot is never mutated to force reactivity');
});
