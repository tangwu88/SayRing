import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier, context, next) {
  return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ?
    `${specifier}.ts` : specifier, context);
} });
const {
  AI_CONCISE_RETRY_PREFIX, AI_USER_MESSAGE_MAX_LENGTH, aiConciseRetryMessage,
  parseAiMessages, parseAiReply, parseAppUpdateManifest, parseShopHome, safeSaydianAsset,
} = await import('../entry/src/main/ets/model/ExperienceContracts.ts');
const { AI_API_READ_TIMEOUT_MS, DEFAULT_API_READ_TIMEOUT_MS, apiReadTimeout } =
  await import('../entry/src/main/ets/model/RequestPolicy.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');

test('shop home uses only the real Saydian catalogue and attachment images', () => {
  const home = parseShopHome({ items: [
    { type: 'swiper', data: { list: [{ url: 'https://app.saydian.cn/attachment/images/banner.png' }] } },
    { type: 'tabs', value: [
      { name: '血压手表', list: [
        { id: '2917', name: '测试商品', picture: '/attachment/images/watch.jpg', price: '200.00', stock: '99' },
        { id: 'bad', name: '无效商品', price: '1.00' },
      ] },
      { name: '运动手表', list: [] },
    ] },
  ] });
  assert.equal(home.bannerUrl, 'https://app.saydian.cn/attachment/images/banner.png');
  assert.equal(home.categories.length, 2);
  assert.deepEqual(home.categories[0].products[0], {
    id: 2917, name: '测试商品', picture: 'https://app.saydian.cn/attachment/images/watch.jpg', price: '200.00', stock: 99,
  });
  assert.equal(home.categories[0].products.length, 1);
});

test('shop and article assets cannot load third-party or traversal URLs', () => {
  assert.equal(safeSaydianAsset('https://evil.invalid/attachment/a.png'), '');
  assert.equal(safeSaydianAsset('/attachment/../secret.png'), '');
  assert.equal(safeSaydianAsset('http://app.saidian.cc/attachment/a.png'), '');
});

test('AI history is normalized, ordered oldest first, and reply cannot be blank', () => {
  const values = parseAiMessages({ list: [
    { id: 2, message: '回复', my: 0, session_id: 'session-a' },
    { id: 1, content: '问题', role: 'user', session_id: 'session-a' },
  ] });
  assert.equal(values[0].mine, true);
  assert.equal(values[0].text, '问题');
  assert.equal(values[1].mine, false);
  assert.equal(parseAiReply({ content: '安全回复', my: 1 }).mine, false);
  assert.throws(() => parseAiReply({ message: ' ' }), /AI/);
  assert.equal(parseAiMessages({ list: [
    { id: 3, message: `${AI_CONCISE_RETRY_PREFIX}血压怎么测`, my: 1 },
  ] })[0].text, '血压怎么测');
});

test('AI create waits on the long-request policy while ordinary APIs keep the short timeout', async () => {
  const now = Date.UTC(2026, 8, 9, 3);
  const calls = [];
  const session = { accessToken: 'synthetic-access', refreshToken: 'synthetic-refresh',
    expiresAt: now + 3600000, memberId: 'fixture-member', displayName: '测试账号' };
  const store = { value: session, async read() { return this.value; }, async write(value) { this.value = value; },
    async clear() { this.value = undefined; } };
  const client = new AccountClient({ async request(...args) {
    calls.push(args);
    return { code: 200, data: { id: 2, message: '长请求已返回', session_id: 'session-a' } };
  } }, store, () => now);
  await client.restore();
  const reply = await client.sendAiMessage('请分析今天的健康数据');
  assert.equal(reply.text, '长请求已返回');
  assert.equal(calls[0][0], '/api/rf-article/chat/create');
  assert.equal(calls[0][5], AI_API_READ_TIMEOUT_MS);
  assert.equal(AI_API_READ_TIMEOUT_MS, 300000);
  assert.equal(apiReadTimeout(undefined), DEFAULT_API_READ_TIMEOUT_MS);
  assert.equal(apiReadTimeout(1), DEFAULT_API_READ_TIMEOUT_MS);
});

test('AI retries a service 422 once with a concise answer request and a fresh session', async () => {
  const now = Date.UTC(2026, 8, 9, 4);
  const calls = [];
  const session = { accessToken: 'synthetic-access', refreshToken: 'synthetic-refresh',
    expiresAt: now + 3600000, memberId: 'fixture-member', displayName: '测试账号' };
  const store = { value: session, async read() { return this.value; }, async write(value) { this.value = value; },
    async clear() { this.value = undefined; } };
  const { ApiError } = await import('../entry/src/main/ets/model/Contracts.ts');
  const client = new AccountClient({ async request(...args) {
    calls.push(args);
    if (calls.length === 1) throw new ApiError('Data Validation Failed.', 422);
    return { code: 200, data: { id: 9, message: '简短回答', session_id: 'session-new' } };
  } }, store, () => now);
  await client.restore();
  const reply = await client.sendAiMessage('血压怎么测', 'session-stale');
  assert.equal(reply.text, '简短回答');
  assert.equal(calls.length, 2);
  assert.equal(calls[0][5], AI_API_READ_TIMEOUT_MS);
  assert.equal(calls[1][5], AI_API_READ_TIMEOUT_MS);
  const retryBody = JSON.parse(calls[1][3]);
  assert.equal(retryBody.message, aiConciseRetryMessage('血压怎么测'));
  assert.equal(retryBody.session_id, undefined);
  assert.ok(retryBody.message.length <= 200);
  assert.equal(AI_USER_MESSAGE_MAX_LENGTH, 160);
});

test('Harmony update manifest is strict and only opens AppGallery', () => {
  const valid = JSON.stringify({
    schema_version: 1, platform: 'harmony', channel: 'production', latest_version: '0.2.0', latest_build: 8,
    minimum_supported_build: 5, release_notes: '更新说明',
    destination: { type: 'harmony_appgallery', url: 'https://appgallery.huawei.com/app/C123456' },
  });
  const info = parseAppUpdateManifest(valid, 4);
  assert.equal(info.hasUpdate, true);
  assert.equal(info.required, true);
  assert.throws(() => parseAppUpdateManifest(valid.replace('appgallery.huawei.com', 'evil.invalid'), 4), /不安全/);
  assert.throws(() => parseAppUpdateManifest(valid.replace('"harmony"', '"android"'), 4), /更新信息暂时不可用/);
});

test('Harmony home and profile follow the iOS functional information architecture', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
  for (const label of ['马上提问', '远程关爱', '健康百科', '健康预警', '全部数据',
    '运动与记录', '我的订单', '权限管理', '帮助反馈', '联系客服', '关于我们', '检查更新']) {
    assert.ok(source.includes(label), `missing ${label}`);
  }
  assert.match(source, /Text\(this\.tr\('shop'\)\)/, 'the store label must use the localized Say Ring brand');
  assert.doesNotMatch(source, /原生开发验证版|查看适配进度|原生适配|接口尚未|先浏览首页|模拟记录/);
  assert.match(source, /AI 正在思考，请耐心等待/);
});

test('vendor dial channel error is localized instead of leaking JL terminology', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/services/VepWearableService.ets', import.meta.url), 'utf8');
  assert.match(source, /JL RCSP service not available/);
  assert.match(source, /当前戒指暂不支持表盘读取/);
  assert.doesNotMatch(source, /手表|赛电/);
});
