import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier, context, next) {
  if (specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier)) return next(specifier + '.ts', context);
  return next(specifier, context);
} });
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const { ApiError, parseArticles, parseArticle, validateStoredSession } = await import('../entry/src/main/ets/model/Contracts.ts');
const now = Date.UTC(2026,8,4,10);
const session = (id='fixture-a', token='synthetic-old', life=3600000) => ({accessToken:token,
  refreshToken:'synthetic-refresh',expiresAt:now+life,memberId:id,displayName:'虚构测试账号'});
const auth = (id='fixture-a', token='synthetic-new') => ({code:200,data:{access_token:token,
  refresh_token:'synthetic-refresh-next',expiration_time:3600,member:{id,nickname:'虚构测试账号'}}});
const deferred = () => {let resolve,reject; const promise=new Promise((a,b)=>{resolve=a;reject=b;}); return {promise,resolve,reject};};
const tick = () => new Promise(resolve=>setImmediate(resolve));
class MemoryStore {
  constructor(value){this.value=value;this.writes=0;this.clears=0;}
  async read(){return this.value;}
  async write(value){this.value=structuredClone(value);this.writes++;}
  async clear(){this.value=undefined;this.clears++;}
}
function make(value,request){const store=new MemoryStore(value);return {store,client:new AccountClient({request},store,()=>now)};}
test('valid stored session restores without network',async()=>{
  const {client}=make(session(),async()=>{throw Error('unexpected');}); assert.equal((await client.restore()).memberId,'fixture-a');
});
test('current returns a defensive credential copy',async()=>{
  const {client}=make(session(),async()=>auth()); await client.restore();client.current().memberId='fixture-b';assert.equal(client.current().memberId,'fixture-a');
});
test('login uses existing contract and stores no password',async()=>{
  const {client,store}=make(undefined,async(path,fields)=>{
    assert.equal(path,'/api/v1/site/login');assert.deepEqual(fields,[{name:'username',value:'fixture'},{name:'password',value:' synthetic '},{name:'group',value:'app'}]);return auth();
  });await client.login(' fixture ',' synthetic ');assert.equal(store.writes,1);assert.equal('password' in store.value,false);
});
test('SMS registration uses the confirmed contract and stores only the resulting session',async()=>{
  const calls=[];const {client,store}=make(undefined,async(path,fields)=>{calls.push({path,fields});return path.endsWith('/sms-code')?{code:200,data:{}}:auth();});
  await client.sendSmsCode(' 13800138000 ');
  await client.registerWithSms(' 13800138000 ',' 123456 ','register-password','register-password',true);
  assert.deepEqual(calls[0],{path:'/api/v1/site/sms-code',fields:[{name:'mobile',value:'13800138000'},{name:'usage',value:'register'}]});
  assert.equal(calls[1].path,'/api/v1/site/register');
  assert.deepEqual(Object.fromEntries(calls[1].fields.map(item=>[item.name,item.value])),{
    mobile:'13800138000',code:'123456',password:'register-password',password_repetition:'register-password',
    nickname:'赛电用户8000',group:'app'
  });
  assert.equal(store.writes,1);assert.equal('password' in store.value,false);
});
test('WeChat login exchanges only the one-time callback data and never a client secret',async()=>{
  const state='sd_1788569000000_01234567-89ab-cdef-0123456789ab';let call;
  const {client,store}=make(undefined,async(path,fields)=>{call={path,fields};return auth();});
  await client.loginWithWechat(' temporary-code ',state);
  assert.equal(call.path,'/api/v1/site/wechat-login');
  assert.deepEqual(call.fields,[{name:'code',value:'temporary-code'},{name:'state',value:state},
    {name:'group',value:'app'},{name:'platform',value:'harmony'},
    {name:'consent_version',value:'harmony-native-legal-v1'},{name:'consent_accepted',value:'1'}]);
  assert.equal(call.fields.some(item=>/secret/i.test(item.name)),false);
  assert.equal(store.writes,1);
});
test('failed WeChat account switch cannot restore the previous account',async()=>{
  const state='sd_1788569000000_01234567-89ab-cdef-0123456789ab';
  const {client,store}=make(session(),async()=>{throw new ApiError('fixture unavailable',404);});await client.restore();
  await assert.rejects(client.loginWithWechat('temporary-code',state));
  assert.equal(client.current(),undefined);assert.equal(store.value,undefined);
});
test('failed account switch cannot restore previous account',async()=>{
  const {client,store}=make(session(),async()=>{throw new ApiError('fixture failure',422);});await client.restore();
  await assert.rejects(client.login('fixture-b','synthetic'));assert.equal(client.current(),undefined);assert.equal(store.value,undefined);assert.equal(await client.restore(),undefined);
});
test('logout clears session and vault',async()=>{
  const {client,store}=make(session(),async()=>auth());await client.restore();await client.logout();assert.equal(client.current(),undefined);assert.equal(store.value,undefined);assert.equal(await client.restore(),undefined);
});
test('restore in progress cannot resurrect logged out account',async()=>{
  const wait=deferred(),store=new MemoryStore(session());store.read=()=>wait.promise;
  const client=new AccountClient({request:async()=>auth()},store,()=>now);const restoring=client.restore();await tick();const logout=client.logout();
  wait.resolve(session());await Promise.all([restoring,logout]);assert.equal(client.current(),undefined);assert.equal(store.value,undefined);
});
test('failed vault clear is reported, never silently successful',async()=>{
  const {client,store}=make(session(),async()=>auth());await client.restore();store.clear=async()=>{throw new ApiError('fixture storage failure');};
  await assert.rejects(client.logout(),/storage/);assert.equal(client.current(),undefined);assert.equal(await client.restore(),undefined);
});
test('no refresh token is required before actual access expiry',async()=>{
  const stored=session('fixture-a','synthetic-old',120000);stored.refreshToken='';
  const {client}=make(stored,async()=>{throw Error('unexpected');});assert.ok(await client.restore());
});
test('transient refresh failure preserves still valid token',async()=>{
  const {client}=make(session('fixture-a','synthetic-old',120000),async()=>{throw new ApiError('offline');});assert.equal((await client.restore()).accessToken,'synthetic-old');
});
test('all concurrent callers can retain a still valid token after transient refresh failure',async()=>{
  let clock=now;const gate=deferred();let refreshes=0;
  const store=new MemoryStore(session());
  const client=new AccountClient({request:async(path)=>{
    if(path.endsWith('/refresh')){refreshes++;await gate.promise;throw new ApiError('offline');}
    return {data:{id:'fixture-a'}};
  }},store,()=>clock);
  await client.restore();clock+=3500000;
  const results=Promise.allSettled([client.profile(),client.profile()]);
  await tick();gate.resolve();
  assert.deepEqual((await results).map(item=>item.status),['fulfilled','fulfilled']);
  assert.equal(refreshes,1);
});
test('expired token is not restored as valid while offline',async()=>{
  const {client}=make(session('fixture-a','synthetic-old',-1000),async()=>{throw new ApiError('offline');});await assert.rejects(client.restore(),/offline/);
});
test('definitive refresh rejection clears persistent credentials',async()=>{
  const {client,store}=make(session('fixture-a','synthetic-old',-1000),async()=>{throw new ApiError('expired',401);});await assert.rejects(client.restore());assert.equal(client.current(),undefined);assert.equal(store.value,undefined);
});
test('concurrent 401s share one refresh',async()=>{
  const gate=deferred();let refreshes=0;const {client}=make(session(),async(path,fields,s)=>{
    if(path.endsWith('/refresh')){refreshes++;await gate.promise;return auth();}
    if(s.accessToken==='synthetic-old')throw new ApiError('expired',401);return {data:{id:'fixture-a'}};
  });await client.restore();const a=client.profile(),b=client.profile();await tick();gate.resolve();await Promise.all([a,b]);assert.equal(refreshes,1);
});
test('late 401 from old token reuses already refreshed token',async()=>{
  const late=deferred();let oldRequests=0,refreshes=0;const {client}=make(session(),async(path,fields,s)=>{
    if(path.endsWith('/refresh')){refreshes++;return auth();}
    if(s.accessToken==='synthetic-old'){oldRequests++;if(oldRequests===2)await late.promise;throw new ApiError('expired',401);}return {data:{id:'fixture-a'}};
  });await client.restore();const a=client.profile(),b=client.profile();await a;late.resolve();await b;assert.equal(refreshes,1);
});
test('old profile cannot appear after switching account',async()=>{
  const pending=deferred();const {client}=make(session(),async path=>path.endsWith('/login')?auth('fixture-b'):pending.promise);
  await client.restore();const old=client.profile();await tick();await client.login('fixture-b','synthetic');pending.resolve({data:{id:'fixture-a'}});await assert.rejects(old,/旧账号/);assert.equal(client.current().memberId,'fixture-b');
});
test('old refresh cannot overwrite or clear new account',async()=>{
  const pending=deferred();const {client,store}=make(session(),async path=>{
    if(path.endsWith('/login'))return auth('fixture-b','synthetic-b');if(path.endsWith('/refresh'))return pending.promise;throw new ApiError('expired',401);
  });await client.restore();const old=client.profile();await tick();await client.login('fixture-b','synthetic');pending.resolve(auth());await assert.rejects(old,/旧账号/);assert.equal(store.value.memberId,'fixture-b');
});
test('mismatched profile is rejected and invalidates account',async()=>{
  const {client,store}=make(session(),async()=>({data:{id:'different-fixture'}}));await client.restore();await assert.rejects(client.profile(),/账号资料/);assert.equal(store.value,undefined);
});
test('404 405 and 503 do not erase valid account',async()=>{
  for(const status of [404,405,503]){const {client,store}=make(session(),async()=>{throw new ApiError('fixture unavailable',status);});await client.restore();await assert.rejects(client.profile());assert.ok(store.value);assert.ok(client.current());}
});
test('rejected profile token retries once, not forever',async()=>{
  let calls=0;const {client,store}=make(session(),async path=>{if(path.endsWith('/refresh'))return auth();calls++;throw new ApiError('expired',401);});
  await client.restore();await assert.rejects(client.profile());assert.equal(calls,2);assert.equal(store.value,undefined);
});
test('public content sends no account credentials',async()=>{
  const paths=[];const {client}=make(session(),async(path,fields,s)=>{assert.equal(s,undefined);paths.push(path);return {data:path.endsWith('/index')?[]:{id:2,title:'fixture',content:'text'}};});
  await client.restore();await client.articles();await client.article('2',true);assert.deepEqual(paths,['/api/rf-article/article/index','/api/rf-article/article-single/view?id=2']);
});
test('article list handles duplicate and malformed entries',()=>{
  assert.deepEqual(parseArticles([{id:1,title:'One'},null,{id:1,title:'Dup'},{id:2,title:42},{id:3,title:'Three'}]),[{id:'1',title:'One'},{id:'3',title:'Three'}]);
  assert.deepEqual(parseArticles({list:[]}),[]);for(const data of [null,{},'bad',[null]])assert.throws(()=>parseArticles(data));
});
test('detail fields cannot pass objects into Text',()=>{
  assert.deepEqual(parseArticle({id:3,title:{bad:1},content:{bad:1},description:'safe'}),{id:'3',title:'',content:'',description:'safe'});
});
test('stored session validates all fields and rejects control bytes',()=>{
  for(const data of [null,{},[],{...session(),memberId:''},{...session(),refreshToken:undefined},{...session(),accessToken:'synthetic\r\nInjected'},{...session(),expiresAt:NaN}])assert.throws(()=>validateStoredSession(data));
});
