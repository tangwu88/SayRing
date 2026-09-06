import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';

globalThis.safeHttpFixture = { sessions: [], requests: [], status: 200, chunks: [], fail: false, canceled: 0, closed: 0 };
const stubs = {
  '@kit.ArkTS': 'export const util={TextDecoder:class{decodeToString(bytes){return new TextDecoder().decode(bytes);}}}',
  '@kit.RemoteCommunicationKit': `export const rcp={
    Request:class{constructor(url,method,headers,content){Object.assign(this,{url,method,headers,content});}},
    createSession:configuration=>{globalThis.safeHttpFixture.sessions.push(configuration);return{
      fetch:async request=>{const f=globalThis.safeHttpFixture;f.requests.push(request);
        for(const chunk of f.chunks)request.destination(chunk);
        if(f.fail)throw Error('fixture failure');
        return{statusCode:f.status};},
      cancel:()=>globalThis.safeHttpFixture.canceled++, close:()=>globalThis.safeHttpFixture.closed++
    };}}`
};
registerHooks({
  resolve(specifier, context, next) {
    if (stubs[specifier]) return { url: `data:text/javascript,${encodeURIComponent(stubs[specifier])}`, shortCircuit: true };
    if (specifier.startsWith('.') && /\.(ts|ets)$/.test(context.parentURL || '') && !/\.[a-z]+$/.test(specifier)) return next(specifier + '.ts', context);
    return next(specifier, context);
  },
  load(url, context, next) {
    if (url.endsWith('.ets')) return { format: 'module', source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8')), shortCircuit: true };
    return next(url, context);
  }
});
const { legacySafeHttp } = await import('../entry/src/main/ets/services/LegacySafeHttp.ets');
const { API_BASE } = await import('../entry/src/main/ets/model/Contracts.ts');
const body = new TextEncoder().encode('{"message":"健康数据"}');
const request = () => legacySafeHttp(`${API_BASE}/api/v1/member/info`, 'POST', { token: 'test-only' }, 'fixture', 15000);

test('API 12 request disables redirects before sending credentials and preserves split UTF-8 data', async () => {
  const f = globalThis.safeHttpFixture;
  f.chunks = [body.slice(0, 15).buffer, body.slice(15).buffer];
  const response = await request();
  assert.equal(response.result, '{"message":"健康数据"}');
  assert.equal(response.responseCode, 200);
  assert.deepEqual(f.sessions[0], { requestConfiguration: { transfer: { autoRedirect: false, timeout: { connectMs: 15000, transferMs: 15000 } } } });
  assert.equal(f.requests[0].headers.token, 'test-only');
  assert.equal(f.closed, 1);
});

test('redirect response is rejected rather than followed and foreign initial origins cannot receive credentials', async () => {
  const f = globalThis.safeHttpFixture;
  f.status = 302;
  const before = f.requests.length;
  await assert.rejects(request(), /服务地址/);
  assert.equal(f.requests.length, before + 1);
  await assert.rejects(legacySafeHttp('https://untrusted.invalid/api/data', 'POST', { token: 'test-only' }, '', 1000), /请求地址/);
  assert.equal(f.requests.length, before + 1);
  f.status = 200;
});

test('oversize data cancels before retaining more than 2MB and closes the session on failure', async () => {
  const f = globalThis.safeHttpFixture;
  f.chunks = [new ArrayBuffer(2 * 1024 * 1024), new ArrayBuffer(1), new ArrayBuffer(1)];
  const closed = f.closed;
  await assert.rejects(request(), /数据过多/);
  assert.equal(f.canceled, 1);
  assert.equal(f.closed, closed + 1);
  f.chunks = []; f.fail = true;
  await assert.rejects(request(), /fixture failure/);
  assert.equal(f.closed, closed + 2);
});

test('both normal and upload transports guard API 23 and use the low-API safe helper', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/services/SaydianApi.ets', import.meta.url), 'utf8');
  for (const part of [source.slice(0, source.indexOf('async upload(')), source.slice(source.indexOf('async upload('))]) {
    assert.equal((part.match(/deviceInfo.sdkApiVersion < 23/g) || []).length, 1);
    assert.ok(part.indexOf("import('./LegacySafeHttp')") < part.indexOf('maxRedirects: 0'));
  }
});
