import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier, context, next) {
  if (specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier)) return next(specifier + '.ts', context);
  return next(specifier, context);
} });
const {
  pushRegistrationFields, pushErrorMessage, notificationRoute, notificationUnreadCount,
  parseShopOrder, parseShopOrders, paymentFields, parseHarmonyPayment, paymentErrorMessage
} = await import('../entry/src/main/ets/model/PushPaymentContracts.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const { ApiError } = await import('../entry/src/main/ets/model/Contracts.ts');
const {
  PAYMENT_TIMEOUT_MESSAGE, withPaymentTimeout, isPaymentTimeout
} = await import('../entry/src/main/ets/model/PaymentWatchdog.ts');

const order = { id: 99, number: 'ORDER-99', amountCents: 19900, status: 0, summary: '测试夹具订单' };
const now = Date.UTC(2026, 8, 5, 8);
const storedSession = { accessToken: 'synthetic-access', refreshToken: 'synthetic-refresh',
  expiresAt: now + 3600000, memberId: 'fixture-member', displayName: '测试账号' };
function accountClient(request) {
  const store = { value: structuredClone(storedSession), async read() { return this.value; },
    async write(value) { this.value = structuredClone(value); }, async clear() { this.value = undefined; } };
  return new AccountClient({ request }, store, () => now);
}

test('Harmony push registration is explicit and contains no account data', () => {
  assert.deepEqual(pushRegistrationFields({ installationId: 'fixture-installation-123', registrationId: 'fixture-registration-token-123' }, '0.1.3+6'), [
    { name: 'installation_id', value: 'fixture-installation-123' },
    { name: 'registration_id', value: 'fixture-registration-token-123' },
    { name: 'platform', value: 'harmony' },
    { name: 'version', value: '0.1.3+6' }
  ]);
});

test('invalid push identifiers and control bytes are rejected', () => {
  assert.throws(() => pushRegistrationFields({ installationId: 'bad', registrationId: 'fixture-registration-token-123' }, '0.1.3'));
  assert.throws(() => pushRegistrationFields({ installationId: 'fixture-installation-123', registrationId: 'bad\nregistration-token' }, '0.1.3'));
});

test('push failures stay actionable without exposing integration details', () => {
  assert.match(pushErrorMessage(1001500001), /暂时不可用/);
  assert.match(pushErrorMessage(1000900010), /应用身份/);
  assert.match(pushErrorMessage(1000900012), /Push Kit/);
  assert.match(pushErrorMessage(1000900014), /设备/);
  assert.match(pushErrorMessage(1600004), /权限/);
  assert.match(pushErrorMessage(1000900011), /网络/);
});

test('notification navigation only accepts whitelisted business routes', () => {
  assert.equal(notificationRoute({ event_type: 'care_invitation', entity_id: '18' }), 'care-invitations');
  assert.equal(notificationRoute({ route: '/health/alerts' }), 'health-alerts');
  for (const value of [{ route: 'https://evil.invalid' }, { route: '../settings' }, { mobile: '13000000000' }, null]) {
    assert.equal(notificationRoute(value), '');
  }
});

test('notification count prefers remind count and is bounded', () => {
  assert.equal(notificationUnreadCount({ announce_count: 4, remind_count: '2' }), 2);
  assert.equal(notificationUnreadCount({ unread_count: 1200 }), 999);
  assert.equal(notificationUnreadCount({ count: 0 }), 0);
  assert.throws(() => notificationUnreadCount({ announce_count: 4 }));
});

test('orders use server ids, server amounts and unpaid state', () => {
  assert.deepEqual(parseShopOrder({ id: '99', order_sn: 'ORDER-99', pay_money: '199.00', order_status: 0, product_name: '手表' }), {
    id: 99, number: 'ORDER-99', amountCents: 19900, status: 0, summary: '手表'
  });
  assert.deepEqual(parseShopOrders({ list: [
    { id: 99, pay_money: 199, order_status: 0 }, { id: 99, pay_money: 199, order_status: 0 }, { bad: true }
  ] }).map(item => item.id), [99]);
  assert.throws(() => parseShopOrder({ id: 99, pay_money: 0, order_status: 0 }));
});

test('payment request retains established server contract and adds Harmony platform', () => {
  const fields = paymentFields('wechat', order);
  assert.deepEqual(fields.map(item => item.name), ['pay_type', 'jump', 'trade_type', 'order_group', 'platform', 'data']);
  assert.equal(fields.find(item => item.name === 'pay_type').value, '1');
  assert.equal(fields.find(item => item.name === 'platform').value, 'harmony');
  assert.deepEqual(JSON.parse(fields.find(item => item.name === 'data').value), { order_id: '99', money: '199.00' });
  assert.throws(() => paymentFields('alipay', { ...order, status: 1 }), /无需重复/);
});

test('explicit Harmony payInfo is preferred and must be valid JSON', () => {
  const request = parseHarmonyPayment('wechat', { harmony: {
    third_app_id: 'wx-fixture', pay_info: '{"token":"fixture-token"}'
  } });
  assert.deepEqual(request, { provider: 'wechat', thirdAppId: 'wx-fixture', payInfo: '{"token":"fixture-token"}' });
  assert.throws(() => parseHarmonyPayment('wechat', { third_app_id: 'wx-fixture', pay_info: 'not-json' }));
});

test('legacy Android provider payloads never enter Harmony PaymentKit', () => {
  const wechat = { config: {
    appid: 'wx-fixture', partnerid: 'partner', prepayid: 'prepay', package: 'Sign=WXPay',
    noncestr: 'nonce', timestamp: '123456', sign: 'server-signature'
  } };
  const alipay = { config: 'app_id=20260001&biz_content=fixture&sign=server-signature' };
  assert.throws(() => parseHarmonyPayment('wechat', wechat), /暂时无法发起支付/);
  assert.throws(() => parseHarmonyPayment('alipay', alipay), /暂时无法发起支付/);
});

test('payment failures distinguish official provider outcomes', () => {
  assert.match(paymentErrorMessage(1022830000), /取消/);
  assert.match(paymentErrorMessage(1014900000), /取消/);
  assert.match(paymentErrorMessage(1022830002), /参数/);
  assert.match(paymentErrorMessage(801), /不支持/);
  assert.match(paymentErrorMessage(1001930001), /失败/);
  assert.match(paymentErrorMessage(1001930002), /已处理/);
  assert.match(paymentErrorMessage(1001930010), /重复/);
  assert.match(paymentErrorMessage(1014900004), /网络/);
  assert.match(paymentErrorMessage(1014900005), /环境/);
});

test('payment watchdog resolves normal calls and releases hung clients', async () => {
  assert.equal(await withPaymentTimeout(Promise.resolve('done'), 20), 'done');
  const providerError = new Error('provider failed');
  await assert.rejects(withPaymentTimeout(Promise.reject(providerError), 20), providerError);
  await assert.rejects(withPaymentTimeout(new Promise(() => {}), 5), error => {
    assert.equal(error.message, PAYMENT_TIMEOUT_MESSAGE);
    assert.equal(isPaymentTimeout(error), true);
    return true;
  });
  assert.equal(isPaymentTimeout(providerError), false);
});

test('push device registration and removal use authenticated server methods', async () => {
  const calls = [];
  const client = accountClient(async (path, fields, session, jsonBody, method) => {
    calls.push({ path, fields, token: session?.accessToken, jsonBody, method });
    return { code: 200, data: {} };
  });
  await client.restore();
  assert.equal(await client.registerPushDevice({ installationId: 'fixture-installation-123',
    registrationId: 'fixture-registration-token-123' }, '0.1.3+6'), true);
  assert.equal(await client.unregisterPushDevice('fixture-installation-123'), true);
  assert.deepEqual(calls.map(item => [item.path, item.method, item.token]), [
    ['/api/v1/member/push-devices', 'POST', 'synthetic-access'],
    ['/api/v1/member/push-devices/fixture-installation-123', 'DELETE', 'synthetic-access']
  ]);
});

test('missing primary notification endpoint falls back without losing session', async () => {
  const paths = [];
  const client = accountClient(async path => {
    paths.push(path);
    if (path.endsWith('/statistics')) throw new ApiError('not found', 404);
    return { code: 200, data: { unread_count: 3 } };
  });
  await client.restore();
  assert.equal(await client.notificationUnread(), 3);
  assert.deepEqual(paths, ['/api/v1/member/notify/statistics', '/api/v1/member/notify/unread-count']);
  assert.ok(client.current());
});

test('payment refreshes authoritative order before requesting a server signature', async () => {
  const calls = [];
  const client = accountClient(async (path, fields, session, jsonBody, method) => {
    calls.push({ path, fields, method });
    if (path.includes('/order/view')) {
      return { code: 200, data: { id: 99, order_sn: 'ORDER-99', pay_money: '199.00',
        order_status: 0, product_name: '测试订单' } };
    }
    return { code: 200, data: { harmony: { third_app_id: 'wx-fixture',
      pay_info: '{"token":"server-signed"}' } } };
  });
  await client.restore();
  const result = await client.harmonyPayment('wechat', { ...order, amountCents: 1 });
  assert.equal(result.payInfo, '{"token":"server-signed"}');
  assert.deepEqual(calls.map(item => item.path), [
    '/api/inv-shop/v1/member/order/view?id=99', '/api/v1/pay'
  ]);
  assert.deepEqual(JSON.parse(calls[1].fields.find(item => item.name === 'data').value),
    { order_id: '99', money: '199.00' });
});
