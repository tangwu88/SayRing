import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks,stripTypeScriptTypes} from 'node:module';
const bytes=new TextEncoder().encode('%PDF-1.4\nsynthetic export\n%%EOF\n').buffer;
const id='20000000-0000-4000-8000-000000000001';
globalThis.reportExportFixture={};
const stubs={
 '@kit.AbilityKit':'export const common={}',
 '@kit.ArkTS':'export const util={TextDecoder:class{decodeToString(b){return new TextDecoder().decode(b)}}}',
 '@kit.CoreFileKit':`export const picker={DocumentSaveOptions:class{},DocumentViewPicker:class{async save(options){const f=globalThis.reportExportFixture;f.options=options;if(f.pickerFail)throw Error('internal error');f.afterPicker?.();return f.selected}}};
 export const fileIo={OpenMode:{READ_WRITE:2},async open(uri,mode){const f=globalThis.reportExportFixture;f.opens.push({uri,mode});if(f.openFail)throw Error('native path details');return{fd:10}},async truncate(){globalThis.reportExportFixture.truncates++},async write(fd,buffer){const f=globalThis.reportExportFixture;f.writes.push(buffer);return f.partial?1:buffer.byteLength},async fsync(){const f=globalThis.reportExportFixture;f.flushes++;if(f.flushFail)throw Error('device failure')},async stat(){const f=globalThis.reportExportFixture;return{size:f.badSize?1:f.writes[0].byteLength}},async close(){const f=globalThis.reportExportFixture;f.closes++;if(f.closeFail)throw Error('descriptor details')}};`,
 '@kit.RemoteCommunicationKit':`export const rcp={Request:class{constructor(url,method,headers){Object.assign(this,{url,method,headers})}},createSession(config){const f=globalThis.reportExportFixture;f.sessions.push(config);return{async fetch(request){f.requests.push(request);for(const chunk of f.chunks)request.destination(chunk);if(f.networkFail)throw Error('native network');return{statusCode:f.status}},cancel(){f.cancels++},close(){f.networkCloses++}}}};`
};
registerHooks({resolve(specifier,context,next){if(stubs[specifier])return{url:'data:text/javascript,'+encodeURIComponent(stubs[specifier]),shortCircuit:true};return next(specifier.startsWith('.')&&/\.(ts|ets)$/.test(context.parentURL||'')&&!/\.[a-z]+$/.test(specifier)?specifier+'.ts':specifier,context)},load(url,context,next){return url.endsWith('.ets')?{format:'module',source:stripTypeScriptTypes(readFileSync(new URL(url),'utf8')),shortCircuit:true}:next(url,context)}});
const{saveReportPdf}=await import('../entry/src/main/ets/services/ReportPdfExport.ets');
const{safeReportPdfHttp}=await import('../entry/src/main/ets/services/LegacySafeHttp.ets');
function reset(){return globalThis.reportExportFixture={selected:['file://fixture/selected/report.pdf'],opens:[],writes:[],truncates:0,flushes:0,closes:0,sessions:[],requests:[],chunks:[bytes],status:200,cancels:0,networkCloses:0}}
const save=(active=()=>true)=>saveReportPdf({},id,bytes,active);
const url='https://app.saydian.cn/global/api/saydian-app/v2/health/reports/'+id+'/export';
test('real PDF bytes are written only to the selected URI, then flushed, size-checked and closed',async()=>{
 const f=reset();assert.equal(await save(),true);assert.deepEqual(f.opens,[{uri:f.selected[0],mode:2}]);assert.deepEqual(f.writes,[bytes]);
 assert.equal(f.flushes,1);assert.equal(f.closes,1);assert.deepEqual(f.options.newFileNames,['saydian-health-report-'+id+'.pdf']);
});
test('canceling the system picker writes nothing and is not reported as success',async()=>{
 const f=reset();f.selected=[];assert.equal(await save(),false);assert.equal(f.opens.length,0);assert.equal(f.writes.length,0);
});
test('account or page changes before/during picker cannot write the old report',async()=>{
 let active=true;const f=reset();f.afterPicker=()=>active=false;await assert.rejects(save(()=>active),/reports_export_failed/);assert.equal(f.opens.length,0);
 reset();await assert.rejects(save(()=>false));assert.equal(globalThis.reportExportFixture.options,undefined);
});
test('partial write, flush, size, open, picker or close failure never reports success or exposes native details',async()=>{
 for(const key of ['partial','flushFail','badSize','openFail','pickerFail','closeFail']){
  const f=reset();f[key]=true;await assert.rejects(save(),/reports_export_failed/);
  if(!['openFail','pickerFail'].includes(key))assert.equal(f.closes,1,key);
 }
});
test('binary transport preserves bytes, authenticates only the global report endpoint and disables redirects',async()=>{
 const f=reset();f.chunks=[bytes.slice(0,7),bytes.slice(7)];
 assert.deepEqual(await safeReportPdfHttp(url,{Authorization:'Bearer synthetic'}),bytes);
 assert.equal(f.sessions[0].requestConfiguration.transfer.autoRedirect,false);assert.equal(f.requests[0].headers.Authorization,'Bearer synthetic');assert.equal(f.networkCloses,1);
 for(const bad of [url.replace('app.saydian.cn','evil.invalid'),url.replace('/api/saydian-app/v2/','/api/v1/'),url+'?redirect=1'])await assert.rejects(safeReportPdfHttp(bad,{}));assert.equal(f.requests.length,1);
});
test('redirect, expired access, denied ownership, missing export font and non-PDF responses are not downloaded as files',async()=>{
 for(const status of [302,401,403,404,503]){const f=reset();f.status=status;await assert.rejects(safeReportPdfHttp(url,{}),error=>error.status===status);assert.equal(f.networkCloses,1)}
 const f=reset();f.chunks=[new TextEncoder().encode('{"data":"not a PDF"}').buffer];await assert.rejects(safeReportPdfHttp(url,{}),/reports_export_failed/);
});
test('binary body has a strict 20 MiB bound and cancels/closes an oversized download',async()=>{
 const f=reset();f.chunks=[new ArrayBuffer(20*1024*1024),new ArrayBuffer(1)];await assert.rejects(safeReportPdfHttp(url,{}),/reports_export_failed/);assert.equal(f.cancels,1);assert.equal(f.networkCloses,1);
});
