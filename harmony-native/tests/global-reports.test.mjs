import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
import { readFileSync } from 'node:fs';
registerHooks({resolve(specifier,context,next){return next(specifier.startsWith('.')&&context.parentURL?.endsWith('.ts')&&!/\.[a-z]+$/.test(specifier)?specifier+'.ts':specifier,context)}});
const {AccountClient}=await import('../entry/src/main/ets/services/AccountClient.ts');
const {ApiError}=await import('../entry/src/main/ets/model/Contracts.ts');
const {HealthUploadService}=await import('../entry/src/main/ets/services/HealthUploadService.ts');
const {parseReportProfile,parseReportEligibility,reportGenerationBlock,validateReportPdf}=await import('../entry/src/main/ets/model/GlobalHealthReports.ts');
const owner='10000000-0000-4000-8000-000000000001',reportId='20000000-0000-4000-8000-000000000001',now=Date.UTC(2026,8,9);
const document={path:'/api/saydian-app/v2/content/legal/health_ai_analysis?version=fixture-v3&locale=en',version:'fixture-v3',locale:'en'};
const profile=()=>({memberId:owner,analysisConsent:{granted:true,version:document.version,availableVersion:document.version,document}});
const eligibility=()=>({eligible:true,consentRequired:false,validRecordCount:10,distinctDays:5,minimumDistinctDays:3,availableCredits:1});
const report=(status='queued')=>({id:reportId,status,period:{from:'2026-08-01T00:00:00Z',to:'2026-09-01T00:00:00Z'},dataCompleteness:{validRecordCount:10,distinctDays:5},freePreview:{title:'Synthetic report',summary:'Synthetic source text'}});
const session=()=>({accessToken:'fixture-access',refreshToken:'fixture-refresh',expiresAt:new Date(now+3600000).toISOString(),member:{id:owner,nickname:'Synthetic user'}});
const pdf=()=>new TextEncoder().encode('%PDF-1.4\nsynthetic fixture\n%%EOF\n').buffer;
function fixture(handler,download=async()=>pdf()){
 const calls=[],downloads=[],store={value:undefined,async read(){return this.value},async write(v){this.value=v},async clear(){this.value=undefined}};
 const client=new AccountClient({async request(...args){calls.push(args);const [path]=args;return {code:200,data:path.endsWith('/auth/login')||path.endsWith('/auth/refresh')?session():await handler(...args)}},async download(...args){downloads.push(args);return download(...args)}},store,()=>now,true);
 return{client,calls,downloads,store};
}
async function login(f){await f.client.login('synthetic@example.com','fixture-password');return f}
function defaults(path,fields,session,body){if(path.endsWith('/health/profile'))return profile();if(path.endsWith('/eligibility'))return eligibility();if(path.endsWith('/'+reportId)&&!body)return report('failed');return report()}

test('global legacy health uploads send nothing and keep local records pending without acknowledgements',async()=>{
 const f=await login(fixture(defaults)),pending=[{id:'synthetic-heart',deviceKey:'synthetic-watch',metric:'heart',timestamp:now,source:'app_measurement',values:[{name:'心率',value:75,unit:'BPM'}],samples:[],sampleFrequency:0}];
 let marks=0;const store={async pending(){return pending},async pendingCount(){return pending.length},async markUploaded(){marks++}};
 const before=f.calls.length,result=await new HealthUploadService(store,f.client).synchronize();
 assert.equal(result.state,'retry');assert.equal(result.uploaded,0);assert.equal(result.pending,1);assert.equal(marks,0);assert.equal(f.calls.length,before);
 const native=readFileSync(new URL('../entry/src/main/ets/services/SaydianApi.ets',import.meta.url),'utf8');
 assert.doesNotMatch(native,/['"]token['"]\s*[:\]]/);assert.match(native,/Authorization/);
});

test('report profiles require the current reviewed metadata, true owner and explicit consent',()=>{
 assert.equal(parseReportProfile(profile(),owner).consentGranted,true);
 for(const changed of [{...profile(),memberId:'wrong'},{...profile(),analysisConsent:undefined}])assert.throws(()=>parseReportProfile(changed,owner));
 for(const document of [null,{path:'https://wrong.invalid/legal',version:'fixture-v3',locale:'en'}])assert.equal(parseReportProfile({...profile(),analysisConsent:{...profile().analysisConsent,document}},owner).consentGranted,false);
 assert.equal(parseReportProfile({...profile(),analysisConsent:{...profile().analysisConsent,version:'old'}},owner).consentGranted,false);
});
test('eligibility fail-closes malformed data, missing consent, insufficient records and missing credits',()=>{
 for(const e of [{...eligibility(),availableCredits:-1},{...eligibility(),minimumDistinctDays:0},{...eligibility(),eligible:1}])assert.throws(()=>parseReportEligibility(e));
 const p=parseReportProfile(profile(),owner),e=parseReportEligibility(eligibility());
 assert.equal(reportGenerationBlock(p,e),'');
 assert.equal(reportGenerationBlock(p,{...e,availableCredits:0}),'reports_payment_unavailable');
 assert.equal(reportGenerationBlock(p,{...e,availableCredits:0},true),'');
 assert.equal(reportGenerationBlock(p,{...e,distinctDays:0}),'reports_need_data');
 assert.equal(reportGenerationBlock({...p,consentGranted:false},e),'reports_consent_required');
});
test('generation rechecks profile and eligibility then sends the actual V2 POST without billing',async()=>{
 const f=await login(fixture(defaults));assert.equal((await f.client.generateHealthReport()).id,reportId);
 assert.deepEqual(f.calls.slice(1).map(c=>c[0].split('/v2')[1]),['/health/profile','/health/reports/eligibility','/health/reports']);
 assert.equal(f.calls.at(-1)[3],'{}');assert.equal(f.calls.at(-1)[4],'POST');assert.ok(f.calls.slice(1).every(c=>c[2].memberId===owner));
 assert.equal(f.calls.some(c=>/billing|payment/.test(c[0])),false);
});
test('failed eligibility or withdrawn consent does not create a report or payment',async()=>{
 for(const mode of ['credits','data','consent']){
  const f=await login(fixture((...args)=>{if(args[0].endsWith('/eligibility'))return {...eligibility(),availableCredits:mode==='credits'?0:1,eligible:mode!=='data',consentRequired:mode==='consent'};return defaults(...args)}));
  await assert.rejects(f.client.generateHealthReport());assert.equal(f.calls.some(c=>c[4]==='POST'&&!c[0].includes('/auth/')),false);
 }
});
test('retry checks FAILED on the server and does not require or consume another credit',async()=>{
 const f=await login(fixture((...args)=>args[0].endsWith('/eligibility')?{...eligibility(),availableCredits:0}:defaults(...args)));
 assert.equal((await f.client.generateHealthReport(reportId)).status,'queued');assert.match(f.calls.at(-1)[0],new RegExp(reportId+'/retry$'));
 const other=await login(fixture((...args)=>args[0].endsWith('/'+reportId)?report('revoked'):defaults(...args)));
 await assert.rejects(other.client.generateHealthReport(reportId),/reports_pending/);assert.equal(other.calls.some(c=>c[0].endsWith('/retry')),false);
});
test('an entitlement race does not pretend payment or report generation succeeded',async()=>{
 const f=await login(fixture((...args)=>args[0].endsWith('/health/reports')?report('awaiting_payment'):defaults(...args)));
 await assert.rejects(f.client.generateHealthReport(),/reports_payment_unavailable/);
});
test('analysis notice and consent match freshly reviewed version and path; withdrawal remains possible without documents',async()=>{
 const f=await login(fixture((...args)=>args[0]===document.path?{version:document.version,contentHtml:'<p>Reviewed synthetic notice</p>',title:'Fixture'}:defaults(...args)));
 assert.match((await f.client.analysisNotice(document)).content,/Reviewed synthetic/);
 await f.client.setReportConsent(true,document);assert.deepEqual(JSON.parse(f.calls.at(-1)[3]),{granted:true,version:'fixture-v3',locale:'en'});
 await assert.rejects(f.client.setReportConsent(true,{...document,version:'old'}),/reports_consent_required/);
 const before=f.calls.length;await f.client.setReportConsent(false);assert.equal(f.calls.length,before+1);assert.equal(JSON.parse(f.calls.at(-1)[3]).granted,false);
});
test('PDF signature, EOF and size validation rejects JSON, empty and truncated responses',()=>{
 assert.deepEqual(validateReportPdf(pdf()),pdf());
 for(const b of [new ArrayBuffer(0),new TextEncoder().encode('{"code":200}').buffer,new TextEncoder().encode('%PDF-1.4\ntruncated').buffer,new ArrayBuffer(20*1024*1024+1)])assert.throws(()=>validateReportPdf(b));
});
test('export preserves UUID and refreshes one rejected credential while authenticating the binary request',async()=>{
 let attempts=0;const f=await login(fixture(defaults,async()=>{if(attempts++===0)throw new ApiError('fixture expired',401);return pdf()}));
 assert.deepEqual(await f.client.exportHealthReport(reportId),pdf());assert.equal(f.downloads.length,2);
 assert.match(f.downloads[0][0],new RegExp(reportId+'/export$'));assert.equal(f.downloads[0][1].memberId,owner);
 assert.equal(f.calls.filter(c=>c[0].endsWith('/auth/refresh')).length,1);
 await assert.rejects(f.client.exportHealthReport('7'));assert.equal(f.downloads.length,2);
});
test('account changes during PDF download invalidate the response before it can be saved',async()=>{
 let release;const pending=new Promise(resolve=>release=resolve);const f=await login(fixture(defaults,()=>pending));
 const task=f.client.exportHealthReport(reportId);await new Promise(resolve=>setImmediate(resolve));
 await f.client.logout();release(pdf());await assert.rejects(task);assert.equal(f.client.current(),undefined);
});
test('overlapping report writes are serialized rather than creating duplicate submissions',async()=>{
 let release;const pending=new Promise(resolve=>release=resolve);const f=await login(fixture((...args)=>args[0].endsWith('/health/profile')?pending:defaults(...args)));
 const first=f.client.generateHealthReport();await assert.rejects(f.client.generateHealthReport(),/reports_pending/);release(profile());await first;
 assert.equal(f.calls.filter(c=>c[0].endsWith('/health/reports')&&c[4]==='POST').length,1);
});
test('UI exposes generation, explicit consent, failed-only retry and real export without fake payment',()=>{
 const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
 for(const id of ['reports_generate','reports_read_notice','reports_analysis_agreement','reports_agree','reports_withdraw','report_export_','report_retry_'])assert.ok(source.includes(id));
 assert.match(source,/report\.status === 'failed'/);assert.match(source,/sameHealthSession\(session, saydianApi.healthSession\(\)\)/);
 assert.match(source,/await saveReportPdf\(context, id, bytes, active\)/);assert.doesNotMatch(source,/message: 'reports_create_unavailable'/);
});
