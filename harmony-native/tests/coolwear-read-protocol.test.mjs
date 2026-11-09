import test from 'node:test';import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';import {execFileSync} from 'node:child_process';
import {mkdtempSync,readFileSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {fileURLToPath} from 'node:url';
registerHooks({resolve(s,c,next){return next(s.startsWith('.')&&c.parentURL?.endsWith('.ts')&&!/\.[a-z]+$/.test(s)?s+'.ts':s,c);}});
const m=await import('../entry/src/main/ets/model/CoolWearReadProtocol.ts');
const controls=await import('../entry/src/main/ets/model/CoolWearMeasurementProtocol.ts');
const root=fileURLToPath(new URL('../../',import.meta.url));
test('Harmony read and ACK frames exactly match original supplied AAR encoder',()=>{
 const folder=mkdtempSync(join(tmpdir(),'sayring-harmony-codec-'));
 const java=name=>process.env.JAVA_HOME?join(process.env.JAVA_HOME,'bin',name):name;
 execFileSync(java('jar'),['xf',join(root,'android/app/libs/coolwear_bluesdk-release.aar'),'classes.jar'],{cwd:folder});
 execFileSync(java('javac'),['-encoding','UTF-8','-cp',join(folder,'classes.jar'),'-d',folder,join(root,'tool/fixtures/CoolWearHarmonyReadOracle.java')]);
 const output=execFileSync(java('java'),['-cp',[folder,join(folder,'classes.jar')].join(process.platform==='win32'?';':':'),'CoolWearHarmonyReadOracle'],{encoding:'utf8'});
 for(const row of output.trim().split(/\r?\n/)){if(row.startsWith('sample:')){const [,v,t]=row.split(':');assert.equal(controls.coolWearTimedManualValue('heart',[0,0,0,0,0xd2,0x49,0x6b,+v],+t),+v);continue;}if(row.startsWith('ended:')){const [,b,h,o]=row.split(':');assert.equal(controls.coolWearManualEnded('heart',[+b]),h==='true');assert.equal(controls.coolWearManualEnded('oxygen',[+b]),o==='true');continue;}if(row.startsWith('control:')){const [,metric,state,role,hex]=row.split(':');const bytes=controls.coolWearMeasurementCommand(+metric===0?'heart':'oxygen',+state===1,4,+role,{heartManual:true,oxygenManual:true,heartHistory:true});assert.equal(Buffer.from(bytes).toString('hex'),hex);continue;}if(row.startsWith('cap:')){const [,bit,h,o,hist]=row.split(':');const b=Array(32).fill(0);b[Math.floor(+bit/8)]=1<<(+bit%8);assert.deepEqual(m.coolWearCapabilities(b),{heartManual:h==='true',oxygenManual:o==='true',heartHistory:hist==='true'});continue;}if(row.startsWith('role-query:')){assert.equal(Buffer.from(m.coolWearQuery(3,2,101)).toString('hex'),row.slice(11));continue;}if(row.startsWith('role-ack:')){assert.equal(Buffer.from(m.coolWearAck({role:101,type:2,sequence:7,command:1,body:[]})).toString('hex'),row.slice(9));continue;}if(row.startsWith('short:')){const bytes=Array.from(Buffer.from(row.slice(6),'hex'));assert.deepEqual(new m.CoolWearReadDecoder().accept(bytes,1).body,[12,1,2,3,4,5,6]);continue;}const [type,seq,cmd,hex]=row.split(':');const result=+cmd===3?m.coolWearQuery(+type,+seq):m.coolWearAck({role:1,type:+type,sequence:+seq,command:1,body:[]});assert.equal(Buffer.from(result).toString('hex'),hex);}
});
const header=(type,body,sequence=7)=>{const b=Array(20).fill(0);b[1]=1;b[2]=Math.max(0,Math.ceil((body.length-10)/19));b[3]=sequence;b[4]=1;b[5]=type;b[8]=body.length&255;b[9]=body.length>>8;b.splice(10,Math.min(body.length,10),...body.slice(0,10));return b;};
test('read ceiling rejects settings, measurement, pair/reset and malformed sequence',()=>{
 for(const type of [9,22,70,112,120,0,255])assert.throws(()=>m.coolWearQuery(type,1));
 for(const seq of [-1,256,NaN,1.5])assert.throws(()=>m.coolWearQuery(2,seq));
 assert.throws(()=>m.coolWearAck({role:1,type:3,sequence:1,command:4,body:[]}));
});
test('decoder accepts bounded exact complete responses and never ACKs ACK packets',()=>{
 const decoder=new m.CoolWearReadDecoder();
 assert.deepEqual(decoder.accept(header(3,[0,0]),1),{role:1,sequence:7,command:1,type:3,body:[0,0]});
 const ack=header(3,[1]);ack[4]=4;assert.equal(decoder.accept(ack,2),undefined);
 for(const modify of [b=>b[8]=200,b=>b[5]=70,b=>b[2]=2]){const b=header(2,[1,2,3,4,5,6]);modify(b);assert.equal(decoder.accept(b,3),undefined);}
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
const makeSession=new Function('ble','constant','COOLWEAR_SERVICE','CoolWearReadDecoder','coolWearQuery','coolWearAck','coolWearFirmware','coolWearBattery','coolWearCapabilitiesQuery','coolWearCapabilities','coolWearMeasurementCommand','coolWearManualValue','coolWearTimedManualValue','coolWearManualEnded',stripTypeScriptTypes(source.slice(source.indexOf('export class')),{mode:'transform'}).replace('export class','class')+';return new CoolWearReadOnlySession();');
function fixture(autoReply=true,mode='normal'){const clients=[],writes=[];
 const ble={GattWriteType:{WRITE:1,WRITE_NO_RESPONSE:2},createGattClientDevice(target){
  const callbacks={};const service=m.COOLWEAR_SERVICE;
  const notify={serviceUuid:service,characteristicUuid:'fixture-notify',properties:{notify:true},descriptors:[],characteristicValue:new ArrayBuffer(0)};
  const writer={...notify,characteristicUuid:'fixture-write',properties:{writeNoResponse:true}};
  const client={closed:false,on(event,callback){callbacks[event]=callback;},connect(){queueMicrotask(()=>callbacks.BLEConnectionStateChange({deviceId:target.toUpperCase(),state:2}));},disconnect(){},close(){this.closed=true;},getServices:async()=>[{serviceUuid:service,characteristics:[notify,writer]}],setCharacteristicChangeNotification:async()=>{},async writeCharacteristicValue(characteristic){const bytes=Array.from(new Uint8Array(characteristic.characteristicValue));writes.push(bytes);if(autoReply&&bytes[4]===3){const packet=header(bytes[5],bytes[5]===2?[12,1,2,3,4,5,6]:bytes[5]===22?[34,16]:[73,0]);packet[1]=101;queueMicrotask(()=>callbacks.BLECharacteristicChange({...notify,characteristicValue:new Uint8Array(packet).buffer}));}if(autoReply&&bytes[4]===1&&[20,24].includes(bytes[5])){
 const emit=(packet)=>queueMicrotask(()=>callbacks.BLECharacteristicChange({...notify,characteristicValue:new Uint8Array(packet).buffer}));
 const ack=header(bytes[5],[1],bytes[3]);ack[1]=101;ack[4]=4;
 if(bytes[10]===1){
  if(mode!=='missing-start-ack')emit(ack);
  const t=Buffer.alloc(4);t.writeUInt32LE(Math.floor(Date.now()/1000));const data=header(bytes[5]===24?7:20,bytes[5]===24?[0,0,0,...t,72]:[...t,97],9);data[1]=101;if(mode==='ended'){const end=header(21,[bytes[5]===24?0x10:0x30],10);end[1]=101;emit(end);}else if(mode!=='no-data')emit(data);
 }else if(mode!=='missing-stop-ack')emit(ack);
}},callbacks};clients.push(client);return client;
 }};
 return {session:makeSession(ble,{ProfileConnectionState:{STATE_CONNECTED:2,STATE_DISCONNECTED:0}},m.COOLWEAR_SERVICE,m.CoolWearReadDecoder,m.coolWearQuery,m.coolWearAck,m.coolWearFirmware,m.coolWearBattery,m.coolWearCapabilitiesQuery,m.coolWearCapabilities,controls.coolWearMeasurementCommand,controls.coolWearManualValue,controls.coolWearTimedManualValue,controls.coolWearManualEnded),clients,writes};
}
test('temporary production session requires device data, sends only reads/ACKs, and closes the link',async()=>{
 const f=fixture();assert.deepEqual(await f.session.read('exact-fixture-target',()=>true),{firmware:'1.2.3.4.5',battery:73,charging:false});assert.equal(f.clients[0].closed,true);
 assert.equal(f.writes.filter(b=>b[4]===3).length,2);assert.equal(f.writes.filter(b=>b[4]===4).length,2);assert.ok(f.writes.filter(b=>b[4]===4||b[5]===3).every(b=>b[1]===101));
 assert.ok(f.writes.every(b=>[2,3].includes(b[5])&&[3,4].includes(b[4])));
});
test('cancelled or changed-owner sessions close promptly and late callbacks cannot revive them',async()=>{
 const f=fixture(false);let current=true;const pending=f.session.read('exact-fixture-target',()=>current);const rejected=assert.rejects(pending,/取消|变化/);
 await Promise.resolve();await Promise.resolve();current=false;f.session.cancel();await rejected;assert.equal(f.clients[0].closed,true);
 f.clients[0].callbacks.BLEConnectionStateChange({deviceId:'exact-fixture-target',state:2});await Promise.resolve();assert.equal(f.clients.length,1);
});
test('capability inspection waits for an actual capability response and does not infer manual heart from history',async()=>{
 const f=fixture();const result=await f.session.read('exact-fixture-target',()=>true,()=>{},true);
 assert.deepEqual(result.capabilities,{heartManual:true,oxygenManual:true,heartHistory:true});
 assert.deepEqual(f.writes.filter(b=>b[4]===3).map(b=>b[5]),[2,3,22]);
 assert.deepEqual(m.coolWearCapabilities([32,0]),{heartManual:false,oxygenManual:false,heartHistory:true});
 assert.equal(m.coolWearCapabilities([34]),undefined);
});
test('measurement commands require explicit manual capability, but stop remains available after revocation',()=>{
 const passive={heartManual:false,oxygenManual:false,heartHistory:true};
 assert.throws(()=>controls.coolWearMeasurementCommand('heart',true,4,101,passive));
 assert.throws(()=>controls.coolWearMeasurementCommand('oxygen',true,4,101,passive));
 assert.equal(controls.coolWearMeasurementCommand('heart',false,4,101,passive)[10],0);
 assert.throws(()=>controls.coolWearMeasurementCommand('hrv',true,4,101,passive));
});
test('heart and oxygen require start ACK plus a genuine sample and STOP ACK before resolving',async()=>{
 for(const metric of ['heart','oxygen']){const f=fixture();const result=await f.session.read('exact-target',()=>true,()=>{},true,metric);
 assert.equal(result.reading.value,metric==='heart'?72:97);assert.equal(result.reading.metric,metric);assert.equal(f.clients[0].closed,true);
 assert.deepEqual(f.writes.filter(b=>b[4]===1).map(b=>[b[5],b[10]]),[[metric==='heart'?24:20,1],[metric==='heart'?24:20,0]]);}
});
test('early data without start ACK never resolves as a measurement and cancellation sends STOP once',async()=>{
 const f=fixture(true,'missing-start-ack');let resolved=false;
 const pending=f.session.read('exact-target',()=>true,()=>{},true,'heart').then(()=>{resolved=true;});const rejected=assert.rejects(pending,/取消/);
 for(let i=0;i<60;i++)await Promise.resolve();assert.equal(resolved,false);f.session.cancel();await rejected;
 assert.equal(f.writes.filter(b=>b[4]===1&&b[10]===0).length,1);assert.equal(f.clients[0].closed,true);
});
test('zero, sentinel and ended packets never become a manual reading',()=>{
 assert.equal(controls.coolWearManualValue('heart',[0,72]),undefined);assert.equal(controls.coolWearManualValue('heart',[1,0]),undefined);
 assert.equal(controls.coolWearManualValue('heart',[1,255]),undefined);assert.equal(controls.coolWearManualValue('oxygen',[1,2,3,4,101]),undefined);
 assert.equal(controls.coolWearManualValue('oxygen',[1,2]),undefined);
});

test('missing STOP confirmation rejects a genuine sample and closes without retrying physical STOP',async()=>{
 const f=fixture(true,'missing-stop-ack');
 await assert.rejects(f.session.read('exact-fixture-target',()=>true,()=>{},true,'heart'),/停止测量未获确认/);
 assert.equal(f.writes.filter(b=>b[4]===1&&b[5]===24&&b[10]===0).length,1);
 assert.equal(f.clients[0].closed,true);
});


test('live SDK heart channel parses records after its prefix and rejects stale, future and malformed samples',()=>{
 const now=1800000000000;const t=Buffer.alloc(4);t.writeUInt32LE(now/1000);
 assert.equal(controls.coolWearTimedManualValue('heart',[0,0,0,...t,72],now),72);
 assert.equal(controls.coolWearTimedManualValue('oxygen',[...t,97],now),97);
 for(const delta of [-601000,601000])assert.equal(controls.coolWearTimedManualValue('heart',[0,0,0,...t,72],now+delta),undefined);
 assert.equal(controls.coolWearTimedManualValue('heart',[0,0,0,...t,72,1],now),undefined);
 assert.equal(controls.coolWearTimedManualValue('oxygen',[...t,101],now),undefined);
 assert.equal(controls.coolWearManualEnded('heart',[0x10]),true);
 assert.equal(controls.coolWearManualEnded('oxygen',[0x30]),true);
 assert.equal(controls.coolWearManualEnded('heart',[0x30]),false);
 assert.equal(new m.CoolWearReadDecoder().accept(header(21,[0x30]),1),undefined);
 for(const type of [7,21])assert.equal(m.coolWearAck({role:101,type,sequence:9,command:1,body:[]})[5],type);
});


test('device measurement-end status is acknowledged before cleanup and never becomes a health reading',async()=>{
 for(const metric of ['heart','oxygen']){
  const f=fixture(true,'ended');await assert.rejects(f.session.read('exact-fixture-target',()=>true,()=>{},true,metric),/戒指已结束测量/);
  assert.equal(f.writes.filter(b=>b[4]===4&&b[5]===21).length,1);
  assert.equal(f.writes.filter(b=>b[4]===1&&b[10]===0).length,1);
  assert.equal(f.clients[0].closed,true);
 }
});

test('cancellation between a sample and its queued STOP still sends exactly one cleanup STOP',async()=>{
 const f=fixture();
 await assert.rejects(f.session.read('exact-fixture-target',()=>true,message=>{if(message.includes('停止测量并确认'))f.session.cancel();},true,'heart'),/取消|变化/);
 assert.equal(f.writes.filter(b=>b[4]===1&&b[5]===24&&b[10]===0).length,1);
 assert.equal(f.clients[0].closed,true);
});
