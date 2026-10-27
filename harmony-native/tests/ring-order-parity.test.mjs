import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier, context, next) {
  return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ? `${specifier}.ts` : specifier, context);
} });
const model = await import('../entry/src/main/ets/model/RingOrderPresentation.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const id = '10000000-0000-4000-8000-000000000150';
const caps = { checkout: { currency: 'CNY', currencyExponent: 2 } };
const order = () => ({ id, orderNo: 'SYNTHETIC-ONLY', status: 'PENDING_PAYMENT', payableCents: 1234,
  currency: 'CNY', allowedActions: ['PAY'], items: [{nameSnapshot: '合成商品', quantity: 2}] });
const now = Date.now();
async function fixture(handler) {
  const calls = [], vault = { value: {accessToken: 'fixture-token', refreshToken: 'fixture-refresh', expiresAt: now + 3600000,
    memberId: id, displayName: '合成账号'}, async read() {return this.value}, async write(value) {this.value=value}, async clear() {this.value=undefined} };
  const client = new AccountClient({async request(...args) {calls.push(args); return {code: 200, data: await handler(...args)}}}, vault, () => now);
  await client.restore(); return {client, calls};
}
test('UUID orders retain server amount, currency, names and pending state', () => {
  const value = model.parseRingOrder(order(), caps, id);
  assert.equal(value.id, id); assert.equal(value.paymentPending, true); assert.equal(model.ringOrderMoney(value), 'CNY 12.34');
  assert.deepEqual(value.items, [{title: '合成商品', quantity: 2}]);
  assert.equal(model.parseRingOrder({...order(), payableCents: 0}, caps).amount, 0);
});
test('missing money, mixed currency, legacy integer ids and wrong order are rejected', () => {
  for (const change of [{payableCents: null}, {payableCents: '12.34'}, {payableCents: -1}, {currency: 'JPY'}, {id: 1}, {status: ''}]) {
    assert.throws(() => model.parseRingOrder({...order(), ...change}, caps));
  }
  assert.throws(() => model.parseRingOrder(order(), caps, id.replace('150','151')));
  assert.equal(model.ringOrderMoney(model.parseRingOrder({...order(),currency:'JPY',currencyExponent:0}, caps)), 'JPY 1234');
});
test('unknown state never becomes pending; read-only and no PAY remain closed', () => {
  for (const change of [{status:'NEW_UNKNOWN_STATE'}, {readOnly:true}, {allowedActions:[]}]) {
    assert.equal(model.parseRingOrder({...order(), ...change}, caps).paymentPending, false);
  }
  assert.equal(model.ringOrderStatus('NEW_UNKNOWN_STATE'), '请刷新查看最新状态');
  assert.throws(() => model.ringOrderRows({items:[order(),{}]}, caps));
  assert.deepEqual(model.ringOrderRows({list:[]},caps), []);
});
test('order filters use V2 status/group contracts, never legacy integer ids', () => {
  assert.equal(model.ringOrderQuery(0), '?status=PENDING_PAYMENT');
  assert.equal(model.ringOrderQuery(1), '?group=pending_shipment');
  assert.equal(model.ringOrderQuery(-1), '?group=after_sales');
  assert.throws(() => model.ringOrderQuery(444));
});
test('production coordinator reads only global V2 orders with authenticated GET', async () => {
  const {client,calls} = await fixture(path => path.endsWith('capabilities') ? caps : path.includes(`/orders/${id}`) ? order() : {items:[order()]});
  assert.equal((await client.ringOrders(0))[0].id,id);
  assert.equal((await client.ringOrder(id)).number,'SYNTHETIC-ONLY');
  for (const call of calls.filter(v=>v[0].includes('/orders'))) {
    assert.match(call[0], /^\/global\/api\/saydian-app\/v2\/commerce\/orders/);
    assert.equal(call[4], 'GET'); assert.equal(call[2].memberId,id); assert.equal(call[3],undefined);
  }
  assert.equal(calls.length,4);
});
test('logout while a read is pending rejects stale data', async () => {
  let finish; const {client} = await fixture(path => path.endsWith('capabilities') ? caps : new Promise(resolve=>finish=resolve));
  const result=client.ringOrder(id); await new Promise(resolve=>setImmediate(resolve));
  await client.logout(); finish(order()); await assert.rejects(result);
});
test('sleep empty and failure copy stays customer facing without inventing data', () => {
  for (const state of ['empty','error','help']) assert.doesNotMatch(model.sleepCustomerMessage(state), /未返回|缺失|null|undefined|SDK/);
  assert.notEqual(model.sleepCustomerMessage('empty'),model.sleepCustomerMessage('error'));
});
