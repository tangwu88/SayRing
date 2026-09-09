import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
import { DatabaseSync } from 'node:sqlite';
import { mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
registerHooks({ resolve(specifier, context, next) {
  return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ? specifier + '.ts' : specifier, context);
}});
const { HEALTH_OWNER_SCHEMA, OWNED_HEALTH_TABLE, healthUploadRequests, assertHealthUploadAccepted,
  recordWithinOwnership, chinaHealthTime, sameHealthSession, UPSERT_OWNED_HEALTH_SQL,
  MARK_HEALTH_UPLOADED_SQL, ownershipStart } = await import('../entry/src/main/ets/model/HealthUpload.ts');
const { HealthUploadService } = await import('../entry/src/main/ets/services/HealthUploadService.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const now = Date.parse('2026-09-06T12:00:00+08:00');
const record = (metric = 'heart', fields = [['心率', 75, 'BPM']], timestamp = now) => ({
  id: `${metric}-${timestamp}`, deviceKey: 'synthetic-watch', metric, timestamp,
  source: 'app_measurement', values: fields.map(([name,value,unit]) => ({name,value,unit})), samples: [], sampleFrequency: 0,
});
const deferred = () => { let resolve; const promise = new Promise(done => resolve = done); return {resolve,promise}; };

test('owner schema migration preserves unscoped original data without assigning any account', () => {
  const db = new DatabaseSync(':memory:');
  db.exec("CREATE TABLE wearable_health_record(record_id TEXT PRIMARY KEY,payload TEXT); INSERT INTO wearable_health_record VALUES ('old','original')");
  db.exec('BEGIN'); for (const sql of HEALTH_OWNER_SCHEMA) db.exec(sql); db.exec('COMMIT');
  for (const sql of HEALTH_OWNER_SCHEMA) db.exec(sql);
  assert.equal(db.prepare('SELECT payload FROM wearable_health_record').get().payload,'original');
  assert.equal(db.prepare(`SELECT COUNT(*) AS n FROM ${OWNED_HEALTH_TABLE}`).get().n,0);
  const insert = db.prepare(`INSERT INTO ${OWNED_HEALTH_TABLE} VALUES(?,?,?,?,?,?,?,?,?)`);
  insert.run('owner-a','same-id','watch','heart',now,'app_measurement','a','pending',now);
  insert.run('owner-b','same-id','watch','heart',now,'app_measurement','b','pending',now);
  assert.deepEqual(db.prepare(`SELECT payload FROM ${OWNED_HEALTH_TABLE} WHERE owner_id=?`).all('owner-a').map(row=>row.payload),['a']);
  db.close();
});
test('real queue SQL preserves synced duplicates and rejects stale upload acknowledgements', () => {
  const db=new DatabaseSync(':memory:');for(const sql of HEALTH_OWNER_SCHEMA)db.exec(sql);
  const save=db.prepare(UPSERT_OWNED_HEALTH_SQL),mark=db.prepare(MARK_HEALTH_UPLOADED_SQL);
  const args=['owner-a','one','watch','heart',now,'app_measurement'];
  save.run(...args,'first','pending',now);mark.run('owner-a','one','first');
  save.run(...args,'first','pending',now+1);
  const state=()=>db.prepare(`SELECT sync_state FROM ${OWNED_HEALTH_TABLE} WHERE owner_id='owner-a'`).get().sync_state;
  assert.equal(state(),'synced');
  save.run(...args,'fuller','pending',now+2);mark.run('owner-a','one','first');assert.equal(state(),'pending');
  mark.run('owner-b','one','fuller');assert.equal(state(),'pending');
  mark.run('owner-a','one','fuller');assert.equal(state(),'synced');db.close();
});
test('same-owner cold restart keeps committed history and pending state without exposing another owner', () => {
  const directory=mkdtempSync(join(tmpdir(),'saydian-owner-restart-')),path=join(directory,'synthetic.db');
  let db=new DatabaseSync(path);
  try {
    for(const sql of HEALTH_OWNER_SCHEMA)db.exec(sql);
    const row=record(),payload=JSON.stringify(row);
    db.prepare(UPSERT_OWNED_HEALTH_SQL).run('owner-a',row.id,row.deviceKey,row.metric,row.timestamp,row.source,payload,'pending',now);
    db.close();db=new DatabaseSync(path);
    for(const sql of HEALTH_OWNER_SCHEMA)db.exec(sql);
    const query=db.prepare(`SELECT payload,sync_state FROM ${OWNED_HEALTH_TABLE} WHERE owner_id=? AND device_key=? AND recorded_at BETWEEN ? AND ?`);
    const restored=query.all('owner-a',row.deviceKey,now-1000,now+1000);
    assert.equal(restored.length,1);assert.deepEqual(JSON.parse(restored[0].payload),row);
    assert.equal(restored[0].sync_state,'pending');assert.equal(query.all('owner-b',row.deviceKey,now-1000,now+1000).length,0);
    // A new collection cutoff only filters new transport records, never old explicitly owned rows.
    assert.equal(ownershipStart('owner-a',now-1000,'owner-a',now+5000,false),now+5000);
    assert.equal(query.all('owner-a',row.deviceKey,now-1000,now+1000).length,1);
  } finally { db.close();unlinkSync(path);rmdirSync(directory); }
});
test('ownership rejects shared watch history, unknown dates and mixed daily totals', () => {
  assert.equal(recordWithinOwnership(record('heart',undefined,now-1),now,now),false);
  assert.equal(recordWithinOwnership(record(),now,now),true);
  assert.equal(recordWithinOwnership(record('heart',undefined,now+120000),now,now),false);
  assert.equal(recordWithinOwnership(record('activity', [['步数',42,'步']],now),now,now),false);
  const tomorrow = now + 86400000;
  assert.equal(recordWithinOwnership(record('activity',[['步数',42,'步']],tomorrow),now,tomorrow),true);
  assert.equal(recordWithinOwnership(record('heart',undefined,0),now,now),false);
});
test('a deliberate reconnect or cold start does not claim another phone\'s intervening watch history', () => {
  assert.equal(ownershipStart('owner-a',now-1000,'owner-a',now,false),now);
  assert.equal(ownershipStart('owner-a',now-1000,'owner-b',now,true),now);
  assert.equal(ownershipStart('owner-a',now-1000,'owner-a',now,true),now-1000);
});
test('China upload time and daily rows are independent of host timezone and omit missing fields', () => {
  assert.equal(chinaHealthTime(Date.parse('2026-09-05T16:01:00Z')),'2026-09-06 00:01:00');
  const rows = healthUploadRequests([record(),record('pressure',[['收缩压',120,'mmHg'],['舒张压',80,'mmHg']])]);
  assert.equal(rows.length,1);
  const row = JSON.parse(rows[0].body).dailyDate[0];
  assert.equal(row.date,'2026-09-06 12:00:00');
  assert.deepEqual(row.pulseReat,[75]);
  assert.deepEqual(row.bloodPressure,{bloodPressureHigh:120,bloodPressureLow:80});
  assert.equal('bloodGlucose' in row,false); assert.equal('step' in row,false);
});
test('sleep is minutes and advanced metrics retain original fields and waveform samples', () => {
  const sleep = JSON.parse(healthUploadRequests([record('sleep',[['总睡眠',420,'分钟'],['深睡',100,'分钟']])])[0].body).dailyDate[0];
  assert.deepEqual(sleep.sleepData,{allSleepTime:420,deepSleepTime:100});
  const ecg = record('ecg',[['平均心率',70,'BPM'],['QT',380,'ms']]); ecg.samples=[0.12,-0.23,0.08];ecg.sampleFrequency=250;
  const upload = healthUploadRequests([ecg])[0], body=JSON.parse(upload.body);
  assert.equal(upload.path,'/api/v1/member/e-c-g'); assert.deepEqual(body.totalArray,ecg.samples);
  assert.equal(body.data.sampleFrequency,250); assert.equal(body.data.averageTimeInterval,380);
  assert.equal(body.data.record_id,ecg.id); assert.equal(body.data.date,'2026-09-06 12:00:00');
  assert.equal('rawVersion' in body.data,false);
});
test('a business success with partial rejection never marks its batch uploaded', () => {
  for (const data of [{rejected:['x']},{rejected:{x:'failure'}},{failed:1},{acceptedIds:['other']}]) {
    assert.throws(()=>assertHealthUploadAccepted(data,['x']));
  }
  assert.doesNotThrow(()=>assertHealthUploadAccepted({acceptedIds:['x'],rejected:[]},['x']));
});
function queueFixture(rows=[record()]) {
  const pending=[...rows], marked=[], calls=[];
  let session={ownerId:'owner-a',generation:1};
  const api={healthSession:()=>({...session}),async uploadHealthRequest(request){calls.push(request)}};
  const store={async pending(owner){assert.equal(owner,'owner-a');return [...pending]},
    async pendingCount(){return pending.length},async markUploaded(owner,records,current){
      assert.equal(owner,'owner-a');if(!current())return;
      for(const row of records){marked.push(row.id);const index=pending.findIndex(item=>item.id===row.id);if(index>=0)pending.splice(index,1)}
    }};
  return {service:new HealthUploadService(store,api),api,marked,calls,pending,setSession(value){session=value}};
}
test('successful upload drains pending queue once and concurrent requests share a single flight', async () => {
  const f=queueFixture(), gate=deferred();f.api.uploadHealthRequest=async request=>{f.calls.push(request);await gate.promise};
  const first=f.service.synchronize(),second=f.service.synchronize(); assert.equal(first,second);gate.resolve();
  assert.deepEqual(await first,{state:'complete',uploaded:1,pending:0,message:''});assert.equal(f.calls.length,1);
});
test('offline upload remains pending and is retried on the next explicit sync', async () => {
  const f=queueFixture(); f.api.uploadHealthRequest=async()=>{throw Error('offline')};
  assert.equal((await f.service.synchronize()).state,'retry');assert.equal(f.marked.length,0);assert.equal(f.pending.length,1);
  f.api.uploadHealthRequest=async()=>{};assert.equal((await f.service.synchronize()).state,'complete');
});
test('switching account or connection generation during network request rejects late completion', async () => {
  for (const accountChange of [true,false]) {
    const f=queueFixture(),gate=deferred();let current=true;
    f.api.uploadHealthRequest=async()=>{if(accountChange)f.setSession({ownerId:'owner-b',generation:2});else current=false;await gate.promise};
    const running=f.service.synchronize(()=>current);gate.resolve();
    assert.equal((await running).state,'cancelled');assert.equal(f.marked.length,0);assert.equal(f.pending.length,1);
  }
});
test('same account with a new login generation is a different health session',()=>{
  assert.equal(sameHealthSession({ownerId:'owner-a',generation:1},{ownerId:'owner-a',generation:2}),false);
  assert.equal(sameHealthSession({ownerId:'',generation:1},{ownerId:'',generation:1}),false);
});
test('account lifecycle reports logout immediately and never accepts upload after account switch', async()=>{
  const session={accessToken:'synthetic',refreshToken:'synthetic-refresh',expiresAt:now+3600000,memberId:'1',displayName:'synthetic'};
  const vault={async read(){return session},async write(){},async clear(){}};
  const gate=deferred(),seen=[];
  const client=new AccountClient({async request(){await gate.promise;return {code:200,data:{}}}},vault,()=>now);
  client.observeHealthSession(value=>seen.push({...value}));await client.restore();const owner=client.healthSession();
  const request=healthUploadRequests([record()])[0];const uploading=client.uploadHealthRequest(request,owner);
  await client.logout();gate.resolve();await assert.rejects(uploading);
  assert.equal(seen.at(-1).ownerId,'');assert.ok(seen.at(-1).generation>owner.generation);
  await assert.rejects(client.uploadHealthRequest(request,owner));
});
