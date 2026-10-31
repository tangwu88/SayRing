import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';
registerHooks({resolve(specifier, context, next) {
  return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ? `${specifier}.ts` : specifier, context);
}});
const m = await import('../entry/src/main/ets/model/ReadingReminders.ts');
const home = await import('../entry/src/main/ets/model/RingHomePresentation.ts');
const contracts = await import('../entry/src/main/ets/model/WearableContracts.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const { ringLoginAvailable, ringLoginFailure } = await import('../entry/src/main/ets/model/RingParity.ts');
const now = Date.now(), owner = '10000000-0000-4000-8000-000000000001';
function snapshot() {
  const s=contracts.emptyWearableSnapshot();
  Object.assign(s,{connected:true,deviceKey:'synthetic-device',firmware:'fixture-fw',provider:'Yuc'});
  Object.assign(s.capabilities,{heart:true,oxygen:true,hrv:true,temperature:true,activity:true});
  return s;
}
function record(metric='heart',value=130,unit='bpm',name='心率') {
  return {id:'synthetic-record',deviceKey:'synthetic-device',metric,timestamp:now,source:'app_measurement',values:[{name,value,unit}],samples:[],sampleFrequency:0};
}
function completed(metric='heart') {return {...contracts.emptyMeasurement(),metric,progress:100};}
function event(settings,s=snapshot(),r=record(),state=completed()) {
  return m.evaluatePersonalReading(settings,s,r,state,now-2000,now+1000);
}
test('capability filtering never treats account history as a device grant',()=>{
  const s=snapshot();s.records=[record('ecg',1,'mV')];
  assert.equal(home.ringMetricVisible(s,'connected','heart'),true);
  assert.equal(home.ringMetricVisible(s,'connected','ecg'),false);
  for(const phase of ['idle','connecting','authenticating','error']) assert.equal(home.ringMetricVisible(s,phase,'heart'),false);
  s.connected=false;assert.equal(home.ringMetricVisible(s,'connected','heart'),false);
  s.connected=true;s.deviceKey='';assert.equal(home.ringMetricVisible(s,'connected','heart'),false);
});
test('activity conversion preserves unknown calories and converts only explicit distance units',()=>{
  const r=record('activity',8000,'raw','calories');
  assert.deepEqual(home.ringActivitySummary(r),{});
  r.values.push({name:'距离',value:150,unit:'m'},{name:'步数',value:239,unit:'步'});
  assert.deepEqual(home.ringActivitySummary(r),{distance:0.15,steps:239});
  r.values[0].unit='kcal';assert.equal(home.ringActivitySummary(r).calories,8000);
  assert.equal(home.ringActivityText(undefined),'--');assert.equal(home.ringActivityText(0),'0');
  assert.equal(home.ringActivityProgress(200,100),100);
  const older={...r,timestamp:now-86400000},other={...r,deviceKey:'another-ring',timestamp:now+1};
  assert.deepEqual(home.ringTodayActivity([older,other],'synthetic-device',now),{});
  assert.equal(home.ringTodayActivity([r,other],'synthetic-device',now).steps,239);
});
test('reading reminders remain opt in and reject history, stale, malformed and incomplete observations',()=>{
  assert.equal(event(m.defaultReadingSettings()),undefined);
  const settings={...m.defaultReadingSettings(),highEnabled:true};
  assert.equal(event(settings).rule,'high');
  for(const patch of [{source:'watch_history'},{timestamp:now-200000},{timestamp:now+5000},{deviceKey:'other'},{id:''}])
    assert.equal(event(settings,snapshot(),{...record(),...patch}),undefined);
  for(const value of [undefined,NaN,Infinity,0,999]) assert.equal(event(settings,snapshot(),{...record(),values:[{name:'心率',value,unit:'bpm'}]}),undefined);
  assert.equal(event(settings,snapshot(),record('heart',130,'unknown')),undefined);
  assert.equal(event(settings,snapshot(),record(),{...completed(),running:true}),undefined);
  assert.equal(event(settings,snapshot(),record(),{...completed(),progress:99}),undefined);
  const s=snapshot();s.capabilities.heart=false;assert.equal(event(settings,s),undefined);
});
test('HRV and skin references are independent, target/firmware scoped, and body estimates are excluded',()=>{
  const settings={...m.defaultReadingSettings(),hrvEnabled:true,temperatureEnabled:true,
    hrvReference:80,hrvDevice:'synthetic-device',hrvFirmware:'fixture-fw',
    skinReference:33,skinDevice:'synthetic-device',skinFirmware:'fixture-fw'};
  const s=snapshot(),hrv=record('hrv',40,'ms','HRV'),skin=record('temperature',34,'°C','体表温度');s.records=[skin];
  assert.equal(event(settings,s,hrv,completed('hrv')).rule,'hrv');
  assert.equal(event(settings,s,skin,completed('temperature')).rule,'temperature');
  assert.equal(event({...settings,hrvFirmware:'old'},s,hrv,completed('hrv')),undefined);
  assert.equal(event({...settings,skinFirmware:'old'},s,skin,completed('temperature')),undefined);
  assert.ok(event({...settings,skinFirmware:'old'},s,hrv,completed('hrv')));
  assert.equal(m.skinValue({...skin,values:[{name:'体温',value:34,unit:'°C'}]}),undefined);
  s.provider='Vep';assert.equal(event(settings,s,hrv,completed('hrv')),undefined);
  assert.equal(m.parseReadingSettings({highEnabled:true,high:NaN}).highEnabled,false);
});
const doc=t=>({path:`/api/saydian-app/v2/content/legal/say_ring_${t}?version=fixture&locale=zh-Hans`,version:'fixture',locale:'zh-Hans'});
function caps(){return {realm:'global',product:'say-ring',supportedLocales:['zh-Hans'],registration:{email:true,sms:true,verificationRequired:true},
  login:{email:true,sms:true,explicitRegistrationCodeLogin:true},smsCountries:['CN'],recovery:{email:true,sms:true},
  verification:{codeLength:6,expiresIn:300,retryAfter:60},consentVersion:'fixture',legal:{userAgreement:doc('user_agreement'),privacyPolicy:doc('privacy_policy')}};}
function auth(){const calls=[],vault={async read(){},async write(){},async clear(){}};
  const client=new AccountClient({async request(...args){calls.push(args);return {code:200,data:args[0].includes('/capabilities?')?caps():
    {accessToken:'synthetic-token',refreshToken:'synthetic-refresh',expiresAt:new Date(now+3600000).toISOString(),member:{id:owner,nickname:'合成账号'}}};}},vault,()=>now,true);
  return {calls,client};}
test('password login uses Android V2 channel/identifier contract and rejects invalid input before transport',async()=>{
  for(const [channel,raw,identifier] of [['sms','13800000000','+8613800000000'],['email',' TEST@example.com ','test@example.com']]){
    const f=auth();await f.client.loginRingWithPassword(channel,raw,'synthetic-password','fixture',true,true,'zh-Hans');
    assert.equal(f.calls[1][0],'/global/api/saydian-app/v2/auth/login');
    assert.deepEqual(JSON.parse(f.calls[1][3]),{channel,identifier,password:'synthetic-password',product:'say-ring',locale:'zh-Hans',consentVersion:'fixture',consentAccepted:true});
  }
  for(const password of ['1234567','x'.repeat(73),'密'.repeat(25)]){
    const f=auth();await assert.rejects(f.client.loginRingWithPassword('sms','13800000000',password,'fixture',true,true,'zh-Hans'));
    assert.equal(f.calls.length,0);
  }
  for(const [accepted,age] of [[false,true],[true,false]]){const f=auth();await assert.rejects(f.client.loginRingWithPassword('sms','13800000000','synthetic-password','fixture',accepted,age,'zh-Hans'));assert.equal(f.calls.length,0);}
  assert.match(ringLoginFailure(new Error('password_length'),true),/密码/);
  assert.equal(ringLoginAvailable({...caps(),login:{email:true,sms:true}},'sms'),false);
});
const coordinatorSource=readFileSync(new URL('../entry/src/main/ets/services/PersonalReadingReminders.ets',import.meta.url),'utf8');
const coordinatorBody=stripTypeScriptTypes(coordinatorSource.slice(coordinatorSource.indexOf('interface PendingReading')),{mode:'transform'});
const makeCoordinator=new Function('readingReminderStore','readingReminderSound','emptyWearableSnapshot','emptyMeasurement',
  'defaultReadingSettings','readingSettingsError','evaluatePersonalReading','supportedReadingRules','readingRuleEnabled',
  coordinatorBody.replace(/export /g,'')+';return new PersonalReadingReminders();');
async function coordinator(){const events=[],sounds=[],notices=[];
  const store={attach(){},async read(){return {...m.defaultReadingSettings(),highEnabled:true};},async save(){},async append(owner,event,current){if(current()) events.push({owner,event});}};
  const c=makeCoordinator(store,{stop(){sounds.push('stop')},play(){sounds.push('play')}},contracts.emptyWearableSnapshot,contracts.emptyMeasurement,
    m.defaultReadingSettings,m.readingSettingsError,m.evaluatePersonalReading,m.supportedReadingRules,m.readingRuleEnabled);
  c.listen(n=>notices.push(n));c.configure(owner,{},snapshot());await Promise.resolve();
  return {c,events,sounds,notices};}
test('preview is side effect free until visible, sounds once, and obeys early mute/owner/background cancellation',async()=>{
  const {c,events,sounds,notices}=await coordinator();
  c.preview(true,true);let n=notices.at(-1);assert.equal(n.preview,true);assert.equal(events.length,0);assert.equal(sounds.includes('play'),false);
  c.mute(n.token);c.noticeVisible(n.token);assert.equal(sounds.includes('play'),false);
  c.preview(true,true);n=notices.at(-1);c.noticeVisible(n.token);c.noticeVisible(n.token);assert.equal(sounds.filter(s=>s==='play').length,1);
  c.preview(true,true);n=notices.at(-1);c.setForeground(false);c.noticeVisible(n.token);assert.equal(sounds.filter(s=>s==='play').length,1);
  c.setForeground(true);c.preview(true,true);n=notices.at(-1);c.configure('another-owner',{},snapshot());c.noticeVisible(n.token);
  assert.equal(sounds.filter(s=>s==='play').length,1);assert.equal(events.length,0);
});
test('manual reminders require exact start ACK, persist once, and do not replay imported history',async()=>{
  const {c,events,notices}=await coordinator();const s=snapshot();const token=c.begin('heart');
  const fresh={...record(),timestamp:Date.now()+1};s.records=[fresh];c.updateSnapshot(s);c.measurement(completed());
  await Promise.resolve();assert.equal(events.length,0);
  c.confirmStart(true,token+1);await Promise.resolve();assert.equal(events.length,0);
  c.confirmStart(true,token);await Promise.resolve();await Promise.resolve();assert.equal(events.length,1);assert.equal(notices.at(-1).preview,false);
  c.measurement(completed());c.updateSnapshot(s);await Promise.resolve();assert.equal(events.length,1);
});
