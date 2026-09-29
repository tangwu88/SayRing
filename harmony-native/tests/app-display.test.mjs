import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';

globalThis.displayNativeFixture = {};
const stubs = {
  '@kit.AbilityKit': 'export const common={};',
  '@kit.BasicServicesKit': 'export const deviceInfo={get sdkApiVersion(){return globalThis.displayNativeFixture.sdkApiVersion??26}};',
  './LegacySafeHttp': `export async function legacySafeHttp(...args){const f=globalThis.displayNativeFixture;f.legacyCalls.push(args);return f.response;}`,
  '@kit.ArkData': `export const preferences={async getPreferences(context,options){const f=globalThis.displayNativeFixture;f.cacheName=options.name;return{async get(key,fallback){return f.cached??fallback},async put(key,value){f.cached=value},async flush(){f.flushes++}}}};`,
  '@kit.NetworkKit': `export const http={RequestMethod:{GET:'GET'},HttpDataType:{STRING:0},createHttp(){return{async request(url,options){const f=globalThis.displayNativeFixture;f.calls.push({url,options});return f.response},destroy(){globalThis.displayNativeFixture.destroyed++}}}};`
};
registerHooks({
  resolve(specifier, context, next) {
    if (stubs[specifier]) return { url: 'data:text/javascript,' + encodeURIComponent(stubs[specifier]), shortCircuit: true };
    if (specifier.startsWith('.') && /\.(ts|ets)$/.test(context.parentURL || '') && !/\.[a-z]+$/.test(specifier)) {
      return next(specifier + (existsSync(new URL(specifier + '.ts', context.parentURL)) ? '.ts' : '.ets'), context);
    }
    return next(specifier, context);
  },
  load(url, context, next) {
    return url.endsWith('.ets') ? { format: 'module', source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8')), shortCircuit: true } : next(url, context);
  }
});
const { AppDisplayState, parseSayRingAppDisplay } = await import('../entry/src/main/ets/model/AppDisplay.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const { ApiError } = await import('../entry/src/main/ets/model/Contracts.ts');
const { sameHealthSession } = await import('../entry/src/main/ets/model/HealthUpload.ts');
const { appDisplayService } = await import('../entry/src/main/ets/services/AppDisplayService.ets');
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no; }); return { promise, resolve, reject }; };
const tick = () => new Promise(resolve => setImmediate(resolve));
const payload = hideAi => ({ product: 'say-ring', hideAi });
function stateFixture(cached, initial = payload(false)) {
  const cache = { cached, writes: [], async read() { return this.cached; }, async write(value) { this.writes.push(value); this.cached = value; } };
  const remote = { reads: 0, value: initial, error: undefined };
  const state = new AppDisplayState(async () => { remote.reads++; if (remote.error) throw remote.error; return remote.value; }, cache);
  return { state, cache, remote };
}

test('display parser accepts only the exact Say Ring product and an actual boolean', () => {
  assert.equal(parseSayRingAppDisplay(payload(true)), true);
  assert.equal(parseSayRingAppDisplay(payload(false)), false);
  for (const value of [undefined, {}, { product: 'saydian-global', hideAi: false }, payload('false'), payload(0), payload(null)]) {
    assert.throws(() => parseSayRingAppDisplay(value), /serviceUnavailable/);
  }
});

test('first launch stays hidden on failure and retries without saving invented values', async () => {
  const f = stateFixture(); f.remote.error = new Error('synthetic network failure');
  assert.equal(f.state.hideAi, true); await f.state.refresh();
  assert.equal(f.state.hideAi, true); assert.deepEqual(f.cache.writes, []);
  f.remote.error = undefined; await f.state.refresh();
  assert.equal(f.state.hideAi, false); assert.deepEqual(f.cache.writes, [false]);
});

test('cached success is restored while invalid or failed refresh preserves either accepted value', async () => {
  for (const cached of [true, false]) {
    const f = stateFixture(cached, payload('bad')); await f.state.refresh();
    assert.equal(f.state.hideAi, cached); assert.deepEqual(f.cache.writes, []);
    f.remote.value = payload(!cached); await f.state.refresh();
    assert.equal(f.state.hideAi, !cached);
    const restarted = stateFixture(f.cache.cached); restarted.remote.error = new Error('offline');
    await restarted.state.refresh(); assert.equal(restarted.state.hideAi, !cached);
  }
});

test('foreground refresh is single-flight and cache write failure never rolls back server visibility', async () => {
  const pending = deferred(); let reads = 0;
  const state = new AppDisplayState(async () => { reads++; return pending.promise; }, { async read() {}, async write() { throw new Error('disk unavailable'); } });
  const first = state.refresh(), second = state.refresh(); await tick(); assert.equal(reads, 1);
  pending.resolve(payload(false)); await Promise.all([first, second]); assert.equal(state.hideAi, false);
});

test('a hide and re-enable cycle invalidates earlier AI responses and observer removal stops UI updates', async () => {
  const f = stateFixture(); const seen = [], stop = f.state.observe(hidden => seen.push(hidden));
  await f.state.refresh(); const generation = f.state.generation; f.state.requireVisible(generation);
  f.remote.value = payload(true); await f.state.refresh(); assert.throws(() => f.state.requireVisible(), /serviceUnavailable/);
  f.remote.value = payload(false); await f.state.refresh(); assert.throws(() => f.state.requireVisible(generation), /serviceUnavailable/);
  stop(); f.remote.value = payload(true); await f.state.refresh(); assert.deepEqual(seen, [true, false, true, false]);
});

test('native public request uses the isolated product URL, no credentials, no redirects and persistent success cache', async () => {
  const f = globalThis.displayNativeFixture = { calls: [], cached: undefined, flushes: 0, destroyed: 0,
    response: { responseCode: 200, result: JSON.stringify({ code: 200, data: payload(false) }) } };
  appDisplayService.attachContext({}); await appDisplayService.refresh();
  assert.equal(f.calls[0].url, 'https://app.saydian.cn/global/api/saydian-app/v2/support/app-display?product=say-ring');
  assert.deepEqual(f.calls[0].options.header, { Accept: 'application/json' });
  assert.equal(f.calls[0].options.maxRedirects, 0); assert.equal(f.calls[0].options.usingCache, false);
  assert.equal(f.cacheName, 'say_ring_global_app_display_v1'); assert.equal(f.cached, false); assert.equal(f.flushes, 1);
  f.response = { responseCode: 404, result: '{}' }; await appDisplayService.refresh();
  assert.equal(appDisplayService.state.hideAi, false); assert.equal(f.flushes, 1); assert.equal(f.destroyed, 2);
});

test('native API 17-22 uses the existing same-origin redirect-safe transport and rejects redirection responses', async () => {
  const f = globalThis.displayNativeFixture = { sdkApiVersion: 17, calls: [], legacyCalls: [], flushes: 0, destroyed: 0,
    response: { responseCode: 200, result: JSON.stringify({ code: 200, data: payload(true) }) } };
  await appDisplayService.refresh();
  assert.deepEqual(f.calls, []);
  assert.deepEqual(f.legacyCalls[0], ['https://app.saydian.cn/global/api/saydian-app/v2/support/app-display?product=say-ring',
    'GET', { Accept: 'application/json' }, '', 12000]);
  assert.equal(appDisplayService.state.hideAi, true); assert.equal(f.cached, true); assert.equal(f.flushes, 1);
  f.response = { responseCode: 302, result: JSON.stringify({ code: 200, data: payload(false) }) };
  await appDisplayService.refresh();
  assert.equal(appDisplayService.state.hideAi, true); assert.equal(f.flushes, 1);
});

const owner = '10000000-0000-4000-8000-000000000001', reportId = '20000000-0000-4000-8000-000000000001';
const now = Date.UTC(2026, 8, 29), document = { path: '/api/saydian-app/v2/content/legal/health_ai_analysis?version=fixture&locale=en', version: 'fixture', locale: 'en' };
function clientFixture(display, handler = async () => ({}), download = async () => new TextEncoder().encode('%PDF-1.4\nsynthetic\n%%EOF\n').buffer) {
  const calls = [], downloads = [];
  const store = { value: { accessToken: 'synthetic-access', refreshToken: 'synthetic-refresh', expiresAt: now + 3600000, memberId: owner, displayName: 'Synthetic' },
    async read() { return this.value; }, async write(v) { this.value = v; }, async clear() { this.value = undefined; } };
  const client = new AccountClient({ async request(...args) { calls.push(args); return { code: 200, data: await handler(...args) }; },
    async download(...args) { downloads.push(args); return download(...args); } }, store, () => now, true, display);
  return { client, calls, downloads, store };
}

test('hidden AI blocks chat, report reads/generation/export and granting consent before transport', async () => {
  const f = clientFixture(stateFixture().state); await f.client.restore();
  for (const operation of [() => f.client.aiMessages(), () => f.client.sendAiMessage('synthetic question'),
    () => f.client.healthReports(), () => f.client.healthReportContent(reportId), () => f.client.reportEligibility(),
    () => f.client.generateHealthReport(), () => f.client.exportHealthReport(reportId), () => f.client.setReportConsent(true, document)]) {
    await assert.rejects(operation(), /serviceUnavailable/);
  }
  assert.deepEqual(f.calls, []); assert.deepEqual(f.downloads, []);
});

test('hiding AI does not prevent reading reviewed legal analysis text or withdrawing consent', async () => {
  const f = clientFixture(stateFixture().state, async path => path.endsWith('/health/profile') ? {
    memberId: owner, analysisConsent: { granted: true, version: 'fixture', availableVersion: 'fixture', document }
  } : path === document.path ? { version: 'fixture', title: 'Synthetic notice', contentHtml: '<p>Reviewed notice</p>' } : {});
  await f.client.restore(); assert.match((await f.client.analysisNotice(document)).content, /Reviewed notice/);
  await f.client.setReportConsent(false); assert.equal(JSON.parse(f.calls.at(-1)[3]).granted, false);
});

test('late AI data and 401 retries are rejected after hiding without refreshing or invalidating the account', async () => {
  for (const rejected of [false, true]) {
    const d = stateFixture(); await d.state.refresh(); const response = deferred();
    const f = clientFixture(d.state, () => response.promise); await f.client.restore();
    const result = f.client.aiMessages(); await tick(); d.remote.value = payload(true); await d.state.refresh();
    if (rejected) response.reject(new ApiError('expired synthetic token', 401)); else response.resolve([]);
    await assert.rejects(result, /serviceUnavailable/); assert.equal(f.calls.length, 1); assert.ok(f.client.current());
  }
});

test('a hide and re-enable cycle during the profile read prevents a pending report generation from continuing', async () => {
  const d = stateFixture(); await d.state.refresh(); const response = deferred();
  const f = clientFixture(d.state, () => response.promise); await f.client.restore();
  const result = f.client.generateHealthReport(); await tick();
  d.remote.value = payload(true); await d.state.refresh(); d.remote.value = payload(false); await d.state.refresh();
  response.resolve({ memberId: owner, analysisConsent: { granted: true, version: 'fixture', availableVersion: 'fixture', document } });
  await assert.rejects(result, /serviceUnavailable/);
  assert.equal(f.calls.length, 1); assert.match(f.calls[0][0], /\/health\/profile$/);
});

test('hiding AI during PDF export rejects late bytes and expired-token retries without discarding the account', async () => {
  for (const rejected of [false, true]) {
    const d = stateFixture(); await d.state.refresh(); const response = deferred();
    const f = clientFixture(d.state, undefined, () => response.promise); await f.client.restore();
    const result = f.client.exportHealthReport(reportId); await tick(); d.remote.value = payload(true); await d.state.refresh();
    if (rejected) response.reject(new ApiError('expired synthetic token', 401));
    else response.resolve(new TextEncoder().encode('%PDF-1.4\nsynthetic\n%%EOF\n').buffer);
    await assert.rejects(result, /serviceUnavailable/);
    assert.equal(f.downloads.length, 1); assert.deepEqual(f.calls, []); assert.ok(f.client.current());
  }
});

test('hiding during the single authenticated retry never turns a late AI 401 into an account logout', async () => {
  for (const exportPdf of [false, true]) {
    const d = stateFixture(); await d.state.refresh(); const response = deferred(); let attempts = 0;
    const aiRequest = () => { if (attempts++ === 0) throw new ApiError('expired synthetic token', 401); return response.promise; };
    const f = clientFixture(d.state, async path => path.endsWith('/auth/refresh') ? {
      accessToken: 'new-synthetic-access', refreshToken: 'new-synthetic-refresh', expiresAt: new Date(now + 3600000).toISOString(),
      member: { id: owner, nickname: 'Synthetic' }
    } : aiRequest(), aiRequest);
    await f.client.restore(); const result = exportPdf ? f.client.exportHealthReport(reportId) : f.client.aiMessages();
    await tick(); assert.equal(attempts, 2); d.remote.value = payload(true); await d.state.refresh();
    response.reject(new ApiError('late synthetic retry rejected', 401));
    await assert.rejects(result, /serviceUnavailable/);
    assert.ok(f.client.current()); assert.equal(f.calls.filter(call => call[0].endsWith('/auth/refresh')).length, 1);
  }
});

const source = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
function method(name) {
  const match = new RegExp(`  private (?:async )?${name}\\(`).exec(source);
  assert.ok(match, name); const end = source.indexOf('\n  }', match.index + 1);
  return source.slice(match.index, end + 4);
}
function pageFixture() {
  const calls = [], response = deferred(), session = { ownerId: owner, generation: 1 };
  const api = { healthSession: () => session, async aiMessages() { calls.push('history'); return response.promise; },
    async sendAiMessage() { calls.push('send'); return response.promise; }, async healthReports() { calls.push('reports'); return []; } };
  const Page = new Function('saydianApi', 'sameHealthSession', `return ${stripTypeScriptTypes(`class Page {${['applyAiDisplay', 'openAiChat', 'sendAiChat', 'openGlobalReports'].map(method).join('\n')}}`)}`)(api, sameHealthSession);
  const page = Object.assign(new Page(), { hideAiContent: false, screen: 'home', guest: false, aiChatGeneration: 0, globalReportsGeneration: 0,
    aiMessages: [], aiInput: '', aiSessionId: '', aiError: '', aiBusy: false, globalReports: [], globalReportParagraphs: [], globalReportsBusy: false,
    innerParents: new Map(), scrollAiToLatest() {}, careFailure: error => error.message,
    openInnerPage(target) { this.innerParents.set(target, this.screen); this.screen = target; } });
  return { page, calls, response };
}

test('production page hides opened AI content, returns to its ordinary parent and discards a late answer', async () => {
  const f = pageFixture(); const opening = f.page.openAiChat(); assert.equal(f.page.screen, 'ai-chat');
  f.page.applyAiDisplay(true); assert.equal(f.page.screen, 'home'); assert.equal(f.page.aiBusy, false);
  f.response.resolve([{ text: 'late synthetic reply', sessionId: 'synthetic' }]); await opening;
  assert.deepEqual(f.page.aiMessages, []); assert.equal(f.page.aiSessionId, '');
  await f.page.openAiChat(); await f.page.openGlobalReports(); await f.page.sendAiChat(); assert.deepEqual(f.calls, ['history']);
});

test('production page hides reports without deleting legal metadata and re-enables entry on false', async () => {
  const f = pageFixture(); f.page.screen = 'health-reports'; f.page.innerParents.set('health-reports', 'account');
  f.page.globalReports = [{ id: reportId }]; f.page.globalAnalysisDocument = document;
  f.page.applyAiDisplay(true); assert.equal(f.page.screen, 'account'); assert.deepEqual(f.page.globalReports, []);
  assert.deepEqual(f.page.globalAnalysisDocument, document);
  f.page.applyAiDisplay(false); const opening = f.page.openAiChat(); assert.equal(f.page.screen, 'ai-chat');
  f.response.resolve([]); await opening; assert.deepEqual(f.calls, ['history']);
});

test('production UI and lifecycle wire the same display state for all AI entries, content and foreground', () => {
  assert.match(source, /if \(!this\.hideAiContent\) \{\s+Row\(\) \{\s+Image\(\$r\('app\.media\.health_doctor'/);
  assert.match(source, /if \(!this\.hideAiContent\) \{\s+Row\(\{ space: 12 \}\) \{\s+Column\(\) \{\s+SymbolGlyph\(\$r\('sys\.symbol\.message'/);
  assert.match(source, /if \(!this\.hideAiContent\) \{\s+this\.PageRow\(\{ title: 'reports'/);
  assert.match(source, /if \(!this\.hideAiContent\) \{ this\.GlobalReportsContent\(\) \}/);
  assert.match(source, /if \(!this\.hideAiContent\) \{ this\.AiChatContent\(\) \}/);
  assert.match(source, /this\.screen === 'ai-chat' && !this\.hideAiContent/);
  const ability = readFileSync(new URL('../entry/src/main/ets/entryability/EntryAbility.ets', import.meta.url), 'utf8');
  assert.match(ability, /onCreate\(want: Want\): void \{\s+appDisplayService\.attachContext/);
  assert.match(ability, /onForeground\(\): void \{[^}]*appDisplayService\.refresh\(\)/);
  const native = readFileSync(new URL('../entry/src/main/ets/services/SaydianApi.ets', import.meta.url), 'utf8');
  assert.match(native, /new AccountClient\([^;]+appDisplayService\.state\)/);
});
