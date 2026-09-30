import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks } from 'node:module';

registerHooks({ resolve(specifier, context, next) {
  if (specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier)) {
    return next(specifier + '.ts', context);
  }
  return next(specifier, context);
} });

const { parseSupportConfig } = await import('../entry/src/main/ets/model/SupportConfig.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');

test('support config accepts only configured server contact fields', () => {
  assert.deepEqual(parseSupportConfig({ configured: true, phone: ' +86 400-123-4567 ',
    officialAccount: ' Say Ring 客服 ', serviceHours: ' 工作日 09:00-18:00 ' }), {
    configured: true, phone: '+86 400-123-4567', officialAccount: 'Say Ring 客服',
    serviceHours: '工作日 09:00-18:00', message: ''
  });
});

test('unconfigured support never invents reference-project contact details', () => {
  assert.deepEqual(parseSupportConfig({ configured: false, message: '暂未配置' }), {
    configured: false, phone: '', officialAccount: '', serviceHours: '', message: '暂未配置'
  });
  assert.throws(() => parseSupportConfig({ configured: true, phone: '', officialAccount: '' }), /配置不完整/);
});

test('account client requests the isolated public support endpoint without a session', async () => {
  const calls = [];
  const client = new AccountClient({ async request(...args) {
    calls.push(args);
    return { code: 200, data: { configured: true, phone: '4001234567', officialAccount: '测试客服' } };
  } }, { async read() { return undefined; }, async write() {}, async clear() {} }, () => 0, true);
  assert.equal((await client.supportConfig()).officialAccount, '测试客服');
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], '/global/api/saydian-app/v2/support/config');
  assert.equal(calls[0][2], undefined);
});

test('contact page mirrors the reference two-row actions and reads backend config', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
  assert.match(source, /saydianApi\.supportConfig\(\)/);
  assert.match(source, /id\('contact_call'\)/);
  assert.match(source, /id\('contact_copy'\)/);
  assert.match(source, /pasteboard\.getSystemPasteboard\(\)\.setData/);
  assert.doesNotMatch(source, /4006386738/);
});
