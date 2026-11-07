import test from 'node:test';import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';import {execFileSync} from 'node:child_process';
import {mkdtempSync,readFileSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {fileURLToPath} from 'node:url';
registerHooks({resolve(s,c,next){return next(s.startsWith('.')&&c.parentURL?.endsWith('.ts')&&!/\.[a-z]+$/.test(s)?s+'.ts':s,c);}});
const m=await import('../entry/src/main/ets/model/CoolWearReadProtocol.ts');
const root=fileURLToPath(new URL('../../',import.meta.url));
test('Harmony read and ACK frames exactly match original supplied AAR encoder',()=>{
 const folder=mkdtempSync(join(tmpdir(),'sayring-harmony-codec-'));
 const java=name=>process.env.JAVA_HOME?join(process.env.JAVA_HOME,'bin',name):name;
 execFileSync(java('jar'),['xf',join(root,'android/app/libs/coolwear_bluesdk-release.aar'),'classes.jar'],{cwd:folder});
 execFileSync(java('javac'),['-encoding','UTF-8','-cp',join(folder,'classes.jar'),'-d',folder,join(root,'tool/fixtures/CoolWearHarmonyReadOracle.java')]);
 const output=execFileSync(java('java'),['-cp',[folder,join(folder,'classes.jar')].join(process.platform==='win32'?';':':'),'CoolWearHarmonyReadOracle'],{encoding:'utf8'});
 for(const row of output.trim().split(/\r?\n/)){const [type,seq,cmd,hex]=row.split(':');const result=+cmd===3?m.coolWearQuery(+type,+seq):m.coolWearAck({type:+type,sequence:+seq,command:1,body:[]});assert.equal(Buffer.from(result).toString('hex'),hex);}
});
const header=(type,body,sequence=7)=>{const b=Array(20).fill(0);b[1]=1;b[2]=Math.max(0,Math.ceil((body.length-10)/19));b[3]=sequence;b[4]=1;b[5]=type;b[8]=body.length&255;b[9]=body.length>>8;b.splice(10,Math.min(body.length,10),...body.slice(0,10));return b;};
test('read ceiling rejects settings, measurement, pair/reset and malformed sequence',()=>{
 for(const type of [9,22,70,112,120,0,255])assert.throws(()=>m.coolWearQuery(type,1));
 for(const seq of [-1,256,NaN,1.5])assert.throws(()=>m.coolWearQuery(2,seq));
 assert.throws(()=>m.coolWearAck({type:3,sequence:1,command:4,body:[]}));
});
test('decoder accepts bounded exact complete responses and never ACKs ACK packets',()=>{
 const decoder=new m.CoolWearReadDecoder();
 assert.deepEqual(decoder.accept(header(3,[0,0]),1),{sequence:7,command:1,type:3,body:[0,0]});
 const ack=header(3,[1]);ack[4]=4;assert.equal(decoder.accept(ack,2),undefined);
 for(const modify of [b=>b[1]=2,b=>b[8]=200,b=>b[5]=22,b=>b[2]=2]){const b=header(2,[1,2,3,4,5,6]);modify(b);assert.equal(decoder.accept(b,3),undefined);}
 assert.equal(m.coolWearBattery([101]),undefined);assert.equal(m.coolWearBattery([]),undefined);assert.equal(m.coolWearBattery([0]),0);
 assert.equal(m.coolWearFirmware([12,1,2,3,4,5]),undefined);assert.equal(m.coolWearFirmware([12,1,2,3,4,5,6]),'1.2.3.4.5');
});
test('missing, stale or out-of-order fragments cannot become device data',()=>{
 const body=Array.from({length:40},(_,i)=>i);const continuation=(index,data)=>{const b=Array(20).fill(0);b[0]=index;data.forEach((v,i)=>b[i+1]=v);return b;};
 const d=new m.CoolWearReadDecoder();assert.equal(d.accept(header(2,body),1),undefined);assert.equal(d.accept(continuation(1,body.slice(10,29)),2),undefined);
 assert.deepEqual(d.accept(continuation(2,body.slice(29)),3).body,body);
 d.accept(header(2,body),4);assert.equal(d.accept(continuation(2,body.slice(29)),5),undefined);
 d.accept(header(2,body),6);assert.equal(d.accept(continuation(1,body.slice(10,29)),4007),undefined);
});

const source=readFileSync(new URL('../entry/src/main/ets/services/CoolWearReadOnlySession.ets',import.meta.url),'utf8');
const {stripTypeScriptTypes}=await import('node:module');
const makeSession=new Function('ble','constant','COOLWEAR_SERVICE','CoolWearReadDecoder','coolWearQuery','coolWearAck','coolWearFirmware','coolWearBattery',stripTypeScriptTypes(source.slice(source.indexOf('export class')),{mode:'transform'}).replace('export class','class')+';return new CoolWearReadOnlySession();');
function fixture(autoReply=true){const clients=[],writes=[];
 const ble={GattWriteType:{WRITE:1,WRITE_NO_RESPONSE:2},createGattClientDevice(target){
  const callbacks={};const service=m.COOLWEAR_SERVICE;
  const notify={serviceUuid:service,characteristicUuid:'fixture-notify',properties:{notify:true},descriptors:[],characteristicValue:new ArrayBuffer(0)};
  const writer={...notify,characteristicUuid:'fixture-write',properties:{writeNoResponse:true}};
  const client={closed:false,on(event,callback){callbacks[event]=callback;},connect(){queueMicrotask(()=>callbacks.BLEConnectionStateChange({deviceId:target,state:2}));},disconnect(){},close(){this.closed=true;},getServices:async()=>[{serviceUuid:service,characteristics:[notify,writer]}],setCharacteristicChangeNotification:async()=>{},async writeCharacteristicValue(characteristic){const bytes=Array.from(new Uint8Array(characteristic.characteristicValue));writes.push(bytes);if(autoReply&&bytes[4]===3){const packet=header(bytes[5],bytes[5]===2?[12,1,2,3,4,5,6]:[73,0]);queueMicrotask(()=>callbacks.BLECharacteristicChange({...notify,characteristicValue:new Uint8Array(packet).buffer}));}},callbacks};clients.push(client);return client;
 }};
 return {session:makeSession(ble,{ProfileConnectionState:{STATE_CONNECTED:2,STATE_DISCONNECTED:0}},m.COOLWEAR_SERVICE,m.CoolWearReadDecoder,m.coolWearQuery,m.coolWearAck,m.coolWearFirmware,m.coolWearBattery),clients,writes};
}
test('temporary production session requires device data, sends only reads/ACKs, and closes the link',async()=>{
 const f=fixture();assert.deepEqual(await f.session.read('exact-fixture-target',()=>true),{firmware:'1.2.3.4.5',battery:73,charging:false});assert.equal(f.clients[0].closed,true);
 assert.equal(f.writes.filter(b=>b[4]===3).length,2);assert.equal(f.writes.filter(b=>b[4]===4).length,2);
 assert.ok(f.writes.every(b=>[2,3].includes(b[5])&&[3,4].includes(b[4])));
});
test('cancelled or changed-owner sessions close promptly and late callbacks cannot revive them',async()=>{
 const f=fixture(false);let current=true;const pending=f.session.read('exact-fixture-target',()=>current);const rejected=assert.rejects(pending,/取消|变化/);
 await Promise.resolve();await Promise.resolve();current=false;f.session.cancel();await rejected;assert.equal(f.clients[0].closed,true);
 f.clients[0].callbacks.BLEConnectionStateChange({deviceId:'exact-fixture-target',state:2});await Promise.resolve();assert.equal(f.clients.length,1);
});
