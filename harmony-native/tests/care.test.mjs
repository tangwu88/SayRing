import test from 'node:test';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
registerHooks({resolve(specifier, context, next) {
  return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ? specifier+'.ts' : specifier, context);
}});
const {AccountClient} = await import('../entry/src/main/ets/services/AccountClient.ts');
const {ApiError} = await import('../entry/src/main/ets/model/Contracts.ts');
const {parseCareMembers,parseCareInvitations,parseCareSettings,careSettingsBody,careMobileValidation,
  chinaDay,chinaDaySeconds,shiftChinaDay,CARE_METRICS,parseCareMetric,careMetricLatest,careRecordText} = await import('../entry/src/main/ets/model/CareContracts.ts');
const day='2026-08-27', now=Date.UTC(2026,8,4,10), metric=key=>CARE_METRICS.find(item=>item.key===key);
const envelope=data=>({code:200,data});
const member={id:59,member_id:1,to_member_id:87,member:{id:87,nickname:'合成家人',mobile:'10000000002',password_hash:'never-keep'}};
const invite=(state=0)=>({id:19,member_id:87,to_member_id:1,examine_status:state,member:{id:87,nickname:'合成邀请人'}});
const auth=id=>envelope({access_token:`synthetic-${id}`,refresh_token:'synthetic-refresh',expiration_time:3600,member:{id,nickname:'合成账号'}});
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function deferred(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return{promise,resolve,reject};}
async function clientWith(request){
  const vault={value:{accessToken:'synthetic-1',refreshToken:'synthetic-refresh',expiresAt:now+3600000,memberId:'1',displayName:'合成账号'},
    async read(){return this.value},async write(value){this.value=value},async clear(){this.value=undefined}};
  const client=new AccountClient({request},vault,()=>now);await client.restore();return{client,vault};
}
test('notification session observer coexists with health ownership and cannot break login/logout',async()=>{
  const {client}=await clientWith(async path=>path.includes('login')?auth(2):envelope([]));
  const health=[],notify=[];client.observeHealthSession(session=>health.push(session));
  const stop=client.observeSession(session=>notify.push(session));
  client.observeSession(()=>{throw new Error('optional callback failed')});
  await client.login('10000000002','123456');
  assert.equal(client.current().memberId,'2');assert.equal(health.at(-1).ownerId,'2');assert.equal(notify.at(-1).ownerId,'2');
  await client.logout();assert.equal(health.at(-1).ownerId,'');assert.equal(notify.at(-1).ownerId,'');
  const length=notify.length;stop();await client.login('10000000002','123456');assert.equal(notify.length,length);
});
test('care relation and observed member IDs remain distinct and sensitive fields are dropped',()=>{
  const result=parseCareMembers([member,member,{...member,id:60,to_member_id:1}], '1');
  assert.deepEqual(result,[{relationId:59,memberId:87,name:'合成家人',mobile:'10000000002'}]);
  assert.equal(JSON.stringify(result).includes('password'),false);
});
test('legacy member aliases work, mismatched nested identity is not displayed',()=>{
  assert.equal(parseCareMembers([{id:3,to_member:{id:4,nickname:'合成别名'}}],'1')[0].name,'合成别名');
  assert.deepEqual(parseCareMembers([{id:3,to_member_id:4,member:{id:5,nickname:'错误账号'}}],'1')[0],{relationId:3,memberId:4,name:'关爱成员',mobile:''});
});
test('malformed care collections are failures rather than fake empty lists',()=>{
  for(const value of [null,{},'bad',123]) assert.throws(()=>parseCareMembers(value,'1'));
  assert.throws(()=>parseCareMembers([{}],'1'));
  assert.throws(()=>parseCareMembers([member,{...member,to_member_id:88}],'1'),/冲突/);
  assert.deepEqual(parseCareMembers({list:[]},'1'),[]);
});
test('incoming invitations exclude outgoing and self; pending badge and actionable list share one state',()=>{
  const list=parseCareInvitations([invite(),invite(),{...invite(1),id:22},{...invite(),id:20,member_id:1,to_member_id:87},{...invite(),id:21,member_id:1}], '1');
  assert.equal(list.length,2);assert.equal(list.filter(item=>item.state==='pending').length,1);
  assert.equal(parseCareInvitations([{...invite(),examine_status:undefined}],'1')[0].state,'other');
  assert.equal(parseCareInvitations([invite(),invite(1)],'1')[0].state,'other');
});
test('recipient nested as inviter is never exposed; matched alternative inviter is used',()=>{
  assert.equal(parseCareInvitations([{...invite(),member:{id:1,nickname:'自己'}}],'1')[0].name,'邀请人 #87');
  assert.equal(parseCareInvitations([{...invite(),member:{id:1},inviter:{id:87,nickname:'正确邀请人'}}],'1')[0].name,'正确邀请人');
});
test('sharing defaults off and preserves unknown historical options',()=>{
  assert.deepEqual(parseCareSettings({}),{enabled:[],unknown:[]});
  const result=parseCareSettings({setting:'["heartReat","future_metric","heartReat"]'});
  assert.deepEqual(result,{enabled:['heartReat'],unknown:['future_metric']});
  assert.deepEqual(JSON.parse(careSettingsBody(87,{enabled:[],unknown:result.unknown})),{type:0,to_member_id:87,setting:['future_metric']});
});
test('invalid sharing values and newly invented permissions cannot be saved',()=>{
  for(const setting of ['broken',{},[1],['bad-key'],['']])assert.throws(()=>parseCareSettings({setting}));
  assert.throws(()=>careSettingsBody(87,{enabled:['invented'],unknown:[]}));
  assert.throws(()=>careSettingsBody(0,{enabled:[],unknown:[]}));
});
test('invite mobile validation prevents self invitations and invalid requests',()=>{
  assert.match(careMobileValidation('123',''),/手机号/);
  assert.match(careMobileValidation('10000000001','10000000001'),/当前/);
  assert.equal(careMobileValidation(' 10000000002 ','10000000001'),'');
});
test('China day boundaries and invalid dates are host-timezone independent',()=>{
  assert.equal(chinaDaySeconds(day),1787760000);assert.equal(chinaDay(Date.UTC(2026,7,26,16)),day);
  assert.equal(shiftChinaDay('2026-03-01',-1),'2026-02-28');
  for(const value of ['2026-02-29','2026-13-01','2026-08-32','2026-8-1'])assert.throws(()=>chinaDaySeconds(value));
});
test('legacy JSON health fields produce accurate isolated metric values',()=>{
  const rows=[{time:'20:00',pulseReat:'[75]',bloodPressure:'{"bloodPressureHigh":128,"bloodPressureLow":82}',bloodGlucose:7.2,
    bloodOxygen:'{"oxygens":[98,0,0]}',bodyTemperature:'{"bodyTemperature":36.8}',HRVData:'[57]',sleepData:'{"allSleepTime":420}'}];
  for(const [key,values] of [['heart',[75]],['pressure',[128,82]],['glucose',[7.2]],['oxygen',[98]],['temperature',[36.8]],['hrv',[57]],['sleep',[420]]]){
    assert.deepEqual(parseCareMetric(metric(key),rows,day,false).records[0].fields.map(item=>item.value),values,key);
  }
});
test('shared raw rows never reinterpret generic value or another metric as selected reading',()=>{
  for(const key of ['heart','glucose','oxygen','temperature','hrv','sleep'])assert.equal(parseCareMetric(metric(key),[{time:'08:00',value:88,step:900}],day,false).state,'empty');
  assert.equal(parseCareMetric(metric('heart'),[{time:'08:00',bloodGlucose:6.1}],day).state,'empty');
});
test('chart series sorted by time; pressure requires two named values and no positional guessing',()=>{
  const result=parseCareMetric(metric('pressure'),{categories:['21:30','07:30'],series:[{name:'舒张压',data:[82,76]},{name:'收缩压',data:[128,118]}]},day);
  assert.deepEqual(result.records[0].fields.map(item=>item.value),[128,82]);
  assert.equal(parseCareMetric(metric('pressure'),[{time:'10:00',systolic:120}],day).state,'empty');
  assert.equal(parseCareMetric(metric('pressure'),{categories:['10:00'],series:[{name:'未知',data:[120]},{name:'未知2',data:[80]}]},day).state,'empty');
});
test('typed chart values retain nested oxygen and temperature structures',()=>{
  for(const [key,value,expected] of [['oxygen',{oxygens:[98,0,0]},98],['temperature','{"bodyTemperature":36.8}',36.8],['heart',[75],75]]){
    const result=parseCareMetric(metric(key),{categories:['08:00'],series:[{name:metric(key).title,data:[value]}]},day);
    assert.equal(result.records[0].fields[0].value,expected);
  }
});
test('empty/invalid/sentinel values do not become records; duplicate same-time samples are deduplicated',()=>{
  assert.equal(parseCareMetric(metric('heart'),[{pulseReat:0},{pulseReat:NaN},{pulseReat:2147483647},{id:99,status:1}],day).state,'empty');
  assert.equal(parseCareMetric(metric('heart'),[{time:'08:00',pulseReat:75},{time:'08:00',pulseReat:75}],day).records.length,1);
  assert.equal(parseCareMetric(metric('heart'),[{date:'2026-08-26 23:59:59',pulseReat:75}],day).state,'empty');
});
test('different readings sharing a server ID cannot collide in native list keys',()=>{
  const result=parseCareMetric(metric('heart'),[{id:1,time:'08:00',pulseReat:75},{id:1,time:'08:00',pulseReat:76}],day);
  assert.equal(result.records.length,2);assert.notEqual(result.records[0].id,result.records[1].id);
});
test('ECG preserves true fields and samples without treating arbitrary positive metadata as health data',()=>{
  const result=parseCareMetric(metric('ecg'),[{date:`${day} 09:30:00`,data:'{"aveHeart":79,"aveHrv":52,"aveQT":372,"frequency":250}',totalArray:'[0,0.12,-0.08]'}],day);
  assert.deepEqual(result.records[0].fields.map(item=>item.value),[79,52,372]);
  assert.deepEqual(result.records[0].samples,[0,0.12,-0.08]);assert.equal(result.records[0].frequency,250);
  assert.equal(parseCareMetric(metric('ecg'),[{status:1,rawVersion:2}],day).state,'empty');
  assert.equal(parseCareMetric(metric('ecg'),[{totalArray:[0,'',1]}],day).state,'empty');
});
test('compound metric fields stay named with correct units; no generic average is invented',()=>{
  const result=parseCareMetric(metric('body'),[{data:'{"BMI":23.2,"bodyFatRate":18.1,"fatRate":10.5,"password_hash":"bad"}'}],day);
  assert.equal(result.records[0].fields.length,3);assert.match(careRecordText(result.records[0]),/脂肪量 10.5 kg/);
  assert.match(careMetricLatest(result),/^记录：/);assert.equal(JSON.stringify(result).includes('password'),false);
  const blood=parseCareMetric(metric('blood'),[{data:{uricAcidVal:320,cholesterol:4.2}}],day);
  assert.equal(blood.records[0].fields[0].unit,'μmol/L');assert.equal(blood.records[0].fields[1].unit,'mmol/L');
});
test('care request identity uses selected member rather than relation ID and preserves authorization',async()=>{
  const paths=[];const {client}=await clientWith(async(path,fields,session,json)=>{paths.push(path);assert.equal(session.memberId,'1');assert.equal(json,undefined);return envelope(path.endsWith('/my')?[member]:[])});
  await client.careMembers();await client.careMetric(59,87,'heart',day);
  assert.ok(paths[1].includes('selectmember=87'));assert.ok(paths[1].includes('date=1787760000'));assert.ok(paths[1].includes('type=pulseReat'));
  await assert.rejects(client.careMetric(59,59,'heart',day),/成员关系/);
});
test('late empty care response cannot clear a newer relation used to read member data',async()=>{
  const requests=[];
  const {client}=await clientWith(async path=>{
    if(!path.endsWith('/my'))return envelope([]);
    const pending=deferred();requests.push(pending);return pending.promise;
  });
  const old=client.careMembers();const ignored=assert.rejects(old,/已刷新/);await tick();
  const latest=client.careMembers();await tick();
  requests[1].resolve(envelope([member]));assert.equal((await latest).length,1);
  requests[0].resolve(envelope([]));await ignored;
  assert.equal((await client.careMetric(59,87,'heart',day)).state,'empty');
});
test('late populated care response cannot restore a relation removed by latest empty data',async()=>{
  const requests=[];
  const {client}=await clientWith(async()=>{const pending=deferred();requests.push(pending);return pending.promise});
  const old=client.careMembers();const ignored=assert.rejects(old,/已刷新/);await tick();
  const latest=client.careMembers();await tick();
  requests[1].resolve(envelope([]));assert.deepEqual(await latest,[]);
  requests[0].resolve(envelope([member]));await ignored;
  await assert.rejects(client.careMetric(59,87,'heart',day),/成员关系/);
});
test('clearing care invalidates in-flight mapping reads even without changing the login generation',async()=>{
  const pending=deferred();const {client}=await clientWith(async()=>pending.promise);
  const reading=client.careMembers();const ignored=assert.rejects(reading,/已刷新/);await tick();
  client.clearCare();
  pending.resolve(envelope([member]));await ignored;
  await assert.rejects(client.careMetric(59,87,'heart',day),/成员关系/);
});
test('account switch rejects old care mapping while new account relations remain readable',async()=>{
  const pending=deferred();let reads=0;
  const {client}=await clientWith(async path=>{
    if(path.endsWith('/login'))return auth(2);
    if(path.endsWith('/my'))return ++reads===1?pending.promise:envelope([member]);
    return envelope([]);
  });
  const old=client.careMembers();const ignored=assert.rejects(old,/旧账号/);await tick();
  await client.login('10000000002','synthetic-password');
  await client.careMembers();
  pending.resolve(envelope([]));await ignored;
  assert.equal(client.current().memberId,'2');
  assert.equal((await client.careMetric(59,87,'heart',day)).state,'empty');
});
test('403 never falls back to an endpoint that could bypass sharing restrictions',async()=>{
  let reads=0;const {client}=await clientWith(async path=>{if(path.endsWith('/my'))return envelope([member]);reads++;throw new ApiError('no permission',403)});
  await client.careMembers();assert.equal((await client.careMetric(59,87,'heart',day)).state,'unauthorized');assert.equal(reads,1);
});
test('typed endpoint failure can use whitelisted same-member raw fallback',async()=>{
  const {client}=await clientWith(async path=>{if(path.endsWith('/my'))return envelope([member]);if(path.includes('type='))throw new ApiError('missing',500);return envelope([{time:'08:00',pulseReat:'[68]'}])});
  await client.careMembers();assert.equal((await client.careMetric(59,87,'heart',day)).records[0].fields[0].value,68);
});
test('care overview reads the shared day once, exposes every metric state and never bypasses a 403',async()=>{
  let rawReads=0;
  const {client}=await clientWith(async path=>{
    if(path.endsWith('/my'))return envelope([member]);
    if(path.includes('/daily-date/preview')&&!path.includes('type=')){
      rawReads++;
      return envelope([{time:'08:00',pulseReat:68,bloodGlucose:6.2,bloodOxygen:99}]);
    }
    if(path.includes('type=pulseReat'))throw new ApiError('typed unavailable',500);
    if(path.includes('type=BloodGlucose'))return envelope([]);
    if(path.includes('/daily-date/preview'))throw new ApiError('not shared',403);
    return envelope([]);
  });
  await client.careMembers();
  const metrics=await client.careMetrics(59,87,day);
  assert.equal(metrics.length,CARE_METRICS.length);
  assert.equal(metrics.find(item=>item.key==='heart').records[0].fields[0].value,68);
  assert.equal(metrics.find(item=>item.key==='glucose').records[0].fields[0].value,6.2);
  assert.equal(metrics.find(item=>item.key==='oxygen').state,'unauthorized');
  assert.equal(metrics.find(item=>item.key==='ecg').state,'empty');
  assert.equal(rawReads,1);
});
test('invitation response is explicit JSON and a handled invitation cannot be repeated',async()=>{
  let writes=0,status=0;const {client}=await clientWith(async(path,fields,session,json)=>{
    if(path.endsWith('/save')){writes++;assert.deepEqual(JSON.parse(json),{id:19,examine_status:2});status=2;return envelope({})}return envelope([invite(status)]);
  });await client.respondCareInvitation(19,false);await assert.rejects(client.respondCareInvitation(19,true),/已处理/);assert.equal(writes,1);
});
test('invite submission tolerates a malformed optional profile phone without a UI type error',async()=>{
  let sent=false;const {client}=await clientWith(async(path,fields,session,json)=>{
    if(path.endsWith('/my'))return envelope({id:1,mobile:{invalid:true}});
    assert.equal(path,'/api/v1/member/care');assert.deepEqual(JSON.parse(json),{mobile:'10000000002'});sent=true;return envelope({});
  });await client.addCare('10000000002');assert.equal(sent,true);
});
test('sharing cannot save before a successful read, and unknown settings survive roundtrip',async()=>{
  let posted;const {client}=await clientWith(async(path,fields,session,json)=>{
    if(path.endsWith('/care'))return envelope([invite(1)]);
    if(json){posted=JSON.parse(json);return envelope({})}return envelope({setting:['heartReat','future_metric']});
  });await assert.rejects(client.saveCareShareSettings(87,[]),/成功读取/);
  await client.careShareSettings(87);await client.saveCareShareSettings(87,['bloodPressure']);
  assert.deepEqual(posted,{type:0,to_member_id:87,setting:['bloodPressure','future_metric']});
  await assert.rejects(client.saveCareShareSettings(87,[]),/成功读取/);
});
test('unaccepted invitation cannot grant share editing',async()=>{
  const {client}=await clientWith(async()=>envelope([invite(0)]));await assert.rejects(client.careShareSettings(87),/先同意/);
});
test('sharing changes on another device prevent stale overwrites',async()=>{
  let state=['heartReat'],writes=0;const {client}=await clientWith(async(path,fields,session,json)=>{
    if(path.endsWith('/care'))return envelope([invite(1)]);
    if(json){writes++;return envelope({})}return envelope({setting:state});
  });await client.careShareSettings(87);state=['heartReat','bloodPressure'];
  await assert.rejects(client.saveCareShareSettings(87,[]),/其他设备更新/);assert.equal(writes,0);
});
test('old care response and relation cache cannot cross account switches',async()=>{
  const wait=deferred();const {client}=await clientWith(async path=>path.endsWith('/login')?auth(2):wait.promise);
  const old=client.careMembers();await tick();await client.login('synthetic-account','synthetic-password');wait.resolve(envelope([member]));
  await assert.rejects(old,/旧账号/);await assert.rejects(client.careMetric(59,87,'heart',day),/成员关系/);
});
test('care 404/405/503 preserves logged-in state while final 401 invalidates it',async()=>{
  for(const status of [404,405,503]){const {client,vault}=await clientWith(async()=>{throw new ApiError('fixture unavailable',status)});await assert.rejects(client.careMembers());assert.ok(vault.value)}
  const {client,vault}=await clientWith(async()=>{throw new ApiError('expired',401)});await assert.rejects(client.careMembers());assert.equal(vault.value,undefined);
});
