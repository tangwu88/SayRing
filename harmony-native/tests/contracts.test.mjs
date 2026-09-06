import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  API_BASE, ApiError, decodeEnvelope, loginValidation, expirationMillis, parseSession,
  buildMultipart, profileImageUrl, profileName, profileField, articleText, safeMessage, canSubmitLogin,
  registrationValidation, wechatAuthorizationValidation,
} from '../entry/src/main/ets/model/Contracts.ts';

const now = Date.UTC(2026, 8, 4, 8);
const fixture = () => ({ code: 200, data: { access_token: 'synthetic-test-token', refresh_token: 'synthetic-refresh',
  expiration_time: 3600, member: { id: 'fixture-only', nickname: '测试夹具' } } });

test('production endpoint is fixed HTTPS', () => assert.equal(API_BASE, 'https://app.saidian.cc'));
test('consent starts required before authentication', () => assert.match(loginValidation('fixture', 'x', false), /同意/));
test('both button and keyboard must wait for session restoration and pending login', () => {
  assert.equal(canSubmitLogin(false, false), true);
  for (const [busy, restoring] of [[true, false], [false, true], [true, true]]) {
    assert.equal(canSubmitLogin(busy, restoring), false);
  }
});
test('empty and excessive account rejected', () => {
  assert.match(loginValidation(' ', 'x', true), /账号/);
  assert.match(loginValidation('x'.repeat(129), 'x', true), /长度/);
});
test('empty and excessive password rejected without changing real password rules', () => {
  assert.match(loginValidation('fixture', '', true), /密码/);
  assert.match(loginValidation('fixture', 'x'.repeat(257), true), /长度/);
  assert.equal(loginValidation(' fixture ', ' x ', true), '');
});
test('registration requires a valid mobile code matching passwords and consent', () => {
  assert.match(registrationValidation('13800138000', '123456', 'abcdef', 'abcdef', false), /同意/);
  assert.match(registrationValidation('1380013800', '123456', 'abcdef', 'abcdef', true), /手机号/);
  assert.match(registrationValidation('13800138000', '12ab', 'abcdef', 'abcdef', true), /验证码/);
  assert.match(registrationValidation('13800138000', '123456', 'short', 'short', true), /至少/);
  assert.match(registrationValidation('13800138000', '123456', 'abcdef', 'different', true), /不一致/);
  assert.equal(registrationValidation(' 13800138000 ', ' 123456 ', 'abcdef', 'abcdef', true), '');
});
test('native WeChat callback accepts only bounded one-time codes and signed state shape', () => {
  const state = 'sd_1788569000000_01234567-89ab-cdef-0123456789ab';
  assert.equal(wechatAuthorizationValidation('temporary-code', state), '');
  assert.match(wechatAuthorizationValidation('bad code', state), /授权信息/);
  assert.match(wechatAuthorizationValidation('temporary-code', 'bad-state'), /授权状态/);
});
test('HTTP and business errors are both enforced', () => {
  assert.throws(() => decodeEnvelope('{"code":401,"message":"请登录"}', 200), (e) => e instanceof ApiError && e.status === 401);
  assert.throws(() => decodeEnvelope('{"code":200}', 500));
  assert.throws(() => decodeEnvelope('{"code":422,"message":"密码错误"}', 200), /密码错误/);
});
test('malformed and non-object API responses fail safely', () => {
  for (const input of ['null', '[]', '123', '"ok"', '<html>Bad gateway</html>']) {
    assert.throws(() => decodeEnvelope(input, 200), /格式异常/);
  }
});
test('200 and string 200 success variants', () => {
  assert.equal(decodeEnvelope('{"code":"200","data":{}}', 200).code, '200');
  assert.equal(decodeEnvelope('{"data":{}}', 200).code, undefined);
});
test('server stack traces never become UI messages', () => {
  assert.equal(safeMessage('<b>Exception /var/www/token</b>', '安全错误'), '安全错误');
  assert.equal(safeMessage('x'.repeat(200), '安全错误'), '安全错误');
  assert.equal(safeMessage('密码错误', '安全错误'), '密码错误');
});
test('relative, epoch-seconds and epoch-ms expiration', () => {
  assert.equal(expirationMillis(3600, now), now + 3600000);
  assert.equal(expirationMillis(String((now + 3600000) / 1000), now), now + 3600000);
  assert.equal(expirationMillis(now + 3600000, now), now + 3600000);
  assert.equal(expirationMillis(undefined, now), now + 43200000);
});
test('invalid expiration values rejected', () => {
  for (const raw of [-1, 0, 'garbage', Infinity, NaN]) assert.throws(() => expirationMillis(raw, now));
});
test('session keeps account identity and no password field', () => {
  const session = parseSession(fixture(), now);
  assert.equal(session.memberId, 'fixture-only');
  assert.equal(session.displayName, '测试夹具');
  assert.equal(session.expiresAt, now + 3600000);
  assert.equal('password' in session, false);
});
test('missing or wrong-type access token cannot be success', () => {
  for (const access_token of [undefined, '', ' ', 123]) {
    assert.throws(() => parseSession({ data: { access_token } }, now), /凭证/);
  }
});
test('already expired absolute token is rejected', () => {
  const payload = fixture(); payload.data.expiration_time = now - 1000;
  assert.throws(() => parseSession(payload, now), /过期/);
});
test('refresh cannot change member identity', () => {
  const original = parseSession(fixture(), now);
  const changed = fixture(); changed.data.member.id = 'different-fixture';
  assert.throws(() => parseSession(changed, now, original), /账号状态/);
});
test('refresh safely retains omitted identity and refresh token', () => {
  const original = parseSession(fixture(), now);
  const next = parseSession({ data: { access_token: 'synthetic-next', expiration_time: 3600 } }, now, original);
  assert.equal(next.memberId, original.memberId);
  assert.equal(next.refreshToken, original.refreshToken);
});
test('profile missing values are not health zeros', () => {
  assert.equal(profileName({ nickname: ' ', username: 'fallback' }), 'fallback');
  assert.equal(profileField(undefined, ' kg'), '未填写');
  assert.equal(profileField('', ' kg'), '未填写');
  assert.equal(profileField(62, ' kg'), '62 kg');
});
test('multipart matches existing native app contract and preserves special characters', () => {
  const body = buildMultipart([{ name: 'password', value: 'fixture&=中文+ ' }, { name: 'group', value: 'app' }], '----TestBoundary');
  assert.ok(body.includes('name="password"\r\n\r\nfixture&=中文+ \r\n'));
  assert.ok(body.endsWith('------TestBoundary--\r\n'));
  assert.ok(body.includes('name="group"\r\n\r\napp\r\n'));
});
test('multipart names and boundary cannot inject headers', () => {
  assert.throws(() => buildMultipart([{ name: 'x"\r\nInjected', value: 'test' }], '----TestBoundary'));
  assert.throws(() => buildMultipart([], 'bad\r\nBoundary'));
});
test('profile image upload accepts only a bounded HTTPS or same-origin path', () => {
  assert.equal(profileImageUrl({ path: '/attachment/avatar/test.png' }), 'https://app.saidian.cc/attachment/avatar/test.png');
  assert.equal(profileImageUrl({ url: 'https://cdn.example.invalid/avatar/a.webp' }), 'https://cdn.example.invalid/avatar/a.webp');
  for (const data of [{}, { url: 'http://example.invalid/a.png' }, { path: '/../secret' }, { url: 'javascript:bad' }]) {
    assert.throws(() => profileImageUrl(data), /头像/);
  }
});
test('article content is plain text, not active scripts', () => {
  assert.equal(articleText('<script>alert(1)</script><p>第一段</p><p>第二段 &amp; 内容</p>'), '第一段\n第二段 & 内容');
  assert.equal(articleText(undefined), '');
});
test('native manifest declares only network and foreground wearable discovery permissions', () => {
  const manifest = JSON.parse(readFileSync(new URL('../entry/src/main/module.json5', import.meta.url)));
  assert.deepEqual(manifest.module.requestPermissions.map(item => item.name), [
    'ohos.permission.INTERNET',
    'ohos.permission.ACCESS_BLUETOOTH',
    'ohos.permission.APPROXIMATELY_LOCATION',
    'ohos.permission.LOCATION',
  ]);
  for (const item of manifest.module.requestPermissions.slice(1)) {
    assert.match(item.reason, /^\$string:/);
    assert.deepEqual(item.usedScene, { abilities: ['EntryAbility'], when: 'inuse' });
  }
  assert.equal(manifest.module.abilities[0].name, 'EntryAbility');
});
test('credential storage never falls back to plaintext preferences', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/services/SessionVault.ets', import.meta.url), 'utf8');
  assert.ok(source.includes('@kit.AssetStoreKit'));
  assert.ok(source.includes('DEVICE_UNLOCKED'));
  assert.equal(/preferences|writeFile|console\./.test(source), false);
});
test('network requests are bounded and do not follow credential redirects', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/services/SaydianApi.ets', import.meta.url), 'utf8');
  assert.ok(source.includes('maxRedirects: 0'));
  assert.ok(source.includes('connectTimeout: 15000'));
  assert.ok(source.includes('client.destroy()'));
  assert.equal(/console\.|hilog\./.test(source), false);
});
