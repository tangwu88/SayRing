import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {test} from 'node:test';
import {fileURLToPath} from 'node:url';
import {legalSmokePath, runGlobalAuthSmoke} from './global_auth_smoke.mjs';

const origin = 'https://app.saydian.cn';
const prefix = '/global/api/saydian-app/v2';
const canonical = '/api/saydian-app/v2';
const id = '12345678-1234-1234-1234-123456789abc';
const secret = 'PRIVATE_CONTACT_TOKEN_HEALTH_VALUE_DO_NOT_LOG';
const version = 'reviewed-fixture-v1';
const legalPath = (type, base = canonical) => `${base}/content/legal/${type}?version=${version}&locale=en`;
const envelope = (data) => ({code: 200, requestId: id, data, message: secret});
const capabilities = () => envelope({
  realm: 'global', supportedLocales: ['en', 'zh-Hans'],
  registration: {email: true, sms: false, verificationRequired: false},
  consentVersion: version,
  legal: {userAgreement: {path: legalPath('user_agreement')}, privacyPolicy: {path: legalPath('privacy_policy')}},
});
const json = (data, status = 200, headers = {}) => new Response(JSON.stringify(data), {
  status, headers: {'Content-Type': 'application/json', ...headers},
});

function fixture(override = () => undefined) {
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({url, options});
    assert.equal(options.method, 'GET');
    assert.equal(options.redirect, 'error');
    assert.equal(options.credentials, 'omit');
    assert.equal(options.body, undefined);
    assert.equal(options.headers.Authorization, undefined);
    assert.equal(options.headers.Cookie, undefined);
    assert(url.startsWith(`${origin}/global/`));
    assert.equal(new URL(url).port, '');
    const changed = override(url, options);
    if (changed !== undefined) return changed;
    if (url.endsWith('/health/ready')) return json({status: 'ready', database: 'ok', revision: secret});
    if (url.includes('/auth/capabilities')) return json(capabilities());
    if (url.endsWith('/members/me')) return json({code: 401, data: null, requestId: id, message: secret}, 401);
    const path = new URL(url);
    return json(envelope({documentType: path.pathname.split('/').at(-1), version,
      locale: path.searchParams.get('locale'), reviewed: true, contentHtml: `<p>${secret}</p>`}));
  };
  return {calls, fetchImpl};
}

test('fixed-origin GET gate requires real readiness/global registration/anonymous denial/legal', async () => {
  const f = fixture();
  const result = await runGlobalAuthSmoke(f);
  assert.equal(result.passed, true);
  assert.equal(f.calls.length, 5);
  assert(f.calls.every(({url}) => !url.startsWith(`${origin}/api/`)));
  assert.equal(result.records.at(-1).checks.loginOrRegistrationTested, false);
  assert(!JSON.stringify(result).includes(secret));
  assert.equal(result.records[1].requestId, id);
  assert.deepEqual(result.validatedLegal, {consentVersion: version,
    userAgreementPath: legalPath('user_agreement', prefix), privacyPolicyPath: legalPath('privacy_policy', prefix)});
  assert.equal(JSON.stringify(result.records).includes(version), false);
});

test('accepts canonical and already isolated legal paths with exact single mapping', () => {
  for (const base of [canonical, prefix]) {
    assert.equal(legalSmokePath(legalPath('user_agreement', base), 'user_agreement', version), legalPath('user_agreement', prefix));
  }
  assert.equal(legalSmokePath(`${canonical}/content/legal/privacy_policy?locale=fr&version=v%20one`, 'privacy_policy', 'v one'), `${prefix}/content/legal/privacy_policy?version=v%20one&locale=fr`);
});

for (const attack of [
  `https://old.saydian.test${legalPath('user_agreement')}`,
  `${origin}${legalPath('user_agreement')}`,
  `//app.saydian.cn${legalPath('user_agreement')}`,
  `/global/api/saydian-app/v2/content/legal/../user_agreement?version=${version}&locale=en`,
  `/global/api/saydian-app/v2/content/legal/%2e%2e/user_agreement?version=${version}&locale=en`,
  `/global/api/saydian-app/v2/content/legal/%252e%252e/user_agreement?version=${version}&locale=en`,
  `${legalPath('user_agreement')}#fragment`, `${legalPath('user_agreement')}&locale=fr`,
  `${legalPath('user_agreement')}&version=another`, `${legalPath('user_agreement')}&next=https://old.example`,
  legalPath('privacy_policy'), legalPath('user_agreement').replace('locale=en', 'locale=xx'),
  `${legalPath('user_agreement')}\n`, legalPath('user_agreement').replace('/content/', '\\content/'),
  legalPath('user_agreement', prefix).replace('/api/', '/global/api/'),
]) {
  test(`rejects untrusted legal reference ${JSON.stringify(attack)}`, () => {
    assert.equal(legalSmokePath(attack, 'user_agreement', version), null);
  });
}

test('invalid capability legal references never cause a request to their URL', async () => {
  const f = fixture((url) => {
    if (!url.includes('/auth/capabilities')) return undefined;
    const caps = capabilities();
    caps.data.legal.userAgreement.path = `https://old.example/${secret}`;
    return json(caps);
  });
  const result = await runGlobalAuthSmoke(f);
  assert.equal(result.passed, false);
  assert.equal(f.calls.length, 4);
  assert(!JSON.stringify(result).includes(secret));
});

for (const mutate of [
  (caps) => { caps.data.realm = secret; },
  (caps) => { caps.data.registration.email = false; },
  (caps) => { delete caps.data.registration.verificationRequired; },
  (caps) => { caps.data.consentVersion = null; },
  (caps) => { caps.data.supportedLocales = ['xx']; },
]) {
  test(`missing or disabled capability fails closed: ${mutate}`, async () => {
    const f = fixture((url) => {
      if (!url.includes('/auth/capabilities')) return undefined;
      const caps = capabilities(); mutate(caps); return json(caps);
    });
    const result = await runGlobalAuthSmoke(f);
    assert.equal(result.passed, false);
    assert.equal(f.calls.length, 3);
    assert(!JSON.stringify(result).includes(secret));
  });
}

test('unready database cannot be hidden by valid auth contracts', async () => {
  const f = fixture((url) => url.endsWith('/health/ready') ? json({status: 'ready', database: 'failed'}) : undefined);
  const result = await runGlobalAuthSmoke(f);
  assert.equal(result.passed, false);
  assert.equal(result.records[0].checks.databaseReady, false);
  assert.equal(result.validatedLegal, null);
});

for (const [verificationRequired, countries, enabled] of [
  [true, [], false], [true, ['US'], true], [false, [], true],
]) {
  test(`SMS-only registration requires a usable channel: verification=${verificationRequired} countries=${countries.length}`, async () => {
    const f = fixture((url) => {
      if (!url.includes('/auth/capabilities')) return undefined;
      const caps = capabilities();
      caps.data.registration = {email: false, sms: true, verificationRequired};
      caps.data.smsCountries = countries;
      return json(caps);
    });
    const result = await runGlobalAuthSmoke(f);
    assert.equal(result.passed, enabled);
    assert.equal(result.records[1].checks.registrationEnabled, enabled);
  });
}

for (const status of [200, 403, 404, 500]) {
  test(`anonymous member must be 401, not ${status}`, async () => {
    const f = fixture((url) => url.endsWith('/members/me') ? json({data: null}, status) : undefined);
    assert.equal((await runGlobalAuthSmoke(f)).passed, false);
  });
}

test('a 401 that contains member data also fails without printing it', async () => {
  const f = fixture((url) => url.endsWith('/members/me') ? json({data: {id: secret}}, 401) : undefined);
  const result = await runGlobalAuthSmoke(f);
  assert.equal(result.passed, false);
  assert(!JSON.stringify(result).includes(secret));
});

for (const change of [
  {reviewed: false}, {version: 'stale'}, {locale: 'fr'}, {documentType: 'privacy_policy'}, {contentHtml: ' '},
  {contentHtml: '<p>&nbsp;</p>'}, {contentHtml: '<script>private()</script>'}, {contentHtml: '<!-- empty -->'},
]) {
  test(`legal mismatch fails: ${JSON.stringify(change)}`, async () => {
    const f = fixture((url) => url.includes('/legal/user_agreement') ? json(envelope({
      documentType: 'user_agreement', version, locale: 'en', reviewed: true, contentHtml: '<p>Test</p>', ...change,
    })) : undefined);
    assert.equal((await runGlobalAuthSmoke(f)).passed, false);
  });
}

test('redirects are not followed and response messages/unsafe request IDs are never emitted', async () => {
  const f = fixture((url) => url.includes('/auth/capabilities')
    ? json({message: secret, requestId: secret}, 302, {Location: `https://old.example/${secret}`, 'X-Request-Id': secret})
    : undefined);
  const result = await runGlobalAuthSmoke(f);
  assert.equal(result.passed, false);
  assert.equal(result.records[1].status, 'redirect_rejected');
  assert.equal(f.calls.length, 3);
  assert(!JSON.stringify(result).includes(secret));
});

test('a substituted response origin is rejected before its body', async () => {
  const f = fixture((url) => {
    if (!url.includes('/auth/capabilities')) return undefined;
    const response = json(capabilities());
    Object.defineProperty(response, 'url', {value: 'https://old.example/'});
    return response;
  });
  const result = await runGlobalAuthSmoke(f);
  assert.equal(result.records[1].status, 'origin_rejected');
  assert.equal(result.passed, false);
});

test('404 deployment stays failed with no body or exception disclosure', async () => {
  const f = fixture(() => json({message: secret, requestId: secret}, 404));
  const result = await runGlobalAuthSmoke(f);
  assert.equal(result.passed, false);
  assert(!JSON.stringify(result).includes(secret));
});

test('transport failures and invalid JSON are bounded and sanitized', async () => {
  const f = fixture((url) => {
    if (url.endsWith('/health/ready')) throw new Error(secret);
    return new Response(secret, {headers: {'content-type': 'text/html'}});
  });
  const result = await runGlobalAuthSmoke(f);
  assert.equal(result.records[0].status, 'transport_error');
  assert.equal(result.records[1].status, 'invalid_json');
  assert(!JSON.stringify(result).includes(secret));
});

test('oversized body is rejected', async () => {
  const f = fixture((url) => url.includes('/auth/capabilities') ? json(capabilities(), 200, {'Content-Length': '300000'}) : undefined);
  const result = await runGlobalAuthSmoke(f);
  assert.equal(result.records[1].status, 'body_too_large');
  assert.equal(result.passed, false);
});

test('a never-settling transport has a deadline, even when it ignores abort', async () => {
  const result = await runGlobalAuthSmoke({fetchImpl: () => new Promise(() => {}), timeoutMs: 5});
  assert.equal(result.passed, false);
  assert(result.records.slice(0, 3).every((row) => row.status === 'timeout'));
});

test('CLI has no URL, credentials or write-mode arguments and does not echo them', () => {
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('./global_auth_smoke.mjs', import.meta.url)), '--url', secret], {encoding: 'utf8'});
  assert.equal(result.status, 2);
  assert(!result.stdout.includes(secret));
  assert.equal(JSON.parse(result.stdout).status, 'invalid_arguments');
  assert.equal(result.stderr, '');
});
