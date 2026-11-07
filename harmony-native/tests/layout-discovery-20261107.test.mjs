import test from 'node:test';import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';import {registerHooks,stripTypeScriptTypes} from 'node:module';
registerHooks({resolve(s,c,next){return next(s.startsWith('.')&&c.parentURL?.endsWith('.ts')&&!/\.[a-z]+$/.test(s)?s+'.ts':s,c);}});
const d=await import('../entry/src/main/ets/model/WearableDiscovery.ts');
const c=await import('../entry/src/main/ets/model/WearableContracts.ts');
const {ringGridWidth,ringMemberNumber}=await import('../entry/src/main/ets/model/RingParity.ts');
test('R/HR/K80 rings are discoverable without granting any supported vendor transport',()=>{
 for(const name of ['SD-RING-R7 Ultra','R7 Pro','R8 Pro','R21','R22','SD-RING-R12','R18','R20','HR01','HR05','K80','SD-RING-HR 05','Q_ring','O_ring']){
  assert.equal(d.isUnavailableRing(name),true,name);assert.equal(c.wearableProviderForName(name),'',name);
 }
 for(const name of ['midea','Room speaker','W8 1234','V Ring','ET488','']) assert.equal(d.isUnavailableRing(name),false,name);
});
test('unavailable discovery merges exact transport only, updates RSSI, and is bounded',()=>{
 const original=[{key:'a',name:'R8',rssi:-60}];
 const result=d.mergeUnavailableRings(original,[{key:'a',name:'R8 Pro',rssi:-50},{key:'b',name:'R8',rssi:-70},{key:'c',name:'midea',rssi:-20}]);
 assert.equal(result.length,2);assert.equal(result[0].rssi,-50);assert.equal(original[0].rssi,-60);
 assert.equal(d.mergeUnavailableRings([],Array.from({length:100},(_,i)=>({key:String(i),name:'R21',rssi:-50}))).length,64);
});
test('member number matches Android numeric validation and never displays account UUID',()=>{
 assert.equal(ringMemberNumber({id:'synthetic-uuid',memberNo:'12345'}),'12345');
 assert.equal(ringMemberNumber({promo_code:123}),'123');
 for(const value of ['synthetic-uuid','ABC123','0',-1,2147483648,1.5,'00123',true])assert.equal(ringMemberNumber({id:123,memberNo:value}),'--');
 assert.equal(ringMemberNumber({memberNo:'bad',promo_code:99}),'99');
});
test('shortcut grids fill their row and wrap at narrow width or large text',()=>{
 assert.equal(ringGridWidth(390,1,3),'33.333333333333336%');
 assert.equal(ringGridWidth(390,1,4),'25%');assert.equal(ringGridWidth(390,1,5),'33.333333333333336%');
 assert.equal(ringGridWidth(332,1,3),'50%');assert.equal(ringGridWidth(390,2,5),'50%');
});
const service=readFileSync(new URL('../entry/src/main/ets/services/VepWearableService.ets',import.meta.url),'utf8');
const raw=service.slice(service.indexOf('  private onScanResults ='),service.indexOf('  private startSystemConnectedCheck()')).replace('private onScanResults','const onScanResults');
const make=new Function('isUnavailableRing','mergeUnavailableRings','knownWearableName','createWearableDevice','mergeWearableDevices',stripTypeScriptTypes(raw,{mode:'transform'})+';return onScanResults;');
test('production BLE callback surfaces R7/R8/HR advertisements without connecting or granting capability',()=>{
 const notifications=[];const ctx={scanning:true,scanObserved:0,scanObservedIds:new Set(),scanPackets:new d.DiscoveryPacketCache(),unavailableRings:[],listener:{onUnavailableRings:r=>notifications.push(r)},sdk:{processScanResults:()=>[]}};
 const callback=make.call(ctx,d.isUnavailableRing,d.mergeUnavailableRings,d.knownWearableName,c.createWearableDevice,c.mergeWearableDevices);
 callback([{deviceId:'fixture-r7',deviceName:'SD-RING-R7 Ultra',rssi:-50,connectable:true,data:new ArrayBuffer(0)},{deviceId:'fixture-r8',deviceName:'R8',rssi:-60,connectable:true,data:new ArrayBuffer(0)},{deviceId:'fixture-speaker',deviceName:'midea',rssi:-30,connectable:true,data:new ArrayBuffer(0)}]);
 assert.equal(notifications.at(-1).length,2);assert.equal(ctx.unavailableRings[0].name,'SD-RING-R7 Ultra');
 ctx.scanning=false;callback([{deviceId:'late',deviceName:'HR05',rssi:-50,data:new ArrayBuffer(0)}]);assert.equal(ctx.unavailableRings.length,2);
});
