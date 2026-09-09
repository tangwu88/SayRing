import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  WECHAT_APP_ID, WECHAT_AUTH_MAX_AGE_MS, buildWechatState, isFreshWechatState,
  parseWechatAuthResult, wechatAuthErrorMessage,
} from '../entry/src/main/ets/model/WechatAuthContracts.ts';

const now = Date.UTC(2026, 8, 5, 8);
const nonce = '01234567-89ab-cdef-0123456789ab';

test('public WeChat app identity is configured without a client credential', () => {
  assert.equal(WECHAT_APP_ID, 'wxc9426c8d822c1302');
  const service = readFileSync(new URL('../entry/src/main/ets/services/WechatAuthService.ets', import.meta.url), 'utf8');
  const client = readFileSync(new URL('../entry/src/main/ets/services/AccountClient.ts', import.meta.url), 'utf8');
  assert.ok(service.includes("from '@tencent/wechat_open_sdk'"));
  assert.equal(/app[_-]?secret|client[_-]?secret/i.test(service + client), false);
});

test('authorization state is unpredictable shaped, exact-match and expires', () => {
  const state = buildWechatState(now, nonce);
  assert.equal(state, `sd_${now}_${nonce}`);
  assert.equal(isFreshWechatState(state, state, now + WECHAT_AUTH_MAX_AGE_MS), true);
  assert.equal(isFreshWechatState(state, state, now + WECHAT_AUTH_MAX_AGE_MS + 1), false);
  assert.equal(isFreshWechatState(state, `${state}x`, now), false);
  assert.equal(buildWechatState(now, 'short'), '');
});

test('callback result parser rejects malformed or oversized values', () => {
  const valid = { status: 'success', code: 'temporary-code', state: buildWechatState(now, nonce),
    openId: '', message: '' };
  assert.deepEqual(parseWechatAuthResult(JSON.stringify(valid)), valid);
  for (const value of ['', 'null', '[]', '{bad', JSON.stringify({ ...valid, code: 8 }),
    JSON.stringify({ ...valid, openId: undefined }), JSON.stringify({ ...valid, openId: 'x'.repeat(129) }),
    'x'.repeat(4097)]) {
    assert.equal(parseWechatAuthResult(value), undefined);
  }
});

test('official callback outcomes use concise user messages', () => {
  assert.match(wechatAuthErrorMessage(-2), /取消/);
  assert.match(wechatAuthErrorMessage(-4), /未同意/);
  assert.match(wechatAuthErrorMessage(-5), /不支持/);
  assert.match(wechatAuthErrorMessage(-99), /失败/);
});
