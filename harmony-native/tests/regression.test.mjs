import test from 'node:test';
import assert from 'node:assert/strict';
import { parseSession, decodeEnvelope, profileField } from '../entry/src/main/ets/model/Contracts.ts';

const now = Date.UTC(2026, 8, 4, 10);
test('login must have a stable scalar account identity', () => {
  for (const id of [undefined, null, '', ' ', {}, [], true]) {
    assert.throws(() => parseSession({ data: {
      access_token: 'synthetic-access', refresh_token: 'synthetic-refresh',
      expiration_time: 3600, member: { id }
    } }, now), /账号|身份/);
  }
});
test('non-finite profile numbers are not rendered as personal values', () => {
  for (const value of [NaN, Infinity, -Infinity, ' ', 'NaN', 'Infinity']) {
    assert.equal(profileField(value, ' kg'), '未填写');
  }
});
test('HTTP failure status takes priority over conflicting business code', () => {
  assert.throws(() => decodeEnvelope('{"code":401}', 503), e => e.status === 503);
  assert.throws(() => decodeEnvelope('{"code":500}', 401), e => e.status === 401);
});
