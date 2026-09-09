import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';

globalThis.wechatPaymentFixture = { installed: true, sent: true, requests: [], sequence: 0 };
globalThis.notificationSettingFixture = { api: 12, opens: 0, rejects: false };
globalThis.canIUse = () => false;
const stubs = {
  '@kit.ArkTS': 'export const util={generateRandomUUID:()=>`fixture-${++globalThis.wechatPaymentFixture.sequence}`}',
  '@kit.AbilityKit': 'export const abilityAccessCtrl={},bundleManager={},common={},Permissions={}',
  '@kit.BasicServicesKit': 'export const deviceInfo={get sdkApiVersion(){return globalThis.notificationSettingFixture.api;}}',
  '@kit.NotificationKit': `export const notificationManager={openNotificationSettings:async()=>{
    globalThis.notificationSettingFixture.opens++;
    if(globalThis.notificationSettingFixture.rejects)throw Error('fixture');
  }}`,
  '@tencent/wechat_open_sdk': `
    export class PayReq { checkArgs(){return true;} }
    export const ErrCode={ERR_OK:0,ERR_USER_CANCEL:-2};
    export const WXAPIFactory={createWXAPI:()=>({
      isWXAppInstalled:()=>globalThis.wechatPaymentFixture.installed,
      sendReq:(_context,request)=>{globalThis.wechatPaymentFixture.requests.push(request);return globalThis.wechatPaymentFixture.sent;}
    })};`,
  '@cashier_alipay/cashiersdk': `export class Pay {pay(){return Promise.resolve(new Map([['resultStatus','6001']]))}}`
};
registerHooks({
  resolve(specifier, context, next) {
    if (stubs[specifier]) return { url: `data:text/javascript,${encodeURIComponent(stubs[specifier])}`, shortCircuit: true };
    if (specifier.startsWith('.') && /\.(ts|ets)$/.test(context.parentURL || '') && !/\.[a-z]+$/.test(specifier)) {
      const extension = context.parentURL.endsWith('.ets') && specifier.startsWith('./') ? '.ets' : '.ts';
      return next(specifier + extension, context);
    }
    return next(specifier, context);
  },
  load(url, context, next) {
    if (url.endsWith('.ets')) return { format: 'module', source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8')), shortCircuit: true };
    return next(url, context);
  }
});
const { nativeWechatPayment, matchesWechatPayment } = await import('../entry/src/main/ets/model/WechatPaymentContracts.ts');
const { wechatPayment } = await import('../entry/src/main/ets/services/WechatPaymentService.ets');
const { canStartHarmonyPayment, harmonyPayment } = await import('../entry/src/main/ets/services/HarmonyPaymentService.ets');
const { openPermissionSetting } = await import('../entry/src/main/ets/services/PermissionPresentation.ets');
const { WECHAT_APP_ID } = await import('../entry/src/main/ets/model/WechatAuthContracts.ts');
const appId = 'wxfixture12345678';
const signed = { appId, partnerId: '1900000109', prepayId: 'fixture-prepay', nonceStr: 'fixture-nonce',
  timeStamp: '1788624000', packageValue: 'Sign=WXPay', sign: 'server-signed-fixture', signType: 'RSA' };
const request = (fields = signed) => ({ provider: 'wechat', thirdAppId: appId, payInfo: JSON.stringify(fields) });

test('native WeChat copies complete server-signed Harmony fields without inventing a signature', () => {
  assert.deepEqual(nativeWechatPayment(request(), appId), signed);
  assert.equal(nativeWechatPayment({ ...request(), provider: 'alipay' }, appId), undefined);
  assert.equal(nativeWechatPayment(request({ opaque_third_pay_data: 'fixture' }), appId), undefined);
  assert.throws(() => nativeWechatPayment(request({ ...signed, sign: '' }), appId));
  assert.throws(() => nativeWechatPayment(request({ ...signed, appId: 'wx-other' }), appId));
  assert.throws(() => nativeWechatPayment({ ...request(), thirdAppId: 'wx-other' }, appId));
  assert.throws(() => nativeWechatPayment(request({ ...signed, timeStamp: '0' }), appId));
  assert.throws(() => nativeWechatPayment(request({ ...signed, nonceStr: 'unsafe\nvalue' }), appId));
});

test('WeChat callbacks require the active transaction or prepay and reject contradictory identifiers', () => {
  assert.equal(matchesWechatPayment('p1', 't1', 'p1', ''), true);
  assert.equal(matchesWechatPayment('p1', 't1', '', 't1'), true);
  for (const [prepay, transaction] of [['p0', 't1'], ['p1', 't0'], ['', '']]) {
    assert.equal(matchesWechatPayment('p1', 't1', prepay, transaction), false);
  }
});

test('SDK launch acknowledgment does not finish payment; mismatched and duplicate callbacks are ignored', async () => {
  let finished = false;
  const started = wechatPayment.start({}, signed).then(() => { finished = true; });
  const active = globalThis.wechatPaymentFixture.requests.at(-1);
  for (const [key, value] of Object.entries(signed)) assert.equal(active[key], value);
  assert.equal(active.callbackAbility, 'EntryAbility');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(finished, false);
  await assert.rejects(wechatPayment.start({}, signed), /正在处理/);
  wechatPayment.handleResponse({ errCode: 0, prepayId: 'old-prepay', transaction: active.transaction });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(finished, false);
  wechatPayment.handleResponse({ errCode: 0, prepayId: signed.prepayId, transaction: active.transaction });
  await started;
  wechatPayment.handleResponse({ errCode: 0, prepayId: signed.prepayId, transaction: active.transaction });
  assert.equal(finished, true);
});

test('cancel and failed launch settle without a payment success and release the single-flight lock', async () => {
  const canceled = wechatPayment.start({}, signed);
  const assertion = assert.rejects(canceled, /已取消/);
  const active = globalThis.wechatPaymentFixture.requests.at(-1);
  wechatPayment.handleResponse({ errCode: -2, prepayId: signed.prepayId, transaction: active.transaction });
  await assertion;
  globalThis.wechatPaymentFixture.sent = false;
  await assert.rejects(wechatPayment.start({}, signed), /未能打开/);
  globalThis.wechatPaymentFixture.sent = true;
  globalThis.wechatPaymentFixture.installed = false;
  await assert.rejects(wechatPayment.start({}, signed), /请先安装微信/);
  globalThis.wechatPaymentFixture.installed = true;
});

test('W8 SDK raises the app minimum to API 17 while notification settings keeps its older-system fallback', () => {
  const build = JSON.parse(readFileSync(new URL('../build-profile.json5', import.meta.url), 'utf8'));
  assert.equal(build.app.products[0].compatibleSdkVersion, '5.0.5(17)');
  const source = readFileSync(new URL('../entry/src/main/ets/services/PermissionPresentation.ets', import.meta.url), 'utf8');
  assert.ok(source.indexOf('deviceInfo.sdkApiVersion >= 13') < source.indexOf('notificationManager.openNotificationSettings'));
  assert.ok(source.includes("action: 'action.settings.app.info'"));
});

test('API 12 uses signed WeChat PayReq and the bundled Alipay cashier while opaque ThirdPay stays gated', async () => {
  assert.equal(canStartHarmonyPayment('wechat'), true);
  assert.equal(canStartHarmonyPayment('alipay'), true);
  const payment = { ...request({ ...signed, appId: WECHAT_APP_ID }), thirdAppId: WECHAT_APP_ID };
  const started = harmonyPayment.start({}, payment);
  const active = globalThis.wechatPaymentFixture.requests.at(-1);
  wechatPayment.handleResponse({ errCode: 0, transaction: active.transaction });
  await started;
  await assert.rejects(harmonyPayment.start({}, { ...payment, provider: 'alipay', payInfo: 'server-signed-order' }), /已取消/);
  await assert.rejects(harmonyPayment.start({}, { ...payment, payInfo: '{"opaque":true}' }), /暂时不可用/);
});

test('notification settings uses API 12 app settings without calling API 13 and handles unresolved routes', async () => {
  const wants = [];
  const context = { applicationInfo: { name: 'cc.saydian.fixture' }, startAbility: async want => wants.push(want) };
  await openPermissionSetting(context, 'notifications');
  assert.equal(globalThis.notificationSettingFixture.opens, 0);
  assert.deepEqual(wants[0], { action: 'action.settings.app.info', parameters: { settingsParamBundleName: 'cc.saydian.fixture' } });
  globalThis.notificationSettingFixture.api = 13;
  await openPermissionSetting(context, 'notifications');
  assert.equal(globalThis.notificationSettingFixture.opens, 1);
  assert.equal(wants.length, 1);
  globalThis.notificationSettingFixture.rejects = true;
  await openPermissionSetting(context, 'notifications');
  assert.equal(wants.length, 2);
  await assert.rejects(openPermissionSetting({ ...context, startAbility: async () => { throw Error('fixture'); } }, 'notifications'), /系统设置/);
});
