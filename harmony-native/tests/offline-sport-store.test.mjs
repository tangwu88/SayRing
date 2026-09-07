import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { DatabaseSync } from 'node:sqlite';
import * as model from '../entry/src/main/ets/model/HealthUpload.ts';

// Execute the production store against SQLite; only the Harmony RDB adapter is substituted.
class Predicates {
  constructor(table) { this.table=table;this.conditions=[];this.args=[];this.order=''; }
  equalTo(column,value) { this.conditions.push(`${column}=?`);this.args.push(value);return this; }
  and() { return this; }
  orderByDesc(column) { this.order=` ORDER BY ${column} DESC`;return this; }
}
globalThis.__sportStoreDependencies={...model,relationalStore:{RdbPredicates:Predicates}};
const storeURL=new URL('../entry/src/main/ets/services/WearableHealthStore.ets',import.meta.url).href;
registerHooks({ load(url,context,next) {
  if(url!==storeURL)return next(url,context);
  const source=readFileSync(new URL(url),'utf8').replace(/^import[\s\S]*?;\r?\n/gm,'');
  return {format:'module',shortCircuit:true,source:stripTypeScriptTypes(
    `const {${Object.keys(globalThis.__sportStoreDependencies).join(',')}}=globalThis.__sportStoreDependencies;\n${source}`)};
}});
const {WearableHealthStore}=await import(storeURL);
function fixture() {
  const db=new DatabaseSync(':memory:');
  for(const sql of model.HEALTH_OWNER_SCHEMA)db.exec(sql);
  const insert=db.prepare(model.UPSERT_OWNED_HEALTH_SQL);
  const add=(owner,id,metric='sport',timestamp=1,deviceKey='watchA')=>{
    const record={id,deviceKey,metric,timestamp,source:'watch_history',values:[{name:'步数',value:100,unit:'步'}],samples:[],sampleFrequency:0};
    insert.run(owner,id,deviceKey,metric,timestamp,'watch_history',JSON.stringify(record),'local_only',timestamp);
    return record;
  };
  const queries=[];
  const native={async query(predicates){
    const sql=`SELECT payload FROM ${predicates.table} WHERE ${predicates.conditions.join(' AND ')}${predicates.order}`;
    queries.push({sql,args:predicates.args});
    const rows=db.prepare(sql).all(...predicates.args);let index=-1;
    return {goToNextRow:()=>++index<rows.length,getString:()=>rows[index].payload,close(){}};
  }};
  const store=new WearableHealthStore();store.store=native;
  return {db,store,native,queries,add};
}
test('production owner-scoped sport query excludes other accounts and old unowned rows across all saved devices',async()=>{
  const {db,store,add,queries,native}=fixture();
  try {
    const old=add('ownerA','old','sport',1),newest=add('ownerA','new','sport',2,'watchB');
    add('ownerB','other','sport',3);add('','legacy','sport',4);
    for(let i=0;i<2001;i++)add('ownerA',`heart-${i}`,'heart',10+i);
    assert.deepEqual(await store.loadSportRecords('ownerA'),[newest,old]);
    const restarted=new WearableHealthStore();restarted.store=native;
    assert.deepEqual(await restarted.loadSportRecords('ownerA'),[newest,old]);
    assert.match(queries[0].sql,/owner_id=\? AND metric=\?/);
    assert.deepEqual(queries[0].args,['ownerA','sport']);
    assert.deepEqual(await store.loadSportRecords(''),[]);
    assert.equal(queries.length,2);
  } finally {db.close();}
});
test('sport query waits for local persistence and reports real database failure, not empty success',async()=>{
  const {db,store,add}=fixture();
  try {
    let release;store.writing=new Promise(resolve=>{release=resolve;});
    const read=store.loadSportRecords('ownerA');
    const record=add('ownerA','just-saved');release();
    assert.deepEqual(await read,[record]);
    store.store={async query(){throw new Error('database unavailable');}};
    await assert.rejects(store.loadSportRecords('ownerA'),/database unavailable/);
  } finally {db.close();}
});
