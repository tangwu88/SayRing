import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';

const storage=new Map(), persisted=new Map(), published=[], canceled=[], wants=[];
let permitted=true, invitations=[], session={ownerId:'1',generation:1}, observer;
const sdk={
  preferences:{async getPreferences(){return{async get(key,fallback){return persisted.get(key)??fallback},async put(key,value){persisted.set(key,value)},async flush(){}}}},
  notificationManager:{SlotType:{SERVICE_INFORMATION:2},ContentType:{NOTIFICATION_CONTENT_BASIC_TEXT:0},
    async isNotificationEnabled(){return permitted},async publish(request){published.push(request)},async cancel(id,label){canceled.push({id,label})}},
  wantAgent:{OperationType:{START_ABILITY:1},WantAgentFlags:{UPDATE_PRESENT_FLAG:3},async getWantAgent(info){wants.push(info);return {fixture:true}}},
  saydianApi:{async careInvitations(){return invitations},observeSession(listener){observer=listener;listener(session);return()=>{observer=undefined}}}
};
globalThis.__careNotificationSdk=sdk;
globalThis.AppStorage={has:key=>storage.has(key),get:key=>storage.get(key),setOrCreate:(key,value)=>storage.set(key,value)};
registerHooks({
  resolve(specifier,context,next){
    if(specifier.startsWith('@kit.') || specifier==='./SaydianApi')return{url:'fixture:'+specifier,shortCircuit:true};
    if(specifier.startsWith('.')&&/\.(ets|ts)$/.test(context.parentURL??'')&&!/\.[a-z]+$/.test(specifier)){
      const base=new URL(specifier,context.parentURL);return next(base.href+(existsSync(new URL(base.href+'.ets'))?'.ets':'.ts'),context);
    }return next(specifier,context);
  },
  load(url,context,next){
    if(url.startsWith('fixture:'))return{format:'module',source:
      'export const common={};export const {preferences,notificationManager,wantAgent,saydianApi}=globalThis.__careNotificationSdk;',shortCircuit:true};
    if(url.endsWith('.ets'))return{format:'module',source:stripTypeScriptTypes(readFileSync(new URL(url),'utf8')),shortCircuit:true};
    return next(url,context);
  }
});
const {CareNotificationService}=await import('../entry/src/main/ets/services/CareNotificationService.ets');
const {captureNotificationEvent,clearNotificationSession,CARE_ARRIVAL_REVISION,setNotificationOwner}=await import('../entry/src/main/ets/services/NotificationNavigation.ets');
const context={abilityInfo:{bundleName:'fixture.saydian',name:'EntryAbility'}};
const tick=async()=>{for(let i=0;i<6;i++)await new Promise(resolve=>setImmediate(resolve))};
function reset(){storage.clear();persisted.clear();published.length=0;canceled.length=0;wants.length=0;permitted=true;invitations=[];session={ownerId:'1',generation:1};clearNotificationSession();setNotificationOwner('');}
const invite=id=>({id,inviterId:2,state:'pending',name:'not-in-notification',mobile:'10000000000'});

test('actual native adapter publishes generic text, allowed route and stable cross-channel key; logout cancels owned notices',async()=>{
  reset();invitations=[invite(21)];const service=new CareNotificationService();
  try{service.attachContext(context);service.setForeground(true);await tick();
    assert.equal(published.length,1);const payload=published[0];
    assert.equal(payload.label,'saydian.care.1.21');assert.equal(payload.appMessageId,payload.label);assert.equal(payload.isAlertOnce,true);
    assert.doesNotMatch(JSON.stringify(payload),/not-in-notification|10000000000|heart|blood/);
    assert.equal(wants[0].wants[0].parameters.route,'care-invitations');assert.equal(wants[0].wants[0].parameters.local_notice_owner,'1');
    assert.equal(service.currentInbox()[0].read,false);assert.equal(storage.get(CARE_ARRIVAL_REVISION),1);
    observer({ownerId:'',generation:2});await tick();assert.equal(service.currentInbox().length,0);
    assert.ok(canceled.some(row=>row.label==='saydian.care.1.21'));
  }finally{service.shutdown()}
});

test('denied notification permission leaves account-local unread; marking read persists without server fake save',async()=>{
  reset();permitted=false;invitations=[invite(22)];const service=new CareNotificationService();
  try{service.attachContext(context);service.setForeground(true);await tick();assert.equal(published.length,0);
    assert.equal(service.currentInbox()[0].read,false);await service.markRead(22);assert.equal(service.currentInbox()[0].read,true);
    assert.equal(JSON.parse(persisted.get('owner_1')).entries[0].read,true);
  }finally{service.shutdown()}
});

test('remote SDK event before account restoration verifies current API and avoids publishing a second local notification',async()=>{
  reset();session={ownerId:'',generation:0};const service=new CareNotificationService();
  try{service.attachContext(context);service.setForeground(true);
    captureNotificationEvent({event_id:'remote-before-restore',event_type:'care_invitation',entity_id:'23',route:'care-invitations'},false);
    invitations=[invite(23)];observer({ownerId:'1',generation:0});await tick();
    assert.equal(service.currentInbox().length,1);assert.equal(published.length,0);
  }finally{service.shutdown()}
});

test('remote after local removes old local tray item and does not duplicate inbox or toast',async()=>{
  reset();invitations=[invite(24)];const service=new CareNotificationService();
  try{service.attachContext(context);service.setForeground(true);await tick();
    captureNotificationEvent({event_id:'remote-later',event_type:'care_invitation_created',entity_id:'24',route:'care-invitations'},false);await tick();
    assert.equal(published.length,1);assert.equal(service.currentInbox().length,1);assert.equal(storage.get(CARE_ARRIVAL_REVISION),1);
    assert.ok(canceled.some(row=>row.label==='saydian.care.1.24'));
  }finally{service.shutdown()}
});

test('logout starts by pausing old-account polling even while push unregister waits; token refresh cannot resume it',async()=>{
  reset();const service=new CareNotificationService();
  try{service.attachContext(context);service.setForeground(true);await tick();
    service.beginSignOut();invitations=[invite(25)];service.refresh();observer({ownerId:'1',generation:1});
    service.setForeground(false);service.setForeground(true);await tick();
    assert.equal(service.isForeground(),false);assert.equal(published.length,0);assert.equal(service.currentInbox().length,0);
    observer({ownerId:'',generation:2});observer({ownerId:'2',generation:3});await tick();
    assert.equal(service.isForeground(),true);assert.equal(published.length,1);assert.equal(published[0].label,'saydian.care.2.25');
  }finally{service.shutdown()}
});
