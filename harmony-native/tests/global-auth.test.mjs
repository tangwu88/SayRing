import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier, context, next) {
  return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ? specifier + '.ts' : specifier, context);
} });
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const { validGlobalPassword, normalizeIdentifier, globalRegistrationValidation, parseGlobalSession, parseAuthCapabilities } = await import('../entry/src/main/ets/model/GlobalAuth.ts');
const { APP_LOCALES, appText, currentAppLocale, normalizeAppLocale, setAppLocale, translationKeys } = await import('../entry/src/main/ets/model/GlobalLocale.ts');
const { internationalUrl, GLOBAL_BUNDLE, GLOBAL_PAYMENTS_ENABLED, GLOBAL_WECHAT_ENABLED, GLOBAL_PUSH_ENABLED } = await import('../entry/src/main/ets/model/GlobalConfiguration.ts');
const { parseGlobalUpdate } = await import('../entry/src/main/ets/model/GlobalUpdate.ts');
const now = Date.UTC(2026,8,9), id = '10000000-0000-4000-8000-000000000001';
const session = () => ({ accessToken: 'synthetic-access', refreshToken: 'synthetic-refresh', expiresAt: new Date(now+3600000).toISOString(), member:{id,nickname:'Synthetic member'} });
const doc = type => ({path:'/api/saydian-app/v2/content/legal/'+type+'?version=fixture-v2&locale=en',locale:'en',version:'fixture-v2'});
const caps = () => ({realm:'global',defaultLocale:'en',supportedLocales:APP_LOCALES,registration:{email:true,sms:true},recovery:{email:true,sms:true},smsCountries:['US','GB'],verification:{codeLength:6,expiresIn:300,retryAfter:60},consentVersion:'fixture-v2',legal:{userAgreement:doc('user_agreement'),privacyPolicy:doc('privacy_policy')}});
const challenge = () => ({challengeId:'20000000-0000-4000-8000-000000000001',expiresIn:300,retryAfter:60,maskedIdentifier:'t***@example.com'});
const envelope = data => ({code:200,data});
function fixture(handler) {
  const calls=[], vault={value:undefined,async read(){return this.value},async write(value){this.value=value},async clear(){this.value=undefined}};
  const client=new AccountClient({async request(...args){calls.push(args);return envelope(await handler(...args))}},vault,()=>now,true);
  return {client,calls,vault};
}


test('account recovery is independent of new registration legal availability and missing recovery fails closed',async()=>{
  const disabledRegistration={...caps(),legal:null,consentVersion:null,registration:{email:false,sms:false}};
  const f=fixture(path=>path.includes('capabilities')?disabledRegistration:challenge());
  await f.client.sendVerificationCode('email','test@example.com','reset_password');
  assert.match(f.calls.at(-1)[0],/verification-code$/);
  const missing=fixture(()=>({...disabledRegistration,recovery:undefined}));
  await assert.rejects(missing.client.sendVerificationCode('email','test@example.com','reset_password'),/channel_unavailable/);
  const login=fixture(()=>session());assert.equal((await login.client.login('test@example.com','fixture-password')).memberId,id);
  assert.equal(login.calls.length,1);
});
test('report history reads preserve UUID identities and the original server conclusion text',async()=>{
  const reportId='30000000-0000-4000-8000-000000000001';
  const report={id:reportId,status:'ready',period:{from:'2026-08-10T00:00:00Z',to:'2026-09-09T00:00:00Z'},dataCompleteness:{validRecordCount:3,distinctDays:3},freePreview:{title:'Synthetic report',summary:'Synthetic source summary'},aiGenerated:true};
  const f=fixture(path=>path.endsWith('/auth/login')?session():path.endsWith('/full')?{...report,content:{overview:'Synthetic unmodified conclusion',trends:['Synthetic trend'],suggestions:[],limitations:['Synthetic limitation'],safetyNotice:'Synthetic notice'}}:{items:[report]});
  await f.client.login('test@example.com','fixture-password');
  assert.equal((await f.client.healthReports())[0].id,reportId);
  assert.deepEqual(await f.client.healthReportContent(reportId),['Synthetic unmodified conclusion','Synthetic trend','Synthetic limitation','Synthetic notice']);
  const count=f.calls.length;await assert.rejects(f.client.healthReportContent('42'));assert.equal(f.calls.length,count);
});

test('global URL and identities fail closed outside the independent instance',()=>{
  assert.equal(GLOBAL_BUNDLE,'cn.saydian.app.global.hm');
  assert.equal(internationalUrl('/api/saydian-app/v2/auth/login'),'https://app.saydian.cn/global/api/saydian-app/v2/auth/login');
  for(const path of ['https://evil.invalid/api/data','/../api/data','/api/../data','/down/files/app.hap'])assert.throws(()=>internationalUrl(path));
  assert.equal(GLOBAL_PAYMENTS_ENABLED,false);assert.equal(GLOBAL_PUSH_ENABLED,false);assert.equal(GLOBAL_WECHAT_ENABLED,false);
});
test('international password validation matches the server UTF-8 ceiling, including CJK and emoji',()=>{
  assert.equal(validGlobalPassword('short'),false);assert.equal(validGlobalPassword('a'.repeat(72)),true);
  assert.equal(validGlobalPassword('a'.repeat(73)),false);assert.equal(validGlobalPassword('好'.repeat(24)),true);
  assert.equal(validGlobalPassword('好'.repeat(25)),false);assert.equal(validGlobalPassword('😀'.repeat(18)),true);
  assert.equal(validGlobalPassword('😀'.repeat(19)),false);
});
test('email and international identifiers do not use mainland-only validation',()=>{
  assert.equal(normalizeIdentifier('email',' Test@Example.com '),'test@example.com');
  assert.equal(normalizeIdentifier('sms','+44 (7700) 900-123'),'+447700900123');
  assert.throws(()=>normalizeIdentifier('sms','07700900123'));assert.throws(()=>normalizeIdentifier('email','not-an-email'));
  assert.equal(globalRegistrationValidation('test@example.com','email','123456','fixture-password','fixture-password',true),'');
  assert.equal(globalRegistrationValidation('test@example.com','email','123456','fixture-password','other-password',true),'password_mismatch');
});
test('default-disabled channels and missing reviewed legal text never send a verification code',async()=>{
  for(const data of [{...caps(),registration:{email:false,sms:false}},{...caps(),legal:null,consentVersion:null}]){
    const f=fixture(()=>data);await assert.rejects(f.client.sendVerificationCode('email','test@example.com','register'),/channel_unavailable/);
    assert.equal(f.calls.length,1);assert.match(f.calls[0][0],/auth\/capabilities\?locale=en/);
    assert.equal(parseAuthCapabilities(data).registration.email,false);
  }
});
test('only server-enabled countries may request SMS codes',async()=>{
  const f=fixture(path=>path.includes('capabilities')?caps():challenge());
  await assert.rejects(f.client.sendVerificationCode('sms','+817000000001','register','en','JP'),/country_unavailable/);
  await f.client.sendVerificationCode('sms','+447700900123','register','en','GB');
  const body=JSON.parse(f.calls.at(-1)[3]);assert.equal(body.identifier,'+447700900123');assert.equal(body.channel,'sms');
});
test('registration uses a scoped challenge, current legal version and real UUID session',async()=>{
  const f=fixture(path=>path.includes('capabilities')?caps():path.endsWith('/verification-code')?challenge():session());
  await f.client.sendVerificationCode('email','test@example.com','register','en');
  await assert.rejects(f.client.registerGlobal('email','other@example.com','123456','fixture-password','fixture-password',true,'en','fixture-v2'),/request_code_first/);
  await assert.rejects(f.client.registerGlobal('email','test@example.com','123456','fixture-password','fixture-password',true,'en','stale'),/consent_outdated/);
  const result=await f.client.registerGlobal('email','test@example.com','123456','fixture-password','fixture-password',true,'en','fixture-v2');
  assert.equal(result.memberId,id);assert.equal(f.vault.value.memberId,id);
  const body=JSON.parse(f.calls.at(-1)[3]);assert.equal(body.consentVersion,'fixture-v2');assert.equal(body.challengeId,challenge().challengeId);
  assert.equal('password' in f.vault.value,false);assert.equal('code' in f.vault.value,false);
  await assert.rejects(f.client.registerGlobal('email','test@example.com','123456','fixture-password','fixture-password',true,'en','fixture-v2'),/request_code_first/);
});
test('reset challenge cannot be confused with a registration challenge',async()=>{
  const f=fixture(path=>path.includes('capabilities')?caps():path.endsWith('/verification-code')?challenge():session());
  await f.client.sendVerificationCode('email','test@example.com','register');
  await assert.rejects(f.client.resetGlobalPassword('email','test@example.com','123456','fixture-password','fixture-password'),/request_code_first/);
  await f.client.sendVerificationCode('email','test@example.com','reset_password');
  assert.equal((await f.client.resetGlobalPassword('email','test@example.com','123456','fixture-password','fixture-password')).memberId,id);
  assert.match(f.calls.at(-1)[0],/\/auth\/reset-password$/);
});
test('login is JSON with email or E164 and never sends a legacy session to the old server',async()=>{
  const f=fixture(()=>session());await f.client.login('Test@Example.com','fixture-password');
  assert.equal(f.calls[0][0],'/api/saydian-app/v2/auth/login');
  assert.deepEqual(JSON.parse(f.calls[0][3]),{channel:'email',identifier:'test@example.com',password:'fixture-password'});
});
test('UUID identity and ISO expiration are required; refresh cannot change ownership',()=>{
  const valid=parseGlobalSession(envelope(session()),now);assert.equal(valid.memberId,id);
  for(const value of [{...session(),expiresAt:now+3600000},{...session(),member:{id:42}},{...session(),expiresAt:new Date(now-1).toISOString()}])assert.throws(()=>parseGlobalSession(envelope(value),now));
  assert.throws(()=>parseGlobalSession(envelope(session()),now,{...valid,memberId:'10000000-0000-4000-8000-000000000002'}));
});
test('anonymous legal reading uses the published global path and validates version',async()=>{
  const f=fixture(path=>path.includes('capabilities')?caps():{version:'fixture-v2',title:'Synthetic legal text',contentHtml:'<p>Synthetic fixture only</p>'});
  const value=await f.client.globalLegal(true,'en');assert.match(value.content,/Synthetic fixture only/);
  assert.equal(f.calls[1][0],doc('privacy_policy').path);assert.equal(f.calls[1][2],undefined);
});
test('eight UI locales default to English without applying a language command to the watch',()=>{
  assert.equal(currentAppLocale(),'en');assert.equal(APP_LOCALES.length,8);assert.equal(normalizeAppLocale('unknown'),'en');
  setAppLocale('fr');assert.equal(appText('login'),'Se connecter');setAppLocale('en');
  assert.equal(appText('查看待支付订单','en'),'View unpaid orders');
  assert.ok(translationKeys().length>=500);
  for(const key of translationKeys())for(const locale of APP_LOCALES){assert.equal(typeof appText(key,locale),'string');assert.ok(appText(key,locale).length>0);}
  const store=readFileSync(new URL('../entry/src/main/ets/services/AppLocaleStore.ets',import.meta.url),'utf8');
  assert.match(store,/saydian_global_preferences/);assert.match(store,/await this.store.flush/);assert.doesNotMatch(store,/vep|yuc|Wearable|setWatchLanguage/i);
});
test('raw user and server text is displayed unchanged instead of matching UI labels',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  for(const field of ['message.text','message.content','invite.name','member.name','block.text','this.selectedOrder.number']){
    assert.ok(source.includes('Text('+field+')'));assert.equal(source.includes('Text(this.tr('+field+'))'),false);
  }
});
test('new global storage cannot restore a domestic token or health database',()=>{
  const vault=readFileSync(new URL('../entry/src/main/ets/services/SessionVault.ets',import.meta.url),'utf8');
  const health=readFileSync(new URL('../entry/src/main/ets/services/WearableHealthStore.ets',import.meta.url),'utf8');
  assert.match(vault,/saydian.global.harmony.session.v1/);assert.match(health,/saydian_global_wearable_health.db/);
});
test('updates require published global bundle metadata and a scoped hashed package',()=>{
  const release={platform:'harmonyos',packageId:GLOBAL_BUNDLE,status:'available',versionName:'1.0.1',buildNumber:10,destination:{kind:'direct',url:'/global/down/files/global-10.hap',fileName:'global-10.hap',sizeBytes:100,sha256:'a'.repeat(64)}};
  const manifest={realm:'global',schemaVersion:1,releases:[release]};
  assert.equal(parseGlobalUpdate(manifest,9).hasUpdate,true);assert.equal(parseGlobalUpdate(manifest,10).hasUpdate,false);
  for(const mutated of [{...manifest,realm:'domestic'},{...manifest,releases:[{...release,packageId:'domestic.fixture'}]},{...manifest,releases:[{...release,status:'coming_soon'}]},{...manifest,releases:[{...release,destination:{...release.destination,url:'/down/files/global-10.hap'}}]}])assert.throws(()=>parseGlobalUpdate(mutated,9));
});
