import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';

globalThis.portalNativeFixture = { calls: [], sdk: 24, destroyed: 0 };
const stubs = {
  '@kit.BasicServicesKit': 'export const deviceInfo={get sdkApiVersion(){return globalThis.portalNativeFixture.sdk}};',
  '@kit.CoreFileKit': 'export const fileIo={};',
  '@kit.ArkTS': 'export const util={};',
  './SessionVault': 'export class SessionVault {}',
  './AppDisplayService': 'export const appDisplayService={modules:globalThis.portalNativeFixture.modules,state:{requireVisible(){throw Error("AI closed")}}};',
  '@kit.NetworkKit': `export const http={RequestMethod:{GET:'GET',POST:'POST',PUT:'PUT',DELETE:'DELETE'},HttpDataType:{STRING:0},
    createHttp(){return{async request(url,options){const f=globalThis.portalNativeFixture;f.calls.push({url,options});
      const reply=await f.handler(new URL(url),options);return{responseCode:reply.status??200,
        result:JSON.stringify({code:reply.status??200,data:reply.data,message:reply.message??''})};},destroy(){globalThis.portalNativeFixture.destroyed++}}}};`
};
registerHooks({
  resolve(specifier, context, next) {
    if (stubs[specifier]) return { url: 'data:text/javascript,' + encodeURIComponent(stubs[specifier]), shortCircuit: true };
    if (specifier.startsWith('.') && /\.(ts|ets)$/.test(context.parentURL ?? '') && !/\.[a-z]+$/.test(specifier)) {
      return next(specifier + (existsSync(new URL(specifier + '.ts', context.parentURL)) ? '.ts' : '.ets'), context);
    }
    return next(specifier, context);
  },
  load(url, context, next) {
    return url.endsWith('.ets') ? { format: 'module', source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8')), shortCircuit: true } : next(url, context);
  }
});
const { ModuleDisplayState } = await import('../entry/src/main/ets/model/ModuleDisplay.ts');
const f = globalThis.portalNativeFixture;
let flags = { health_library: true, mall: true };
f.modules = new ModuleDisplayState(async () => ({ product: 'say-ring', platform: 'harmonyos',
  moduleVisibility: { schemaVersion: 1, validForSeconds: 300, modules: flags } }));
await f.modules.refresh();
after(() => f.modules.close());
const { NativeHttpTransport } = await import('../entry/src/main/ets/services/SaydianApi.ets');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const portal = await import('../entry/src/main/ets/model/GlobalPortal.ts');
const owner = '10000000-0000-4000-8000-000000000001';
const person = '10000000-0000-4000-8000-000000000002';
const third = '10000000-0000-4000-8000-000000000003';
const rel = '20000000-0000-4000-8000-000000000001';
const incoming = '20000000-0000-4000-8000-000000000002';
const cat = '30000000-0000-4000-8000-000000000001';
const item = '40000000-0000-4000-8000-000000000001';
const prefix = '/global/api/saydian-app/v2';
const relationship = (overrides = {}) => ({ id: rel, inviterMemberId: owner, recipientMemberId: person,
  status: 'active', metrics: ['heart_rate'], expiresAt: null, direction: 'sent',
  inviter: { id: owner, nickname: '合成本人' }, recipient: { id: person, nickname: '合成家人' }, ...overrides });
const inbound = (status = 'pending', metrics = []) => relationship({ id: incoming, inviterMemberId: person,
  recipientMemberId: owner, inviter: { id: person, nickname: '合成邀请人' }, recipient: { id: owner }, direction: 'received', status, metrics });
const product = (overrides = {}) => ({ id: item, name: '合成戒指', priceCents: 12345, currency: 'CNY', currencyExponent: 2,
  coverImage: '/attachment/fixture.jpg', stock: 3, ...overrides });

async function client(handler) {
  f.calls = []; f.handler = handler; flags = { health_library: true, mall: true }; await f.modules.refresh();
  const store = { value: { accessToken: 'synthetic-token', refreshToken: 'synthetic-refresh', expiresAt: Date.now() + 3600000,
    memberId: owner, displayName: '合成账号' }, async read() { return this.value; }, async write(value) { this.value = value; }, async clear() { this.value = undefined; } };
  const api = new AccountClient(new NativeHttpTransport(), store, () => Date.now(), true);
  await api.restore(); return api;
}
function assertWire(publicOnly = false) {
  for (const { url: raw, options } of f.calls) {
    const url = new URL(raw);
    assert.equal(url.origin, 'https://app.saydian.cn'); assert.ok(url.pathname.startsWith(prefix + '/'), raw);
    assert.equal(options.maxRedirects, 0); assert.equal(options.usingCache, false);
    if (publicOnly) assert.equal(options.header.Authorization, undefined);
    if (url.pathname.startsWith(prefix + '/care/')) assert.equal(options.header.Authorization, 'Bearer synthetic-token');
    if (/\/(?:content|commerce)\//.test(url.pathname)) {
      assert.equal(url.searchParams.get('product'), 'say-ring'); assert.equal(url.searchParams.get('platform'), 'harmonyos');
    }
  }
}

test('API24 real transport opens UUID encyclopedia categories, list pages and HTML details without legacy routes', async () => {
  const api = await client(async url => {
    if (url.pathname.endsWith('/categories')) return { data: [{ id: cat, name: '合成分类' }] };
    if (url.pathname.endsWith('/articles/' + item)) return { data: { id: item, title: '合成百科', contentHtml: '<p>合成正文</p>' } };
    assert.equal(url.searchParams.get('categoryId'), cat); assert.equal(url.searchParams.get('page'), '2');
    return { data: { items: [{ id: item, title: '合成百科', summary: '摘要' }], total: 31 } };
  });
  assert.equal((await api.articleCategories())[0].id, cat);
  assert.equal((await api.articlesByCategory(cat, 2))[0].id, item);
  assert.equal((await api.article(item, false)).content, '<p>合成正文</p>'); assertWire(true);
  const before = f.calls.length;
  await assert.rejects(api.article('../another', false)); await assert.rejects(api.articlesByCategory('3'));
  assert.equal(f.calls.length, before);
});

test('API24 catalog uses bootstrap plus paginated product API and preserves UUID, currency exponent and details', async () => {
  const api = await client(async url => {
    if (url.pathname.endsWith('/home')) return { data: { categories: [{ id: cat, name: '戒指' }], featured: [] } };
    if (url.pathname.endsWith('/products/' + item)) return { data: product({ gallery: ['/attachment/second.jpg'], detailHtml: '<p>合成商品详情</p>' }) };
    return { data: { items: [product()], total: 31, page: Number(url.searchParams.get('page')) } };
  });
  const home = await api.shopHome(); assert.equal(home.categories.length, 2); assert.equal(home.categories[0].products[0].id, item);
  assert.equal(home.categories[0].products[0].price, 'CNY 123.45'); assert.equal(home.categories[0].total, 31);
  await api.ringShopCategory(cat, '戒指', 2, '合成 戒指');
  const query = new URL(f.calls.at(-1).url).searchParams;
  assert.equal(query.get('categoryId'), cat); assert.equal(query.get('page'), '2'); assert.equal(query.get('keyword'), '合成 戒指');
  const detail = await api.ringShopProduct(item); assert.equal(detail.id, item); assert.equal(detail.covers.length, 2);
  assert.ok(detail.blocks.some(block => block.text.includes('合成商品详情'))); assertWire(true);
  assert.equal(portal.portalProduct(product({ currency: 'JPY', currencyExponent: 0 })).price, 'JPY 12345');
  for (const patch of [{ priceCents: null }, { currency: null }, { currencyExponent: null }]) assert.equal(portal.portalProduct(product(patch)).price, '价格待确认');
  assert.throws(() => portal.portalShopCategory('all', '全部', { items: {}, total: 0, page: 1 }));
});

test('API24 care lists preserve relationship and member UUIDs and never mistake another account for the owner', async () => {
  const api = await client(async url => { assert.equal(url.pathname, prefix + '/care/relationships'); return { data: [relationship(), inbound()] }; });
  const members = await api.careMembers(), invitations = await api.careInvitations();
  assert.deepEqual(members, [{ relationId: rel, memberId: person, name: '合成家人', mobile: '' }]);
  assert.equal(invitations[0].id, incoming); assert.equal(invitations[0].inviterId, person); assert.equal(invitations[0].state, 'pending');
  assertWire();
  assert.throws(() => portal.portalRelationships([relationship({ recipientMemberId: third, inviterMemberId: person })], owner, Date.now()));
  assert.throws(() => portal.portalRelationships([relationship({ direction: 'received' })], owner, Date.now()));
  assert.throws(() => portal.portalRelationships([relationship(), relationship()], owner, Date.now()));
});

test('invitation response targets the relationship UUID and only a current incoming pending invitation', async () => {
  const api = await client(async (url, options) => {
    if (options.method === 'GET') return { data: [inbound()] };
    assert.equal(url.pathname, prefix + `/care/relationships/${incoming}/respond`);
    assert.deepEqual(JSON.parse(options.extraData), { accepted: true }); return { data: inbound('active') };
  });
  await api.respondCareInvitation(incoming, true); assertWire();
  const posts = f.calls.filter(call => call.options.method === 'POST').length;
  await assert.rejects(api.respondCareInvitation(rel, true));
  assert.equal(f.calls.filter(call => call.options.method === 'POST').length, posts);
});

test('invitation contact follows Android default Chinese mobile normalization without executing real delivery', async () => {
  const api = await client(async (url, options) => {
    assert.equal(url.pathname, prefix + '/care/invitations'); assert.equal(options.method, 'POST');
    if(JSON.parse(options.extraData).identifier==='+8613800000001')return {status:400,message:'不能添加当前登录账号作为关爱成员'};
    assert.deepEqual(JSON.parse(options.extraData), { identifier: '+8613800000002' }); return { data: relationship() };
  });
  await api.addCare('13800000002');
  await assert.rejects(api.addCare('13800000001'),/不能添加/); assertWire();
});

test('sharing uses the incoming relationship UUID and preserves existing unsupported permissions without adding them', async () => {
  let metrics = ['heart_rate', 'ecg'];
  const api = await client(async (url, options) => {
    if (options.method === 'GET') return { data: [inbound('active', metrics)] };
    assert.equal(url.pathname, prefix + `/care/relationships/${incoming}/permissions`);
    assert.deepEqual(JSON.parse(options.extraData), { metrics: ['ecg'] }); metrics = ['ecg'];
    return { data: inbound('active', metrics) };
  });
  assert.deepEqual(await api.careShareSettings(person), { enabled: ['heartReat'], unknown: ['ecg'] });
  await api.saveCareShareSettings(person, []); assertWire();
  assert.deepEqual(await api.careShareSettings(person), { enabled: [], unknown: ['ecg'] });
  assert.throws(() => portal.portalShareBody(['invented'], []));
});

test('a changed permission snapshot is not overwritten by an old page', async () => {
  let metrics = ['heart_rate'];
  const api = await client(async () => ({ data: [inbound('active', metrics)] }));
  await api.careShareSettings(person); metrics = ['blood_oxygen'];
  await assert.rejects(api.saveCareShareSettings(person, []), /其他设备更新/);
  assert.equal(f.calls.some(call => call.options.method === 'POST'), false);
});

test('health reads authorize each metric and discard returned records when sharing is revoked in flight', async () => {
  let active = true;
  const api = await client(async (url) => {
    if (url.pathname.endsWith('/relationships')) return { data: [relationship({ status: active ? 'active' : 'revoked' })] };
    assert.equal(url.pathname, prefix + `/care/relationships/${rel}/health`);
    assert.equal(url.searchParams.get('metric'), 'heart_rate');
    assert.equal(url.searchParams.get('from'), '2026-10-27T16:00:00.000Z');
    return { data: [{ id: 'fixture-heart-record', metric: 'heart_rate', observedAt: '2026-10-28T02:00:00.000Z', values: { value: 75 }, unit: 'bpm' }] };
  });
  await api.careMembers(); const metric = await api.careMetric(rel, person, 'heart', '2026-10-28');
  assert.equal(metric.records[0].fields[0].value, 75); assert.equal(metric.records[0].id, 'fixture-heart-record');
  active = false; const revoked = await api.careMetric(rel, person, 'heart', '2026-10-28');
  assert.equal(revoked.state, 'unauthorized'); assert.deepEqual(revoked.records, []);
  const before = f.calls.length; await assert.rejects(api.careMetric(rel, third, 'heart', '2026-10-28'));
  assert.equal(f.calls.length, before); assertWire();
});

test('logout rejects a late relationship response instead of filling the new account page', async () => {
  let finish; const pending = new Promise(resolve => { finish = resolve; });
  const api = await client(async () => pending);
  const reading = api.careMembers(); await new Promise(resolve => setImmediate(resolve)); await api.logout();
  finish({ data: [relationship()] }); await assert.rejects(reading, /旧账号/); assert.equal(api.current(), undefined);
});

test('hidden module reads do not reach NetworkKit and fixed-origin validation still rejects old or foreign APIs', async () => {
  const api = await client(async () => { throw Error('unexpected network access'); });
  flags = { health_library: false, mall: false }; await f.modules.refresh();
  await assert.rejects(api.articleCategories()); await assert.rejects(api.shopHome()); assert.equal(f.calls.length, 0);
  const transport = new NativeHttpTransport();
  await assert.rejects(transport.request('/api/v1/member/care/my'));
  await assert.rejects(transport.request('https://foreign.invalid/global/api/saydian-app/v2/care/relationships'));
  assert.equal(f.calls.length, 0);
});
