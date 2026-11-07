import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks, stripTypeScriptTypes} from 'node:module';
registerHooks({resolve(s,c,next){return next(s.startsWith('.') && c.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(s)?`${s}.ts`:s,c);}});
const {ringTodayActivity,ringDeviceRecords}=await import('../entry/src/main/ets/model/RingHomePresentation.ts');
const {ringVerificationCode}=await import('../entry/src/main/ets/model/RingParity.ts');
const now=new Date(2026,10,7,12).getTime();
const record=(time,values,extra={})=>({id:`fixture-${time}`,deviceKey:'fixture-ring',metric:'activity',timestamp:time,source:'watch_history',values,samples:[],sampleFrequency:0,...extra});
const value=(name,value,unit)=>({name,value,unit});
test('partial activity updates preserve latest valid value per field without sums or zero filling',()=>{
 const old=record(now-1000,[value('steps',100,'steps'),value('distance',500,'m'),value('calories',30,'kcal')]);
 const recent=record(now,[value('steps',120,'steps'),value('calories',999,'raw')]);
 const input=[old,recent];
 assert.deepEqual(ringTodayActivity(input,'fixture-ring',now),{steps:120,distance:0.5,calories:30});
 assert.equal(input[0],old);
 assert.equal(ringTodayActivity([old,record(now,[value('steps',0,'steps')])],'fixture-ring',now).steps,0);
});
test('activity never borrows yesterday, another device, invalid or future records',()=>{
 const records=[record(now-86400000,[value('calories',30,'kcal')]),record(now,[value('distance',1,'km')],{deviceKey:'other'}),record(now+10000,[value('steps',99,'steps')]),record(NaN,[value('steps',99,'steps')]),record(now,[value('steps',12,'steps')])];
 assert.deepEqual(ringTodayActivity(records,'fixture-ring',now),{steps:12});
 assert.deepEqual(ringTodayActivity(records,'',now),{});
});
test('sleep and metric history remain exact-target, valid-time and newest-first',()=>{
 const r=record(now-1000,[],{metric:'sleep'});
 assert.deepEqual(ringDeviceRecords([r,record(now,[],{metric:'sleep',deviceKey:'other'}),record(now+10000,[],{metric:'sleep'}),record(0,[],{metric:'sleep'}),record(now,[])],'fixture-ring','sleep',now),[r]);
 assert.deepEqual(ringDeviceRecords([r],'','sleep',now),[]);
});
test('all auth code input accepts only one six-digit group',()=>{
 for(const [input,expected] of [['123456123456','123456'],['12a 34-56','123456'],['000000','000000'],['123','123'],['','']]) assert.equal(ringVerificationCode(input),expected);
 const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
 for(const field of ['loginCode','registerCode','resetCode']) assert.ok(source.includes(`this.${field} = ringVerificationCode(value)`));
});
const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
test('home uses dated recent sleep and reminder remains reachable outside home',()=>{
 const home=source.slice(source.indexOf('  HealthHome()'),source.indexOf('  HealthHome()')+15000);
 assert.ok(!home.includes("id('home_reading_reminders')"));
 assert.ok(home.includes('最近一次睡眠'));
 assert.ok(home.includes("localDateKey(this.wearableMetricRecords('sleep')[0].timestamp)"));
 assert.ok(source.includes("id('mine_reading_reminders')"));
});
const body=source.slice(source.indexOf('  private async syncSportRecords()'),source.indexOf('  private sportActive()'));
const run=new Function('vepWearable','saydianApi','sameHealthSession',stripTypeScriptTypes(body.replace('private async syncSportRecords()', 'async function syncSportRecords()'),{mode:'transform'})+';return syncSportRecords;');
test('sport sync ignores late failure after navigation, account or target change',async()=>{
 for(const change of ['screen','target','account','page','none']){
  let finish;const pending=new Promise(r=>finish=r);let account='a',loads=0;
  const ctx={wearableSnapshot:{connected:true,deviceKey:'ring-a'},wearableCapability:()=>true,wearableBusy:()=>false,wearableMeasurement:{running:false},sportActive:()=>false,pageGeneration:1,screen:'sport-records',sportError:'',loadSportRecords:async()=>{loads++;}};
  const fn=run({syncHistory:()=>pending},{healthSession:()=>account},(a,b)=>a===b);
  const operation=fn.call(ctx);
  if(change==='screen')ctx.screen='home';if(change==='target')ctx.wearableSnapshot.deviceKey='ring-b';if(change==='account')account='b';if(change==='page')ctx.pageGeneration++;
  finish(false);await operation;
  assert.equal(loads,change==='none'?1:0);assert.equal(!!ctx.sportError,change==='none');
 }
});
