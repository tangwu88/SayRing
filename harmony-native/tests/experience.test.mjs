import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier, context, next) {
  return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ?
    `${specifier}.ts` : specifier, context);
} });
const {
  parseAiMessages, parseAiReply, parseAppUpdateManifest, parseShopHome, safeSaydianAsset,
} = await import('../entry/src/main/ets/model/ExperienceContracts.ts');

test('shop home uses only the real Saydian catalogue and attachment images', () => {
  const home = parseShopHome({ items: [
    { type: 'swiper', data: { list: [{ url: 'https://app.saidian.cc/attachment/images/banner.png' }] } },
    { type: 'tabs', value: [
      { name: '血压手表', list: [
        { id: '2917', name: '测试商品', picture: '/attachment/images/watch.jpg', price: '200.00', stock: '99' },
        { id: 'bad', name: '无效商品', price: '1.00' },
      ] },
      { name: '运动手表', list: [] },
    ] },
  ] });
  assert.equal(home.bannerUrl, 'https://app.saidian.cc/attachment/images/banner.png');
  assert.equal(home.categories.length, 2);
  assert.deepEqual(home.categories[0].products[0], {
    id: 2917, name: '测试商品', picture: 'https://app.saidian.cc/attachment/images/watch.jpg', price: '200.00', stock: 99,
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
  assert.throws(() => parseAppUpdateManifest(valid.replace('"harmony"', '"android"'), 4), /不匹配/);
});

test('Harmony home and profile follow the iOS functional information architecture', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
  for (const label of ['马上提问', '远程关爱', '健康百科', '健康预警', '赛电商城', '全部数据',
    '运动与记录', '我的订单', '权限管理', '帮助反馈', '联系客服', '关于我们', '检查更新']) {
    assert.ok(source.includes(label), `missing ${label}`);
  }
  assert.doesNotMatch(source, /原生开发验证版|查看适配进度/);
  assert.match(source, /商品规格、购物车和创建订单接口尚未完成原生适配/);
});

test('vendor dial channel error is localized instead of leaking JL terminology', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/services/VepWearableService.ets', import.meta.url), 'utf8');
  assert.match(source, /JL RCSP service not available/);
  assert.match(source, /当前手表未开放表盘读取通道/);
});
