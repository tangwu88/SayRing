import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';
registerHooks({resolve(specifier,context,next){
  return next(specifier.startsWith('.')&&context.parentURL?.endsWith('.ts')&&!/\.[a-z]+$/.test(specifier)?`${specifier}.ts`:specifier,context);
}});
const {sameHealthSession}=await import('../entry/src/main/ets/model/HealthUpload.ts');
const {profileDraftError}=await import('../entry/src/main/ets/model/DisplayPreferences.ts');
const {ApiError,profileName}=await import('../entry/src/main/ets/model/Contracts.ts');
const {refreshSummaryOnSettingsReturn}=await import('../entry/src/main/ets/model/DeviceSettingsTransactions.ts');
const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
function method(name){
  const match=new RegExp(`  private (?:async )?${name}\\(`).exec(source);
  assert.ok(match,`production ${name} method exists`);
  const end=source.indexOf('\n  }',match.index+1);
  return source.slice(match.index,end+4);
}
const deferred=()=>{let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no;});return {promise,resolve,reject};};
const sport={id:'sport-1',deviceKey:'watchA',metric:'sport',timestamp:1,source:'watch_history',values:[{name:'时长',value:10,unit:'分钟'}],samples:[]};
function fixture(){
  const session={ownerId:'ownerA',generation:1};
  const api={healthSession:()=>({...session}),async saveProfile(draft){return {...draft,id:'ownerA'};}};
  const service={reads:0,syncs:0,async savedSportRecords(){this.reads++;return [sport];},async syncHistory(){this.syncs++;return true;}};
  const Page=new Function('saydianApi','vepWearable','sameHealthSession','profileDraftError','profileName','ApiError','refreshSummaryOnSettingsReturn',
    `return ${stripTypeScriptTypes(`class Page {${['clearSportRecords','openSportRecords','loadSportRecords',
      'syncSportRecords','openRecord','openInnerPage','saveProfileDraft','back'].map(method).join('\n')}}`)}`)
    (api,service,sameHealthSession,profileDraftError,profileName,ApiError,refreshSummaryOnSettingsReturn);
  const page=new Page();
  Object.assign(page,{screen:'home',guest:false,sportGeneration:0,pageGeneration:1,contentGeneration:1,
    localSportRecords:[],sportLoading:false,sportError:'',wearableSnapshot:{connected:false},
    wearableCapability:()=>true,wearableBusy:()=>false,sportActive:()=>false,wearableMeasurement:{running:false},
    innerParents:new Map(),formBusy:false,formMessage:'',editNickname:'合成名字',editGender:0,editBirthday:'1990-01-01',
    editHeight:'172',editWeight:'65',editAvatarUri:'',profile:{id:'ownerA',nickname:'旧名字'},
    accountFormFailure(error){if(error.status===401){this.formBusy=false;this.screen='login';}return error.message;}});
  return {page,service,api,session};
}
const settle=async()=>{for(let i=0;i<6;i++)await Promise.resolve();};
test('production sport entry loads saved history offline and record detail returns to the same list',async()=>{
  const {page,service}=fixture();
  page.openSportRecords();await settle();
  assert.equal(page.screen,'sport-records');assert.deepEqual(page.localSportRecords,[sport]);assert.equal(service.syncs,0);
  page.openRecord(sport);assert.equal(page.screen,'health-record');assert.equal(page.selectedHealthRecord,sport);
  page.back();assert.equal(page.screen,'sport-records');assert.deepEqual(page.localSportRecords,[sport]);
});
test('production sport sync requires connected supported idle device, but local refresh does not',async()=>{
  const {page,service}=fixture();
  await page.syncSportRecords();assert.equal(service.syncs,0);
  page.wearableSnapshot.connected=true;page.wearableCapability=()=>false;
  await page.syncSportRecords();assert.equal(service.syncs,0);
  page.wearableCapability=()=>true;page.wearableMeasurement.running=true;
  await page.syncSportRecords();assert.equal(service.syncs,0);
  page.wearableMeasurement.running=false;
  await page.syncSportRecords();assert.equal(service.syncs,1);assert.deepEqual(page.localSportRecords,[sport]);
  page.wearableSnapshot.connected=false;await page.loadSportRecords();assert.equal(service.reads,2);
});
test('failed database refresh keeps already displayed rows and distinguishes failure from no records',async()=>{
  const {page,service}=fixture();page.localSportRecords=[sport];
  service.savedSportRecords=async()=>{throw new Error('unavailable');};
  await page.loadSportRecords();assert.deepEqual(page.localSportRecords,[sport]);assert.match(page.sportError,/读取失败/);
  assert.equal(page.sportLoading,false);
});
test('old account sport read cannot repopulate records after clearing or overwrite the next request',async()=>{
  const {page,service,session}=fixture();const first=deferred();
  service.savedSportRecords=()=>first.promise;
  const reading=page.loadSportRecords();session.ownerId='ownerB';session.generation++;
  page.clearSportRecords();service.savedSportRecords=async()=>[];
  await page.loadSportRecords();first.resolve([sport]);await reading;
  assert.deepEqual(page.localSportRecords,[]);assert.equal(page.sportLoading,false);
});
test('signed-out sport entry does not request private history',async()=>{
  const {page,service}=fixture();page.guest=true;page.localSportRecords=[sport];
  await page.loadSportRecords();assert.deepEqual(page.localSportRecords,[]);assert.equal(service.reads,0);
});
test('profile page preserves submitted edits and never announces success after readback mismatch',async()=>{
  const {page,api}=fixture();api.saveProfile=async()=>{throw new ApiError('个人资料未全部保存，请核对身高后重试');};
  await page.saveProfileDraft();assert.match(page.formMessage,/未全部保存/);assert.equal(page.profile.nickname,'旧名字');
  assert.equal(page.editHeight,'172');assert.equal(page.formBusy,false);
});
test('profile upload from old account does not trigger a save under the new account',async()=>{
  const {page,api,session}=fixture();const upload=deferred();let saves=0;
  page.editAvatarUri='synthetic-avatar';api.uploadProfileImage=()=>upload.promise;api.saveProfile=async()=>{saves++;};
  const saving=page.saveProfileDraft();session.ownerId='ownerB';session.generation++;
  page.contentGeneration++;page.formMessage='新账号';page.formBusy=false;
  upload.resolve('/attachment/avatar.png');await saving;
  assert.equal(saves,0);assert.equal(page.formMessage,'新账号');assert.equal(page.formBusy,false);
});
test('profile save late response never updates a new account or releases its form lock',async()=>{
  const {page,api,session}=fixture();const save=deferred();api.saveProfile=()=>save.promise;
  const saving=page.saveProfileDraft();session.ownerId='ownerB';session.generation++;
  page.contentGeneration++;page.profile={id:'ownerB',nickname:'新账号'};page.formMessage='新表单';page.formBusy=true;
  save.resolve({id:'ownerA',nickname:'旧保存'});await saving;
  assert.equal(page.profile.id,'ownerB');assert.equal(page.formMessage,'新表单');assert.equal(page.formBusy,true);
});
test('profile session expiry exits the stale form rather than leaving a permanent busy lock',async()=>{
  const {page,api,session}=fixture();api.saveProfile=async()=>{session.ownerId='';session.generation++;throw new ApiError('expired',401);};
  await page.saveProfileDraft();assert.equal(page.formBusy,false);assert.equal(page.screen,'login');assert.match(page.formMessage,/登录已失效/);
});
test('sport builder keeps saved rows and exposes only the real service-backed live controls',()=>{
  const builder=source.slice(source.indexOf('  SportRecordContent()'),source.indexOf('  HealthAlertContent()'));
  assert.match(builder,/ForEach\(this\.localSportRecords/);
  assert.match(builder,/\.onClick\(\(\) => this\.openRecord\(record\)\)/);
  assert.match(builder,/startSport\(this\.selectedSportMode\)|toggleSportPause\(\)|confirmStopSport\(\)/);
  assert.match(builder,/sportRoutePolyline\(this\.sportSession\.route/);
  assert.doesNotMatch(builder,/wearableMetricRecords\('sport'\)|模拟运动|测试轨迹/);
  const disconnectedBranch=builder.slice(builder.indexOf('if (!this.wearableSnapshot.connected)'),builder.indexOf('} else if'));
  assert.doesNotMatch(disconnectedBranch,/ForEach|return|margin\(\{ top: 160/);
});
