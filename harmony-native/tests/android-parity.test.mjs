import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier, context, next) {
  return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ? `${specifier}.ts` : specifier, context);
} });
const model = await import('../entry/src/main/ets/model/RingParity.ts');
const config = await import('../entry/src/main/ets/model/GlobalConfiguration.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const source = name => readFileSync(new URL(`../entry/src/main/ets/${name}`, import.meta.url), 'utf8');
const now = Date.now(), id = '10000000-0000-4000-8000-000000000032';
const document = type => ({path:`/api/saydian-app/v2/content/legal/say_ring_${type}?version=fixture-v3&locale=zh-Hans`,version:'fixture-v3',locale:'zh-Hans'});
const caps = () => ({realm:'global',product:'say-ring',defaultLocale:'zh-Hans',supportedLocales:['zh-Hans'],
  login:{email:true,sms:true,explicitRegistrationCodeLogin:true,smsAutoRegistration:true}, registration:{email:true,sms:true,verificationRequired:true},recovery:{email:true,sms:true},
  smsCountries:['CN'],verification:{codeLength:6,expiresIn:300,retryAfter:60},consentVersion:'fixture-v3',
  legal:{userAgreement:document('user_agreement'),privacyPolicy:document('privacy_policy')}});
const challenge = () => ({challengeId:'synthetic-challenge-1132',expiresIn:300,retryAfter:60,maskedIdentifier:'1********00'});
const session = () => ({token:'synthetic-access',refreshToken:'synthetic-refresh',expiresAt:new Date(now+3600000).toISOString(),user:{id,nickname:'合成账号'}});
function fixture(handler) {
  const calls=[],vault={value:undefined, async read(){return this.value}, async write(value){this.value=value},async clear(){this.value=undefined}};
  const client = new AccountClient({async request(...args){calls.push(args);return args[0].includes('/capabilities?') ? {code:200,data:await handler(...args)} : await handler(...args)}},vault,()=>now,true);
  return {client,calls,vault};
}
test('Harmony primary palette and customer-service destination match Android sources',()=>{
  const theme=readFileSync(new URL('../../lib/ui/app_theme.dart',import.meta.url),'utf8');
  for(const color of ['285C68','1E2933','687181','F7F7F5','E8EBF0']) assert.ok(theme.includes(color));
  assert.equal(model.RING_THEME.primary,'#285C68');
  assert.ok(readFileSync(new URL('../../lib/services/say_ring_support.dart',import.meta.url),'utf8').includes(model.RING_CUSTOMER_SERVICE));
});
test('global request routing admits deployed V2 and only the two exact Android shared auth endpoints',()=>{
  assert.equal(config.ringRequestUrl('/global/api/saydian-app/v2/member/profile'),'https://app.saydian.cn/global/api/saydian-app/v2/member/profile');
  const android=readFileSync(new URL('../../lib/services/global_environment.dart',import.meta.url),'utf8');
  for(const path of [config.RING_CODE_REQUEST,config.RING_CODE_LOGIN]) {assert.ok(android.includes(path));assert.equal(config.ringRequestUrl(path),'https://app.saydian.cn'+path);}
  for(const path of ['/api/saidian-mall/v1/auth/code/login','https://evil.invalid/a','/global/api/saidian-mall/v1/auth/code/login?other=1','/global/api/saidian-mall/v1/other','/global/api/saydian-app/v2/../other']) assert.throws(()=>config.ringRequestUrl(path));
  assert.match(source('services/SaydianApi.ets'),/const url = ringRequestUrl\(path\)/);
  assert.match(source('services/LegacySafeHttp.ets'),/sharedCode && \(method !== 'POST' \|\| headers\['Authorization'\]\)/);
});
test('China phone normalization has no country selector or permissive prose parsing',()=>{
  assert.equal(model.ringLoginIdentifier('sms','13800000000'),'+8613800000000');
  assert.equal(model.ringLoginIdentifier('sms','+8613800000000'),'+8613800000000');
  assert.equal(model.ringLoginIdentifier('email',' TEST@example.com '),'test@example.com');
  for(const raw of ['123','+447700900123','电话13800000000','13800000000x1']) assert.throws(()=>model.ringLoginIdentifier('sms',raw));
});
test('capability absent, disabled country, or unpublished legal metadata closes code login',()=>{
  for(const value of [{...caps(),login:undefined},{...caps(),smsCountries:[]},{...caps(),consentVersion:''},{...caps(),legal:undefined}]) assert.equal(model.ringLoginAvailable(value,'sms'),false);
});
test('SMS code request uses the Android product, identity, country and public-only endpoint',async()=>{
  const f=fixture(path=>path.includes('/capabilities?')?caps():challenge());
  assert.equal((await f.client.requestRingLoginCode('sms','13800000000','zh-Hans')).challengeId,challenge().challengeId);
  assert.equal(f.calls[1][0],config.RING_CODE_REQUEST); assert.equal(f.calls[1][2],undefined);
  assert.deepEqual(JSON.parse(f.calls[1][3]),{product:'say-ring',channel:'sms',identifier:'+8613800000000',country:'CN',locale:'zh-Hans'});
});
test('closed login service never sends a code request',async()=>{
  const f=fixture(()=>({...caps(),login:{email:false,sms:false}}));
  await assert.rejects(f.client.requestRingLoginCode('sms','13800000000','zh-Hans'));
  assert.equal(f.calls.length,1);
});
test('code login persists real returned identity with consent and age, never legacy registration',async()=>{
  const f=fixture(path=>path.includes('/capabilities?')?caps():session());
  const value=await f.client.loginRingWithCode('sms','13800000000',challenge().challengeId,'123456','fixture-v3',true,true,'zh-Hans');
  assert.equal(value.memberId,id);assert.equal(f.vault.value.memberId,id);assert.equal(f.calls[1][0],config.RING_CODE_LOGIN);
  const body=JSON.parse(f.calls[1][3]);assert.equal(body.ageConfirmed,true);assert.equal(body.consentVersion,'fixture-v3');assert.equal(body.product,'say-ring');
  assert.equal(f.calls.some(call=>call[0].includes('register')),false);
});
test('missing consent or minimum-age confirmation makes zero requests',async()=>{
  for(const [accepted,age] of [[false,true],[true,false]]) {const f=fixture(()=>session());
    await assert.rejects(f.client.loginRingWithCode('sms','13800000000',challenge().challengeId,'123456','fixture-v3',accepted,age,'zh-Hans'));assert.equal(f.calls.length,0);}
});
test('updated legal version cannot be silently accepted during login',async()=>{
  const f=fixture(()=>caps());await assert.rejects(f.client.loginRingWithCode('sms','13800000000',challenge().challengeId,'123456','old-version',true,true,'zh-Hans'));
  assert.equal(f.calls.length,1);assert.equal(f.vault.value,undefined);
});
test('test-mode and expired identities are rejected, zero retryAfter is accepted',()=>{
  assert.equal(model.parseRingLoginChallenge({...challenge(),retryAfter:0}).retryAfter,0);
  assert.throws(()=>model.parseRingLoginChallenge({...challenge(),retryAfter:-1}));
  for(const payload of [{...session(),user:{id,phoneTestMode:true}},{...session(),expiresAt:new Date(now-1000).toISOString()},{...session(),token:''},{...session(),refreshToken:''}]) assert.throws(()=>model.parseRingLoginSession(payload,now));
});
test('card ordering and visibility never invent unsupported metrics or modify available records',()=>{
  const available=['activity','sleep','heart']; const original=[...available];
  const layout=model.parseHomeCardLayout({order:['heart','unsupported','heart','sleep'],hidden:['sleep']});
  assert.deepEqual(model.orderedHomeCards(available,layout),['heart','activity']);
  assert.deepEqual(model.orderedHomeCards(available,layout,true),['heart','sleep','activity']);assert.deepEqual(available,original);
  assert.deepEqual(model.orderedHomeCards(available,{order:[],hidden:available}),[]);
});
test('care switches follow supported metrics while preserving hidden and unknown prior grants',()=>{
  assert.deepEqual(model.ringCareOptions(false,['heart','oxygen']).map(option=>option.key),['bloodOxygen','heartReat']);
  assert.deepEqual(model.ringCareOptions(false,[]),[]);
  const original={enabled:['heartReat','bloodPressure','server_extra'],unknown:['future_extra']};
  const next=model.toggleRingCareGroup(original,['heartReat','bloodOxygen']);
  assert.deepEqual(next,{enabled:['bloodPressure','server_extra','heartReat','bloodOxygen'],unknown:['future_extra']});
  assert.deepEqual(original.enabled,['heartReat','bloodPressure','server_extra']);
  assert.deepEqual(model.toggleRingCareGroup(original,[]),original);
});
test('a late code-login reply cannot restore a session after logout',async()=>{
  let respond, arrived;
  const started=new Promise(resolve=>arrived=resolve), blocked=new Promise(resolve=>respond=resolve);
  const f=fixture(path=>{if(path.includes('/capabilities?'))return caps();arrived();return blocked;});
  const pending=f.client.loginRingWithCode('sms','13800000000',challenge().challengeId,'123456','fixture-v3',true,true,'zh-Hans');
  const rejected=assert.rejects(pending);await started;await f.client.logout();respond(session());await rejected;
  assert.equal(f.vault.value,undefined);assert.equal(f.client.current(),undefined);
});
test('login, card editing and sport routes expose Android-equivalent interactions without fake native controls',()=>{
  const ui=source('pages/Index.ets'), login=ui.slice(ui.indexOf('  Login() {'),ui.indexOf('  Registration() {'));
  assert.match(ui,/appLocale: string = 'zh-Hans'/);assert.match(ui,/authChannel: AuthChannel = 'sms'/);
  assert.doesNotMatch(login,/this.LanguagePicker\(|auth_country/);
  assert.match(login,/this.AuthMethodSelector\(\)/);
  assert.match(ui,/passwordLoginMode: boolean = true/);
  assert.match(ui,/this.pageWidth >= 332 && this.systemFontScale <= 1.2/);
  for(const id of ['login_send_code','login_code','home_edit_cards','save_home_cards','sport_more','ring_wechat_support']) assert.ok(ui.includes(id));
  assert.match(ui,/this.loginChallengeIdentity !==/);assert.match(ui,/Date.now\(\) >= this.loginChallengeExpiresAt/);
  assert.match(ui,/modes.slice\(0, 4\)/);assert.match(ui,/this.HomeCardEditor\(\)/);
  assert.match(source('services/HomeCardPreferenceStore.ets'),/encodeURIComponent\(owner/);
  assert.match(source('services/AppLocaleStore.ets'),/const locale = 'zh-Hans'/);
  assert.match(source('model/GlobalConfiguration.ts'),/GLOBAL_WECHAT_ENABLED: boolean = false/);
});

test('ring discovery guidance never asks a screenless ring to light up or confirm on-device',()=>{
  const ui=source('pages/Index.ets');
  assert.doesNotMatch(ui,/让手表保持亮屏|手表保持亮屏|如果手表弹出确认|其他设置可在手表上查看和调整/);
  assert.ok(ui.includes('如手机出现系统配对请求，请核对名称后确认'));
  assert.ok(ui.includes('仅已适配的型号可连接'));
  assert.doesNotMatch(ui,/#FFF1F3|#FFE4E9|#33D20B27/);
});
